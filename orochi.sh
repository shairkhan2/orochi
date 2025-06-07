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

# Auto-detect timezone
detected_tz=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime)
echo "Detected timezone: $detected_tz"

# User inputs
read -p "Chromium username: " chromium_user
read -sp "Chromium password: " chromium_pass && echo
read -p "Timezone [$detected_tz]: " chromium_tz
chromium_tz=${chromium_tz:-$detected_tz}
read -p "Homepage URL [https://google.com]: " homepage
homepage=${homepage:-https://google.com}

# System optimization
echo -e "\n\033[1;32m[1/5] Optimizing system...\033[0m"
{
  echo "vm.swappiness=10"
  echo "vm.vfs_cache_pressure=50"
  echo "fs.file-max=2097152"
  echo "net.core.somaxconn=65535"
  echo "vm.overcommit_memory=1"
} >> /etc/sysctl.conf
sysctl -p

# Fix Docker storage driver
echo -e "\n\033[1;32m[2/5] Configuring Docker...\033[0m"
systemctl stop docker
mkdir -p /etc/docker
echo '{"storage-driver":"vfs"}' > /etc/docker/daemon.json
rm -rf /var/lib/docker/*
systemctl start docker

# Install Docker
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
echo -e "\n\033[1;32m[3/5] Configuring Chromium...\033[0m"
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
    shm_size: "8gb"
    cpus: "7.0"
    mem_limit: 28g
    environment:
      - CUSTOM_USER=$chromium_user
      - PASSWORD=$chromium_pass
      - PUID=1000
      - PGID=1000
      - TZ=$chromium_tz
      - CHROME_CLI=--app=$homepage
      - DISABLE_GPU=false
      - CHROMIUM_FLAGS=\
--no-sandbox \
--ignore-gpu-blocklist \
--disable-gpu \
--num-raster-threads=8 \
--force_cpu_raster \
--disable-accelerated-video-decode \
--disable-background-networking \
--disable-breakpad \
--disable-component-update \
--disable-default-apps \
--disable-dev-shm-usage \
--disable-hang-monitor \
--disable-prompt-on-repost \
--disable-renderer-backgrounding \
--disable-sync \
--disable-background-timer-throttling \
--disable-client-side-phishing-detection \
--disable-domain-reliability \
--disable-features=TranslateUI,BackForwardCache \
--disable-ipc-flooding-protection \
--disable-notifications \
--disable-speech-api \
--metrics-recording-only \
--no-default-browser-check \
--noerrdialogs \
--no-first-run \
--autoplay-policy=no-user-gesture-required \
--password-store=basic \
--js-flags=--max-old-space-size=24576 \
--restore-last-session \
--start-maximized \
--start-fullscreen \
--disable-session-crashed-bubble \
--disable-infobars \
--kiosk
    volumes:
      - ./config:/config
      - /dev/shm:/dev/shm
      - /tmp/.X11-unix:/tmp/.X11-unix
    ports:
      - "3000:3000"
      - "3001:3001"
    restart: unless-stopped
EOF

# Set permissions
chmod 777 -R config/

# Start Chromium
echo -e "\n\033[1;32m[4/5] Launching Chromium...\033[0m"
docker compose up -d

# Get public IP
echo -e "\n\033[1;32m[5/5] Getting access information...\033[0m"
public_ip=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

# Final instructions
cat <<EOF | tee /root/chromium_access.txt

==================================================
 ✅ Chromium Remote Browser Access Instructions ✅
==================================================
Access URLs:
  🌐 HTTP:  http://$public_ip:3000
  🔐 HTTPS: https://$public_ip:3001  (ignore SSL warning)

Credentials:
  👤 Username: $chromium_user
  🔒 Password: $chromium_pass

Firewall Configuration:
  📌 Open ports 3000 (HTTP) and 3001 (HTTPS)
  ☁️  Google Cloud: Create firewall rule for tcp:3000-3001

Management Commands:
  ⛔ Stop Chromium:   cd /opt/chromium && docker compose down
  ▶️  Start Chromium:  cd /opt/chromium && docker compose up -d
  📜 View Logs:       docker logs -f chromium
  ❌ Full Uninstall:  cd /opt/chromium && docker compose down -v --rmi all

🕒 Note: First launch may take 1-2 minutes
📁 Info saved to: /root/chromium_access.txt
==================================================
EOF

