# ---------------------------------------------------------------------------
# NFS download repo
# ---------------------------------------------------------------------------
resource "docker_volume" "tovpn_repo_nfs" {
  name   = "tovpn_repo_nfs"
  driver = "local"

  driver_opts = {
    type   = "nfs4"
    o      = "addr=${var.media_server},rw"
    device = var.tovpn_repo_mnt
  }
}

# ---------------------------------------------------------------------------
# Transmission – Torrent Client (via OpenVPN)
# ---------------------------------------------------------------------------
resource "docker_image" "transmission" {
  name = "haugene/transmission-openvpn:5.5.2"
}

resource "docker_container" "transmission" {
  name    = "transmission"
  image   = docker_image.transmission.image_id
  restart = "unless-stopped"

  # No Traefik on this host — publish the web UI directly on 9091.
  ports {
    internal = 9091
    external = 9091
  }

  capabilities {
    add = ["NET_ADMIN"]
  }

  # CREATE_TUN_DEVICE=true (image default) creates /dev/net/tun inside the
  # container, so the host device does not need to be mounted.

  # Direct (unproxied) access: RPC auth is still enforced, and the whitelist
  # is kept to loopback (Docker's userland proxy forwards via 127.0.0.1),
  # the LAN, and the Docker bridge range.
  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "OPENVPN_PROVIDER=NORDVPN",
    "OPENVPN_USERNAME=${var.openvpn_username}",
    "OPENVPN_PASSWORD=${var.openvpn_password}",
    "OPENVPN_OPTS=--inactive 3600 --ping 10 --ping-exit 60",
    "LOCAL_NETWORK=${var.local_network}",
    "TRANSMISSION_RPC_AUTHENTICATION_REQUIRED=true",
    "TRANSMISSION_RPC_USERNAME=${var.transmission_rpc_username}",
    "TRANSMISSION_RPC_PASSWORD=${var.transmission_rpc_password}",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/transmission/config"
    container_path = "/config"
  }
  volumes {
    volume_name    = "/mnt/r5-dstor/dl-repo"
    container_path = "/data"
  }
}
