# Envoy y Envoy Gateway

## ¿Qué es?

**Envoy** es un proxy L4/L7 de alto rendimiento. Es el **data plane**: recibe conexiones, elige una ruta, balancea, reintenta y emite métricas y logs. Su rasgo distintivo es que casi todo se le puede configurar **en caliente** mediante una API ([xDS](09-envoy-xds.md)).

**Envoy Gateway** es un **control plane** que implementa Gateway API usando Envoy. Observa `GatewayClass`, `Gateway` y `HTTPRoute`, despliega los proxies necesarios y les envía la configuración traducida.

En una frase: Envoy mueve los bytes; Envoy Gateway decide con qué configuración.

## ¿Qué problema resuelve?

Usar Envoy "a mano" significa escribir cientos de líneas de listeners, filtros y clusters, y además construir tu propio servidor xDS si quieres cambios sin reiniciar. Envoy Gateway reduce eso a un `Gateway` y un `HTTPRoute`.

## Conceptos clave

| Término | Definición |
|---|---|
| **Control plane** | Deployment `envoy-gateway`; traduce y sirve xDS (gRPC 18000). No ve tráfico de usuarios. |
| **Data plane** | Deployment `envoy-gateway-system-hub-gateway-…`, uno por Gateway. |
| **shutdown-manager** | Sidecar que drena conexiones antes de apagar Envoy. |
| **EnvoyProxy** | CRD para personalizar cómo se despliega el data plane. |
| **Downstream / Upstream** | Quien llama a Envoy / a quien llama Envoy. |
| **Admin API** | `127.0.0.1:19000` dentro del pod. |
| **Políticas** | `BackendTrafficPolicy`, `SecurityPolicy`, `ClientTrafficPolicy`: extensiones no cubiertas por Gateway API. |

## Cómo se usa en este POC

- Instalación: [scripts/gateway.sh](../../scripts/gateway.sh) (chart OCI; incluye los CRDs de Gateway API).
- Personalización: [gateway/envoyproxy.yaml](../../gateway/envoyproxy.yaml).

### Cómo entra el tráfico (y por qué port-mapping)

```
tu máquina 127.0.0.1:8080
   └─► contenedor hub-control-plane :30080     (extraPortMappings)
         └─► Service NodePort 80:30080         (kube-proxy)
               └─► pod Envoy :10080            (listener "http" del Gateway)
```

- Envoy escucha en **10080** y no en 80 porque corre sin privilegios: Envoy Gateway desplaza los puertos bajos sumando 10000. El Service hace la traducción.
- Se eligió port-mapping frente a `kubectl port-forward` porque es permanente y recorre el datapath real. Alternativa más "realista": `cloud-provider-kind` para tener Services `LoadBalancer`.

### Backends multi-clúster

Envoy Gateway entiende `ServiceImport` de forma nativa: busca los `EndpointSlice` con la label `multicluster.kubernetes.io/service-name` y usa sus direcciones como endpoints. **No resuelve DNS `clusterset.local`** para esto; el DNS existe para que otros pods llamen al servicio.

### Access logs

Cada petición se registra en JSON en stdout, con `upstream_host`, `route_name` y `response_flags`. Es el primer sitio donde mirar:

| `response_flags` | Significado |
|---|---|
| `NR` | no hay ruta (→ 404) |
| `UF` | falló la conexión al upstream (→ 503) |
| `UH` | no hay upstreams sanos |
| `UT` | timeout del upstream |

## Comandos útiles para inspeccionar / debuggear

```bash
khub -n envoy-gateway-system get deploy,svc,pods
khub -n envoy-gateway-system logs deploy/envoy-gateway --tail=50
khub -n envoy-gateway-system logs -l gateway.envoyproxy.io/owning-gateway-name=hub-gateway -c envoy --tail=20
task xds
curl -v -H 'Host: webapp.local' http://localhost:8080/
```

## Para profundizar

- <https://gateway.envoyproxy.io/docs/>
- <https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview>
