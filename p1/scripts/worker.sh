#!/bin/bash
set -e

echo "==> ⚙️  Instalando dependencias... ⚙️"
apt-get update -y
apt-get install -y curl
apt-get install vagrant -y
vagrant plugin install vagrant-vbguest

SERVER_IP="192.168.56.10"
WORKER_IP="192.168.56.11"

echo "==>> ⚠️ Esperando del token del server ... ⚠️"
while [ ! -f /vagrant/scripts/node-token ]; do
    sleep 3
done

TOKEN=$(cat /vagrant/scripts/node-token)

echo "==>> ⚙️  Instalando K3s en modo agent... ⚙️"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent \
    --server https://${SERVER_IP}:6443 \
    --token ${TOKEN} \
    --node-ip ${WORKER_IP}" sh -

echo "==>> 🟢 Worker listo ${WORKER_IP} 🟢"