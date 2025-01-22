#!/bin/bash
set -e

sudo hostnamectl set-hostname bind9
sudo sed -i 's/lsrv01/bind9/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: 00:0C:29:87:6E:CC
      dhcp4: false
      addresses:
        - 172.16.10.20/24
      set-name: server
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      routes:
        - to: default
          via: 172.16.10.254
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF

sudo mv ./01.yaml /etc/netplan/01.yaml
sudo chmod 600 /etc/netplan/*yaml
sudo netplan apply

sudo apt update
sudo apt install bind9 bind9-utils bind9-doc -y

sudo cat <<EOF > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";

    // Forward DNS queries to these servers
    forwarders {
        8.8.8.8;    // Google DNS
        8.8.4.4;    // Google DNS
    };

    // Allow only recursive queries from internal networks
    allow-recursion { 192.168.0.0/16; 172.16.0.0/16; };

    auth-nxdomain no;    # Conform to RFC1035
    listen-on-v6 { any; };
};
EOF

sudo systemctl restart bind9

