# ---------------------------------------------------------------------------
# Cloudflared – Cloudflare Tunnel
# ---------------------------------------------------------------------------
resource "docker_image" "cloudflared" {
  name = "cloudflare/cloudflared:2026.5.0"
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
