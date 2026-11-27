#!/usr/bin/env bash
# =============================================================================
# tools.sh — descarga las CLIs fijadas en versions.env dentro de ./.bin
# -----------------------------------------------------------------------------
# Idempotente: si la versión correcta ya está, no descarga nada.
# Cada binario se verifica con el checksum SHA-256 publicado por su proyecto
# (subctl no publica checksum por archivo en la release, se valida su versión).
# =============================================================================
source "$(dirname "$0")/lib.sh"

[[ "$(uname -s)" == "Linux" ]] || die "Este lab está probado solo en Linux (ver docs/prerequisites.md)"
case "$(uname -m)" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *)       die "Arquitectura no soportada: $(uname -m)" ;;
esac

mkdir -p "${BIN_DIR}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# have <binario> <versión>: ¿ya está instalada exactamente esa versión?
have() { [[ -x "${BIN_DIR}/$1" && "$(cat "${BIN_DIR}/.$1.version" 2>/dev/null)" == "$2" ]]; }
mark() { printf '%s' "$2" > "${BIN_DIR}/.$1.version"; ok "$1 $2"; }

# fetch <url> <destino>
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

# verify <archivo> <sha256 esperado>
verify() { echo "$2  $1" | sha256sum -c --quiet - || die "Checksum inválido para $1"; }

step "Instalando herramientas en ${BIN_DIR}"

if have kind "${KIND_VERSION}"; then ok "kind ${KIND_VERSION} (ya instalado)"; else
  url="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  fetch "$url" "${TMP}/kind"
  verify "${TMP}/kind" "$(curl -fsSL "${url}.sha256sum" | awk '{print $1}')"
  install -m 0755 "${TMP}/kind" "${BIN_DIR}/kind"; mark kind "${KIND_VERSION}"
fi

if have kubectl "${KUBECTL_VERSION}"; then ok "kubectl ${KUBECTL_VERSION} (ya instalado)"; else
  url="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  fetch "$url" "${TMP}/kubectl"
  verify "${TMP}/kubectl" "$(curl -fsSL "${url}.sha256")"
  install -m 0755 "${TMP}/kubectl" "${BIN_DIR}/kubectl"; mark kubectl "${KUBECTL_VERSION}"
fi

if have helm "${HELM_VERSION}"; then ok "helm ${HELM_VERSION} (ya instalado)"; else
  url="https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
  fetch "$url" "${TMP}/helm.tgz"
  verify "${TMP}/helm.tgz" "$(curl -fsSL "${url}.sha256sum" | awk '{print $1}')"
  tar -xzf "${TMP}/helm.tgz" -C "${TMP}"
  install -m 0755 "${TMP}/linux-${ARCH}/helm" "${BIN_DIR}/helm"; mark helm "${HELM_VERSION}"
fi

if have subctl "${SUBCTL_VERSION}"; then ok "subctl ${SUBCTL_VERSION} (ya instalado)"; else
  fetch "https://github.com/submariner-io/releases/releases/download/${SUBCTL_VERSION}/subctl-${SUBCTL_VERSION}-linux-${ARCH}.tar.xz" "${TMP}/subctl.tar.xz"
  mkdir -p "${TMP}/subctl.d"
  tar -xJf "${TMP}/subctl.tar.xz" -C "${TMP}/subctl.d"
  install -m 0755 "$(find "${TMP}/subctl.d" -type f -name 'subctl*' | head -n1)" "${BIN_DIR}/subctl"
  mark subctl "${SUBCTL_VERSION}"
fi

if have crossplane "${CROSSPLANE_CLI_VERSION}"; then ok "crossplane CLI ${CROSSPLANE_CLI_VERSION} (ya instalado)"; else
  # Se usa el bundle .tar.gz porque su .sha256 es fiable; en v2.4.1 el .sha256
  # publicado junto al binario suelto no coincide con ese binario.
  url="https://cli.crossplane.io/stable/${CROSSPLANE_CLI_VERSION}/bundle/linux_${ARCH}/crossplane-cli.tar.gz"
  fetch "$url" "${TMP}/crossplane.tgz"
  verify "${TMP}/crossplane.tgz" "$(curl -fsSL "${url}.sha256" | awk '{print $1}')"
  mkdir -p "${TMP}/xp.d"
  tar -xzf "${TMP}/crossplane.tgz" -C "${TMP}/xp.d"
  install -m 0755 "${TMP}/xp.d/crossplane" "${BIN_DIR}/crossplane"; mark crossplane "${CROSSPLANE_CLI_VERSION}"
fi
