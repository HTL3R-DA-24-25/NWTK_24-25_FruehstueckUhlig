#!/bin/bash
set -e

sudo hostnamectl set-hostname mirror
sudo sed -i 's/linuhligsxxx/mirror/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    lan:
      match:
        macaddress: bc:24:11:15:79:ee
      dhcp4: false
      addresses:
        - 192.168.100.1/24
      set-name: server
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF

