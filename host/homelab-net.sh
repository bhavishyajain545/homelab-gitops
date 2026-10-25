#!/usr/bin/env bash
# Creates the private dummy interface k3s binds to. Idempotent.
set -euo pipefail
NODE_IP="${NODE_IP:-10.240.0.1}"
ip link show k3s0 >/dev/null 2>&1 || ip link add k3s0 type dummy
ip addr replace "${NODE_IP}/32" dev k3s0
ip link set k3s0 up
