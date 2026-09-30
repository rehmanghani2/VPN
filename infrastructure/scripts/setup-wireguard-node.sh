#!/usr/bin/env bash
# ==============================================================================
# Commercial VPN Platform - Phase 1: WireGuard Edge Node Provisioning Script
# Supported OS: Ubuntu 22.04 / 24.04 LTS, Debian 11 / 12
# Features:
#   - Automated Linux kernel optimization (BBR, packet forwarding, buffer tuning)
#   - Zero-leak Unbound recursive DNS resolver with DNSSEC (no upstream ISP logs)
#   - WireGuard server configuration with iptables NAT masquerade
#   - Automated generation of test client configuration & terminal QR code
# ==============================================================================

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root (use sudo)." >&2
   exit 1
fi

echo "================================================================="
echo "   COMMERCIAL VPN PLATFORM: WIREGUARD NODE PROVISIONING          "
echo "================================================================="

# --- 1. Detect Network Configuration ---
WAN_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -n1)
if [[ -z "$WAN_IFACE" ]]; then
    echo "[ERROR] Could not automatically detect public network interface." >&2
    exit 1
fi

SERVER_PUB_IP=$(curl -s4 --max-time 5 https://ifconfig.me || curl -s4 --max-time 5 https://api.ipify.org)
if [[ -z "$SERVER_PUB_IP" ]]; then
    echo "[ERROR] Could not detect public IPv4 address." >&2
    exit 1
fi

echo "[INFO] Network Interface: ${WAN_IFACE}"
echo "[INFO] Public IP Address: ${SERVER_PUB_IP}"

# Network Subnets
WG_PORT=51820
WG_NET_V4="10.8.0.0/24"
WG_SRV_IP_V4="10.8.0.1"
WG_NET_V6="fd42:42:42::/64"
WG_SRV_IP_V6="fd42:42:42::1"
DNS_RESOLVER_V4="10.8.0.1"
DNS_RESOLVER_V6="fd42:42:42::1"

# --- 2. Update System & Install Dependencies ---
echo "[INFO] Updating package lists and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y wireguard wireguard-tools iptables ufw unbound unbound-host qrencode curl dnsutils bc

# --- 3. Linux Kernel & Networking Optimization ---
echo "[INFO] Configuring kernel parameters (/etc/sysctl.d/99-vpn-tuning.conf)..."
cat > /etc/sysctl.d/99-vpn-tuning.conf <<EOF
# Commercial VPN Kernel Tuning
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# BBR Congestion Control for high-throughput, low-latency streaming
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Socket Buffer Optimization
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Connection & Anti-Spoofing Hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.core.netdev_max_backlog = 10000
EOF

sysctl --system > /dev/null 2>&1

# --- 4. Configure Unbound Local Recursive DNS (Zero-Leak) ---
echo "[INFO] Setting up Unbound Recursive DNS server..."
cat > /etc/unbound/unbound.conf.d/vpn-resolver.conf <<EOF
server:
    num-threads: 2
    verbosity: 0
    interface: ${WG_SRV_IP_V4}
    interface: ${WG_SRV_IP_V6}
    port: 53
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes

    # Access control: Only allow VPN tunnel clients
    access-control: 127.0.0.1/32 allow
    access-control: ${WG_NET_V4} allow
    access-control: ${WG_NET_V6} allow

    # Privacy & Zero-Logging
    hide-identity: yes
    hide-version: yes
    use-caps-for-id: yes
    log-queries: no
    log-replies: no
    log-tag-queryreply: no

    # DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    val-clean-additional: yes

    # Performance Caching
    prefetch: yes
    prefetch-key: yes
    msg-cache-size: 64m
    rrset-cache-size: 128m
EOF

# Restart and enable Unbound
systemctl restart unbound
systemctl enable unbound

# --- 5. Generate WireGuard Server Keys ---
echo "[INFO] Generating WireGuard cryptographic keys..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

echo "$SERVER_PRIV_KEY" > /etc/wireguard/server_private.key
echo "$SERVER_PUB_KEY" > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

# --- 6. Configure WireGuard Interface (wg0) ---
echo "[INFO] Writing WireGuard configuration (/etc/wireguard/wg0.conf)..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${WG_SRV_IP_V4}/24, ${WG_SRV_IP_V6}/64
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV_KEY}

# Firewall & NAT Masquerading Rules
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IFACE} -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${WAN_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IFACE} -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${WAN_IFACE} -j MASQUERADE

# Client peers will be appended below
EOF

chmod 600 /etc/wireguard/wg0.conf

# Start WireGuard service
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# --- 7. Create Helper Script to Add Clients on Node ---
cat > /usr/local/bin/vpn-add-client << 'ADDCLIENT_EOF'
#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${1:-client1}"
WG_CONF="/etc/wireguard/wg0.conf"
SERVER_PUB_KEY=$(cat /etc/wireguard/server_public.key)
SERVER_ENDPOINT="$(curl -s4 https://ifconfig.me):51820"

# Determine next available IPv4 address
LAST_OCTET=$(grep -E 'AllowedIPs = 10\.8\.0\.' "$WG_CONF" | awk '{print $3}' | cut -d'.' -f4 | cut -d'/' -f1 | sort -n | tail -n1)
if [[ -z "$LAST_OCTET" ]]; then
    NEXT_OCTET=2
else
    NEXT_OCTET=$((LAST_OCTET + 1))
fi

CLIENT_IP_V4="10.8.0.${NEXT_OCTET}"
CLIENT_IP_V6="fd42:42:42::${NEXT_OCTET}"

CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)
CLIENT_PRESHARED_KEY=$(wg genpsk)

# Append peer to server wg0.conf
cat >> "$WG_CONF" <<PEER_EOF

# Peer: ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRESHARED_KEY}
AllowedIPs = ${CLIENT_IP_V4}/32, ${CLIENT_IP_V6}/128
PEER_EOF

# Apply peer directly to running wireguard interface without restarting
wg set wg0 peer "$CLIENT_PUB_KEY" preshared-key <(echo "$CLIENT_PRESHARED_KEY") allowed-ips "${CLIENT_IP_V4}/32,${CLIENT_IP_V6}/128"

# Output client configuration file
CLIENT_DIR="/root/wireguard-clients"
mkdir -p "$CLIENT_DIR"
CLIENT_CONF="${CLIENT_DIR}/${CLIENT_NAME}.conf"

cat > "$CLIENT_CONF" <<CLIENT_EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_IP_V4}/24, ${CLIENT_IP_V6}/64
DNS = 10.8.0.1, fd42:42:42::1
MTU = 1360

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRESHARED_KEY}
Endpoint = ${SERVER_ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CLIENT_EOF

echo "=========================================================="
echo " Client '${CLIENT_NAME}' created successfully!"
echo " Configuration saved to: ${CLIENT_CONF}"
echo "=========================================================="
echo ""
echo "--- CLIENT CONFIGURATION CONTENT ---"
cat "$CLIENT_CONF"
echo "-------------------------------------"
echo ""
echo "Scan the QR code below using the official WireGuard App on iOS/Android:"
qrencode -t ansiutf8 < "$CLIENT_CONF"
ADDCLIENT_EOF

chmod +x /usr/local/bin/vpn-add-client

# --- 8. Generate First Verification Client ---
echo "[INFO] Creating test client configuration (client1)..."
/usr/local/bin/vpn-add-client client1

echo ""
echo "================================================================="
echo "   WIREGUARD NODE SETUP COMPLETE!                                "
echo "   Test file: /root/wireguard-clients/client1.conf               "
echo "   Add more clients later with: vpn-add-client <name>            "
echo "================================================================="
