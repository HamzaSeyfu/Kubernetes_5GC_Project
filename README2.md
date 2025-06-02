Voici ce que je vois d’après vos dernières captures :

1. **Tous les pods (AMF, SMF, UPF) sont en `CrashLoopBackOff`**
   Même si, dans la sortie de `kubectl describe pod ...` le conteneur apparaît brièvement en **Running**, il redémarre aussitôt (d’où un CrashLoopBackOff permanent). Autrement dit, l’instance “en Running” que vous décrivez n’est qu’un tout petit laps de temps avant qu’elle plante à nouveau.

2. **Le ping fonctionne, mais le test TCP/HTTP que vous avez fait ciblait le mauvais pod/port**

   * Vous avez pingé **10.244.0.9**, qui est l’IP du pod SMF. Le ping était OK, donc le réseau CNI est bien configuré.
   * Ensuite vous avez tapé

     ```bash
     telnet 10.244.0.9 8805  
     nc -zv 10.244.0.9 8805  
     wget -qO- http://10.244.0.9:8805/nnrf-nfm/v1/nf-instances  
     ```

     → Mais **10.244.0.9 (SMF) n’écoute jamais le port 8805**. Par définition :

     * L’AMF expose son SBI HTTP sur le port **7777**,
     * Le SMF expose son SBI HTTP sur le port **7778**,
     * Le UPF expose son PFCP sur le port **8805** (et généralement rien en HTTP sur 8805).

   En d’autres termes, lorsque vous faites `nc 10.244.0.9 8805`, il est normal que vous obteniez “Connection refused” : le SMF **n’écoute pas** sur 8805. Pour tester correctement :

   * Si vous voulez vérifier que le SMF répond en HTTP, essayez le port **7778** sur 10.244.0.9, par exemple depuis le busybox :

     ```sh
     nc -zv 10.244.0.9 7778  
     # ou  
     wget -qO- http://10.244.0.9:7778/nnrf-nfm/v1/nf-instances
     ```
   * Si vous voulez vérifier l’UPF, utilisez l’IP du pod UPF (par exemple 10.244.0.8) et le port **8805** :

     ```sh
     nc -zv 10.244.0.8 8805  
     # ou  
     wget -qO- http://10.244.0.8:8805/  # (certains UPF ne répondent pas en HTTP mais check PFCP via UDP)
     ```
   * Pour l’AMF, ce sera l’IP associée (par exemple 10.244.0.10) sur le port **7777**.

3. **Les pods CrashLoopBackOff ne restent jamais assez longtemps en “Running” pour accepter une connexion**

   * Même si vous y arrivez à accéder brièvement (dans la capture précédente, l’UPF a pu être en Running au moment où vous avez décrit le pod), dès que vous tentez un `nc` ou un `wget`, l’application à l’intérieur du conteneur plante, ce qui provoque le redémarrage du pod.
   * C’est pourquoi, lorsque vous affichez les logs via `kubectl logs -f minimal5gc-minimal5gc-upf-…`, vous n’obtenez rien : soit le processus meurt avant d’écrire quoi que ce soit, soit vous regardez le conteneur **après** qu’il ait crashé (il n’y a plus de sortie “en cours”).

