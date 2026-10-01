terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45.0"
    }
  }
}

# Firewall definition ensuring zero-leak edge protection
resource "hcloud_firewall" "vpn_firewall" {
  name = "vpn-cluster-firewall"

  # Standard WireGuard UDP listen port
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "51820"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "WireGuard UDP Data Plane"
  }

  # Stealth / Anti-DPI Obfuscation HTTPS Camouflage port
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Anti-DPI HTTPS Stealth Ingress"
  }

  # Edge Node Agent Management API (Backend Control Plane)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "51821"
    source_ips = [
      "0.0.0.0/0", # In production, restrict to backend IP range
      "::/0"
    ]
    description = "Node Agent Orchestration Webhook"
  }

  # SSH for Break-Glass Administrator Access
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0"
    ]
    description = "Admin SSH"
  }
}

# Provision multi-region WireGuard edge nodes with automated zero-touch bootstrap
resource "hcloud_server" "edge_nodes" {
  for_each    = var.regions
  name        = "vpn-edge-${each.key}"
  image       = "ubuntu-22.04"
  server_type = each.value.server_type
  location    = each.value.location
  firewall_ids = [hcloud_firewall.vpn_firewall.id]

  user_data = templatefile("${path.module}/../scripts/node-bootstrap-cloudinit.yaml", {
    BACKEND_CONTROL_URL = var.backend_api_url,
    NODE_COUNTRY_CODE   = each.value.country_code,
    NODE_COUNTRY_NAME   = each.value.country_name,
    NODE_CITY           = each.value.city
  })

  labels = {
    role       = "vpn-edge-node"
    region     = each.key
    obfuscated = tostring(each.value.obfuscated)
    managed_by = "terraform"
  }
}
