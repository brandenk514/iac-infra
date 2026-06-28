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

variable "tdarr_transcode_cache" {
  description = "Host path for the dedicated Tdarr transcode cache"
  type        = string
  default     = "/mnt/r5-dstor/transcode-cache"
}

# ---------------------------------------------------------------------------
# NFS / Media
# ---------------------------------------------------------------------------
variable "media_server" {
  description = "IP address of the NFS media server"
  type        = string
  default     = "192.168.105.4"
}

variable "media_library_mnt" {
  description = "NFS export path for the media library"
  type        = string
  default     = ":/volume1/media-library"
}

variable "tovpn_repo_mnt" {
  description = "Path to the transmission/VPN download directory"
  type        = string
  default     = ":/volume1/tovpn-repo"
}

# ---------------------------------------------------------------------------
# Cloudflared Tunnel
# ---------------------------------------------------------------------------
variable "cloudflared_token" {
  description = "Cloudflare tunnel token"
  type        = string
  sensitive   = true
}

variable "twogt_cloudflared_token" {
  description = "Cloudflare tunnel token"
  type        = string
  sensitive   = true
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
# Traefik
# ---------------------------------------------------------------------------
variable "traefik_dashboard_credentials" {
  description = "Htpasswd credentials for the Traefik dashboard"
  type        = string
  sensitive   = true
}

variable "cf_dns_api_token" {
  description = "Cloudflare DNS API token for ACME certificate resolution"
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

# ---------------------------------------------------------------------------
# Immich
# ---------------------------------------------------------------------------
variable "immich_version" {
  description = "Immich image tag"
  type        = string
}

variable "db_password" {
  description = "Postgres password for Immich"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Postgres user for Immich"
  type        = string
  default     = "uac-pg"
}

variable "db_database_name" {
  description = "Postgres database name for Immich"
  type        = string
  default     = "uac-photos"
}

variable "db_data_location" {
  description = "Host path for the Immich Postgres data directory"
  type        = string
  default     = "/mnt/r5-dstor/containers/immich-repo/postgres"
}

variable "upload_location" {
  description = "Host path for Immich media uploads"
  type        = string
  default     = "/mnt/r5-dstor/containers/immich-repo/upload"
}
