# ==============================================================================
# Oracle Cloud Infrastructure Always Free VPN Node - Outputs
# ==============================================================================

output "vpn_public_ip" {
  description = "Public Static IPv4 Address of the Always Free VPN Edge Node"
  value       = oci_core_instance.vpn_node.public_ip
}

output "vpn_instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.vpn_node.id
}

output "ssh_command" {
  description = "Direct SSH login command"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${oci_core_instance.vpn_node.public_ip}"
}

output "wireguard_endpoint" {
  description = "WireGuard client connection endpoint"
  value       = "${oci_core_instance.vpn_node.public_ip}:51820"
}

output "node_agent_url" {
  description = "Internal Node Agent API endpoint"
  value       = "http://${oci_core_instance.vpn_node.public_ip}:51821"
}
