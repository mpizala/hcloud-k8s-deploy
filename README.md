# Rancher K8S Cluster at Hetzner Cloud

Simple create a Kubernetes Cluster with Rancher in Hetzner-Cloud

## Requirements

```
brew install hcloud rancher-cli
```

## How to use

```
Usage:  ./hcloud-k8s-deploy.sh --project <name> [OPTIONS]

Simple create a Kubernetes Cluster with Rancher in Hetzner-Cloud

Mandatory:
      --project <name>     Your Project Name will be use for hcloud-context and rancher-cluster name

Options:
      --enable-ha          Enable K8S-HA Setup
      --worker <n>         Number of Worker Nodes (default "1")

      --home-location      hcloud Datacenter ("fsn1"|"hel1"|"nbg1") (default "nbg1")

      -D, --debug          Enable debug mode
      -h, --help           Show help for more information
```

# Todos

* implement Lets Encrypt
* get kubectl config after setup
* auto-deploy hcloud volumes (hcloud-csi)
* try out hcloud cluster-provider
* rancher setup with rancher-data


<https://github.com/mxschmitt/ui-driver-hetzner>
<https://github.com/hetznercloud/hcloud-cloud-controller-manager>
<https://github.com/hetznercloud/csi-driver>

# Sample Logout

```
Goto https://console.hetzner.cloud/projects
and create 1) a hcloud project and 2) an api-token

Token:
Context hcloud-labs created and activated

Your ssh public key (/Users/mpizala/.ssh/id_rsa.pub)?: /Users/mpizala/.ssh/id_rsa.pub
hcloud: SSH key with the same fingerprint already exists (uniqueness_error)

Create Floating IP...
116.203.9.159 (default)

Deploy Rancher...
rancher-server has 94.130.177.131

Waiting for SSH is up...
Connection to 94.130.177.131 port 22 [tcp/ssh] succeeded!

Waiting for Rancher is up...
Rancher is up!

WebUI: https://94.130.177.131/
Username: admin
Password: xxx

Add certificate to your trust store (login.keychain)
1 certificate imported.

Create an API Key -> https://94.130.177.131/apikeys
Your API Key (Bearer Token):

Login to Rancher
The authenticity of server 'https://94.130.177.131' can't be established.
[snip]
Do you want to continue connecting (yes/no)? yes

Create Cluster...
Successfully created cluster hcloud-labs

Create Master Node (1)...
k8s-master-01 has 159.69.105.102

Create Worker Node (1)...
k8s-worker-01 has 159.69.105.230

Assign floating-ip to k8s-worker-01

Have fun!

WebUI: https://94.130.177.131/
Username: admin
Password: xxx
```
