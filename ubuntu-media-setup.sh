#!/bin/bash

# 1. SETUP PATHS
# Ask for the base pool path
read -p "Enter the full path to your Data/Media pool (e.g., /mnt/data): " BASE_POOL

# Define directories based on the pool path
CONFIG_DIR="$BASE_POOL/configs"
MEDIA_DIR="$BASE_POOL/media"
DOCKER_DIR="$BASE_POOL/docker"
QBIT_WG_DIR="$CONFIG_DIR/qbittorrent/wireguard"

# Get Current User Info for Permissions
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Get Network Info for VPN Killswitch
PRIVATE_IP=$(hostname -I | awk '{print $1}')
CIDR_NETWORK="${PRIVATE_IP%.*}.0/24"

echo "------------------------------------------"
echo "Creating folder structure at $BASE_POOL..."
echo "------------------------------------------"

# Create Folders
mkdir -p "$CONFIG_DIR"/{prowlarr,radarr,sonarr,jellyseerr,profilarr,jellyfin,qbittorrent}
mkdir -p "$MEDIA_DIR"/{movies,tv,downloads}
mkdir -p "$DOCKER_DIR"
mkdir -p "$QBIT_WG_DIR"

# Set Permissions (Using current Ubuntu user)
sudo chown -R $USER:$USER "$BASE_POOL"
sudo chmod -R 775 "$BASE_POOL"

# 2. WIREGUARD CONFIG SECTION
echo ""
echo "WireGuard VPN Setup (AirVPN / Hotio qBittorrent)"
echo "1) Paste your WireGuard config text here (until Ctrl+D)"
echo "2) Provide a path to an existing .conf file on this machine"
echo "3) Skip for now (add manually to $QBIT_WG_DIR/wg0.conf later)"
read -p "Choose an option [1-3]: " WG_CHOICE

case $WG_CHOICE in
    1)
        echo "Please paste your WireGuard configuration below."
        echo "Press ENTER then Ctrl+D when finished."
        cat > "$QBIT_WG_DIR/wg0.conf"
        echo "Saved to $QBIT_WG_DIR/wg0.conf"
        ;;
    2)
        read -p "Enter the full path to your config file: " SOURCE_FILE
        if [ -f "$SOURCE_FILE" ]; then
            cp "$SOURCE_FILE" "$QBIT_WG_DIR/wg0.conf"
            echo "Copied $SOURCE_FILE to $QBIT_WG_DIR/wg0.conf"
        else
            echo "Error: File not found. Skipping VPN config."
        fi
        ;;
    *)
        echo "Skipping VPN config. Remember to add it manually!"
        ;;
esac

# 3. GENERATE DOCKER COMPOSE
echo "Generating docker-compose.yml..."
cat > "$DOCKER_DIR/docker-compose.yml" <<EOF
networks:
  media_network:
    driver: bridge

services:
  prowlarr:
    image: linuxserver/prowlarr
    container_name: prowlarr
    restart: unless-stopped
    ports:
      - 9696:9696
    networks:
      - media_network
    volumes:
      - $CONFIG_DIR/prowlarr:/config
      - $MEDIA_DIR:/media

  radarr:
    image: linuxserver/radarr
    container_name: radarr
    restart: unless-stopped
    ports:
      - 7878:7878
    environment:
      - PUID=$USER_ID
      - PGID=$GROUP_ID
      - TZ=America/New_York
    networks:
      - media_network
    volumes:
      - $CONFIG_DIR/radarr:/config
      - $MEDIA_DIR:/media

  sonarr:
    image: linuxserver/sonarr
    container_name: sonarr
    restart: unless-stopped
    ports:
      - 8989:8989
    environment:
      - PUID=$USER_ID
      - PGID=$GROUP_ID
      - TZ=America/New_York
    networks:
      - media_network
    volumes:
      - $CONFIG_DIR/sonarr:/config
      - $MEDIA_DIR:/media

  jellyseerr:
    image: fallenbagel/jellyseerr
    container_name: jellyseerr
    restart: unless-stopped
    ports:
      - 5055:5055
    environment:
      - TZ=America/New_York
    networks:
      - media_network
    volumes:
      - $CONFIG_DIR/jellyseerr:/app/config
      
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=info
      - TZ=America/New_York
    networks:
      - media_network
    ports:
      - 8191:8191
    restart: unless-stopped

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - 8096:8096
    environment:
      - PUID=$USER_ID
      - PGID=$GROUP_ID
      - TZ=America/New_York
    networks:
      - media_network
    volumes:
      - $CONFIG_DIR/jellyfin:/config
      - $MEDIA_DIR:/media
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  qbittorrent:
    image: ghcr.io/hotio/qbittorrent:release-5.1.2
    container_name: qbittorrent
    restart: unless-stopped
    ports:
      - 8080:8080
    environment:
      - PUID=$USER_ID
      - PGID=$GROUP_ID
      - UMASK=002
      - TZ=America/New_York
      - WEBUI_PORTS=8080/tcp,8080/udp
      - VPN_ENABLED=true
      - VPN_CONF=wg0
      - VPN_PROVIDER=generic
      - VPN_LAN_NETWORK=$CIDR_NETWORK
      - VPN_AUTO_PORT_FORWARD=true
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    volumes:
      - $CONFIG_DIR/qbittorrent:/config
      - $MEDIA_DIR:/media

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo ""
echo "------------------------------------------"
echo "Setup Complete!"
echo "Docker directory: $DOCKER_DIR"
echo "Media directory: $MEDIA_DIR"
echo "------------------------------------------"
echo "To start your containers, run:"
echo "cd $DOCKER_DIR && docker compose up -d"