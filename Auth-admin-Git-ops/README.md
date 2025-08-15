# Definitive Guide: Configuring Admin Permissions in OpenShift GitOps

This guide resolves the `permission denied: repositories, create` error for a user authenticating via OpenShift (e.g., using `htpasswd`), even when the configuration appears to be correct.

## The Problem

* You have a user in OpenShift (e.g., an `admin` user from an `htpasswd` file).
* When attempting any action in Argo CD (like adding a repository), you receive a `permission denied` error.
* Manual changes to ConfigMaps (like `argocd-rbac-cm`) are reverted or do not work.

## Root Cause

1.  **Operator-Managed Configuration:** OpenShift GitOps is controlled by an Operator, which reverts manual changes made to its components. Configuration must be applied to the primary resource (`ArgoCD Custom Resource`).
2.  **Missing Identity Information (Scopes):** By default, Argo CD may not receive the user's complete profile information from OpenShift (such as the exact username). It needs to be explicitly instructed to request this data.

---

## Step-by-Step Solution

### Step 1: Identify the Exact Username

Before configuring, confirm the exact name OpenShift uses for your user.

1.  Log into OpenShift with your user account.
2.  Run the following command in your terminal:
    ```bash
    oc whoami
    ```
    The result (e.g., `admin`) is the name you will use in the permission policy.

### Step 2: Apply the Correct Configuration (in the ArgoCD CR)

This is the most critical step. We will permanently instruct the Operator which permissions to grant and what user information to request.

1.  Open the `ArgoCD` Custom Resource (CR) for editing:
    ```bash
    oc edit argocd openshift-gitops -n openshift-gitops
    ```

2.  Locate the `spec:` section and add (or modify) the `rbac:` block to look exactly like the example below. Replace `your-user-here` with the username you confirmed in Step 1.
    ```yaml
    spec:
      # ... (other settings may be here, do not delete them)

      # START OF THE BLOCK TO ADD/MODIFY
      rbac:
        # 1. Tells Argo CD to request the full user profile (name, email, groups)
        scopes: '[profile, email, groups]'

        # 2. Defines the permission policy
        policy: |
          # Default rules (good to have)
          g, system:cluster-admins, role:admin
          g, cluster-admins, role:admin
          
          # Your custom rule: gives the 'admin' role to your user
          g, your-user-here, role:admin
      # END OF BLOCK

      # ... (other settings may continue here)
    ```
3.  Save and close the file. The Operator will now apply this configuration.

### Step 3: Force a System and Session Refresh

To ensure the new configuration is loaded and that no old cache is interfering, force a restart of the key components and your session.

1.  Restart the Argo CD pods from your terminal:
    ```bash
    # Restart the main server
    oc rollout restart deployment/openshift-gitops-server -n openshift-gitops
    
    # Restart the authentication server
    oc rollout restart deployment/openshift-gitops-dex-server -n openshift-gitops
    ```
2.  Wait a minute or two for the new pods to reach the `Running` state.
3.  Perform a clean login:
    * Open a **new incognito/private browser window** (this prevents session caching).
    * Navigate to the Argo CD URL.
    * Log in using the main **`Log in via OpenShift`** option.

After following these three steps, your user will have the administrator permissions correctly applied in Argo CD, and the error will no longer occur.