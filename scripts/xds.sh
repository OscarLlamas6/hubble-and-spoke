#!/usr/bin/env bash
# =============================================================================
# xds.sh — muestra la configuración EFECTIVA del proxy Envoy (FASE 5)
# -----------------------------------------------------------------------------
#   task xds             resumen LDS / RDS / CDS / EDS + versiones
#   task xds -- raw      además deja el config_dump completo en out/
#
# La admin API de Envoy escucha solo en 127.0.0.1:19000 DENTRO del pod, por eso
# hace falta port-forward. Explicación: docs/concepts/09-envoy-xds.md
# =============================================================================
source "$(dirname "$0")/lib.sh"

PORT=${PORT:-19000}
OUT="${ROOT_DIR}/out/config_dump.json"
mkdir -p "$(dirname "$OUT")"

pod=$(khub -n envoy-gateway-system get pod \
  -l gateway.envoyproxy.io/owning-gateway-name=hub-gateway \
  -o jsonpath='{.items[0].metadata.name}')
[[ -n "$pod" ]] || die "No encuentro el pod de Envoy (¿ejecutaste task gateway?)"

# kubectl directo (no la función khub): con una función, $! sería el PID de una
# subshell y al matarla el port-forward quedaría huérfano ocupando el puerto.
kubectl --context "${HUB_CTX}" -n envoy-gateway-system port-forward "$pod" "${PORT}:19000" >/dev/null &
pf=$!
trap 'kill $pf 2>/dev/null || true' EXIT
admin_ready() { kill -0 "$pf" 2>/dev/null && curl -fs "http://127.0.0.1:${PORT}/ready"; }
retry 20 1 admin_ready || die "No pude abrir la admin API en :${PORT} (¿puerto ocupado? prueba PORT=19100)"

# include_eds: sin este parámetro el dump NO trae los endpoints.
curl -fs "http://127.0.0.1:${PORT}/config_dump?include_eds" >"$OUT"

# q <sufijo del @type> <filtro jq>
q() { jq -r ".configs[] | select(.\"@type\" | endswith(\"$1\")) | $2" "$OUT"; }

step "Pod: ${pod}"

step "BOOTSTRAP (estático): solo sabe cómo hablar con el control plane"
q BootstrapConfigDump '.bootstrap | "ADS api_type: \(.dynamic_resources.ads_config.api_type)\nclusters estáticos: \([.static_resources.clusters[].name] | join(", "))"'

step "LDS — Listeners   ← Gateway.spec.listeners"
q ListenersConfigDump '.dynamic_listeners[] | .active_state as $s | "\(.name)  puerto=\($s.listener.address.socket_address.port_value)  version=\($s.version_info[0:12])"'

step "RDS — Routes      ← HTTPRoute"
q RoutesConfigDump '.dynamic_route_configs[]? | .version_info as $v | .route_config | "config=\(.name)  version=\($v[0:12])", (.virtual_hosts[]? | "  dominios=\(.domains | join(",")) → " + ([.routes[] | "\(.match.prefix // .match.path) ⇒ \(.route.cluster)"] | join("; ")))'

step "CDS — Clusters    ← backendRefs"
q ClustersConfigDump '.dynamic_active_clusters[]? | "\(.cluster.name)  type=\(.cluster.type)  version=\(.version_info[0:12])"'

step "EDS — Endpoints   ← EndpointSlices del ServiceImport (ClusterIP de remote)"
q EndpointsConfigDump '.dynamic_endpoint_configs[]? | .endpoint_config | "\(.cluster_name) → " + ([.endpoints[]?.lb_endpoints[]?.endpoint.address.socket_address | "\(.address):\(.port_value)"] | join(", "))'

step "SDS — Secrets (certificados)"
q SecretsConfigDump '(.dynamic_active_secrets // []) | if length == 0 then "ninguno recibido por SDS (el lab no usa TLS en listeners)" else (.[] | .name) end'

if [[ "${1:-}" == raw ]]; then
  info ""; ok "config_dump completo: ${OUT}"
fi
