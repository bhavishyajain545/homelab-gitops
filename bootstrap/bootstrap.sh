#!/usr/bin/env bash
# One-shot, idempotent bootstrap: host prep -> k3s -> Argo CD -> Traefik route.
set -euo pipefail
cd "$(dirname "$0")"
for step in 00-host.sh 10-k3s.sh 20-argocd.sh 30-traefik.sh; do
  echo; echo "########## $step"; bash "./$step"
done
