# Loki Stack - Part 3

## Introduction

In this part of the article we'll look at the configurations needed to get Loki up and running, with all the necessary details.

The first part of this article can be found here.

The second part can be found here.

---

## Object Bucket Claim

This was created on the first part of this series of articles. Check it out here.

---

## Secret

You will need to create a secret containing the OBC's access details. First, obtain your Cluster Name:

```bash
echo $(oc config view -o jsonpath='{.contexts[0].context.cluster}')
homelab
```

### Object Storage Secret

Create a secret containing the OBC access details:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: logging-loki-s3
  namespace: openshift-logging
stringData:
  access_key_id: lQueo8uZfaan0kUo3w1Z
  access_key_secret: fk2mN1CiBEYAuohPtnvEr7gi4wGd3SX6xvpfwcIQ
  bucketnames: loki-d33d77dd-8ff5-4e48-abf5-08acdd20eebb
  endpoint: https://s3.openshift-storage.svc:443
  region: homecloud
```

> ⚠️ Don't forget to add the `https://` to the endpoint!

---

## Loki Stack

The Loki Stack can consume an enormous amount of computer resources. For this deploy we will create a stack `1x.extra-small`.

From your Openshift Web UI, select the project `openshift-logging`.

Create the Loki Stack using the YAML below as a template.

> Don't change the `storage.schemas` parameters.

```yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging-loki
  namespace: openshift-logging
spec:
  limits:
    global:
      retention:
        days: 2
      ingestion:
        ingestionRate: 8
        ingestionBurstSize: 16
        maxLabelNameLength: 1024
        maxLabelValueLength: 2048
        maxLabelNamesPerSeries: 30
        maxGlobalStreamsPerTenant: 10000
        maxLineSize: 256000
      queries:
        maxEntriesLimitPerQuery: 10000
        maxChunksPerQuery: 2000000
        maxQuerySeries: 1000
        queryTimeout: 1m
  tenants:
    mode: openshift-logging
  managementState: Managed
  rules:
    enabled: true
  replicationFactor: 1
  size: 1x.extra-small
  storage:
    schemas:
      - effectiveDate: '2022-06-21'
        version: v13
    secret:
      name: logging-loki-s3
      type: s3
    tls:
      caName: openshift-service-ca.crt
  storageClassName: thin-csi
  tenants:
    mode: openshift-logging
  template:
    compactor:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    distributor:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    gateway:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    indexGateway:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    ingester:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    querier:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    queryFrontend:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
    ruler:
      nodeSelector:
        node-role.kubernetes.io/infra: ''
      tolerations:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
```

---

### Loki Pods

Check the created stack with the following command:

```bash
oc -n openshift-logging get lokistack logging-loki -o yaml
```

### Log Ingester

Check if the Loki ingester and Loki ruler have any problems by tailing their logs:

```bash
oc logs logging-loki-ingester-0 -n openshift-logging -f
oc logs logging-loki-ruler-0 -n openshift-logging -f
```

### Loki Querier

Check that the querier is connected to the query frontend:

```bash
QUERIER=$(oc get pods -n openshift-logging|grep loki-querier|awk '{print $1}')
for I in $QUERIER ; do oc logs -n openshift-logging $I | grep frontend= ; done
```

Example output:

```
level=info ts=2025-01-17T12:53:55.620945933Z caller=worker.go:141 component=querier msg="Starting querier worker connected to query-frontend" frontend=logging-loki-query-frontend-grpc.openshift-logging.svc.cluster.local:9095
level=info ts=2025-01-17T12:54:18.795643559Z caller=worker.go:141 component=querier msg="Starting querier worker connected to query-frontend" frontend=logging-loki-query-frontend-grpc.openshift-logging.svc.cluster.local:9095
```

---

## Dashboards

At this point you should already be able to see data collected in the Loki dashboards.

---

## Observability

Install **Cluster Observability Operator** if you haven't already installed it.

> The Observability configuration will be done later.

Things are very different here. You no longer have to create a `ClusterLogging`, as was the case in the past. Now the setup is based on service accounts, roles and observability plugins.

---

## UI Plugin

In this scenario, the Loki instance was named `logging-loki`.

Make sure to use your Loki instance name.

Use the following YAML to create an instance of the `UIPlugin`:

```yaml
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: logging
spec:
  type: Logging
  logging:
    lokiStack:
      name: logging-loki
    logsLimit: 50
    timeout: 30s
```

---

## Logging Console Plugin

After the creation of the Loki stack, you should see a refreshed web console on your dashboard.  
If you don't see it, manually enable the **Red Hat OpenShift Logging Console Plugin**.

1. In the OpenShift Container Platform web console, click **Operators → Installed Operators**.  
2. Select the **Red Hat OpenShift Logging Operator**.  
3. Under **Console plugin**, click **Disabled**.  
4. Select **Enable** and then **Save**.  
5. This change will restart the `openshift-console` pods.  
6. After the pods restart, refresh the web console — a new **Logs** option will appear under **Observe**.

---

## Troubleshooting Panel

You can also create a Troubleshooting Panel if you wish:

```yaml
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: troubleshooting-panel
spec:
  type: TroubleshootingPanel
```

---

## Service Account and RBAC

Use the following template to create the SA and RBAC resources:

```yaml
kind: ServiceAccount
apiVersion: v1
metadata:
  name: logcollector
  namespace: openshift-logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: logging-collector-logs-writer
rules:
- apiGroups:
  - loki.grafana.com
  resourceNames:
  - logs
  resources:
  - application
  - audit
  - infrastructure
  verbs:
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name:  logging-collector-logs-writer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name:  logging-collector-logs-writer
subjects:
- kind: ServiceAccount
  name: logcollector
  namespace: openshift-logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: collect-application-logs
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: collect-application-logs
subjects:
- kind: ServiceAccount
  name: logcollector
  namespace: openshift-logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: collect-infrastructure-logs
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: collect-infrastructure-logs
subjects:
- kind: ServiceAccount
  name: logcollector
  namespace: openshift-logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: collect-audit-logs
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: collect-audit-logs
subjects:
- kind: ServiceAccount
  name: logcollector
  namespace: openshift-logging
```

Apply it:

```bash
oc apply -f logging-sa-rbac.yaml
```

---

## Cluster Log Forwarder

Use the following YAML as example to create the CLF:

```yaml
apiVersion: observability.openshift.io/v1
kind: ClusterLogForwarder
metadata:
  name: logging
  namespace: openshift-logging
spec:
  collector:
    tolerations:
      - operator: Exists
  managementState: Managed
  outputs:
    - lokiStack:
        authentication:
          token:
            from: serviceAccount
        target:
          name: logging-loki
          namespace: openshift-logging
      name: default-lokistack
      tls:
        ca:
          configMapName: openshift-service-ca.crt
          key: service-ca.crt
      type: lokiStack
  filters:
  - name: multiline
    type: detectMultilineException
  pipelines:
    - inputRefs:
        - application
      name: apps
      filterRefs:
      - multiline
      outputRefs:
        - default-lokistack
    - inputRefs:
        - infrastructure
      name: infrastructure-logs
      filterRefs:
      - multiline
      outputRefs:
        - default-lokistack
    - inputRefs:
        - audit
      name: audit-logs
      filterRefs:
      - multiline
      outputRefs:
        - default-lokistack
  serviceAccount:
    name: logcollector
```

---

## Check Some Logs

Install a sample app by using the developer dashboard, and check if you can collect its application logs.

1. Go to **Observe > Logs**.  
2. Apply filters as shown in the examples below.  
3. Be sure to generate traffic on your sample app.

---