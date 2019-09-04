# K8S-Cluster with Rancher in Hetzner-Cloud

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
      --project <name>               Your Project Name will be use for hcloud-context and rancher-cluster name

Options:
      --rancher-version <version>    Rancher Version (Image Tag) (default "latest")
      --enable-ha                    Enable K8S-HA Setup
      --worker <number>              Number of Worker Nodes (default "1")

      --home-location <data-center>  hcloud Datacenter ("fsn1"|"hel1"|"nbg1") (default "nbg1")

      -D, --debug                    Enable debug mode
      -h, --help                     Show help for more information
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
./hcloud-k8s-deploy.sh \
	--project labs \
	--rancher-version 2.2.8 \
	--enable-ha \
	--worker 5

Goto https://console.hetzner.cloud/projects
and create 1) a hcloud project and 2) an api-token

Token:
Context labs created and activated

Your ssh public key (/Users/mpizala/.ssh/id_rsa.pub)?: /Users/mpizala/.ssh/id_rsa.pub
hcloud: SSH key with the same fingerprint already exists (uniqueness_error)

Create Floating-IP...
116.203.9.153 (default)

Deploy Rancher...
rancher-server has 116.203.61.197

Waiting for SSH is up...
Connection to 116.203.61.197 port 22 [tcp/ssh] succeeded!

Waiting for Rancher is up...
Rancher is up!

WebUI: https://116.203.61.197/
Username: admin
Password: xxx

Add certificate to your trust store (login.keychain)
1 certificate imported.

Create an API Key -> https://116.203.61.197/apikeys
Your API Key (Bearer Token):

Login to Rancher
The authenticity of server 'https://116.203.61.197' can't be established.
Cert chain is : [Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 7863633936770576905 (0x6d213d66f4eab209)
    Signature Algorithm: SHA256-RSA
        Issuer: O=the-ranch,CN=cattle-ca
        Validity
            Not Before: Sep 4 22:40:56 2019 UTC
            Not After : Sep 3 22:44:12 2020 UTC
        Subject: O=the-ranch,CN=cattle
        Subject Public Key Info:
            Public Key Algorithm: RSA
                Public-Key: (2048 bit)
                Modulus:
                    b3:cc:0a:ef:f7:d7:fa:1b:9c:8e:09:43:7b:dd:10:
                    f2:80:94:62:39:fe:e1:17:c5:98:d5:bd:d5:f0:3a:
                    fb:22:9d:bc:5c:5d:f7:c7:2a:4c:1c:b5:a0:11:33:
                    fe:b0:66:4a:90:c3:db:73:48:f6:7e:8b:d2:ea:9f:
                    87:68:f4:5c:3e:38:52:03:0d:00:75:e5:b7:93:91:
                    7e:6d:08:9a:52:71:01:57:b8:8f:e4:bb:94:a4:5e:
                    71:50:8a:29:b6:9b:c5:1b:4d:ec:6b:85:71:98:67:
                    94:ac:6e:52:c0:ac:ef:a3:10:0c:5b:dc:df:93:35:
                    f3:7d:bd:28:97:6f:b6:55:43:1a:7e:3c:82:05:96:
                    ea:ce:fa:d3:f3:b3:5d:69:5c:d8:d3:4e:d2:d6:9e:
                    f9:00:b7:5b:13:66:6e:f9:fa:ff:0c:04:85:2e:82:
                    1b:88:1f:0d:fd:ce:28:2a:6d:9b:15:b0:4f:f6:c5:
                    2b:3a:aa:23:3d:64:69:20:d9:c8:28:72:88:65:9b:
                    20:f8:64:6a:5c:bb:68:23:9d:5c:af:07:6f:34:bf:
                    a5:38:18:c8:f2:15:b6:a0:cf:2d:62:14:d5:65:20:
                    08:70:84:48:99:17:f1:6b:0b:1f:11:21:36:6b:ae:
                    e9:c7:47:2b:45:90:4c:a4:79:50:f0:bb:bc:1f:0d:
                    11
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage:
                TLS Web Server Authentication
            X509v3 Subject Alternative Name:
                DNS:
                IP Address:116.203.61.197

    Signature Algorithm: SHA256-RSA
         b0:d8:b8:67:ad:29:f1:b9:0c:34:03:de:24:7c:98:a7:6c:97:
         99:a8:5b:bf:b4:46:aa:a1:9a:34:58:f0:6d:83:be:ee:80:2b:
         44:43:a4:ac:60:ef:c5:26:c2:c1:80:74:8c:2f:55:f5:d2:04:
         4b:44:37:84:9f:e9:c2:0c:3d:7a:56:b2:d0:20:42:09:eb:b0:
         87:58:81:51:4f:96:83:02:ec:2a:4f:d6:0a:95:d6:17:38:76:
         8e:01:93:08:e4:e0:55:bd:e7:98:71:1f:41:06:4e:95:b0:72:
         9d:e3:94:a5:0f:43:3b:5d:7c:7b:d5:95:62:a7:da:41:3b:de:
         5a:66:64:7e:c3:c4:5e:54:aa:ce:3d:ee:d3:ce:0d:d8:b9:bc:
         ba:8c:04:73:a2:63:40:cb:b7:4a:4b:20:7e:0d:8b:7f:75:c8:
         66:7e:f6:d0:6e:6c:dc:06:3e:b1:b9:2a:57:d5:4d:eb:41:56:
         a8:53:39:f9:37:d1:92:1b:f2:89:0f:6a:7d:47:2f:40:cc:ac:
         f9:45:df:a5:a7:63:a9:75:68:a6:07:87:ed:9d:01:bd:c0:4e:
         6c:86:68:49:84:87:ea:54:c5:15:eb:30:af:77:b8:36:75:bd:
         35:b3:11:92:15:2d:2b:be:8c:77:99:6e:e9:76:c7:7a:4c:b5:
         22:8f:78:8e
]
Do you want to continue connecting (yes/no)? yes

Create Cluster...
Successfully created cluster labs

Create Master Nodes (3) for HA...
k8s-master-01 has 78.47.113.251
k8s-master-02 has 116.203.18.143
k8s-master-03 has 195.201.43.6

Create Worker Nodes (5)...
k8s-worker-01 has 116.203.95.49
k8s-worker-02 has 116.203.109.154
k8s-worker-03 has 116.203.201.139
k8s-worker-04 has 159.69.144.127
k8s-worker-05 has 159.69.147.142

Assign Floating-IP to Worker...
k8s-worker-01 has 116.203.9.153 (floating-ip)

Have fun!

WebUI: https://116.203.61.197/
Username: admin
Password: xxx
```
