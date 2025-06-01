Pour diagnostiquer rapidement pourquoi ni `free5gc/amf:v3.0.11` ni `ghcr.io/orange-opensource/free5gc-amf:v3.0.6` ne fonctionnent, puis trouver une combinaison qui démarre, voici une serie d’étapes concrètes :

---

## 1. Pourquoi les deux premières combinaisons ont échoué

1. **`free5gc/amf:v3.0.11` (et équivalents SMF/UPF) : Erreur “not found”**

   ```
   Failed to pull image "free5gc/amf:v3.0.11": failed to resolve reference "docker.io/free5gc/amf:v3.0.11": manifest unknown: manifest unknown
   ```

   → Le tag `v3.0.11` **n’existe pas** sur Docker Hub. Les images officielles `free5gc/amf` n’ont pas ce tag.

2. **`ghcr.io/orange-opensource/free5gc-amf:v3.0.6` (et SMF/UPF) : Erreur 403 Forbidden**

   ```
   failed to pull and unpack image "ghcr.io/orange-opensource/free5gc-amf:v3.0.6": failed to fetch anonymous token: unexpected status from GET request to https://ghcr.io/token?scope=repository%3Aorange-opensource%2Ffree5gc-amf%3Apull&service=ghcr.io: 403 Forbidden
   ```

   → Les images Orange sur GitHub Container Registry **sont privées** ou nécessitent une authentification (token). Impossible de les “docker pull” directement sans disposer d’un secret GHCR.

---

## 2. Choisir des images publiques valides

Je vous propose d’essayer **directement les tags “latest”** (ou les versions antérieures existantes) sur Docker Hub. Les trois images officielles “free5gc” sur Docker Hub sont :

* `free5gc/amf`
* `free5gc/smf`
* `free5gc/upf`

Elles ont au moins un tag `latest`, et souvent des tags `v3.0.10`, `v3.0.9`, etc.
Nous allons tester, dans l’ordre :

1. `free5gc/amf:latest` – `free5gc/smf:latest` – `free5gc/upf:latest`
2. `free5gc/amf:v3.0.10` – `free5gc/smf:v3.0.10` – `free5gc/upf:v3.0.10`
3. `free5gc/amf:v3.0.9` –  `free5gc/smf:v3.0.9` –  `free5gc/upf:v3.0.9`

Dès qu’une combinaison fait passer les 3 pods en `Running`, nous validerons ces tags et les fixerons dans `values.yaml`.

---

## 3. Procédure pas à pas pour tester chaque combinaison

À chaque essai :

1. **Désinstaller** la release existante
2. **Installer** le chart en surchargeant les trois images (AMF, SMF, UPF)
3. **Attendre** 15–20 s que les pods tentent de démarrer
4. **Vérifier** l’état (`kubectl get pods`)
5. Si tout est en `Running`, on garde cette combinaison et on met à jour `values.yaml`. Autrement, on passe à la combinaison suivante.

### 3.1 Préparez-vous dans le dossier du chart minimal

```bash
cd ~/Kubernetes_5GC_Project-main/5GC\ minimal
```

Assurez-vous d’avoir bien dans `values.yaml` au minimum :

```yaml
imagePullPolicy: IfNotPresent

images:
  amf:
    repository: free5gc/amf
    tag: latest       # on écrase ce champ par --set
  smf:
    repository: free5gc/smf
    tag: latest       # on écrase ce champ par --set
  upf:
    repository: free5gc/upf
    tag: latest       # on écrase ce champ par --set
```

Et dans **templates/deployment-\*.yaml**, juste après `image: …`, avoir :

```yaml
imagePullPolicy: {{ .Values.imagePullPolicy }}
```

### 3.2 Combinaison 1 : `latest`

