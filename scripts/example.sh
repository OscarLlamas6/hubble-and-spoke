#!/usr/bin/env bash
# =============================================================================
# example.sh — FASE 6: aplica (o borra) un WebApp (claim v1) o un WebAppV2
#              (XR v2) y espera a que esté Ready
#   ./scripts/example.sh apply  [archivo]
#   ./scripts/example.sh delete [archivo]
# =============================================================================
source "$(dirname "$0")/lib.sh"

action=${1:-apply}
file=${2:-${ROOT_DIR}/crossplane/examples/webapp-claim.yaml}
[[ -f "$file" ]] || die "No existe el archivo: $file"

# Tipo, nombre y namespace del recurso contenido en el archivo.
read -r kind name ns < <(khub create --dry-run=client -f "$file" -o json |
  jq -rs 'map(.items? // [.]) | add | map(select(.kind == "WebApp" or .kind == "WebAppV2"))[0] | "\(.kind | ascii_downcase) \(.metadata.name) \(.metadata.namespace)"')

case "$action" in
  apply)
    step "Aplicando ${kind} ${ns}/${name}"
    khub apply -f "$file"
    step "Esperando Ready (todos los recursos compuestos en ambos clústeres)"
    if ! khub -n "$ns" wait --for=condition=Ready "${kind}/${name}" --timeout=300s; then
      "${ROOT_DIR}/scripts/status.sh" || true
      die "${kind} no llegó a Ready (ver docs/troubleshooting.md)"
    fi
    khub -n "$ns" get "${kind}/${name}"
    ;;
  delete)
    step "Borrando ${kind} ${ns}/${name}"
    # Solo el recurso: el Namespace del archivo puede tener otros.
    khub -n "$ns" delete "${kind}/${name}" --ignore-not-found --wait=true --timeout=180s
    ;;
  *) die "Acción desconocida: $action (apply|delete)" ;;
esac
