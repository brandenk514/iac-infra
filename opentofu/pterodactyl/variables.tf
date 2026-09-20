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
  default     = "/mnt/r5-dstor/containers"
}

# ---------------------------------------------------------------------------
# NFS / Downloads
# ---------------------------------------------------------------------------
variable "media_server" {
  description = "IP address of the NFS media server"
  type        = string
  default     = "192.168.105.4"
}

variable "local_network" {
  description = "LAN CIDR that should bypass the VPN (transmission LOCAL_NETWORK)"
  type        = string
  default     = "192.168.105.0/24, 192.168.100.0/24"
}

variable "tovpn_repo_mnt" {
  description = "Path to the transmission/VPN download directory"
  type        = string
  default     = ":/volume1/tovpn-repo"
}

# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
variable "timezone" {
  description = "Timezone for containers"
  type        = string
  default     = "America/Denver"
}

variable "puid" {
  description = "User ID for containers"
  type        = string
  default     = "1000"
}

variable "pgid" {
  description = "Group ID for containers"
  type        = string
  default     = "1000"
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

# ---------------------------------------------------------------------------
# Transmission / OpenVPN
# ---------------------------------------------------------------------------
variable "openvpn_username" {
  description = "NordVPN service credential username"
  type        = string
  sensitive   = true
}

variable "openvpn_password" {
  description = "NordVPN service credential password"
  type        = string
  sensitive   = true
}