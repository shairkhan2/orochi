#!/bin/bash

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "=================================="
echo " Apache Guacamole + XFCE + Chromium"
echo "=================================="

apt update
apt install -y docker.io docker-compose curl gnupg

mkdir -p /opt/guac
cd /opt/guac

# Write docker-compose.yaml with chromium auto-opening your URL
cat > docker-compose.yaml <<EOF
version: "3.8"

services:
  guacd:
    image: guacamole/guacd
    container_name: guacd
    restart: always

  guacamole:
    image: guacamole/guacamole
    container_name: guacamole
    depends_on:
      - guacd
      - postgres
    environment:
      GUACD_HOSTNAME: guacd
      POSTGRES_HOSTNAME: postgres
      POSTGRES_DATABASE: guacamole_db
      POSTGRES_USER: guac_user
      POSTGRES_PASSWORD: guac_pass
      GUACAMOLE_HOME: /guac-home
    volumes:
      - ./guac-home:/guac-home
    ports:
      - "8080:8080"
    restart: always

  postgres:
    image: postgres:14
    container_name: guac-db
    environment:
      POSTGRES_DB: guacamole_db
      POSTGRES_USER: guac_user
      POSTGRES_PASSWORD: guac_pass
    volumes:
      - ./init:/docker-entrypoint-initdb.d
      - pgdata:/var/lib/postgresql/data
    restart: always

  xfce-chromium:
    image: dorowu/ubuntu-desktop-lxde-vnc
    container_name: xfce-chromium
    environment:
      - USER=root
      - VNC_PASSWORD=password
      - RESOLUTION=1280x800
    ports:
      - "5901:5901"
    shm_size: 2gb
    restart: always
    volumes:
      - /dev/shm:/dev/shm
    command: >
      /bin/bash -c "chromium-browser --no-sandbox --disable-dev-shm-usage 'https://onprover.orochi.network/?referralCode=8K3d_boisss' && /usr/bin/supervisord -n"

volumes:
  pgdata:
EOF

# Prepare Guacamole DB initialization scripts
mkdir -p init
curl -sL https://raw.githubusercontent.com/apache/guacamole-client/master/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-postgresql/schema/001-create-schema.sql -o init/001-create-schema.sql
curl -sL https://raw.githubusercontent.com/apache/guacamole-client/master/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-postgresql/schema/002-create-admin-user.sql -o init/002-create-admin-user.sql

# Start all containers
docker compose up -d

# Show connection info
public_ip=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo ""
echo "==========================================="
echo " Guacamole Remote Desktop with Chromium"
echo "==========================================="
echo "Open in your browser:"
echo "  http://$public_ip:8080/guacamole"
echo ""
echo "Default login:"
echo "  Username: guacadmin"
echo "  Password: guacadmin"
echo ""
echo "Internal VNC (for info only):"
echo "  Host: xfce-chromium"
echo "  Port: 5901"
echo ""
echo "IMPORTANT: Change default password after first login!"

