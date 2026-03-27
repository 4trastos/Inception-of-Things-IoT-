#!/bin/bash
set -e

echo "==> ⚙️ Instalando dependencias..."
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release
apt-get install vagrant -y
vagrant plugin install vagrant-vbguest

echo "==> ⚙️ Instalando Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker vagrant

echo "==> ⚙️ Instalando kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "==> ⚙️ Instalando K3d..."
curl -sfL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "==> ⚙️ Instalando Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "==> 🟢 install.sh completado"
docker --version && kubectl version --client && k3d version && helm version --short