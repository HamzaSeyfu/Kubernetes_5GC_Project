Voici une méthode simple pour **itérer rapidement** sur plusieurs images publiques d’AMF, SMF et UPF, afin de repérer celles qui démarrent correctement dans votre chart minimal5gc. L’idée est :

1. **Lister quelques candidats d’images officielles ou couramment utilisées**
2. **Déployer rapidement le chart en surchargeant à la volée les champs `images.*.repository` et `images.*.tag`**
3. **Vérifier si chaque pod (AMF/SMF/UPF) passe en `Running`**
4. **Choisir la combinaison qui fonctionne, puis la fixer définitivement dans `values.yaml`**

---

## 1. Quelques images publiques à tester

En général, on trouve deux familles principales d’images pour Free5GC (ou implémentations 5G Core) :

1. **Images “Free5GC” officielles sur Docker Hub**

   * `free5gc/amf`
   * `free5gc/smf`
   * `free5gc/upf`
   * Tags souvent du type `v3.0.11`, `v3.0.10` ou `latest`

2. **Images packagées par Orange sur GitHub Container Registry**

   * `ghcr.io/orange-opensource/free5gc-amf`
   * `ghcr.io/orange-opensource/free5gc-smf`
   * `ghcr.io/orange-opensource/free5gc-upf`
   * Tags souvent du type `v3.0.6`, `v3.0.7`, etc.

3. **(Éventuellement) autres forks ou builds communautaires**

   * Par exemple : `mfazza/5gc-amf` ou `zlaczed/5gc-smf` (ces noms sont hypothétiques – si vous trouvez un fork GitHub d’une équipe tierce, vous pouvez l’essayer).
   * Dans la suite je vais surtout illustrer avec les deux premières familles.

---

## 2. Procédure pas à pas pour tester en CLI

Pour chaque ensemble d’images (AMF+SMF+UPF), vous allez :

1. **Désinstaller** d’éventuelles releases existantes
2. **Lancer** le chart en surchargeant la partie `images.*`
3. **Attendre 20-30 s** que Kubernetes tire les images et crée les pods
4. **Vérifier** l’état des pods (et leurs logs si nécessaire)
5. **Noter** si les trois pods se mettent en `Running` (et restent stables) ou s’il y a une `CrashLoopBackOff` / `ErrImagePull` / autre
6. **Désinstaller** avant de passer à la combi suivante

### 2.1 Exemple de commande générique

Puisque vous avez déjà un dossier `5GC minimal/` avec `Chart.yaml` + `values.yaml` (sans affecter la partie `images:`), on fera par exemple :

```bash
cd ~/Kubernetes_5GC_Project-main/5GC\ minimal

# (1) Désinstaller l’ancienne release, s’il en existait une
helm uninstall minimal5gc --namespace default || true

# (2) Installer en surchargeant les images pour AMF, SMF et UPF
helm install minimal5gc . \
  --set imagePullPolicy=IfNotPresent \
  --set images.amf.repository=<AMF_REPO> \
  --set images.amf.tag=<AMF_TAG> \
  --set images.smf.repository=<SMF_REPO> \
  --set images.smf.tag=<SMF_TAG> \
  --set images.upf.repository=<UPF_REPO> \
  --set images.upf.tag=<UPF_TAG>
```

* Remplacez `<AMF_REPO>`, `<AMF_TAG>`, etc. par les images que vous voulez tester.
* L’argument `--set imagePullPolicy=IfNotPresent` garantit qu’on n’essaiera pas de télécharger une image absente si vous avez déjà implanté une version locale.

### 2.2 Combinaisons à essayer dans l’ordre

Ci-dessous, un tableau de 4 combinaisons courantes :

| N° | AMF                                               | SMF                                               | UPF                                               |
| -- | ------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------- |
| 1  | `free5gc/amf` `:v3.0.11`                          | `free5gc/smf` `:v3.0.11`                          | `free5gc/upf` `:v3.0.11`                          |
| 2  | `free5gc/amf` `:latest`                           | `free5gc/smf` `:latest`                           | `free5gc/upf` `:latest`                           |
| 3  | `ghcr.io/orange-opensource/free5gc-amf` `:v3.0.6` | `ghcr.io/orange-opensource/free5gc-smf` `:v3.0.6` | `ghcr.io/orange-opensource/free5gc-upf` `:v3.0.6` |
| 4  | `ghcr.io/orange-opensource/free5gc-amf` `:latest` | `ghcr.io/orange-opensource/free5gc-smf` `:latest` | `ghcr.io/orange-opensource/free5gc-upf` `:latest` |

**Important** : le tag `:latest` n’est pas toujours fiable (parfois il n’existe pas, ou correspond à une version instable). Commencez donc de préférence par la ligne 1, puis la ligne 3 (versions stables Orange). Si la ligne 1 plante (`ErrImagePull` ou `CrashLoopBackOff`), passez à la ligne 2 ou ­`3`.

---

### 2.3 Exemple concret pour la première combinaison

