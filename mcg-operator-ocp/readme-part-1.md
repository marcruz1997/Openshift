# Loki Stack Deployment - Part 1: Object Storage Setup

## Introduction
The deployment described in this article is within supported operation, according to the official documentation.

In this first part of the article we will cover the object storage, as it is a requisite to run Loki Stack.

**Please pay attention to the following details:**

- All the instructions presented here were tested on **OpenShift 4.16**.
- We will be using **ODF 4.16**.
- Follow the steps in the presented order.
- **Do not install the Red Hat OpenShift Logging Operator yet.** This needs to be done **AFTER** the log store Operator!

---

## Assumptions

- You already have OpenShift up and running.
- You have enough resources to run a **Standalone Multicloud Object Gateway (MCG)**.  
  > Please note that standalone MCG is limited to 2TB backing store.
- An ODF Subscription Guide can be found here.
- You need to open BU guidance for now.
- You can skip to **Part 2** of this article if you already have a S3 bucket ready for use.
- If you just want to see how Loki is configured in these new versions, go to **Part 3** of this series of articles.

---

## Object Storage

This will be provided by **ODF's MCG**. You don't need to setup a full scale ODF with CephFS volumes. The operator provides all necessary software. If you deploy only the object storage, a lot of resources will be saved.

> ⚠️ Keep in mind that this is a stand-alone setup and provides no redundancy.

**Please remember:**

- MCG + Noobaa for Loki or Quay does not require an ODF subscription.
- You are limited to 2TB backing store.
- The Block, File and other storage types provided by ODF require a subscription.

---

## Machine Set

For production environments, create a **MachineSet (MS)** with `16 vCPU` and `32 GB RAM`.

For this lab, use a **8 vCPU / 16 GB RAM** MachineSet for the **MCG (Multicloud Object Gateway)**.  
You can use the following YAML as a template:

```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: homecloud-hqrlw
  name: homecloud-hqrlw-mcg
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: homecloud-hqrlw
      machine.openshift.io/cluster-api-machineset: homecloud-hqrlw-mcg
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: homecloud-hqrlw
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: homecloud-hqrlw-mcg
    spec:
      lifecycleHooks: {}
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
          node-role.kubernetes.io: infra
          node-role.kubernetes.io/worker: ""
          cluster.ocs.openshift.io/openshift-storage: ""
          env: odf
      providerSpec:
        value:
          apiVersion: machine.openshift.io/v1beta1
          credentialsSecret:
            name: vsphere-cloud-credentials
          diskGiB: 120
          kind: VSphereMachineProviderSpec
          memoryMiB: 16384
          metadata:
            creationTimestamp: null
          network:
            devices:
            - networkName: ocp-s3
          numCPUs: 8
          numCoresPerSocket: 8
          snapshot: ""
          template: homecloud-hqrlw-rhcos-homecloud-rio
          userDataSecret:
            name: worker-user-data
          workspace:
            datacenter: Datacenter
            datastore: /Datacenter/datastore/NETAC
            folder: /Datacenter/vm/OCP/S3/ODF
            resourcePool: /Datacenter/host/Homelab/Resources/rpool-s3
            server: X.X.X.X
      taints:
        - effect: NoSchedule
          key: node.ocs.openshift.io/storage
          value: "true"
```

Wait for the node to be **Ready** before moving on to the next steps.

---

## Machine Config Pool (MCP)

Create the **Machine Config Pool** definition. Use the YAML below as a template:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: odf
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
      env: odf
  paused: false
```

---

## Storage Class

Optionally, you can create a **Storage Class (SC)**.  
This is especially useful in a virtualized environment, to point to a different datastore for use as a **Noobaa backing store**.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc-odf-datastore
parameters:
  datastore: ASGARD
  fstype: ext4
  diskformat: thin
provisioner: kubernetes.io/vsphere-volume
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

---

## OpenShift Data Foundation Operator

Install the **ODF Operator**, but **do not create any storage subsystem yet!**

> Wait for the pods in the `openshift-storage` namespace to be in the **Running** state.

---

## Noobaa Backing Storage

The backing storage is a persistent volume for Noobaa. Without any ODF subscription, you can use a **2TB object storage volume**.

> You can't deploy a full scale ODF without a valid subscription.

Template YAML:

```yaml
apiVersion: noobaa.io/v1alpha1
kind: BackingStore
metadata:
  finalizers:
  - noobaa.io/finalizer
  labels:
    app: noobaa
  name: noobaa-pv-backing-store
  namespace: openshift-storage
spec:
  pvPool:
    numVolumes: 1
    resources:
      requests:
        storage: 500Gi
  type: pv-pool
