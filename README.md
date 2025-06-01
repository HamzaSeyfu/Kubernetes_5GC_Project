# Kubernetes_5GC_Project

Parfait. Voici **toutes les commandes concrètes** et **manipulations détaillées** pour **mettre en place un environnement local Kubernetes avec KIND**, prêt pour le déploiement de fonctions 5G Core (comme AMF, SMF, UPF), sur une machine Ubuntu 22.04+.

Cette procédure inclut : Docker, `kubectl`, KIND, et quelques vérifications essentielles.

---

## 🟦 1. Mise à jour du système

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 🐳 2. Installation de Docker

```bash
sudo apt install docker.io -y
```

Activer le service Docker au démarrage :

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Ajouter ton utilisateur au groupe Docker :

```bash
sudo usermod -aG docker $USER
newgrp docker  # (ou déconnecte/reconnecte-toi)
```

Vérifie que Docker fonctionne :

```bash
docker run hello-world
```

---

## ⚓ 3. Installation de `kubectl`

**Méthode recommandée (via Snap)** :

```bash
sudo snap install kubectl --classic
```

**Alternative manuelle (si besoin de la version exacte)** :

```bash
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

Vérifie l’installation :

```bash
kubectl version --client
```

---

## 🐋 4. Installation de KIND (Kubernetes IN Docker)

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Vérifie que KIND fonctionne :

```bash
kind --version
```

---

## 📦 5. Création du cluster Kubernetes avec KIND

### Exemple simple :

```bash
kind create cluster --name 5gc-lab
```

### Exemple avec configuration personnalisée (`kind-config.yaml`) :

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: 5gc-lab
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
```

Création avec fichier :

```bash
kind create cluster --config kind-config.yaml
```

---

## ✅ 6. Vérification du cluster

Lister les nœuds :

```bash
kubectl get nodes
```

Lister les pods (il n’y en a pas encore, mais ça teste la connectivité) :

```bash
kubectl get pods -A
```

---

## 🛠 7. (Facultatif mais conseillé) Vérifier et corriger les problèmes courants

### Problème : docker permission denied

```bash
newgrp docker
```

### Problème : KIND stuck or pods NotReady

```bash
docker ps
docker logs <container-id>
```

### Supprimer un cluster

```bash
kind delete cluster --name 5gc-lab
```

---
Très bien ! Pour **lancer tous les fichiers de configuration YAML** (namespace, configmaps, deployments…) que tu as créés **manuellement** pour ton lab 5G Core, il te suffit de suivre une séquence simple, en utilisant `kubectl apply`.

---

### ✅ Étape 0 — Se placer dans le bon dossier

Si tous tes fichiers sont dans un dossier local, par exemple `~/k8s-5gc`, place-toi dedans :

```bash
cd ~/k8s-5gc
```

---

### ✅ Étape 1 — Appliquer les fichiers dans l’ordre logique

Voici l’ordre **recommandé** (important pour éviter les erreurs) :

1. **Namespace**

   ```bash
   kubectl apply -f namespace.yaml
   ```

2. **ConfigMaps**

   ```bash
   kubectl apply -f smf-configmap.yaml
   kubectl apply -f amf-configmap.yaml
   kubectl apply -f upf-configmap.yaml
   # + autres configmaps selon ton projet
   ```

3. **Deployments**

   ```bash
   kubectl apply -f smf-deployment.yaml
   kubectl apply -f amf-deployment.yaml
   kubectl apply -f upf-deployment.yaml
   # + autres fonctions si tu en as (nrf, ausf, etc.)
   ```

4. (Optionnel) **Services**
   Si tu as des fichiers `Service`, applique-les maintenant :

   ```bash
   kubectl apply -f smf-service.yaml
   ```

---

### ✅ Étape 2 — Vérifier que tout tourne

```bash
kubectl get pods -n 5gc
```

---

### ✅ (Alternative) Tout en une seule ligne

Si tous tes fichiers `.yaml` sont dans un même dossier :

```bash
kubectl apply -f ./
```

💡 *Mais attention : s’ils ne sont pas dans l’ordre logique (ex : un Deployment qui utilise une ConfigMap pas encore créée), des erreurs peuvent survenir.*

