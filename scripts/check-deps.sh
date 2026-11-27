#!/usr/bin/env bash
# =============================================================================
# check-deps.sh — ¿esta máquina puede levantar el lab?
# Falla (exit 1) solo ante problemas bloqueantes; el resto son advertencias.
# =============================================================================
source "$(dirname "$0")/lib.sh"

failed=0
step "Herramientas del sistema (las únicas que debes instalar tú)"
for tool in docker curl tar xz sha256sum; do
  if command -v "$tool" >/dev/null; then ok "$tool"; else warn "falta '$tool'"; failed=1; fi
done

if docker info >/dev/null 2>&1; then
  ok "Docker responde (server $(docker version --format '{{.Server.Version}}'))"
else
  warn "Docker no responde: ¿está corriendo y tu usuario está en el grupo 'docker'?"; failed=1
fi

step "Herramientas fijadas en ./.bin"
for tool in kind kubectl helm subctl crossplane xprin xprin-helpers yq; do
  if [[ -x "${BIN_DIR}/${tool}" ]]; then
    ok "${tool} $(cat "${BIN_DIR}/.${tool}.version" 2>/dev/null)"
  else
    warn "falta .bin/${tool} — ejecuta: task tools"; failed=1
  fi
done

step "Recursos y kernel"
mem_gb=$(awk '/MemAvailable/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if ((mem_gb >= 8)); then ok "RAM disponible: ${mem_gb} GiB"; else warn "RAM disponible: ${mem_gb} GiB (recomendado ≥ 8)"; fi

# kind con varios nodos consume muchos inotify; si se agotan, los pods fallan
# con "too many open files".
inst=$(sysctl -n fs.inotify.max_user_instances 2>/dev/null || echo 0)
watches=$(sysctl -n fs.inotify.max_user_watches 2>/dev/null || echo 0)
if ((inst >= 512 && watches >= 524288)); then
  ok "inotify: instances=${inst} watches=${watches}"
else
  warn "inotify bajo (instances=${inst}, watches=${watches}). Si ves 'too many open files':"
  warn "  sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288"
fi

step "Puerto del host para Envoy Gateway"
if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE ':8080$' && ! docker ps --format '{{.Names}}' | grep -qx 'hub-control-plane'; then
  warn "El puerto 8080 está ocupado; el clúster hub no podrá publicarlo"; failed=1
else
  ok "puerto 8080 utilizable"
fi

((failed == 0)) || die "Hay problemas bloqueantes (ver arriba)"
ok "Todo listo"
