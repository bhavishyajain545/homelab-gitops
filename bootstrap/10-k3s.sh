#!/usr/bin/env bash
# Installs (or reconfigures) k3s, kubectl and helm. Idempotent.
source "$(dirname "$0")/common.sh"
need_root

GW="$(proxy_gateway)"
[[ -n "$GW" ]] || die "could not determine the gateway of docker network '$DOCKER_PROXY_NET'"
log "NodePorts will only listen on ${GW} (docker '${DOCKER_PROXY_NET}' gateway)"

mkdir -p /etc/rancher/k3s
sed -e "s#__NODE_IP__#${NODE_IP}#g" -e "s#__NODEPORT_CIDR__#${GW}/32#g" \
  "$REPO_ROOT/host/k3s-config.yaml" > /etc/rancher/k3s/config.yaml.new
if ! cmp -s /etc/rancher/k3s/config.yaml.new /etc/rancher/k3s/config.yaml 2>/dev/null; then
  mv /etc/rancher/k3s/config.yaml.new /etc/rancher/k3s/config.yaml
  CONFIG_CHANGED=1
else
  rm -f /etc/rancher/k3s/config.yaml.new
fi

if ! command -v k3s >/dev/null || [[ "$(k3s --version | awk 'NR==1{print $3}')" != "$K3S_VERSION" ]]; then
  log "Installing k3s ${K3S_VERSION}"
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server
elif [[ "${CONFIG_CHANGED:-0}" == 1 ]]; then
  log "k3s config changed, restarting"
  systemctl restart k3s
fi
# k3s.service must start after the private interface + guard exist
mkdir -p /etc/systemd/system/k3s.service.d
printf '[Unit]\nAfter=homelab-net.service homelab-guard.service\nRequires=homelab-net.service\n' \
  > /etc/systemd/system/k3s.service.d/10-homelab.conf
systemctl daemon-reload

# kubeconfig: k3s writes 127.0.0.1, but the API only binds the private IP
sed -i "s#https://127.0.0.1:6443#https://${NODE_IP}:6443#" /etc/rancher/k3s/k3s.yaml
chmod 600 /etc/rancher/k3s/k3s.yaml
mkdir -p /root/.kube && ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config

log "Waiting for node Ready"
for _ in $(seq 60); do kubectl get nodes 2>/dev/null | grep -q ' Ready' && break; sleep 5; done
kubectl get nodes -o wide

if ! command -v helm >/dev/null || ! helm version --short | grep -q "${HELM_VERSION}"; then
  log "Installing helm ${HELM_VERSION}"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \
    | DESIRED_VERSION="$HELM_VERSION" bash
fi
