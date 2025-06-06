#!/bin/bash

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Welcome message
cat <<EOF
=====================================
 Chromium Remote Browser Installer
 Optimized for 8-core/32GB servers
=====================================
EOF

# User inputs
read -p "Enter Chromium username: " chromium_user
read -sp "Enter Chromium password: " chromium_pass && echo
read -p "Timezone (e.g. Asia/Kolkata): " chromium_tz
read -p "Homepage URL [default: https://google.com]: " homepage
homepage=${homepage:-https://google.com}

# System optimization
echo -e "\n\033[1;32m[1/5] Optimizing system for maximum performance...\033[0m"
{
  echo "vm.swappiness=10"
  echo "vm.vfs_cache_pressure=50"
  echo "fs.file-max=2097152"
  echo "net.core.somaxconn=65535"
} >> /etc/sysctl.conf
sysctl -p

# Install Docker
echo -e "\n\033[1;32m[2/5] Installing Docker engine...\033[0m"
apt update
apt remove -y docker docker-engine docker.io containerd runc
apt install -y apt-transport-https ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker $SUDO_USER

# Create Chromium directory
echo -e "\n\033[1;32m[3/5] Configuring Chromium environment...\033[0m"
mkdir -p /opt/chromium/{config,data}
cd /opt/chromium

# Generate docker-compose.yaml
cat > docker-compose.yaml <<EOF
version: '3.8'
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    privileged: true
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    deploy:
      resources:
        limits:
          cpus: '7.0'
          memory: 24G
        reservations:
          memory: 16G
    shm_size: "8gb"
    environment:
      - CUSTOM_USER=$chromium_user
      - PASSWORD=$chromium_pass
      - PUID=1000
      - PGID=1000
      - TZ=$chromium_tz
      - CHROME_CLI=$homepage
      - DISABLE_GPU=false
      - CHROMIUM_FLAGS=--no-sandbox --disable-dev-shm-usage --ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --max-active-webgl-contexts=32 --max-gum-fps=60 --num-raster-threads=8
    volumes:
      - ./config:/config
      - /dev/shm:/dev/shm
      - /tmp/.X11-unix:/tmp/.X11-unix
    ports:
      - "3010:3000"
      - "3011:3001"
    network_mode: host
    restart: unless-stopped
EOF

# Start Chromium
echo -e "\n\033[1;32m[4/5] Launching Chromium container...\033[0m"
docker compose up -d

# Get IP address
ip_address=$(hostname -I | awk '{print $1}')

# Final instructions
echo -e "\n\033[1;32m[5/5] Installation complete!\033[0m"
cat <<EOF

==================================================
 Chromium Remote Browser Access Instructions
==================================================
Access URLS:
  - http://$ip_address:3010
  - https://$ip_address:3011

Credentials:
  Username: $chromium_user
  Password: $chromium_pass

Firewall Configuration (if blocked):
  Open ports 3010 (HTTP) and 3011 (HTTPS)
  For Google Cloud: Create firewall rule for ports 3010-3011

Management Commands:
  Stop Chromium:   docker stop chromium
  Start Chromium:  docker start chromium
  View Logs:       docker logs -f chromium
  Uninstall:       cd /opt/chromium && docker compose down --rmi all

Note: First launch may take 1-2 minutes while downloading browser data
==================================================
EOF
