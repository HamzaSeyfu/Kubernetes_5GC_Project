Voici un **script de test complet**, que vous pouvez copier-coller dans votre terminal (en adaptant les labels si besoin). Il :

1. **Supprime** les anciens pods (ceux issus de l’ancienne release `minimal5gc-5gc-…`)
2. **Vérifie** qu’il ne reste que les pods de la release courante `minimal5gc-minimal5gc-…`
3. **Fait** les tests de connectivité **interne** (dans chaque pod)
4. **Fait** les tests de connectivité **via Service** depuis un pod client BusyBox
5. **Vérifie** le montage des ConfigMaps
6. **Inspecte** les logs pour les échanges NRF/PFCP
7. **Teste** la résilience (redémarrage d’un pod AMF)

```bash
# 1. Supprimer les anciens pods (prefixe minimal5gc-5gc-)
kubectl delete pod $(kubectl get pods -n 5gc -o name | grep minimal5gc-5gc) -n 5gc

# 2. S’assurer qu’il ne reste que les pods minimal5gc-minimal5gc-…
kubectl get pods -n 5gc

# 3. Tests de connectivité INTERNE (à l’intérieur de chaque pod)
POD_AMF=$(kubectl get pod -n 5gc -l app=minimal5gc-minimal5gc-amf -o jsonpath='{.items[0].metadata.name}')
POD_SMF=$(kubectl get pod -n 5gc -l app=minimal5gc-minimal5gc-smf -o jsonpath='{.items[0].metadata.name}')
POD_UPF=$(kubectl get pod -n 5gc -l app=minimal5gc-minimal5gc-upf -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n 5gc -it $POD_AMF -- sh -c "nc -zv 127.0.0.1 7777 && echo 'AMF: port 7777 OK' || echo 'AMF: port 7777 KO'"
kubectl exec -n 5gc -it $POD_SMF -- sh -c "nc -zv 127.0.0.1 7778 && echo 'SMF: port 7778 OK' || echo 'SMF: port 7778 KO'"
kubectl exec -n 5gc -it $POD_UPF -- sh -c "nc -zv 127.0.0.1 8805 && echo 'UPF: port 8805 OK' || echo 'UPF: port 8805 KO'"

# 4. Tests de connectivité via SERVICES (depuis un pod client BusyBox)
kubectl run -n 5gc test-client --rm -i --tty --image=busybox -- sh -c "
  nc -zv minimal5gc-amf 7777 && echo 'Service AMF joignable' || echo 'Service AMF INJOIGNABLE';
  nc -zv minimal5gc-smf 7778 && echo 'Service SMF joignable' || echo 'Service SMF INJOIGNABLE';
  nc -zv minimal5gc-upf 8805 && echo 'Service UPF joignable' || echo 'Service UPF INJOIGNABLE';
"

# 5. Vérifier le montage des ConfigMaps (lecture du JSON injecté)
kubectl exec -n 5gc -it $POD_AMF -- cat /free5gc/config/amf.json
kubectl exec -n 5gc -it $POD_SMF -- cat /free5gc/config/smf.json
kubectl exec -n 5gc -it $POD_UPF -- cat /free5gc/config/upf.json

# 6. Inspection rapide des logs pour valider NRF/PFCP
kubectl logs -n 5gc deployment/minimal5gc-minimal5gc-amf | grep -i nrf
kubectl logs -n 5gc deployment/minimal5gc-minimal5gc-smf | grep -i pfcp
kubectl logs -n 5gc deployment/minimal5gc-minimal5gc-upf | grep -i pfcp

# 7. Test de résilience : redémarrage du pod AMF
echo ">>> Suppression du pod AMF pour test de résilience"
kubectl delete pod -n 5gc $POD_AMF

# Observer la recréation
echo ">>> Nouveaux pods en cours de création :"
kubectl get pods -n 5gc -w | grep minimal5gc-minimal5gc-amf

# 8. Pendant ce temps, depuis un 2ᵉ pod client, tester la connectivité répétée
kubectl run -n 5gc test-client2 --rm -i --tty --image=busybox -- sh -c "
  while true; do
    nc -zv minimal5gc-amf 7777 && echo AMF OK || echo AMF KO;
    sleep 1;
  done
"
```

---

**Explications rapides** :

* On supprime d’abord **uniquement** les pods portant l’ancien préfixe (`minimal5gc-5gc-…`).
* On identifie ensuite automatiquement les noms des nouveaux pods (`minimal5gc-minimal5gc-…`) via un label selector `app=…`.
* On réalise **en interne** (dans chaque pod) un `nc -zv 127.0.0.1 <port>` pour vérifier que le listener netcat tourne bien.
* On réalise **depuis un pod client** un `nc -zv minimal5gc-<NF> <port>` pour s’assurer que le Service ClusterIP redirige correctement.
* On **cat** les ConfigMaps montés dans les pods pour prouver que la config JSON est injectée.
* On interroge les **logs** des Deployments pour valider les enregistrements NRF et les sessions PFCP.
* Enfin, on **supprime** le pod AMF pour illustrer la résilience (un nouveau pod est recréé automatiquement) et on boucle un test `nc` pour montrer que le service ne reste pas indisponible longtemps.

