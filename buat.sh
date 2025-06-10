#!/bin/bash

# =============================
#  OpenWrt Local HTTPS Cert Generator
# =============================

set -e

# 🎨 Warna
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m'

CERT_DIR="openwrt-certs"
SAN_CONFIG="$CERT_DIR/san.cnf"
DAYS_VALID_CA=1825
DAYS_VALID_CERT=825
ST="Jakarta Barat"
L="Jakarta"
usernam="openwrt.local"
ipserver="192.168.1.1"

# 🔄 Buat direktori output
mkdir -p "$CERT_DIR"

echo -e "${BLUE}📁 Membuat direktori sertifikat: $CERT_DIR${NC}"

# 📄 1. Buat Root CA
echo -e "${GREEN}🔐 Membuat Root CA...${NC}"
openssl genrsa -out "$CERT_DIR/ca.key" 4096 > /dev/null 2>&1
openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days $DAYS_VALID_CA \
    -out "$CERT_DIR/ca.crt" \
    -subj "/C=ID/ST=${ST}/L=${L}/O=OpenWrt Local CA/CN=OpenWrt-Root-CA"

# 🧾 2. Buat file SAN config
cat > "$SAN_CONFIG" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = ID
ST = ${ST}
L = ${L}
O = OpenWrt
CN = ${usernam}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${usernam}
IP.1 = ${ipserver}
EOF

echo -e "${BLUE}⚙️  Konfigurasi SAN ditulis ke: $SAN_CONFIG${NC}"

# 🔑 3. Buat private key & CSR
echo -e "${GREEN}🛠️  Membuat private key dan CSR untuk openwrt.local...${NC}"
openssl genrsa -out "$CERT_DIR/openwrt.key" 2048 > /dev/null 2>&1
openssl req -new -key "$CERT_DIR/openwrt.key" -out "$CERT_DIR/openwrt.csr" -config "$SAN_CONFIG"

# 📝 4. Sign CSR dengan CA
echo -e "${GREEN}✍️  Menandatangani sertifikat dengan Root CA...${NC}"
openssl x509 -req -in "$CERT_DIR/openwrt.csr" \
    -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
    -out "$CERT_DIR/openwrt.crt" -days $DAYS_VALID_CERT -sha256 \
    -extfile "$SAN_CONFIG" -extensions req_ext

# 📦 5. Buat file PFX (opsional)
echo -e "${GREEN}📦 Membuat file .pfx untuk import ke Windows/Android...${NC}"
openssl pkcs12 -export \
    -out "$CERT_DIR/openwrt.pfx" \
    -inkey "$CERT_DIR/openwrt.key" \
    -in "$CERT_DIR/openwrt.crt" \
    -certfile "$CERT_DIR/ca.crt" \
    -name "OpenWrt Local Cert" \
    -passout pass:openwrt123

# ✅ Selesai
echo -e "\n${YELLOW}🎉 Sertifikat berhasil dibuat!${NC}"
echo -e "${BLUE}📁 File disimpan di folder: $CERT_DIR${NC}"

echo -e "${GREEN}🔑 File penting:${NC}"
echo -e " - ${YELLOW}ca.crt${NC}       → Install di Android/Linux/Windows sebagai CA certificate"
echo -e " - ${YELLOW}openwrt.crt${NC}   → Sertifikat HTTPS untuk OpenWrt"
echo -e " - ${YELLOW}openwrt.key${NC}   → Private key HTTPS (jangan dibagikan)"
echo -e " - ${YELLOW}openwrt.pfx${NC}   → Import ke Windows/Android (password: ${RED}openwrt123${NC})"

echo -e "\n${BLUE}🚀 Untuk OpenWrt:${NC}"
echo -e " - Salin ${YELLOW}openwrt.crt${NC} dan ${YELLOW}openwrt.key${NC} ke /etc/"
echo -e " - Edit /etc/config/uhttpd agar mengarah ke file tersebut"
echo -e " - Restart uhttpd: ${YELLOW}/etc/init.d/uhttpd restart${NC}\n"