1. **Positionnez-vous** dans le dossier `5GC minimal/` puis lancez :

   ```bash
   cd ~/Kubernetes_5GC_Project-main/5GC\ minimal
   helm uninstall minimal5gc --namespace default || true

   helm install minimal5gc . \
     --set imagePullPolicy=IfNotPresent \
     --set images.amf.repository=free5gc/amf \
     --set images.amf.tag=v3.0.11 \
     --set images.smf.repository=free5gc/smf \
     --set images.smf.tag=v3.0.11 \
     --set images.upf.repository=free5gc/upf \
     --set images.upf.tag=v3.0.11
   ```

2. **Patienter 15 s**, puis vérifiez :

   ```bash
   kubectl get pods
   ```

   * Si vous voyez

     ```
     minimal5gc-minimal5gc-amf-xxxxx   1/1   Running   0   25s
     minimal5gc-minimal5gc-smf-xxxxx   1/1   Running   0   25s
     minimal5gc-minimal5gc-upf-xxxxx   1/1   Running   0   25s
     ```

     alors **bravo**, cette combinaison fonctionne : gardez ces valeurs dans votre `values.yaml`.
   * Si vous voyez `ErrImagePull` ou `ImagePullBackOff`, alors soit le tag n’existe pas, soit le repo n’est pas public. Dans ce cas, appuyez sur **Ctrl +C** (pour stopper toute attente) et passez à la combinaison suivante.

3. Pour diagnostiquer (si l’un des pods ne démarre pas) :

   ```bash
   # Décrire un pod pour voir la raison exacte
   kubectl describe pod minimal5gc-minimal5gc-amf-xxxxx
   # ou lire les logs (exemple pour AMF)
   kubectl logs deploy/minimal5gc-amf
   ```

   * Recherche : `Failed to pull image ...` → repository/tag incorrect
   * Ou `CrashLoopBackOff` → l’image est tirée, mais le binaire à l’intérieur plante (par exemple, configuration incomplète ou binaire incompatible)

4. **Désinstallez** avant d’essayer la combi suivante :

   ```bash
   helm uninstall minimal5gc --namespace default
   ```

---

### 2.4 Tester les autres combinaisons

Réitérez exactement la même procédure pour les lignes 2, 3 et 4 du tableau. Par exemple, pour la ligne 3 (Orange v3.0.6) :

```bash
cd ~/Kubernetes_5GC_Project-main/5GC\ minimal
helm uninstall minimal5gc --namespace default || true

helm install minimal5gc . \
  --set imagePullPolicy=IfNotPresent \
  --set images.amf.repository=ghcr.io/orange-opensource/free5gc-amf \
  --set images.amf.tag=v3.0.6 \
  --set images.smf.repository=ghcr.io/orange-opensource/free5gc-smf \
  --set images.smf.tag=v3.0.6 \
  --set images.upf.repository=ghcr.io/orange-opensource/free5gc-upf \
  --set images.upf.tag=v3.0.6

kubectl get pods
```

* **Si** les trois pods passent en `Running` → vous retenez cette combinaison (orange-opensource v3.0.6).
* **Sinon** → notez l’erreur, puis désinstallez et testez la ligne 4 (Orange\:latest), etc.

---

## 3. Une fois la bonne combinaison trouvée, fixez-la dans `values.yaml`

Imaginons que **seule la ligne 3 (Orange v3.0.6) fonctionne** (AMF, SMF et UPF passent en `Running`). Alors modifiez **définitivement** votre `5GC minimal/values.yaml` comme suit :

```yaml
# values.yaml (mise à jour définitive)

imagePullPolicy: IfNotPresent

images:
  amf:
    repository: ghcr.io/orange-opensource/free5gc-amf
    tag: v3.0.6
  smf:
    repository: ghcr.io/orange-opensource/free5gc-smf
    tag: v3.0.6
  upf:
    repository: ghcr.io/orange-opensource/free5gc-upf
    tag: v3.0.6

# AMF configuration
amf:
  replicaCount: 1
  port: 7777
  config: |
    {
      "sbi": { "scheme": "http", "ipv4": "0.0.0.0", "port": 7777 },
      "smf": { "address": "{{ include \"minimal5gc.fullname\" . }}-smf", "port": 7778 }
    }

# SMF configuration
smf:
  replicaCount: 1
  port: 7778
  config: |
    {
      "sbi": { "scheme": "http", "ipv4": "0.0.0.0", "port": 7778 },
      "amf": { "address": "{{ include \"minimal5gc.fullname\" . }}-amf", "port": 7777 },
      "upf": { "address": "{{ include \"minimal5gc.fullname\" . }}-upf", "port": 8805 }
    }

# UPF configuration
upf:
  replicaCount: 1
  port: 8805
  config: |
    {
      "sbi": { "scheme": "http", "ipv4": "0.0.0.0", "port": 8805 }
      # (ajoutez ici PFCP/GTP si nécessaire)
    }
```

