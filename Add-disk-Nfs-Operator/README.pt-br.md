# Configuração de Novo SSD com NFS para OpenShift 4.19 SNO

Este guia descreve o passo a passo para preparar um novo SSD em um Single Node OpenShift (SNO) 4.19 baremetal, configurando-o como armazenamento NFS para uso em PersistentVolumes (PV) no OpenShift.

---

## Pré-requisitos

- Acesso SSH ao nó SNO.
- Disco SSD novo conectado, não particionado (ex: `/dev/sda`).
- OpenShift 4.19 instalado e configurado.
- Permissões para aplicar objetos no OpenShift (via `oc`).

---

## Passo a passo

### 1. Identificar o novo disco

```bash
lsblk -o NAME,SIZE,MOUNTPOINT

NAME        SIZE MOUNTPOINT
nvme0n1   931.5G 
├─nvme0n1p1   1M 
├─nvme0n1p2 127M 
├─nvme0n1p3 384M /boot
└─nvme0n1p4 931G /var
sda       931.5G 

```

---

### 2. Criar partição no disco usando `fdisk`

```bash
sudo fdisk /dev/sda
```

No prompt do `fdisk`:

```
Command (m for help): n
Partition number (1): 1
First sector: [ENTER]
Last sector: [ENTER]
Command (m for help): w
```

---

### 3. Criar sistema de arquivos ext4

```bash
sudo mkfs.ext4 /dev/sda1
```

---

### 4. Criar ponto de montagem e montar a partição

```bash
sudo mkdir -p /mnt/data-nfs1
sudo mount /dev/sda1 /mnt/data-nfs1
```

---

### 5. Configurar montagem automática


Descubra o UUID da partição:
##### OBS: Por que usar UUID?

O nome do dispositivo (ex: /dev/sda1) pode mudar se o disco for reconectado ou se outros dispositivos forem adicionados. O UUID é único e fixo para a partição, garantindo que o sistema sempre monte o disco correto.

```bash
sudo blkid /dev/sda1
```

```bash
echo 'UUID=<uuid-da-partição> /mnt/data-nfs1 ext4 defaults 0 0' | sudo tee -a /etc/fstab

```

---

### 6. Configurar exportação NFS

Edite o arquivo `/etc/exports` adicionando:

```
/mnt/data-nfs1 *(rw,sync,no_subtree_check,no_root_squash)
```

---

### 7. Aplicar exportação e iniciar serviços NFS

```bash
sudo exportfs -a
sudo exportfs -v
sudo systemctl enable --now rpcbind
sudo systemctl enable --now nfs-server
sudo systemctl restart nfs-server
```

---

### 8. Verificar exportação NFS

```bash
showmount -e localhost

Export list for localhost:
/mnt/data-nfs1  *
```

---

### 9. Criar PersistentVolume (PV) no OpenShift

Arquivo `pv-nfs-ssd.yaml`:

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
  storageClassName: seu-storageclass
  nfs:
    path: /mnt/data-nfs1
    server: <IP_DO_SNO>
```

Substitua `<IP_DO_SNO>` e `seu-storageclass` conforme seu ambiente.

---

### 10. Criar PersistentVolumeClaim (PVC)

Arquivo `pvc-nfs-teste.yaml`:

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
  storageClassName: seu-storageclass
```

---

### 11. Aplicar os manifests no OpenShift

```bash
oc apply -f pv-nfs-ssd.yaml
oc apply -f pvc-nfs-teste.yaml -n seu-projeto
```

Substitua `seu-projeto` pelo namespace da sua aplicação.

---

### 12. Verificar status do PV e PVC

```bash
oc get pv
oc get pvc -n seu-projeto
oc describe pvc pvc-nfs-test -n seu-projeto
```

---

## Notas

- O StorageClass pode ser um já existente no cluster.
- PVC deve estar no namespace do projeto da aplicação.
- PV e StorageClass são recursos cluster-wide e podem ser aplicados em qualquer namespace.

---