```bash
# 1) Désinstallez la release existante, s’il y en a une
helm uninstall minimal5gc --namespace default || true

# 2) Installez en surchargeant sur “latest”
helm install minimal5gc . \
  --set imagePullPolicy=IfNotPresent \
  --set images.amf.repository=free5gc/amf \
  --set images.amf.tag=latest \
  --set images.smf.repository=free5gc/smf \
  --set images.smf.tag=latest \
  --set images.upf.repository=free5gc/upf \
  --set images.upf.tag=latest

# 3) Attendez 20 s pour laisser le temps aux pods de se tirer et d'essayer de démarrer
sleep 20

# 4) Vérifiez l’état des pods
kubectl get pods
```

* Si vous obtenez **trois pods en `Running`**, c’est gagné :

  ```
  NAME                                     READY   STATUS    RESTARTS   AGE
  minimal5gc-minimal5gc-amf-xxxxx          1/1    Running    0        30s
  minimal5gc-minimal5gc-smf-xxxxx          1/1    Running    0        30s
  minimal5gc-minimal5gc-upf-xxxxx          1/1    Running    0        30s
  ```

  → Alors fixez “latest” dans votre `values.yaml` et sortez du processus de tests.
* Sinon, notez l’erreur (par ex. `ErrImagePull` ou `CrashLoopBackOff`), puis passez à la combinaison suivante :

```bash
helm uninstall minimal5gc --namespace default
```

### 3.3 Combinaison 2 : `v3.0.10`

*(Il se peut que Docker Hub héberge `v3.0.10`. Si ce tag n’existe pas non plus, vous pourrez voir `ErrImagePull` et passer à la combinaison 3.)*

```bash
helm install minimal5gc . \
  --set imagePullPolicy=IfNotPresent \
  --set images.amf.repository=free5gc/amf \
  --set images.amf.tag=v3.0.10 \
  --set images.smf.repository=free5gc/smf \
  --set images.smf.tag=v3.0.10 \
  --set images.upf.repository=free5gc/upf \
  --set images.upf.tag=v3.0.10

sleep 20
kubectl get pods
# Si Running → on garde v3.0.10
# Sinon → helm uninstall minimal5gc, puis essai suivant
helm uninstall minimal5gc --namespace default
```

### 3.4 Combinaison 3 : `v3.0.9`

*(De même, on tente avec le tag `v3.0.9`. Si ça n’existe pas, on aura ErrImagePull → on passe.)*

```bash
helm install minimal5gc . \
  --set imagePullPolicy=IfNotPresent \
  --set images.amf.repository=free5gc/amf \
  --set images.amf.tag=v3.0.9 \
  --set images.smf.repository=free5gc/smf \
  --set images.smf.tag=v3.0.9 \
  --set images.upf.repository=free5gc/upf \
  --set images.upf.tag=v3.0.9

sleep 20
kubectl get pods
# Si Running → on garde v3.0.9
# Sinon → on passe à une autre source d’images
helm uninstall minimal5gc --namespace default
```

---

## 4. Si aucune de ces trois versions n’est disponible

Il arrive que Docker Hub ne publie que le tag `latest` (sans version numérotée) ou qu’il ait fait le ménage dans les anciens tags. Si `latest`, `v3.0.10` et `v3.0.9` ne donnent rien, essayez plutôt les deux combinaisons suivantes :

* **Combinaison 4 : versions `v3.0.8`**

  ```bash
  helm install minimal5gc . \
    --set imagePullPolicy=IfNotPresent \
    --set images.amf.repository=free5gc/amf \
    --set images.amf.tag=v3.0.8 \
    --set images.smf.repository=free5gc/smf \
    --set images.smf.tag=v3.0.8 \
    --set images.upf.repository=free5gc/upf \
    --set images.upf.tag=v3.0.8

  sleep 20
  kubectl get pods
  helm uninstall minimal5gc --namespace default
  ```
