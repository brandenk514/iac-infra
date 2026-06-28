# ---------------------------------------------------------------------------
# Cloudflared – Cloudflare Tunnel
# ---------------------------------------------------------------------------
resource "docker_image" "cloudflared" {
  name = "cloudflare/cloudflared:2026.6.1"
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

# ---------------------------------------------------------------------------
# 2GT Cloudflared – Cloudflare Tunnel
# ---------------------------------------------------------------------------
resource "docker_image" "cloudflared" {
  name = "cloudflare/cloudflared:2026.6.1"
}

resource "docker_container" "cloudflared" {
  name     = "2gt_cloudflared"
  image    = docker_image.cloudflared.image_id
  restart  = "unless-stopped"
  hostname = "cloudflared"

  command = [
    "tunnel",
    "--no-autoupdate",
    "run",
    "--token",
    var.twogt_cloudflared_token,
  ]
}