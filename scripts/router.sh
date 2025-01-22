#!/bin/bash
set -e

sudo hostnamectl set-hostname router
sudo sed -i 's/lsrv01/router/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    wienserver:
      match:
        macaddress: 00:0C:29:2B:BC:E2
      dhcp4: false
      addresses:
        - 192.168.0.254/24
      set-name: wienserver
    wienad:
      match:
        macaddress: 00:0C:29:2B:BC:EC
      dhcp4: false
      addresses:
        - 192.168.10.254/24
      set-name: wienad
    rennweg:
      match:
        macaddress: 00:0C:29:2B:BC:F6
      dhcp4: false
      addresses:
        - 172.16.100.254/24
      set-name: rennweg
    grazserver:
      match:
        macaddress: 00:0C:29:2B:BC:00
      dhcp4: false
      addresses:
        - 172.16.10.254/24
      set-name: grazserver
    grazad:
      match:
        macaddress: 00:0C:29:2B:BC:0A
      dhcp4: false
      addresses:
        - 192.168.0.254/24
      set-name: grazad
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF


sudo mv ./01.yaml /etc/netplan/01.yaml
sudo chmod 600 /etc/netplan/*yaml
sudo netplan apply

sudo sysctl net.ipv4.ip_forward=1
sudo sysctl -p

sudo iptables -t nat -A POSTROUTING -o ens33 -j MASQUERADE

sudo apt update
sudo apt install iptables-persistent -y
