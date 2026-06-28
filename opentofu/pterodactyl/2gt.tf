# ---------------------------------------------------------------------------
# 2GT Website
# ---------------------------------------------------------------------------
resource "docker_image" "twogt_website" {
    name = "2gtbk/2gt_website:latest"
}

resource "docker_container" "twogt_website" {
    name    = "2gt-website"
    image   = docker_image.twogt_website.image_id
    restart = "unless-stopped"

    ports {
        internal = 80
        external = 9999
    }

    env = [
        "JEKYLL_ENV=production",
    ]
}
