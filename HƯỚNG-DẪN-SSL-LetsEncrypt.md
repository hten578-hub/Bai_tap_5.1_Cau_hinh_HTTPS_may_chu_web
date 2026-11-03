# HƯỚNG DẪN CÀI ĐẶT SSL BẰNG LET'S ENCRYPT & CẤU HÌNH VIRTUAL HOST HTTPS

## 1. MỤC TIÊU

- Cài đặt chứng chỉ SSL/TLS miễn phí từ Let's Encrypt bằng Certbot
- Cấu hình Virtual Host (Nginx hoặc Apache) để phục vụ website qua HTTPS
- Kiểm tra, xác minh chứng chỉ hoạt động đúng
- Thiết lập tự động gia hạn chứng chỉ

---

## 2. MÔI TRƯỜNG LAB

| Thành phần | Yêu cầu |
|---|---|
| Hệ điều hành | Ubuntu 22.04 LTS hoặc 24.04 LTS (hoặc Debian 11/12) |
| Web Server | Nginx HOẶC Apache2 |
| Tên miền | Có 1 domain trỏ về IP server (VD: `example.com`) |
| Quyền | User có quyền sudo |
| Port | Port 80 và 443 mở trên firewall |
| RAM | Tối thiểu 512MB (khuyến nghị 1GB+) |

> Nếu chưa có domain thật, có thể dùng dịch vụ DNS động như DuckDNS (`tenban.duckdns.org`) hoặc nostrIP.

---

## 3. CÁC BƯỚC THỰC HÀNH

### Bước 0: Chuẩn bị server

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt Nginx (chọn 1 trong 2)
sudo apt install -y nginx

# HOẶC cài đặt Apache
sudo apt install -y apache2

# Mở port 80 và 443 trên firewall
sudo ufw allow 'Nginx Full'    # hoặc: sudo ufw allow 'Apache Full'
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status
```

### Bước 1: Tạo Virtual Host ban đầu (HTTP)

#### Với Nginx:

```bash
sudo mkdir -p /var/www/example.com/html
sudo chown -R $USER:$USER /var/www/example.com/html

# Tạo file index mẫu
cat << 'EOF' | sudo tee /var/www/example.com/html/index.html
<!DOCTYPE html>
<html>
<head><title>Example.com - SSL Lab</title></head>
<body>
<h1>Chào mừng đến với example.com</h1>
<p>Trang web đã được bảo mật bằng SSL Let's Encrypt.</p>
</body>
</html>
EOF

# Tạo Virtual Host config
sudo tee /etc/nginx/sites-available/example.com << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    root /var/www/example.com/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# Kích hoạt site
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

#### Với Apache:

```bash
sudo mkdir -p /var/www/example.com/html
sudo chown -R $USER:$USER /var/www/example.com/html

# Tạo file index mẫu
cat << 'EOF' | sudo tee /var/www/example.com/html/index.html
<!DOCTYPE html>
<html>
<head><title>Example.com - SSL Lab</title></head>
<body>
<h1>Chào mừng đến với example.com</h1>
<p>Trang web đã được bảo mật bằng SSL Let's Encrypt.</p>
</body>
</html>
EOF

# Tạo Virtual Host config
sudo tee /etc/apache2/sites-available/example.com.conf << 'EOF'
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com
    DocumentRoot /var/www/example.com/html
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Kích hoạt site
sudo a2ensite example.com
sudo a2dissite 000-default
sudo apache2ctl configtest
sudo systemctl reload apache2
```

> Thay `example.com` bằng domain thật của bạn trong mọi lệnh trên.

### Bước 2: Cài đặt Certbot

```bash
# Cài đặt Certbot + plugin cho web server
# Với Nginx:
sudo apt install -y certbot python3-certbot-nginx

# Với Apache:
sudo apt install -y certbot python3-certbot-apache

# Kiểm tra phiên bản
certbot --version
```

### Bước 3: Xin cấp chứng chỉ SSL

