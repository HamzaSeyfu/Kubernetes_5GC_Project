Il arrive parfois qu’un pod passe très brièvement en Running avant de redémarrer, ce qui peut donner l’impression qu’il est « Running » quand on le décrit, alors qu’en réalité il fait un CrashLoopBackOff (c’est la dernière instance qui a réussi à démarrer assez longtemps pour qu’on puisse la décrire). Pour tester sa connectivité et vérifier s’il fonctionne même momentanément, voici une série d’étapes et de commandes à exécuter. L’idée est de :

1. Identifier l’IP du pod (ou récupérer son nom exact)
2. Exécuter un petit conteneur utilitaire « de test » (par exemple busybox ou curlimages/curl) pour qu’il puisse se connecter au pod AMF/SMF/UPF et essayer d’atteindre les ports SBI ou PFCP.
3. Tester depuis l’hôte (votre machine) la connectivité au service via port-forwarding si nécessaire.
4. Observer les logs au même moment pour voir quel type d’erreur se produit juste avant le redémarrage.

---

## 1. Vérifier l’état global et récupérer le nom/IP du pod

1. Lancez :

   ```bash
   kubectl get pods -o wide
   ```

   Vous verrez quelque chose comme :

   ```
   NAME                        READY   STATUS             RESTARTS   AGE   IP          NODE
   minimal5gc-minimal5gc-amf   0/1     CrashLoopBackOff   4          2m   10.244.0.5  kind-control-plane
   minimal5gc-minimal5gc-smf   0/1     CrashLoopBackOff   4          2m   10.244.0.6  kind-control-plane
   minimal5gc-minimal5gc-upf   1/1     Running            0          2m   10.244.0.7  kind-control-plane
   ```

   * Ici, on voit que **UPF** est encore “Running” (ceci correspond à la dernière instance qui n’a pas encore crashé), tandis que l’AMF et le SMF tournent en boucle d’échec.
   * Notez l’**IP** (`10.244.0.7`) et le nom exact du pod UPF (`minimal5gc-minimal5gc-upf-…`).

2. Pour avoir la dernière IP même si le pod redémarre, vous pouvez aussi décrire le ReplicaSet :

   ```bash
   kubectl describe rs minimal5gc-minimal5gc-upf
   ```

   et rechercher l’IP de la dernière instance sous “Events” → “Added interface” ou “IP” dans la section “Status” (mais généralement `kubectl get pods -o wide` suffit).

---

## 2. Tester la connectivité depuis un conteneur « busybox » ou « curl » dans le cluster

Pour tester la connectivité de l’intérieur du cluster (couche L3 + L4) :

1. Créez un pod de test avec `busybox` (ou `curlimages/curl` si vous avez besoin de curl) :

   ```bash
   kubectl run test-shell \
     --rm -i -t \
     --image=busybox:1.34 \
     --command /bin/sh
   ```

   Cette commande vous ouvre un shell interactif dans un conteneur **busybox**. Lorsque vous en avez fini, tapez `exit` pour fermer et faire disparaître le pod `test-shell` (option `--rm`).

2. Depuis ce shell, essayez de **pinger** (ICMP) l’UPF (ou l’AMF/SMF) en utilisant l’IP récupérée plus haut :

   ```sh
   # Dans le pod test-shell (busybox), par exemple :
   ping -c 3 10.244.0.7
   ```

   * Si cela répond, c’est que la couche réseau de Kind fonctionne correctement.
   * Si vous avez un “NetworkPolicy” restrictive, ou si ce pod ne peut pas être pingué, vous verrez un timeout. Dans ce cas, il faut vérifier vos NetworkPolicies ou CNI.

3. Toujours depuis le même shell, testez la connectivité TCP sur le port **SBI AMF** (7777) ou SBI SMF (7778), ou PFCP UPF (8805). Par exemple, pour UPF :

   ```sh
   # Tester le port PFCP (8805) de l'UPF
   telnet 10.244.0.7 8805
   ```

   ou bien :

   ```sh
   nc -zv 10.244.0.7 8805
   ```

   * Si le port est ouvert et qu’un service écoute, vous verrez un message « connected » ou « open ».
   * Si le résultat est “connection refused” ou “timeout”, cela veut dire que le conteneur UPF n’écoute pas sur ce port ou qu’il a crashé juste avant.