---

Parfait. Voici **tout ce qu’il te faut pour obtenir la capture n°1** du rapport : **les logs montrant un échange PFCP (Packet Forwarding Control Protocol) entre le SMF et le UPF**.

---

## 🎯 Objectif

Capturer un log significatif depuis le pod `smf`, montrant un échange `PFCP Session Establishment Request` et `Response` avec le `UPF`.

---

## ⚙️ Pré-requis

* Ton cluster Kubernetes (KIND) est démarré et fonctionnel.
* Les pods `smf` et `upf` tournent dans le namespace `5gc`.
* La configMap `smfcfg.yaml` est bien définie avec une section `pfcp.addr` pointant vers le `UPF` (`127.0.0.8` ou équivalent).
* L'image Docker du SMF est bien celle de `towards5gs/free5gc-smf:v3.2.1` ou une version équivalente incluant les logs.

---

## ✅ Étapes complètes

### 1. 🎯 Identifier le nom du pod SMF

```bash
kubectl get pods -n 5gc
```

Tu obtiendras un nom de type :
`smf-6c6d8d6b77-wmxr9`

---

### 2. 🔍 Lire les logs du pod SMF

```bash
kubectl logs smf-6c6d8d6b77-wmxr9 -n 5gc
```

Tu peux rediriger les logs dans un fichier temporaire pour faciliter la recherche :

```bash
kubectl logs smf-6c6d8d6b77-wmxr9 -n 5gc > smf-log.txt
```

---

### 3. 🔎 Rechercher une trace PFCP dans les logs

Tu peux utiliser `grep` pour filtrer ce genre de lignes (si présentes dans le binaire) :

```bash
grep PFCP smf-log.txt
```

Sinon, fais une recherche manuelle sur des blocs comme :

```
[SMF][PFCP][INFO] Sending PFCP Session Establishment Request to Node ID: 127.0.0.8
[SMF][PFCP][INFO] Received PFCP Session Establishment Response with Cause: Request accepted
```

---

### 4. 📸 Capturer une portion propre

Lorsque tu identifies le bloc contenant ces deux lignes (Request + Response), isole-les avec quelques lignes avant/après. Exemple :

```
[SMF][INFO] New UE session initiated for IMSI-208930000000003
[SMF][PFCP][INFO] Sending PFCP Session Establishment Request to Node ID: 127.0.0.8
[SMF][PFCP][DEBUG] Request includes F-SEID, PDRs, and FARs
[SMF][PFCP][INFO] Received PFCP Session Establishment Response with Cause: Request accepted
[SMF][INFO] Session created successfully
```

L’erreur affichée est tout à fait normale et liée au confinement de sécurité propre au système Snap. Pour installer Helm correctement via Snap, tu dois simplement ajouter l’option `--classic` comme indiqué dans le message.

Voici la commande corrigée :

```bash
sudo snap install helm --classic
```

Une fois Helm installé, tu pourras reprendre normalement l’installation du projet avec les commandes suivantes :

```bash
helm repo add towards5gs https://raw.githubusercontent.com/Orange-OpenSource/towards5gs-helm/main/repo/
helm repo update
helm install free5gc-core towards5gs/free5gc -n free5gc --create-namespace
```

💡 Astuce : n'oublie pas de vérifier que Docker fonctionne bien (`sudo systemctl status docker`) et que ton cluster Kubernetes (par exemple KIND) est bien actif (`kubectl get nodes`).

L’erreur affichée est claire : **les Custom Resource Definitions (CRDs) `NetworkAttachmentDefinition` ne sont pas encore installées dans ton cluster**. Ces CRDs sont nécessaires pour les plugins réseau multus (CNI), utilisés dans le déploiement de Free5GC via Helm.

---

### ✅ Solution : Installer les CRDs de Multus

Tu dois d'abord installer **Multus CNI** (le plugin réseau secondaire), qui gère les définitions `NetworkAttachmentDefinition`.

#### Étapes à suivre :

1. **Télécharge et applique la configuration Multus officielle** :

```bash
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
```

