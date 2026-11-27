#!/usr/bin/env bash
# render.sh — ejecuta el pipeline de la Composition EN LOCAL (solo necesita Docker)
source "$(dirname "$0")/lib.sh"
cd "${ROOT_DIR}/crossplane"
exec crossplane composition render render/xr.yaml composition-webapp.yaml functions.yaml \
  --crossplane-version="v${CROSSPLANE_VERSION}" --include-function-results "$@"
