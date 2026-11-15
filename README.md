# hashcode-visio

Our own Jitsi Meet, open to anyone, at **https://visio.hashcode.digital**. Rabotka's interview calls are one app using it.

It runs on its own server, which runs [Dokploy](https://dokploy.com) (at dokploy.hashcode.digital), and plugs into Dokploy's Traefik like any app there:
- the call's web page joins `dokploy-network`;
- a Cloudflare tunnel brings `visio.hashcode.digital` to that Traefik on `http://localhost:80`. Cloudflare serves HTTPS, and 80/443 are closed to the internet, as on the main VPS;
- media and TURN can't pass through the tunnel. They are published on the host and reached on its IP (`VISIO_PUBLIC_IP`).

Postgres, Redis, Vault and the other shared services stay on the main VPS (hashcode-vps-infra). Only Vault is used from here, by the deploy.

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
| `transcriber` | `jitsi/jigasi:stable-11031` | Captions (« Sous-titres »): joins the call as a hidden participant when the business turns them on. |
| `vosk` | built from `vosk/Dockerfile` (`kaldi-vosk-server` + `vosk-model-small-fr-0.22`) | French speech-to-text for the captions. Nothing is saved. |

All images are pinned: bump them deliberately, the five Jitsi ones (with Jigasi) together.

`config/` holds:
- **`custom-config.js`** keeps the captions in French, hides the « translate into » list (Vosk doesn't translate), and closes the call at once when it ends.
- **`custom-interface_config.js`** names the app « HashCode Visio », puts HashCode's mark in the call and on the welcome page (linking to hashcode.digital), and drops Jitsi's app-store footer.
- **`etherpad-pad.css`** is Etherpad's skin stylesheet plus one rule hiding its « pad deletion token » box, which Etherpad 3 has no setting for.
- **`web/`**, the welcome page in HashCode's look:
  - `plugin.head.html`: Inter and the stylesheet, every rule scoped to `.welcome`, so the call screen is untouched;
  - `welcomePageAdditionalContent.html`: the three points and the footer under the room field;
  - `title.html`: title, description, canonical, share card (Open Graph and X, with `og-image.png`) and structured data (schema.org `WebApplication`), on every page;
  - `og-image.png`: the 1200×630 share card, rendered from `og/og-image.html` (the command to regenerate it is in that file);
  - `robots.txt` and `sitemap.xml`: only the welcome page is indexed; rooms stay out of search;
  - `hashcode-logo.png`: the mark;
  - `hashcode-branding.sh`: runs at each start and writes « HashCode Visio » and the tagline into Jitsi's translations and its PWA manifest.

  The stylesheet follows the class names of `jitsi/web:stable-11031`. **After bumping Jitsi, open the welcome page and check it.**

## How Rabotka uses it

- **The token:** for each call, `rabotka-backend` signs an HS256 JWT with `JITSI_APP_SECRET` from its Vault, which **must equal `JWT_APP_SECRET` here**. The token carries:
  - `iss: rabotka` (= `JWT_APP_ID`) and `aud: jitsi`;
  - `sub: visio.hashcode.digital`;
  - `room`: that interview's room only;
  - `context.user`: the person's name and email, and `moderator` (true for the business);
  - `context.features.transcription: true` for the business only: only it can turn the captions on, and everyone sees them.
- **The embed:** `rabotka-business` embeds the call with `@jitsi/react-sdk` (`JitsiMeeting`, `domain=visio.hashcode.digital`) with that token.
- **Open to anyone:** a room opens without a token (`JWT_ALLOW_EMPTY`), and the first person in moderates. Rabotka is one app using it: its token names the person, makes the business moderator and turns the captions on. A token with a wrong signature is still refused.

Locally, `rabotka-backend/docker-compose.yml` runs the same images on `https://localhost:8443`, with a self-signed certificate. That's for development; this repo is for the server.

## Before the first deploy

Follow **[DEPLOY.md](DEPLOY.md)**:
1. the server runs Dokploy, and the deploy user can run `docker`;
2. the tunnel's public hostnames (`visio`, `dokploy` behind Access);
3. firewall for media and TURN;
4. Vault (`secret/apps/hashcode-visio` + AppRole);
5. GitHub secrets;
6. first deploy;
7. Rabotka's `JITSI_APP_SECRET`.

**Where the secrets live:**
- **Vault, `secret/apps/hashcode-visio`:** everything the stack runs with: `VISIO_PUBLIC_IP`, `JWT_APP_SECRET`, `JICOFO_AUTH_PASSWORD`, `JVB_AUTH_PASSWORD`, `JIGASI_TRANSCRIBER_PASSWORD`, `TURN_SECRET` (plus optional `VISIO_DOMAIN`, `JWT_APP_ID`).
- **GitHub:** only how to reach the server and Vault: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_PORT`, `VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID`, and optional `SLACK_WEBHOOK_URL`.

`JWT_APP_SECRET` must equal `JITSI_APP_SECRET` in Rabotka's own Vault entries (develop and production), or every call is refused.

## Deploying

Every push to `main`, or a manual run (**Actions → Deploy Visio → Run workflow**), runs these steps:

1. **Validate** the compose file and the scripts. This also runs on pull requests.
2. **Build Vosk** (the one image we build) in GitHub Actions and push it to GHCR as `hashcode-visio-vosk:small-fr-0.22-<hash of vosk/>`, with a registry build cache, as rabotka-backend does. When `vosk/` hasn't changed, that tag already exists and the build is skipped.
3. **Log in to Vault** (AppRole) and read `secret/apps/hashcode-visio`. A missing or empty required key fails the deploy instead of starting a server with no auth.
4. **Copy** `docker-compose.yml`, `.env.example`, `config/` and `scripts/` to `~/hashcode-visio` on the VPS with rsync. There's no git checkout on the box, so nothing there can drift or conflict.
5. **Write `.env`** from Vault (mode 600), check that `dokploy-network` exists, log in to GHCR with the run's token, `docker compose pull` (only changed layers download), log out, then `docker compose up -d --no-build --remove-orphans`. Nothing is built on the server.
6. **Smoke tests:**
   - the page answers over HTTPS;
   - `external_api.js` is served;
   - tokens are still checked (JWT on, no anonymous domain);
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
