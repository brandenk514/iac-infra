# ---------------------------------------------------------------------------
# Cloudflared – Cloudflare Tunnel
# ---------------------------------------------------------------------------
resource "docker_image" "cloudflared" {
  name = "cloudflare/cloudflared:latest"
}

resource "docker_container" "cloudflared" {
  name     = "cloudflared"
  image    = docker_image.cloudflared.image_id
  restart  = "unless-stopped"
  hostname = "cloudflared"

  command = [
    "tunnel",
    "--no-autoupdate",
    "run",
    "--token",
    var.cloudflared_token,
  ]
}
