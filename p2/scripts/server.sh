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

echo "==>> ⚠️ Aplicando manifiesttos ⚠️"
kubectl apply -f /vagrant/confs/

echo "==>> 🟢 Server listo en ${SERVER_IP} 🟢"