#!/usr/bin/env bash
# =============================================================================
# clusters.sh — FASE 1: crea los clústeres kind "hub" y "remote" (idempotente)
# =============================================================================
source "$(dirname "$0")/lib.sh"

mkdir -p "$(dirname "${KUBECONFIG}")"

for cluster in "${HUB_CLUSTER}" "${REMOTE_CLUSTER}"; do
  step "Clúster kind '${cluster}'"
  if kind get clusters 2>/dev/null | grep -qx "${cluster}"; then
    ok "ya existe"
    kind export kubeconfig --name "${cluster}" --kubeconfig "${KUBECONFIG}"
  else
    kind create cluster \
      --config "${ROOT_DIR}/clusters/kind-${cluster}.yaml" \
      --image "${KIND_NODE_IMAGE}" \
      --kubeconfig "${KUBECONFIG}" \
      --wait 120s
  fi
done

step "Nodos"
for ctx in "${HUB_CTX}" "${REMOTE_CTX}"; do
  kubectl --context "$ctx" wait --for=condition=Ready nodes --all --timeout=120s
  info "$ctx:"; kubectl --context "$ctx" get nodes -o wide
done
ok "Clústeres listos. Kubeconfig del lab: ${KUBECONFIG}"
