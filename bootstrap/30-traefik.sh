#!/usr/bin/env bash
# Adds a file provider to the EXISTING Docker Traefik (it keeps its docker
# provider and Let's Encrypt resolver) and installs the DNS-gated route timer.
# Only the traefik container is recreated; other containers are untouched.
source "$(dirname "$0")/common.sh"
need_root

COMPOSE="$TRAEFIK_DIR/docker-compose.yml"
[[ -f "$COMPOSE" ]] || die "$COMPOSE not found"
mkdir -p "$TRAEFIK_DIR/dynamic"

if ! grep -q 'providers.file.directory' "$COMPOSE"; then
  log "Adding file provider to $COMPOSE (backup: $COMPOSE.bak-$(date +%s))"
  cp -a "$COMPOSE" "$COMPOSE.bak-$(date +%s)"
  sed -i \
    -e '/"--providers.docker.network=proxy"/a\      - "--providers.file.directory=/etc/traefik/dynamic"\n      - "--providers.file.watch=true"' \
    -e '/- \.\/letsencrypt:\/letsencrypt/a\      - ./dynamic:/etc/traefik/dynamic:ro' \
    "$COMPOSE"
  (cd "$TRAEFIK_DIR" && docker compose config -q && docker compose up -d --no-deps traefik)
else
  log "File provider already configured"
fi

install -m 0644 "$REPO_ROOT/host/systemd/homelab-dns-gate.service" /etc/systemd/system/
install -m 0644 "$REPO_ROOT/host/systemd/homelab-dns-gate.timer"   /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now homelab-dns-gate.timer
DYN_DIR="$TRAEFIK_DIR/dynamic" "$REPO_ROOT/host/traefik/dns-gate.sh"
