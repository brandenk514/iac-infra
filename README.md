# IAC-INFRA

Homelab infrastructure as code. OpenTofu manages containerized stacks over SSH; Ansible handles host-level configuration. State lives in Backblaze B2 via the `s3` backend; CI runners reach hosts over the Tailnet.

## Stacks

### OpenTofu

Each stack uses the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider and connects to its target host with `ssh://`. Backend keys are isolated per stack so blast radius is one host at a time.

- [`opentofu/trex/`](opentofu/trex/) — primary server: Traefik, media (Sonarr/Radarr/Lidarr/Prowlarr/Jellyfin/Jellyseerr), Immich, monitoring (Beszel/Dozzle), AI (Ollama/Open WebUI), and supporting services.
- [`opentofu/nanosaurus/`](opentofu/nanosaurus/) — dedicated Tdarr transcode server with Intel A310 QSV hardware acceleration; ships a Beszel agent for monitoring.
- [`opentofu/pterodactyl/`](opentofu/pterodactyl/) — Cloudflare Tunnel (`cloudflared`) container fronting the Pterodactyl game-server panel.

### Ansible

Two roles applied to the `homelab` group via [`ansible/site.yml`](ansible/site.yml). Both roles are tagged so they can be run independently.

- `baseline` — one-shot standardization for a fresh Ubuntu host: packages (`btop`, `htop`, `vim`, `git`, `fail2ban`, `chrony`, `unattended-upgrades`, `apt-listchanges`), admin user with SSH keys + passwordless sudo, SSH hardening (drop-in at `/etc/ssh/sshd_config.d/00-hardening.conf`), timezone, Docker CE from the official repo, and Tailscale from the official repo. Patching is delegated to `unattended-upgrades` (28-day cycle, auto-reboot at 03:00 local when a kernel package is staged) — there is no separate update playbook.
- `traefik` — renders Traefik's static (`traefik.yml`) and dynamic (`config.yml`) config files into the host container mount, ensures `acme.json` is `0600`, and restarts the Traefik container on change. The container itself is created by the `trex` OpenTofu stack; this role owns its on-disk configuration so changes can be reviewed and rolled out without re-applying Tofu.

No host firewall is installed. Docker bypasses UFW by inserting its own iptables rules, so UFW gives false confidence once Docker is running. The network boundary is enforced by *bind policy*: container ports are published to `127.0.0.1:` or to the Tailscale interface (e.g. `100.x.y.z:443`). Anything that must be LAN-reachable goes through Traefik, which is the only container bound to `0.0.0.0`. SSH brute-force protection is handled by `fail2ban`.

## Layout

```
opentofu/
├── trex/         # primary homelab server
├── nanosaurus/   # transcode server (Tdarr + QSV)
└── pterodactyl/  # cloudflared tunnel
ansible/
├── roles/baseline/   # OS, SSH, Docker, Tailscale, unattended-upgrades
├── roles/traefik/    # Traefik static/dynamic config + acme.json
└── site.yml          # applies both roles, tag-selectable
.github/workflows/
└── tofu-deploy.yml   # opentofu apply per stack
```

## Usage

### OpenTofu stacks

From inside a stack directory:

```sh
cp terraform.tfvars.example terraform.tfvars  # when present
tofu init
tofu plan
tofu apply
```

CI applies each stack on push to `main` when files under `opentofu/**` change — see [.github/workflows/tofu-deploy.yml](.github/workflows/tofu-deploy.yml). Each stack is its own job with its own B2 state key (`trex/`, `tdarr/`, `pterodactyl/`). The runner joins the Tailnet via the Tailscale GitHub Action, writes the SSH key and per-stack `terraform.tfvars` from secrets, then runs `tofu init` + `tofu apply -auto-approve`.

Required secrets:

| Secret | Purpose |
| --- | --- |
| `B2_KEY_ID`, `B2_APPLICATION_KEY` | Backblaze application key (S3-compatible) |
| `B2_BUCKET`, `B2_REGION` | State bucket + region |
| `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET` | Tailscale OAuth for the CI runner |
| `TF_SSH_KEY` | Private key for the Docker-host SSH user |
| `TF_TFVARS_MAIN` | tfvars content for `trex` |
| `TF_TFVARS_TDARR` | tfvars content for `nanosaurus` (key kept post-rename) |
| `TF_TFVARS_PTERODACTYL` | tfvars content for `pterodactyl` |

### Ansible

First-time setup:

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml
```

Populate `inventory.yml` with your hosts and set `admin_authorized_keys` in `group_vars/all.yml` (or per-host in `host_vars/<host>.yml`). Store `tailscale_authkey` in `ansible-vault` or pass it at runtime.

#### Provision a new server

```sh
# Initial run as root over a fresh install.
ansible-playbook -i inventory.yml site.yml -u root -e tailscale_authkey=tskey-auth-...

# Subsequent runs via the admin user.
ansible-playbook site.yml
```

If `admin_authorized_keys` is empty, the baseline role skips admin-user creation and Docker-group membership — useful when you're managing the existing user out-of-band.

#### Apply one role at a time

```sh
ansible-playbook site.yml --tags baseline
ansible-playbook site.yml --tags traefik
```

#### Patching

Hosts patch themselves via `unattended-upgrades` configured by the baseline role: `apt` periodic runs every 28 days, all standard origins (security, updates, backports, ESM) are allowed, and the host reboots automatically at 03:00 when a kernel package is staged. There is no separate `update` playbook or scheduled CI job.

### Variables

Defaults live in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml) and each role's `defaults/main.yml`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `admin_user` | `core-ci` | Admin account created by baseline |
| `admin_authorized_keys` | `[]` | Public keys for the admin user — empty disables user creation |
| `ssh_port` | `22` | SSH port |
| `ssh_permit_root_login` | `"no"` | sshd hardening drop-in setting |
| `ssh_password_authentication` | `"no"` | sshd hardening drop-in setting |
| `timezone` | `America/Denver` | System timezone |
| `tailscale_authkey` | `""` | Auth key for `tailscale up`; empty installs only |
| `tailscale_up_args` | `--ssh` | Extra flags passed to `tailscale up` |
| `traefik_docker_mnt` | `/mnt/r5-dstor/containers` | Host container mount; the role writes config under `<mnt>/traefik/confs` and certs under `<mnt>/traefik/certs` |
| `traefik_acme_email` | (set in defaults) | Email used for Let's Encrypt registration |
| `traefik_cert_domains` | (set in defaults) | Domains/SANs requested via the Cloudflare DNS-01 challenge |
| `traefik_entrypoints` | `web`/`websecure` + `external-web`/`external-websecure` | Listener definitions rendered into `traefik.yml` |
