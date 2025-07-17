# Passo a Passo: Criar Usuário Admin no OpenShift e Remover o kubeadmin

## Passo 1: Criar o usuário admin com htpasswd

1. **Instalar a ferramenta `htpasswd`** (em sistemas RHEL/Fedora):

   ```bash
   sudo yum install -y httpd-tools
   ```

2. **Criar o arquivo de senhas:**

   ```bash
   htpasswd -c -B -b users.htpasswd admin senha
   ```

   > Para adicionar mais usuários ao arquivo:

   ```bash
   htpasswd -B -b users.htpasswd user senha
   ```

3. **Criar o Secret no OpenShift com esse arquivo:**

   ```bash
   oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config
   ```

4. **Criar o recurso OAuth com esse conteúdo:**

   **Arquivo: `oauth.yaml`**

   ```yaml
   ---
   apiVersion: config.openshift.io/v1
   kind: OAuth
   metadata:
     name: cluster
   spec:
     identityProviders:
     - name: my_htpasswd_provider
       mappingMethod: claim
       type: HTPasswd
       htpasswd:
         fileData:
           name: htpass-secret
   ```

   **Aplicar com:**

   ```bash
   oc apply -f oauth.yaml
   ```

## Passo 2: Conceder permissões de administrador ao usuário admin

```bash
oc adm policy add-cluster-role-to-user cluster-admin admin
```

## Passo 3: Remover o usuário kubeadmin

1. **Remover o Secret com a senha do kubeadmin:**

   ```bash
   oc delete secret kubeadmin -n kube-system
   ```

2. **(Opcional) Revogar tokens ativos do kubeadmin:**

   ```bash
   oc delete secret -n kube-system -l "kubernetes.io/service-account.name=kubeadmin"
   ```

## ✅ Resultado

- O usuário `admin` agora possui permissões administrativas.
- O usuário `kubeadmin` foi removido do cluster por segurança.