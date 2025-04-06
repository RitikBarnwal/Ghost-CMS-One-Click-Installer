#!/bin/bash

# Ghost CMS Installer for Ubuntu (Interactive One-Click Version)
# Author: Ritik Barnwal — https://ritikbarnwal.in

echo "=========================================="
echo " 🧙 Welcome to Ghost CMS Installer Script"
echo "=========================================="

# === CREATE NEW SYSTEM USER ===
while true; do
  read -rp "Enter a new system username to run Ghost (avoid 'ghost'): " GHOST_SYS_USER
  if [[ "$GHOST_SYS_USER" =~ ^[a-z_][a-z0-9_-]*$ && "$GHOST_SYS_USER" != "ghost" ]]; then
    break
  else
    echo "❌ Invalid or restricted username. Please try again."
  fi
done

if id "$GHOST_SYS_USER" &>/dev/null; then
  echo "✅ User '$GHOST_SYS_USER' already exists. Skipping creation..."
else
  sudo adduser --gecos "" "$GHOST_SYS_USER"
  sudo usermod -aG sudo "$GHOST_SYS_USER"
fi

# === DOMAIN INPUT & VALIDATION ===
while true; do
  read -rp "Enter your domain name (e.g., example.com): " GHOST_DOMAIN
  if [[ "$GHOST_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    break
  else
    echo "❌ Invalid domain format. Please enter a valid domain (e.g., example.com)"
  fi
done

# Extract domain name without TLD
DOMAIN_NAME=$(echo "$GHOST_DOMAIN" | cut -d'.' -f1)
DEFAULT_GHOST_DIR="/var/www/$DOMAIN_NAME"
read -rp "Enter the directory to install Ghost [${DEFAULT_GHOST_DIR}]: " GHOST_DIR
GHOST_DIR=${GHOST_DIR:-$DEFAULT_GHOST_DIR}

read -rsp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""
read -rp "Enter Ghost database name [ghost_db]: " GHOST_DB_NAME
GHOST_DB_NAME=${GHOST_DB_NAME:-ghost_db}
read -rp "Enter Ghost database user [ghost_user]: " GHOST_DB_USER
GHOST_DB_USER=${GHOST_DB_USER:-ghost_user}
read -rsp "Enter password for Ghost database user: " MYSQL_GHOST_PASSWORD
echo ""

# === TEMP SCRIPT TO RUN AS NEW USER ===
TEMP_SCRIPT="/tmp/ghost-install-$RANDOM.sh"

cat <<EOF | sudo tee "$TEMP_SCRIPT" > /dev/null
#!/bin/bash

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing required packages..."
sudo apt install -y nginx mysql-server nodejs npm unzip curl ca-certificates sudo

echo "Setting up MySQL..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
sudo mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE ${GHOST_DB_NAME};"
sudo mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER '${GHOST_DB_USER}'@'localhost' IDENTIFIED BY '${MYSQL_GHOST_PASSWORD}';"
sudo mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${GHOST_DB_NAME}.* TO '${GHOST_DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

echo "Installing Node.js LTS and Ghost CLI..."
sudo npm install -g n
sudo n lts
sudo npm install -g ghost-cli

echo "Setting up directory at ${GHOST_DIR}..."
sudo mkdir -p "$GHOST_DIR"
sudo chown $GHOST_SYS_USER:$GHOST_SYS_USER "$GHOST_DIR"
sudo chmod 775 "$GHOST_DIR"
cd "$GHOST_DIR"

echo "Installing Ghost CMS..."
ghost install \
  --db mysql \
  --dbhost localhost \
  --dbuser "$GHOST_DB_USER" \
  --dbpass "$MYSQL_GHOST_PASSWORD" \
  --dbname "$GHOST_DB_NAME" \
  --no-prompt \
  --no-setup-nginx \
  --no-setup-ssl \
  --no-setup-systemd \
  --url "https://${GHOST_DOMAIN}"

echo "Configuring NGINX..."
sudo tee /etc/nginx/sites-available/ghost > /dev/null <<NGINX
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

echo "Setting up SSL with Let's Encrypt..."
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d "$GHOST_DOMAIN" --non-interactive --agree-tos -m "admin@${GHOST_DOMAIN}"

echo "Setting up Ghost systemd service..."
ghost setup systemd

echo ""
echo "=========================================="
echo " ✅ INSTALLATION COMPLETE"
echo "=========================================="
echo " Domain:           $GHOST_DOMAIN"
echo " Install Path:     $GHOST_DIR"
echo " Database:         $GHOST_DB_NAME"
echo " DB User:          $GHOST_DB_USER"
echo " Ghost URL:        https://$GHOST_DOMAIN"
echo " Admin Panel:      https://$GHOST_DOMAIN/ghost"
echo "=========================================="
EOF

# === EXECUTE AS NEW USER ===
chmod +x "$TEMP_SCRIPT"
sudo -u "$GHOST_SYS_USER" bash "$TEMP_SCRIPT"

# Cleanup
sudo rm -f "$TEMP_SCRIPT"
