#!/usr/bin/env bash
# =============================================================================
# field.sh <render.yaml> <composition-resource-name> <expresión yq> <esperado>
# -----------------------------------------------------------------------------
# Los `Object` renderizados tienen nombres con hash, así que no sirven para
# seleccionarlos en una aserción. Lo estable es la anotación
# crossplane.io/composition-resource-name (deployment, service, httproute...).
# =============================================================================
set -euo pipefail
render=$1 name=$2 expr=$3 expected=$4

actual=$(NAME="$name" yq eval-all \
  "select(.metadata.annotations.\"crossplane.io/composition-resource-name\" == strenv(NAME)) | ${expr}" "$render")

if [[ "$actual" != "$expected" ]]; then
  echo "[$name] ${expr}: esperado '${expected}', obtenido '${actual}'"
  exit 1
fi
echo "[$name] ${expr} = ${actual}"
