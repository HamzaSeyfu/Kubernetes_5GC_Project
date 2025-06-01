Voici un guide détaillé pour reprendre les Dockerfiles et les charts Helm du dépôt “towards5gs-helm” **uniquement à partir du ZIP** que vous avez déjà, sans passer par Git. L’idée est de :

1. **Extraire le ZIP** au bon endroit
2. **Builder** les images Docker (AMF, SMF, UPF) à partir des Dockerfiles extraits
3. **Charger** ces images dans votre cluster Kubernetes local (k3d ou Minikube)
4. **Revenir** dans votre chart “minimal5gc” et **déployer**

Assumons que vous travaillez dans le répertoire :

```
~/Kubernetes_5GC_Project-main
```

et que le ZIP `towards5gs-helm-main.zip` s’y trouve (ou est accessible depuis `/mnt/data`).

---

### 1. Se placer dans le bon dossier et extraire le ZIP

1. Ouvrez un terminal, puis positionnez‐vous à la racine de votre projet :

   ```bash
   cd ~/Kubernetes_5GC_Project-main
   ```
2. Vérifiez que le fichier ZIP est bien présent (par exemple si vous l’avez uploadé, il devrait apparaître ici) :

   ```bash
   ls
   # Vous devez voir : 5GC minimal/   towards5gs-helm-main.zip   (et éventuellement d’autres dossiers)
   ```
3. Créez un dossier "upstream" qui accueillera le contenu du ZIP, puis extrayez-le :

   ```bash
   mkdir upstream
   unzip towards5gs-helm-main.zip -d upstream
   ```

   * Le `-d upstream` demande à `unzip` de placer tous les fichiers dans le sous‐répertoire `upstream/`.
   * Après cette commande, vous devriez avoir :

     ```
     ~/Kubernetes_5GC_Project-main/
     ├── 5GC minimal/
     ├── towards5gs-helm-main.zip
     └── upstream/
         └── towards5gs-helm-main/
             ├── charts/
             ├── docker/
             ├── docs/
             ├── .github/
             ├── Chart.yaml
             └── (etc.)
     ```
4. Pour simplifier, renommez le dossier extrait en quelque chose de plus court (facultatif) :

   ```bash
   mv upstream/towards5gs-helm-main upstream/towards5gs-helm
   ```

   À la fin vous aurez donc :

   ```
   ~/Kubernetes_5GC_Project-main/
   ├── 5GC minimal/
   ├── upstream/
   │   └── towards5gs-helm/
   │       ├── charts/
   │       ├── docker/
   │       ├── docs/
   │       └── ...
   └── towards5gs-helm-main.zip
   ```

---

### 2. Builder vos images Docker localement

Vous allez maintenant utiliser les Dockerfiles qui se trouvent sous `upstream/towards5gs-helm/docker/free5gc/…` pour créer les trois images dont votre chart minimal dépend.

1. **Positionnez‐vous** dans le dossier `upstream/towards5gs-helm` :

   ```bash
   cd upstream/towards5gs-helm
   ```
2. Lancez la commande de build pour chaque NF :

   * **AMF**

     ```bash
     docker build \
       -t free5gc/amf:v3.0.11 \
       -f docker/free5gc/amf/Dockerfile \
       docker/free5gc/amf
     ```

     Explications :

     * `-t free5gc/amf:v3.0.11` → on taggue l’image sous `free5gc/amf:v3.0.11`.
     * `-f docker/free5gc/amf/Dockerfile` → chemin vers le Dockerfile de l’AMF.
     * `docker/free5gc/amf` → contexte de build (tout ce qu’il y a dans ce dossier sera envoyé au démon Docker).

   * **SMF**

     ```bash
     docker build \
       -t free5gc/smf:v3.0.11 \
       -f docker/free5gc/smf/Dockerfile \
       docker/free5gc/smf
     ```

   * **UPF**

     ```bash
     docker build \
       -t free5gc/upf:v3.0.11 \
       -f docker/free5gc/upf/Dockerfile \
       docker/free5gc/upf
     ```

   Si le build réussit, vous verrez des messages “Successfully built …” à la fin.

   > **Remarque** : si vous souhaitez une autre version que `v3.0.11`, adaptez le tag (`-t free5gc/amf:VOTRE_TAG`) en conséquence, tant que le Dockerfile supporte ce tag.

