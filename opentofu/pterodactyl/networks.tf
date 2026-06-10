# ---------------------------------------------------------------------------
# Docker Networks
# ---------------------------------------------------------------------------
resource "docker_network" "tdarr" {
  name   = "tdarr"
  driver = "bridge"
}

resource "docker_network" "proxy" {
  name   = "Traefik"
  driver = "bridge"
}

resource "docker_network" "immich" {
  name   = "Immich Backend Network"
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

# ---------------------------------------------------------------------------
# Docker Volumes
# ---------------------------------------------------------------------------
resource "docker_volume" "tv_nfs" {
  name   = "tv_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = "${var.media_library_mnt}/TV"
  }
}

resource "docker_volume" "movies_nfs" {
  name   = "movies_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = "${var.media_library_mnt}/Movies"
  }
}

resource "docker_volume" "music_nfs" {
  name   = "music_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = "${var.media_library_mnt}/Music"
  }
}

resource "docker_volume" "books_nfs" {
  name   = "books_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = "${var.media_library_mnt}/Books"
  }
}

resource "docker_volume" "anime_nfs" {
  name   = "anime_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = "${var.media_library_mnt}/Anime"
  }
}

resource "docker_volume" "kids_tv_nfs" {
  name   = "kids_tv_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = "${var.media_library_mnt}/KidsTV"
  }
}
