#!/bin/bash

CLUSTER=$1
TEAM=$2
PRODUCT=$3
COMPONENT=$4
KUBE_API=https://192.168.10.1:6443
KUBECONFIG_PATH=/root/.kube/config
TOKEN=
VAULT_HOST=vault-stg.dev.example.com
SECRET_FILE=$5

SECRET_PATH=$CLUSTER/$TEAM/$PRODUCT/$COMPONENT/data/env
ROLE_NAME=$CLUSTER-$TEAM-$PRODUCT-$COMPONENT
AUTH_PATH=$CLUSTER/$TEAM/$PRODUCT/$COMPONENT

printHelp() {
  echo "Usage: wrapper.sh <cluster> <team> <product> <component> <variables-filename>"
  echo "options:"
  echo "Note: variables file should be a valid json structure"
  echo "Please install jq and curl before running script"
  echo "eg: wrapper.sh stg boo zoo moo vars.json"

}

update(){
#Add or update secret variables
curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data @$SECRET_FILE \
    https://$VAULT_HOST/v1/$SECRET_PATH
}

setup() {
#Get Data from service account
set -xe
VAULT_SA_NAME=$(kubectl --kubeconfig=$KUBECONFIG_PATH get sa $COMPONENT -n $PRODUCT \
    -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(kubectl --kubeconfig=$KUBECONFIG_PATH get secret $VAULT_SA_NAME \
    -o jsonpath="{.data.token}" -n $PRODUCT | base64 --decode; echo)
SA_CA_CRT=$(kubectl --kubeconfig=$KUBECONFIG_PATH get secret $VAULT_SA_NAME \
    -o jsonpath="{.data['ca\.crt']}" -n $PRODUCT | base64 --decode; echo)

#Enable Kubernetes Auth method for AUTH_PATH

JSONPAYLOAD=$( jq -n \
                  --arg path "$AUTH_PATH" \
                  '{"type":"kubernetes", "path":$path}' )
echo $JSONPAYLOAD > /tmp/payload.json
curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data @/tmp/payload.json \
    https://$VAULT_HOST/v1/sys/auth/$AUTH_PATH

#CONFIG Kubernetes Auth method with service account for AUTH_PATH

JSONPAYLOAD=$( jq -n \
                  --arg ca "$SA_CA_CRT" \
                  --arg token "$SA_JWT_TOKEN" \
                  --arg host "$KUBE_API" \
                  '{"kubernetes_host":$host,"kubernetes_ca_cert":$ca, "token_reviewer_jwt" :$token}' )
echo $JSONPAYLOAD > /tmp/payload.json
curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data @/tmp/payload.json \
    https://$VAULT_HOST/v1/auth/$AUTH_PATH/config


#Enable KV secret Engine
JSONPAYLOAD='{ "type": "kv", "options" : {"version": "2"}}'
echo $JSONPAYLOAD > /tmp/payload.json
curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data @/tmp/payload.json \
    https://$VAULT_HOST/v1/sys/mounts/$AUTH_PATH

#Create read list policy for the secret engine
JSONPAYLOAD=$( jq -n \
                   --arg path "path \"$AUTH_PATH/data/*\" {capabilities = [\"read\", \"list\"]}" \
                  '{ "policy": $path }' )

echo $JSONPAYLOAD > /tmp/payload.json
curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data @/tmp/payload.json \
    https://$VAULT_HOST/v1/sys/policy/$ROLE_NAME-policy

#Bind Role of kubernetes auth method with policy of secret engine
JSONPAYLOAD=$( jq -n \
                   --arg sa "$COMPONENT" \
                   --arg ns "$PRODUCT" \
                   --arg policy "$ROLE_NAME-policy" \
                  '{"bound_service_account_names":$sa,"bound_service_account_namespaces":$ns,"policies":[$policy]}' )

echo $JSONPAYLOAD > /tmp/payload.json
curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data @/tmp/payload.json \
    https://$VAULT_HOST/v1/auth/$AUTH_PATH/role/$ROLE_NAME
update
}

printHelp
setup
