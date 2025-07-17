# Step-by-Step: Create Admin User in OpenShift and Remove kubeadmin

## Step 1: Create the admin user with htpasswd

1. **Install the `htpasswd` tool** (on RHEL/Fedora systems):

   ```bash
   sudo yum install -y httpd-tools
   ```

2. **Create the password file:**

   ```bash
   htpasswd -c -B -b users.htpasswd admin password
   ```

   > To add more users to the file:

   ```bash
   htpasswd -B -b users.htpasswd user password
   ```

3. **Create the Secret in OpenShift with this file:**

   ```bash
   oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config
   ```

4. **Create the OAuth resource with the following content:**

   **File: `oauth.yaml`**

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

   **Apply with:**

   ```bash
   oc apply -f oauth.yaml
   ```

## Step 2: Grant cluster admin permissions to the admin user

```bash
oc adm policy add-cluster-role-to-user cluster-admin admin
```

## Step 3: Remove the kubeadmin user

1. **Delete the Secret with the kubeadmin password:**

   ```bash
   oc delete secret kubeadmin -n kube-system
   ```

2. **(Optional) Revoke active tokens for kubeadmin:**

   ```bash
   oc delete secret -n kube-system -l "kubernetes.io/service-account.name=kubeadmin"
   ```

## ✅ Result

- The `admin` user now has cluster-admin permissions.
- The `kubeadmin` user has been removed from the cluster for security purposes.