# Deploy checklist

Bring visio.hashcode.digital up for the first time on its own server. After this, every push to `main` deploys by itself (README → *Deploying*).

The order matters: DNS first (propagation), Vault before the first deploy, Rabotka last.

---

## Step 1 — The server runs hashcode-vps-infra

The visio has its own server (6 GB). It runs the same base as the main VPS: Docker, Traefik and the `hashcode-public` network, from [hashcode-vps-infra](https://github.com/brx-hashcode/hashcode-vps-infra).

On the new server, as the deploy user:

```bash
git clone https://github.com/brx-hashcode/hashcode-vps-infra.git ~/hashcode-vps-infra
cd ~/hashcode-vps-infra
./scripts/setup.sh                 # creates .env from .env.example, acme.json
# Fill .env: EMAIL and CF_DNS_API_TOKEN at least (Traefik's certificates).
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d traefik
```

Only Traefik is needed here. Postgres, Redis, Vault and the other services stay on the main VPS.

Then follow its README → *After a reboot*: the `hashcode-stack.service` unit, and the `systemctl mask` of host web servers.

Check: `docker network inspect hashcode-public` answers.

---

## Step 2 — DNS (Cloudflare, zone hashcode.digital)

| Name | Type | Content | Proxy |
|---|---|---|---|
| `visio` | A | the new server's public IPv4 | **DNS only** (grey cloud) |

It has to stay DNS only: video (UDP 10000) and TURN can't pass through the Cloudflare proxy. Traefik's certificate comes through DNS-01, so the setting doesn't affect it.

Check: `dig +short visio.hashcode.digital` returns the server's IP, not a Cloudflare address.

---

## Step 3 — Firewall

On top of 22, 80 and 443, open these on the server **and** in the hosting provider's firewall, if it has one:

| Port | For |
|---|---|
| `10000/udp` | Media (video bridge) |
| `3478/udp`, `3478/tcp` | STUN/TURN |
| `49160–49200/udp` | TURN relay |

With ufw: `sudo ./scripts/firewall.sh` from `~/hashcode-visio`, once the first deploy has copied it there. Or now, with the same four `ufw allow` lines.

---

## Step 4 — Vault

Use the terminal built into **https://vault.hashcode.digital** (the `>_` icon), with an admin token, as described in `docs/deploying-a-new-app.md`.

### The secrets

Under the `secret` engine, create **`apps/hashcode-visio`** with these keys:

| Key | Value | Required |
|---|---|---|
| `VISIO_PUBLIC_IP` | The new server's public IPv4 | yes |
| `JWT_APP_SECRET` | `openssl rand -hex 32`. **The same value goes into Rabotka (step 7).** | yes |
| `JICOFO_AUTH_PASSWORD` | `openssl rand -hex 24` | yes |
| `JVB_AUTH_PASSWORD` | `openssl rand -hex 24` | yes |
| `TURN_SECRET` | `openssl rand -hex 32` | yes |
| `VISIO_DOMAIN` | `visio.hashcode.digital` | no, that's the default |
| `JWT_APP_ID` | `rabotka` | no, that's the default |

Generate the values on your Mac and paste them in. The deploy stops if a required key is missing or empty.

### The policy and the role

The web terminal can break on quotes, so encode the policy on your Mac:

```bash
base64 < vault/hashcode-visio.hcl | tr -d '\n'; echo
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

The repo only holds how to reach the server and Vault. Everything the stack runs with comes from Vault. Set each one from your Mac, pasting the value at the prompt:

```bash
R=brx-hashcode/hashcode-visio
gh secret set VPS_HOST -R $R          # the new server's IP or hostname
gh secret set VPS_USER -R $R          # its deploy user
gh secret set VPS_SSH_KEY -R $R < ~/.ssh/<deploy key>   # private key for that user
gh secret set VPS_PORT -R $R          # optional, 22 by default
gh secret set VAULT_ADDR -R $R        # https://vault.hashcode.digital
gh secret set VAULT_ROLE_ID -R $R     # role_id from step 4
gh secret set VAULT_SECRET_ID -R $R   # secret_id from step 4
gh secret set SLACK_WEBHOOK_URL -R $R # optional
```

The deploy key's public half must be in the deploy user's `~/.ssh/authorized_keys` on the new server. That user also needs to run `docker` (`docker` group).

Never paste a Vault token, these IDs or a private key into a chat, a ticket or a commit.

---

## Step 6 — First deploy

**Actions → Deploy Visio → Run workflow** on `main`, or push to `main`.

The workflow:
1. checks the GitHub secrets;
2. logs in to Vault and checks every required key;
3. copies the stack to `~/hashcode-visio` and writes `.env` (mode 600);
4. starts the stack;
5. smoke-tests HTTPS, the embed script, closed anonymous rooms and the logo.

Check:
- https://visio.hashcode.digital opens over a valid certificate;
- opening `https://visio.hashcode.digital/test` without a token is refused (« Authentication required »).

---

## Step 7 — Point Rabotka at it

In Vault, on **both** `apps/rabotka-backend-develop` and `apps/rabotka-backend-production`:

| Key | Value |
|---|---|
| `JITSI_APP_SECRET` | **the same value as `JWT_APP_SECRET`** in `apps/hashcode-visio` |
| `JITSI_DOMAIN` | optional, defaults to `visio.hashcode.digital` |
| `JITSI_APP_ID` | optional, defaults to `rabotka` |

Then ship the `feat/self-hosted-jitsi` branches of rabotka-backend and rabotka-business. The backend reads these keys at deploy time.

Check, from Rabotka develop: a business on a plan with « Video interviews in Rabotka » opens an interview's visio. The call loads from visio.hashcode.digital with the HashCode logo, and the candidate's link joins it.

After that, the old `JAAS_*` keys in Rabotka's Vault can be deleted.

---

## Rotating a secret

1. **`JWT_APP_SECRET`:**
   1. Change it in `apps/hashcode-visio` **and** as `JITSI_APP_SECRET` in both Rabotka entries.
   2. Redeploy the visio, then both backends.
   3. Calls already open keep running; new ones need the new value on both sides.
2. **The others** (`JICOFO_AUTH_PASSWORD`, `JVB_AUTH_PASSWORD`, `TURN_SECRET`): change them in Vault and re-run the workflow. They're used only inside this server.