4. Pour tester un appel HTTP (SBI) sur AMF, faites par exemple :

   ```sh
   # Si l'AMF était encore en Running longtemps, et qu’on avait son IP (ici 10.244.0.5) :
   wget -qO- http://10.244.0.5:7777/nnrf-nfm/v1/nf-instances
   ```

   * Sur `wget`, si vous obtenez un JSON (ou un statut 200/204), alors l’AMF répond.
   * Sinon, vous verrez “Connection refused” ou “No route to host”.

---

## 3. Tester depuis votre machine hôte (port-forwarding)

Si vous préférez tester depuis votre hôte (sans lancer un busybox dans le cluster), utilisez le port forwarding :

1. **Identifiez** le nom du pod (version “Running” ou celui qui redémarre, par exemple UPF) :

   ```bash
   kubectl get pods
   # minimal5gc-minimal5gc-upf-9544f94c9-pz5g8   1/1   Running   0  30s
   ```

2. **Forwardez** le port du pod vers votre machine. Par exemple, pour UPF (8805) :

   ```bash
   kubectl port-forward minimal5gc-minimal5gc-upf-9544f94c9 8805:8805
   ```

   * Tenez cette commande ouverte dans un terminal ; elle maintient la redirection du port.
   * Dans un autre onglet, testez localement :

     ```bash
     nc -zv 127.0.0.1 8805
     # ou
     telnet 127.0.0.1 8805
     ```
   * Si le port est ouvert, c’est que l’UPF écoute bien (au moment où il est en Running).
   * Sinon, vous obtiendrez “Connection refused” (ce qui signifie que le container n’écoute plus).

3. Pour tester l’API HTTP du SMF/AMF (7777, 7778), procédez de la même façon. Exemple pour l’AMF :

   ```bash
   # Récupérez le nom exact du pod AMF (même s’il crashloop, utilisez le dernier en Running ou le plus jeune)
   kubectl get pods | grep amf
   # Imaginons qu'il s'appelle minimal5gc-minimal5gc-amf-f95cbf65c-4txr2
   kubectl port-forward minimal5gc-minimal5gc-amf-f95cbf65c-4txr2 7777:7777
   # Dans un autre terminal
   curl http://127.0.0.1:7777/nnrf-nfm/v1/nf-instances
   ```

---

## 4. Surveiller les logs en parallèle

Pendant vos tests de connectivité, gardez un autre onglet qui suit les logs du pod. Par exemple, pour l’UPF dans notre exemple :

```bash
kubectl logs -f minimal5gc-minimal5gc-upf-9544f94c9-pz5g8
```

* Si l’UPF retourne des erreurs PFCP (« bind failed », « cannot attach to interface », etc.), vous saurez immédiatement pourquoi il redémarre.
* Si vous voyez un message du type « listening on port 8805 », alors le port est bien ouvert.

Faites de même pour l’AMF et le SMF (si vous arrivez à en avoir une instance en Running suffisamment longtemps pour les décrire et obtenir des logs) :

```bash
kubectl logs -f minimal5gc-minimal5gc-amf-<suffix>
kubectl logs -f minimal5gc-minimal5gc-smf-<suffix>
```

---

## 5. Tests spécifiques à chaque NF

### 5.1. AMF (Service-Based Interface – HTTP)

* **Port : 7777**
* **Prérequis** : Au minimum, l’AMF doit savoir où trouver le SMF (même s’il n’y a pas de NRF).
* **Exemple de test** :

  ```bash
  # Depuis le busybox dans le cluster :
  wget -qO- http://10.244.0.5:7777/nnrf-nfm/v1/nf-instances
  ```

  → Réponse JSON si l’AMF tourne.
