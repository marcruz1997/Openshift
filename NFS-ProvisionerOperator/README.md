# Create and Manage Local Persistent Volumes for OpenShift Virtualization with NFS Provisioner Operator (on SNO)

## Introduction

In OpenShift Virtualization, virtual machines (VMs) require persistent storage to retain data even after reboots or migrations. This storage is provided by **Persistent Volumes (PVs)**, which persist beyond the lifecycle of pods or VMs.

This article demonstrates how to configure and manage local persistent volumes in a **Single Node OpenShift (SNO)** environment using the **NFS Provisioner Operator**, a dynamic NFS-based provisioning solution ideal for local labs, testing, and development with OpenShift Virtualization — especially when no external storage backend is available.

---

## Context and Challenges in SNO Environments

Traditionally, PVs were manually created by administrators, requiring pre-provisioning and leading to inefficiency. The advent of dynamic provisioning via `StorageClass` simplified this process, but SNO environments by default **do not provide a native storage provisioner**.

---

## NFS Provisioner Operator as a Solution

The **NFS Provisioner Operator**, available at [OperatorHub.io](https://operatorhub.io), deploys an NFS server within the cluster and sets up the subdirectory provisioner from the project [`kubernetes-sigs/nfs-subdir-external-provisioner`](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner).

### Advantages in SNO environments:

- ✅ Enables automatic NFS volume provisioning for VMs  
- ✅ Easy installation via OperatorHub or YAML  
- ✅ Lightweight solution for local use, no need for external storage  
- ✅ Compatible with the virtual disks used by OpenShift Virtualization VMs

---

## How It Works

1. The operator installs an NFS server inside the cluster (on SNO)  
2. A `StorageClass` is created pointing to the provisioner  
3. When a VM requests a `PVC` using that `StorageClass`, the provisioner creates a directory on the NFS server  
4. The VM mounts this volume and uses it as a persistent disk  

---

## General Flow

| Step                    | Description                        |
|-------------------------|--------------------------------|
| Install the NFS Provisioner | Via OperatorHub or YAML       |
| Create StorageClass       | Points to the NFS provisioner   |
| Create PVC for the VM     | Uses the NFS StorageClass       |
| Use PVC in the VM         | VM mounts the volume            |

---

## Why Use It in SNO?

**Single Node OpenShift** is ideal for local testing and development, allowing you to run OpenShift and Virtualization on a single physical node. However, it **does not include a default dynamic storage provisioner**, limiting PVC usage with VMs.

With the NFS Provisioner Operator, you:

- ✅ Enable persistent volume usage in VMs running on SNO  
- ✅ Eliminate the need for external storage solutions  
- ✅ Recreate production-like scenarios in your lab  

---

## 🛠️ Step-by-Step Installation

### 1. Login and Preparation

```bash
# Login to the cluster
oc login -u kubeadmin -p kubeadmin https://api.sno.testing:6443 

# Create a new namespace
oc new-project nfsprovisioner-operator
```

### 2. Deploy the NFS Provisioner Operator

``` yaml
cat << EOF | oc apply -f -  
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfs-provisioner-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: nfs-provisioner-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 3. Create Local NFS Directory on the SNO Node

```bash
# Check node names
oc get nodes
```
```bash
# Set variable with the target node name
export target_node=$(oc get node --no-headers -o name|cut -d'/' -f2)
```
```bash
# Add label to the node
oc label node/${target_node} app=nfs-provisioner
```

```bash
# Access via debug
oc debug node/${target_node}
```

```bash
# Inside the debug shell:
chroot /host
mkdir -p /home/core/nfs
chcon -Rvt svirt_sandbox_file_t /home/core/nfs
exit; exit
```

### 4. Create the NFS Server via NFSProvisioner Resource

```yaml
apiVersion: cache.jhouse.com/v1alpha1
kind: NFSProvisioner
metadata:
  name: nfsprovisioner-sample
  namespace: nfsprovisioner-operator
spec:
  nodeSelector: 
    app: nfs-provisioner
  hostPathDir: "/home/core/nfs"
```

```bash
# Apply the resource
oc apply -f nfsprovisioner.yaml
```

```bash
# Check pod
oc get pods -n nfsprovisioner-operator
```

### 5. Set NFS StorageClass as Default

```bash
# Update StorageClass annotation
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

```bash 
# Verify the update
oc get sc
```

### 6. ✅ Provisioning Validation

```bash
#Create Test PVC
oc apply -f https://raw.githubusercontent.com/Jooho/jhouse_openshift/master/test_cases/operator/test/test-pvc.yaml
```

```bash 
# Check PVC and PV
oc get pv,pvc
```

##### If the PVC STATUS = Bound, provisioning was successful!

### 7. Make StorageProfile Compatible with Virtualization

```bash
# List StorageProfiles
oc get storageprofile
```

```bash
# Update the NFS StorageProfile
oc patch storageprofile nfs --type=merge -p '{
  "spec": {
    "claimPropertySets": [
      {
        "accessModes": ["ReadWriteOnce", "ReadWriteMany", "ReadOnlyMany"],
        "volumeMode": "Filesystem"
      },
      {
        "accessModes": ["ReadWriteOnce", "ReadWriteMany", "ReadOnlyMany"],
        "volumeMode": "Block"
      }
    ]
  }
}'
```

### 8. ✅ Final Considerations
With this setup, your SNO environment with OpenShift Virtualization can automatically and reliably provision persistent storage using only local cluster resources.

This solution is ideal for:

🔁 Simulating production scenarios

🧪 Performing high-fidelity testing

☁️ Avoiding reliance on external or public cloud storage
