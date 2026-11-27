#!/usr/bin/env bash
# =============================================================================
# render.sh — ejecuta el pipeline de una Composition EN LOCAL (solo Docker)
#   ./scripts/render.sh        API v1 (claims)
#   ./scripts/render.sh v2     API v2 (XR namespaced)
# Los argumentos extra se pasan a `crossplane composition render`.
# =============================================================================
source "$(dirname "$0")/lib.sh"
cd "${ROOT_DIR}/crossplane"

case "${1:-v1}" in
  v2) shift; xr=v2/render/xr.yaml; composition=v2/composition-webappv2.yaml; xrd=v2/xrd-webappv2.yaml ;;
  *)  [[ "${1:-}" == v1 ]] && shift; xr="render/xr.yaml"; composition="composition-webapp.yaml"; xrd="xrd-webapp.yaml" ;;
esac

# --xrd aplica los defaults del XRD y le dice al motor el scope correcto
# (sin él, un XR v1/LegacyCluster se renderiza como si fuera v2).
exec crossplane composition render "$xr" "$composition" functions.yaml --xrd="$xrd" \
  --crossplane-version="v${CROSSPLANE_VERSION}" --include-function-results "$@"
