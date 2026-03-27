#!/bin/bash

echo "==> ⚙️ Configurando entorno 42..."

# Usar /tmp para Vagrant y VirtualBox (espacio ilimitado en el campus)
export VAGRANT_HOME=/sgoinfre/students/$USER/.vagrant.d
mkdir -p "/sgoinfre/students/$USER/.vagrant.d"
mkdir -p "/sgoinfre/students/$USER/VirtualBox VMs"

vboxmanage setproperty machinefolder "/sgoinfre/students/$USER/VirtualBox VMs"

echo "==> 🟢 Entorno configurado"
echo "==> VAGRANT_HOME: $VAGRANT_HOME"
echo "==> VirtualBox VMs: /sgoinfre/students/$USER/VirtualBox VMs"
