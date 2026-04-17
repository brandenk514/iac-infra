# ---------------------------------------------------------------------------
# Docker Networks
# ---------------------------------------------------------------------------
resource "docker_network" "tdarr" {
  name   = "tdarr"
  driver = "bridge"
}

# ---------------------------------------------------------------------------
# Docker Volumes
# ---------------------------------------------------------------------------
resource "docker_volume" "media_library_nfs" {
  name   = "media_library_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = var.media_library_mnt
  }
}