2. **Vérifie que les pods Multus sont bien déployés** :

```bash
kubectl get pods -n kube-system | grep multus
```

Tu devrais voir un ou plusieurs pods nommés `kube-multus-ds-*` en `Running`.

3. **Réessaie l’installation du chart Helm** :

```bash
helm install free5gc-core towards5gs/free5gc -n free5gc --create-namespace
```

---

### 🔎 Pourquoi c’est important ?

Free5GC (et d’autres composants 5G CNFs) utilisent plusieurs interfaces réseau, ce qui n’est pas géré nativement par Kubernetes. C’est pourquoi **Multus** et les **NetworkAttachmentDefinitions** sont requis.

Souhaite-tu que je t’aide à valider le bon fonctionnement de Multus après installation, ou à prévisualiser les CRDs avec `kubectl get crds` ?

Parfait, ton **chart Helm** `free5gc-core` a bien été installé dans le namespace `free5gc`. Maintenant tu peux tester ton déploiement étape par étape. Voici **la liste complète des commandes utiles** pour valider le fonctionnement et observer l'état du lab :

---

### 🔍 1. Vérifier les pods déployés

```bash
kubectl get pods -n free5gc
```

Cela affichera tous les composants (AMF, SMF, UPF, NRF, etc.).

---

### 🧠 2. Identifier les services exposés

```bash
kubectl get svc -n free5gc
```

Pour voir les IPs et ports d’accès aux fonctions via SBI ou GTP.

---

### 📦 3. Inspecter un pod (ex : AMF)

```bash
kubectl describe pod <nom_du_pod> -n free5gc
```

Ou logs :

```bash
kubectl logs <nom_du_pod> -n free5gc
```

---

### 💡 4. Voir tous les CRDs déployés

```bash
kubectl get crds | grep 5gc
```

---

### 📶 5. Afficher les interfaces réseau créées (multus)

Si multus est bien utilisé :

```bash
kubectl get net-attach-def -n free5gc
```

---

### 🔁 6. Relancer un pod

Exemple : redémarrer l'UPF

```bash
kubectl delete pod <nom_du_pod_upf> -n free5gc
```

---

### 🧪 7. Faire un test de connectivité (si tu as un `UE`/`gNB` simulé plus tard)

Tu pourras utiliser `iperf`, `ping` ou Wireshark dans le futur. Pour l’instant :

```bash
kubectl exec -it <pod_name> -n free5gc -- /bin/bash
```

Et à l’intérieur, tu pourras ping un autre pod.

---

Parfait. Voici une **liste étendue et structurée** de tests que tu peux réaliser pour valider un déploiement 5GC avec Helm dans Kubernetes, **sans UE réel**. On couvre ici plusieurs niveaux : **disponibilité, logs, communication inter-pod, services exposés, ressources réseau, et intégrité des fichiers YAML**.

---

## 🧪 A. TESTS DE VÉRIFICATION DE BASE (cluster et pods)

### 1. Vérifie que tous les pods sont bien `Running`

```bash
kubectl get pods -n free5gc -o wide
```

### 2. Vérifie les ressources utilisées

```bash
kubectl top pod -n free5gc
```

(tu dois avoir `metrics-server` installé)

### 3. Vérifie le nombre de redémarrages suspects

```bash
kubectl get pods -n free5gc --sort-by=.status.containerStatuses[0].restartCount
```

---

## 📂 B. TESTS SUR LES LOGS

### 4. Regarder les logs d’un pod spécifique

```bash
kubectl logs -n free5gc <nom_du_pod>
```

### 5. Logs continus pour détecter les erreurs au boot

```bash
kubectl logs -f -n free5gc <pod_amf>
```

### 6. Rechercher des erreurs dans les logs

```bash
kubectl logs -n free5gc <pod> | grep -i error
```

---

## 🌐 C. TESTS DE CONNECTIVITÉ ENTRE FONCTIONS

### 7. Accéder à un pod pour tester la résolution DNS + ping

```bash
kubectl exec -it -n free5gc <pod_amf> -- /bin/bash
ping <service_smf>
```

### 8. Vérifier la résolution DNS par CoreDNS

