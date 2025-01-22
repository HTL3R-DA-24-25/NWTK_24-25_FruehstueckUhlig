#!/bin/bash
set -e

sudo hostnamectl set-hostname syslog
sudo sed -i 's/lsrv01/syslog/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: 00:0C:29:38:0A:B7
      dhcp4: false
      addresses:
        - 192.168.0.1/24
      set-name: server
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      routes:
        - to: default
          via: 192.168.0.254
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF

sudo mv ./01.yaml /etc/netplan/01.yaml
sudo chmod 600 /etc/netplan/*yaml
sudo netplan apply

sudo apt update
sudo apt install rsyslog

sudo nano /etc/rsyslog.conf

