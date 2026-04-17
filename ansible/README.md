# Pterodactyl (DMZ)

Installs Pterodactyl Panel + Wings on `pterodactyl.dmz.uaccloud.com` (Ubuntu 24.04), fronted by a Cloudflare Tunnel.

## Architecture

| Component      | Bind              | Exposure                                        |
| -------------- | ----------------- | ----------------------------------------------- |
| nginx (Panel)  | `127.0.0.1:80`    | tunnel → `games.uaccloud.com`                   |
| Wings API      | `0.0.0.0:8443`    | tunnel → `games-node.uaccloud.com` (self-signed, `noTLSVerify: true`) |
| Wings SFTP     | `0.0.0.0:2022`    | direct DMZ firewall rule                        |
| MariaDB, Redis | `127.0.0.1`       | internal only                                   |
| SSH            | `:22`             | admin only                                      |

## Secrets (Gitea Actions)

All values live in Gitea repo/org secrets and are injected into the runner env. None are stored in the repo.

| Secret                   | Purpose                                                |
| ------------------------ | ------------------------------------------------------ |
| `SSH_PRIVATE_KEY`        | Runner → DMZ host                                      |
| `MARIADB_ROOT_PASSWORD`  | MariaDB root                                           |
| `PANEL_DB_PASSWORD`      | `pterodactyl` DB user                                  |
| `PANEL_APP_KEY`          | Laravel app key (`base64:...`)                         |
| `PANEL_ADMIN_EMAIL`      | Initial admin account                                  |
| `PANEL_ADMIN_PASSWORD`   | Initial admin account                                  |
| `CF_TUNNEL_TOKEN`        | Cloudflare remote-managed tunnel connector token       |
| `WINGS_NODE_CONFIG`      | Full contents of `/etc/pterodactyl/config.yml` (phase 2) |

Mirror these into a personal password manager — Gitea secrets are the consumer, not the source of truth.

## Deployment flow

Node provisioning is inherently two-phase: Panel must exist before you can create a node, and the node's config.yml is what Wings needs to start.

### Phase 1 — Panel + tunnel

1. Create the Cloudflare Tunnel in the Zero Trust dashboard (remote-managed). Copy the connector token into `CF_TUNNEL_TOKEN`.
2. Configure ingress rules in the dashboard:
   - `games.uaccloud.com` → `http://127.0.0.1:80`
   - `games-node.uaccloud.com` → `https://127.0.0.1:8443` with **No TLS Verify** enabled
3. Generate `PANEL_APP_KEY` locally with `php artisan key:generate --show` (or any `base64:` + 32-byte random value) and add all other Gitea secrets.
4. Push to `main`. Workflow runs Panel + cloudflared roles; wings installs binary + cert but the service stays down until phase 2.
5. Log in to `https://games.uaccloud.com` with the admin credentials.

### Phase 2 — Node

1. In Panel: create a Location, then create a Node with FQDN `games-node.uaccloud.com`, scheme `https`, port `8443`, SFTP port `2022`.
2. Open the node's **Configuration** tab and copy the generated YAML.
3. Paste into the `WINGS_NODE_CONFIG` Gitea secret (full file contents).
4. Re-run the workflow. Wings picks up `/etc/pterodactyl/config.yml` and starts.

## Local runs

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml
export MARIADB_ROOT_PASSWORD=... PANEL_DB_PASSWORD=... # etc
ansible-playbook pterodactyl.yml
```
