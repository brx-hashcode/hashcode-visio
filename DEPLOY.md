# Deploy checklist

Bring visio.hashcode.digital up for the first time on its own server. After this, every push to `main` deploys by itself (README → *Deploying*).

The order matters: the tunnel hostnames first, Vault before the first deploy, Rabotka last.

---

## Step 1 — The server

The visio has its own server, set up like the main VPS:
- **Dokploy** and its Traefik (`dokploy-traefik`, network `dokploy-network`);
- **a Cloudflare tunnel** (`cloudflared.service`, managed from the Zero Trust dashboard);
- **`docker-block-ports.service`**, which drops 80, 443 and 3000 from the internet. Web traffic only arrives through the tunnel.

Nothing from hashcode-vps-infra is installed here. A second Traefik would fight Dokploy's for 80 and 443. Postgres, Redis and Vault stay on the main VPS.

The deploy logs in over SSH and runs `docker compose`, so the deploy user must be in the `docker` group. Once, on the server:

```bash
sudo usermod -aG docker <deploy user>
# log out and back in, then:
docker network inspect dokploy-network >/dev/null && echo ok
```

---

## Step 2 — Cloudflare: the tunnel's public hostnames

In **Zero Trust → Networks → Tunnels →** this server's tunnel **→ Public hostnames**, add:

