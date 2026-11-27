#!/usr/bin/env bash
# =============================================================================
# submariner.sh — FASE 2: conecta "hub" y "remote" con Submariner
# -----------------------------------------------------------------------------
# Pasos (explicados a fondo en submariner/README.md):
#   1. deploy-broker en hub  → CRDs + ServiceAccount que actúan de "tablón de
#                              anuncios" donde los clústeres publican endpoints.
#   2. label del gateway node → qué nodo termina el túnel.
#   3. join de cada clúster   → instala operator, gateway, route-agent y
#                              Lighthouse (DNS multi-clúster).
#   4. espera a que el túnel esté "connected".
# Idempotente: se puede re-ejecutar.
# =============================================================================
source "$(dirname "$0")/lib.sh"

OUT_DIR="${ROOT_DIR}/out"
BROKER_INFO="${OUT_DIR}/broker-info.subm"
mkdir -p "${OUT_DIR}"

# La URL del API server del broker debe ser alcanzable DESDE LOS PODS de remote.
# El kubeconfig del host usa https://127.0.0.1:<puerto>, que dentro de un pod
# apuntaría al propio pod. Usamos la IP del nodo hub en la red Docker "kind".
BROKER_URL="https://$(node_ip "${HUB_CLUSTER}-control-plane"):6443"

step "Broker en ${HUB_CLUSTER} (URL anunciada: ${BROKER_URL})"
if khub get namespace submariner-k8s-broker >/dev/null 2>&1 && [[ -f "${BROKER_INFO}" ]]; then
  ok "el broker ya está desplegado"
else
  # subctl escribe broker-info.subm en el directorio actual.
  (cd "${OUT_DIR}" && subctl deploy-broker \
    --context "${HUB_CTX}" \
    --broker-url "${BROKER_URL}" \
    --components service-discovery,connectivity \
    --version "${SUBMARINER_VERSION}")
fi

# join <contexto> <cluster-id> <podCIDR> <serviceCIDR>
join() {
  local ctx=$1 id=$2 pod_cidr=$3 svc_cidr=$4
  step "Join de '${id}' al broker"
  kubectl --context "$ctx" label node "${id}-control-plane" submariner.io/gateway=true --overwrite

  if kubectl --context "$ctx" -n submariner-operator get daemonset submariner-gateway >/dev/null 2>&1; then
    ok "'${id}' ya está unido"
    return
  fi

  # --natt=false          : los nodos se ven directamente en la red Docker, no hay NAT.
  # --cable-driver        : libreswan = túnel IPsec (cifrado). Es el default.
  # --clustercidr/--service-cidr : explícitos para no depender del autodescubrimiento.
  subctl join "${BROKER_INFO}" \
    --context "$ctx" \
    --clusterid "$id" \
    --natt=false \
    --cable-driver libreswan \
    --clustercidr "$pod_cidr" \
    --servicecidr "$svc_cidr" \
    --check-broker-certificate=true \
    --version "${SUBMARINER_VERSION}"
}

join "${HUB_CTX}"    "${HUB_CLUSTER}"    10.10.0.0/16 10.110.0.0/16
join "${REMOTE_CTX}" "${REMOTE_CLUSTER}" 10.20.0.0/16 10.120.0.0/16

step "Esperando a los componentes de Submariner"
for ctx in "${HUB_CTX}" "${REMOTE_CTX}"; do
  for ds in submariner-gateway submariner-routeagent; do
    retry 60 5 kubectl --context "$ctx" -n submariner-operator get daemonset "$ds" ||
      die "$ctx: no apareció el DaemonSet $ds"
    kubectl --context "$ctx" -n submariner-operator rollout status daemonset "$ds" --timeout=300s
  done
  for dp in submariner-lighthouse-agent submariner-lighthouse-coredns; do
    retry 60 5 kubectl --context "$ctx" -n submariner-operator get deployment "$dp" ||
      die "$ctx: no apareció el Deployment $dp"
    kubectl --context "$ctx" -n submariner-operator rollout status deployment "$dp" --timeout=300s
  done
done

step "Esperando el túnel entre gateways"
connected() {
  [[ "$(kubectl --context "$1" -n submariner-operator get gateways.submariner.io \
        -o jsonpath='{.items[0].status.connections[0].status}')" == "connected" ]]
}
for ctx in "${HUB_CTX}" "${REMOTE_CTX}"; do
  retry 60 5 connected "$ctx" || { subctl show all --context "$ctx" || true; die "$ctx: el túnel no conectó (ver docs/troubleshooting.md)"; }
  ok "$ctx: connected"
done

subctl show connections --context "${HUB_CTX}"