* Enregistrez le fichier.
* Ensuite, pour être sûr que votre cluster est à jour :

  ```bash
  helm uninstall minimal5gc || true
  helm install minimal5gc .
  kubectl get pods
  ```

Vous verrez alors à chaque `helm install` que Kubernetes utilise les images Orange v3.0.6, sans jamais re­surcharger un tag qui pointe sur `latest`.

---

## 4. Récapitulatif (script simplifié)

Si vous voulez automatiser ce test (à lancer à la main chaque fois), vous pouvez même créer un petit script bash dans `5GC minimal/` :

```bash
#!/usr/bin/env bash
set -e

declare -A AMF_IMAGES=(
  ["free5gc/amf"]="v3.0.11"
  ["free5gc/amf"]="latest"
  ["ghcr.io/orange-opensource/free5gc-amf"]="v3.0.6"
  ["ghcr.io/orange-opensource/free5gc-amf"]="latest"
)
declare -A SMF_IMAGES=(
  ["free5gc/smf"]="v3.0.11"
  ["free5gc/smf"]="latest"
  ["ghcr.io/orange-opensource/free5gc-smf"]="v3.0.6"
  ["ghcr.io/orange-opensource/free5gc-smf"]="latest"
)
declare -A UPF_IMAGES=(
  ["free5gc/upf"]="v3.0.11"
  ["free5gc/upf"]="latest"
  ["ghcr.io/orange-opensource/free5gc-upf"]="v3.0.6"
  ["ghcr.io/orange-opensource/free5gc-upf"]="latest"
)

# Liste ordonnée de combinaisons à tester
COMBOS=(
  "free5gc/amf:v3.0.11 free5gc/smf:v3.0.11 free5gc/upf:v3.0.11"
  "free5gc/amf:latest free5gc/smf:latest free5gc/upf:latest"
  "ghcr.io/orange-opensource/free5gc-amf:v3.0.6 ghcr.io/orange-opensource/free5gc-smf:v3.0.6 ghcr.io/orange-opensource/free5gc-upf:v3.0.6"
  "ghcr.io/orange-opensource/free5gc-amf:latest ghcr.io/orange-opensource/free5gc-smf:latest ghcr.io/orange-opensource/free5gc-upf:latest"
)

for combo in "${COMBOS[@]}"; do
  read -r AMF_IMG SMF_IMG UPF_IMG <<<"$combo"
  echo "==== Test de $AMF_IMG / $SMF_IMG / $UPF_IMG ===="

  helm uninstall minimal5gc --namespace default || true

  helm install minimal5gc . \
    --set imagePullPolicy=IfNotPresent \
    --set images.amf.repository="${AMF_IMG%%:*}" \
    --set images.amf.tag="${AMF_IMG##*:}" \
    --set images.smf.repository="${SMF_IMG%%:*}" \
    --set images.smf.tag="${SMF_IMG##*:}" \
    --set images.upf.repository="${UPF_IMG%%:*}" \
    --set images.upf.tag="${UPF_IMG##*:}"

  echo "→ Attente 20 s pour que les pods démarrent…"
  sleep 20

  kubectl get pods
  echo

  echo "→ Lire les logs pour vérifier le démarrage :"
  echo "  AMF logs : kubectl logs deploy/minimal5gc-amf"
  echo "  SMF logs : kubectl logs deploy/minimal5gc-smf"
  echo "  UPF logs : kubectl logs deploy/minimal5gc-upf"
  echo
  echo "------------------------------------------------------"
  echo
done

echo "Tests terminés. Choisissez la combinaison qui fonctionne et ajustez votre values.yaml."
```

* Sauvegardez ce script sous `5GC minimal/test_images.sh`, puis :

  ```bash
  chmod +x test_images.sh
  ./test_images.sh
  ```
* Il va itérer sur chaque combinaison, déployer, attendre 20 s, afficher l’état des pods et proposer les logs pour vous laisser vérifier si chaque pod est stable.

---

### 5. Conclusion

1. **Choisissez la combinaison (AMF/SMF/UPF) qui met les 3 pods en `Running` sans `ErrImagePull` ni `CrashLoopBackOff`.**
2. **Copiez-collez ces trois lignes dans votre `values.yaml`** pour verrouiller définitivement ces images :

   ```yaml
   images:
     amf:
       repository: <LA_COMBINAISON_AMF_REPO>
       tag: <LE_TAG_QUI_FONCTIONNE>
     smf:
       repository: <LA_COMBINAISON_SMF_REPO>
       tag: <LE_TAG_QUI_FONCTIONNE>
     upf:
       repository: <LA_COMBINAISON_UPF_REPO>
       tag: <LE_TAG_QUI_FONCTIONNE>
   ```
3. **Relancez ensuite** un `helm uninstall minimal5gc && helm install minimal5gc .` pour vous assurer que tout est stable.

Avec cette démarche, vous aurez testé **rapidement** plusieurs images publiques, choisi celle qui fonctionne dans votre environnement Kind, et mis à jour votre chart minimal5gc en conséquence.
