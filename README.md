# hashcode-visio

Our own Jitsi Meet for Rabotka's interview calls, at **https://visio.hashcode.digital**.

It runs on its own server (6 GB), set up with [hashcode-vps-infra](https://github.com/brx-hashcode/hashcode-vps-infra)'s Traefik, and plugs into it like any app:
- the call's web page joins the shared `hashcode-public` network;
- the infra's Traefik serves it over HTTPS, with Let's Encrypt over Cloudflare DNS-01;
- media and TURN bypass Traefik and are published on the host.

This repo only holds the visio stack.

## Stack

| Service | Image | Role |
|---|---|---|
| `web` | `jitsi/web:stable-11031` | The call page and `external_api.js`; nginx in front of Prosody, the whiteboard and Etherpad. Routed by Traefik. |
| `prosody` | `jitsi/prosody:stable-11031` | XMPP signalling; checks every room's JWT. |
| `jicofo` | `jitsi/jicofo:stable-11031` | Conference focus. |
| `jvb` | `jitsi/jvb:stable-11031` | Video bridge. Media on **UDP 10000**, straight from the browsers. |
| `turn` | `coturn/coturn:4.18.0` | STUN/TURN for candidates on strict mobile or office networks. **3478 udp/tcp**, relay **49160–49200/udp**. |
| `whiteboard` | `jitsi/excalidraw-backend:2026.10.0` | The whiteboard in the call. |
| `etherpad` | `etherpad/etherpad:3.3.7` | « Document partagé » in the call. |

All images are pinned: bump them deliberately, all four Jitsi ones together.

`config/` holds two branding files:
- **`custom-interface_config.js`** replaces the « jitsi » logo with HashCode's (the brx-hashcode GitHub avatar, linking to hashcode.digital) and names the app « Rabotka ».
- **`etherpad-pad.css`** is Etherpad's skin stylesheet plus one rule hiding its « pad deletion token » box, which Etherpad 3 has no setting for.

## How Rabotka uses it

- **The token:** for each call, `rabotka-backend` signs an HS256 JWT with `JITSI_APP_SECRET` from its Vault, which **must equal `JWT_APP_SECRET` here**. The token carries:
  - `iss: rabotka` (= `JWT_APP_ID`) and `aud: jitsi`;
  - `sub: visio.hashcode.digital`;
  - `room`: that interview's room only;
  - `context.user`: the person's name and email, and `moderator` (true for the business).
- **The embed:** `rabotka-business` embeds the call with `@jitsi/react-sdk` (`JitsiMeeting`, `domain=visio.hashcode.digital`) with that token.
- **No token, no room:** without a valid token the server refuses the room. The smoke test checks that anonymous rooms stay closed.

Locally, `rabotka-backend/docker-compose.yml` runs the same images on `https://localhost:8443`, with a self-signed certificate. That's for development; this repo is for the server.

## Before the first deploy

Follow **[DEPLOY.md](DEPLOY.md)**:
1. the server runs hashcode-vps-infra's Traefik;
2. DNS (`visio`, DNS only);
3. firewall;
4. Vault (`secret/apps/hashcode-visio` + AppRole);
5. GitHub secrets;
6. first deploy;
7. Rabotka's `JITSI_APP_SECRET`.

**Where the secrets live:**
- **Vault, `secret/apps/hashcode-visio`:** everything the stack runs with: `VISIO_PUBLIC_IP`, `JWT_APP_SECRET`, `JICOFO_AUTH_PASSWORD`, `JVB_AUTH_PASSWORD`, `TURN_SECRET` (plus optional `VISIO_DOMAIN`, `JWT_APP_ID`).
- **GitHub:** only how to reach the server and Vault: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_PORT`, `VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID`, and optional `SLACK_WEBHOOK_URL`.

`JWT_APP_SECRET` must equal `JITSI_APP_SECRET` in Rabotka's own Vault entries (develop and production), or every call is refused.

## Deploying

Every push to `main`, or a manual run (**Actions → Deploy Visio → Run workflow**), runs these steps:

1. **Validate** the compose file and the scripts. This also runs on pull requests.
2. **Log in to Vault** (AppRole) and read `secret/apps/hashcode-visio`. A missing or empty required key fails the deploy instead of starting a server with no auth.
3. **Copy** `docker-compose.yml`, `.env.example`, `config/` and `scripts/` to `~/hashcode-visio` on the VPS with rsync. There's no git checkout on the box, so nothing there can drift or conflict.
4. **Write `.env`** from Vault (mode 600), check that `hashcode-public` exists, then `docker compose pull && docker compose up -d --remove-orphans`.
5. **Smoke tests:**
   - the page answers over HTTPS;
   - `external_api.js` is served;
   - anonymous rooms are closed (JWT on);
   - the HashCode logo is in place;
   - then Slack gets the result.

## On the server

```bash
cd ~/hashcode-visio
docker compose ps
docker compose logs -f web prosody jicofo jvb
docker compose restart web          # after a config/ change
docker compose pull && docker compose up -d
```

`scripts/setup.sh` bootstraps by hand without the workflow: it checks the infra network and `.env`, lists the ports, then starts the stack.

## Sizing

Jitsi and its services use about 2–3 GB of RAM at rest. Each running call adds mostly CPU and bandwidth on the video bridge.

Recording and live streaming (Jibri) aren't part of this stack. Each Jibri needs about 2–4 GB and 2 CPUs for a single call, so they would need their own capacity.

## Troubleshooting

- **The call stays on « Configuration des appareils… »:** the browser hasn't granted camera and microphone access, or another tab is holding the camera.
- **Joins, then « disconnected »:** UDP 10000 isn't reachable. Check the firewall and `VISIO_PUBLIC_IP`.
- **« not allowed to join »:** the token was signed with a different secret (`JWT_APP_SECRET` ≠ Vault `JITSI_APP_SECRET`), or for another room.
- **A candidate on mobile data can't connect:** TURN isn't reachable. Check 3478 udp/tcp and 49160–49200/udp.
