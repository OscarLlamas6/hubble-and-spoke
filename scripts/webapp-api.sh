#!/usr/bin/env bash
# =============================================================================
# webapp-api.sh — FASE 4: publica la API `WebApp` (XRD + Composition) en hub
# =============================================================================
source "$(dirname "$0")/lib.sh"
CP="${ROOT_DIR}/crossplane"

step "XRD: crea los CRDs XWebApp y WebApp"
khub apply -f "${CP}/xrd-webapp.yaml"
khub wait --for=condition=Established --for=condition=Offered \
  compositeresourcedefinition/xwebapps.platform.lab.local --timeout=120s 2>/dev/null ||
  { khub wait --for=condition=Established compositeresourcedefinition/xwebapps.platform.lab.local --timeout=120s
    khub wait --for=condition=Offered compositeresourcedefinition/xwebapps.platform.lab.local --timeout=120s; }

step "Composition: cómo se construye un WebApp"
khub apply -f "${CP}/composition-webapp.yaml"
ok "API lista: kubectl explain webapp.spec"
