# 🚀 Deploy do MinIO no Red Hat OpenShift 4.16 (sem operador)

> ⚠️ **Importante:** O **MinIO Operator não é compatível com o OpenShift**. Portanto, este guia utiliza uma abordagem manual com pods e recursos nativos do Kubernetes/OpenShift.

---

## 📋 Requisitos

- OpenShift 4.19 (funciona em outras versões também)
- Acesso administrativo ao cluster (`oc` CLI)
- Configuração do DNS para acesso externo aos routes

---

## 🧱 Estrutura do Deploy

1. Criar Namespace
2. Criar PVC
3. Criar Deployment
4. Ajustar permissões (SCC)
5. Criar Services
6. Criar Routes
7. Criar Bucket e Usuário
8. Acessar via WebUI ou API

---

## 1️⃣ Criar Namespace

```yaml
# minio-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minio-ocp
  labels:
    name: minio-ocp
```

```bash
oc create -f minio-ns.yaml
```

---

## 2️⃣ Criar PVC (PersistentVolumeClaim)

> 🔧 Ajuste `storageClassName` conforme seu ambiente.

```yaml
# minio-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-ocp
  namespace: minio-ocp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: thin-csi
  volumeMode: Filesystem
```

```bash
oc create -f minio-pvc.yaml
```

---

## 3️⃣ Criar Deployment do MinIO

> ⚠️ Ajuste `nodeSelector`, volumes e permissões conforme sua infraestrutura.

```yaml
# minio-ocp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio-ocp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: ''
      volumes:
        - name: minio-ocp
          persistentVolumeClaim:
            claimName: minio-ocp
      containers:
        - name: minio
          image: quay.io/minio/minio:latest
          imagePullPolicy: IfNotPresent
          args:
            - "minio server /data --console-address :9090"
          ports:
            - containerPort: 9000
            - containerPort: 9090
          volumeMounts:
            - name: minio-ocp
              mountPath: /data
          readinessProbe:
            tcpSocket:
              port: 9090
            timeoutSeconds: 5
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
```

```bash
oc create -f minio-ocp.yaml
```

---

## 4️⃣ Ajustar Permissões (SCC)

```bash
oc project
oc get deployment/minio -o yaml | oc adm policy scc-subject-review -f -
oc get pod -n minio-ocp -l app=minio -o=jsonpath='{.items[0].spec.serviceAccountName}'
oc adm policy add-scc-to-user anyuid -z default -n minio-ocp
```

---

## 5️⃣ Criar Services

```yaml
# minio-svc.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: minio-webui
  namespace: minio-ocp
spec:
  selector:
    app: minio
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 9090
      name: webui
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: minio-api
  namespace: minio-ocp
spec:
  selector:
    app: minio
  ports:
    - protocol: TCP
      port: 9000
      targetPort: 9000
      name: api
  type: ClusterIP
```

```bash
oc create -f minio-svc.yaml
```

---

## 6️⃣ Criar Routes para acesso externo

```yaml
# minio-route.yaml
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: webui
  namespace: minio-ocp
spec:
  host: webui-minio-ocp.apps.onpremises.example.com
  to:
    kind: Service
    name: minio-webui
  port:
    targetPort: webui
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: s3
  namespace: minio-ocp
spec:
  host: s3-minio-ocp.apps.onpremises.example.com
  to:
    kind: Service
    name: minio-api
  port:
    targetPort: api
```

```bash
oc create -f minio-route.yaml
```

---

## 7️⃣ Acessar Console Web do MinIO

```
http://webui-minio-ocp.apps.onpremises.example.com
```

Login padrão:
```
Username: minioadmin
Password: minioadmin
```

---

## 8️⃣ Criar Usuário e Bucket

1. WebUI: **Identity > Users > Create User**
2. Criar usuário: `loki`, senha: `password`
3. Criar Access Key: baixe o JSON com `accessKey` e `secretKey`
4. Criar bucket: **Buckets > Create > loki**
5. Vincule o usuário `loki` no acesso do bucket

---

## 📦 Verificar Armazenamento no POD

```bash
oc rsh -n minio-ocp <nome-do-pod> du -h /data/loki/
```

---

## 🧰 Ferramentas úteis

- [`mc`](https://min.io/docs/minio/linux/reference/minio-mc.html): cliente CLI do MinIO

---

## 📈 Integração com Prometheus

Requer configuração de métricas com autenticação. Pode ser abordado em um próximo guia.

---

## 🧠 Dicas Finais

- Utilize **Tenants** em produção
- Configure **TLS nas routes**
- Crie `ServiceAccounts` com permissões mínimas

---

### 📣 Créditos

Este guia foi baseado no conteúdo criado por **André Rocha** do blog [LinuxElite](https://linuxelite.com.br)