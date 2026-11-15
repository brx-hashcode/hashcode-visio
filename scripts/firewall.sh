#!/usr/bin/env bash
set -euo pipefail

# Opens what the visio needs on the server's IP: media and TURN. Web traffic
# comes through the Cloudflare tunnel, not these ports.
# Run as root on the VPS: sudo ./scripts/firewall.sh

ufw allow 10000/udp comment 'visio: media (jvb)'
ufw allow 3478/udp comment 'visio: TURN/STUN'
ufw allow 3478/tcp comment 'visio: TURN/STUN over TCP'
ufw allow 49160:49200/udp comment 'visio: TURN relay'
ufw status numbered
