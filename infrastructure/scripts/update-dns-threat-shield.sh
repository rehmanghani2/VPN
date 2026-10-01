#!/usr/bin/env bash
# ==============================================================================
# Commercial VPN Platform - DNS Threat Shield & Ad-Block Provisioner
# Generates Unbound DNS Response Policy Zones (RPZ) for:
# 1. Malware, Ransomware, Phishing & Botnet C2
# 2. Ads, Tracking, Analytics & Fingerprinting Telemetry
# ==============================================================================

set -euo pipefail

UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
SHIELD_CACHE_DIR="/var/cache/vpn-threat-shield"
MALWARE_CONF="$UNBOUND_CONF_DIR/threat-shield-malware.conf"
ALL_SHIELD_CONF="$UNBOUND_CONF_DIR/threat-shield-all.conf"

mkdir -p "$UNBOUND_CONF_DIR" "$SHIELD_CACHE_DIR"

echo "[*] Downloading vetted threat intelligence feeds..."

# 1. Malware & Phishing blocklists
curl -sSL "https://malware-filter.gitlab.io/malware-filter/phishing-filter-domains.txt" \
  -o "$SHIELD_CACHE_DIR/phishing.txt" || true

curl -sSL "https://urlhaus.abuse.ch/downloads/hostfile/" \
  -o "$SHIELD_CACHE_DIR/urlhaus.txt" || true

# 2. Ads & Trackers blocklists (StevenBlack unified)
curl -sSL "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
  -o "$SHIELD_CACHE_DIR/stevenblack.hosts" || true

echo "[*] Compiling Unbound local-zone NXDOMAIN rules..."

# Generate Malware-only config
echo "server:" > "$MALWARE_CONF"
echo "    # DNS Threat Shield - Malware & Phishing Protection" >> "$MALWARE_CONF"

if [ -f "$SHIELD_CACHE_DIR/phishing.txt" ]; then
  grep -v '^#' "$SHIELD_CACHE_DIR/phishing.txt" | grep -v '^$' | sed 's/\r$//' | awk '{print "    local-zone: \"" $1 "\" always_nxdomain"}' | head -n 50000 >> "$MALWARE_CONF"
fi

if [ -f "$SHIELD_CACHE_DIR/urlhaus.txt" ]; then
  grep '^127.0.0.1' "$SHIELD_CACHE_DIR/urlhaus.txt" | awk '{print "    local-zone: \"" $2 "\" always_nxdomain"}' | head -n 50000 >> "$MALWARE_CONF"
fi

# Generate Full Shield (Malware + Ads + Trackers) config
cp "$MALWARE_CONF" "$ALL_SHIELD_CONF"
sed -i 's/Malware & Phishing Protection/Full Threat Shield (Ads + Trackers + Malware)/' "$ALL_SHIELD_CONF"

if [ -f "$SHIELD_CACHE_DIR/stevenblack.hosts" ]; then
  grep '^0.0.0.0' "$SHIELD_CACHE_DIR/stevenblack.hosts" | awk '{print "    local-zone: \"" $2 "\" always_nxdomain"}' | head -n 100000 >> "$ALL_SHIELD_CONF"
fi

echo "[*] Validating Unbound configuration..."
if command -v unbound-checkconf &>/dev/null; then
  unbound-checkconf || echo "[!] Warning: Check configuration syntax"
fi

echo "[*] Reloading Unbound DNS Server..."
if systemctl is-active --quiet unbound; then
  systemctl restart unbound
  echo "[+] Unbound DNS Threat Shield active with $(wc -l < "$ALL_SHIELD_CONF") rules!"
else
  echo "[+] Unbound rules prepared in $UNBOUND_CONF_DIR"
fi
