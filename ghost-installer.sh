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
sudo adduser --gecos "" "$SYS_USER"
sudo usermod -aG sudo "$SYS_USER"

# === MYSQL CREDS ===
read -rsp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""
if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
  echo "❌ MySQL root password cannot be empty. Exiting."
  exit 1
fi

read -rp "Enter Ghost database name [ghost_db]: " GHOST_DB_NAME
GHOST_DB_NAME=${GHOST_DB_NAME:-ghost_db}
read -rp "Enter Ghost DB user [ghost_user]: " GHOST_DB_USER
GHOST_DB_USER=${GHOST_DB_USER:-ghost_user}
read -rsp "Enter Ghost DB user password: " MYSQL_GHOST_PASSWORD
echo ""

# === PREPARE SYSTEM ===
echo "✅ Updating system & installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mysql-server unzip curl ca-certificates sudo python3-certbot-nginx build-essential ufw

# === Enable UFW ports for HTTP/HTTPS ===
sudo ufw allow 'Nginx Full' || true

# === INSTALL NODE + GHOST-CLI ===
echo "✅ Installing Node.js v20 LTS and Ghost CLI..."
sudo apt install -y nodejs npm
sudo npm install -g n
sudo n 20
sudo cp -r /usr/local/n/versions/node/20 /usr/
echo 'export PATH="/usr/local/n/versions/node/20/bin:$PATH"' | sudo tee -a /etc/profile.d/node20.sh
sudo chmod +x /etc/profile.d/node20.sh
source /etc/profile.d/node20.sh
sudo ln -sf /usr/local/bin/node /usr/bin/node
sudo ln -sf /usr/local/bin/npm /usr/bin/npm
sudo npm install -g ghost-cli

echo "Node Version: $(node -v)"
echo "Ghost CLI Version: $(ghost --version)"

# === MYSQL SETUP ===
echo "✅ Configuring MySQL..."

# Set root password and auth method
cat <<EOF | sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# Create Ghost DB + user
cat <<EOF > /tmp/ghost-db.sql
CREATE DATABASE IF NOT EXISTS \`${GHOST_DB_NAME}\`;
CREATE USER IF NOT EXISTS '${GHOST_DB_USER}'@'localhost' IDENTIFIED BY '${MYSQL_GHOST_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${GHOST_DB_NAME}\`.* TO '${GHOST_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < /tmp/ghost-db.sql
rm /tmp/ghost-db.sql

sudo systemctl enable mysql

# === CREATE INSTALL DIR ===
echo "✅ Creating installation directory..."
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$SYS_USER:$SYS_USER" "$INSTALL_DIR"
sudo chmod 775 "$INSTALL_DIR"

# === INSTALL SCRIPT FOR USER ===
INSTALL_SCRIPT=$(cat <<EOF
#!/bin/bash
set -e

export PATH="/usr/local/n/versions/node/20/bin:\$PATH"
cd "/var/www/$DOMAIN_NAME"

echo ""
echo "🚀 You can now run the following command to install Ghost:"
echo ""
echo "ghost install \\\\"
echo "  --db mysql \\\\"
echo "  --dbhost localhost \\\\"
echo "  --dbuser '$GHOST_DB_USER' \\\\"
echo "  --dbpass '$MYSQL_GHOST_PASSWORD' \\\\"
echo "  --dbname '$GHOST_DB_NAME' \\\\"
echo "  --url 'https://$GHOST_DOMAIN' \\\\"
echo "  --no-prompt \\\\"
echo "  --no-setup-nginx \\\\"
echo "  --no-setup-ssl"
echo ""
echo "👉 After that, run:"
echo "  ghost setup systemd"
echo "  ghost setup nginx"
echo "  ghost setup ssl"
echo ""
EOF
)

echo "$INSTALL_SCRIPT" | sudo tee "/home/$SYS_USER/install_ghost.sh" > /dev/null
sudo chmod +x "/home/$SYS_USER/install_ghost.sh"
sudo chown "$SYS_USER:$SYS_USER" "/home/$SYS_USER/install_ghost.sh"

# === FINISH ===
echo ""
echo "=========================================="
echo "✅ Ghost environment is ready!"
echo ""
echo "👤 Switch to user: sudo su - $SYS_USER"
echo "🚀 Run Ghost installer: bash ~/install_ghost.sh"
echo ""
echo "📝 Then complete SSL & Nginx setup from within Ghost CLI."
echo "=========================================="
