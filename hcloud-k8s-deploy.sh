#!/bin/bash
set -Eeuo pipefail

# help
showHelp () { 
    echo "Usage:  ./$(basename $0) --project <name> [OPTIONS]

Simple create a Kubernetes Cluster with Rancher in Hetzner-Cloud

Mandatory:
      --project <name>               Your Project Name will be use for hcloud-context and rancher-cluster name

Options:
      --rancher-version <version>    Rancher Version (Image Tag) (default \"latest\")
      --enable-ha                    Enable K8S-HA Setup
      --worker <number>              Number of Worker Nodes (default \"1\")

      --home-location <data-center>  hcloud Datacenter (\"fsn1\"|\"hel1\"|\"nbg1\") (default \"nbg1\")

      -D, --debug                    Enable debug mode
      -h, --help                     Show help for more information"
}

# defaults
MASTERNUM=1
WORKERNUM=1
HOMELOCATION="nbg1"
RANCHERVERSION="latest"

#
if [ $# = 0 ]; then
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
        --project)
            shift # past argument
            CONTEXT="${1}"
            shift # past value
            ;;
        --rancher-version)
            shift # past argument
            RANCHERVERSION="${1}"
            shift # past value
            ;;
        --enable-ha) # do k8s-ha setup
            shift # past argument
            MASTERNUM=3
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
            SERVERS=$(hcloud server list | grep -v NAME | awk '{print $2}')
            while read -r server; do hcloud server delete "${server}"; done < <(echo "$SERVERS")
            FIPS=$(hcloud floating-ip list | grep -E "^[0-9]" | awk '{print $1}')
            while read -r fip; do hcloud floating-ip delete "${fip}"; done < <(echo "$FIPS")
            exit
            ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done


# global stuff
_ssh () {
    ssh -o "UserKnownHostsFile=/dev/null" \
        -o "StrictHostKeyChecking=no" \
        -q \
        "${RANCHERIP}" "${@}"
}

########################################################################
# init                                                                 #
########################################################################
echo $'Goto https://console.hetzner.cloud/projects'
echo $'and create 1) a hcloud project and 2) an api-token\n'


# create context
hcloud context delete "${CONTEXT}" >/dev/null 2>&1 || true
hcloud context create "${CONTEXT}"
hcloud context use "${CONTEXT}"

# add ssh-key to context
MESSAGE=$'\nYour ssh public key (/Users/'"${USER}"$'/.ssh/id_rsa.pub)?:'
#echo "${MESSAGE}"
read -r -p "${MESSAGE} " SSHPUBKEYFILE 
#SSHPUBKEYFILE=/Users/mpizala/.ssh/id_rsa.pub
#echo "${SSHPUBKEYFILE}"

hcloud ssh-key create \
    --name "${USER}" \
    --public-key-from-file "${SSHPUBKEYFILE}" || true

# create floating-ip 
echo $'\nCreate Floating-IP...'
DESCRIPTION=default
FIPID=$(hcloud floating-ip create --type ipv4 --home-location "${HOMELOCATION}" --description "${DESCRIPTION}" | cut -d" " -f3)
FIP=$(hcloud floating-ip list | grep -E "^${FIPID}" | awk '{print $4}')
echo "${FIP} (${DESCRIPTION})"


########################################################################
# rancher                                                              #
########################################################################

RANCHERHOSTNAME="rancher-server"
echo $'\nDeploy Rancher...'

# inject rancher version
perl -i -pe"s@rancher:latest@rancher:${RANCHERVERSION}@g" cloud-config/rancher
# inject floating-ip to cloud-config
perl -i -pe"s@ip addr add.*@ip addr add ${FIP} dev eth0@g" cloud-config/rancher

# create server
RANCHER=$(
    hcloud server create \
    --name "${RANCHERHOSTNAME}" \
    --type cx21-ceph \
    --image centos-7 \
    --datacenter "${HOMELOCATION}-dc3" \
    --ssh-key "${USER}" \
    --user-data-from-file cloud-config/rancher
)

# assign floating-ip
hcloud floating-ip assign "${FIPID}" "${RANCHERHOSTNAME}" >/dev/null

# 
RANCHERIP=$(echo "${RANCHER}" | grep IPv4 | cut -d" " -f2)
echo "${RANCHERHOSTNAME} has ${RANCHERIP}"

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
    RESETPASS="docker exec \$(docker ps -q 2>&1) /usr/bin/reset-password 2>&1 | tail -n1"
    PASSWORD=$(_ssh "${RESETPASS} 2>/dev/null")
    pat="^[a-zA-Z0-9_-]{20}$"
    if [[ "${PASSWORD}" =~ $pat ]]; then
        OK=1
    else
        sleep 5
    fi
done
echo 'Rancher is up!'
echo $'\n'"WebUI: https://${RANCHERIP}/"
echo 'Username: admin'
echo "Password: ${PASSWORD}"

# add certificate to trust store (darwin)
echo $'\nAdd certificate to your trust store (login.keychain)'
openssl s_client -showcerts -connect "${RANCHERIP}:443" -servername "${RANCHERIP}" </dev/null 2>/dev/null | openssl x509 -outform PEM > "${RANCHERIP}.pem" || true
/usr/bin/security import "${RANCHERIP}.pem" -k ~/Library/Keychains/login.keychain
/usr/bin/security add-trusted-cert -r trustAsRoot -k ~/Library/Keychains/login.keychain "${RANCHERIP}.pem"

########################################################################
# create cluster                                                       #
########################################################################

# config rancher-cli
echo $'\n'"Create an API Key -> https://${RANCHERIP}/apikeys"
MESSAGE=$'Your API Key (Bearer Token):'
read -r -s -p "${MESSAGE} " BEARER 

echo $'\n\nLogin to Rancher'
rancher login "https://${RANCHERIP}/" -t "${BEARER}" 2>/dev/null || true 
echo $'\nCreate Cluster...'
rancher cluster create --psp-default-policy restricted "${CONTEXT}" 2>/dev/null
rancher context switch 2>/dev/null

########################################################################
# create k8s-master                                                    #
########################################################################

# inject cluster connect
DEPLOYMASTER=$(rancher cluster add-node --etcd --management --controlplane -q "${CONTEXT}" 2>&1 | grep -v "WARN[0000] No context set")
perl -i -pe"s@sudo docker run.*@${DEPLOYMASTER}@g" cloud-config/k8s-master
# inject floating-ip to cloud-config
perl -i -pe"s@ip addr add.*@ip addr add ${FIP} dev eth0@g" cloud-config/k8s-master

# create server
if [ "${MASTERNUM}" = 3 ]; then
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
        --ssh-key "${USER}" \
        --user-data-from-file cloud-config/k8s-master
    )
    MASTERIP=$(echo "${MASTER}" | grep IPv4 | cut -d" " -f2)
    echo "k8s-master-0${i} has ${MASTERIP}"
done

########################################################################
# create k8s-worker                                                    #
########################################################################

# inject cluster connect
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
        --name "k8s-worker-0${i}" \
        --type cx31 \
        --image centos-7 \
        --datacenter "${HOMELOCATION}-dc3" \
        --ssh-key "${USER}" \
        --user-data-from-file cloud-config/k8s-worker
    )
    WORKERIP=$(echo "${WORKER}" | grep IPv4 | cut -d" " -f2)
    echo "k8s-worker-0${i} has ${WORKERIP}"
done

# assign floating-ip
echo $'\nAssign Floating-IP to Worker...'
hcloud floating-ip assign "${FIPID}" k8s-worker-01 >/dev/null
echo "k8s-worker-01 has ${FIP} (floating-ip)"

# bye bye
echo $'\nHave fun!'
echo $'\n'"WebUI: https://${RANCHERIP}/"
echo 'Username: admin'
echo "Password: ${PASSWORD}"