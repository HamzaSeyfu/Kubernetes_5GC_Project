Ce que l’on voit dans votre dernier `kubectl describe` est en fait la source du problème : votre conteneur « AMF » tourne en fait l’image `free5gc/smf:latest`, et non `free5gc/amf:latest`. Du coup, le binaire SMF se lance, exécute sa tâche (ou affiche son aide) et se termine immédiatement avec un code de sortie 0. Kubernetes, avec `restartPolicy: Always`, voit que le conteneur a terminé (Exit Code 0) et tente de le redémarrer indéfiniment, ce qui se traduit par un CrashLoopBackOff. En clair :

1. **AMF Pod**

   * `Image:   free5gc/smf:latest`
   * **Last State → Completed, Exit Code 0** (le binaire SMF s’est terminé normalement)
   * **State → Waiting, Reason → CrashLoopBackOff** (K8s relance sans cesse un conteneur qui quitte immédiatement)

2. **SMF Pod et UPF Pod** probablement souffrent d’un problème similaire (image incorrecte ou binaire qui ne reste pas en écoute).

---

## 1. Correction immédiate : pointer chaque NF sur la bonne image

Ouvrez votre `5GC minimal/values.yaml` et corrigez la section `images:` pour que chaque NF (amf, smf, upf) utilise bien le **package d’image correspondant**, par exemple :

```yaml
imagePullPolicy: IfNotPresent

images:
  amf:
    repository: free5gc/amf
    tag: latest

  smf:
    repository: free5gc/smf
    tag: latest

  upf:
    repository: free5gc/upf
    tag: latest

# (reste de la config AMF/SMF/UPF…)
```

En particulier, dans votre sortie, on voit :

```
Containers:
  amf:
    Image: free5gc/smf:latest
    Last State: Completed (Exit Code 0)
    State: Waiting (Reason CrashLoopBackOff)
```

Cela signifie que votre template `deployment-amf.yaml` a été généré (via `values.yaml`) avec `image: free5gc/smf:latest` au lieu de `free5gc/amf:latest`. À corriger ainsi :

```diff
--- a/5GC minimal/values.yaml
+++ b/5GC minimal/values.yaml
 images:
-  amf:
-    repository: free5gc/smf
-    tag: latest
+  amf:
+    repository: free5gc/amf
+    tag: latest

   smf:
     repository: free5gc/smf
     tag: latest
   upf:
     repository: free5gc/upf
     tag: latest
```

Ensuite, relancez :

```bash
cd ~/Kubernetes_5GC_Project-main/5GC\ minimal
helm uninstall minimal5gc || true
helm install minimal5gc .
```

Vérifiez immédiatement avec :

```bash
kubectl get pods -o wide
```

Vous devriez maintenant voir le pod **AMF** tirer bien l’image `free5gc/amf:latest`, puis rester en état **Running** (au moins suffisamment pour écouter son port 7777). Pareil pour le SMF et l’UPF.

---

## 2. Tester la connectivité de chaque NF quand les pods sont Running

Dès qu’un pod passe à l’état **Running**, vous pouvez vérifier qu’il accepte bien les connexions sur le bon port. Voici les combinaisons à tester, en supposant que vos pods tournent avec ces IP :

* AMF : port **7777**
* SMF : port **7778**
* UPF : port **8805**

### 2.1 Récupérez les IP des pods

```bash
kubectl get pods -o wide
```

Exemple de sortie corrigée :

```
NAME                           READY   STATUS    RESTARTS   AGE   IP          NODE
minimal5gc-minimal5gc-amf-xxx  1/1     Running   0          10s   10.244.0.10 kind-control-plane
minimal5gc-minimal5gc-smf-yyy  1/1     Running   0          10s   10.244.0.11 kind-control-plane
minimal5gc-minimal5gc-upf-zzz  1/1     Running   0          10s   10.244.0.12 kind-control-plane
```

Notez bien ces IP (ici `10.244.0.10`, `10.244.0.11`, `10.244.0.12`), elles serviront pour valider la connectivité.

### 2.2 Lancer un pod “busybox” pour tester depuis l’intérieur du cluster

```bash
kubectl run test-shell \
  --rm -i -t \
  --image=busybox:1.34 \
  --command /bin/sh
```

Dans le shell **busybox**, exécutez :