```

---

## Storage System

Now you can create a **StorageSystem** of type **Multicloud Object Gateway**.

- Make sure you select the correct StorageClass (SC).
- Wait for the creation of all Noobaa resources.

If you check the PODs now, you should see PODs for **Noobaa Core, DB, Backing Storage, and Endpoint**.  
They should be running on a dedicated infra node.

---

## Check MCG Status

After a few minutes, verify that the MCG instance has finished provisioning:

```bash
$ oc get -n openshift-storage noobaas noobaa
NAME    S3-ENDPOINTS                  STS-ENDPOINTS                  SYSLOG-ENDPOINTS  IMAGE                                                                                                          PHASE AGE
noobaa ["https://10.2.224.180:32068"] ["https://10.2.224.180:32753"]                   registry.redhat.io/odf4/mcg-core-rhel9@sha256:78bdf7855b49d3f510b376e655e1782eb3b708dd788b203d4004732c25e8075a Ready 42h
```

---

## Replace the Default Backing Storage

The standard backing store is only **50GB**, which isn't enough for Loki.

### Inform the system that a backing store will be added manually

```bash
$ oc -n openshift-storage get backingstore
$ oc -n openshift-storage patch noobaa/noobaa   --type json --patch='[{"op":"add","path":"/spec/manualDefaultBackingStore","value":true}]'
```

### Change the default backing store for all OBCs

```bash
$ oc patch bucketclass noobaa-default-bucket-class   --patch '{"spec":{"placementPolicy":{"tiers":[{"backingStores":["noobaa-pv-backing-store"]}]}}}'   --type merge -n openshift-storage
```

If that doesn’t work, use this variation:

```bash
$ oc patch Bucketclass noobaa-default-bucket-class -n openshift-storage --type=json --patch='[{"op": "replace", "path": "/spec/placementPolicy/tiers/0/backingStores/0", "value": "noobaa-pv-backing-store"}]'
```

---

## Remove the Old Default Backing Storage

This step requires the **Noobaa CLI**.

```bash
$ tar xzvf noobaa-operator-v5.17.2-linux-amd64.tar.gz .
$ mv noobaa-operator /usr/local/bin/noobaa
$ oc project openshift-storage
$ noobaa account update admin@noobaa.io --new_default_resource=noobaa-pv-backing-store
```

Sample output:

```
INFO[0000] ❌ Not Found: NooBaaAccount "admin@noobaa.io"
INFO[0000] ✅ Exists: NooBaa "noobaa"
INFO[0000] ✅ Exists: Service "noobaa-mgmt"
INFO[0000] ✅ Exists: Secret "noobaa-operator"
INFO[0000] ✅ Exists: Secret "noobaa-admin"
INFO[0000] ✈️  RPC: account.read_account() Request: {Email:admin@noobaa.io}
WARN[0000] RPC: GetConnection creating connection to wss://localhost:44283/rpc/ 0xc00094e420
INFO[0000] RPC: Connecting websocket (0xc00094e420) &{RPC:0xc0000d2050 Address:wss://localhost:44283/rpc/ State:init WS:<nil> PendingRequests:map[] NextRequestID:0 Lock:{state:1 sema:0} ReconnectDelay:0s cancelPings:<nil>}
INFO[0000] RPC: Connected websocket (0xc00094e420) &{RPC:0xc0000d2050 Address:wss://localhost:44283/rpc/ State:init WS:<nil> PendingRequests:map[] NextRequestID:0 Lock:{state:1 sema:0} ReconnectDelay:0s cancelPings:<nil>}
INFO[0000] ✅ RPC: account.read_account() Response OK: took 0.7ms
INFO[0000] ✈️  RPC: account.update_account_s3_access() Request: {Email:admin@noobaa.io S3Access:true DefaultResource:0xc0001211e0 ForceMd5Etag:<nil> AllowBucketCreation:<nil> NsfsAccountConfig:<nil>}
INFO[0000] ✅ RPC: account.update_account_s3_access() Response OK: took 406.2ms
```

After running the above command, you can remove the old default backing store:

```bash
$ oc delete backingstore noobaa-default-backing-store -n openshift-storage | oc patch -n openshift-storage backingstore/noobaa-default-backing-store --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
```

### Verify

```bash
$ oc get backingstore
NAME                           TYPE      PHASE      AGE
noobaa-default-backing-store   pv-pool   Deleting   66m
noobaa-pv-backing-store        pv-pool   Ready      68m

$ oc get pods -n openshift-storage -o wide
NAME                                               READY   STATUS        RESTARTS   AGE   IP             NODE                             NOMINATED NODE   READINESS GATES
noobaa-core-0                                      2/2     Running       0          73m   10.228.18.2    homecloud-hqrlw-mcg-xvcmt        <none>           <none>
noobaa-db-pg-0                                     1/1     Running       0          73m   10.228.18.4    homecloud-hqrlw-mcg-xvcmt        <none>           <none>
noobaa-default-backing-store-noobaa-pod-5a488e78   1/1     Terminating   0          15m   10.228.18.11   homecloud-hqrlw-mcg-xvcmt        <none>           <none>
```