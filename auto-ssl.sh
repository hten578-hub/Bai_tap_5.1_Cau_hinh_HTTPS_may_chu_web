#!/bin/bash
#
# auto-ssl.sh — Tự động hoá cài đặt SSL Let's Encrypt + cấu hình HTTPS trên Nginx
#
# Cách dùng:
#   sudo bash auto-ssl.sh example.com
#
# Script sẽ:
#   1. Cài đặt Nginx + Certbot
#   2. Tạo Virtual Host HTTP ban đầu
#   3. Xin cấp chứng chỉ SSL từ Let's Encrypt
#   4. Cấu hình HTTPS + redirect + HSTS
#   5. Test dry-run gia hạn
#

set -e

# ── Kiểm tra quyền root ──
if [ "$EUID" -ne 0 ]; then
  echo "❌ Vui lòng chạy bằng sudo: sudo bash $0 <domain>"
  exit 1
fi

# ── Kiểm tra tham số domain ──
DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "❌ Cú pháp: sudo bash $0 <domain>"
  echo "   Ví dụ:   sudo bash $0 example.com"
  exit 1
fi

EMAIL="${2:-admin@${DOMAIN}}"
WEB_DIR="/var/www/${DOMAIN}/html"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"

echo "============================================"
echo "  Tự động cài đặt SSL Let's Encrypt"
echo "  Domain : ${DOMAIN}"
echo "  Email  : ${EMAIL}"
echo "  Web Dir: ${WEB_DIR}"
echo "============================================"
echo ""

# ── Bước 1: Cập nhật hệ thống + cài Nginx ──
echo "[1/6] Cài đặt Nginx..."
apt update -y
apt install -y nginx certbot python3-certbot-nginx

# ── Bước 2: Tạo thư mục web + trang index ──
echo "[2/6] Tạo thư mục web và trang index..."
mkdir -p "${WEB_DIR}"
chown -R www-data:www-data "${WEB_DIR}"

cat > "${WEB_DIR}/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${DOMAIN} — SSL Let's Encrypt</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex; justify-content: center; align-items: center;
            min-height: 100vh; margin: 0;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: #fff;
        }
        .card {
            background: rgba(255,255,255,0.15);
            padding: 40px 60px; border-radius: 16px;
            text-align: center; backdrop-filter: blur(10px);
        }
        h1 { margin: 0 0 10px; }
        p { margin: 5px 0; opacity: 0.9; }
        .lock { font-size: 48px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="lock">🔒</div>
        <h1>${DOMAIN}</h1>
        <p>Bảo mật bởi Let's Encrypt SSL</p>
        <p>HTTPS đã được kích hoạt</p>
    </div>
</body>
</html>
HTMLEOF

# ── Bước 3: Tạo Virtual Host HTTP ──
echo "[3/6] Tạo Virtual Host HTTP..."
cat > "${NGINX_CONF}" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    root ${WEB_DIR};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINXEOF

ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "  ✓ Virtual Host HTTP đã được tạo"

# ── Bước 4: Xin cấp chứng chỉ SSL ──
echo "[4/6] Xin cấp chứng chỉ SSL từ Let's Encrypt..."
certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --redirect

echo "  ✓ Chứng chỉ SSL đã được cấp"

# ── Bước 5: Thêm cấu hình bảo mật bổ sung ──
echo "[5/6] Thêm cấu hình bảo mật SSL..."

# Ghi đè file config với cấu hình đầy đủ bảo mật
cat > "${NGINX_CONF}" << NGINXFULL
# HTTP — redirect sang HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTPS
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${DOMAIN} www.${DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    ssl_stapling on;
    ssl_stapling_verify on;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    root ${WEB_DIR};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINXFULL

nginx -t
systemctl reload nginx

echo "  ✓ Cấu hình HTTPS + HSTS + redirect đã được áp dụng"

# ── Bước 6: Test gia hạn ──
echo "[6/6] Test gia hạn (dry-run)..."
certbot renew --dry-run

echo ""
echo "============================================"
echo "  ✅ HOÀN TẤT!"
echo "============================================"
echo ""
echo "  Website:  https://${DOMAIN}"
echo "  Cert:     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  Config:   ${NGINX_CONF}"
echo ""
echo "  Kiểm tra:"
echo "    curl -I https://${DOMAIN}"
echo "    openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} </dev/null"
echo ""
echo "  Gia hạn thủ công:"
echo "    sudo certbot renew"
echo "    sudo certbot renew --dry-run"
echo ""
echo "============================================"