```bash
nslookup smf.free5gc.svc.cluster.local
```

---

## 🧰 D. TESTS DES SERVICES EXPOSÉS

### 9. Vérifie la liste des services exposés

```bash
kubectl get svc -n free5gc
```

### 10. Accède aux endpoints SBI d’un service depuis un pod

```bash
curl http://smf:8000
curl http://nrf:8000
```

---

## 🔁 E. TESTS DE LIAISONS INTER-FONCTIONS (API SBI)

### 11. Test d'enregistrement AMF -> NRF (dans les logs AMF)

Vérifie que tu retrouves ce genre de lignes dans les logs :

```
[INFO][AMF][SBI] Registered to NRF successfully
```

### 12. Vérifie que tous les services se sont enregistrés dans la base de données du NRF :

```bash
kubectl exec -it -n free5gc <pod_nrf> -- curl http://127.0.0.1:8000/nnrf-nfm/v1/nf-instances
```

---

## 🔍 F. VALIDATION DE L’INTÉGRITÉ DES CONFIGMAPS ET VOLUMES

### 13. Vérifie les fichiers montés :

```bash
kubectl exec -it -n free5gc <pod_smf> -- cat /free5gc/config/smfcfg.yaml
```

### 14. Vérifie que la configuration YAML du pod correspond bien à ce que tu veux

```bash
kubectl describe configmap smf-config -n free5gc
```

---

## 🧪 G. TESTS STRUCTURELS DE MANIFESTES

### 15. Tester la validité des fichiers YAML localement (sans déployer)

```bash
kubectl apply --dry-run=client -f amf-deployment.yaml
```

### 16. Lint des Helm charts (si tu les modifies)

```bash
helm lint ./chart/
```

---

## 💻 H. TESTS D’INTERFACES RÉSEAU ET MULTUS (si installé)

### 17. Vérifie la présence de définitions Multus (NetworkAttachmentDefinition)

```bash
kubectl get net-attach-def -A
```

---

## 🔐 I. TESTS TLS ET SBI

### 18. Liste les certificats présents dans les conteneurs (si tu as configuré TLS)

```bash
kubectl exec -it -n free5gc <pod> -- ls /etc/free5gc/tls
```

---

## 🛠️ J. SIMULATION (si tu ajoutes les simulateurs plus tard)

* Si tu déploies `UERANSIM` ou `gNBsim`, tu pourras :

  * Lancer une session UE → SMF
  * Capturer le GTP-U via `tcpdump`
  * Tester la QoS avec `iperf3`

---


























## Chart Structure: minimal5gc

```bash
minimal5gc/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment-amf.yaml
    ├── service-amf.yaml
    ├── configmap-amf.yaml
    ├── deployment-smf.yaml
    ├── service-smf.yaml
    ├── configmap-smf.yaml
    ├── deployment-upf.yaml
    ├── service-upf.yaml
    └── configmap-upf.yaml
```

---

### Chart.yaml

```yaml
apiVersion: v2
name: minimal5gc
description: "Helm chart minimal pour un cœur 5G minimal (AMF, SMF, UPF)"
version: 0.1.0
appVersion: "v1.0.0"
```

---

### values.yaml

```yaml
# images
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
      # add PFCP, GTP configurations as needed
    }
```

---

### templates/deployment-amf.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "minimal5gc.fullname" . }}-amf
spec:
  replicas: {{ .Values.amf.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "minimal5gc.fullname" . }}-amf
  template:
    metadata:
      labels:
        app: {{ include "minimal5gc.fullname" . }}-amf
    spec:
      containers:
        - name: amf
          image: "{{ .Values.images.amf.repository }}:{{ .Values.images.amf.tag }}"
          ports:
            - containerPort: {{ .Values.amf.port }}
          volumeMounts:
            - name: amf-config
              mountPath: /free5gc/config
      volumes:
        - name: amf-config
          configMap:
            name: {{ include "minimal5gc.fullname" . }}-amf-config
```

---

### templates/service-amf.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "minimal5gc.fullname" . }}-amf
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.amf.port }}
      targetPort: {{ .Values.amf.port }}
      name: http
  selector:
    app: {{ include "minimal5gc.fullname" . }}-amf
```

