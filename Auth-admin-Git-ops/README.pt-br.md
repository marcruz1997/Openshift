# Guia Definitivo: Configurando Permissões de Admin no OpenShift GitOps

Este guia resolve o erro `permission denied: repositories, create` para um usuário que se autentica via OpenShift (ex: `htpasswd`), mesmo quando as configurações parecem corretas.

## Contexto do Problema

* Você tem um usuário no OpenShift (ex: `admin` de um `htpasswd`).
* Ao tentar fazer qualquer ação no Argo CD (como adicionar um repositório), você recebe um erro de `permission denied`.
* As alterações manuais em ConfigMaps (como `argocd-rbac-cm`) são revertidas ou não funcionam.

## Causa Raiz

1.  **Gerenciamento por Operador:** O OpenShift GitOps é controlado por um Operador, que desfaz alterações manuais em seus componentes. A configuração deve ser feita no recurso principal (`ArgoCD Custom Resource`).
2.  **Falta de Informação de Identidade (Scopes):** Por padrão, o Argo CD pode não receber do OpenShift as informações completas do perfil do usuário (como o nome de usuário exato). Ele precisa ser instruído a solicitar esses dados.

---

## Passo a Passo para a Solução

### Passo 1: Identificar o Nome de Usuário Exato

Antes de configurar, confirme o nome exato que o OpenShift usa para o seu usuário.

1.  Faça login no OpenShift com o seu usuário.
2.  Execute no terminal:
    ```bash
    oc whoami
    ```
    O resultado (ex: `admin`) é o nome que você usará na política de permissão.

### Passo 2: Configurar a Permissão da Forma Correta (no ArgoCD CR)

Esta é a etapa mais importante. Vamos dizer ao Operador, de forma permanente, qual permissão dar e quais informações do usuário ele deve solicitar.

1.  Abra o Recurso Personalizado (CR) do `ArgoCD` para edição:
    ```bash
    oc edit argocd openshift-gitops -n openshift-gitops
    ```

2.  Localize a seção `spec:` e adicione (ou modifique) o bloco `rbac:` para que fique exatamente como abaixo. Substitua `seu-usuario-aqui` pelo nome de usuário que você confirmou no Passo 1.
    ```yaml
    spec:
      # ... (pode haver outras configurações aqui, não as apague)

      # INÍCIO DO BLOCO A SER ADICIONADO/MODIFICADO
      rbac:
        # 1. Diz ao Argo CD para pedir o perfil completo do usuário (nome, email, grupos)
        scopes: '[profile, email, groups]'

        # 2. Define a política de permissão
        policy: |
          # Regras padrão (bom ter)
          g, system:cluster-admins, role:admin
          g, cluster-admins, role:admin
          
          # Sua regra personalizada: dá a role 'admin' para o seu usuário
          g, seu-usuario-aqui, role:admin
      # FIM DO BLOCO

      # ... (outras configurações podem continuar aqui)
    ```
3.  Salve e feche o arquivo. O Operador agora aplicará essa configuração.

### Passo 3: Forçar a Atualização do Sistema e da Sessão

Para garantir que a nova configuração seja carregada e não haja nenhum cache antigo atrapalhando, force a reinicialização dos componentes chave e da sua sessão.

1.  Reinicie os pods do Argo CD no terminal:
    ```bash
    # Reinicia o servidor principal
    oc rollout restart deployment/openshift-gitops-server -n openshift-gitops
    
    # Reinicia o servidor de autenticação
    oc rollout restart deployment/openshift-gitops-dex-server -n openshift-gitops
    ```
2.  Aguarde um ou dois minutos para que os novos pods estejam no estado `Running`.
3.  Faça um novo login limpo:
    * Abra uma **nova janela anônima** no seu navegador (isso evita cache de sessão).
    * Acesse a URL do Argo CD.
    * Faça login usando a opção principal **`Log in via OpenShift`**.

Após seguir estes três passos, seu usuário terá as permissões de administrador corretamente aplicadas no Argo CD e o erro não ocorrerá mais.