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
# General
# ---------------------------------------------------------------------------
variable "timezone" {
  description = "Timezone for containers"
  type        = string
  default     = "America/Los_Angeles"
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
# NFS / Media
# ---------------------------------------------------------------------------
variable "media_server" {
  description = "IP address of the NFS media server"
  type        = string
  default     = "192.168.105.20"
}

variable "media_library_mnt" {
  description = "NFS export path for the media library"
  type        = string
  default     = ":/mnt/backup_pool/media-backup-pool"
}
