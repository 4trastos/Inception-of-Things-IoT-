#!/bin/bash

cp /vagrant/scripts/setup.sh /root/setup.sh
chmod +x /root/setup.sh
nohup /root/setup.sh > /var/log/iot-setup.log 2>&1 &
echo "==> 🚀 Setup en background — sigue con:"
echo "    vagrant ssh -c 'tail -f /var/log/iot-setup.log'"