#!/bin/bash
set -e

PKI_DIR="/opt/pki"
ORG_NAME="MyOrg"
COUNTRY="RU"
STATE="Moscow"
CITY="Moscow"
EMAIL="admin@example.com"

# Обработчик ошибок
error_exit() {
    echo "Ошибка на строке $1: '$BASH_COMMAND'" >&2
    exit 1
}
trap 'error_exit $LINENO' ERR

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Скрипт требует запуска от root" >&2
    exit 1
fi

# Установка зависимостей
echo "Установка зависимостей..."
apt update || { echo "Не удалось обновить пакеты" >&2; exit 1; }
apt install -y easy-rsa || { echo "Не удалось установить easy-rsa" >&2; exit 1; }

# Создание структуры
echo "Создание PKI-директории..."
mkdir -p "$PKI_DIR" || { echo "Не удалось создать $PKI_DIR" >&2; exit 1; }
cd "$PKI_DIR"

# Инициализация CA-структуры
make-cadir . || { echo "Не удалось инициализировать easy-rsa структуру" >&2; exit 1; }

# Настройка vars
cat > vars <<EOF || { echo "Не удалось записать vars" >&2; exit 1; }
set_var EASYRSA_REQ_COUNTRY    "$COUNTRY"
set_var EASYRSA_REQ_PROVINCE   "$STATE"
set_var EASYRSA_REQ_CITY       "$CITY"
set_var EASYRSA_REQ_ORG        "$ORG_NAME"
set_var EASYRSA_REQ_EMAIL      "$EMAIL"
set_var EASYRSA_REQ_OU         "PKI"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    365
EOF

# Инициализация УЦ
echo "Инициализация УЦ..."
source ./vars
./easyrsa init-pki || { echo "Не удалось инициализировать PKI" >&2; exit 1; }
./easyrsa build-ca nopass <<< "" || { echo "Не удалось создать корневой сертификат" >&2; exit 1; }

echo "PKI успешно настроен. Корневой сертификат: $PKI_DIR/pki/ca.crt"