terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.40.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ------------------------------------------------------------------------------
# 1. NETWORK TOPOLOGY (VCN, Subnet, Internet Gateway, Security List)
# ------------------------------------------------------------------------------

# Virtual Cloud Network
resource "oci_core_vcn" "vpn_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "vpn-edge-vcn"
  dns_label      = "vpnedge"
}

# Internet Gateway for Public Internet Ingress/Egress
resource "oci_core_internet_gateway" "vpn_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vpn_vcn.id
  display_name   = "vpn-internet-gateway"
  enabled        = true
}

# Route Table directing 0.0.0.0/0 traffic to Internet Gateway
resource "oci_core_route_table" "vpn_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vpn_vcn.id
  display_name   = "vpn-public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.vpn_igw.id
  }
}

# Security List (Kernel-grade port filtering for VPN endpoints)
resource "oci_core_security_list" "vpn_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vpn_vcn.id
  display_name   = "vpn-edge-security-list"

  # Outbound: Allow all egress traffic
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound internet traffic"
  }

  # Inbound: WireGuard UDP Data Plane (Default: 51820)
  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "0.0.0.0/0"
    description = "WireGuard UDP Data Plane"
    udp_options {
      min = 51820
      max = 51820
    }
  }

  # Inbound: Stealth / Anti-DPI HTTPS Camouflage (TCP 443)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Anti-DPI HTTPS Stealth Ingress"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Inbound: Edge Node Agent Orchestration Daemon (TCP 51821)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Node Agent Orchestration Webhook"
    tcp_options {
      min = 51821
      max = 51821
    }
  }

  # Inbound: SSH for Break-Glass Admin Access (TCP 22)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Admin SSH"
    tcp_options {
      min = 22
      max = 22
    }
  }
}

# Regional Public Subnet
resource "oci_core_subnet" "vpn_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vpn_vcn.id
  display_name      = "vpn-public-subnet"
  dns_label         = "vpnsub"
  route_table_id    = oci_core_route_table.vpn_route_table.id
  security_list_ids = [oci_core_security_list.vpn_security_list.id]
}

# ------------------------------------------------------------------------------
# 2. IMAGE & AVAILABILITY DOMAIN DISCOVERY
# ------------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Fetch latest Canonical Ubuntu 22.04 LTS image for ARM64 (aarch64)
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ------------------------------------------------------------------------------
# 3. ALWAYS FREE COMPUTE INSTANCE (Ampere A1 ARM Flex)
# ------------------------------------------------------------------------------

resource "oci_core_instance" "vpn_node" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.node_display_name
  shape               = "VM.Standard.A1.Flex" # Always Free Eligible

  shape_config {
    ocpus         = var.node_ocpus          # 1 to 4 OCPUs (Always Free limit: 4 total)
    memory_in_gbs = var.node_memory_in_gbs  # 6 to 24 GB RAM (Always Free limit: 24 total)
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.vpn_subnet.id
    display_name     = "vpn-vnic"
    assign_public_ip = true
    hostname_label   = "vpnedgenode"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gbs # Always Free allows up to 200 GB
  }

  # Automated Zero-Touch Cloud-Init WireGuard & Node Agent bootstrap
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/../../scripts/node-bootstrap-cloudinit.yaml", {
      BACKEND_CONTROL_URL = var.backend_api_url,
      NODE_COUNTRY_CODE   = var.node_country_code,
      NODE_COUNTRY_NAME   = var.node_country_name,
      NODE_CITY           = var.node_city
    }))
  }

  freeform_tags = {
    "Project"    = "Antigravity-VPN"
    "Role"       = "wireguard-edge-node"
    "Tier"       = "always-free"
    "ManagedBy"  = "terraform"
  }
}
