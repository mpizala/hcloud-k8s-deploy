#!/bin/bash
#set -Eeuo pipefail

# help
showHelp () {
    echo "Usage:  ./$(basename "$0") --context <name> [OPTIONS]

Simple create a Kubernetes Cluster with Rancher in Hetzner-Cloud

Mandatory:
      --context <name>               Your Project Name will be use for hcloud-context and rancher-cluster name

Options:
      --rancher-version <version>    Rancher Version (Image Tag) (default \"latest\")

      --master <number>              Number of Master Nodes (\"1\"|\"3\"|\"5\") (default \"1\")
      --worker <number>              Number of Worker Nodes (default \"1\")

      --home-location <data-center>  hcloud Datacenter (\"fsn1\"|\"hel1\"|\"nbg1\") (default \"nbg1\")

      -D, --debug                    Enable debug mode
      -h, --help                     Show help for more information"
}

# set defaults
CONTEXT=demo
HOMELOCATION="nbg1"
RANCHERNAME="rancher-server"
RANCHERVERSION="latest"
MASTERNUM=1
MASTERNAME=k8s-master-0
WORKERNUM=1
WORKERNAME=k8s-worker-0

# check args
if [ $# = 0 ]; then
    echo $'1 argument required, 0 provided\n'
    showHelp;
    exit 1
fi

# get parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --help|-h)
            shift # past argument
            showHelp
            exit
            ;;
        --debug|-D)
            shift # past argument
            set -x
            ;;
        --context)
            shift # past argument
            CONTEXT="${1}"
            shift # past value
            ;;
        --rancher-version)
            shift # past argument
            RANCHERVERSION="${1}"
            shift # past value
            ;;
        --master) # do k8s-ha setup
            shift # past argument
            MASTERNUM=$1
            shift # past argument
        ;;
        --worker)
            shift # past argument
            WORKERNUM=$1
            shift # past argument
            ;;
        --home-location)
            shift # past argument
            HOMELOCATION=$1
            shift # past argument
            ;;
        --clean)
            # !!! dangerous
            # hidden feature for cleanup your current hcloud context
            # be sure what you do
            hcloud context use ${CONTEXT}
            _clean () {
                OBJS=$(hcloud "${1}" list | grep -v "^ID" | awk '{print $1}')
                for obj in ${OBJS}; do
                    hcloud "$1" delete "${obj}";
                done
            }
            _clean server
            _clean ssh-key
            _clean floating-ip
            _clean volume

            shift # past argument
            ;;
        *) # unknown option
            echo "unknown option \"${1}\""
            exit 1
            shift # past argument
            ;;
    esac
done

# execute on target
_ssh () {
    ssh -o "UserKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking=no" \
        -q \
        "${RANCHERIP}" "${@}"
}


########################################################################
# init                                                                 #
########################################################################
echo $'\nGoto https://console.hetzner.cloud/projects'
echo $'and create 1) a hcloud project and 2) an api-token\n'

# create context
hcloud context delete "${CONTEXT}" >/dev/null 2>&1 || true
hcloud context create "${CONTEXT}"
hcloud context use "${CONTEXT}"

# create ssh-keys
echo $'\nPrepare SSH-Keys...'

# delete ssh-keys
for key in $(hcloud ssh-key list | grep -v "^ID" | awk '{print $2}'); do
    hcloud ssh-key delete "${key}" >/dev/null;
done
# add ssh-key to context
for key in $(ls ssh-keys); do
    hcloud ssh-key create \
        --name "$(basename ${key} .pub)" \
        --public-key-from-file "ssh-keys/${key}" >/dev/null || true
done
hcloud ssh-key list | grep -v -E "^ID"

# config option for hcloud server create
ADDKEYS=$(
    for key in $(ls ssh-keys); do
        echo --ssh-key $(basename ${key} .pub)
    done | xargs
)

# create floating-ip
echo $'\nCreate Floating-IP...'
DESCRIPTION=default
FIPID=$(hcloud floating-ip create --type ipv4 --home-location "${HOMELOCATION}" --description "${DESCRIPTION}" | cut -d" " -f3)
FIP=$(hcloud floating-ip list | grep -E "^${FIPID}" | awk '{print $4}')
echo "${FIP} (${DESCRIPTION})"


