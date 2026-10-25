# shellcheck shell=bash
# Shared settings for the bootstrap scripts. Every version is pinned here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

K3S_VERSION="${K3S_VERSION:-v1.36.5+k3s1}"
HELM_VERSION="${HELM_VERSION:-v4.3.1}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.11.1}"   # keep in sync with apps/argocd.yaml

NODE_IP="${NODE_IP:-10.240.0.1}"                 # private dummy interface k3s0
DOCKER_PROXY_NET="${DOCKER_PROXY_NET:-proxy}"   # network the Docker Traefik lives on
TRAEFIK_DIR="${TRAEFIK_DIR:-/opt/apps/traefik}"
SECRETS_DIR="${SECRETS_DIR:-/root/homelab-secrets}"

ARGOCD_NODEPORT=30080
GRAFANA_NODEPORT=30300

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || die "run as root"; }

proxy_gateway() {
  docker network inspect "$DOCKER_PROXY_NET" -f '{{(index .IPAM.Config 0).Gateway}}'
}

rand_password() { python3 -c 'import secrets; print(secrets.token_urlsafe(24))'; }