* **Port-forwarding** sur votre hôte :

  ```bash
  kubectl port-forward minimal5gc-minimal5gc-amf-<suffix> 7777:7777
  curl http://127.0.0.1:7777/nnrf-nfm/v1/nf-instances
  ```

### 5.2. SMF (SBI – HTTP / PFCP vers UPF)

* **Port HTTP : 7778**, **Port PFCP : 8805** (PFCP est le protocole UDP/TCP pour parler à l’UPF).
* **Exemple de test HTTP** (SMF vers AMF) :

  ```bash
  wget -qO- http://10.244.0.6:7778/nnrf-nfm/v1/nf-instances
  ```
* **Exemple de test PFCP** (SMF → UPF) :

  ```bash
  nc -u -v 10.244.0.7 8805
  ```

  Vous devez obtenir “succeeded” si le socket UDP est accessible.
* **Port-forwarding HTTP (7778)** :

  ```bash
  kubectl port-forward minimal5gc-minimal5gc-smf-<suffix> 7778:7778
  curl http://127.0.0.1:7778/nnrf-nfm/v1/nf-instances
  ```
* **Port-forwarding PFCP (8805)** :

  ```bash
  kubectl port-forward minimal5gc-minimal5gc-upf-<suffix> 8805:8805
  nc -u -v 127.0.0.1 8805
  ```

### 5.3. UPF (PFCP Listener)

* **Port fixe : 8805**
* **Test** :

  ```bash
  # Depuis busybox
  nc -zv 10.244.0.7 8805
  ```
* **Port-forwarding** :

  ```bash
  kubectl port-forward minimal5gc-minimal5gc-upf-<suffix> 8805:8805
  nc -zv 127.0.0.1 8805
  ```

---

## 6. Diagnostiquer un CrashLoopBackOff qui ne s’explique pas immédiatement

Si, au bout de plusieurs tentatives, vous avez toujours des CrashLoopBackOff et que rien ne tourne en Running suffisamment longtemps pour répondre sur les ports, voici une procédure pas à pas :

1. Mettez l’UPF (ou l’AMF/SMF) en **hyper-verbeux** (si l’image le supporte), pour voir exactement pourquoi il plante :

   * Certains container images acceptent une variable d’environnement comme `LOG_LEVEL=debug`. Ajoutez cette ligne dans le `deployment-upf.yaml` (sous `env:`) :

     ```yaml
     env:
       - name: LOG_LEVEL
         value: "debug"
     ```
   * Relancez le chart, puis taillez les logs (`kubectl logs -f …`) pour identifier précisément l’erreur.

2. Vérifiez si l’image attend un **fichier de configuration** minimal qu’on ne lui a pas fourni :

   * Dans `configmap-upf.yaml`, vous avez (par défaut) un JSON minimal. Essayez d’en fournir un encore plus simplifié, voire vide, juste pour voir si le conteneur reste en Running.
   * Exemple d’UPF « hello world » :

     ```yaml
     # configmap-upf.yaml (version de debug)
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: {{ include "minimal5gc.fullname" . }}-upf-config
     data:
       upf.json: |-
         {
           "sbi": { "scheme": "http", "ipv4": "0.0.0.0", "port": 8805 }
           # on retire les PFCP/GTP/IF-N3 pour isoler le problème
         }
     ```
   * Redeployez, puis voyez si le pod reste en Running sans configuration PFCP.

3. Si c’est encore CrashLoopBackOff, ouvrez un shell dans le pod pour inspecter la filesystem et tenter de lancer le binaire à la main :

   ```bash
   # Attendez qu’il soit "ContainerCreating", puis rapidement :
   kubectl run debug-shell \
     --rm -it \
     --image=free5gc/upf:latest \
     --overrides='
   {
     "apiVersion": "v1",
     "kind": "Pod",
     "metadata": { "name": "upf-debug" },
     "spec": {
       "containers": [
         {
           "name": "upf",
           "image": "free5gc/upf:latest",
           "stdin": true,
           "tty": true,
           "command": ["/bin/sh"]
         }
       ],
       "restartPolicy": "Never"
     }
   }' \
     -- /bin/sh
   ```

   Cela lance un shell **interactif** dans un conteneur `free5gc/upf:latest`.

   * Depuis ce shell, essayez d’exécuter manuellement le binaire UPF avec vos fichiers de config (“`upfd`” ou “`free5gc-upf`”), pour voir l’erreur en temps réel.
   * Vous pouvez monter la configmap en volume (avec `-v`) ou copier manuellement la config dans `/free5gc/config` pour isoler le problème.