########################################################################
# rancher                                                              #
########################################################################

echo $'\nDeploy Rancher...'

# inject rancher version
perl -i -pe"s@rancher:[vl].*@rancher:${RANCHERVERSION}@g" cloud-config/rancher
# inject floating-ip to cloud-config
perl -i -pe"s@ip addr add.*@ip addr add ${FIP} dev eth0@g" cloud-config/rancher

# create server
RANCHER=$(
    hcloud server create \
    --name "${RANCHERNAME}" \
    --type cx21-ceph \
    --image centos-7 \
    --datacenter "${HOMELOCATION}-dc3" \
    ${ADDKEYS} \
    --user-data-from-file cloud-config/rancher
)
RANCHERIP=$(echo "${RANCHER}" | grep IPv4 | cut -d" " -f2)
echo "${RANCHERNAME} has ${RANCHERIP}"

# enable backup
echo $'\nEnable Backup...'
hcloud server enable-backup "${RANCHERNAME}" >/dev/null
echo "Backup enabled for ${RANCHERNAME}"

# assign floating-ip
hcloud floating-ip assign "${FIPID}" "${RANCHERNAME}" >/dev/null

# wait for ssh
echo $'\nWaiting for SSH is up...'
OK=0
while [ "$OK" != '1' ]; do
    sleep 5 # for retry
    echo -ne | nc -z -G 1 "${RANCHERIP}" 22 && OK=1;
done

# wait for rancher
echo $'\nWaiting for Rancher is up...'
# set rancher admin password
#echo $'\nSet Rancher admin password...'
OK=0
while [ "$OK" != "1" ]; do
    RANCHERPW="docker exec \$(docker ps -q 2>&1) /usr/bin/reset-password 2>&1 | tail -n1"
    PASSWORD=$(_ssh "${RANCHERPW} 2>/dev/null")
    pat="^[a-zA-Z0-9_-]{20}$"
    if [[ "${PASSWORD}" =~ $pat ]]; then
        OK=1
    else
        sleep 5
    fi
done
echo $'Rancher is up!'

# get certificate
openssl s_client -showcerts -connect "${RANCHERIP}:443" -servername "${RANCHERIP}" </dev/null 2>/dev/null | openssl x509 -outform PEM > "${RANCHERIP}.pem" || true


########################################################################
# create rancher                                                       #
########################################################################

# config rancher-cli
echo $'\n'"Creating Rancher API Key..."
# rancher login
APIKEY=$(
    curl -i -s -k  -X $'POST' \
    --data-binary $'{\"username\":\"admin\",\"password\":\"'"${PASSWORD}"$'\",\"description\":\"hcloud-k8s-deploy\",\"responseType\":\"cookie\",\"ttl\":57600000}' \
    "https://${RANCHERIP}/v3-public/localProviders/local?action=login" | grep Set-Cookie  | awk '{print $2}' | cut -d= -f2 | cut -d";" -f1
)
echo "${APIKEY}"

echo $'\nConfigure Rancher CLI...'
rancher login "https://${RANCHERIP}/" -t "${APIKEY}" --skip-verify

echo $'\nCreate Cluster...'
rancher cluster create \
    --psp-default-policy restricted \
    "${CONTEXT}" 2>/dev/null
rancher context switch 2>/dev/null


########################################################################
# create k8s-master                                                    #
########################################################################

# inject cluster join
DEPLOYMASTER=$(rancher cluster add-node --etcd --controlplane -q "${CONTEXT}" 2>&1 | grep -v "WARN[0000] No context set")
perl -i -pe"s@sudo docker run.*@${DEPLOYMASTER}@g" cloud-config/k8s-master
# inject floating-ip to cloud-config
perl -i -pe"s@ip addr add.*@ip addr add ${FIP} dev eth0@g" cloud-config/k8s-master

# create server
if [ "${MASTERNUM}" = 3 ] || [ "${MASTERNUM}" = 5 ]; then
    echo $'\nCreate Master Nodes '"(${MASTERNUM}) for HA..."
else
    echo $'\nCreate Master Node '"(${MASTERNUM})..."
fi

