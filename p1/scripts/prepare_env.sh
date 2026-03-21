#!/bin/bash

echo "==> ⚙️ Configurando entorno 42..."

# Usar /tmp para Vagrant y VirtualBox (espacio ilimitado en el campus)
export VAGRANT_HOME=/tmp/davgalle/.vagrant.d
mkdir -p /tmp/davgalle/.vagrant.d
mkdir -p "/tmp/davgalle/VirtualBox VMs"

vboxmanage setproperty machinefolder "/tmp/davgalle/VirtualBox VMs"

echo "==> 🟢 Entorno configurado"
echo "==> VAGRANT_HOME: $VAGRANT_HOME"
echo "==> VirtualBox VMs: /tmp/davgalle/VirtualBox VMs"