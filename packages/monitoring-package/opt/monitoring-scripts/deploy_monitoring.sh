#!/bin/bash
set -e  # остановка при любой ошибке

# Параметры
USER="monitor"
GROUP="monitor"
NODE_EXPORTER_VERSION="1.6.1"
OPENVPN_EXPORTER_VERSION="1.0.0"

# Создание пользователя и группы
if ! getent group $GROUP >/dev/null; then
    sudo groupadd --system $GROUP
fi
if ! id -u $USER >/dev/null 2>&1; then
    sudo useradd --system --shell /bin/false --no-create-home --gid $GROUP $USER
fi

# Установка node_exporter
echo "Установка node_exporter..."
sudo mkdir -p /opt/node_exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
sudo cp node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /opt/node_exporter/
sudo chown $USER:$GROUP /opt/node_exporter/node_exporter

# Юнит node_exporter
cat << EOF | sudo tee /etc/systemd/system/node_exporter.service > /dev/null
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=$USER
Group=$GROUP
ExecStart=/opt/node_exporter/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Установка openvpn_exporter (если на OpenVPN-сервере)
if [[ $(hostname) == *"openvpn"* ]]; then
    echo "Установка openvpn_exporter..."
    sudo mkdir -p /opt/openvpn_exporter
    cd /tmp
    wget https://github.com/kumina/openvpn_exporter/releases/download/v$OPENVPN_EXPORTER_VERSION/openvpn_exporter-$OPENVPN_EXPORTER_VERSION.linux-amd64.tar.gz
    tar xzf openvpn_exporter-$OPENVPN_EXPORTER_VERSION.linux-amd64.tar.gz
    sudo cp openvpn_exporter-$OPENVPN_EXPORTER_VERSION.linux-amd64/openvpn_exporter /opt/openvpn_exporter/

    # Проверка: существует ли status.log
    if [[ ! -f "/var/log/openvpn/status.log" ]]; then
        echo "Ошибка: /var/log/openvpn/status.log не найден. Настройке OpenVPN - 'status /var/log/openvpn/status.log 10' and 'status-version 2'"
        exit 1
    fi

    # Юнит openvpn_exporter
    cat << EOF | sudo tee /etc/systemd/system/openvpn_exporter.service > /dev/null
[Unit]
Description=OpenVPN Exporter
After=openvpn@server.service

[Service]
User=$USER
Group=openvpn
ExecStart=/opt/openvpn_exporter/openvpn_exporter --openvpn.status_paths /var/log/openvpn/status.log
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now openvpn_exporter
fi

echo "Разворачивание завершено."