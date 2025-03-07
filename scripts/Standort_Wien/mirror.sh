#!/bin/bash
set -e

sudo hostnamectl set-hostname mirror
sudo sed -i 's/lsrv01/mirror/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: 00:0C:29:53:B9:64
      dhcp4: false
      addresses:
        - 192.168.0.2/24
      set-name: server
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      routes:
        - to: default
          via: 192.168.0.254
    mirror:
      match:
        macaddress: 00:0C:29:53:B9:6E
      set-name: mirror
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF

sudo mv ./01.yaml /etc/netplan/01.yaml
sudo chmod 600 /etc/netplan/*yaml
sudo netplan apply


sudo apt update
sudo apt install tshark -y

sudo tshark -i mirror -w /temp/capture-output.pcap