4. **Comment diagnostiquer le CrashLoopBackOff et tester la connectivité “au bon moment”**

   ### a) Récupérer les logs de la dernière instance (avant crash)

   Dès qu’un conteneur monument commence à tourner, Kubernetes redirige sa sortie vers un log temporaire. Mais lorsqu’il replante, un nouveau pod (ou conteneur) prend le relais. Pour voir les logs de l’instance **précédente**, faites :

   ```bash
   kubectl logs -p minimal5gc-minimal5gc-upf-9544f94c9-pz5g8
   ```

   ou, si vous ne connaissez pas l’identifiant exact du pod existant et qu’il y a plusieurs replis :

   ```bash
   K=$(kubectl get pods | grep minimal5gc-minimal5gc-upf | awk '{ print $1 }')
   kubectl logs -p $K
   ```

   Vous devriez alors voir un **message d’erreur** (dans cette sortie « précédente ») expliquant pourquoi l’UPF se termine (ex. config JSON introuvable, port déjà utilisé, erreur de binding, etc.). Faites la même chose pour l’AMF et le SMF :

   ```bash
   kubectl logs -p $(kubectl get pods | grep minimal5gc-minimal5gc-amf | awk '{print $1}')  
   kubectl logs -p $(kubectl get pods | grep minimal5gc-minimal5gc-smf | awk '{print $1}')
   ```

   ### b) Observer la raison du redémarrage

   Pour chaque pod en CrashLoopBackOff, décrivez-le pour voir le “Reason” exact :

   ```bash
   kubectl describe pod minimal5gc-minimal5gc-amf-656f74d5b7-tpncc
   ```

   Dans la section **Status → Containers → Last State**, vous verrez quelque chose comme `Exit Code: 1` ou `Signal: 11`, voire un petit message “Error” ou “OOMKilled”. Ça vous oriente sur la cause (manque de config, mémoire insuffisante, binaire non trouvé…).

   ### c) Tester la connectivité juste au moment où le conteneur est en Running

   Pour augmenter votre fenêtre de temps, vous pouvez forcer un “sleep” dans l’entrée du conteneur (mais je vous recommande d’abord d’identifier la raison du crash en logs). Cependant, si vous voulez vraiment tester la connectivité quand le conteneur “touche brièvement au Running” :

   1. Dans une console, exécutez :

      ```bash
      kubectl logs -f minimal5gc-minimal5gc-upf-9544f94c9-pz5g8
      ```

      Vous verrez le log défiler “en direct”.
   2. Dans une autre console, bouclez sur `kubectl get pods -o wide` jusqu’à ce qu’il indique “Running” (et non “CrashLoopBackOff”) pour l’UPF. Ça ne dure que 1 ou 2 secondes, mais vous pouvez essayer dans cette fenêtre :

      ```bash
      kubectl get pods -o wide | grep minimal5gc-minimal5gc-upf | grep Running && \
        echo "→ Tentative de connexion PFCP 10.244.0.8:8805…" && \
        nc -zv 10.244.0.8 8805
      ```

      Si vous voyez que l’UPF s’est lancé “Enough” pour répondre à votre `nc -zv`, vous aurez le message “succeeded”. Sinon, il y aura “Connection refused” et dans vos logs simultanés (dans l’autre onglet) vous verrez pourquoi il s’est interrompu immédiatement.

   ### d) Utiliser un pod de test “en pause” (optionnel)

   Parfois, on crée un pod “pause” pour garder la stack réseau allumée et s’y connecter depuis un shell :

   ```bash
   kubectl run tester --rm -i -t --image=busybox:1.34 -- /bin/sh
   ```

   À l’intérieur de ce shell “tester”, vous pouvez faire :

   ```shell
   # ping
   ping -c3 10.244.0.8       # IP de l’UPF
   # test PFCP
   nc -zv 10.244.0.8 8805
   # test SBI SMF
   nc -zv 10.244.0.9 7778
   # test SBI AMF
   nc -zv 10.244.0.10 7777
   # test HTTP AMF
   wget -qO- http://10.244.0.10:7777/nnrf-nfm/v1/nf-instances
   ```

   Si l’un de ces tests fonctionne **avant que le pod target ne plante**, vous saurez que la couche réseau est OK et que c’est vraiment l’application (le binaire AMF/SMF/UPF) qui plante.

---

## 4. Pourquoi les NF plantent-elles ? (hypothèses courantes)

1. **Configuration JSON incomplète ou malformée**

   * Si le fichier `amf.json`, `smf.json` ou `upf.json` contenu dans votre ConfigMap est invalide (virgule manquante, accolade fermante oubliée, etc.), le binaire se termine immédiatement sans démarrer.
   * Par exemple, vous aviez dans `upf.json` uniquement :

     ```json
     {
       "sbi": {"scheme":"http","ipv4":"0.0.0.0","port":8805}
     }
     ```

     Mais un UPF **attend** en plus une section `pfcp` ou `gtp` minimale pour démarrer. Si cette section est absente, le démarrage échoue.

