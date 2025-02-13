#!/bin/bash
set -e

sudo hostnamectl set-hostname netflow
sudo sed -i 's/lsrv01/netflow/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: bc:24:11:13:da:16
      dhcp4: false
      addresses:
        - 192.168.1.3/24
      set-name: server
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      routes:
        - to: default
          via: 192.168.1.254
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF

sudo mv ./01.yaml /etc/netplan/01.yaml
sudo chmod 600 /etc/netplan/*yaml
sudo netplan apply

sudo apt update
sudo apt install ntopng -y
sudo systemctl enable --now ntopng



