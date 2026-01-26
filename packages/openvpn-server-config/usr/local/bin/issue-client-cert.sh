#!/bin/bash
set -e

# === Настройки ===
CLIENT_NAME="$1"
PKI_DIR="/root/pki"
OUT_DIR="/tmp/client-$CLIENT_NAME"
SERVER_IP="YOUR_SERVER_PUBLIC_IP"  # ← ЗАМЕНИТЕ НА РЕАЛЬНЫЙ IP/DOMAIN

# === Проверка аргумента ===
if [[ -z "$CLIENT_NAME" ]]; then
  echo "Использование: $0 <client_name>"
  exit 1
fi

# === Функции ===
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
  log "❌ ОШИБКА: $1"
  exit 1
}

# === Проверка файлов УЦ ===
[[ -f "$PKI_DIR/pki/ca.crt" ]] || error_exit "Не найден ca.crt: $PKI_DIR/pki/ca.crt"
[[ -f "$PKI_DIR/private/ca.key" ]] || error_exit "Не найден ca.key: $PKI_DIR/private/ca.key"

# === Создание рабочей директории ===
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

# === Генерация ключа и CSR (если ещё нет) ===
if [[ ! -f "${CLIENT_NAME}.key" ]]; then
  log "Генерация ключа и CSR для клиента '$CLIENT_NAME'..."
  openssl genpkey -algorithm RSA -out "${CLIENT_NAME}.key" -pkeyopt rsa_keygen_bits:2048 || error_exit "Ошибка генерации ключа"
  openssl req -new -key "${CLIENT_NAME}.key" -out "${CLIENT_NAME}.csr" -subj "/CN=$CLIENT_NAME" || error_exit "Ошибка генерации CSR"
fi

# === Подпись сертификата ===
log "Подпись сертификата УЦ..."
cat > v3.ext <<EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = clientAuth
EOF

openssl x509 -req \
  -in "${CLIENT_NAME}.csr" \
  -CA "$PKI_DIR/pki/ca.crt" \
  -CAkey "$PKI_DIR/private/ca.key" \
  -CAcreateserial \
  -out "${CLIENT_NAME}.crt" \
  -days 365 \
  -sha256 \
  -extfile v3.ext || error_exit "Ошибка подписи сертификата"

rm -f v3.ext

# === Генерация .ovpn файла ===
log "Создание клиентского конфига ${CLIENT_NAME}.ovpn..."
cat > "${CLIENT_NAME}.ovpn" <<EOF
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun

<ca>
$(cat "$PKI_DIR/pki/ca.crt")
</ca>

<cert>
$(cat "${CLIENT_NAME}.crt")
</cert>

<key>
$(cat "${CLIENT_NAME}.key")
</key>

data-ciphers AES-256-GCM:AES-128-GCM
auth SHA256
remote-cert-tls server
verb 3
EOF

# === Архивация ===
tar -czf "${CLIENT_NAME}.tar.gz" "${CLIENT_NAME}.ovpn" || error_exit "Ошибка создания архива"

log "✅ Готово! Клиентский пакет: $OUT_DIR/${CLIENT_NAME}.tar.gz"