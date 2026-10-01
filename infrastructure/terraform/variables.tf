variable "backend_api_url" {
  description = "The centralized NestJS control plane URL for edge nodes to register against"
  type        = string
  default     = "https://api.commercialvpn.com/api/v1"
}

variable "node_auth_token" {
  description = "Mutual authentication secret token for Edge Node Agent <-> Backend API communication"
  type        = string
  default     = "vpn-node-agent-secure-token-2026"
  sensitive   = true
}

variable "regions" {
  description = "Configuration map for multi-region VPN cluster edge nodes"
  type = map(object({
    country_code = string
    country_name = string
    city         = string
    server_type  = string
    location     = string
    obfuscated   = bool
  }))
  default = {
    "eu-central-fra" = {
      country_code = "DE"
      country_name = "Germany"
      city         = "Frankfurt"
      server_type  = "cx22"
      location     = "fsn1"
      obfuscated   = true
    },
    "us-east-nyc" = {
      country_code = "US"
      country_name = "United States"
      city         = "New York"
      server_type  = "cx22"
      location     = "ash"
      obfuscated   = false
    },
    "ap-southeast-sin" = {
      country_code = "SG"
      country_name = "Singapore"
      city         = "Singapore"
      server_type  = "cx22"
      location     = "sin"
      obfuscated   = false
    },
    "eu-west-lon" = {
      country_code = "GB"
      country_name = "United Kingdom"
      city         = "London"
      server_type  = "cx22"
      location     = "hel1"
      obfuscated   = true
    }
  }
}