#### Cách A: Certbot tự động sửa config (khuyến nghị cho người mới)

```bash
# Nginx:
sudo certbot --nginx -d example.com -d www.example.com

# Apache:
sudo certbot --apache -d example.com -d www.example.com
```

Certbot sẽ:
1. Hỏi email để nhận thông báo hết hạn
2. Đồng ý Điều khoản dịch vụ (Yes)
3. Hỏi có redirect HTTP → HTTPS không → chọn **2** (Redirect)
4. Tự động sửa file Virtual Host thêm block `listen 443 ssl`

#### Cách B: Certbot manual (chỉ lấy cert, tự sửa config thủ công)

```bash
sudo certbot certonly --nginx -d example.com -d www.example.com
# HOẶC
sudo certbot certonly --standalone -d example.com -d www.example.com
```

> Với `--standalone`, cần tạm dừng web server trước (`sudo systemctl stop nginx`) vì Certbot tự mở port 80 để xác thực.

### Bước 4: Cấu hình Virtual Host HTTPS thủ công (nếu dùng certonly)

#### Nginx - file `/etc/nginx/sites-available/example.com`:

```nginx
# HTTP → redirect sang HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;
}

# HTTPS
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name example.com www.example.com;

    # Đường dẫn chứng chỉ (Certbot tự tạo)
    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # Cấu hình SSL an toàn
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;

    # HSTS Header
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    root /var/www/example.com/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Sau đó:
```bash
sudo nginx -t && sudo systemctl reload nginx
```

#### Apache - file `/etc/apache2/sites-available/example.com-le-ssl.conf`:

```apache
<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com
    DocumentRoot /var/www/example.com/html

    SSLEngine on
    SSLCertificateFile      /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile    /etc/letsencrypt/live/example.com/privkey.pem

    # Cấu hình SSL an toàn
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    SSLSessionTickets off

    # HSTS
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

Sau đó:
```bash
sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite example.com-le-ssl
sudo apache2ctl configtest
sudo systemctl reload apache2
```

---

## 4. KIỂM TRA & XÁC MINH

### 4.1. Kiểm tra chứng chỉ đã được cấp

```bash
# Xem thông tin chứng chỉ
sudo certbot certificates

# Xem chi tiết chứng chỉ bằng openssl
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -subject -issuer -dates

# Kết quả mẫu:
# subject=CN=example.com
# issuer=C=US, O=Let's Encrypt, CN=R3
# notBefore=Nov  3 12:00:00 2026 GMT
# notAfter=Feb  1 12:00:00 2027 GMT
```

### 4.2. Kiểm tra trang web load qua HTTPS

```bash
# curl kiểm tra header HTTPS
curl -I https://example.com

# Kết quả mẫu:
# HTTP/2 200
# server: nginx/1.18.0
# date: Tue, 03 Nov 2026 12:00:00 GMT
# content-type: text/html
# strict-transport-security: max-age=63072000; includeSubDomains
```

### 4.3. Kiểm tra bằng openssl s_client

```bash
# Kiểm tra handshake và chứng chỉ
echo | openssl s_client -connect example.com:443 -servername example.com

# Chỉ xem chứng chỉ
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -text -noout

# Kiểm tra chain chứng chỉ
echo | openssl s_client -connect example.com:443 -servername example.com -showcerts 2>/dev/null | grep -E "Verify|verify"
# Kết quả mong đợi: Verify return code: 0 (ok)
```

### 4.4. Kiểm tra redirect HTTP → HTTPS

```bash
curl -I http://example.com
# Kết quả mong đợi: 301 Moved Permanently, Location: https://example.com/
```

### 4.5. Test SSL Labs (online)

Vào trang: **https://www.ssllabs.com/ssltest/analyze.html?d=example.com**

Nhập domain của bạn → chờ kết quả. Mục tiêu đạt **Grade A hoặc A+**.

Chụp màn hình kết quả để đưa vào báo cáo.

### 4.6. Kiểm tra gia hạn (renew)

