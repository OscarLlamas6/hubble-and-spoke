# Gateway API

## ¿Qué es?

La API estándar de Kubernetes (CRDs de SIG Network) para exponer y enrutar tráfico. Es la sucesora de Ingress: en vez de un objeto único lleno de anotaciones, separa **qué implementación**, **qué puntos de entrada** y **qué rutas** en objetos distintos, cada uno pensado para un rol.

Es solo una especificación: sin una **implementación** (aquí [Envoy Gateway](08-envoy-gateway.md)) los objetos no hacen nada.

## ¿Qué problema resuelve?

Ingress solo expresa host + path hacia un Service. Todo lo demás (reintentos, pesos, cabeceras, TLS avanzado) terminó en anotaciones propietarias, distintas en cada controlador y sin validación. Además, un único objeto mezclaba responsabilidades de plataforma y de aplicación.

## Conceptos clave

| Objeto | Rol | Qué define |
|---|---|---|
| **GatewayClass** | proveedor de infraestructura | qué controlador implementa |
| **Gateway** | operador del clúster | listeners (puerto, protocolo, TLS) y quién puede adjuntar rutas |
| **HTTPRoute** | desarrollador | hostnames, matches, filtros, backends |
| **parentRefs** | — | a qué Gateway se adjunta una ruta |
| **backendRefs** | — | destino: Service u otro tipo, como `ServiceImport` |
| **allowedRoutes** | — | consentimiento del Gateway hacia namespaces |
| **ReferenceGrant** | — | consentimiento para referenciar objetos de otro namespace |
| **status.conditions** | — | `Accepted`, `Programmed`, `ResolvedRefs` |

El adjuntado es un **apretón de manos**: la ruta pide (`parentRefs`) y el Gateway permite (`allowedRoutes`). Ambos lados deben estar de acuerdo.

## Cómo se usa en este POC

| Objeto | Archivo | Namespace |
|---|---|---|
| `GatewayClass/envoy` | [gateway/gatewayclass.yaml](../../gateway/gatewayclass.yaml) | cluster |
| `Gateway/hub-gateway` | [gateway/gateway.yaml](../../gateway/gateway.yaml) | `gateway-system` |
| `HTTPRoute/webapp` | generado por la [Composition](../../crossplane/composition-webapp.yaml) | el del claim (`demo`) |

La ruta resultante:

```yaml
spec:
  hostnames: [webapp.local]
  parentRefs:
    - { name: hub-gateway, namespace: gateway-system }
  rules:
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs:
        - group: multicluster.x-k8s.io     # ← no es un Service
          kind: ServiceImport
          name: webapp
          port: 80
```

El backend es el `ServiceImport` que Submariner crea en el mismo namespace, así que no hace falta `ReferenceGrant`.

Como `allowedRoutes.from: All`, cualquier namespace puede publicar. Es cómodo para el lab; en una plataforma compartida restríngelo por labels y vigila que dos equipos no reclamen el mismo hostname.

### Cómo leer el status (lo más útil para depurar)

| Condición | Si es `False` |
|---|---|
| `GatewayClass Accepted` | el controlador no corre o `controllerName` no coincide |
| `Gateway Programmed` | el data plane no está listo |
| `HTTPRoute Accepted` | `parentRefs` mal, o `allowedRoutes` no lo permite |
| `HTTPRoute ResolvedRefs` | el backend no existe (`BackendNotFound`) |

## Comandos útiles para inspeccionar / debuggear

```bash
khub get gatewayclass,gateway,httproute -A
khub -n gateway-system describe gateway hub-gateway
khub -n demo get httproute webapp -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
khub explain httproute.spec.rules.backendRefs
```

## Para profundizar

- <https://gateway-api.sigs.k8s.io/>
- <https://gateway-api.sigs.k8s.io/reference/api-types/httproute/>
