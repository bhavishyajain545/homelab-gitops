#!/usr/bin/env bash
# Defence in depth for a VPS that has no host firewall.
#
# Everything Kubernetes-related is already bound to private addresses
# (see host/k3s-config.yaml). This script adds a narrowly scoped safety net:
# packets arriving on the PUBLIC interface for Kubernetes ports are dropped in
# the raw table, before Docker's or kube-proxy's NAT rules ever see them.
#
# It only owns the chain HOMELAB-GUARD (raw table) plus a single jump rule in
# raw/PREROUTING. It never flushes or edits Docker / kube-proxy chains.
# Idempotent: safe to run on every boot (homelab-guard.service).
set -euo pipefail

PUBLIC_IF="${PUBLIC_IF:-$(ip -4 route show default | awk '{print $5; exit}')}"
CHAIN=HOMELAB-GUARD

# tcp: k8s API/supervisor, internal apiserver, etcd, kubelet & control-plane
#      metrics, node-exporter, NodePort range
TCP_PORTS=(6443 6444 2379:2380 10248:10260 9100 30000:32767)
# udp: flannel vxlan / wireguard backends (unused with host-gw, blocked anyway)
UDP_PORTS=(8472 51820:51821 30000:32767)

apply() {
  local ipt="$1"
  $ipt -w -t raw -N "$CHAIN" 2>/dev/null || true
  $ipt -w -t raw -F "$CHAIN"
  for p in "${TCP_PORTS[@]}"; do $ipt -w -t raw -A "$CHAIN" -p tcp --dport "$p" -j DROP; done
  for p in "${UDP_PORTS[@]}"; do $ipt -w -t raw -A "$CHAIN" -p udp --dport "$p" -j DROP; done
  $ipt -w -t raw -C PREROUTING -i "$PUBLIC_IF" -j "$CHAIN" 2>/dev/null \
    || $ipt -w -t raw -I PREROUTING 1 -i "$PUBLIC_IF" -j "$CHAIN"
}

apply iptables
command -v ip6tables >/dev/null && apply ip6tables
echo "homelab-guard: Kubernetes ports dropped on ${PUBLIC_IF}"
