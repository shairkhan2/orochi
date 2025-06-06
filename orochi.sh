#!/bin/bash

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "============================="
echo "  Apache Guacamole Installer"
echo "  Remote Chromium with GUI"
echo "============================="

apt update
apt install -y docker.io docker-compose curl gnupg

mkdir -p /opt/guac
cd /opt/guac

# Docker Compose for Guacamole + XFCE + Chromium
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

volumes:
  pgdata:
EOF

# SQL Init for Guacamole DB
mkdir -p init
curl -sL https://raw.githubusercontent.com/apache/guacamole-client/master/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-postgresql/schema/001-create-schema.sql -o init/001-create-schema.sql
curl -sL https://raw.githubusercontent.com/apache/guacamole-client/master/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-postgresql/schema/002-create-admin-user.sql -o init/002-create-admin-user.sql

# Start containers
docker compose up -d

# Show info
public_ip=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')
echo ""
echo "==========================================="
echo " Guacamole Remote Desktop with Chromium"
echo "==========================================="
echo "URL:       http://$public_ip:8080/guacamole"
echo "Username:  guacadmin"
echo "Password:  guacadmin"
echo ""
echo "VNC (internal): Host: xfce-chromium, Port: 5901"
echo "Change default password after login!"