---

### 3. Charger les images dans votre cluster local

Selon que vous utilisez **k3d** ou **Minikube**, la méthode varie légèrement :

#### 3.1. Si vous utilisez k3d

1. Vérifiez le nom de votre cluster k3d (par exemple ici on l’a appelé `5gc` quand on l’a créé).

   ```bash
   k3d cluster list
   ```

   S’il s’appelle bien `5gc`, faites :

   ```bash
   k3d image import \
     free5gc/amf:v3.0.11 \
     free5gc/smf:v3.0.11 \
     free5gc/upf:v3.0.11 \
     -c 5gc
   ```

   Cela “copie” les trois images dans le registre interne du cluster k3d, afin que Kubernetes puisse les utiliser sans tenter de les télécharger depuis Docker Hub.

#### 3.2. Si vous utilisez Minikube

1. Vérifiez que Minikube est démarré. Si ce n’est pas fait :

   ```bash
   minikube start
   ```
2. Chargez les images dans Minikube :

   ```bash
   minikube image load free5gc/amf:v3.0.11
   minikube image load free5gc/smf:v3.0.11
   minikube image load free5gc/upf:v3.0.11
   ```

   Ces commandes transfèrent vos images Docker locales dans le registre interne de Minikube.

---

### 4. Configurer votre chart minimal pour pointer vers ces images

1. Revenez dans le dossier de votre chart `minimal5gc`. Par exemple, si vous étiez dans `upstream/towards5gs-helm`, remontez :

   ```bash
   cd ~/Kubernetes_5GC_Project-main/5GC\ minimal
   ```

2. Ouvrez le fichier `values.yaml` et vérifiez que la section `images:` est bien configurée comme suit :

   ```yaml
   # values.yaml de minimal5gc

   imagePullPolicy: IfNotPresent

   images:
     amf:
       repository: free5gc/amf
       tag: v3.0.11
     smf:
       repository: free5gc/smf
       tag: v3.0.11
     upf:
       repository: free5gc/upf
       tag: v3.0.11

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
         # (ajoutez ici si besoin la config PFCP/GTP)
       }
   ```

   * **Important** : on appelle les images `free5gc/amf:v3.0.11`, etc., exactement comme vous venez de les builder.
   * La directive `imagePullPolicy: IfNotPresent` garantit que Kubernetes ne va pas tenter de les télécharger d’un registry externe si elles sont déjà présentes localement.

3. Pour chaque template de déploiement (déjà créé précédemment : `deployment-amf.yaml`, `deployment-smf.yaml`, `deployment-upf.yaml`), assurez-vous d’avoir bien la ligne :

   ```yaml
   imagePullPolicy: {{ .Values.imagePullPolicy }}
   ```

   juste après `image: …`, par exemple :

   ```yaml
   containers:
     - name: amf
       image: "{{ .Values.images.amf.repository }}:{{ .Values.images.amf.tag }}"
       imagePullPolicy: {{ .Values.imagePullPolicy }}
       ports:
         - containerPort: {{ .Values.amf.port }}
       volumeMounts:
         - name: amf-config
           mountPath: /free5gc/config
   ```

   Idem dans les fichiers `deployment-smf.yaml` et `deployment-upf.yaml`.

---

### 5. Déployer (ou redéployer) votre chart minimal5gc

1. Si vous avez déjà une release `minimal5gc` installée, désinstallez-la pour repartir à zéro :

   ```bash
   helm uninstall minimal5gc || true
   ```

2. Depuis le dossier `5GC minimal/`, relancez un lint pour vérifier qu’il n’y a plus d’erreur :

   ```bash
   helm lint .
   ```

   Vous devriez seulement voir des warnings (ex. “icon is recommended”), mais **aucune erreur**.

3. Installez le chart :

   ```bash
   helm install minimal5gc .
   ```

4. Vérifiez immédiatement l’état des pods :

   ```bash
   kubectl get pods
   ```

   – Les trois pods `minimal5gc-minimal5gc-amf-xxxxx`, `minimal5gc-minimal5gc-smf-xxxxx` et `minimal5gc-minimal5gc-upf-xxxxx` devraient passer en **Running** en quelques secondes.
   – Si vous voyez encore `ErrImagePull`, c’est que Kubernetes ne trouve pas l’image. Dans ce cas, repassez en revue les étapes 2 et 3 pour vous assurer que vous avez bien :

   * Builde vos images `free5gc/amf:v3.0.11` (et SMF/UPF) depuis le dossier `upstream/towards5gs-helm/docker/...`.
   * Importé ces images dans votre cluster k3d ou Minikube.
   * Vérifié que `values.yaml` pointe bien sur `free5gc/amf:v3.0.11` (et non sur `latest` ou sur un tag erroné).

