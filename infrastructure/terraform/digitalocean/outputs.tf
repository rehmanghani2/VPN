# ==============================================================================
# DigitalOcean Multi-Region VPN Infrastructure - Outputs
# ==============================================================================

output "edge_node_public_ips" {
  description = "Public IPv4 addresses of provisioned multi-region droplets"
  value = {
    for k, v in digitalocean_droplet.edge_nodes : k => v.ipv4_address
  }
}

output "wireguard_endpoints" {
  description = "Public WireGuard UDP endpoints for clients"
  value = {
    for k, v in digitalocean_droplet.edge_nodes : k => "${v.ipv4_address}:51820"
  }
}

output "node_agent_api_endpoints" {
  description = "Internal Node Agent orchestration URLs"
  value = {
    for k, v in digitalocean_droplet.edge_nodes : k => "http://${v.ipv4_address}:51821"
  }
}

output "ssh_commands" {
  description = "SSH administrative login commands per node"
  value = {
    for k, v in digitalocean_droplet.edge_nodes : k => "ssh root@${v.ipv4_address}"
  }
}
