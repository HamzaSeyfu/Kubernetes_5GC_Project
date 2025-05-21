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

Souhaites-tu que je te génère un **script Bash** avec tous ces tests chaînés automatiquement dans l’ordre ?
