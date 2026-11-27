#!/usr/bin/env bash
# =============================================================================
# down.sh — destruye el laboratorio
# Borra los dos clústeres, el kubeconfig del lab y los artefactos (incluido
# broker-info.subm, que contiene secretos). Conserva ./.bin para no
# re-descargar; `PURGE=1 task down` también lo elimina.
# =============================================================================
source "$(dirname "$0")/lib.sh"

command -v kind >/dev/null || die "No hay kind en .bin ni en el sistema (ejecuta: task tools)"
for cluster in "${HUB_CLUSTER}" "${REMOTE_CLUSTER}"; do
  step "Borrando clúster '${cluster}'"
  kind delete cluster --name "${cluster}" --kubeconfig "${KUBECONFIG}"
done
rm -rf "${ROOT_DIR}/out" "${ROOT_DIR}/.kube"
[[ "${PURGE:-0}" == 1 ]] && rm -rf "${BIN_DIR}"
ok "Laboratorio destruido"
