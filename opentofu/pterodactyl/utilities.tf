
# ---------------------------------------------------------------------------
# LubeLogger – Vehicle Maintenance Tracker
# ---------------------------------------------------------------------------
resource "docker_image" "lubelogger" {
    name = "ghcr.io/hargata/lubelogger:latest"
}

resource "docker_container" "lubelogger" {
    name    = "lubelogger"
    image   = docker_image.lubelogger.image_id
    restart = "unless-stopped"

    networks_advanced {
        name    = docker_network.proxy.id
        aliases = ["lubelogger"]
    }

    volumes {
        host_path      = "${var.docker_mnt}/lubelogger/data"
        container_path = "/App/data"
    }

    volumes {
        host_path      = "${var.docker_mnt}/lubelogger/keys"
        container_path = "/root/.aspnet/DataProtection-Keys"
    }

    env = [
        "TZ=${var.timezone}",
    ]

    dynamic "labels" {
        for_each = {
        "traefik.enable"                                            = "true"
        "traefik.http.routers.lubelogger.rule"                      = "Host(`lubelogger.local.uaccloud.com`)"
        "traefik.http.services.lubelogger.loadbalancer.server.port" = "8080"
        "traefik.http.routers.lubelogger.tls"                       = "true"
        "traefik.http.routers.lubelogger.tls.certresolver"          = "cloudflare"
        "traefik.http.routers.lubelogger.entrypoints"               = "websecure"
        }
        content {
        label = labels.key
        value = labels.value
        }
    }
}

# ---------------------------------------------------------------------------
# Archive Team Warrior
# ---------------------------------------------------------------------------
resource "docker_image" "archiveteam_warrior" {
    name = "atdr.meo.ws/archiveteam/warrior-dockerfile:latest@sha256:d8016cd962ec67736646b6dfe963a4cab215991b1c95b67c85a395502abd7610"
}

resource "docker_container" "archiveteam_warrior" {
    name    = "archiveteam-warrior"
    image   = docker_image.archiveteam_warrior.image_id
    restart = "unless-stopped"

    networks_advanced {
        name    = docker_network.proxy.id
        aliases = ["archiveteam-warrior"]
    }

    log_driver = "json-file"
    log_opts = {
        "max-size" = "50m"
    }

    env = [
        "DOWNLOADER=bking2142",
        "SELECTED_PROJECT=auto",
        "CONCURRENT_ITEMS=6",
        "SHARED_RSYNC_THREADS=6",
        "WARRIOR_ID=-bking2142",
    ]

    dynamic "labels" {
        for_each = {
        "traefik.enable"                                                     = "true"
        "traefik.http.routers.archiveteam-warrior.rule"                      = "Host(`archive.local.uaccloud.com`)"
        "traefik.http.services.archiveteam-warrior.loadbalancer.server.port" = "8001"
        "traefik.http.routers.archiveteam-warrior.tls"                       = "true"
        "traefik.http.routers.archiveteam-warrior.tls.certresolver"          = "cloudflare"
        "traefik.http.routers.archiveteam-warrior.entrypoints"               = "websecure"
        }
        content {
        label = labels.key
        value = labels.value
        }
    }
}