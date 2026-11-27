#!/usr/bin/env bash
# =============================================================================
# gateway.sh — FASE 5: Gateway API + Envoy Gateway en hub
# =============================================================================
source "$(dirname "$0")/lib.sh"
GW="${ROOT_DIR}/gateway"

step "Instalando Envoy Gateway ${ENVOY_GATEWAY_VERSION} (incluye los CRDs de Gateway API)"
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_GATEWAY_VERSION}" \
  --kube-context "${HUB_CTX}" \
  --namespace envoy-gateway-system --create-namespace \
  --wait --timeout 5m

step "EnvoyProxy, GatewayClass y Gateway"
khub apply -f "${GW}/envoyproxy.yaml" -f "${GW}/gatewayclass.yaml" -f "${GW}/gateway.yaml"
khub wait --for=condition=Accepted gatewayclass/envoy --timeout=120s
khub -n gateway-system wait --for=condition=Programmed gateway/hub-gateway --timeout=300s

step "Data plane creado por Envoy Gateway"
khub -n envoy-gateway-system get deploy,svc -l gateway.envoyproxy.io/owning-gateway-name=hub-gateway
ok "Gateway accesible en http://localhost:8080 (responderá 404 hasta que haya rutas)"