4. Enfin, comparez avec l’image « tout-en-un ». Normalement, une image monolithe Free5GC n’a pas ce problème de CrashLoopBackOff. Si elle tourne, c’est la preuve que le problème vient de l’absence de dépendance (NRF, Mongo, etc.) ou d’une configuration PFCP manquante.

---

## 7. Exemple de tests rapides à exécuter

Prenons le cas concret où **UPF** est la seule fonction qui arrive à « tenir » en Running quelques secondes. Voici un condensé des commandes pour tester :

1. Récupérer la liste des pods (avec IP) :

   ```bash
   kubectl get pods -o wide
   ```

2. Ouvrir un shell busybox dans le cluster :

   ```bash
   kubectl run test-shell --rm -i -t --image=busybox:1.34 --command /bin/sh
   ```

3. Depuis `test-shell`, testez le PFCP sur UPF (IP=10.244.0.7, port=8805) :

   ```sh
   ping -c 2 10.244.0.7
   nc -zv 10.244.0.7 8805
   ```

   * Si “connected” alors UPF accepte le PFCP.
   * Sinon “connection refused” indique qu’il n’écoute pas (ou a crashé juste avant).

4. Si vous voulez tester l’HTTP SBI UPF (certains UPF exposent une API REST pour la configuration) :

   ```sh
   wget -qO- http://10.244.0.7:8805   # (si l’UPF expose un endpoint HTTP sur 8805)
   # ou si UPF n’a pas d’HTTP, testez AMF ou SMF de la même façon
   ```

5. Garder un terminal « logs » à côté pour UPF :

   ```bash
   kubectl logs -f minimal5gc-minimal5gc-upf-9544f94c9-pz5g8
   ```

   * Regardez dans les logs si l’UPF recycle PFCP ou remonte une erreur juste au moment où vous exécutez `nc`.

---

## 8. Conclusion

* Un pod en **CrashLoopBackOff** peut brièvement apparaître comme “Running” quand on le décrit (car on regarde le dernier état réussi).
* Pour vérifier la connectivité effective, **créez un conteneur de test** (busybox ou un conteneur curl) à l’intérieur du cluster, puis :

  1. `ping` pour vérifier la couche L3
  2. `nc -zv <pod_IP> <port>` pour vérifier la couche L4 (SBI HTTP : 7777/7778 ou PFCP : 8805)
* Vous pouvez aussi **port-forward** le(s) pod(s) vers votre hôte pour tester en local (ex. `curl http://127.0.0.1:7777`).
* Si vous voyez que le pod répond plusieurs secondes avant de crash, notez l’erreur exacte dans les **logs** (`kubectl logs -f …`) pour comprendre pourquoi il finit par redémarrer (configuration manquante, dépendance NRF absente, PFCP non configuré, etc.).
* Enfin, la solution la plus simple pour obtenir **3 pods “Running” en continu** est généralement d’utiliser une **image “all-in-one”** (monolithique) de Free5GC qui embarque AMF+SMF+UPF+NRF+… dans un seul conteneur, ou de forcer un seul conteneur stable (par ex. `free5gc/smf:latest` ou `free5gc/upf:latest`) pour les 3 rôles, de manière à ce qu’ils ne plantent pas faute de dépendances.

Avec ces commandes et ces tests, vous pourrez isoler précisément quel port ou quel service n’est pas accessible, et corriger la configuration ou changer l’image jusqu’à obtenir un état **Running** stable pour chaque NF.
