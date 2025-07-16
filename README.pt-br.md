# Criar e Gerenciar Volumes Persistentes Locais para OpenShift Virtualization com NFS Provisioner Operator (em SNO)

## Introdução

No OpenShift Virtualization, as máquinas virtuais (VMs) requerem armazenamento persistente para manter dados mesmo após reinicializações ou migrações. Esse armazenamento é fornecido por **Persistent Volumes (PVs)**, que persistem além do ciclo de vida de pods ou VMs.

Este artigo demonstra como configurar e gerenciar volumes persistentes locais em um ambiente **Single Node OpenShift (SNO)** usando o **NFS Provisioner Operator**, uma solução de provisionamento dinâmico via NFS, ideal para laboratórios locais, testes e desenvolvimento com OpenShift Virtualization — especialmente quando não há um backend de armazenamento externo.

---

## Contexto e Desafios em Ambientes SNO

Tradicionalmente, os PVs eram criados manualmente por administradores, exigindo pré-provisionamento e causando ineficiência. A chegada do provisionamento dinâmico via `StorageClass` simplificou esse processo, mas ambientes SNO, por padrão, **não oferecem um provisionador de armazenamento nativo**.

---

## NFS Provisioner Operator como Solução

O **NFS Provisioner Operator**, disponível no [OperatorHub.io](https://operatorhub.io), implanta um servidor NFS no próprio cluster e configura o provisionador de subdiretórios do projeto [`kubernetes-sigs/nfs-subdir-external-provisioner`](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner).

### Vantagens em ambientes SNO:

- ✅ Permite o provisionamento automático de volumes NFS para VMs  
- ✅ Instalação fácil via OperatorHub ou YAML  
- ✅ Solução leve para uso local, sem necessidade de storage externo  
- ✅ Compatível com os discos virtuais usados por VMs do OpenShift Virtualization

---

## Como Funciona

1. O operador instala um servidor NFS dentro do cluster (em SNO)  
2. Um `StorageClass` é criado apontando para o provisionador  
3. Quando uma VM solicita um `PVC` usando essa `StorageClass`, o provisionador cria um diretório no servidor NFS  
4. A VM monta esse volume e o utiliza como disco persistente  

---

## Fluxo Geral

| Etapa                   | Descrição                        |
|-------------------------|--------------------------------|
| Instalar o NFS Provisioner | Via OperatorHub ou YAML       |
| Criar StorageClass       | Aponta para o provisionador NFS |
| Criar PVC para a VM      | Usa a StorageClass NFS          |
| Usar PVC na VM           | VM monta o volume               |

---

## Por que usar no SNO?

O **Single Node OpenShift** é ideal para testes e desenvolvimento locais, permitindo rodar OpenShift e Virtualization em um único nó físico. No entanto, ele **não inclui um provisionador de storage dinâmico por padrão**, limitando o uso de PVCs com VMs.

Com o NFS Provisioner Operator, você:

- ✅ Habilita o uso de volumes persistentes em VMs rodando no SNO  
- ✅ Elimina a necessidade de soluções externas de storage  
- ✅ Recria cenários reais de produção em laboratório  

---

## 🛠️ Instalação Passo a Passo

### 1. Login e Preparação

```bash
# Login no cluster
oc login -u kubeadmin -p kubeadmin https://api.sno.testing:6443 

# Criar um novo namespace
oc new-project nfsprovisioner-operator
```

### 2. Implantar o NFS Provisioner Operator

``` yaml

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
```

```bash
# Aplicar o manifest
oc apply -f subscription.yaml
```

### 3. Criar Diretório NFS Local no Nó SNO

```bash
# Verificar nome dos nós
oc get nodes
```
```bash
# Definir variável com o nome do nó alvo
export target_node=$(oc get node --no-headers -o name|cut -d'/' -f2)
```
```bash
# Adicionar label no nó
oc label node/${target_node} app=nfs-provisioner
```

```bash
# Acessar via debug
oc debug node/${target_node}
```

```bash
# Dentro do shell do debug:
chroot /host
mkdir -p /home/core/nfs
chcon -Rvt svirt_sandbox_file_t /home/core/nfs
exit; exit
```


### 4. Criar o Servidor NFS via Recurso NFSProvisioner

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
# Aplicar o recurso
oc apply -f nfsprovisioner.yaml
```

```bash
# Verificar pod
oc get pods -n nfsprovisioner-operator
```

### 5. Tornar o StorageClass NFS como Padrão


```bash
# Atualizar anotação do StorageClass
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

```bash 
# Verificar se foi atualizado
oc get sc
```

### 6. ✅ Validação do Provisionamento


```bash
#Criar PVC de Teste
oc apply -f https://raw.githubusercontent.com/Jooho/jhouse_openshift/master/test_cases/operator/test/test-pvc.yaml
```

```bash 
# Verificar PVC e PV

oc get pv,pvc
```
##### Se o PVC estiver com STATUS = Bound, o provisionamento foi bem-sucedido!

### 7. Compatibilizar StorageProfile com o Virtualization

```bash
# Listar StorageProfiles
oc get storageprofile
```

```bash
# Atualizar o StorageProfile do NFS
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

### 8. ✅ Considerações Finais
Com esse setup, seu ambiente SNO com OpenShift Virtualization pode provisionar armazenamento persistente de forma automática e reutilizável, utilizando apenas recursos locais do cluster.

Essa solução é ideal para:

🔁 Simular cenários de produção

🧪 Realizar testes com alta fidelidade

☁️ Evitar dependência de storage externo ou nuvens públicas

---







