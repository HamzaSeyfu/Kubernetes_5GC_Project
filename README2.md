Pour que vos trois pods **AMF**, **SMF** et **UPF** passent en `Running` **sans** dépendre de Free5GC (ni des images Orange), nous allons simplement les faire tourner sur un conteneur “dummy” (par exemple `busybox:latest`) qui ne plante jamais. Concrètement, on modifie vos **déploiements** pour :

1. Point à `busybox:latest` (ou `alpine:latest`),
2. Ajouter un `command: ["sh","-c","while true; do sleep 3600; done"]` pour que le container ne fasse que dormir,

et on garde vos **services** et **ConfigMaps** en place (même s’ils ne sont pas utilisés par le binaire 5GC).

---

## 1. Valeurs (values.yaml)

Dans votre `values.yaml`, vous avez déjà forcé :

```yaml
images:
  amf:
    repository: busybox
    tag: latest
  smf:
    repository: busybox
    tag: latest
  upf:
    repository: busybox
    tag: latest

imagePullPolicy: IfNotPresent

# Les blocs amf:, smf:, upf: peuvent rester (même s’ils ne seront pas lus par busybox).
amf:
  replicaCount: 1
  port: 7777
  config: |
    { ... }
smf:
  replicaCount: 1
  port: 7778
  config: |
    { ... }
upf:
  replicaCount: 1
  port: 8805
  config: |
    { ... }
```

Vérifiez bien que `images.amf.repository = busybox` et `tag = latest` (idem pour smf/upf). Vous pouvez totalement ignorer les blocs JSON si vous ne comptez pas lancer le binaire Free5GC.

---

## 2. Modifier les manifests de déploiement

Pour chacun des trois fichiers `templates/deployment-*.yaml` (AMF, SMF, UPF), remplacez **uniquement** la section `containers:` par le bloc ci-dessous. L’idée est de remplacer l’image 5GC par `busybox:latest` et d’y exécuter un “sleep infini”.

### 2.1. `templates/deployment-amf.yaml`

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
          # On force l'image Busybox :
          image: "busybox:latest"
          imagePullPolicy: IfNotPresent
          # Pour ne jamais planter, on loop en sleep :
          command: ["sh", "-c"]
          args:
            - |
              while true; do
                sleep 3600
              done
          ports:
            - containerPort: {{ .Values.amf.port }}
      volumes:
        - name: amf-config
          configMap:
            name: {{ include "minimal5gc.fullname" . }}-amf-config
```

### 2.2. `templates/deployment-smf.yaml`

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
          image: "busybox:latest"
          imagePullPolicy: IfNotPresent
          command: ["sh", "-c"]
          args:
            - |
              while true; do
                sleep 3600
              done
          ports:
            - containerPort: {{ .Values.smf.port }}
      volumes:
        - name: smf-config
          configMap:
            name: {{ include "minimal5gc.fullname" . }}-smf-config
```

### 2.3. `templates/deployment-upf.yaml`

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
          image: "busybox:latest"
          imagePullPolicy: IfNotPresent
          command: ["sh", "-c"]
          args:
            - |
              while true; do
                sleep 3600
              done
          ports:
            - containerPort: {{ .Values.upf.port }}
      volumes:
        - name: upf-config
          configMap:
            name: {{ include "minimal5gc.fullname" . }}-upf-config
```

> **Remarque** :
>
> * Nous avons remplacé toutes les références à `.Values.images.*` par l’image fixe `"busybox:latest"`.
> * Le `command` + `args` force busybox à rester “up” (il ne fait que dormir).
> * Les `volumes` et `configMap` sont toujours déclarés (vous pouvez les laisser ou bien les supprimer si vous voulez simplifier davantage), mais busybox s’exécute sans s’en soucier.

---

## 3. Vérifier `_helpers.tpl`

Assurez-vous que **le fichier existe** dans `templates/_helpers.tpl` :

```gotemplate
{{- define "minimal5gc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "minimal5gc.fullname" -}}
{{- printf "%s-%s" (include "minimal5gc.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
```

Si cette définition manque, vos `{{ include "minimal5gc.fullname" . }}` dans les noms de ressources planteront.

---

## 4. Chart.yaml (vérification rapide)

Votre `Chart.yaml` doit présenter au minimum :

```yaml
apiVersion: v2
name: minimal5gc
description: "Helm chart minimal (AMF, SMF, UPF)"
version: 0.1.0
appVersion: "v1.0.0"
```

Sans ce schéma, Helm ne reconnaît pas votre dossier comme un chart valide.

---

## 5. Déployer (depuis le dossier racine du chart)

1. Depuis le dossier qui contient **Chart.yaml** et **values.yaml**, exécutez :

   ```bash
   helm lint .
   ```

   Vous devriez voir uniquement un (\[INFO] Chart.yaml: icon is recommended) ou rien de bloquant.

2. Désinstallez toute release antérieure (pour repartir à zéro) :

   ```bash
   helm uninstall minimal5gc --namespace default || true
   ```

3. Lancez l’installation :

   ```bash
   helm install minimal5gc .
   ```

4. Vérifiez immédiatement l’état des pods :

   ```bash
   kubectl get pods
   ```

   Vous devez obtenir quelque chose comme :

   ```
   NAME                                  READY   STATUS    RESTARTS   AGE
   minimal5gc-minimal5gc-amf-<suffix>    1/1     Running   0          10s
   minimal5gc-minimal5gc-smf-<suffix>    1/1     Running   0          10s
   minimal5gc-minimal5gc-upf-<suffix>    1/1     Running   0          10s
   ```

---

### Résumé :

* **But** : passer les pods AMF/SMF/UPF en `Running`, **coûte que coûte**, sans image 5GC valide.
* **Méthode** :

  1. Dans `values.yaml`, pointez `images.* -> busybox:latest`.
  2. Dans **chaque** `templates/deployment-*.yaml`, remplacez le bloc `containers:` pour qu’il utilise `busybox:latest` + un `command: ["sh","-c","while true; do sleep 3600; done"]`.
  3. Conservez (ou supprimez au choix) vos ConfigMaps et Services ; ils n’empêcheront pas busybox de tourner.
  4. Assurez-vous du **Chart.yaml** correct et du `_helpers.tpl` en place.
  5. Faire un `helm lint .`, `helm uninstall minimal5gc`, puis `helm install minimal5gc .`, et enfin `kubectl get pods`.

Avec cette approche, vos trois pods démarreront et resteront indéfiniment en `Running`.
