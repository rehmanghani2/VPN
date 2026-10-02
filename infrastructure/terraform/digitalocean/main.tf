terraform {
  required_version = ">= 1.5.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.38.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# ------------------------------------------------------------------------------
# 1. SSH KEY REGISTRATION
# ------------------------------------------------------------------------------
resource "digitalocean_ssh_key" "admin_key" {
  name       = "vpn-admin-key"
  public_key = var.ssh_public_key
}

# ------------------------------------------------------------------------------
# 2. DIGITALOCEAN CLOUD FIREWALL (Strict Zero-Leak Packet Rules)
# ------------------------------------------------------------------------------
resource "digitalocean_firewall" "vpn_firewall" {
  name        = "vpn-cluster-firewall"
  droplet_ids = [for d in digitalocean_droplet.edge_nodes : d.id]

  # Inbound: WireGuard UDP Data Plane (Default: 51820)
  inbound_rule {
    protocol         = "udp"
    port_range       = "51820"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Inbound: Stealth / Anti-DPI HTTPS Camouflage (TCP 443)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Inbound: Edge Node Agent Orchestration Daemon (TCP 51821)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "51821"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Inbound: SSH for Break-Glass Admin Access (TCP 22)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Outbound: Allow all egress traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ------------------------------------------------------------------------------
# 3. MULTI-REGION EDGE DROPLETS (NYC, Frankfurt, Singapore, London, etc.)
# ------------------------------------------------------------------------------
resource "digitalocean_droplet" "edge_nodes" {
  for_each   = var.regions
  name       = "vpn-edge-${each.key}"
  region     = each.value.region_slug
  image      = "ubuntu-22-04-x64"
  size       = each.value.droplet_size
  monitoring = true
  ipv6       = true
  ssh_keys   = [digitalocean_ssh_key.admin_key.fingerprint]

  # Automated Zero-Touch Cloud-Init WireGuard & Node Agent bootstrap
  user_data = templatefile("${path.module}/../../scripts/node-bootstrap-cloudinit.yaml", {
    BACKEND_CONTROL_URL = var.backend_api_url,
    NODE_COUNTRY_CODE   = each.value.country_code,
    NODE_COUNTRY_NAME   = each.value.country_name,
    NODE_CITY           = each.value.city
  })

  tags = [
    "antigravity-vpn",
    "wireguard-edge-node",
    "region-${each.key}"
  ]
}