2. **Absence de dépendance NRF ou MongoDB**

   * Certaines images “stand-alone” AMF/SMF essayent d’aller contacter un **NRF** ou une base **MongoDB** à leur démarrage. Si vous ne l’avez pas déployé, le conteneur plante.
   * Exemple dans les logs (via `kubectl logs -p`) :

     ```
     2025-06-01T10:00:00.123Z [ERR] Could not connect to NRF at 127.0.0.1:8000. Exiting…
     ```
   * Dans un déploiement minimal, il faut soit fournir un `nrf` factice (une adresse IP/Port lambda), soit monter un `nrf.json` qui met `"nrf": { "address": "dummy", "port": 80 }` pour forcer la logique à passer outre.

3. **Le binaire n’existe pas ou le `ENTRYPOINT` n’est pas correct**

   * Dans `deployment-upf.yaml`, si l’`image: free5gc/upf:latest` ne définit **pas** correctement l’ENTRYPOINT (parfois, l’image attend des arguments, comme `upfc -c /free5gc/config/upf.json`), le conteneur démarre, voit “commande inconnue” et se termine.
   * Vérifiez le `Dockerfile` upstream (dans `docker/free5gc/upf/Dockerfile`) : il devrait indiquer l’entrée, par exemple

     ```dockerfile
     ENTRYPOINT ["free5gc-upfd"]
     CMD ["-c","/free5gc/config/upf.json"]
     ```
   * Si c’est absent, il faut ajouter `command:` et `args:` dans votre `deployment-upf.yaml`.

---

## 5. Étapes concrètes pour corriger le minimum et obtenir des pods “Running”

1. **Inspectez vos ConfigMaps**

   * `kubectl get cm minimal5gc-minimal5gc-amf-config -o yaml`
   * `kubectl get cm minimal5gc-minimal5gc-smf-config -o yaml`
   * `kubectl get cm minimal5gc-minimal5gc-upf-config -o yaml`
     Assurez‐vous que la syntaxe JSON (indentation, virgules, accolades) est **strictement valide**. Vous pouvez copier le contenu dans un validateur JSON en ligne pour être sûr.

2. **Ajoutez une configuration “dummy” pour la partie NRF/MongoDB** (pour AMF/SMF) si votre image l’attend. Par exemple, dans `amf.json`/`smf.json` :

   ```jsonc
   {
     "sbi": { "scheme": "http", "ipv4": "0.0.0.0", "port": 7777 },
     "nrf": { "address": "127.0.0.1", "port": 8000, "scheme": "http" },
     "mongodb": { "url": "mongodb://127.0.0.1:27017/free5gc" }
   }
   ```

   Ça force l’AMF à tenter de contacter un “NRF” inexistant sur localhost, mais au moins il ne crashera pas pour manque de “section”.

3. **Vérifiez l’`entrypoint` du conteneur**

   * Regardez le Dockerfile (depuis le ZIP) :

     ```bash
     sed -n '1,20p' ~/Kubernetes_5GC_Project-main/upstream/towards5gs-helm/docker/free5gc/upf/Dockerfile
     ```
   * Si vous remarquez une ligne `ENTRYPOINT [...]` ou `CMD [...]`, notez l’exécutable attendu (par exemple `free5gc-upf/upfd`).
   * Dans votre `deployment-upf.yaml`, assurez-vous que vous **ne réécrasez pas** l’entrée par accident. S’il n’y a pas d’ENTRYPOINT, ajoutez dans `deployment-upf.yaml` :

     ```yaml
     spec:
       containers:
         - name: upf
           image: "{{ .Values.images.upf.repository }}:{{ .Values.images.upf.tag }}"
           imagePullPolicy: {{ .Values.imagePullPolicy }}
           command: ["free5gc-upfd"]        # ou le binaire exact
           args: ["-c", "/free5gc/config/upf.json"]
           ports:
             - containerPort: {{ .Values.upf.port }}
           volumeMounts:
             - name: upf-config
               mountPath: /free5gc/config
     ```
   * Idem pour AMF/SMF : parfois l’image attend un binaire particulier ou des args (vérifiez la doc officielle).

