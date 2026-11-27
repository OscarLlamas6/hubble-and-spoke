#!/usr/bin/env bash
# =============================================================================
# submariner-verify.sh — prueba que un pod en hub alcanza un Service de remote
#   ./scripts/submariner-verify.sh          # prueba y limpia
#   KEEP=1 ./scripts/submariner-verify.sh   # deja los recursos para explorar
# =============================================================================
source "$(dirname "$0")/lib.sh"

NS=sm-test
cleanup() {
  [[ "${KEEP:-0}" == 1 ]] && { warn "KEEP=1: se conserva el namespace ${NS} en ambos clústeres"; return; }
  khub delete namespace "$NS" --ignore-not-found --wait=false >/dev/null
  kremote delete namespace "$NS" --ignore-not-found --wait=false >/dev/null
}
trap cleanup EXIT

step "Desplegando whoami exportado en ${REMOTE_CLUSTER}"
for ctx in "${HUB_CTX}" "${REMOTE_CTX}"; do
  # Si una ejecución anterior lo está borrando, esperamos a que termine.
  if [[ "$(kubectl --context "$ctx" get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" == Terminating ]]; then
    kubectl --context "$ctx" wait --for=delete "namespace/$NS" --timeout=180s
  fi
  kubectl --context "$ctx" create namespace "$NS" --dry-run=client -o yaml | kubectl --context "$ctx" apply -f -
done
kremote apply -f "${ROOT_DIR}/submariner/connectivity-test.yaml"
kremote -n "$NS" rollout status deployment/whoami --timeout=180s

step "Esperando el ServiceImport en ${HUB_CLUSTER}"
retry 30 2 khub -n "$NS" get serviceimport whoami || die "No apareció el ServiceImport (ver docs/troubleshooting.md)"
khub -n "$NS" get serviceimport whoami
khub -n "$NS" get endpointslices -l multicluster.kubernetes.io/service-name=whoami

step "curl desde un pod de ${HUB_CLUSTER} a whoami.${NS}.svc.clusterset.local"
khub -n "$NS" delete pod curl --ignore-not-found --wait=true >/dev/null
khub -n "$NS" run curl --image=curlimages/curl:8.17.0 --restart=Never --command -- sleep 300 >/dev/null
khub -n "$NS" wait --for=condition=Ready pod/curl --timeout=180s >/dev/null
# Justo después del join, CoreDNS está recargando la zona clusterset.local y una
# resolución aislada puede fallar. Por eso exigimos 5 éxitos CONSECUTIVOS.
five_in_a_row() {
  khub -n "$NS" exec curl -- sh -c \
    "for i in 1 2 3 4 5; do curl -fsS -o /dev/null --max-time 5 http://whoami.${NS}.svc.clusterset.local/ || exit 1; sleep 1; done"
}
retry 30 2 five_in_a_row || die "El pod no pudo llamar de forma estable al servicio remoto"
khub -n "$NS" exec curl -- curl -fsS --max-time 5 "http://whoami.${NS}.svc.clusterset.local/"
ok "Conectividad cross-cluster + DNS clusterset verificados"
