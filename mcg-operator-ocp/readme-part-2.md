# The Loki Stack

Well, this one was not very fun to understand and do a proper deployment. The documentation does not help and you need to deduce some things, and experience others. In this lab we are installing everything in a vSphere cluster. I tried to make the process as clean and easy to maintain as possible, but perhaps some adjustments are still needed.

The deployment has been tested on **OpenShift 4.16**. In this release, a lot was changed in the logging stack.

For convenience, the first part of this article can be found here. In the first part we talked about using **MCG as Object Storage**.

Zanoni Maciel helped me with some templates. Be sure to visit his blog.  
The first part of this article can be found here.

⚠️ **Please do the tasks in the order they are presented** ⚠️  
⚠️ **You must install the Red Hat OpenShift Logging Operator AFTER the log store Operator!** ⚠️

---

## Requirements

- MachineSet for the Loki Stack  
- MCG up and running  
- Operators installed  
- Monitoring configured  

### Software used

- Logging **6.1.1**  
- Loki **6.1.1**  
- Observability **0.4.1**  

---

## Loki Resources

Loki stack requires a lot of resources. So it is a good practice to use dedicated nodes for it.

---

## OpenShift Logging Machine Set

We will now create a MS with **2 VM replicas** with **16 vCPU** and **48 GB RAM**.  
This will be enough to run a `1x.extra-small` deployment.

### Create OpenShift Logging Machine Set

```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: homecloud-hqrlw
  name: homecloud-hqrlw-infra-logging
  namespace: openshift-machine-api
spec:
  replicas: 2
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: homecloud-hqrlw
      machine.openshift.io/cluster-api-machineset: homecloud-hqrlw-infra-logging
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: homecloud-hqrlw
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: homecloud-hqrlw-infra-logging
    spec:
      metadata:
        creationTimestamp: null
        labels:
          node-role.kubernetes.io/infra: ""
          node-role.kubernetes.io/worker: ""
          env: logging
      providerSpec:
        value:
          credentialsSecret:
            name: vsphere-cloud-credentials
          diskGiB: 120
          kind: VSphereMachineProviderSpec
          memoryMiB: 49152
          metadata:
            creationTimestamp: null
          network:
            devices:
              - networkName: 'ocp-s3'
          numCPUs: 16
          numCoresPerSocket: 16
          snapshot: ""
          template: homecloud-hqrlw-rhcos-homecloud-rio
          userDataSecret:
            name: worker-user-data
          workspace:
            datacenter: Datacenter
            datastore: NETAC
            diskType: thin-csi
            folder: /Datacenter/vm/OCP/S3/LOGGING
            resourcepool: /Datacenter/host/Homelab/Resources/rpool-s3
            server: 192.168.15.62
          template: homecloud-hqrlw-rhcos-homecloud-rio
          apiVersion: vsphereprovider.openshift.io/v1beta1
      taints:
        - effect: NoSchedule
          key: logging
          value: reserved
        - effect: NoExecute
          key: logging
          value: reserved
```

Wait for the creation of the nodes.

---

## Machine Config Pool for Logging (MCP)

You can use the following template to create the MCP:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: logging
spec:
  machineConfigSelector:
    matchExpressions:
    - key: machineconfiguration.openshift.io/role
      operator: In
      values:
      - worker
      - infra
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/infra: ""
      env: logging
  paused: false
```

---

## OpenShift Logging Operator

Install the **Red Hat OpenShift Logging 6.1.1 Operator**.

> Make sure to check **"Enable Operator recommended cluster monitoring on this Namespace"**.  
> The logging operator setup will be done later.

---

## Cluster Monitoring Instance Config Map (CM)

You can use the following template to configure monitoring:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
 name: cluster-monitoring-config
 namespace: openshift-monitoring
data:
 config.yaml: |+
   alertmanagerMain:
     volumeClaimTemplate:
       metadata:
         name: pvc-alertmanager
       spec:
         storageClassName: thin-csi
         resources:
           requests:
             storage: 2Gi
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   prometheusK8s:
     volumeClaimTemplate:
       metadata:
         name: pvc-prometheus
       spec:
         storageClassName: thin-csi
         resources:
           requests:
             storage: 100Gi
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   prometheusOperator:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   k8sPrometheusAdapter:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   kubeStateMetrics:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   telemeterClient:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   openshiftStateMetrics:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   thanosQuerier:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   monitoringPlugin:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
   metricsServer:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoSchedule
     - key: node.role.kubernetes.io/infra
       value: reserved
       effect: NoExecute
```

---

## S3 Bucket

As we are using only the **MCG (standalone multicloud object gateway)**, create an OBC named `loki` and set the storage class to `openshift-storage.noobaa.io`.

> Be sure to select the namespace used for Loki (**openshift-logging**).

### You can also use a command like the one below to create the OBC

```bash
cat <<EOF | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: loki
  namespace: openshift-logging
spec:
  storageClassName: openshift-storage.noobaa.io
  generateBucketName: loki
EOF
```

### Claim Data

Take note of the bucket access details.

---

## OpenShift Loki Operator

Install the **Red Hat OpenShift Loki Operator**.

> Make sure to check "Enable Operator recommended cluster monitoring on this Namespace".

### Check the CSVs

```bash
oc get csv -n openshift-logging
```

**Output example:**

```
NAME                                   DISPLAY                          VERSION   REPLACES                               PHASE
cluster-logging.v6.1.1                 Red Hat OpenShift Logging        6.1.1     cluster-logging.v6.1.0                 Succeeded
loki-operator.v6.1.1                   Loki Operator                    6.1.1     loki-operator.v6.1.0                   Succeeded
```

You can collect some status in more depth:

```bash
oc get csv -n openshift-logging loki-operator.v6.1.1 -o json | jq -r '.status'
```