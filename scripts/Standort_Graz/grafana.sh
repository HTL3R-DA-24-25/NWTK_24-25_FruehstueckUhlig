#!/bin/bash
set -e

sudo hostnamectl set-hostname grafana
sudo sed -i 's/lsrv01/grafana/g' /etc/hosts

sudo cat <<EOF > ./01.yaml
network:
  version: 2
  ethernets:
    server:
      match:
        macaddress: 00:0C:29:38:0A:B7
      dhcp4: false
      addresses:
        - 172.16.0.10/24
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
cd node_exporter-*.*-amd64
sudo cp node_exporter /usr/local/bin/node_exporter
cd ..

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


wget https://github.com/prometheus/prometheus/releases/download/v3.1.0/prometheus-3.1.0.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
rm prometheus-*.tar.gz
cd prometheus-*
sudo cp prometheus /usr/local/bin/prometheus
sudo mkdir -p /etc/prometheus
sudo cp prometheus.yml /etc/prometheus/prometheus.yml
sudo chmod 775 /etc/prometheus/prometheus.yml
cd ..

sudo cat <<EOF > prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml

[Install]
WantedBy=multi-user.target
EOF
sudo useradd -rs /bin/false prometheus
sudo mv prometheus.service /etc/systemd/system/prometheus.service
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo mkdir -p /data
sudo chown -R prometheus:prometheus /data
sudo chmod -R 775 /data

sudo apt-get install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install grafana
sudo systemctl enable --now grafana-server.service
#port 3000 - ID 1860 für Dashboard
#/etc/prometheus/prometheus.yml