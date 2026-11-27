#!/usr/bin/env bash
# =============================================================================
# webapp-api.sh — FASE 4: publica en hub las DOS APIs (XRD + Composition)
#   WebApp    → modelo v1 con claims        (crossplane/)
#   WebAppV2  → modelo v2, XR namespaced    (crossplane/v2/)
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
step "API v2: RBAC, XRD y Composition"
khub apply -f "${CP}/v2/rbac-httproute.yaml" -f "${CP}/v2/xrd-webappv2.yaml"
khub wait --for=condition=Established compositeresourcedefinition/webappv2s.platform.lab.local --timeout=120s
khub apply -f "${CP}/v2/composition-webappv2.yaml"
ok "APIs listas: kubectl explain webapp.spec / webappv2.spec"
