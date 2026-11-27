#!/usr/bin/env bash
# =============================================================================
# status.sh — foto de todo el flujo, en el mismo orden en que viaja la petición
# =============================================================================
source "$(dirname "$0")/lib.sh"
set +e

step "[hub] Claims → XR → recursos gestionados (Crossplane)"
khub get webapp -A
khub get xwebapp
khub get object.kubernetes.crossplane.io

step "[hub] API v2: XR namespaced → recursos (sin claim)"
khub get webappv2 -A
khub get object.kubernetes.m.crossplane.io -A

step "[hub] Gateway API"
khub get gatewayclass
khub get gateway -A
khub get httproute -A

step "[hub] Submariner: lo importado desde remote"
khub get serviceimport -A
khub get endpointslices -A -l endpointslice.kubernetes.io/managed-by=lighthouse-agent.submariner.io

step "[remote] Cargas reales y exports"
# Un bloque por cada namespace que tenga claims o XRs v2.
for ns in $(khub get webapp,webappv2 -A -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u); do
  info "namespace ${ns}:"
  kremote -n "$ns" get deploy,svc,pods,serviceexport
done
