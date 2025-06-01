Le fait que l’AMF (“free5gc/amf\:latest”) démarre puis plante (CrashLoopBackOff) signifie généralement que :

1. L’AMF voit bien son binaire se lancer (pas d’ErrImagePull),
2. Mais qu’il n’a pas la configuration ou les services adjacents (NF Registry, base de données, etc.) dont il a besoin pour tourner,
3. Et il se tue tout seul en ne trouvant pas par exemple le NRF, le MongoDB, ou une partie de son fichier de config.

Concrètement, lorsque vous utilisez des images “AMF seules” sur Docker Hub, elles ne fonctionnent pas en stand-alone : elles attendent d’avoir un NRF à qui s’enregistrer, une instance MongoDB pour stocker leurs données, etc. Si vous ne leur fournissez pas ces dépendances, elles quittent immédiatement — d’où le CrashLoopBackOff.

Pour mettre rapidement **3 pods AMF/SMF/UPF en Running**, vous avez deux options :

---

## 1. Utiliser une image “all-in-one” Free5GC qui contient tout le cœur

Au lieu de tirer une image “AMF seule”, vous pouvez partir sur une image publique qui embarque **toutes les fonctions réseau** (AMF, SMF, UPF, NRF, UDR, UDM, PCF, AUSF, NSSF…) dans un unique conteneur prêt à l’emploi. En une sorte de “mini-core” tout-en-un, compatible avec un déploiement minimal. Plusieurs forks existent, par exemple :

* **`free5gc/free5gc-full`** (ou un nom proche) : certaines équipes publient une image qui lance tout le control plane dans un seul processus (toutes les NFs déclarées dans un seul conteneur).
* **`irithmetic/free5gc`** (hypothétique, selon ce qu’on trouve sur Docker Hub).
* **`nbl5gc/5gc`** ou **`free5gc/monolithic`**, les noms varient d’un fork à l’autre.

L’avantage :

* Vous n’aurez plus besoin de configurer un AMF isolé, ni d’instancier un NRF/MongoDB séparément.
* Le cœur démarre “tout en un” et reste en Running.

### Exemple pour tester une image “all-in-one”

1. Dans votre repo **`5GC minimal/`**, lancez un test rapide en surchargeant l’AMF/SMF/UPF pour qu’ils pointent tous vers la même image “monolithique” (là où tout est packagé).

   ```bash
   cd ~/Kubernetes_5GC_Project-main/5GC\ minimal

   # Désinstallez l’ancienne release
   helm uninstall minimal5gc --namespace default || true

   # Installez en forçant AMF, SMF et UPF sur la même image “tout-en-un”
   helm install minimal5gc . \
     --set imagePullPolicy=IfNotPresent \
     --set images.amf.repository=free5gc/free5gc-full \
     --set images.amf.tag=latest \
     --set images.smf.repository=free5gc/free5gc-full \
     --set images.smf.tag=latest \
     --set images.upf.repository=free5gc/free5gc-full \
     --set images.upf.tag=latest
   ```

   Ici, on force AMF, SMF, UPF à appeler la même image `free5gc/free5gc-full:latest`.

   * L’idée est que ce conteneur “tout en un” démarre bien, expose plusieurs ports internes (7777, 7778, 8805, etc.) et répond comme si AMF, SMF, UPF étaient chacun leur propre service.
   * Dans ce cas, tous les pods se lanceront, mais chacun d’eux exécutera en réalité le même binaire multi-fonction (tout-en-un).

2. Attendez 15–20 s, puis vérifiez :

   ```bash
   sleep 20
   kubectl get pods
   ```

   → Si vous voyez

   ```
   minimal5gc-minimal5gc-amf-xxxxx   1/1   Running   0   30s  
   minimal5gc-minimal5gc-smf-xxxxx   1/1   Running   0   30s  
   minimal5gc-minimal5gc-upf-xxxxx   1/1   Running   0   30s  
   ```

   cela signifie que l’image “tout-en un” fonctionne (même si derrière, il n’y a qu’un seul service packagé, exposé sous plusieurs ports).

3. Si **`free5gc/free5gc-full:latest`** n’existe pas ou ne démarre pas, essayez d’autres noms d’image “monolithe” trouvés sur Docker Hub, par exemple :

   * `nbl5gc/free5gc`
   * `dace/free5gc-monolith`
   * `moriarty/5gcore-allinone`

   La technique est toujours la même : remplacez `free5gc/free5gc-full` par le repo et le tag que vous trouvez sur Docker Hub, relancez le `helm install` et vérifiez si les pods tournent.

4. Dès que vous obtenez **tous les pods en Running**, fixez cette image dans **votre** `5GC minimal/values.yaml`. Par exemple :

   ```yaml
   imagePullPolicy: IfNotPresent

   images:
     amf:
       repository: free5gc/free5gc-full
       tag: latest
     smf:
       repository: free5gc/free5gc-full
       tag: latest
     upf:
       repository: free5gc/free5gc-full
       tag: latest

   # (reste inchangé)
   ```

   Ensuite :

   ```bash
   helm uninstall minimal5gc --namespace default || true
   helm install minimal5gc .
   kubectl get pods
   ```

   Vos pods resteront alors en Running à chaque déploiement, puisque cette image “tout-en-un” embarque toutes les NFs.

