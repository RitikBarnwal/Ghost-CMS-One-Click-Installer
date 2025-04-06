#!/bin/bash

# Ghost CMS Auto Installer for Ubuntu (One-Click)
# Author: Ritik Barnwal — https://ritikbarnwal.in

set -e

echo "=========================================="
echo " 🧙 Welcome to Ghost CMS Installer Script"
echo " 🧙 Author: Ritik Barnwal — https://ritikbarnwal.in"
echo "=========================================="

# === GET DOMAIN ===
while true; do
  read -rp "Enter your domain (e.g., example.com): " GHOST_DOMAIN
  if [[ "$GHOST_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    break
  else
    echo "❌ Invalid domain. Please try again."
  fi
done

# Extract short name from domain (example.com -> example)
DOMAIN_NAME=$(echo "$GHOST_DOMAIN" | cut -d'.' -f1)
INSTALL_DIR="/var/www/$DOMAIN_NAME"

# === NEW SYSTEM USER ===
read -rp "Enter the Linux username to create (e.g., ghostuser): " SYS_USER

# Create user with home dir, add to sudo
sudo adduser --gecos "" "$SYS_USER"
sudo usermod -aG sudo "$SYS_USER"

# === MYSQL CREDS ===
read -rsp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""
read -rp "Enter Ghost database name [ghost_db]: " GHOST_DB_NAME
GHOST_DB_NAME=${GHOST_DB_NAME:-ghost_db}

read -rp "Enter Ghost DB user [ghost_user]: " GHOST_DB_USER
GHOST_DB_USER=${GHOST_DB_USER:-ghost_user}

read -rsp "Enter Ghost DB user password: " MYSQL_GHOST_PASSWORD
echo ""

# === PREPARE SYSTEM ===
echo "✅ Updating system & installing packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mysql-server nodejs npm unzip curl ca-certificates sudo

# === MYSQL SETUP ===
echo "✅ Configuring MySQL..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
sudo mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE ${GHOST_DB_NAME};"
sudo mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER '${GHOST_DB_USER}'@'localhost' IDENTIFIED BY '${MYSQL_GHOST_PASSWORD}';"
sudo mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${GHOST_DB_NAME}.* TO '${GHOST_DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

# === INSTALL NODE + GHOST-CLI ===
echo "✅ Installing Node LTS and Ghost CLI..."
sudo npm install -g n
sudo n lts
sudo npm install -g ghost-cli

# === CREATE INSTALL DIR ===
echo "✅ Creating installation directory..."
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$SYS_USER":"$SYS_USER" "$INSTALL_DIR"
sudo chmod 775 "$INSTALL_DIR"

# === SCRIPT TO RUN AS NEW USER ===
INSTALL_SCRIPT=$(cat <<EOF
#!/bin/bash
set -e

cd "$INSTALL_DIR"

ghost install \\
  --db mysql \\
  --dbhost localhost \\
  --dbuser "$GHOST_DB_USER" \\
  --dbpass "$MYSQL_GHOST_PASSWORD" \\
  --dbname "$GHOST_DB_NAME" \\
  --url "https://$GHOST_DOMAIN" \\
  --no-prompt \\
  --no-setup-nginx \\
  --no-setup-ssl

echo "✅ Setting up systemd service for Ghost..."
sudo ghost setup systemd

echo "✅ Setting up NGINX config..."
sudo tee /etc/nginx/sites-available/ghost <<NGINX
server {
    listen 80;
    server_name $GHOST_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:2368;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/ghost /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

echo "✅ Installing SSL via Certbot..."
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d "$GHOST_DOMAIN" --non-interactive --agree-tos -m "admin@$GHOST_DOMAIN"

echo ""
echo "=========================================="
echo " ✅ INSTALLATION COMPLETE"
echo "=========================================="
echo " URL: https://$GHOST_DOMAIN"
echo " Admin: https://$GHOST_DOMAIN/ghost"
echo " Directory: $INSTALL_DIR"
EOF
)

# Save the inner script and pass to the new user
echo "$INSTALL_SCRIPT" | sudo tee "/home/$SYS_USER/install_ghost.sh" > /dev/null
sudo chmod +x "/home/$SYS_USER/install_ghost.sh"
sudo chown "$SYS_USER:$SYS_USER" "/home/$SYS_USER/install_ghost.sh"

# === SWITCH & EXECUTE AS NEW USER ===
echo "🚀 Switching to user $SYS_USER to finish Ghost installation..."
sudo -u "$SYS_USER" bash "/home/$SYS_USER/install_ghost.sh"
