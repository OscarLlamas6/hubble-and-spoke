#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh — prueba de punta a punta
# -----------------------------------------------------------------------------
#   curl (tu máquina) → Envoy (hub) → túnel Submariner → Service → pod (remote)
#
# No basta con un 200: comprobamos que quien responde es un pod que EXISTE en el
# clúster remote, para demostrar que la petición realmente cruzó de clúster.
#
# Variables: HOST (webapp.local), APP (webapp), NS (demo),
#            URL (http://localhost:8080/), REQUESTS (10)
# =============================================================================
source "$(dirname "$0")/lib.sh"

HOST=${HOST:-webapp.local}
APP=${APP:-webapp}
NS=${NS:-demo}
URL=${URL:-http://localhost:8080/}
REQUESTS=${REQUESTS:-10}

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

request() { curl -sS -o "$body_file" -w '%{http_code}' --max-time 5 -H "Host: ${HOST}" "$URL"; }
is_200() { [[ "$(request)" == 200 ]]; }

step "1. GET ${URL}  (Host: ${HOST})"
retry 30 2 is_200 || die "No se obtuvo HTTP 200 (último código: $(request || true)). Ver docs/troubleshooting.md"
ok "HTTP 200"
sed 's/^/    /' "$body_file"

step "2. ¿Respondió un pod del clúster remote?"
remote_pods=$(kremote -n "$NS" get pods -l "app.kubernetes.io/name=${APP}" -o jsonpath='{.items[*].metadata.name}')
[[ -n "$remote_pods" ]] || die "No hay pods de ${APP} en remote"
pod=$(awk '/^Hostname:/ {print $2}' "$body_file")
grep -qw -- "$pod" <<<"$remote_pods" || die "'${pod}' no es un pod de remote (${remote_pods})"
ok "Contestó '${pod}', que corre en remote"
if khub -n "$NS" get deployment "$APP" >/dev/null 2>&1; then
  die "Existe un Deployment '${APP}' en hub; no debería"
fi
ok "En hub no existe ningún Deployment '${APP}'"

step "3. ${REQUESTS} peticiones seguidas (reparto entre réplicas)"
declare -A hits=()
for ((i = 0; i < REQUESTS; i++)); do
  [[ "$(request)" == 200 ]] || die "La petición $((i + 1)) falló"
  p=$(awk '/^Hostname:/ {print $2}' "$body_file")
  hits[$p]=$((${hits[$p]:-0} + 1))
done
for p in "${!hits[@]}"; do info "$p → ${hits[$p]}"; done
ok "Smoke test superado"
