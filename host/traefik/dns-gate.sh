#!/usr/bin/env bash
# Enables a Traefik route only once its DNS A record points at this server.
#
# Why: a router with certResolver=letsencrypt makes Traefik request a cert
# immediately. If DNS doesn't resolve yet the HTTP-01 challenge fails, and
# repeated failures run into Let's Encrypt's failed-validation rate limit.
# So each route file is written only after public resolvers (1.1.1.1 and
# 8.8.8.8) agree on the A record. Run by homelab-dns-gate.timer; idempotent.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DYN_DIR="${DYN_DIR:-/opt/apps/traefik/dynamic}"
PUBLIC_IP="${PUBLIC_IP:-$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')}"
GW="${GW:-$(docker network inspect proxy -f '{{(index .IPAM.Config 0).Gateway}}')}"

# name  host  nodeport
ROUTES=(
  "argocd  argocd.futurnex.io   30080"
  "grafana grafana.futurnex.io  30300"
)

mkdir -p "$DYN_DIR"
for r in "${ROUTES[@]}"; do
  read -r name host port <<<"$r"
  out="$DYN_DIR/$name.yml"
  a1="$(dig +short A "$host" @1.1.1.1 | tail -1)"
  a2="$(dig +short A "$host" @8.8.8.8 | tail -1)"
  if [[ "$a1" == "$PUBLIC_IP" && "$a2" == "$PUBLIC_IP" ]]; then
    tmp="$(mktemp)"
    sed -e "s#__NAME__#$name#g" -e "s#__HOST__#$host#g" -e "s#__GW__#$GW#g" -e "s#__PORT__#$port#g" \
      "$DIR/route.yml.tmpl" > "$tmp"
    if ! cmp -s "$tmp" "$out"; then
      # write to a dot-file first so Traefik's watcher never sees a partial file
      install -m 0644 "$tmp" "$DYN_DIR/.$name.yml.tmp" && mv "$DYN_DIR/.$name.yml.tmp" "$out"
      echo "enabled route $host -> $GW:$port"
    fi
    rm -f "$tmp"
  else
    echo "pending DNS: $host (1.1.1.1='$a1', 8.8.8.8='$a2', want $PUBLIC_IP)"
  fi
done
exit 0