* **Combinaison 5 : versions `v3.0.7`**

  ```bash
  helm install minimal5gc . \
    --set imagePullPolicy=IfNotPresent \
    --set images.amf.repository=free5gc/amf \
    --set images.amf.tag=v3.0.7 \
    --set images.smf.repository=free5gc/smf \
    --set images.smf.tag=v3.0.7 \
    --set images.upf.repository=free5gc/upf \
    --set images.upf.tag=v3.0.7

  sleep 20
  kubectl get pods
  helm uninstall minimal5gc --namespace default
  ```

En général, au moins **une** de ces variantes (`latest`, `v3.0.10`, `v3.0.9`, `v3.0.8`, `v3.0.7`) finit par permettre au pod d’atteindre `Running`.

---

## 5. Exemple complet de script bash de test

Pour automatiser la séquence, créez un fichier `test_images.sh` dans `5GC minimal/` :

```bash
#!/usr/bin/env bash
set -e

# Tableau de combinaisons “repo:tag” à tester dans l’ordre
COMBOS=(
  "free5gc/amf:latest free5gc/smf:latest free5gc/upf:latest"
  "free5gc/amf:v3.0.10 free5gc/smf:v3.0.10 free5gc/upf:v3.0.10"
  "free5gc/amf:v3.0.9 free5gc/smf:v3.0.9 free5gc/upf:v3.0.9"
  "free5gc/amf:v3.0.8 free5gc/smf:v3.0.8 free5gc/upf:v3.0.8"
  "free5gc/amf:v3.0.7 free5gc/smf:v3.0.7 free5gc/upf:v3.0.7"
)

for combo in "${COMBOS[@]}"; do
  # Découper la chaîne “repo:tag” pour chaque NF
  read -r AMF_FULL SMF_FULL UPF_FULL <<<"$combo"
  AMF_REPO="${AMF_FULL%%:*}"
  AMF_TAG="${AMF_FULL##*:}"
  SMF_REPO="${SMF_FULL%%:*}"
  SMF_TAG="${SMF_FULL##*:}"
  UPF_REPO="${UPF_FULL%%:*}"
  UPF_TAG="${UPF_FULL##*:}"

  echo
  echo "============================================"
  echo " Test des images :"
  echo "   AMF → $AMF_REPO:$AMF_TAG"
  echo "   SMF → $SMF_REPO:$SMF_TAG"
  echo "   UPF → $UPF_REPO:$UPF_TAG"
  echo "--------------------------------------------"

  # 1) Désinstaller l’ancienne release (pour repartir à zéro)
  helm uninstall minimal5gc --namespace default || true

  # 2) Installer en surchargeant les images
  helm install minimal5gc . \
    --set imagePullPolicy=IfNotPresent \
    --set images.amf.repository="$AMF_REPO" \
    --set images.amf.tag="$AMF_TAG" \
    --set images.smf.repository="$SMF_REPO" \
    --set images.smf.tag="$SMF_TAG" \
    --set images.upf.repository="$UPF_REPO" \
    --set images.upf.tag="$UPF_TAG"

  # 3) Attendre que les pods démarrent
  echo "→ En attente de 20 s pour le pull et le démarrage des pods..."
  sleep 20

  # 4) Afficher l’état des pods
  kubectl get pods
  
  # 5) Vérifier si tous les pods sont en Running
  ALL_RUNNING=true
  for nf in amf smf upf; do
    pod_name=$(kubectl get pods -l app=minimal5gc-minimal5gc-$nf -o jsonpath='{.items[0].status.phase}')
    if [[ "$pod_name" != "Running" ]]; then
      ALL_RUNNING=false
    fi
  done

  if $ALL_RUNNING; then
    echo
    echo "→ Succès : Tous les pods (AMF, SMF, UPF) sont en Running avec les images $combo"
    echo "→ Copiez ces trois lignes dans values.yaml :"
    echo "    images:"
    echo "      amf:"
    echo "        repository: $AMF_REPO"
    echo "        tag: $AMF_TAG"
    echo "      smf:"
    echo "        repository: $SMF_REPO"
    echo "        tag: $SMF_TAG"
    echo "      upf:"
    echo "        repository: $UPF_REPO"
    echo "        tag: $UPF_TAG"
    exit 0
  else
    echo "→ Échec avec cette combinaison (au moins un pod n’est pas en Running)."
    echo "  → Status détaillé :"
    kubectl get pods
    echo
    echo "→ Désinstallation pour tester la prochaine combinaison..."
    helm uninstall minimal5gc --namespace default || true
    echo
  fi
done

echo
echo "Aucune combinaison valide n’a permis d’avoir les 3 pods en Running. Vérifiez vos tags ou votre connexion Internet."
exit 1
```

