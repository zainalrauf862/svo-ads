#!/usr/bin/env bash
# Pemasang Dashboard Iklan Tim SE di VPS (jalankan sebagai root)
set -e
DOMAIN="tim.dash-adszainal.tech"
REPO="https://raw.githubusercontent.com/zainalrauf862/svo-ads/main"

echo "==================================================="
echo "   Pasang Dashboard Iklan Tim SE  ($DOMAIN)"
echo "==================================================="

echo "[1/7] Install paket…"
apt-get update -y -qq
apt-get install -y -qq nginx python3 apache2-utils curl >/dev/null

echo "[2/7] Ambil file dashboard & skrip…"
mkdir -p /opt/svo-ads /var/www/tim
curl -fsSL "$REPO/fetch.py"    -o /opt/svo-ads/fetch.py
curl -fsSL "$REPO/index.html"  -o /var/www/tim/index.html
curl -fsSL "$REPO/iklan.html"  -o /var/www/tim/iklan.html

# accounts.json (mapping akun -> SE). Awal: SVO SONYA - 01
if [ ! -f /opt/svo-ads/accounts.json ]; then
  cat > /opt/svo-ads/accounts.json <<'JSON'
{
  "1336003693740549": { "se": "Sonya", "de": "", "produk": "" }
}
JSON
fi

echo "[3/7] Simpan token…"
if [ ! -s /opt/svo-ads/token.txt ]; then
  echo
  read -r -s -p "   Tempel TOKEN Meta lalu tekan Enter: " TK; echo
  printf '%s' "$TK" > /opt/svo-ads/token.txt
fi
chmod 600 /opt/svo-ads/token.txt

echo "[4/7] Buat password login (username: tim)…"
if [ ! -f /etc/nginx/.htpasswd-tim ]; then
  htpasswd -c /etc/nginx/.htpasswd-tim tim
fi

echo "[5/7] Konfigurasi nginx…"
cat > /etc/nginx/sites-available/tim <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root /var/www/tim;
    index index.html;
    location = /data.json { add_header Cache-Control "no-store"; auth_basic "Dashboard Iklan Tim SE"; auth_basic_user_file /etc/nginx/.htpasswd-tim; }
    location / {
        auth_basic "Dashboard Iklan Tim SE";
        auth_basic_user_file /etc/nginx/.htpasswd-tim;
        try_files \$uri \$uri/ =404;
    }
}
EOF
ln -sf /etc/nginx/sites-available/tim /etc/nginx/sites-enabled/tim
nginx -t && systemctl reload nginx
ufw allow 'Nginx Full' >/dev/null 2>&1 || true

echo "[6/7] Tarik data pertama dari Meta…"
python3 /opt/svo-ads/fetch.py || echo "   (!) fetch pertama gagal — cek token/akun. Bisa diulang nanti."

echo "[7/7] Pasang jadwal otomatis (tiap 30 menit)…"
( crontab -l 2>/dev/null | grep -v 'svo-ads/fetch.py' ; \
  echo "*/30 * * * * /usr/bin/python3 /opt/svo-ads/fetch.py >/var/log/svo-ads.log 2>&1" ) | crontab -

echo
echo "==================================================="
echo "  SELESAI ✅"
echo "  Berikutnya:"
echo "  1) Pastikan DNS Hostinger: A record 'tim' -> IP VPS"
echo "  2) Pasang HTTPS:  certbot --nginx -d $DOMAIN"
echo "  3) Buka: http://$DOMAIN   (login user: tim)"
echo "==================================================="
