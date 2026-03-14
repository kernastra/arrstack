#!/bin/bash

# ============================================================
#  Color helpers
# ============================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[DONE]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[NOTE]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; }
divider() { echo -e "${BOLD}============================================================${RESET}"; }
pause()   { echo ""; read -rp "$(echo -e "${BOLD}Press ENTER to continue...${RESET}")"; echo ""; }

# ============================================================
#  WELCOME SCREEN
# ============================================================
clear
divider
echo -e "${BOLD}   Media Server Setup Script${RESET}"
echo -e "   Sets up Jellyfin, Sonarr, Radarr, qBittorrent & more"
divider
echo ""
echo "  This script will:"
echo "    1. Install Docker (if not already installed)"
echo "    2. Ask where you want to store your media & config files"
echo "    3. Set up your WireGuard VPN for private downloading"
echo "    4. Generate everything needed to launch your media server"
echo ""
warn "You will be asked a few simple questions. Just follow along!"
pause

# ============================================================
#  STEP 1 — INSTALL DOCKER IF MISSING
# ============================================================
divider
echo -e "${BOLD}  Step 1 of 4 — Docker${RESET}"
divider
echo ""

if command -v docker &>/dev/null; then
    success "Docker is already installed. Moving on."
else
    warn "Docker was not found on this system. Installing it now..."
    echo "  (This may take a few minutes — please don't close the window)"
    echo ""
    sudo apt-get update -y -qq
    sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    success "Docker installed successfully!"
    warn "IMPORTANT: After this script finishes, log out and log back in"
    warn "           so Docker works without 'sudo'."
fi

pause

# ============================================================
#  STEP 2 — STORAGE LOCATION
# ============================================================
divider
echo -e "${BOLD}  Step 2 of 4 — Storage Location${RESET}"
divider
echo ""
echo "  Where do you want to store your media and config files?"
echo "  This should be a folder on your hard drive or NAS."
echo ""
echo "  Examples:"
echo "    /mnt/data       (external drive or NAS)"
echo "    /home/$USER/media  (your home folder)"
echo ""

while true; do
    read -rp "$(echo -e "${BOLD}  Enter the full path: ${RESET}")" BASE_POOL
    if [ -z "$BASE_POOL" ]; then
        error "Path cannot be empty. Please try again."
        continue
    fi
    if [ ! -d "$BASE_POOL" ]; then
        echo ""
        warn "That folder doesn't exist yet."
        read -rp "$(echo -e "${BOLD}  Create it now? [y/n]: ${RESET}")" CREATE_CONFIRM
        if [[ "$CREATE_CONFIRM" =~ ^[Yy]$ ]]; then
            mkdir -p "$BASE_POOL" && success "Folder created: $BASE_POOL" && break
        else
            error "Please enter a path that already exists, or say yes to create it."
        fi
    else
        success "Using: $BASE_POOL"
        break
    fi
done

# ---- Derive sub-directories ----
CONFIG_DIR="$BASE_POOL/configs"
MEDIA_DIR="$BASE_POOL/media"
DOCKER_DIR="$BASE_POOL/docker"
QBIT_WG_DIR="$CONFIG_DIR/qbittorrent/wireguard"

USER_ID=$(id -u)
GROUP_ID=$(id -g)
PRIVATE_IP=$(hostname -I | awk '{print $1}')
CIDR_NETWORK="${PRIVATE_IP%.*}.0/24"

echo ""
info "Creating folder structure..."
mkdir -p "$CONFIG_DIR"/{prowlarr,radarr,sonarr,jellyseerr,profilarr,jellyfin,qbittorrent}
mkdir -p "$MEDIA_DIR"/{movies,tv,downloads}
mkdir -p "$DOCKER_DIR"
mkdir -p "$QBIT_WG_DIR"
sudo chown -R "$USER":"$USER" "$BASE_POOL"
sudo chmod -R 775 "$BASE_POOL"
success "All folders created and permissions set."

pause

