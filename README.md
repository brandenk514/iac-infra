# IAC-INFRA

Homelab infrastructure as code. Terraform for containerized stacks over SSH; Ansible for host-level installs.

## Stacks

### Terraform

Uses the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider over SSH.

- [`opentofu/trex/`](opentofu/trex/) — primary server: Traefik, media (Sonarr/Radarr/Lidarr/Prowlarr/Jellyfin/Jellyseerr), Immich, monitoring (Beszel/Dozzle), AI (Ollama/Open WebUI), and supporting services.
- [`opentofu/nanosaurus/`](opentofu/nanosaurus/) — dedicated Tdarr transcode server with Intel A310 QSV hardware acceleration.

### Ansible

- [`ansible/`](ansible/) — host-level configuration for homelab Ubuntu servers. `baseline` role provisions new hosts (packages, admin user, SSH hardening, Docker, Tailscale); `update` role patches and conditionally reboots. See [ansible/README.md](ansible/README.md) for deployment flow and required variables.

## Usage

### Terraform stacks

From inside a stack directory:

```sh
cp terraform.tfvars.example terraform.tfvars  # fill in values (when present)
terraform init
terraform plan
terraform apply
```

### Ansible

Baseline provisioning is run by hand from a workstation (see [ansible/README.md](ansible/README.md)).

Monthly patching runs on a schedule via GitHub Actions — see [.github/workflows/update.yml](.github/workflows/update.yml). The workflow checks out the repo on a GitHub-hosted runner, joins the Tailnet via the Tailscale action, installs Ansible, writes the SSH key and inventory from repo secrets (`ANSIBLE_SSH_KEY`, `ANSIBLE_INVENTORY`), and runs `update.yml`. Fires at 04:00 UTC on the 1st of each month, and can also be triggered manually via `workflow_dispatch`.

## Layout

```
opentofu/
├── trex/           # primary homelab server
└── nanosaurus/     # dedicated transcode server
ansible/            # host-level config (baseline + update roles)
.github/workflows/  # terraform deploy + scheduled monthly patching
```

## Ansible

Host-level configuration for homelab Ubuntu servers.

### Roles

- `baseline` — one-shot standardization for a new server: packages (`btop`, `htop`, `vim`, `git`, `fail2ban`, `chrony`, `unattended-upgrades`), admin user with SSH keys + passwordless sudo, SSH hardening (drop-in at `/etc/ssh/sshd_config.d/00-hardening.conf`), timezone, Docker CE from the official repo, and Tailscale from the official repo.

  No host firewall is installed. Docker bypasses UFW by inserting its own iptables rules, so UFW gives false confidence once Docker is running. Instead, the network boundary for these hosts is enforced by *bind policy*: container ports are published to `127.0.0.1:` or to the Tailscale interface (e.g. `100.x.y.z:443`). Anything that must be LAN-reachable goes through Traefik, which is itself the only container bound to `0.0.0.0`. SSH brute-force protection is handled by `fail2ban`.
- `update` — idempotent patching: `apt update && apt dist-upgrade`, autoremove, autoclean. Reboots only when `/var/run/reboot-required.pkgs` contains a `linux-image-*` entry.

### Playbooks

- `site.yml` — applies `baseline` to the `homelab` group.
- `update.yml` — applies `update` to the `homelab` group, one host at a time (`serial: 1`).

### First-time setup

```sh
ansible-galaxy collection install -r requirements.yml
```

Populate `inventory.yml` with your hosts and set `admin_authorized_keys` in `group_vars/all.yml` (or per-host in `host_vars/<host>.yml`).

## Deploy a new server

```sh
# Initial run as root over a fresh install.
ansible-playbook -i inventory.yml site.yml -u root -e tailscale_authkey=tskey-auth-...

# Subsequent runs via admin user.
ansible-playbook site.yml
```

If `admin_authorized_keys` is empty, the baseline role skips admin-user creation and Docker-group membership — useful when you're managing the existing user out-of-band.

### Run updates

```sh
ansible-playbook update.yml
```

A host reboots only when a kernel package was updated. Hosts are processed one at a time so the cluster never loses more than one node to a reboot.

### Variables

See [`group_vars/all.yml`](group_vars/all.yml). Key values:

| Variable | Default | Purpose |
| --- | --- | --- |
| `admin_user` | `ops` | Admin account created by baseline |
| `admin_authorized_keys` | `[]` | Public keys for the admin user — empty disables user creation |
| `ssh_port` | `22` | SSH port |
| `timezone` | `UTC` | System timezone |
| `tailscale_authkey` | `""` | Auth key for `tailscale up`; empty installs only |
| `tailscale_up_args` | `--ssh` | Extra flags passed to `tailscale up` |
| `update_reboot_timeout` | `600` | Seconds to wait for a host to come back after reboot |

Store `tailscale_authkey` in `ansible-vault` or pass at runtime with `-e tailscale_authkey=...`.