| Hostname | Service |
|---|---|
| `visio.hashcode.digital` | `http://localhost:80` (Dokploy's Traefik, which routes to the call page) |
| `dokploy.hashcode.digital` | `http://localhost:3000` (Dokploy's dashboard) |

Cloudflare creates the proxied DNS records itself. Remove any existing `visio` or `dokploy` record first, or the hostname can't be added.

**Put `dokploy.hashcode.digital` behind Cloudflare Access** (Zero Trust → Access → Applications, your email only). On 2026-09-12, a public admin login page got all of hashcode.digital flagged by Google Safe Browsing (see hashcode-vps-infra, Portainer).

No certificate is issued on the server: Cloudflare serves HTTPS, and Let's Encrypt can't reach the box anyway.

Check:
- `curl -sI https://visio.hashcode.digital` answers. Before the first deploy, a 404 comes from Traefik, which is expected.
- https://dokploy.hashcode.digital asks for your Access login first.

---

## Step 3 — Firewall: media and TURN

Video and TURN can't pass through the tunnel. Browsers reach them on the server's IP (`VISIO_PUBLIC_IP`), so these ports must be open. `docker-block-ports.service` doesn't touch them:

| Port | For |
|---|---|
| `10000/udp` | Media (video bridge) |
| `3478/udp`, `3478/tcp` | STUN/TURN |
| `49160–49200/udp` | TURN relay |

Docker publishes container ports ahead of ufw, so they work even with ufw active. Still, run `sudo ./scripts/firewall.sh` from `~/hashcode-visio` after the first deploy, so `ufw status` shows them. Open them in the hosting provider's firewall too, if it has one.

---

## Step 4 — Vault

Use the terminal built into **https://vault.hashcode.digital** (the `>_` icon), with an admin token, as described in `docs/deploying-a-new-app.md`.

### The secrets

Under the `secret` engine, create `apps/hashcode-visio` with these keys:

| Key | Value | Required |
|---|---|---|
| `VISIO_PUBLIC_IP` | The new server's public IPv4 | yes |
| `JWT_APP_SECRET` | `openssl rand -hex 32`. **The same value goes into Rabotka (step 7).** | yes |
| `JICOFO_AUTH_PASSWORD` | `openssl rand -hex 24` | yes |
| `JVB_AUTH_PASSWORD` | `openssl rand -hex 24` | yes |
| `JIGASI_TRANSCRIBER_PASSWORD` | `openssl rand -hex 24` | yes |
| `TURN_SECRET` | `openssl rand -hex 32` | yes |
| `VISIO_DOMAIN` | `visio.hashcode.digital` | no, that's the default |
| `JWT_APP_ID` | `rabotka` | no, that's the default |

Generate the values on your Mac and paste them in. The deploy stops if a required key is missing or empty.

### The policy and the role

The web terminal can break on quotes, so encode the policy on your Mac:

```bash
base64 < ~/projects/hashcode/hashcode-visio/vault/hashcode-visio.hcl | tr -d '\n'; echo
```

Then in the Vault terminal:

```
vault write sys/policies/acl/hashcode-visio policy=<BASE64>
vault write auth/approle/role/hashcode-visio token_policies=hashcode-visio token_ttl=10m token_max_ttl=30m
vault read auth/approle/role/hashcode-visio/role-id
vault write -force auth/approle/role/hashcode-visio/secret-id
```

Keep the `role_id` and the `secret_id` (not `secret_id_accessor`). A `secret_id` is shown only once.

---

## Step 5 — GitHub secrets

The repo only holds how to reach the server and Vault. Everything the stack runs with comes from Vault.

The deploy gets its own SSH key, not your personal one, so you can revoke it alone. From your Mac:

```bash
R=brx-hashcode/hashcode-visio

# A deploy key for GitHub Actions, authorized on the visio server.
ssh-keygen -t ed25519 -N '' -C 'github-actions@hashcode-visio' -f ~/.ssh/hashcode-visio-deploy
ssh-copy-id -i ~/.ssh/hashcode-visio-deploy.pub hashcode-vps-visio

# How to reach the server (values from ~/.ssh/config, Host hashcode-vps-visio).
gh secret set VPS_HOST -R $R --body "$(ssh -G hashcode-vps-visio | awk '/^hostname /{print $2}')"
gh secret set VPS_USER -R $R --body "$(ssh -G hashcode-vps-visio | awk '/^user /{print $2}')"
gh secret set VPS_PORT -R $R --body "$(ssh -G hashcode-vps-visio | awk '/^port /{print $2}')"
gh secret set VPS_SSH_KEY -R $R < ~/.ssh/hashcode-visio-deploy

# Vault: the address, then the two IDs from step 4, pasted at the prompt.
gh secret set VAULT_ADDR -R $R --body https://vault.hashcode.digital
gh secret set VAULT_ROLE_ID -R $R
gh secret set VAULT_SECRET_ID -R $R

gh secret list -R $R
```

`SLACK_WEBHOOK_URL` is optional: `gh secret set SLACK_WEBHOOK_URL -R $R`.

Never paste a Vault token, these IDs or a private key into a chat, a ticket or a commit.

---

## Step 6 — First deploy

**Actions → Deploy Visio → Run workflow** on `main`, or push to `main`.

The workflow:

1. checks the GitHub secrets;
2. logs in to Vault and checks every required key;
3. copies the stack to `~/hashcode-visio` and writes `.env` (mode 600);
4. starts the stack;
5. smoke-tests HTTPS, the embed script, token checking and the logo.

Check:

- https://visio.hashcode.digital opens over a valid certificate;
- opening `https://visio.hashcode.digital/test` joins the room straight away, with no « Authentification requise » box.

---

## Step 7 — Point Rabotka at it

In Vault, on **both** `apps/rabotka-backend-develop` and `apps/rabotka-backend-production`:

| Key                | Value                                                           |
| ------------------ | --------------------------------------------------------------- |
| `JITSI_APP_SECRET` | **the same value as** `JWT_APP_SECRET` in `apps/hashcode-visio` |
| `JITSI_DOMAIN`     | optional, defaults to `visio.hashcode.digital`                  |
| `JITSI_APP_ID`     | optional, defaults to `rabotka`                                 |

Then ship the `feat/self-hosted-jitsi` branches of rabotka-backend and rabotka-business. The backend reads these keys at deploy time.

Check, from Rabotka develop: a business on a plan with « Video interviews in Rabotka » opens an interview's visio. The call loads from visio.hashcode.digital with the HashCode logo, and the candidate's link joins it.

After that, the old `JAAS_*` keys in Rabotka's Vault can be deleted.

---

## Rotating a secret

1. `JWT_APP_SECRET`**:**
   1. Change it in `apps/hashcode-visio` **and** as `JITSI_APP_SECRET` in both Rabotka entries.
   2. Redeploy the visio, then both backends.
   3. Calls already open keep running; new ones need the new value on both sides.
2. **The others** (`JICOFO_AUTH_PASSWORD`, `JVB_AUTH_PASSWORD`, `JIGASI_TRANSCRIBER_PASSWORD`, `TURN_SECRET`): change them in Vault and re-run the workflow. They're used only inside this server.
