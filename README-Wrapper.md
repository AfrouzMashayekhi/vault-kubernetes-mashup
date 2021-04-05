# Wrapper manual
Wrapper is a bash script to create or update variable secrets in vault and integrate it with kubenretes authentication.
the usage of wrapper is `wrapper.sh <cluster> <team> <product> <component> <variables-filename>`
In wrapper script you should set below variables based on your working space and also the requirement of this script is jq and curl package so please before running script, install this packages.


KUBE_API: kube api address of kubernetes cluster which you need to vault authentication be integrated eg. https://192.168.10.1:6443

KUBECONFIG_PATH: kubeconfig path for getting service accounts and retrieve some data from kuberntes cluster eg. /root/.kube/config

TOKEN: the root token or the token which allowed to create auth, secret engines, plociy creation in vault cluster

VAULT_HOST: the https address of vault cluster eg. vault-stg.dev.example.com

SECRET_FILE= A json file which contains keys and values please assure that this file is a valid json file the key values should be in `data` block eg.
```json
{
"data": {
"foo": "bar",
"zip": "zap"
}}
```

## Secret Engine
the secret engine will be created in below path based on args 
`SECRET_PATH=$CLUSTER/$TEAM/$PRODUCT/$COMPONENT`
variables and env will be saved in the secret engine with the name of `env`
`SECRET_PATH=$CLUSTER/$TEAM/$PRODUCT/$COMPONENT/data/env`

## Kubernetes Auth
the wrapper will create an auth method of kubernetes in `$CLUSTER/$TEAM/$PRODUCT/$COMPONENT` path for every service account created in kubernetes and in the auth method it will create a role with the name of `$CLUSTER-$TEAM-$PRODUCT-$COMPONENT` in auth path

## Policy 
A policy `$CLUSTER-$TEAM-$PRODUCT-$COMPONENT-policy` will be created to bind secret engine `$CLUSTER/$TEAM/$PRODUCT/$COMPONENT` to the role `$CLUSTER-$TEAM-$PRODUCT-$COMPONENT` which is created in auth path `$CLUSTER/$TEAM/$PRODUCT/$COMPONENT`


## Annotation needed in deployment of application to bind vault to deployment
```yaml
annotations:
    #https://www.vaultproject.io/docs/platform/k8s/injector/annotations
    #enable injector 
    vault.hashicorp.com/agent-inject: "true"
    #kubernetes auth path 
    vault.hashicorp.com/auth-path: auth/$CLUSTER/$TEAM/$PRODUCT/$COMPONENT`
    # the role in kubernetes authentication
    vault.hashicorp.com/role: "$CLUSTER-$TEAM-$PRODUCT-$COMPONENT"
    # get data from vault again
    vault.hashicorp.com/agent-inject-status: "update"
    # data will be saved in /vault/secrets/FILEPATH like  "/vault/secrets/env"
    # FILEPATH is determined with agent-ingect-secret-FILEPATH
    # the value of this annotation is the path in vault
    # the path will be secret engine path+ /data/ + filename <env>
    # https://learn.hashicorp.com/tutorials/vault/kubernetes-sidecar#inject-secrets-into-the-pod
    vault.hashicorp.com/agent-inject-secret-env: "$CLUSTER/$TEAM/$PRODUCT/$COMPONENT/data/env"
    # if we want to be a connection string we can add secret's vaule to a template and write it in the file in /vault/secrets
    # https://learn.hashicorp.com/tutorials/vault/kubernetes-sidecar#apply-a-template-to-the-injected-secrets
    # Environment variable export template
    # for more example of agent : https://www.vaultproject.io/docs/platform/k8s/injector/examples
    #.data block is from secret json which contains data block and the keys 
    # we can change keys with export like below and set the value of key foo to username
    vault.hashicorp.com/agent-inject-template-env: |
    {{ with secret "$CLUSTER/$TEAM/$PRODUCT/$COMPONENT/data/env" -}}
    export USERNAME="{{ .Data.data.foo }}"
    export PASSWORD="{{ .Data.data.zip }}"
    {{- end }}


...

# and to run template inject we should add below cmd to export values  "-c", ". /vault/secrets/env && ...
containers:
  - image: ...
    command: [ "/bin/sh" ]
    # we had to add this to render file config and export variables
    args: [ "-c", ". /vault/secrets/env && ./entrypoint.sh" ]

```