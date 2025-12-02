# Configuração de Interface Secundária com NNCP para uso como Bridge em VMs no OpenShift Virtualization

O primeiro passo para habilitar interfaces secundárias dedicadas às VMs
no OpenShift Virtualization é instalar o NMState Operator, responsável
por gerenciar configurações de rede nos nodes de forma declarativa.

## 1. Instalar o NMState Operator

A instalação é feita via **OperatorHub**:

-   Acesse **Operators → OperatorHub**
-   Busque por **NMState**
-   Clique em **Install**
-   Aguarde até que o operador esteja ativo

## 2. Verificar interfaces disponíveis no Node

Com o operador instalado, acesse:

**Networking → NodeNetworkState**

Ali você verá todas as interfaces disponíveis em cada node do cluster.

> ⚠️ **Atenção:**\
> A interface usada pelo cluster como rede de gerenciamento (geralmente
> associada à `br-ex`) **não pode ser utilizada** para criar bridges de
> VMs.\
> Use apenas interfaces físicas adicionais livres.

## 3. Criar o NNCP para transformar a interface física em uma Linux Bridge

Após identificar a interface disponível, crie um
**NodeNetworkConfigurationPolicy (NNCP)** definindo uma *linux-bridge*
que será usada pelas VMs.

A bridge será responsável por conectar as VMs à rede física e, caso
exista DHCP, elas poderão receber IP automaticamente.

### Exemplo de YAML:

``` yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  annotations:
    description: 'bridge das VMs para a rede'
  name: bridge-vms-lan
spec:
  desiredState:
    interfaces:
      - name: br-vms
        type: linux-bridge
        state: up
        bridge:
          options:
            stp:
              enabled: false
          port:
            - name: enp7s0   # Nome da interface disponível para uso
```

## 4. Validar aplicação da configuração nos nodes

Após a criação do NNCP, verifique se a configuração foi aplicada:

-   Acesse **Compute → NodeNetworkConfigurationPolicy**
-   Confirme o status como **Available**
-   Confira se os nodes receberam a configuração (de acordo com
    *nodeSelector*, se usado)

> 🔄 **Importante:**\
> Se precisar editar o NNCP, primeiro altere o `state` para **absent**,
> permitindo que o operador remova a configuração anterior.\
> Somente depois aplique a nova versão.

## 5. Criar a NetworkAttachmentDefinition (NAD)

Com a bridge criada nos nodes, agora é necessário criar o **NAD**, que
será a interface de rede disponível para anexar às VMs.

### Exemplo:

``` yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: teste
  namespace: default
spec:
  config: |-
    {
      "cniVersion": "0.3.1",
      "name": "teste",
      "type": "bridge",
      "bridge": "br-vms",
      "ipam": {},
      "macspoofchk": false,
      "preserveDefaultVlan": false
    }
```

📌 **Observação:**

O NAD pode ser criado:

-   No namespace **default**, ficando disponível para todas as VMs do
    cluster\
-   Em um **namespace específico**, ficando visível apenas dentro dele

## 6. Conectar a VM à Bridge

Ao criar a VM:

1.  Vá até a seção **Network**
2.  Adicione uma nova interface
3.  Selecione o NAD criado (ex.: `teste`)
4.  Finalize a criação da VM

Se a rede possuir DHCP, a VM receberá o IP automaticamente.\
Caso contrário, configure o IP manualmente dentro da VM (ex.: `nmtui`,
`nmcli` ou edição de arquivos de rede).
