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
apt-get install -y wireguard wireguard-tools iptables ufw unbound unbound-host qrencode curl dnsutils bc nodejs

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

# --- 9. Install & Launch Antigravity Edge Node Agent (Dynamic Sync Daemon) ---
echo "[INFO] Deploying Antigravity Edge Node Agent (Dynamic Control Plane)..."
mkdir -p /opt/vpn-node-agent

cat > /opt/vpn-node-agent/agent.js << 'AGENT_EOF'
#!/usr/bin/env node
const http = require('http');
const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');

const PORT = process.env.AGENT_PORT || 51821;
const WG_INTERFACE = process.env.WG_INTERFACE || 'wg0';
const WG_CONF_PATH = process.env.WG_CONF_PATH || `/etc/wireguard/${WG_INTERFACE}.conf`;
const AUTH_TOKEN = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';

function isValidPublicKey(key) {
  return typeof key === 'string' && /^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw480]=$/.test(key.trim());
}

function getJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) reject(new Error('Payload too large'));
    });
    req.on('end', () => {
      try { resolve(body ? JSON.parse(body) : {}); }
      catch (err) { reject(new Error('Invalid JSON format')); }
    });
    req.on('error', reject);
  });
}

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'X-Powered-By': 'Antigravity-VPN-NodeAgent',
  });
  res.end(JSON.stringify(data));
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;

  if (req.method === 'GET' && pathname === '/health') {
    return sendJson(res, 200, {
      status: 'UP',
      node: os.hostname(),
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    });
  }

  const authHeader = req.headers['x-node-token'] || req.headers['authorization'];
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.substring(7) : authHeader;

  if (token !== AUTH_TOKEN) {
    return sendJson(res, 401, { error: 'Unauthorized: Invalid node synchronization token' });
  }

  try {
    if (req.method === 'POST' && pathname === '/peers/add') {
      const { publicKey, allowedIps, presharedKey } = await getJsonBody(req);
      if (!isValidPublicKey(publicKey)) return sendJson(res, 400, { error: 'Invalid WireGuard public key' });
      if (!allowedIps || !Array.isArray(allowedIps) || allowedIps.length === 0) {
        return sendJson(res, 400, { error: 'allowedIps must be a non-empty array of CIDRs' });
      }

      const ipsString = allowedIps.join(',');
      let wgCmd = `wg set ${WG_INTERFACE} peer "${publicKey}" allowed-ips "${ipsString}"`;
      if (presharedKey) {
        wgCmd = `wg set ${WG_INTERFACE} peer "${publicKey}" preshared-key <(echo "${presharedKey}") allowed-ips "${ipsString}"`;
      }

      try {
        execSync(wgCmd, { shell: '/bin/bash', stdio: 'pipe' });
      } catch (err) {
        return sendJson(res, 500, { error: `Failed to set peer in kernel: ${err.message}` });
      }

      try {
        if (fs.existsSync(WG_CONF_PATH)) {
          let conf = fs.readFileSync(WG_CONF_PATH, 'utf8');
          if (!conf.includes(publicKey)) {
            const peerBlock = `\n# Peer registered by NodeAgent: ${new Date().toISOString()}\n[Peer]\nPublicKey = ${publicKey}\nAllowedIPs = ${ipsString}\n`;
            fs.appendFileSync(WG_CONF_PATH, peerBlock);
          }
        }
      } catch (confErr) {
        console.warn('[WARN] Could not append to wg0.conf:', confErr.message);
      }

      return sendJson(res, 200, { success: true, message: 'Peer registered in kernel', peer: { publicKey, allowedIps } });
    }

    if (req.method === 'POST' && pathname === '/peers/remove') {
      const { publicKey } = await getJsonBody(req);
      if (!isValidPublicKey(publicKey)) return sendJson(res, 400, { error: 'Invalid WireGuard public key' });

      try {
        execSync(`wg set ${WG_INTERFACE} peer "${publicKey}" remove`, { stdio: 'pipe' });
      } catch (err) {
        console.error('[ERROR] Failed executing wg set remove:', err.message);
      }

      try {
        if (fs.existsSync(WG_CONF_PATH)) {
          const conf = fs.readFileSync(WG_CONF_PATH, 'utf8');
          const regex = new RegExp(`\n?#?[^\\[]*\\[Peer\\][^\\[]*PublicKey\\s*=\\s*${publicKey.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^\\[]*`, 'gi');
          fs.writeFileSync(WG_CONF_PATH, conf.replace(regex, ''));
        }
      } catch (confErr) {
        console.warn('[WARN] Could not clean wg0.conf:', confErr.message);
      }

      return sendJson(res, 200, { success: true, message: 'Peer removed from WireGuard kernel interface' });
    }

    if (req.method === 'GET' && pathname === '/metrics') {
      let activePeers = 0, totalRx = 0, totalTx = 0;
      try {
        const dump = execSync(`wg show ${WG_INTERFACE} dump`, { encoding: 'utf8' }).trim().split('\n');
        const peerLines = dump.slice(1);
        activePeers = peerLines.length;
        for (const line of peerLines) {
          const parts = line.split('\t');
          if (parts.length >= 7) {
            totalRx += parseInt(parts[5], 10) || 0;
            totalTx += parseInt(parts[6], 10) || 0;
          }
        }
      } catch (dumpErr) { activePeers = 0; }

      const totalMem = os.totalmem();
      const freeMem = os.freemem();
      return sendJson(res, 200, {
        node: os.hostname(),
        status: 'ONLINE',
        activePeers,
        bandwidth: { totalRxBytes: totalRx, totalTxBytes: totalTx },
        system: {
          cpuCount: os.cpus().length,
          loadAverage: os.loadavg(),
          memoryUsagePercent: Math.round(((totalMem - freeMem) / totalMem) * 100),
          totalMemoryMB: Math.round(totalMem / (1024 * 1024)),
          freeMemoryMB: Math.round(freeMem / (1024 * 1024)),
        },
        timestamp: new Date().toISOString(),
      });
    }

    return sendJson(res, 404, { error: 'Route not found' });
  } catch (err) {
    return sendJson(res, 500, { error: 'Internal server error: ' + err.message });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Antigravity VPN Edge Node Agent listening on port ${PORT}`);
});
AGENT_EOF

chmod +x /opt/vpn-node-agent/agent.js

# Setup systemd service
cat > /etc/systemd/system/vpn-node-agent.service << 'SERVICE_EOF'
[Unit]
Description=Antigravity VPN Edge Node Agent & Dynamic WireGuard Synchronizer
After=network.target wg-quick@wg0.service
Wants=wg-quick@wg0.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-node-agent
ExecStart=/usr/bin/node /opt/vpn-node-agent/agent.js
Restart=always
RestartSec=5
Environment=AGENT_PORT=51821
Environment=WG_INTERFACE=wg0
Environment=WG_CONF_PATH=/etc/wireguard/wg0.conf
Environment=NODE_AGENT_TOKEN=vpn-node-agent-secure-token-2026
LimitNOFILE=65536
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable --now vpn-node-agent

# Allow agent port if UFW is active
if command -v ufw >/dev/null 2>&1; then
    ufw allow 51821/tcp comment 'Antigravity VPN Node Agent' > /dev/null 2>&1 || true
fi

echo ""
echo "================================================================="
echo "   WIREGUARD NODE & DYNAMIC AGENT SETUP COMPLETE!                "
echo "   Test file: /root/wireguard-clients/client1.conf               "
echo "   Node Agent Service: systemctl status vpn-node-agent           "
echo "   Node Agent Port: 51821 (REST Control Plane)                   "
echo "   Add more clients later with: vpn-add-client <name>            "
echo "================================================================="