Avec cette suite de commandes, vous couvrirez **tous** les points mentionnés dans votre rapport, dans l’ordre logique : connectivité, configurations, logs, puis résilience.

J’ai créé le script de tests ajusté pour votre environnement BusyBox et sans vérification de JSON. Téléchargez-le et exécutez-le comme suit :

[Download `run-tests.sh`](sandbox:/mnt/data/scripts/run-tests.sh)

Puis, dans votre terminal :

```bash
chmod +x scripts/run-tests.sh
./scripts/run-tests.sh
```

Ce script exécutera automatiquement :

1. Les tests de connectivité interne (`nc -zv 127.0.0.1 <port>`) dans chaque pod BusyBox.
2. Les tests de connectivité via les services depuis un pod client BusyBox.
3. Le test de résilience en supprimant le pod AMF puis en vérifiant sa recréation et la connectivité post-failover.

Pour tout supprimer et repartir sur une base propre, tu as trois possibilités :

---

### 1) Supprimer et laisser le Deployment recréer les pods

```bash
# supprime tous les pods dans le namespace 5gc
kubectl delete pods -n 5gc --all

# surveille leur recréation automatique
kubectl get pods -n 5gc -w
```

Comme tu as un Deployment en place, Kubernetes va immédiatement recréer trois nouveaux pods.

---

### 2) Redémarrer manuellement chaque Deployment

```bash
kubectl rollout restart deployment/minimal5gc-minimal5gc-amf   -n 5gc
kubectl rollout restart deployment/minimal5gc-minimal5gc-smf   -n 5gc
kubectl rollout restart deployment/minimal5gc-minimal5gc-upf   -n 5gc

# puis vérifier
kubectl get pods -n 5gc
```

Ça déclenche un **rolling restart** sans toucher au reste du chart.

---

### 3) Désinstaller et réinstaller la release Helm

```bash
helm uninstall minimal5gc -n 5gc
helm install   minimal5gc ./    -n 5gc
```

> **NB** : adapte le chemin `./` si tu n’es pas dans le bon dossier.
> Cette méthode te remet tout à zéro : ConfigMaps, Services, Deployments, pods, etc.

---

Une fois les pods à nouveau en **Running**, relance ton script de tests ou tes commandes `nc` pour valider la connectivité de nouveau :

```bash
kubectl get pods -n 5gc
./scripts/run-tests.sh
```


Le message

```
nc: bad address 'minimal5gc-amf'
Service AMF unreachable
```

vient tout simplement du fait que **vos Services ne s’appellent pas `minimal5gc-amf`** mais `{{ include "minimal5gc.fullname" . }}-amf`, autrement dit ici **`minimal5gc-minimal5gc-amf`** (puisque votre Chart et votre release s’appellent tous les deux `minimal5gc`). Kubernetes DNS ne trouve donc rien sous le nom abrégé `minimal5gc-amf`.

---

### Comment corriger

1. **Vérifiez le nom exact de votre Service**

   ```bash
   kubectl get svc -n 5gc
   NAME                             TYPE        CLUSTER-IP      ...  
   minimal5gc-minimal5gc-amf       ClusterIP   10.96.xxx.xxx  
   minimal5gc-minimal5gc-smf       ClusterIP   10.96.xxx.yyy  
   minimal5gc-minimal5gc-upf       ClusterIP   10.96.xxx.zzz  
   ```

2. **Adaptez vos tests externes**
   Remplacez dans le script les lignes

   ```bash
   nc -zv minimal5gc-amf 7777
   nc -zv minimal5gc-smf 7778
   nc -zv minimal5gc-upf 8805
   ```

   par

   ```bash
   nc -zv minimal5gc-minimal5gc-amf 7777 && echo 'AMF OK' || echo 'AMF KO'
   nc -zv minimal5gc-minimal5gc-smf 7778 && echo 'SMF OK' || echo 'SMF KO'
   nc -zv minimal5gc-minimal5gc-upf 8805 && echo 'UPF OK' || echo 'UPF KO'
   ```

3. **(Optionnel) Utiliser la résolution DNS directe**
   Si vous voulez garder des noms courts, vous pouvez créer un **Service alias** ou un **headless Service** `amf` qui cible les mêmes pods, par exemple un manifest

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: amf
     namespace: 5gc
   spec:
     type: ClusterIP
     selector:
       app: minimal5gc-minimal5gc-amf
     ports:
       - port: 7777
         targetPort: 7777
   ```

   Vous pourrez alors taper

   ```bash
   nc -zv amf 7777
   ```

Une fois ces ajustements effectués, votre script external connectivity repassera en **OK** pour AMF, SMF et UPF.


L’erreur :

```
error: there is no need to specify a resource type as a separate argument when passing arguments in resource/name form
```

vient du fait que `kubectl get pods -o name` renvoie des chaînes du type `pod/minimal5gc-minimal5gc-amf-…`, et que le script faisait ensuite :

```bash
kubectl delete pod -n 5gc pod/minimal5gc-minimal5gc-amf-… -n 5gc
```

soit un `pod` en double (`delete pod pod/...`). Pour corriger, on supprime la répétition du type et on laisse `kubectl delete` gérer directement le couple `resource/name`. Voici le script **intégralement corrigé** :

```bash
#!/usr/bin/env bash
set -euo pipefail

