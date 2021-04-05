```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
kubectl create ns vault-stage
#helm install vault-stage hashicorp/vault -n vault-stage
helm install --kubeconfig=/root/.kube/config vault-stage hashicorp/vault -f values.yaml  -n vault-stage

```
vault initilazation
```shell
/ $ vault operator init

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 3 key to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```
vault seal
use keys above to unseal the threshold is 3 so you should use 3 key to unseal
```bash
/ $  vault operator unseal ...
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    1/3
Unseal Nonce       351321e4-3a0c-7420-5b20-3ac2c6d2b5cc
Version            1.6.2
Storage Type       file
HA Enabled         false
/ $  vault operator unseal ...
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    2/3
Unseal Nonce       351321e4-3a0c-7420-5b20-3ac2c6d2b5cc
Version            1.6.2
Storage Type       file
HA Enabled         false
/ $  vault operator unseal ...
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         1.6.2
Storage Type    file
Cluster Name    vault-cluster-03dec6cc
Cluster ID      e48124fe-afcc-e0dd-f2b1-a6f01b4ca37a
HA Enabled      false
```

auth method

```shell
vault auth enable kubernetes
kubectl get sa vault-auth     -o jsonpath="{.secrets[*]['name']}" -n vault-test
export SA_JWT_TOKEN=$(kubectl get secret vault-auth-token-tzf2j   -o jsonpath="{.data.token}" -n vault-test | base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret vault-auth-token-tzf2j  -o jsonpath="{.data['ca\.crt']}" -n vault-test | base64 --decode; echo)
vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="https://192.168.10.1:6443" \
        kubernetes_ca_cert="$SA_CA_CRT"
vault write auth/kubernetes/role/test \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=vault-test \
        policies=myapp-kv-ro \
        ttl=24h
```

Test:
```shell
kubectl create serviceaccount vault-auth -n vault-test
kubectl apply -f vault-sa.yaml
vault secrets enable myapp

vault policy write myapp-kv-ro - <<EOF
path "secret/data/myapp/*" {
    capabilities = ["read", "list"]
}
EOF

kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7 -n vault-test
/# apk update
/# apk add curl jq

/# KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
/# echo $KUBE_TOKEN

/# curl --request POST \
        --data '{"jwt": "'"$KUBE_TOKEN"'", "role": "test"}' \
        http://vault-stage.vault-stage:8200/v1/auth/kubernetes/login | jq


```
# add to deployment
https://learn.hashicorp.com/tutorials/vault/kubernetes-sidecar#launch-an-application

### OverAll
1. for accessing kubernetes to vault you should enable kuberenetes auth method
2. create a secret key value or anything set policy for read creation deletion... (deletion not recommended)
3. create a service account in kubernetes
4. create a role in method kubernetes of vault and assign service account to it.