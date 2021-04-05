https://www.consul.io/docs/k8s/installation/install
https://learn.hashicorp.com/tutorials/vault/ha-with-consul?in=vault/day-one-consul

#checklist 
https://www.vaultproject.io/docs/platform/k8s/helm/run#production-deployment-checklist
https://learn.hashicorp.com/tutorials/vault/production-hardening?in=vault/day-one-consul
https://learn.hashicorp.com/tutorials/vault/raft-reference-architecture?in=vault/day-one-raft
#Setup consul
```shell
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
#helm install consul-stage hashicorp/consul -n vault-stage
helm install --kubeconfig=/root/.kube/config consul-stage hashicorp/consul -f consul-values.yaml  -n vault-stage
```
#Setup Vault
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
kubectl create ns vault-stage
#helm install vault-stage hashicorp/vault -n vault-stage
helm install --kubeconfig=/root/.kube/config vault-stage hashicorp/vault -f values-ha.yaml  -n vault-stage
```
#Init

```shell
stage-kubectl apply -f consul-ui-ingress.yaml
stage-kubectl apply -f vault-ui-ingress.yaml
```
open ui in browser and init vault in browser `vault-stg.dev.example.com`
enter 5 shared key and threshold 3 key download key file and unseal 
if it doesn't unseall run below in each terminal of pods in vault-ha-stage
```shell
# all the pods should be unseal and running status in the log of pods it has be shown that pods are unsealed and in standby mode or leader mode

vault operator unseal
```
NOTE: 
if you don't use ui for init and unsealing use cli
in cli of pods run `vault operator init` in JUST one of the vault pods and get unsealing keys and run `vault operator unseal` for ALL pods
