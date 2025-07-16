
Criar e Gerenciar Volumes Persistentes Locais para OpenShift Virtualization com NFS Provisioner Operator (em SNO)
Introdução
No OpenShift Virtualization, as máquinas virtuais (VMs) requerem armazenamento persistente para manter dados mesmo após reinicializações ou migrações. Esse armazenamento é fornecido por Persistent Volumes (PVs), que persistem além do ciclo de vida de pods ou VMs.
Este artigo demonstra como configurar e gerenciar volumes persistentes locais em um ambiente Single Node OpenShift (SNO) usando o NFS Provisioner Operator, uma solução de provisionamento dinâmico via NFS, ideal para laboratórios locais, testes e desenvolvimento com OpenShift Virtualization, especialmente quando não há um backend de armazenamento externo.

Contexto e Desafios em Ambientes SNO
Tradicionalmente, os PVs eram criados manualmente por administradores, exigindo pré-provisionamento e causando ineficiência. A chegada do provisionamento dinâmico via StorageClass simplificou esse processo, mas ambientes SNO, por padrão, não oferecem um provisionador de armazenamento nativo.

NFS Provisioner Operator como Solução
O NFS Provisioner Operator, disponível no OperatorHub.io, implanta um servidor NFS no próprio cluster e configura o provisionador de subdiretórios do projeto kubernetes-sigs/nfs-subdir-external-provisioner.
Vantagens em ambientes SNO:
Permite o provisionamento automático de volumes NFS para VMs.


Fácil instalação via OperatorHub ou linha de comando.


Solução leve para uso local, sem necessidade de storage externo.


Compatível com os discos virtuais usados por VMs do OpenShift Virtualization.



Como Funciona
O operador instala um servidor NFS dentro do cluster (em SNO).


Um StorageClass é criado apontando para o provisionador.


Quando uma VM solicita um PVC usando essa StorageClass, o provisionador cria um diretório no servidor NFS.


A VM monta esse volume e o utiliza como disco persistente.



Fluxo Geral


Etapa
Descrição
Instalar o NFS Provisioner
Via OperatorHub ou YAML
Criar StorageClass
Aponta para o provisionador NFS
Criar PVC para a VM
Usa a StorageClass NFS
Usar PVC na VM
VM monta o volume


Por que usar no SNO?
O Single Node OpenShift é ideal para testes e desenvolvimento locais, permitindo rodar OpenShift e Virtualization em um único nó físico. No entanto, ele não inclui um provisionador de storage dinâmico por padrão, limitando o uso de PVCs com VMs.
Com o NFS Provisioner Operator, você:
✅ Habilita o uso de volumes persistentes em VMs rodando no SNO
 ✅ Elimina a necessidade de soluções externas de storage
 ✅ Recria cenários reais de produção em laboratório

🛠️ Instalação passo a passo
1. Login e preparação
bash
# Login
oc login -u kubeadmin -p kubeadmin https://https://api.sno.testing:6443 

# Criar um novo namespace
oc new-project nfsprovisioner-operator

# Implantar o operador NFS Provisioner no terminal (Você também pode usar o Console OpenShift)

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



3. Criar diretório NFS local no nó SNO

# Verificar nós
oc get nodes
NAME                 STATUS   ROLES           AGE   VERSION
crc-8rwmc-master-0   Ready    master,worker   54d   v1.22.3+e790d7f

# Definir variável de ambiente para o nome do nó alvo
export target_node=$(oc get node --no-headers -o name|cut -d'/' -f2)
oc label node/${target_node} app=nfs-provisioner

# ssh para o nó
oc debug node/${target_node}

# Criar um diretório e configurar o rótulo Selinux.
$ chroot /host
$ mkdir -p /home/core/nfs
$ chcon -Rvt svirt_sandbox_file_t /home/core/nfs
$ exit; exit



4. Criar o servidor NFS via recurso NFSProvisioner
bash
# Criar Recurso Personalizado NFSProvisioner
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

# Verificar se o Servidor NFS está rodando
oc get pod
NAME                               READY   STATUS    RESTARTS   AGE
nfs-provisioner-77bc99bd9c-57jf2   1/1     Running   0          2m32s



5. Tornar o NFS StorageClass padrão

# Atualizar anotação do NFS StorageClass
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verificar o padrão próximo ao nfs StorageClass
oc get sc
NAME            PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs (default)   example.com/nfs   Delete          Immediate           false                  4m29s



✅ Validação

# Criar um PVC de teste
oc apply -f https://raw.githubusercontent.com/Jooho/jhouse_openshift/master/test_cases/operator/test/test-pvc.yaml
persistentvolumeclaim/nfs-pvc-example created

# Verificar o PV/PVC de teste
oc get pv, pvc

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                                                 STORAGECLASS   REASON   AGE
persistentvolume/pvc-e30ba0c8-4a41-4fa0-bc2c-999190fd0282   1Mi        RWX            Delete           Bound       nfsprovisioner-operator/nfs-pvc-example               nfs                     5s

NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/nfs-pvc-example   Bound    pvc-e30ba0c8-4a41-4fa0-bc2c-999190fd0282   1Mi        RWX            nfs            5s

Se o PVC estiver com STATUS = Bound, o provisionamento foi bem-sucedido.

Compatibilizar StorageProfile com o Virtualization
Para suportar volumeMode: Block e diferentes accessModes com OpenShift Virtualization:

oc get storageprofile


oc get storageprofile

NAME   AGE
nfs    73m



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




Considerações Finais
Com esse setup, seu ambiente SNO com OpenShift Virtualization pode provisionar armazenamento persistente de forma automática e reutilizável, utilizando apenas recursos locais do cluster.
Essa solução é ideal para:
Simular cenários de produção.


Realizar testes com alta fidelidade.


Evitar dependência de storage externo ou nuvens públicas.

