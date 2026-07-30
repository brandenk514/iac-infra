# ---------------------------------------------------------------------------
# Prowlarr – Indexer Manager
# ---------------------------------------------------------------------------
resource "docker_image" "prowlarr" {
  name = "linuxserver/prowlarr:2.5.2"
}

resource "docker_container" "prowlarr" {
  name    = "prowlarr"
  image   = docker_image.prowlarr.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["prowlarr"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/prowlarr/config"
    container_path = "/config"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                          = "true"
      "traefik.http.routers.prowlarr.rule"                      = "Host(`prowlarr.local.uaccloud.com`)"
      "traefik.http.routers.prowlarr.entrypoints"               = "websecure"
      "traefik.http.services.prowlarr.loadbalancer.server.port" = "9696"
      "traefik.http.routers.prowlarr.tls"                       = "true"
      "traefik.http.routers.prowlarr.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Sonarr – TV Series
# ---------------------------------------------------------------------------
resource "docker_image" "sonarr" {
  name = "linuxserver/sonarr:4.0.19"
}

resource "docker_container" "sonarr" {
  name    = "sonarr"
  image   = docker_image.sonarr.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["sonarr"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/sonarr/config"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.tv_nfs.name
    container_path = "/tv"
  }
  volumes {
    volume_name    = docker_volume.anime_nfs.name
    container_path = "/anime"
  }
  volumes {
    volume_name    = docker_volume.kids_tv_nfs.name
    container_path = "/kids-tv"
  }
  volumes {
    volume_name    = docker_volume.tovpn_repo_nfs.name
    container_path = "/downloads"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                        = "true"
      "traefik.http.routers.sonarr.rule"                      = "Host(`sonarr.local.uaccloud.com`)"
      "traefik.http.routers.sonarr.entrypoints"               = "websecure"
      "traefik.http.services.sonarr.loadbalancer.server.port" = "8989"
      "traefik.http.routers.sonarr.tls"                       = "true"
      "traefik.http.routers.sonarr.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Radarr – Movies
# ---------------------------------------------------------------------------
resource "docker_image" "radarr" {
  name = "linuxserver/radarr:6.3.0"
}

resource "docker_container" "radarr" {
  name    = "radarr"
  image   = docker_image.radarr.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["radarr"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/radarr/config"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.movies_nfs.name
    container_path = "/movies"
  }
  volumes {
    volume_name    = docker_volume.tovpn_repo_nfs.name
    container_path = "/downloads"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                        = "true"
      "traefik.http.routers.radarr.rule"                      = "Host(`radarr.local.uaccloud.com`)"
      "traefik.http.routers.radarr.entrypoints"               = "websecure"
      "traefik.http.services.radarr.loadbalancer.server.port" = "7878"
      "traefik.http.routers.radarr.tls"                       = "true"
      "traefik.http.routers.radarr.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Lidarr – Music
# ---------------------------------------------------------------------------
resource "docker_image" "lidarr" {
  name = "linuxserver/lidarr:3.1.0"
}

resource "docker_container" "lidarr" {
  name    = "lidarr"
  image   = docker_image.lidarr.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["lidarr"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/lidarr/config"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.music_nfs.name
    container_path = "/music"
  }
  volumes {
    volume_name    = docker_volume.tovpn_repo_nfs.name
    container_path = "/downloads"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                        = "true"
      "traefik.http.routers.lidarr.rule"                      = "Host(`lidarr.local.uaccloud.com`)"
      "traefik.http.routers.lidarr.entrypoints"               = "websecure"
      "traefik.http.services.lidarr.loadbalancer.server.port" = "8686"
      "traefik.http.routers.lidarr.tls"                       = "true"
      "traefik.http.routers.lidarr.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Transmission over VPN (tovpn)
# ---------------------------------------------------------------------------
resource "docker_image" "tovpn" {
  name = "haugene/transmission-openvpn:5.4.2"
}

resource "docker_container" "tovpn" {
  name       = "tovpn"
  image      = docker_image.tovpn.image_id
  restart    = "unless-stopped"
  privileged = true

  capabilities {
    add = ["NET_ADMIN"]
  }

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["tovpn"]
  }

  volumes {
    volume_name    = docker_volume.tovpn_repo_nfs.name
    container_path = "/data"
  }
  volumes {
    host_path      = "${var.docker_mnt}/transmission/config"
    container_path = "/config"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "UMASK=002",
    "OPENVPN_PROVIDER=NORDVPN",
    "OPENVPN_CONFIG=",
    "OPENVPN_USERNAME=${var.openvpn_username}",
    "OPENVPN_PASSWORD=${var.openvpn_password}",
    "LOCAL_NETWORK=192.168.100.0/24, 192.168.105.0/24",
    "TRANSMISSION_WEB_HOME=/opt/transmission-ui/flood-for-transmission",
  ]

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                       = "true"
      "traefik.http.routers.tovpn.rule"                      = "Host(`tovpn.local.uaccloud.com`)"
      "traefik.http.routers.tovpn.entrypoints"               = "websecure"
      "traefik.http.services.tovpn.loadbalancer.server.port" = "9091"
      "traefik.http.routers.tovpn.tls"                       = "true"
      "traefik.http.routers.tovpn.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Jellyfin – Media Server
# ---------------------------------------------------------------------------
resource "docker_image" "jellyfin" {
  name = "lscr.io/linuxserver/jellyfin:10.11.11"
}

resource "docker_container" "jellyfin" {
  name    = "jellyfin"
  image   = docker_image.jellyfin.image_id
  restart = "unless-stopped"

  devices {
    host_path      = "/dev/dri/renderD129"
    container_path = "/dev/dri/renderD129"
  }

  devices {
    host_path      = "/dev/dri/card1"
    container_path = "/dev/dri/card1"
  }

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["jellyfin"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "JELLYFIN_PublishedServerUrl=https://watch.uaccloud.com",
    "LIBVA_DRIVER_NAME=iHD",
    "DOCKER_MODS=linuxserver/mods:jellyfin-opencl",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/jellyfin/config"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.tv_nfs.name
    container_path = "/data/tvshows"
  }
  volumes {
    volume_name    = docker_volume.movies_nfs.name
    container_path = "/data/movies"
  }
  volumes {
    volume_name    = docker_volume.music_nfs.name
    container_path = "/data/music"
  }
  volumes {
    volume_name    = docker_volume.anime_nfs.name
    container_path = "/data/anime"
  }
  volumes {
    volume_name    = docker_volume.kids_tv_nfs.name
    container_path = "/data/kids-tv"
  }
  volumes {
    volume_name    = docker_volume.books_nfs.name
    container_path = "/data/books"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                          = "true"
      "traefik.http.routers.jellyfin.rule"                      = "Host(`flix.uaccloud.com`)"
      "traefik.http.services.jellyfin.loadbalancer.server.port" = "8096"
      "traefik.http.routers.jellyfin.tls"                       = "true"
      "traefik.http.routers.jellyfin.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.jellyfin.entrypoints"               = "external-websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Seerr – Media Requests (successor to Jellyseerr)
# ---------------------------------------------------------------------------
resource "docker_image" "seerr" {
  name = "ghcr.io/seerr-team/seerr:v3.4.1"
}

resource "docker_container" "seerr" {
  name    = "seerr"
  image   = docker_image.seerr.image_id
  restart = "unless-stopped"
  init    = true

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["seerr"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/seerr"
    container_path = "/app/config"
  }

  env = [
    "LOG_LEVEL=debug",
    "TZ=${var.timezone}",
    "PORT=5055",
  ]

  healthcheck {
    test         = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5055/api/v1/settings/public || exit 1"]
    start_period = "20s"
    timeout      = "3s"
    interval     = "15s"
    retries      = 3
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                       = "true"
      "traefik.docker.network"                               = "proxy"
      "traefik.http.routers.seerr.rule"                      = "Host(`request.uaccloud.com`)"
      "traefik.http.services.seerr.loadbalancer.server.port" = "5055"
      "traefik.http.routers.seerr.tls"                       = "true"
      "traefik.http.routers.seerr.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.seerr.entrypoints"               = "external-websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# FlareSolverr – Captcha Bypass Proxy
# ---------------------------------------------------------------------------
resource "docker_image" "flaresolverr" {
  name = "ghcr.io/flaresolverr/flaresolverr:v3.5.0"
}

resource "docker_container" "flaresolverr" {
  name     = "flaresolverr"
  image    = docker_image.flaresolverr.image_id
  restart  = "unless-stopped"
  hostname = "flaresolverr"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["flaresolverr"]
  }

  env = [
    "LOG_LEVEL=info",
    "LOG_HTML=false",
    "CAPTCHA_SOLVER=none",
    "TZ=${var.timezone}",
    "TEST_URL=https://www.google.com",
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                              = "true"
      "traefik.http.routers.flaresolverr.rule"                      = "Host(`solverr.local.uaccloud.com`)"
      "traefik.http.services.flaresolverr.loadbalancer.server.port" = "8191"
      "traefik.http.routers.flaresolverr.tls"                       = "true"
      "traefik.http.routers.flaresolverr.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.flaresolverr.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# LazyLibrarian – Books
# ---------------------------------------------------------------------------
resource "docker_image" "lazylibrarian" {
  name = "lscr.io/linuxserver/lazylibrarian:5f28f033-ls281"
}

resource "docker_container" "lazylibrarian" {
  name    = "lazylibrarian"
  image   = docker_image.lazylibrarian.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["lazylibrarian"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/lazylibrarian/config"
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.tovpn_repo_nfs.name
    container_path = "/downloads"
  }
  volumes {
    volume_name    = docker_volume.books_nfs.name
    container_path = "/books"
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "DOCKER_MODS=linuxserver/mods:universal-calibre|linuxserver/mods:lazylibrarian-ffmpeg",
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                               = "true"
      "traefik.http.routers.lazylibrarian.rule"                      = "Host(`books.local.uaccloud.com`)"
      "traefik.http.services.lazylibrarian.loadbalancer.server.port" = "5299"
      "traefik.http.routers.lazylibrarian.tls"                       = "true"
      "traefik.http.routers.lazylibrarian.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.lazylibrarian.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Houndarr – Media Tracker
# ---------------------------------------------------------------------------
resource "docker_image" "houndarr" {
  name = "ghcr.io/av1155/houndarr:latest"
}

resource "docker_container" "houndarr" {
  name    = "houndarr"
  image   = docker_image.houndarr.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["houndarr"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/houndarr/data"
    container_path = "/data"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                          = "true"
      "traefik.http.routers.houndarr.rule"                      = "Host(`houndarr.local.uaccloud.com`)"
      "traefik.http.routers.houndarr.entrypoints"               = "websecure"
      "traefik.http.services.houndarr.loadbalancer.server.port" = "8877"
      "traefik.http.routers.houndarr.tls"                       = "true"
      "traefik.http.routers.houndarr.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Maintainerr – Media Library Cleanup
# ---------------------------------------------------------------------------
resource "docker_image" "maintainerr" {
name = "ghcr.io/maintainerr/maintainerr:latest"
}

resource "docker_container" "maintainerr" {
name    = "maintainerr"
image   = docker_image.maintainerr.image_id
restart = "unless-stopped"
user    = "1000:1000"

networks_advanced {
name    = docker_network.proxy.id
aliases = ["maintainerr"]
  }

env = [
"TZ=${var.timezone}",
  ]

volumes {
host_path      = "${var.docker_mnt}/maintainerr/data"
container_path = "/opt/data"
  }

healthcheck {
test         = ["CMD", "/opt/app/healthcheck.sh"]
interval     = "30s"
timeout      = "5s"
start_period = "40s"
retries      = 3
  }

dynamic "labels" {
for_each = {
"traefik.enable"                                              = "true"
"traefik.http.routers.maintainerr.rule"                       = "Host(`maintainerr.local.uaccloud.com`)"
"traefik.http.routers.maintainerr.entrypoints"                = "websecure"
"traefik.http.services.maintainerr.loadbalancer.server.port"  = "6246"
"traefik.http.routers.maintainerr.tls"                        = "true"
"traefik.http.routers.maintainerr.tls.certresolver"           = "cloudflare"
    }
content {
label = labels.key
value = labels.value
    }
  }
}
