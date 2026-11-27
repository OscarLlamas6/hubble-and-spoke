# Multi-Cluster Services API (MCS)

## ¿Qué es?

Una especificación de Kubernetes (KEP-1645, SIG Multicluster) que define cómo publicar un Service a un conjunto de clústeres (*clusterset*). Submariner es una implementación.

## ¿Qué problema resuelve?

Que cada herramienta inventara su propia forma de decir "este servicio es global". Con un estándar, consumidores como Envoy Gateway pueden soportar `ServiceImport` sin saber quién lo implementa.

## Conceptos clave

| Término | Definición |
|---|---|
| **ClusterSet** | Grupo de clústeres que confían entre sí. |
| **Namespace sameness** | El mismo nombre de namespace significa lo mismo en todos. |
| **ServiceExport** | Lo creas tú junto al Service. |
| **ServiceImport** | Lo crea la implementación en los consumidores. |
| **`ClusterSetIP` / `Headless`** | Tipos de import. |
| **`clusterset.local`** | Zona DNS del clusterset. |
| **EndpointSlice importado** | Direcciones, con label `multicluster.kubernetes.io/service-name`. |

## Cómo se usa en este POC

- `ServiceExport` en `remote`: lo compone Crossplane (recurso `service-export`).
- `ServiceImport` en `hub`: lo crea Lighthouse; es el `backendRef` del HTTPRoute.

Observación de la implementación: el `ServiceImport` es de tipo `ClusterSetIP` pero **sin IP asignada** (la anotación `lighthouse.submariner.io/use-clusterset-ip: "false"`). El DNS devuelve la ClusterIP del clúster exportador.

*Namespace sameness* tiene implicaciones de seguridad: quien pueda crear un Service y un export en el namespace `demo` de cualquier clúster del clusterset puede recibir tráfico destinado a ese nombre.

## Comandos útiles para inspeccionar / debuggear

```bash
kremote -n demo get serviceexport webapp -o yaml        # conditions Valid y Ready
khub -n demo get serviceimport webapp -o yaml
khub -n demo get endpointslices -l multicluster.kubernetes.io/service-name=webapp -o yaml
```

## Para profundizar

- <https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/1645-multi-cluster-services-api>
- <https://multicluster.sigs.k8s.io/concepts/multicluster-services-api/>
