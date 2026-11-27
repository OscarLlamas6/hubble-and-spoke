# shellcheck shell=bash
# =============================================================================
# env.sh — para TU terminal interactiva (bash o zsh):
#
#     source scripts/env.sh
#
# Después, `kubectl`, `kind`, `subctl`, `helm` y `crossplane` son las versiones
# fijadas del lab y apuntan SOLO a los clústeres del lab. Cierra la terminal
# para volver a tu entorno normal.
# =============================================================================
_lab_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export PATH="${_lab_root}/.bin:${PATH}"
export KUBECONFIG="${_lab_root}/.kube/config"
alias khub='kubectl --context kind-hub'
alias kremote='kubectl --context kind-remote'
unset _lab_root
echo "Entorno del lab activo (KUBECONFIG=${KUBECONFIG}). Alias: khub, kremote"
