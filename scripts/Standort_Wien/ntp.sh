#!/bin/bash
set -e

sudo hostnamectl set-hostname ntp
sudo sed -i 's/lsrv01/ntp/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: 00:0C:29:2B:62:1E
      dhcp4: false
      addresses:
        - 192.168.0.4/24
      set-name: server
      nameservers:
        addresses: [172.16.10.20, 8.8.8.8]
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
sudo apt install ntp -y

sudo systemctl restart ntp
sudo systemctl enable ntp

sudo ufw allow 123/udp
sudo ufw reload