for i in $(seq 1 "${MASTERNUM}"); do
    MASTER=$(
    hcloud server create \
        --name "k8s-master-0$i" \
        --type cx31-ceph \
        --image centos-7 \
        --datacenter "${HOMELOCATION}-dc3" \
        ${ADDKEYS} \
        --user-data-from-file cloud-config/k8s-master
    )
    MASTERIP=$(echo "${MASTER}" | grep IPv4 | cut -d" " -f2)
    echo "${MASTERNAME}${i} has ${MASTERIP}"
done


########################################################################
# create k8s-worker                                                    #
########################################################################

# inject cluster join
DEPLOYWORKER=$(rancher cluster add-node --worker -q "${CONTEXT}")
perl -i -pe"s@sudo docker run.*@${DEPLOYWORKER}@g" cloud-config/k8s-worker
# inject floating-ip to cloud-config
perl -i -pe"s@ip addr add.*@ip addr add ${FIP} dev eth0@g" cloud-config/k8s-worker

# create server
if [ "${WORKERNUM}" = 1 ]; then
    echo $'\nCreate Worker Node '"(${WORKERNUM})..."
else
    echo $'\nCreate Worker Nodes '"(${WORKERNUM})..."
fi

for i in $(seq 1 "${WORKERNUM}"); do
    WORKER=$(
    hcloud server create \
        --name "${WORKERNAME}${i}" \
        --type cx31 \
        --image centos-7 \
        --datacenter "${HOMELOCATION}-dc3" \
        ${ADDKEYS} \
        --user-data-from-file cloud-config/k8s-worker
    )
    WORKERIP=$(echo "${WORKER}" | grep IPv4 | cut -d" " -f2)
    echo "${WORKERNAME}${i} has ${WORKERIP}"
done

# assign floating-ip
echo $'\nAssign Floating-IP to Worker...'
hcloud floating-ip assign "${FIPID}" k8s-worker-01 >/dev/null
echo "k8s-worker-01 has ${FIP} (floating-ip)"

# import and trust certificate
echo $'\nAdd Rancher Certificate to login.keychain...'
/usr/bin/security import "${RANCHERIP}.pem" -k ~/Library/Keychains/login.keychain
echo $'Set trust for Rancher Certificate. Authorization is required...'
/usr/bin/security add-trusted-cert -r trustAsRoot -k ~/Library/Keychains/login.keychain "${RANCHERIP}.pem"
echo $'1 certificate trusted.'

# bye bye
echo $'\nHave fun!'
echo $'\n'"WebUI: https://${RANCHERIP}/"
echo 'Username: admin'
echo "Password: ${PASSWORD}"

########################################################################
# kubectl                                                              #
########################################################################

echo $'\nWaiting for Master is up...'
# generate kubeconfig
OK=0
DONE=0
while [ "$OK" != '1' ]; do
    MASTERSTATE=$(rancher nodes list | grep ${MASTERNAME}1 | awk '{print $3}')
    if [ "${MASTERSTATE}" == "active" ]; then
        echo "${MASTERNAME}1 is up!"
        # generate kubeconfigs
        echo $'Generate Kubeconfig...'
        CLUSTERID=$(rancher cluster list  | tail -n 1 | awk '{print $2}')
        curl -s -k -X $'POST' \
             -H "Cookie: R_SESS=${APIKEY}" \
             "https://${RANCHERIP}/v3/clusters/${CLUSTERID}?action=generateKubeconfig" | jq .config -r > "kubeconfigs/${CONTEXT}"
        echo $'\n'"Save \"kubeconfigs/${CONTEXT}\" "
        OK=1
    else
       sleep 5
    fi
done

export KUBECONFIG="kubeconfigs/${CONTEXT}"


########################################################################
# Container Storage Interface                                          #
########################################################################

echo $'Add Container Storage Interface driver for Hetzner Cloud\n'

# add access token
read -s -r -p "Your hcloud Token: " HCLOUDTOKEN
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-csi
  namespace: kube-system
stringData:
  token: ${HCLOUDTOKEN}
EOF

# add hcloud-csi
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml

########################################################################
# Certificate                                                          #
########################################################################

# create dns

# generate certificate

# create certificate