5. Pour vous assurer que l’AMF fonctionne, récupérez le CLUSTER IP du service AMF et testez l’API SBI :

   ```bash
   AMF_IP=$(kubectl get svc minimal5gc-amf -o jsonpath='{.spec.clusterIP}')
   curl http://$AMF_IP:7777/nnrf-nfm/v1/nf-instances
   ```

   Vous devriez voir un petit JSON listant l’instance AMF enregistrée.

6. Pareil pour le SMF (pour vérifier qu’il a bien démarré, même s’il n’a rien à renvoyer immédiatement). Exemple :

   ```bash
   SMF_IP=$(kubectl get svc minimal5gc-smf -o jsonpath='{.spec.clusterIP}')
   curl http://$SMF_IP:7778/nnrf-nfm/v1/nf-instances
   ```

---

## Récapitulatif des commandes

En une suite d’actions séquentielles, on a :

```bash
# 1) Se placer à la racine du projet
cd ~/Kubernetes_5GC_Project-main

# 2) Créer et extraire le ZIP dans "upstream"
mkdir upstream
unzip towards5gs-helm-main.zip -d upstream
mv upstream/towards5gs-helm-main upstream/towards5gs-helm

# 3) Builder les images depuis le dossier extrait
cd upstream/towards5gs-helm

# AMF
docker build -t free5gc/amf:v3.0.11 \
  -f docker/free5gc/amf/Dockerfile \
  docker/free5gc/amf

# SMF
docker build -t free5gc/smf:v3.0.11 \
  -f docker/free5gc/smf/Dockerfile \
  docker/free5gc/smf

# UPF
docker build -t free5gc/upf:v3.0.11 \
  -f docker/free5gc/upf/Dockerfile \
  docker/free5gc/upf

# 4) Charger les images dans k3d ou Minikube
# Si vous utilisez k3d (cluster nommé "5gc")
k3d image import free5gc/amf:v3.0.11 free5gc/smf:v3.0.11 free5gc/upf:v3.0.11 -c 5gc

# Si vous utilisez Minikube
# minikube image load free5gc/amf:v3.0.11
# minikube image load free5gc/smf:v3.0.11
# minikube image load free5gc/upf:v3.0.11

# 5) Revenir dans votre chart minimal5gc
cd ../../5GC\ minimal

# 6) Ajuster values.yaml pour pointer vers free5gc/amf:v3.0.11, etc.
#    (vérifiez que imagePullPolicy: IfNotPresent est bien présent)

# 7) Désinstaller d’éventuelles anciennes releases puis déployer
helm uninstall minimal5gc || true
helm lint .
helm install minimal5gc .

# 8) Vérifier les pods et tester l’API
kubectl get pods
kubectl get svc

# Exemple de test SBI sur l’AMF
AMF_IP=$(kubectl get svc minimal5gc-amf -o jsonpath='{.spec.clusterIP}')
curl http://$AMF_IP:7777/nnrf-nfm/v1/nf-instances
```

Si vous suivez scrupuleusement ces étapes, vous aurez :

* **Vos propres images** `free5gc/amf:v3.0.11`, `free5gc/smf:v3.0.11`, `free5gc/upf:v3.0.11` construites à partir des Dockerfiles du ZIP.
* Ces images disponibles dans votre cluster Kubernetes local (pas d’erreur `ErrImagePull`).
* Un déploiement Helm “minimal5gc” qui démarre les pods AMF, SMF et UPF en **Running**.

> **Note** : si vous n’avez pas k3d ni Minikube, mais un autre type de cluster local (Docker Desktop Kubernetes, Kind…), adaptez simplement la commande d’import (`k3d image import` ↔ `minikube image load` ↔ `kind load docker-image`).

N’hésitez pas à copier-coller les commandes une par une, et à vérifier après chaque étape (`ls`, `docker images`, `kubectl get pods`) que tout correspond bien à ce qui est attendu.
