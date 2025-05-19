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

Souhaites-tu que je t’aide à créer un script `deploy.sh` qui applique tout proprement dans l’ordre ?

