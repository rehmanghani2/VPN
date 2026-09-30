# Phase 1: Data Plane Engineering & Verification Guide

This guide covers setting up your first WireGuard edge node, generating a test client profile, and performing end-to-end verification tests before writing application code.

---

## 1. Deploying the First Edge Node

### Prerequisites
- A remote Linux VPS (Ubuntu 22.04 / 24.04 LTS or Debian 11/12).
  - Recommended providers for testing: Hetzner Cloud (low cost, high performance), Oracle Cloud Free Tier, DigitalOcean, Vultr, or AWS Lightsail.
- Public IPv4 address.
- Root SSH access.
- Inbound UDP port `51820` opened on your cloud provider's firewall / security group.

### Execution
1. SSH into your VPS:
   ```bash
   ssh root@<YOUR_VPS_IP>
   ```

2. Download and run the setup script:
   ```bash
   curl -sSL -O https://raw.githubusercontent.com/<YOUR_REPO>/infrastructure/scripts/setup-wireguard-node.sh
   # Or copy the contents of e:\Projects\VPN\infrastructure\scripts\setup-wireguard-node.sh to the server
   chmod +x setup-wireguard-node.sh
   sudo ./setup-wireguard-node.sh
   ```

3. What the script does automatically:
   - Enables IPv4/IPv6 packet forwarding and sets Linux BBR congestion control.
   - Installs WireGuard and Unbound.
   - Sets up Unbound as a strictly non-logging local recursive DNS resolver bound to `10.8.0.1`.
   - Generates server cryptographic keys and configures `wg0`.
   - Creates `/root/wireguard-clients/client1.conf`.
   - Displays an ASCII QR code in your terminal.

---

## 2. Testing with Official WireGuard Client

Do not build Flutter yet. Test using official WireGuard clients:

### On Mobile (Android / iOS):
1. Install the official **WireGuard** app from Google Play Store or Apple App Store.
2. Tap the `+` button -> **Scan from QR code**.
3. Scan the QR code displayed in the VPS terminal.
4. Name the tunnel `VPN-Test-Node1` and toggle it ON.

### On Desktop (Windows):
1. Download [WireGuard for Windows](https://www.wireguard.com/install/).
2. Copy `/root/wireguard-clients/client1.conf` from your VPS to your Windows PC.
3. Open WireGuard -> **Add Tunnel** -> Select `client1.conf`.
4. Click **Activate**.

---

## 3. Strict Verification Checklist

Verify the following before marking Phase 1 complete:

| Test | Procedure | Success Criteria |
|---|---|---|
| **1. Handshake & Transfer** | Open WireGuard app and look at tunnel statistics. | **Latest handshake:** Received within last 2 minutes.<br>**Transfer:** Both `rx` (received) and `tx` (sent) bytes are incrementing. |
| **2. Public IP Masking** | Visit `https://ifconfig.me` or `https://whatismyipaddress.com` in your browser. | The displayed IP matches your VPS public IP, NOT your real ISP IP. |
| **3. Zero DNS Leaks** | Visit `https://www.dnsleaktest.com` and run the **Extended Test**. | Only 1 DNS server appears, and it is located in your VPS datacenter/country. **NO ISP servers or home location IPs appear.** |
| **4. IPv6 Leak Protection** | Visit `https://test-ipv6.com`. | No local ISP IPv6 address leaks. It will either route through VPS IPv6 or show IPv6 disabled/protected. |
| **5. Clean Disconnect** | Deactivate the WireGuard tunnel. | Internet instantly switches back to local ISP connection without hanging or broken routing tables. |

---

## 4. Adding Additional Test Devices

To generate more test configurations for other devices (e.g., test simultaneously on phone + laptop):
```bash
vpn-add-client laptop-windows
vpn-add-client phone-android
```
The script automatically assigns the next IP (e.g., `10.8.0.3`, `10.8.0.4`) without interrupting existing connections.
