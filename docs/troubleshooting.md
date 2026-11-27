# Troubleshooting

## Método: sigue la cadena

```bash
task status
./scripts/run.sh crossplane resource trace webapp.platform.lab.local/webapp -n demo --context kind-hub
```

| Pregunta | Comando (tras `source scripts/env.sh`) |
|---|---|
| ¿El claim está Synced/Ready? | `khub -n demo get webapp` |
| ¿Qué `Object` falla? | `khub get object` → `khub describe object <n>` |
| ¿Están los pods en remote? | `kremote -n demo get pods` |
| ¿Se exportó? | `kremote -n demo get serviceexport webapp -o yaml` |
| ¿Llegó el import? | `khub -n demo get serviceimport,endpointslices` |
| ¿La ruta resuelve? | `khub -n demo describe httproute webapp` |
| ¿Hay túnel? | `task submariner:status` |
| ¿Qué dice Envoy? | `task xds` y access logs |

## Escenarios reproducidos

Provocados en este lab; los síntomas son los observados.

### La imagen no existe

- Claim `SYNCED=True`, `READY=False`; el XR dice `Unready resources: deployment`.
- Pods en `ErrImagePull` en `remote`.
- `curl` → **503** `upstream connect error or disconnect/reset before headers`.
- `trace` muestra un único `Object` en `Unavailable`.

Moraleja: `SYNCED` significa "pude aplicar", no "funciona".

### El backend no tiene pods

Con 0 réplicas (pausando antes Crossplane): **503**. La ruta sigue `Accepted` y resuelta, porque Envoy solo ve la ClusterIP.

```bash
khub annotate object --all crossplane.io/paused=true --overwrite
kremote -n demo scale deploy webapp --replicas=0
curl -i -H 'Host: webapp.local' http://localhost:8080/
khub annotate object --all crossplane.io/paused-      # recuperar
```

### Falta el ServiceExport

- `curl` → **500**.
- `HTTPRoute`: `Accepted=True`, `ResolvedRefs=False`, `BackendNotFound: ... service import demo/webapp not found`.

Al quitar la pausa, Crossplane recrea el export y se recupera en segundos.

## Problemas de instalación

### `kubeadm join` falla: "The kubelet is not healthy" / `too many open files`

Límite de inotify. Ocurrió al construir este lab con `max_user_instances=128` al añadir un segundo nodo; por eso hay uno por clúster. Si lo necesitas:

```bash
sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288
```

Para que persista, escríbelo en `/etc/sysctl.d/`.

### `Chart.yaml file is missing` al instalar Crossplane

Helm confundió el chart `crossplane` con la carpeta `./crossplane`. Usa la URL completa del `.tgz` (ya lo hace el script).

### Checksum inválido de la CLI de Crossplane

En v2.4.1, el `.sha256` publicado junto al binario suelto no coincide con él; el del bundle `.tar.gz` sí, y es el que usa `tools.sh`. Si ves un error de checksum en otra herramienta, **no lo saltes**: reintenta y verifica la versión.

### El puerto 8080 está ocupado

`ss -ltnp | grep 8080`. Libéralo, o cambia `hostPort` en [kind-hub.yaml](../clusters/kind-hub.yaml), recrea el clúster y usa `URL=http://localhost:<puerto>/ task test`.

### `port 19000 already in use`

Quedó un `port-forward` abierto: `pgrep -af port-forward`, o `PORT=19100 task xds`.

## Submariner

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Túnel no pasa de `connecting` | broker anunciado con `127.0.0.1`, o IPsec bloqueado | revisa `--broker-url`; mira logs de `ds/submariner-gateway`; prueba `--cable-driver vxlan` para aislar IPsec |
| CIDRs solapados | clústeres con el default de kind | `subctl diagnose all`; recrea con los CIDRs del repo o usa Globalnet |
| `*.clusterset.local` no resuelve justo tras instalar | CoreDNS recargando | espera ~1 min y reintenta |
| No resuelve nunca | falta el export o la zona en CoreDNS | `kremote get serviceexport -A`; `khub -n kube-system get cm coredns -o yaml` |
| Hay export pero no import | no existe el namespace en el clúster consumidor | créalo |
| Dejó de funcionar tras reiniciar Docker/host | cambiaron las IPs de los nodos | `task down && task up` |

## Crossplane

| Síntoma | Qué mirar |
|---|---|
| Provider/Function no `HEALTHY` | `khub describe provider.pkg ...`; descarga de imagen |
| Composition en `Unready` | `khub describe xwebapp` (nombra los recursos pendientes) |
| XR con `Synced=False` | evento de la función que falló; reproduce con `task crossplane:render` |
| `Object` con `cannot ... forbidden` | RBAC del ProviderConfig `hub`, o credenciales de `remote` |
| `Object` no conecta a remote | el Secret debe usar el kubeconfig `--internal`; repite `task crossplane` |
| Cambios que tardan | el provider observa cada 20 s |
| El claim no se borra | `khub get object`: algún finalizer espera a `remote`. No quites finalizers sin entender por qué |
| Aviso `CompositeResourceDefinition v1 is deprecated` | esperado ([claims](concepts/03-crossplane-claims.md)) |

## Gateway / Envoy

| Síntoma | Significado |
|---|---|
| `curl` → conexión rechazada | no hay port mapping (¿clúster creado con otro archivo?) |
| 404 | ninguna ruta para ese `Host` (`response_flags: NR`) |
| 500 | `backendRef` no resuelto |
| 503 | Envoy no pudo conectar con el endpoint |
| Gateway sin `Programmed` | pods del data plane; `khub -n envoy-gateway-system describe pods` |

## Reinicio limpio

```bash
task down && task up
```
