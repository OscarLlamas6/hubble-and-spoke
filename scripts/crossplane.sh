#!/usr/bin/env bash
# =============================================================================
# crossplane.sh — FASE 3: Crossplane + provider-kubernetes + ProviderConfigs
# =============================================================================
source "$(dirname "$0")/lib.sh"
CP="${ROOT_DIR}/crossplane"

step "Instalando Crossplane ${CROSSPLANE_VERSION} en ${HUB_CLUSTER} (Helm)"
# URL directa del chart: si usáramos el nombre "crossplane", Helm lo confundiría
# con la carpeta ./crossplane de este repo.
helm upgrade --install crossplane \
  "https://charts.crossplane.io/stable/crossplane-${CROSSPLANE_VERSION}.tgz" \
  --kube-context "${HUB_CTX}" \
  --namespace crossplane-system --create-namespace \
  --wait --timeout 5m

step "Instalando provider-kubernetes y las Composition Functions"
retry 30 2 khub get crd providers.pkg.crossplane.io deploymentruntimeconfigs.pkg.crossplane.io functions.pkg.crossplane.io ||
  die "Los CRDs de paquetes de Crossplane no aparecieron"
khub apply -f "${CP}/provider-kubernetes.yaml" -f "${CP}/functions.yaml"
khub wait --for=condition=Healthy provider.pkg.crossplane.io --all --timeout=300s
khub wait --for=condition=Healthy function.pkg.crossplane.io --all --timeout=300s

step "Secret con el kubeconfig interno de ${REMOTE_CLUSTER}"
# El kubeconfig se canaliza directo al Secret: nunca se escribe en disco.
kind get kubeconfig --name "${REMOTE_CLUSTER}" --internal |
  khub -n crossplane-system create secret generic remote-kubeconfig \
    --from-file=kubeconfig=/dev/stdin --dry-run=client -o yaml |
  khub apply -f -

step "ProviderConfigs"
retry 30 2 khub get crd providerconfigs.kubernetes.crossplane.io || die "Falta el CRD ProviderConfig"
khub wait --for=condition=Established crd/providerconfigs.kubernetes.crossplane.io crd/objects.kubernetes.crossplane.io --timeout=120s
khub apply -f "${CP}/providerconfig-remote.yaml" -f "${CP}/providerconfig-hub.yaml"
# Equivalente moderno (namespaced MRs), para la API v2.
khub wait --for=condition=Established crd/clusterproviderconfigs.kubernetes.m.crossplane.io crd/objects.kubernetes.m.crossplane.io --timeout=120s
khub apply -f "${CP}/v2/clusterproviderconfig-remote.yaml"

step "Prueba: crear un Namespace en ${REMOTE_CLUSTER} desde ${HUB_CLUSTER}"
khub apply -f "${CP}/smoke-namespace.yaml"
khub wait --for=condition=Ready object.kubernetes.crossplane.io/smoke-remote-namespace --timeout=120s
kremote get namespace crossplane-smoke-test
khub delete -f "${CP}/smoke-namespace.yaml" --wait=true
ok "Crossplane puede gestionar recursos en ${REMOTE_CLUSTER}"
