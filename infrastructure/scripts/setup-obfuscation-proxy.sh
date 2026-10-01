#!/usr/bin/env bash
# ==============================================================================
# Commercial VPN Platform - Phase 4: Anti-DPI & Stealth Obfuscation Proxy Setup
# Supported OS: Ubuntu 22.04 / 24.04 LTS, Debian 11 / 12
# Features:
#   - Deploys Anti-DPI Obfuscation Proxy on Port 443
#   - Proxies obfuscated UDP traffic into local WireGuard (127.0.0.1:51820)
#   - Active Probing Defense against Deep Packet Inspection (DPI) scanners
#   - Configures systemd service with automatic resurrection
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root (use sudo)." >&2
   exit 1
fi

echo "================================================================="
echo "   COMMERCIAL VPN PLATFORM: ANTI-DPI OBFUSCATION PROXY SETUP     "
echo "================================================================="

# Install Node.js if not present
if ! command -v node >/dev/null 2>&1; then
    echo "[INFO] Installing Node.js..."
    apt-get update -y
    apt-get install -y nodejs
fi

# Directory setup
mkdir -p /opt/vpn-obfuscation-proxy
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Deploy proxy script
if [[ -f "${SCRIPT_DIR}/../obfuscation/obfuscation-proxy.js" ]]; then
    cp "${SCRIPT_DIR}/../obfuscation/obfuscation-proxy.js" /opt/vpn-obfuscation-proxy/
else
    echo "[ERROR] obfuscation-proxy.js source not found." >&2
    exit 1
fi

chmod +x /opt/vpn-obfuscation-proxy/obfuscation-proxy.js

# Deploy systemd service unit
if [[ -f "${SCRIPT_DIR}/../obfuscation/vpn-obfuscation-proxy.service" ]]; then
    cp "${SCRIPT_DIR}/../obfuscation/vpn-obfuscation-proxy.service" /etc/systemd/system/
fi

systemctl daemon-reload
systemctl enable --now vpn-obfuscation-proxy

# Firewall configuration: open port 443 TCP/UDP
if command -v ufw >/dev/null 2>&1; then
    ufw allow 443/udp comment 'Antigravity VPN Stealth UDP' > /dev/null 2>&1 || true
    ufw allow 443/tcp comment 'Antigravity VPN Camouflage TCP' > /dev/null 2>&1 || true
fi

echo ""
echo "================================================================="
echo "   ANTI-DPI OBFUSCATION PROXY INSTALLED SUCCESSFULLY!           "
echo "   Status: systemctl status vpn-obfuscation-proxy                "
echo "   Port: 443 (Camouflaged HTTPS & Stealth WireGuard)             "
echo "================================================================="
