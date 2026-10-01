output "edge_node_ips" {
  description = "Public IPv4 addresses for provisioned edge nodes across all regions"
  value = {
    for k, v in hcloud_server.edge_nodes : k => v.ipv4_address
  }
}

output "edge_node_status" {
  description = "Deployment status of provisioned multi-region cluster"
  value = {
    for k, v in hcloud_server.edge_nodes : k => {
      id       = v.id
      ip       = v.ipv4_address
      status   = v.status
      location = v.location
    }
  }
}
