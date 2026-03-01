# 🚀 Ubuntu Media Server Automator

An interactive bash script designed to build a high-performance, atomic-move-ready media stack on Ubuntu Server. This project is heavily inspired by the [Servers@Home](https://github.com/serversathome) workflow and follows the [TRaSH Guides](https://trash-guides.info/) standards for hardlinking and data efficiency.

---

## ✨ Features
- **Atomic Moves & Hardlinks:** Implements the `/data` root structure to ensure instant file moves between downloads and your library without disk overhead.
- **Interactive VPN Setup:** Prompts for AirVPN/WireGuard credentials and generates a secure kill-switch config for the Hotio qBittorrent container.
- **NVIDIA GPU Support:** Pre-configured for **NVIDIA Hardware Transcoding**. Perfect for users with a Quadro P400, RTX 3070, or similar.
- **Complete 'Arr Stack:** One-script setup for Prowlarr, Radarr, Sonarr, Jellyseerr, Jellyfin, and Flaresolverr.
- **Watchtower Integration:** Automatically keeps your containers updated with the latest security patches.

---

## 🛠️ Prerequisites

Before running the script, ensure your Ubuntu server is prepared:

### 1. NVIDIA Drivers & Container Toolkit
If you plan to use an NVIDIA GPU for transcoding (highly recommended for your Quadro P400), run these commands:

```bash
# Install Drivers (535 is the stable choice for Pascal/P400 cards)
sudo apt update && sudo apt install nvidia-driver-535 -y

# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
dsudo apt update && sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 2. Storage Pool
Ensure your ZFS or storage pool is imported and mounted to a directory (e.g., /mnt/data).


🚀 Installation

Run the following one-liner to download and execute the interactive setup script:
```bash
def sudo su -c "wget https://raw.githubusercontent.com/kernastra/arrstack/main/ubuntu-media-setup.sh && chmod +x ubuntu-media-setup.sh && bash ubuntu-media-setup.sh"
```
What the script will ask for:
- **Base Path:** The full path to your mount point (e.g., /mnt/data).
- **VPN Config:** You will be prompted to paste your WireGuard wg0.conf or provide a path to an existing one.


📂 Directory Structure
The script creates a unified structure to enable Atomic Moves:

```
/mnt/data
├── configs/          # Individual app configuration folders
├── docker/           # Location of your docker-compose.yml
└── media/            # Unified media root
    ├── downloads/    # Combined torrent/usenet download folder
    ├── movies/       # Final Movie library
    └── tv/           # Final TV library
```

🐳 Post-Installation
Once the script finishes, navigate to your docker directory and start the stack:
```bash
cd /mnt/data/docker
docker compose up -d
```
Dashboard Access:

```
| Service       | Default Port        |
|---------------|---------------------|
| Jellyfin      | http://your-ip:8096 |
| qBittorrent   | http://your-ip:8080 |
| Sonarr        | http://your-ip:8989 |
| Radarr        | http://your-ip:7878 |
| Prowlarr      | http://your-ip:9696 |
```


# 🔧 Troubleshooting

### 1. NVIDIA GPU Not Found
If Jellyfin doesn't see your **Quadro P400**, verify the drivers are loaded on the host:
```bash
nvidia-smi
```

If this command returns an error, the driver is not installed correctly. If it works, but the container still fails, verify the NVIDIA Container Runtime is the default:
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 2. "Permission Denied" in Apps
If Sonarr or Radarr cannot write to your media folders, it is usually because the BASE_POOL permissions were not inherited. Fix them manually with:
```bash
# Replace 'yourusername' with your actual Ubuntu user
sudo chown -R $USER:$USER /mnt/data
sudo chmod -R 775 /mnt/data
```

### 3. qBittorrent Not Starting (VPN Issues)
If qBittorrent is stuck or crashing, it is likely a WireGuard config issue.
- Check the logs: `docker logs qbittorrent`
- Ensure your `wg0.conf` is in the correct folder: `/mnt/data/configs/qbittorrent/wireguard/`
- Verify the `VPN_LAN_NETWORK` in the `docker-compose.yml` matches your local subnet (e.g., `192.168.1.0/24`).

### 4. ZFS Pool Not Mounting on Reboot
If your media disappears after a reboot, ensure your ZFS pool is set to automount:
```bash
sudo zfs set mountpoint=/mnt/data your_pool_name
def sudo zfs set canmount=on your_pool_name
```

### 5. Atomic Moves Not Working
If you see "Copying" instead of "Moving" in the logs, ensure you are mapping the root folder in your Docker containers.
- Incorrect: `- /mnt/data/media/movies:/movies`
- Correct: `- /mnt/data/media:/media`
All apps must see the same `/media` root to enable hardlinks.

---

🤝 Credits:
- Servers@Home for the logic and script inspiration.
- TRaSH Guides for the hardlinking folder structure.
- Hotio for the excellent WireGuard-integrated Docker images.

---

📜 License:
MIT License - Feel free to use and modify for your own home lab!