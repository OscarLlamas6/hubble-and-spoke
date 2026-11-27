#!/usr/bin/env bash
# =============================================================================
# example.sh — FASE 6: aplica (o borra) un claim WebApp y espera a que esté Ready
#   ./scripts/example.sh apply  [archivo]
#   ./scripts/example.sh delete [archivo]
# =============================================================================
source "$(dirname "$0")/lib.sh"

action=${1:-apply}
file=${2:-${ROOT_DIR}/crossplane/examples/webapp-claim.yaml}
[[ -f "$file" ]] || die "No existe el archivo: $file"

# Nombre y namespace del WebApp contenido en el archivo.
read -r name ns < <(khub create --dry-run=client -f "$file" -o json |
  jq -rs 'map(.items? // [.]) | add | map(select(.kind == "WebApp"))[0].metadata | "\(.name) \(.namespace)"')

case "$action" in
  apply)
    step "Aplicando el claim ${ns}/${name}"
    khub apply -f "$file"
    step "Esperando Ready (todos los recursos compuestos en ambos clústeres)"
    if ! khub -n "$ns" wait --for=condition=Ready "webapp/${name}" --timeout=300s; then
      "${ROOT_DIR}/scripts/status.sh" || true
      die "El claim no llegó a Ready (ver docs/troubleshooting.md)"
    fi
    khub -n "$ns" get "webapp/${name}"
    ;;
  delete)
    step "Borrando el claim ${ns}/${name}"
    # Solo el claim: el Namespace del archivo puede tener otros claims.
    khub -n "$ns" delete "webapp/${name}" --ignore-not-found --wait=true --timeout=180s
    ;;
  *) die "Acción desconocida: $action (apply|delete)" ;;
esac
