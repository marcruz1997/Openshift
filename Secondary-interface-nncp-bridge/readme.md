# Secondary Interface Configuration with NNCP for Use as a Bridge in OpenShift Virtualization VMs

The first step to enable dedicated secondary interfaces for VMs in
OpenShift Virtualization is to install the **NMState Operator**, which
is responsible for managing network configurations on cluster nodes in a
declarative way.

## 1. Install the NMState Operator

Installation is done through the **OperatorHub**:

-   Go to **Operators → OperatorHub**
-   Search for **NMState**
-   Click **Install**
-   Wait until the operator becomes active

## 2. Check available interfaces on the Node

Once the operator is installed, navigate to:

**Networking → NodeNetworkState**

There you will find all network interfaces available on each cluster
node.

> ⚠️ **Attention:**\
> The interface used by the cluster as the management network (usually
> associated with `br-ex`) **cannot be used** to create VM bridges.\
> Only use additional free physical interfaces.

## 3. Create the NNCP to convert a physical interface into a Linux Bridge

After identifying an available interface, create a
**NodeNetworkConfigurationPolicy (NNCP)** defining a *linux-bridge* to
be used by the VMs.

The bridge will connect the VMs to the physical network and, if DHCP is
available, the VMs can automatically receive an IP address.

### YAML example:

``` yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  annotations:
    description: 'VM bridge for LAN access'
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
            - name: enp7s0   # Name of the available interface
```

## 4. Validate that the configuration was applied to the nodes

After creating the NNCP, verify its application:

-   Go to **Compute → NodeNetworkConfigurationPolicy**
-   Confirm that the status is **Available**
-   Check whether the nodes received the configuration (based on any
    applied `nodeSelector`)

> 🔄 **Important:**\
> If you need to edit the NNCP, first change the `state` to **absent**
> so the operator removes the previous configuration.\
> Only then apply the new version.

## 5. Create the NetworkAttachmentDefinition (NAD)

With the bridge created on the nodes, you must now create the **NAD**,
which will serve as the network interface available for VM attachment.

### Example:

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

📌 **Note:**

You may create the NAD:

-   In the **default** namespace, making it available to all VMs in the
    cluster\
-   In a **specific namespace**, making it visible only within that
    namespace

## 6. Connect the VM to the Bridge

When creating the VM:

1.  Go to the **Network** section\
2.  Add a new interface\
3.  Select the created NAD (e.g., `teste`)\
4.  Complete the VM creation

If the network has DHCP, the VM will automatically receive an IP
address.\
Otherwise, configure the IP manually inside the VM (using `nmtui`,
`nmcli`, or network configuration files).
