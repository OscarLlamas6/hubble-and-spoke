#!/usr/bin/env bash
# run.sh — ejecuta cualquier comando dentro del entorno del lab
#   ./scripts/run.sh kubectl --context kind-hub get pods -A
source "$(dirname "$0")/lib.sh"
exec "$@"