NS=5gc
PREFIX=minimal5gc-minimal5gc

echo "1️⃣ Suppression des anciens pods (${PREFIX})…"
PODS_TO_DELETE=$(kubectl get pods -n $NS -o name | grep $PREFIX || true)
if [ -n "$PODS_TO_DELETE" ]; then
  kubectl delete -n $NS $PODS_TO_DELETE
else
  echo "→ Aucun pod ${PREFIX} trouvé à supprimer"
fi
echo

echo "2️⃣ Pods actuellement en place dans namespace $NS :"
kubectl get pods -n $NS
echo

# 3️⃣ Tests de connectivité INTERNE
echo "🔌 Internal connectivity tests…"
POD_AMF=$(kubectl get pod -n $NS -l app=${PREFIX}-amf -o jsonpath='{.items[0].metadata.name}')
POD_SMF=$(kubectl get pod -n $NS -l app=${PREFIX}-smf -o jsonpath='{.items[0].metadata.name}')
POD_UPF=$(kubectl get pod -n $NS -l app=${PREFIX}-upf -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NS "$POD_AMF" -- nc -zv 127.0.0.1 7777 && echo "AMF: port 7777 OK" || echo "AMF: port 7777 KO"
kubectl exec -n $NS "$POD_SMF" -- nc -zv 127.0.0.1 7778 && echo "SMF: port 7778 OK" || echo "SMF: port 7778 KO"
kubectl exec -n $NS "$POD_UPF" -- nc -zv 127.0.0.1 8805 && echo "UPF: port 8805 OK" || echo "UPF: port 8805 KO"
echo

# 4️⃣ Tests de connectivité via SERVICES
echo "🌐 External connectivity tests via services…"
kubectl run -n $NS test-client --rm -i --tty --image=busybox --restart=Never -- sh -c "
  nc -zv ${PREFIX}-amf 7777 && echo 'Service AMF joignable' || echo 'Service AMF INJOIGNABLE';
  nc -zv ${PREFIX}-smf 7778 && echo 'Service SMF joignable' || echo 'Service SMF INJOIGNABLE';
  nc -zv ${PREFIX}-upf 8805 && echo 'Service UPF joignable' || echo 'Service UPF INJOIGNABLE';
"
echo

# 5️⃣ Vérification du montage des ConfigMaps
echo "📂 Vérification des ConfigMaps montées…"
kubectl exec -n $NS "$POD_AMF" -- sh -c "ls /free5gc/config && echo 'AMF ConfigMap OK' || echo 'AMF ConfigMap MANQUANTE'"
kubectl exec -n $NS "$POD_SMF" -- sh -c "ls /free5gc/config && echo 'SMF ConfigMap OK' || echo 'SMF ConfigMap MANQUANTE'"
kubectl exec -n $NS "$POD_UPF" -- sh -c "ls /free5gc/config && echo 'UPF ConfigMap OK' || echo 'UPF ConfigMap MANQUANTE'"
echo

# 6️⃣ Inspection rapide des logs pour N11 / PFCP
echo "📝 Logs N11 / PFCP…"
kubectl logs -n $NS deployment/${PREFIX}-amf | grep -i nrf || echo "→ Pas de logs NRF dans AMF"
kubectl logs -n $NS deployment/${PREFIX}-smf | grep -i pfcp || echo "→ Pas de logs PFCP dans SMF"
kubectl logs -n $NS deployment/${PREFIX}-upf | grep -i pfcp || echo "→ Pas de logs PFCP dans UPF"
echo

# 7️⃣ Test de résilience : suppression du pod AMF
echo "🔄 Test de résilience : suppression du pod AMF…"
kubectl delete pod -n $NS "$POD_AMF"
echo "⏳ En attente du nouveau pod AMF Ready…"
kubectl wait --for=condition=Ready pod -l app=${PREFIX}-amf -n $NS --timeout=120s
echo

# 8️⃣ Re-test en boucle depuis un second pod client
echo "🧪 Re-test service AMF après failover…"
kubectl run -n $NS test-client2 --rm -i --tty --image=busybox --restart=Never -- sh -c "
  while true; do
    nc -zv ${PREFIX}-amf 7777 && echo 'AMF OK post-failover' || echo 'AMF KO post-failover';
    sleep 1;
  done
"
echo

echo "🎉 Tous les tests sont terminés !"
```

**Étapes pour l’utiliser :**

1. Collez ce contenu dans `scripts/run-tests.sh`.
2. Rendez-le exécutable :

   ```bash
   chmod +x scripts/run-tests.sh
   ```
3. Lancez-le :

   ```bash
   ./scripts/run-tests.sh
   ```

Vous aurez alors bien la suppression des anciens pods, le redéploiement automatique, et tous les tests internes/externe/failover qui passent sur les bons noms de services.
