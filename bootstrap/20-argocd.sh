#!/usr/bin/env bash
# Installs Argo CD once with Helm, then hands control to Git (app-of-apps).
# Idempotent: re-running upgrades to the pinned chart and re-applies the root app.
source "$(dirname "$0")/common.sh"
need_root

kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd

# argocd-secret is NOT managed by the chart (configs.secret.createSecret=false)
# so the admin password never touches Git. Random, stored root-only on the host.
PW_FILE="$SECRETS_DIR/argocd-admin.txt"
install -d -m 0700 "$SECRETS_DIR"
if ! kubectl -n argocd get secret argocd-secret >/dev/null 2>&1; then
  log "Creating argocd-secret with a random admin password"
  [[ -s "$PW_FILE" ]] || { umask 077; rand_password > "$PW_FILE"; }
  HASH="$(python3 -c 'import bcrypt,sys; print(bcrypt.hashpw(sys.stdin.read().strip().encode(), bcrypt.gensalt(10)).decode())' < "$PW_FILE")"
  kubectl -n argocd create secret generic argocd-secret \
    --from-literal=admin.password="$HASH" \
    --from-literal=admin.passwordMtime="$(date -u +%FT%TZ)" \
    --from-literal=server.secretkey="$(rand_password)"
  kubectl -n argocd label secret argocd-secret app.kubernetes.io/part-of=argocd
fi
chmod 600 "$PW_FILE"

log "Installing Argo CD chart ${ARGOCD_CHART_VERSION}"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd -n argocd \
  --version "$ARGOCD_CHART_VERSION" \
  -f "$REPO_ROOT/platform/argocd/values.yaml" \
  --wait --timeout 10m

log "Applying the root Application (app-of-apps)"
kubectl apply -f "$REPO_ROOT/bootstrap/root-app.yaml"
kubectl -n argocd get applications
