#!/usr/bin/env bash
# =============================================================================
# lib.sh — funciones y variables compartidas por TODOS los scripts del lab
# -----------------------------------------------------------------------------
# Cada script hace `source "$(dirname "$0")/lib.sh"` y con eso obtiene:
#   * modo estricto de bash
#   * las versiones de versions.env
#   * un PATH que prioriza las herramientas fijadas en ./.bin
#   * un KUBECONFIG PROPIO del repo (.kube/config)
#
# El KUBECONFIG propio es una medida de seguridad deliberada: el lab jamás lee
# ni modifica ~/.kube/config, así que es imposible que un comando de aquí
# termine ejecutándose contra un clúster real.
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

set -a
# shellcheck source=../versions.env
source "${ROOT_DIR}/versions.env"
set +a

export BIN_DIR="${ROOT_DIR}/.bin"
export PATH="${BIN_DIR}:${PATH}"
export KUBECONFIG="${ROOT_DIR}/.kube/config"

# Nombres de clúster. kind antepone "kind-" al nombre del contexto.
export HUB_CLUSTER=hub
export REMOTE_CLUSTER=remote
export HUB_CTX="kind-${HUB_CLUSTER}"
export REMOTE_CTX="kind-${REMOTE_CLUSTER}"

# Salida con color solo si es una terminal.
if [[ -t 1 ]]; then
  C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_OFF=$'\033[0m'
else
  C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_OFF=''
fi

step() { printf '\n%s==> %s%s\n' "$C_BLUE" "$*" "$C_OFF"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '%s ✔  %s%s\n' "$C_GREEN" "$*" "$C_OFF"; }
warn() { printf '%s !  %s%s\n' "$C_YELLOW" "$*" "$C_OFF" >&2; }
die()  { printf '%s ✘  %s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }

# Atajos con contexto SIEMPRE explícito (nunca dependemos del "current-context").
khub()    { kubectl --context "${HUB_CTX}" "$@"; }
kremote() { kubectl --context "${REMOTE_CTX}" "$@"; }

# retry <intentos> <pausa_seg> <comando...>
# Reintenta hasta que el comando salga con 0. La reconciliación en Kubernetes es
# asíncrona: casi nada está listo en el instante en que se aplica.
retry() {
  local attempts=$1 delay=$2 i
  shift 2
  for ((i = 1; i <= attempts; i++)); do
    "$@" >/dev/null 2>&1 && return 0
    sleep "$delay"
  done
  return 1
}

# IP de un nodo kind en la red Docker "kind" (la que ven los otros clústeres).
node_ip() {
  docker inspect -f '{{(index .NetworkSettings.Networks "kind").IPAddress}}' "$1"
}
