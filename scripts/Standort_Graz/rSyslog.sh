#!/bin/bash
set -e

sudo hostnamectl set-hostname rSyslog
sudo sed -i 's/lsrv01/rSyslog/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: 00:0C:29:38:0A:B7
      dhcp4: false
      addresses:
        - 172.16.0.1/24
      set-name: server
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      routes:
        - to: default
          via: 172.16.0.254
    default:
      match:
        name: "ens*"
      dhcp4: true
EOF

sudo mv ./01.yaml /etc/netplan/01.yaml
sudo chmod 600 /etc/netplan/*yaml
sudo netplan apply

wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
rm node_exporter-*.*-amd64.tar.gz
sudo cp node_exporter /usr/local/bin/node_exporter
cd node_exporter-*.*-amd64

sudo cat <<EOF > node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo useradd -rs /bin/false node_exporter
sudo mv node_exporter.service /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

sudo apt update
sudo apt install rsyslog

sudo nano /etc/rsyslog.conf