```sh
# 1) Tester ICMP (ping) pour chaque NF
ping -c 3 10.244.0.10   # AMF
ping -c 3 10.244.0.11   # SMF
ping -c 3 10.244.0.12   # UPF

# 2) Tester la couche SBI HTTP
nc -zv 10.244.0.10 7777   # AMF
nc -zv 10.244.0.11 7778   # SMF

# 3) Tester la couche PFCP (UDP) pour UPF
# busybox nc peut ne pas supporter UDP selon la version, essayez quand même :
nc -zvu 10.244.0.12 8805

# 4) Si vous voulez valider l’API HTTP AMF
wget -qO- http://10.244.0.10:7777/nnrf-nfm/v1/nf-instances

# 5) De même pour l’API SMF (il doit retourner un JSON ou au moins un code 200/204)
wget -qO- http://10.244.0.11:7778/nnrf-nfm/v1/nf-instances
```

* **Attendu** :

  * Le ping répond (0 % de perte).
  * `nc -zv 10.244.0.10 7777` se termine par “succeeded” → l’AMF écoute bien sur 7777.
  * `nc -zv 10.244.0.11 7778` se termine par “succeeded” → le SMF écoute bien sur 7778.
  * `nc -zvu 10.244.0.12 8805` (UDP PFCP) retourne “succeeded” ou “open” → l’UPF écoute sur 8805.
  * Les appels `wget` renvoient du JSON valide (ou au moins un code HTTP 200/204).

Si tout ceci fonctionne, alors vos NFs sont correctement déployées et connectables.

### 2.3 Tester depuis l’hôte via port‐forwarding

Si vous préférez tester depuis votre machine locale (VM), faites :

#### Pour l’AMF

```bash
# 1) Trouvez l’un des pods AMF
POD_AMF=$(kubectl get pods | grep minimal5gc-minimal5gc-amf | awk '{print $1}')

# 2) Creez un port‐forward
kubectl port-forward $POD_AMF 7777:7777 &
PID_FORWARD=$!

# 3) Dans une autre fenêtre, testez localement
curl http://127.0.0.1:7777/nnrf-nfm/v1/nf-instances

# 4) Quand vous avez fini, tuez le port‐forward
kill $PID_FORWARD
```

#### Pour le SMF

```bash
POD_SMF=$(kubectl get pods | grep minimal5gc-minimal5gc-smf | awk '{print $1}')
kubectl port-forward $POD_SMF 7778:7778 &
PID_FORWARD=$!
curl http://127.0.0.1:7778/nnrf-nfm/v1/nf-instances
kill $PID_FORWARD
```

#### Pour l’UPF (PFCP sur 8805)

Le protocole PFCP est habituellement du UDP, donc vous ne pourrez pas faire un HTTP GET contre 8805. Vous pouvez au moins vérifier que le port est ouvert :

```bash
POD_UPF=$(kubectl get pods | grep minimal5gc-minimal5gc-upf | awk '{print $1}')
kubectl port-forward $POD_UPF 8805:8805 &
PID_FORWARD=$!
# tester avec netcat en UDP depuis votre hôte
nc -zvu 127.0.0.1 8805
kill $PID_FORWARD
```

Si `nc -zvu 127.0.0.1 8805` répond “succeeded” ou “open”, cela signifie que l’UPF accepte bien des paquets PFCP sur 8805.

---

## 3. En résumé : pourquoi ça plantait et comment savoir que ça fonctionne

1. **Cause du CrashLoopBackOff initial**

   * Le pod AMF utilisait l’image SMF (`free5gc/smf:latest`) → le binaire SMF s’exécutait puis se terminait immédiatement (Exit Code 0), d’où la boucle de redémarrage.
   * Même principe pour SMF/UPF si vous aviez des erreurs de config JSON ou des images non adaptées.

2. **Correction**

   * Modifiez votre `values.yaml` pour que :

     ```yaml
     images:
       amf:
         repository: free5gc/amf
         tag: latest
       smf:
         repository: free5gc/smf
         tag: latest
       upf:
         repository: free5gc/upf
         tag: latest
     ```
   * Relancez `helm uninstall minimal5gc && helm install minimal5gc .` et vérifiez que les pods passent en `1/1 Running`.

3. **Validation fonctionnelle (connectivité)**

   * **ICMP** : `ping` entre pods pour confirmer que le réseau Kind fonctionne.
   * **TCP/HTTP** :

     * AMF : port 7777
     * SMF : port 7778
   * **UDP/PFCP** :

     * UPF : port 8805 (utiliser `nc -zvu`).
   * **API SBI** (HTTP) :

     * `curl http://<IP_AMF>:7777/nnrf-nfm/v1/nf-instances`
     * `curl http://<IP_SMF>:7778/nnrf-nfm/v1/nf-instances`

Dès que ces tests retournent (1) un ping OK, (2) “succeeded” sur les `nc -zv` ou “code 200/204 + JSON” sur les `curl`, vous savez que votre cœur minimal est réellement **en Running** et **opérationnel** (même s’il ne gère encore que l’enregistrement Simple NF). Any further SF/UPF interaction (PFCP sessions, etc.) sera la suite logique.
