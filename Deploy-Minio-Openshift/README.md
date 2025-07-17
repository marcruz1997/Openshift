# 🚀 Deploying MinIO on Red Hat OpenShift 4.19 (without Operator)

> ⚠️ **Important:** The **MinIO Operator is not compatible with OpenShift**. Therefore, this guide uses a manual approach with pods and native Kubernetes/OpenShift resources.

---

## 📋 Requirements

- OpenShift 4.19 (also works on other versions)
- Administrative access to the cluster (`oc` CLI)
- DNS configuration for external route access

---

## 🧱 Deployment Structure

1. Create Namespace
2. Create PVC
3. Create Deployment
4. Adjust permissions (SCC)
5. Create Services
6. Create Routes
7. Create Bucket and User
8. Access via WebUI or API

---

## 1️⃣ Create Namespace

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

## 2️⃣ Create PVC (PersistentVolumeClaim)

> 🔧 Adjust the `storageClassName` according to your environment.

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

## 3️⃣ Create MinIO Deployment

> ⚠️ Adjust `nodeSelector`, volumes, and permissions as needed for your infrastructure.

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

## 4️⃣ Adjust Permissions (SCC)

```bash
oc project
oc get deployment/minio -o yaml | oc adm policy scc-subject-review -f -
oc get pod -n minio-ocp -l app=minio -o=jsonpath='{.items[0].spec.serviceAccountName}'
oc adm policy add-scc-to-user anyuid -z default -n minio-ocp
```

---

## 5️⃣ Create Services

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

## 6️⃣ Create External Routes

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

## 7️⃣ Access MinIO Web Console

```
http://webui-minio-ocp.apps.onpremises.example.com
```

Default login:
```
Username: minioadmin
Password: minioadmin
```

---

## 8️⃣ Create User and Bucket

1. WebUI: **Identity > Users > Create User**
2. Create user: `loki`, password: `password`
3. Create Access Key: download the JSON with `accessKey` and `secretKey`
4. Create bucket: **Buckets > Create > loki**
5. Link user `loki` to the bucket under access

---

## 📦 Check Storage on the POD

```bash
oc rsh -n minio-ocp <pod-name> du -h /data/loki/
```

---

## 🧰 Useful Tools

- [`mc`](https://min.io/docs/minio/linux/reference/minio-mc.html): MinIO command-line client

---

## 📈 Prometheus Integration

Requires configuration for metrics and authentication. Might be covered in a future guide.

---

## 🧠 Final Tips

- Use **Tenants** in production
- Configure **TLS on routes**
- Use dedicated `ServiceAccounts` with minimal permissions

---

### 📣 Credits

This guide is based on original content by **André Rocha** from the blog [LinuxElite](https://linuxelite.com.br)