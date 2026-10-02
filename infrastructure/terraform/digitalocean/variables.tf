# ==============================================================================
# DigitalOcean Multi-Region VPN Infrastructure - Variables
# ==============================================================================

variable "do_token" {
  description = "DigitalOcean Personal Access Token (from API -> Tokens -> Generate New Token)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Public SSH key content (e.g., contents of ~/.ssh/id_rsa.pub) to authorize on all nodes"
  type        = string
}

variable "backend_api_url" {
  description = "Central NestJS Control Plane API URL for edge nodes to register against"
  type        = string
  default     = "http://YOUR_CENTRAL_IP:3000/api/v1"
}

# ------------------------------------------------------------------------------
# Multi-Region Deployment Matrix (4 Continents)
# ------------------------------------------------------------------------------
variable "regions" {
  description = "Configuration map for multi-region VPN cluster nodes"
  type = map(object({
    region_slug  = string
    country_code = string
    country_name = string
    city         = string
    droplet_size = string
    obfuscated   = bool
  }))
  default = {
    "us-nyc" = {
      region_slug  = "nyc3"
      country_code = "US"
      country_name = "United States"
      city         = "New York"
      droplet_size = "s-1vcpu-1gb"
      obfuscated   = false
    },
    "eu-fra" = {
      region_slug  = "fra1"
      country_code = "DE"
      country_name = "Germany"
      city         = "Frankfurt"
      droplet_size = "s-1vcpu-1gb"
      obfuscated   = true
    },
    "ap-sgp" = {
      region_slug  = "sgp1"
      country_code = "SG"
      country_name = "Singapore"
      city         = "Singapore"
      droplet_size = "s-1vcpu-1gb"
      obfuscated   = false
    },
    "eu-lon" = {
      region_slug  = "lon1"
      country_code = "GB"
      country_name = "United Kingdom"
      city         = "London"
      droplet_size = "s-1vcpu-1gb"
      obfuscated   = true
    }
  }
}
