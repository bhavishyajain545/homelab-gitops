#!/usr/bin/env bash
# Host preparation: private interface for k3s + public-interface port guard.
source "$(dirname "$0")/common.sh"
need_root

log "Installing homelab-net (dummy interface k3s0 -> ${NODE_IP})"
install -m 0755 "$REPO_ROOT/host/homelab-net.sh"   /usr/local/sbin/homelab-net.sh
install -m 0755 "$REPO_ROOT/host/homelab-guard.sh" /usr/local/sbin/homelab-guard.sh
install -m 0644 "$REPO_ROOT/host/systemd/homelab-net.service"   /etc/systemd/system/
install -m 0644 "$REPO_ROOT/host/systemd/homelab-guard.service" /etc/systemd/system/
mkdir -p /etc/systemd/system/homelab-net.service.d
printf '[Service]\nEnvironment=NODE_IP=%s\n' "$NODE_IP" > /etc/systemd/system/homelab-net.service.d/env.conf

systemctl daemon-reload
systemctl enable --now homelab-net.service
log "Installing homelab-guard (raw-table drop of k8s ports on the public NIC)"
systemctl enable homelab-guard.service
systemctl restart homelab-guard.service

install -d -m 0700 "$SECRETS_DIR"
ip -br addr show k3s0
