#!/bin/bash
set -e

# Konfigurasi Database & User
DB_NAME="db_cms"
DB_USER="user_cms"
DB_PASS="password_db"

echo "=== 1. Memperbarui Repositori & Memasang Paket ==="
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install nginx mariadb-server php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip unzip curl tar -y

echo "=== 2. Mengaktifkan Service ==="
systemctl enable nginx
systemctl start nginx
systemctl enable mariadb
systemctl start mariadb

echo "=== 3. Membuat Database MariaDB ==="
mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "=== 4. Mengunduh & Mengekstrak WordPress ==="
rm -rf /var/www/html/*
curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf /tmp/wordpress.tar.gz -C /tmp/
cp -r /tmp/wordpress/* /var/www/html/
rm -rf /tmp/wordpress /tmp/wordpress.tar.gz

echo "=== 5. Mengatur Konfigurasi Nginx ==="
PHP_SOCK=$(find /run/php/ -name "php*-fpm.sock" | head -n 1)

cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

echo "=== 6. Mengatur Hak Akses Direktori ==="
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

echo "=== 7. Restart Nginx ==="
nginx -t
systemctl restart nginx

echo "=== Instalasi Selesai! Web siap diakses. ==="
