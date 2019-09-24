# K8S-Cluster with Rancher in Hetzner-Cloud

Simple create a Kubernetes Cluster with Rancher in Hetzner-Cloud

## Requirements

```
brew install hcloud rancher-cli jq
```

## How to use

```
Usage:  ./hcloud-k8s-deploy.sh --context <name> [OPTIONS]

Simple create a Kubernetes Cluster with Rancher in Hetzner-Cloud

Mandatory:
      --context <name>               Your Project Name will be use for hcloud-context and rancher-cluster name

Options:
      --rancher-version <version>    Rancher Version (Image Tag) (default "latest")
      --rancher-type <type>          Type of Rancher Node (default "cx21-ceph")

      --master <number>              Number of Master Nodes ("1"|"3"|"5") (default "1")
      --master-type <type>           Type of Master Nodes (default "cx31-ceph")

      --worker <number>              Number of Worker Nodes (default "1")
      --worker-type <type>           Type of Worker Nodes (default "cx31")

      --home-location <data-center>  hcloud Datacenter ("fsn1"|"hel1"|"nbg1") (default "nbg1")

      -D, --debug                    Enable debug mode
      -h, --help                     Show help for more information
```
# Edit Cloud-Config files

Cloud-Config files are now protected with .gitingore

You can update cloud-config folder and files with `git add -f`

# Todos

* implement Lets Encrypt
* <del>get kubectl config after setup</del>
* <del>auto-deploy hcloud volumes (hcloud-csi)</del>
* try out hcloud cluster-provider
* <del>rancher setup with rancher-data</del>


<https://github.com/mxschmitt/ui-driver-hetzner>

<https://github.com/hetznercloud/hcloud-cloud-controller-manager>

<https://github.com/hetznercloud/csi-driver>

# Sample Logout

```
```