```bash
# Test gia hạn khô (dry run) - không ghi vào hệ thống
sudo certbot renew --dry-run

# Kết quả mong đợi:
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Processing /etc/letsencrypt/renewal/example.com.conf
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Account registered.
# Simulating renewal of certificate(s) for example.com and www.example.com
# Congratulations, all renewals succeeded.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Kiểm tra timer tự động gia hạn
sudo systemctl list-timers | grep certbot
# Certbot tạo sẵn systemd timer: certbot.timer chạy 2 lần/ngày
```

---

## 5. CẤU TRÚC BÁO CÁO ĐỀ XUẤT (2–4 trang)

### Trang 1
- **Tiêu đề:** Báo cáo thực hành — Cài đặt SSL Let's Encrypt và cấu hình HTTPS
- **Mục tiêu:** Cài đặt SSL miễn phí bằng Let's Encrypt, cấu hình Virtual Host HTTPS, kiểm tra bảo mật
- **Môi trường:** Bảng liệt kê OS, web server, domain, IP

### Trang 2
- **Các lệnh đã chạy:** Copy log terminal từ lúc `apt install certbot` đến `certbot --nginx -d ...`
- **Ảnh màn hình:**
  - Ảnh 1: Certbot thông báo "Successfully received certificate" (output certbot)
  - Ảnh 2: Trình duyệt mở `https://example.com` có biểu tượng ổ khoá (HTTPS)

### Trang 3
- **Kết quả openssl s_client:** Copy output lệnh `openssl s_client -connect ...`
- **Kết quả curl -I:** Copy output `curl -I https://example.com`
- **File cấu hình Virtual Host:** Dán nội dung file `/etc/nginx/sites-available/example.com` (hoặc Apache tương ứng)
- **Ảnh test SSL Labs:** Chụp màn hình kết quả từ ssllabs.com

### Trang 4
- **Kiểm tra renew:** Copy output `sudo certbot renew --dry-run`
- **(Bonus) Kịch bản bash tự động:** Dán nội dung script `auto-ssl.sh` (xem file đính kèm)
- **Kết luận:** Tóm tắt kết quả đạt được

---

## 6. LƯU Ý QUAN TRỌNG

1. **Domain phải trỏ đúng IP** trước khi chạy certbot — kiểm tra bằng `dig example.com` hoặc `nslookup example.com`
2. **Port 80 phải mở** — Let's Encrypt dùng HTTP-01 challenge qua port 80 để xác thực
3. **Chứng chỉ hết hạn sau 90 ngày** — Certbot timer tự động gia hạn, nhưng nên test `--dry-run` định kỳ
4. **Sao lưu config** trước khi sửa: `sudo cp /etc/nginx/sites-available/example.com /etc/nginx/sites-available/example.com.bak`
5. **Nếu dùng Cloudflare proxy** — cần tắt proxy (chuyển sang DNS only / grey cloud) trước khi xin cert, hoặc dùng DNS-01 challenge
6. **Nếu nhiều domain** — thêm nhiều `-d` flag: `-d example.com -d www.example.com -d api.example.com`

---

## 7. KHẮC PHỤC LỖI THƯỜNG GẺP

| Lỗi | Nguyên nhân | Khắc phục |
|---|---|---|
| `Connection refused` | Web server chưa chạy | `sudo systemctl start nginx` |
| `Failed authorization` | Domain chưa trỏ đúng IP | Kiểm tra `dig example.com`, sửa DNS |
| `Port 80 already in use` | Tiến trình khác chiếm port 80 | `sudo lsof -i :80` rồi kill tiến trình |
| `Certificate not yet valid` | Đồng hồ server sai | `sudo apt install ntp && sudo ntpdate pool.ntp.org` |
| `Rate limit` | Xin cert quá nhiều lần | Đợi 1 giờ (5 cert/tuần/domain) |
| `curl: (60) SSL certificate problem` | Chain không đầy đủ | Kiểm tra `fullchain.pem` thay vì `cert.pem` |
