#!/usr/bin/env bash
# =============================================================================
# unit-test.sh — tests de las Compositions con xprin (SIN clúster, solo Docker)
#   task test:unit                    todos los suites
#   task test:unit -- tests/v2        solo un directorio o archivo
#   task test:unit:update-goldens     regenera las salidas de referencia
# =============================================================================
source "$(dirname "$0")/lib.sh"

CACHE="${ROOT_DIR}/tests/.cache"
mkdir -p "${CACHE}"

step "Preparando entradas derivadas (siempre desde los archivos reales del lab)"
# (1) El Claim del ejemplo real, sin el documento Namespace que lo acompaña.
yq 'select(.kind == "WebApp")' "${ROOT_DIR}/crossplane/examples/webapp-claim.yaml" >"${CACHE}/claim.yaml"
# (2) Solo el objeto Provider: validate descarga el paquete y usa sus CRDs
#     para validar los `Object` renderizados.
yq 'select(.kind == "Provider")' "${ROOT_DIR}/crossplane/provider-kubernetes.yaml" >"${CACHE}/provider.yaml"
# (3) CRD de HTTPRoute, la misma versión que instala Envoy Gateway.
crd="${CACHE}/httproute-${GATEWAY_API_VERSION}.yaml"
[[ -s "$crd" ]] || curl -fsSL --retry 3 -o "$crd" \
  "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/experimental/gateway.networking.k8s.io_httproutes.yaml"
cp "$crd" "${CACHE}/httproute-crd.yaml"
# (4) Config de xprin: render con la MISMA versión de Crossplane del clúster.
# Caché de paquetes/schemas dentro del repo, no en tu HOME.
export CROSSPLANE_XPKG_CACHE="${CACHE}/xpkg"
cat >"${CACHE}/xprin-config.yaml" <<CFG
dependencies:
  crossplane: ${BIN_DIR}/crossplane
subcommands:
  render: composition render --include-full-xr
  validate: resource validate --error-on-missing-schemas --cache-dir=${CROSSPLANE_XPKG_CACHE}
CFG
ok "listo"

command=${XPRIN_COMMAND:-test}
targets=("$@")
((${#targets[@]})) || targets=("${ROOT_DIR}/tests/v1/webapp_xprin.yaml" "${ROOT_DIR}/tests/v2/webappv2_xprin.yaml")

# --crossplane-version : la misma versión del clúster, en render y en validate.
# --no-container-reuse : por defecto xprin reutiliza los contenedores de las
#   functions en una red Docker propia; en la máquina donde se construyó el lab
#   esa red hacía que el render se colgara hasta el timeout.
args=(--crossplane-version="v${CROSSPLANE_VERSION}" --no-container-reuse)
[[ "$command" == test ]] && args+=(--verbose --show-assertions --show-hooks)
cd "${ROOT_DIR}"
xprin -c "${CACHE}/xprin-config.yaml" "$command" "${targets[@]}" "${args[@]}"

[[ "$command" == test && $# -eq 0 ]] || exit 0

# ---------------------------------------------------------------------------
# Casos NEGATIVOS: entradas que el schema del XRD debe rechazar. Se hacen aquí
# porque la versión publicada de xprin (v0.7.0) no permite esperar un fallo.
# ---------------------------------------------------------------------------
step "Casos negativos (deben ser rechazados por el XRD)"
# must_reject <xrd> <archivo> <texto que debe aparecer en el error>
must_reject() {
  local out
  if out=$(crossplane resource validate "$1" "$2" --cache-dir="${CROSSPLANE_XPKG_CACHE}" \
    --crossplane-image="xpkg.crossplane.io/crossplane/crossplane:v${CROSSPLANE_VERSION}" 2>&1); then
    die "$2 fue aceptado y debía rechazarse"
  fi
  grep -q -- "$3" <<<"$out" || { echo "$out"; die "$2 falló, pero no por '$3'"; }
  ok "$2 rechazado por $3"
}
# El claim se convierte a XR igual que hace xprin, y se valida el XR.
xprin-helpers convert-claim-to-xr tests/v1/claim-invalid.yaml >"${CACHE}/xr-invalid-v1.yaml"
must_reject crossplane/xrd-webapp.yaml "${CACHE}/xr-invalid-v1.yaml" "spec.replicas"
must_reject crossplane/v2/xrd-webappv2.yaml tests/v2/xr-invalid.yaml "spec.image"
