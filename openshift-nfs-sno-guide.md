# Creating and Managing Local Persistent Volumes for OpenShift Virtualization with NFS Provisioner Operator (on SNO)

## 📘 Introduction

In OpenShift Virtualization, virtual machines (VMs) require **persistent storage** to retain data even after reboots or migrations. This storage is provided by **Persistent Volumes (PVs)**, which exist independently of the lifecycle of pods or VMs.

This article demonstrates how to configure and manage **local persistent volumes in a Single Node OpenShift (SNO)** environment using the **NFS Provisioner Operator** — a dynamic NFS-based provisioning solution ideal for local labs, testing, and development scenarios with OpenShift Virtualization, especially when no external storage backend is available.

---

## ⚙️ Context and Challenges in SNO Environments

Traditionally, PVs were manually created by administrators, requiring pre-provisioning and leading to inefficiencies. The advent of **dynamic provisioning** through `StorageClass` streamlined this process. However, **SNO environments do not include a built-in dynamic storage provisioner** by default.

---

## 💡 NFS Provisioner Operator as a Solution

The **NFS Provisioner Operator**, available via [OperatorHub.io](https://operatorhub.io), deploys an **NFS server inside the cluster** and configures the [subdirectory external provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) from Kubernetes.

### ✅ Benefits in SNO Environments:

- Enables automatic NFS volume provisioning for VMs  
- Easy installation via OperatorHub or CLI  
- Lightweight and suitable for local use  
- Fully compatible with virtual disks used by OpenShift Virtualization VMs

---

## 🧠 How It Works

1. The operator deploys an **NFS server** within the SNO cluster.
2. A **StorageClass** is created to use the NFS provisioner.
3. When a VM requests a **PersistentVolumeClaim (PVC)** using this `StorageClass`, the provisioner creates a directory inside the NFS server.
4. The VM mounts this volume and uses it as a persistent disk.

---

## 🧭 General Workflow

| Step                     | Description                           |
|--------------------------|---------------------------------------|
| Install NFS Provisioner  | Via OperatorHub or YAML               |
| Create StorageClass      | Points to the NFS provisioner         |
| Create PVC for the VM    | Uses the NFS StorageClass             |
| Use PVC inside the VM    | VM mounts the volume for persistence  |

---

## 🧩 Why Use This on SNO?

**Single Node OpenShift (SNO)** is ideal for local testing and development, running OpenShift and OpenShift Virtualization on a single physical node. However, it lacks a native dynamic storage provisioner by default, which limits the use of PVCs with VMs.

With the **NFS Provisioner Operator**, you can:

- ✅ Enable persistent volume support for VMs running on SNO  
- ✅ Eliminate the need for external storage solutions  
- ✅ Recreate production-like scenarios in your lab environment

---

## 🛠️ Step-by-Step Installation

### 1. Login and Environment Preparation

```bash
# Login to OpenShift
oc login -u kubeadmin -p kubeadmin https://api.sno.testing:6443 

# Create a new namespace
oc new-project nfsprovisioner-operator
2. Deploy the NFS Provisioner Operator
bash
Copy
Edit
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
3. Create a Local NFS Directory on the SNO Node
bash
Copy
Edit
# Check the nodes
oc get nodes

# Set environment variable for the target node name
export target_node=$(oc get node --no-headers -o name | cut -d'/' -f2)

# Label the node
oc label node/${target_node} app=nfs-provisioner
4. Create Directory and Set SELinux Labels
bash
Copy
Edit
# SSH into the node
oc debug node/${target_node}

# Inside the debug shell:
chroot /host
mkdir -p /home/core/nfs
chcon -Rvt svirt_sandbox_file_t /home/core/nfs

# Exit the debug session
exit; exit
5. Create the NFS Server using the Custom Resource
bash
Copy
Edit
cat << EOF | oc apply -f -  
apiVersion: cache.jhouse.com/v1alpha1
kind: NFSProvisioner
metadata:
  name: nfsprovisioner-sample
  namespace: nfsprovisioner-operator
spec:
  nodeSelector: 
    app: nfs-provisioner
  hostPathDir: "/home/core/nfs"
EOF
bash
Copy
Edit
# Check the NFS server pod
oc get pod
Expected output:

text
Copy
Edit
NAME                               READY   STATUS    RESTARTS   AGE
nfs-provisioner-xxxxxxx-xxxxx      1/1     Running   0          Xm
6. Make the NFS StorageClass the Default
bash
Copy
Edit
# Patch the StorageClass to make it default
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Confirm it
oc get sc
Expected:

text
Copy
Edit
NAME            PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs (default)   example.com/nfs   Delete          Immediate           false                  Xm
7. Validation
bash
Copy
Edit
# Apply a test PVC
oc apply -f https://raw.githubusercontent.com/Jooho/jhouse_openshift/master/test_cases/operator/test/test-pvc.yaml

# Check PVC and PV
oc get pv, pvc
Expected output:

text
Copy
Edit
persistentvolume/pvc-xxxxxxxx...   1Mi   RWX   Delete   Bound   nfs-pvc-example   nfs   ...
persistentvolumeclaim/nfs-pvc-example   Bound   pvc-xxxxxxxx...   1Mi   RWX   nfs   ...
8. Make the StorageProfile Compatible with Virtualization
bash
Copy
Edit
# List StorageProfiles
oc get storageprofile

# Patch the profile for block mode
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
⚠️ Note: Adjust accessModes according to your application’s requirements and test accordingly.

✅ Final Considerations
With this setup, your SNO environment with OpenShift Virtualization can dynamically provision persistent storage using only local resources.

This solution is ideal for:

Simulating production-like scenarios

High-fidelity testing environments

Avoiding dependence on external storage solutions or cloud providers

