# Bài tập 5.1: Cấu hình HTTPS cho máy chủ web

**Họ và tên:** Nguyễn Thị Huệ Minh  
**Mã sinh viên:** 23810310177  
**Lớp:** D18CNPM3  

---

## Mô tả

Bài tập thực hành cài đặt SSL bằng Let's Encrypt và cấu hình Virtual Host HTTPS trên Nginx.

## Môi trường

- Ubuntu 22.04 LTS (WSL2 trên Windows 11)
- Nginx 1.28.3
- Certbot 4.0.0
- Domain: hueminh.duckdns.org

## Nội dung

- `Nguyễn Thị Huệ Minh - 23810310177 - Bao-cao-SSL-LetsEncrypt.docx` — Báo cáo thực hành
- `auto-ssl.sh` — Script bash tự động hoá cài SSL

## Kết quả

- Chứng chỉ SSL cấp bởi Let's Encrypt, hiệu lực đến 01/02/2027
- HTTPS hoạt động với TLS 1.3
- Redirect HTTP → HTTPS (301)
- HSTS header đã bật
- Verify return code: 0 (ok)
