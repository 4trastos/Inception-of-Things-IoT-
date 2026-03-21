#!/bin/bash
set -e

echo "==>> ⚙️  Instalando dependencias... ⚙️"
apt-get update -y
apt-get install -y curl

SERVER_IP="192.168.56.110"

echo "==>> ⚙️  Instalando K3s en modo server... Añadiendo IP al certificado SSL... 🔒"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --tls-san ${SERVER_IP} \
    --node-ip ${SERVER_IP} \
    --write-kubeconfig-mode 644" sh -

echo "==>> ⚠️  Esperando a que K3S aranque... ⚠️"
sleep 10

echo "==>> 🔒  Guardando el token para el worker... 🔒"
mkdir -p /vagrant/scripts
cp /var/lib/rancher/k3s/server/node-token /vagrant/scripts/node-token

echo "==>> 🖥️  Configurando kubectl para el usuario valgrant... 👉 (permite usar kubectl directamente sin sudo)"
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

echo "==>> 🟢  Server listo en: ${SERVER_IP} 🟢"

echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /root/.bashrc