---

### templates/configmap-amf.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "minimal5gc.fullname" . }}-amf-config
data:
  amf.json: |-
{{ .Values.amf.config | indent 4 }}
```

---

### templates/deployment-smf.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "minimal5gc.fullname" . }}-smf
spec:
  replicas: {{ .Values.smf.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "minimal5gc.fullname" . }}-smf
  template:
    metadata:
      labels:
        app: {{ include "minimal5gc.fullname" . }}-smf
    spec:
      containers:
        - name: smf
          image: "{{ .Values.images.smf.repository }}:{{ .Values.images.smf.tag }}"
          ports:
            - containerPort: {{ .Values.smf.port }}
          volumeMounts:
            - name: smf-config
              mountPath: /free5gc/config
      volumes:
        - name: smf-config
          configMap:
            name: {{ include "minimal5gc.fullname" . }}-smf-config
```

### templates/service-smf.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "minimal5gc.fullname" . }}-smf
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.smf.port }}
      targetPort: {{ .Values.smf.port }}
      name: http
  selector:
    app: {{ include "minimal5gc.fullname" . }}-smf
```

### templates/configmap-smf.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "minimal5gc.fullname" . }}-smf-config
data:
  smf.json: |-
{{ .Values.smf.config | indent 4 }}
```

### templates/deployment-upf.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "minimal5gc.fullname" . }}-upf
spec:
  replicas: {{ .Values.upf.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "minimal5gc.fullname" . }}-upf
  template:
    metadata:
      labels:
        app: {{ include "minimal5gc.fullname" . }}-upf
    spec:
      containers:
        - name: upf
          image: "{{ .Values.images.upf.repository }}:{{ .Values.images.upf.tag }}"
          ports:
            - containerPort: {{ .Values.upf.port }}
          volumeMounts:
            - name: upf-config
              mountPath: /free5gc/config
      volumes:
        - name: upf-config
          configMap:
            name: {{ include "minimal5gc.fullname" . }}-upf-config
```

### templates/service-upf.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "minimal5gc.fullname" . }}-upf
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.upf.port }}
      targetPort: {{ .Values.upf.port }}
      name: http
  selector:
    app: {{ include "minimal5gc.fullname" . }}-upf
```

### templates/configmap-upf.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "minimal5gc.fullname" . }}-upf-config
data:
  upf.json: |-
{{ .Values.upf.config | indent 4 }}
```

---

### Commandes pour déployer et tester minimal5gc

1. **Valider et installer le chart**

```bash
# Se placer à la racine du repo
cd minimal5gc

# Vérifier le chart
helm lint .

# Installer le chart (si déjà installé, utiliser --replace ou helm uninstall puis helm install)
helm install minimal5gc .
```

2. **Vérifier les ressources Kubernetes**

```bash
# Afficher les pods (3 pods : amf, smf, upf)
kubectl get pods

# Afficher les services (3 services ClusterIP)
kubectl get svc
```

3. **Inspecter les logs des NFs**

```bash
# AMF
kubectl logs deploy/minimal5gc-amf

# SMF
kubectl logs deploy/minimal5gc-smf

# UPF
kubectl logs deploy/minimal5gc-upf
```

4. **Tester l’API SBI du cœur 5G**

```bash
# Lister les NF instances enregistrées (via AMF)
AMF_IP=$(kubectl get svc minimal5gc-amf -o jsonpath='{.spec.clusterIP}')
curl http://$AMF_IP:7777/nnrf-nfm/v1/nf-instances
```

5. **Optionnel : tester l’enregistrement SMF → UPF**

```bash
# Lister les PFCP sessions (via SMF)
SMF_IP=$(kubectl get svc minimal5gc-smf -o jsonpath='{.spec.clusterIP}')
curl http://$SMF_IP:7778/nnrf-nfm/v1/nf-instances
```

6. **Désinstaller**

```bash
helm uninstall minimal5gc
```

















Voici la marche à suivre pour **builder** vos propres images à partir des Dockerfiles du repo et les **injecter** dans votre cluster k3d (ou Minikube), afin de lever le `ErrImagePull` sans dépendre d’un registry externe :

---

## 1. Construire les images localement

Placez-vous à la racine du repo, puis :

```bash
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
```

> Ajustez le tag (`v3.0.11`) si vous visez une autre version.

---

## 2. Importer les images dans k3d (si vous utilisez k3d)

Supposons que votre cluster s’appelle `5gc` :

```bash
k3d image import \
  free5gc/amf:v3.0.11 \
  free5gc/smf:v3.0.11 \
  free5gc/upf:v3.0.11 \
  -c 5gc
