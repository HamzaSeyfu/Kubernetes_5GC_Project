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

Voici un script complet, prêt à copier-coller dans `scripts/run-tests.sh`. Il utilise vos informations de Service (`minimal5gc-minimal5gc-amf`, etc.) et supprime correctement les anciens pods avant de tout retester :

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Variables ────────────────────────────────────────────────────────────────
NS=5gc
PREFIX=minimal5gc-minimal5gc

# ─── 1) Supprimer les anciens pods ─────────────────────────────────────────────
echo "1️⃣  Deleting existing pods with prefix ${PREFIX}..."
PODS=$(kubectl get pods -n "$NS" -o name | grep "$PREFIX" || true)
if [ -n "$PODS" ]; then
  kubectl delete -n "$NS" $PODS
else
  echo "→ No pods to delete"
fi
echo

# ─── 2) Afficher les pods restants ─────────────────────────────────────────────
echo "2️⃣  Pods currently in namespace $NS:"
kubectl get pods -n "$NS"
echo

# ─── 3) Tests de connectivité INTERNE ──────────────────────────────────────────
echo "3️⃣  Internal connectivity tests..."
POD_AMF=$(kubectl get pod -n "$NS" -l app="${PREFIX}-amf" -o jsonpath='{.items[0].metadata.name}')
POD_SMF=$(kubectl get pod -n "$NS" -l app="${PREFIX}-smf" -o jsonpath='{.items[0].metadata.name}')
POD_UPF=$(kubectl get pod -n "$NS" -l app="${PREFIX}-upf" -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n "$NS" "$POD_AMF" -- nc -zv 127.0.0.1 7777 && echo "✅ AMF internal OK" || echo "❌ AMF internal KO"
kubectl exec -n "$NS" "$POD_SMF" -- nc -zv 127.0.0.1 7778 && echo "✅ SMF internal OK" || echo "❌ SMF internal KO"
kubectl exec -n "$NS" "$POD_UPF" -- nc -zv 127.0.0.1 8805 && echo "✅ UPF internal OK" || echo "❌ UPF internal KO"
echo

# ─── 4) Tests de connectivité via SERVICE ───────────────────────────────────────
echo "4️⃣  External connectivity tests via SERVICES..."
kubectl run -n "$NS" test-client --rm -i --tty --image=busybox --restart=Never -- sh -c "
  nc -zv ${PREFIX}-amf 7777 && echo '✅ Service AMF reachable' || echo '❌ Service AMF unreachable';
  nc -zv ${PREFIX}-smf 7778 && echo '✅ Service SMF reachable' || echo '❌ Service SMF unreachable';
  nc -zv ${PREFIX}-upf 8805 && echo '✅ Service UPF reachable' || echo '❌ Service UPF unreachable';
"
echo

# ─── 5) Vérifier le montage des ConfigMaps ───────────────────────────────────────
echo "5️⃣  Verifying ConfigMap mounts..."
kubectl exec -n "$NS" "$POD_AMF" -- sh -c "ls /free5gc/config && echo '✅ AMF ConfigMap OK'" || echo "❌ AMF ConfigMap missing"
kubectl exec -n "$NS" "$POD_SMF" -- sh -c "ls /free5gc/config && echo '✅ SMF ConfigMap OK'" || echo "❌ SMF ConfigMap missing"
kubectl exec -n "$NS" "$POD_UPF" -- sh -c "ls /free5gc/config && echo '✅ UPF ConfigMap OK'" || echo "❌ UPF ConfigMap missing"
echo

# ─── 6) Inspection rapide des logs N11 / PFCP ────────────────────────────────────
echo "6️⃣  Inspecting logs for N11 / PFCP..."
kubectl logs -n "$NS" deployment/${PREFIX}-amf | grep -i nrf || echo "→ No NRF logs in AMF"
kubectl logs -n "$NS" deployment/${PREFIX}-smf | grep -i pfcp || echo "→ No PFCP logs in SMF"
kubectl logs -n "$NS" deployment/${PREFIX}-upf | grep -i pfcp || echo "→ No PFCP logs in UPF"
echo

# ─── 7) Test de résilience : suppression du pod AMF ──────────────────────────────
echo "7️⃣  Resilience test: deleting AMF pod..."
kubectl delete pod -n "$NS" "$POD_AMF"
echo "⏳ Waiting for AMF to be Ready..."
kubectl wait --for=condition=Ready pod -l app=${PREFIX}-amf -n "$NS" --timeout=120s
echo

# ─── 8) Re-test SERVICE AMF après failover ───────────────────────────────────────
echo "8️⃣  Re-testing Service AMF post-failover..."
kubectl run -n "$NS" test-client2 --rm -i --tty --image=busybox --restart=Never -- sh -c "
  for i in {1..10}; do
    nc -zv ${PREFIX}-amf 7777 && echo '✅ AMF OK post-failover' || echo '❌ AMF KO post-failover';
    sleep 1;
  done
"
echo

echo "🎉 All tests completed!"
```

**Pour l’utiliser :**

1. Sauvegardez ce script sous `scripts/run-tests.sh`.
2. Rendez-le exécutable :

   ```bash
   chmod +x scripts/run-tests.sh
   ```
3. Lancez-le :

   ```bash
   ./scripts/run-tests.sh
   ```

Vous aurez alors en une seule passe la suppression des anciens pods, la vérification de la connectivité interne et via Services, le montage des ConfigMaps, la validation des logs N11/PFCP, et enfin un test de résilience AMF post-failover.

