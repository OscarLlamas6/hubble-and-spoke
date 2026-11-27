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

step "[hub] Gateway API"
khub get gatewayclass
khub get gateway -A
khub get httproute -A

step "[hub] Submariner: lo importado desde remote"
khub get serviceimport -A
khub get endpointslices -A -l endpointslice.kubernetes.io/managed-by=lighthouse-agent.submariner.io

step "[remote] Cargas reales y exports"
# Un bloque por cada namespace que tenga claims.
for ns in $(khub get webapp -A -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u); do
  info "namespace ${ns}:"
  kremote -n "$ns" get deploy,svc,pods,serviceexport
done