---

## 2. Créer un petit pod “all-in-one” local dans le chart

Si vous ne trouvez pas d’image publique “tout-en-un” fiable, vous pouvez bricoler votre propre “monolithe” en quelques lignes :

1. **Prenez n’importe laquelle des images AMF/SMF/UPF qui démarrent sans CrashLoopBackOff** et forçons le chart à lancer tous les trois pods contre la même image. Par exemple `free5gc/amf:latest` donne CrashLoopBackOff, mais voyons si `free5gc/smf:latest` démarre (parfois SMF démarre plus facilement). Testez manuellement :

   ```bash
   docker pull free5gc/smf:latest
   docker run --rm -it free5gc/smf:latest
   ```

   * Si vous voyez que le conteneur démarre (sans se tuer), c’est déjà un bon signe.
   * Relevez le repository/tag exact, puis dans `5GC minimal/values.yaml` forçons SMF pour AMF/SMF/UPF.

2. Exemple concret (en supposant que `free5gc/smf:latest` tourne) :

   ```bash
   cd ~/Kubernetes_5GC_Project-main/5GC\ minimal

   # Désinstallez l’ancienne release
   helm uninstall minimal5gc --namespace default || true

   # Installez en forçant AMF, SMF et UPF sur free5gc/smf:latest
   helm install minimal5gc . \
     --set imagePullPolicy=IfNotPresent \
     --set images.amf.repository=free5gc/smf \
     --set images.amf.tag=latest \
     --set images.smf.repository=free5gc/smf \
     --set images.smf.tag=latest \
     --set images.upf.repository=free5gc/smf \
     --set images.upf.tag=latest
   ```

   Tous vos pods vont tenter de démarrer le binaire SMF, ce qui peut mieux tenir en `Running` (cela ne vous donnera pas un cœur 5G “réel”, mais ça vous permettra d’avoir trois pods stables le temps de tester l’orchestration).

3. Si **`free5gc/smf:latest`** ne passe pas non plus, essayez **`free5gc/upf:latest`** ou **`free5gc/amf:latest`** (certains forks ont un bug ou une dépendance minimale corrigée). L’idée est toujours la même :

   * En “bricolant”, forcez le chart à lancer la même image pour AMF/SMF/UPF, tant qu’elle ne plante pas directement.
   * Dès que vous trouvez **une image unique** qui tourne correctement en pod simple, vous pourrez dupliquer ce comportement sur les trois pods du chart et obtenir un cluster “minimisé” dont les pods sont en Running.

4. Lorsque vous aurez trouvé **une image stable** (par exemple `free5gc/upf:latest`), modifiez définitivement votre `values.yaml` pour pointer AMF/SMF/UPF sur ce repo\:tag, par exemple :

   ```yaml
   imagePullPolicy: IfNotPresent

   images:
     amf:
       repository: free5gc/upf
       tag: latest
     smf:
       repository: free5gc/upf
       tag: latest
     upf:
       repository: free5gc/upf
       tag: latest

   # (reste inchangé)
   ```

   puis :

   ```bash
   helm uninstall minimal5gc --namespace default || true
   helm install minimal5gc .
   kubectl get pods
   ```

   Vous aurez ainsi **trois pods “upf”** stables (Running), pointés chacun sur l’image `free5gc/upf:latest`. Ce n’est pas un vrai cœur 5G, mais cela vous donne un environnement où “tous vos pods Kubernetes sont en Running” pour la démonstration ou pour affiner votre chart Helm.

---

### En résumé rapide

1. **CrashLoopBackOff** signifie que l’image (AMF/SMF/UPF “stand-alone”) n’a pas ses dépendances (NRF, MongoDB, etc.) et se termine.
2. La recette la plus simple pour avoir des pods en Running est d’utiliser une **image “tout-en-un”** (un monolithe Free5GC) qui contient déjà toutes les NFs.

   * Exemple : `free5gc/free5gc-full:latest` (ou une variante que vous trouvez sur Docker Hub).
   * Déployez votre chart en forçant AMF/SMF/UPF sur cette même image :

     ```bash
     helm install minimal5gc . \
       --set imagePullPolicy=IfNotPresent \
       --set images.amf.repository=free5gc/free5gc-full \
       --set images.amf.tag=latest \
       --set images.smf.repository=free5gc/free5gc-full \
       --set images.smf.tag=latest \
       --set images.upf.repository=free5gc/free5gc-full \
       --set images.upf.tag=latest
     ```
3. Si vous ne trouvez pas d’image monolithe publique, testez la même image **AMF** ou **SMF** pour les trois pods (p. ex. `free5gc/smf:latest` pour all), ce qui vous donnera trois pods “RF SMF” stables.
4. Dès que vous identifiez **l’image unique** qui ne plante pas, ajustez votre `values.yaml` pour pointer AMF/SMF/UPF dessus, et relancez un `helm install` définitif.

Une fois que tous vos pods sont `Running`, vous aurez un chart minimal fonctionnel, prêt à être enrichi (configuration, networking, tests RAN, etc.).
