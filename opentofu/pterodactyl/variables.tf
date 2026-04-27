# ---------------------------------------------------------------------------
# SSH Connection
# ---------------------------------------------------------------------------
variable "ssh_user" {
  description = "SSH user for the remote Docker host"
  type        = string
}

variable "ssh_host" {
  description = "Hostname or IP of the remote Docker host"
  type        = string
}

variable "ssh_port" {
  description = "SSH port on the remote host"
  type        = number
  default     = 22
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
variable "docker_mnt" {
  description = "Base path for container persistent storage"
  type        = string
  default     = "/opt"
}

# ---------------------------------------------------------------------------
# Cloudflared Tunnel
# ---------------------------------------------------------------------------
variable "cloudflared_token" {
  description = "Cloudflare tunnel token"
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Beszel Agent
# ---------------------------------------------------------------------------
variable "beszel_agent_hub_url" {
  description = "Beszel hub URL for the agent"
  type        = string
  default     = "https://monitor.local.uaccloud.com"
}

variable "beszel_agent_key" {
  description = "SSH public key for Beszel agent auth"
  type        = string
  sensitive   = true
}

variable "beszel_agent_token" {
  description = "Auth token for Beszel agent"
  type        = string
  sensitive   = true
}
