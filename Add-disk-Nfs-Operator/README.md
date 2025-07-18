# SSD Configuration with NFS for OpenShift 4.19 SNO

This guide provides a step-by-step process to prepare a new SSD on a Single Node OpenShift (SNO) 4.19 baremetal setup, configuring it as NFS storage for use in PersistentVolumes (PV) within OpenShift.

---

## Prerequisites

- SSH access to the SNO node.
- New SSD connected, unpartitioned (e.g., `/dev/sda`).
- OpenShift 4.19 installed and configured.
- Permissions to apply OpenShift objects (via `oc`).

---

## Step-by-step Guide

### 1. Identify the new disk

```bash
lsblk -o NAME,SIZE,MOUNTPOINT
```

Expected output:

```text
NAME        SIZE MOUNTPOINT
nvme0n1   931.5G 
├─nvme0n1p1   1M 
├─nvme0n1p2 127M 
├─nvme0n1p3 384M /boot
└─nvme0n1p4 931G /var
sda       931.5G 
```

### 2. Create a partition using `fdisk`

```bash
sudo fdisk /dev/sda
```

Inside `fdisk`:

```
Command (m for help): n
Partition number (1): 1
First sector: [ENTER]
Last sector: [ENTER]
Command (m for help): w
```

### 3. Create ext4 filesystem

```bash
sudo mkfs.ext4 /dev/sda1
```

### 4. Create mount point and mount the partition

```bash
sudo mkdir -p /mnt/data-nfs1
sudo mount /dev/sda1 /mnt/data-nfs1
```

### 5. Configure automatic mounting

##### Note: Why use UUID?
The device name (e.g., /dev/sda1) can change if the disk is reconnected or if new devices are added. The UUID is unique and persistent for the partition, ensuring the system always mounts the correct disk.

Get the UUID of the partition:

```bash
sudo blkid /dev/sda1
```

Append to `/etc/fstab`:

```bash
echo 'UUID=<uuid-partition-name> /mnt/data-nfs1 ext4 defaults 0 0' | sudo tee -a /etc/fstab

```

### 6. Configure NFS export

Edit `/etc/exports`:

```
/mnt/data-nfs1 *(rw,sync,no_subtree_check,no_root_squash)
```

### 7. Apply export and start NFS services

```bash
sudo exportfs -a
sudo exportfs -v
sudo systemctl enable --now rpcbind
sudo systemctl enable --now nfs-server
sudo systemctl restart nfs-server
```

### 8. Verify NFS export

```bash
showmount -e localhost
```

Expected output:

```text
Export list for localhost:
/mnt/data-nfs1  *
```

### 9. Create PersistentVolume (PV) in OpenShift

`pv-nfs-ssd.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs-ssd1
spec:
  capacity:
    storage: 930Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: your-storageclass
  nfs:
    path: /mnt/data-nfs1
    server: <SNO_IP>
```

Replace `<SNO_IP>` and `your-storageclass` as needed.

### 10. Create PersistentVolumeClaim (PVC)

`pvc-nfs-test.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs-test
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: your-storageclass
```

### 11. Apply manifests to OpenShift

```bash
oc apply -f pv-nfs-ssd.yaml
oc apply -f pvc-nfs-test.yaml -n your-project
```

Replace `your-project` with your app's namespace.

### 12. Verify PV and PVC status

```bash
oc get pv
oc get pvc -n your-project
oc describe pvc pvc-nfs-test -n your-project
```

---

## Notes

- The StorageClass can be an existing one in your cluster.
- PVC must be created in the namespace of your application.
- PV and StorageClass are cluster-wide resources and can be applied globally.