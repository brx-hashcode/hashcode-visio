#!/usr/bin/env bash
set -euo pipefail

# Bootstrap by hand, in ~/hashcode-visio, on a box running Dokploy (its
# Traefik and the dokploy-network must exist). The GitHub workflow does the
# same on every push to main; this is only for a manual start.

echo "==> Checking Dokploy's network..."
if ! docker network inspect dokploy-network >/dev/null 2>&1; then
  echo "    dokploy-network is missing: install Dokploy first."
  exit 1
fi

echo "==> Checking .env..."
if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "    Created .env from .env.example: fill it in, then run this again."
  exit 1
fi
if grep -q '=changeme$' .env; then
  echo "    .env still has 'changeme' values: fill them in first."
  exit 1
fi


echo "==> Firewall: these ports must be open on the VPS (and in any provider firewall):"
echo "      10000/udp           media (video bridge)"
echo "      3478/udp, 3478/tcp  TURN/STUN"
echo "      49160-49200/udp     TURN relay"
echo "    With ufw: sudo ./scripts/firewall.sh"

echo "==> Starting the stack..."
docker compose pull --ignore-buildable
docker compose up -d --build
echo "==> Done: https://$(grep '^VISIO_DOMAIN=' .env | cut -d= -f2)"
