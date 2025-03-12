#!/bin/bash
set -e

sudo hostnamectl set-hostname LinFirewall
sudo sed -i 's/lsrv01/LinFirewall/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    outside:
      match:
        macaddress: 00:0C:29:2B:BC:0A
      dhcp4: false
      addresses:
        - 103.152.126.42/29
      routes:
        - to: default
          via: 103.152.126.41
      set-name: outside
    inside:
      match:
        macaddress: 00:0C:29:2B:BC:0A
      dhcp4: false
      addresses:
        - 10.10.10.254/24
      set-name: inside    
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

sudo ufw disable
sudo ufw 
sudo iptables -t nat -A POSTROUTING -o outside -j MASQUERADE

sudo apt update
sudo apt install iptables-persistent -y

# nft add table nat
# nft add chain nat postrouting { type nat hook postrouting priority 100 \; }
# nft add rule nat postrouting oifname "outside" masquerade