1. **Sauvegardez** ce script sous `5GC minimal/test_images.sh` puis rendez-le exécutable :

   ```bash
   cd ~/Kubernetes_5GC_Project-main/5GC\ minimal
   chmod +x test_images.sh
   ```

2. **Lancez** :

   ```bash
   ./test_images.sh
   ```

* Le script va, pour chacune des 5 combinaisons (`latest`, `v3.0.10`, `v3.0.9`, `v3.0.8`, `v3.0.7`), déployer le chart, attendre 20 s, puis vérifier si les pods `amf`, `smf` et `upf` sont passés en `Running`.
* Au premier succès, il affichera la combinaison gagnante et la commande à copier dans votre `values.yaml`.
* Si aucune combinaison ne fonctionne, cela signifie soit que Docker Hub ne propose pas ces tags, soit que votre machine n’a pas accès à Internet pour les télécharger.

---

## 6. À la fin du test : fixer la combinaison dans `values.yaml`

Dès que le script (ou vos essais manuels) indique une combinaison qui fonctionne, ouvrez **`5GC minimal/values.yaml`** et remplacez la section `images:` par :

```yaml
images:
  amf:
    repository: <LE_REPO_QUI_FONCTIONNE>
    tag: <LE_TAG_QUI_FONCTIONNE>
  smf:
    repository: <LE_REPO_QUI_FONCTIONNE>
    tag: <LE_TAG_QUI_FONCTIONNE>
  upf:
    repository: <LE_REPO_QUI_FONCTIONNE>
    tag: <LE_TAG_QUI_FONCTIONNE>
```

Par exemple, si la combinaison gagnante est :

```
free5gc/amf:v3.0.10
free5gc/smf:v3.0.10
free5gc/upf:v3.0.10
```

Alors vous mettez :

```yaml
imagePullPolicy: IfNotPresent

images:
  amf:
    repository: free5gc/amf
    tag: v3.0.10
  smf:
    repository: free5gc/smf
    tag: v3.0.10
  upf:
    repository: free5gc/upf
    tag: v3.0.10

# … reste de votre config AMF/SMF/UPF …
```

Puis relancez :

```bash
helm uninstall minimal5gc --namespace default || true
helm install minimal5gc .
kubectl get pods
```

Vous aurez alors **définitivement** les bonnes images dans `values.yaml` et vos pods resteront en `Running` à chaque nouveau `helm install`.

---

### En résumé

1. **`ErrImagePull`** avec `v3.0.11` (inexistant) et **`403 Forbidden`** avec la version Orange (`v3.0.6`) confirment que ces tags ne sont pas accessibles au public.
2. **Essayez les tags “latest” puis “v3.0.10”, “v3.0.9”**, etc. sur le repo **`free5gc/amf`, `free5gc/smf`, `free5gc/upf`**.
3. **Le petit script** `test_images.sh` dans `5GC minimal/` vous aidera à automatiser ces essais.
4. **Une fois une combinaison OK trouvée**, copiez-la dans **`values.yaml`** et déployez pour avoir vos pods **en Running** de manière pérenne.

Ainsi vous saurez exactement quelles images publiques démarrent correctement pour AMF, SMF et UPF dans votre chart minimal.