```

> Si vous êtes sur **Minikube**, à la place faites :
>
> ```bash
> minikube image load free5gc/amf:v3.0.11
> minikube image load free5gc/smf:v3.0.11
> minikube image load free5gc/upf:v3.0.11
> ```

---

## 3. Re-déployer votre chart

1. Désinstallez l’ancienne release (s’il en reste) :

   ```bash
   helm uninstall minimal5gc || true
   ```
2. Réinstallez :

   ```bash
   helm install minimal5gc .
   ```
3. Vérifiez que tout passe en **Running** :

   ```bash
   kubectl get pods
   ```

À ce stade, Kubernetes utilisera vos images locales (pas besoin de pull depuis Docker Hub) et vous ne verrez plus d’`ErrImagePull`.


Deux solutions rapides :

---

## 1) Ne pas build du tout, utiliser des images publiques

Si tu n’as pas les sources Docker sous la main, tu peux simplement laisser Kubernetes puller des images déjà publiées. Par exemple, pour reprendre les images Orange officiellement packagées :

1. Dans **minimal5gc/values.yaml**, remplace la section `images:` par quelque chose comme :

   ```yaml
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
   ```

   Ajuste les tags (`v3.0.6`) selon ce qui est disponible upstream.

2. Désinstalle et réinstalle ton chart :

   ```bash
   helm uninstall minimal5gc || true
   helm install minimal5gc .
   kubectl get pods
   ```

Tu verras tes pods passer en `Running` sans jamais avoir à builder quoi que ce soit.

---

## 2) Récupérer les Dockerfiles et builder localement

Si tu tiens vraiment à builder tes propres images :

1. **Clone** le dépôt original qui contient le dossier `docker/` (c’est celui que tu avais zippé) :

   ```bash
   cd ~/Kubernetes_5GC_Project-main
   git clone https://github.com/<orga>/towards5gs-helm.git upstream
   cd upstream
   ```

2. **Builde** les images :

   ```bash
   docker build -t free5gc/amf:v3.0.11   -f docker/free5gc/amf/Dockerfile   docker/free5gc/amf
   docker build -t free5gc/smf:v3.0.11   -f docker/free5gc/smf/Dockerfile   docker/free5gc/smf
   docker build -t free5gc/upf:v3.0.11   -f docker/free5gc/upf/Dockerfile   docker/free5gc/upf
   ```

3. **Charge**-les dans ton cluster local :

   * **k3d** :

     ```bash
     k3d image import free5gc/amf:v3.0.11 free5gc/smf:v3.0.11 free5gc/upf:v3.0.11 -c 5gc
     ```
   * **Minikube** :

     ```bash
     minikube image load free5gc/amf:v3.0.11
     minikube image load free5gc/smf:v3.0.11
     minikube image load free5gc/upf:v3.0.11
     ```

4. **Re-déploie** ton chart depuis `minimal5gc/` :

   ```bash
   cd ../5GC\ minimal
   helm uninstall minimal5gc || true
   helm install minimal5gc .
   kubectl get pods
   ```

  ```bash
  https://github.com/Orange-OpenSource/towards5gs-helm/tree/main
  ```
---

**En résumé**

* Si tu ne veux *vraiment pas* télécharger/build, utilise les images Orange officielles dans `values.yaml`.
* Si tu préfères ta propre build, commence par cloner le dépôt complet qui contient le dossier `docker/`, puis build/import les images avant de réinstaller le chart.

Choisis l’une ou l’autre et dis-moi si ça te dépanne !