4. **Déployez de nouveau et suivez immédiatement les logs “précédents”**

   ```bash
   helm uninstall minimal5gc || true
   helm install minimal5gc .
   # juste après, dès que vous voyez les pods passer à “ContainerCreating” → 
   sleep 5
   kubectl logs -p $(kubectl get pods | grep minimal5gc-minimal5gc-upf | awk '{print $1}')
   # (idem pour AMF et SMF)
   ```

   Vous devriez maintenant voir une erreur beaucoup plus parlante (“Could not find free5gc-upfd binary” ou “config JSON incorrect”).

5. **Tester la connectivité quand le pod est encore “Running”**
   Après avoir corrigé la config / l’entrypoint, relancez :

   ```bash
   helm uninstall minimal5gc || true
   helm install minimal5gc .
   sleep 10
   kubectl get pods -o wide
   ```

   Tant qu’un pod apparaît en `Running` (même 10 secondes), ouvrez un autre terminal et faites un `nc -zv` / `wget` sur le port approprié. Exemple pour l’UPF :

   ```bash
   IP_UPF=$(kubectl get pods -o wide | grep minimal5gc-minimal5gc-upf | awk '{print $6}')
   nc -zv $IP_UPF 8805
   ```

   Si vous obtenez “succeeded”, c’est que l’UPF écoute bien sur le port PFCP. Pour l’AMF :

   ```bash
   IP_AMF=$(kubectl get pods -o wide | grep minimal5gc-minimal5gc-amf | awk '{print $6}')
   wget -qO- http://$IP_AMF:7777/nnrf-nfm/v1/nf-instances
   ```

   Et pour le SMF :

   ```bash
   IP_SMF=$(kubectl get pods -o wide | grep minimal5gc-minimal5gc-smf | awk '{print $6}')
   wget -qO- http://$IP_SMF:7778/nnrf-nfm/v1/nf-instances
   ```

---

### En résumé

1. **CrashLoopBackOff** signifie que l’application à l’intérieur du conteneur plante presque aussitôt.
2. **Ping** → OK → le réseau CNI est correct.
3. **`nc -zv 10.244.0.9 8805` → “Connection refused”** est normal si vous ciblez **SMF** (10.244.0.9) sur le port 8805, car SMF n’écoute pas là-dessus.
4. Pour voir pourquoi **UPF/SMF/AMF** plantent, faites toujours `kubectl logs -p <pod>` (les logs « previous ») ou `kubectl describe pod <pod>` pour extraire le message d’erreur exact.
5. Vérifiez que vos **ConfigMaps JSON** sont valides (s’ils contiennent des erreurs, le binaire lèvera immédiatement une exception).
6. Assurez-vous que le **Dockerfile** définit bien un **ENTRYPOINT** ou ajoutez-le dans `deployment-*.yaml` (`command:` / `args:`) pour appeler le bon binaire avec le bon fichier de config.
7. **Rebuild/déployez** et dès qu’un pod apparaît quelques secondes en `Running`, testez depuis un busybox ou par port-forwarding sur :

   * AMF → port **7777**
   * SMF → port **7778**
   * UPF → port **8805**
     → S’ils répondent, c’est que l’exécutable s’est lancé correctement.
8. Une fois que chaque NF tourne (au moins assez longtemps pour répondre), corrigez définitivement `values.yaml` et vos templates, puis reclonez le déploiement.

Avec ces étapes, vous devriez pouvoir isoler la cause du CrashLoopBackOff (config manquante ou binaire qui n’est pas exécuté) et valider, à chaque instants où les pods sont “Running”, la connectivité SBI (HTTP) et PFCP dans votre cluster Kind.
