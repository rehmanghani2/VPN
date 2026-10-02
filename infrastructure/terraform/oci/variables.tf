# ==============================================================================
# Oracle Cloud Infrastructure (OCI) Always Free VPN Node - Variables
# ==============================================================================

variable "tenancy_ocid" {
  description = "OCID of your Oracle Cloud Tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user calling the API"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the public key uploaded to Oracle Cloud Console"
  type        = string
}

variable "private_key_path" {
  description = "Path to your local OCI API private key (.pem)"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI Region for the Always Free node (e.g. us-ashburn-1, eu-frankfurt-1, ap-singapore-1)"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "Compartment OCID (Usually same as tenancy_ocid for Root compartment)"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key content to authorize for the 'ubuntu' user"
  type        = string
}

# ------------------------------------------------------------------------------
# Node Compute & Specs (Always Free Ampere A1 ARM defaults)
# ------------------------------------------------------------------------------
variable "node_display_name" {
  description = "Name tag for the edge node"
  type        = string
  default     = "vpn-edge-oracle-free"
}

variable "node_ocpus" {
  description = "Number of OCPUs for the Ampere ARM VM (Always Free gives up to 4 total)"
  type        = number
  default     = 2
}

variable "node_memory_in_gbs" {
  description = "RAM in GB (Always Free gives up to 24 GB total)"
  type        = number
  default     = 12
}

variable "boot_volume_size_gbs" {
  description = "Boot volume size in GB (Always Free allows up to 200 GB total)"
  type        = number
  default     = 50
}

# ------------------------------------------------------------------------------
# VPN Control Plane Integration
# ------------------------------------------------------------------------------
variable "backend_api_url" {
  description = "Public URL of your NestJS backend control plane for auto-registration"
  type        = string
  default     = "http://your-backend-ip:3000/api/v1"
}

variable "node_country_code" {
  description = "Country ISO code of the node location"
  type        = string
  default     = "US"
}

variable "node_country_name" {
  description = "Country name of the node location"
  type        = string
  default     = "United States"
}

variable "node_city" {
  description = "City of the OCI data center"
  type        = string
  default     = "Ashburn"
}