# ============================================================
#  STEP 3 — TIMEZONE
# ============================================================
divider
echo -e "${BOLD}  Step 3 of 4 — Timezone${RESET}"
divider
echo ""
echo "  Your timezone keeps schedules and timestamps accurate."
echo ""
echo "  Common examples:"
echo "    America/New_York    America/Chicago    America/Los_Angeles"
echo "    Europe/London       Europe/Berlin      Asia/Tokyo"
echo ""
read -rp "$(echo -e "${BOLD}  Enter your timezone [default: America/New_York]: ${RESET}")" TZ_INPUT
TZ_INPUT="${TZ_INPUT:-America/New_York}"
success "Timezone set to: $TZ_INPUT"

pause

# ============================================================
#  STEP 4 — WIREGUARD VPN
# ============================================================
divider
echo -e "${BOLD}  Step 4 of 4 — VPN (WireGuard)${RESET}"
divider
echo ""
echo "  qBittorrent will route all downloads through a VPN for privacy."
echo "  You need a WireGuard config file from your VPN provider (e.g. AirVPN)."
echo ""
echo "    1) Paste your WireGuard config text directly here"
echo "    2) I already have the .conf file — give the path to it"
echo "    3) Skip for now (you can add it later)"
echo ""
read -rp "$(echo -e "${BOLD}  Choose an option [1/2/3]: ${RESET}")" WG_CHOICE

case $WG_CHOICE in
    1)
        echo ""
        info "Paste your WireGuard config below."
        warn "When you're done pasting, press ENTER then Ctrl+D on a blank line."
        echo ""
        cat > "$QBIT_WG_DIR/wg0.conf"
        success "WireGuard config saved."
        ;;
    2)
        echo ""
        read -rp "$(echo -e "${BOLD}  Enter the full path to your .conf file: ${RESET}")" SOURCE_FILE
        if [ -f "$SOURCE_FILE" ]; then
            cp "$SOURCE_FILE" "$QBIT_WG_DIR/wg0.conf"
            success "Config copied to $QBIT_WG_DIR/wg0.conf"
        else
            error "File not found at: $SOURCE_FILE"
            warn "Skipping VPN config. Add it manually later at:"
            warn "  $QBIT_WG_DIR/wg0.conf"
        fi
        ;;
    *)
        warn "Skipping VPN setup."
        warn "Add your config manually later at: $QBIT_WG_DIR/wg0.conf"
        ;;
esac

pause

# ============================================================
#  GENERATE DOCKER COMPOSE
# ============================================================
info "Generating your docker-compose.yml file..."

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
      - TZ=$TZ_INPUT
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
      - TZ=$TZ_INPUT
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
      - TZ=$TZ_INPUT
    networks:
      - media_network
    volumes:
      - $CONFIG_DIR/jellyseerr:/app/config

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=info
      - TZ=$TZ_INPUT
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
      - TZ=$TZ_INPUT
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
      - TZ=$TZ_INPUT
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

success "docker-compose.yml created at $DOCKER_DIR/docker-compose.yml"

# ============================================================
#  ALL DONE
# ============================================================
echo ""
divider
echo -e "${GREEN}${BOLD}   Setup Complete! Here's what to do next:${RESET}"
divider
echo ""
echo -e "  ${BOLD}1. Start your containers:${RESET}"
echo -e "     ${CYAN}cd $DOCKER_DIR && docker compose up -d${RESET}"
echo ""
echo -e "  ${BOLD}2. Open these in your browser (replace 'localhost' with your"
echo -e "     server's IP address if accessing from another device):${RESET}"
echo ""
echo -e "     ${CYAN}Jellyfin${RESET}     (your media player)  →  http://localhost:8096"
echo -e "     ${CYAN}Jellyseerr${RESET}   (request movies/TV)  →  http://localhost:5055"
echo -e "     ${CYAN}Sonarr${RESET}       (TV shows)           →  http://localhost:8989"
echo -e "     ${CYAN}Radarr${RESET}       (movies)             →  http://localhost:7878"
echo -e "     ${CYAN}Prowlarr${RESET}     (indexers)           →  http://localhost:9696"
echo -e "     ${CYAN}qBittorrent${RESET}  (downloader)         →  http://localhost:8080"
echo ""
echo -e "  ${BOLD}3. Your files are stored at:${RESET}"
echo -e "     Media:   ${CYAN}$MEDIA_DIR${RESET}"
echo -e "     Configs: ${CYAN}$CONFIG_DIR${RESET}"
echo ""
divider
echo ""
