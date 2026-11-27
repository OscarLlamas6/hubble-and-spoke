# Crossplane v2: XR namespaced, sin claims

## ¿Qué es?

El modelo actual de Crossplane. El recurso compuesto (**XR**) puede vivir en un namespace, así que el usuario lo aplica directamente y desaparece el claim. Además, un XR puede componer **cualquier recurso de Kubernetes**, no solo managed resources de un provider.

Este lab implementa **las dos APIs a la vez** para compararlas: `WebApp` (v1, claims) y `WebAppV2` (v2).

## ¿Qué problema resuelve?

El modelo v1 necesitaba dos objetos (Claim + XR) para dar acceso por namespace, y envoltorios como `Object` incluso para crear algo en el mismo clúster. La documentación oficial lo resume como eliminar *"awkward abstractions like claims and provider-kubernetes Objects"*.

## Conceptos clave

| Término | Definición |
|---|---|
| **XRD `apiextensions.crossplane.io/v2`** | La definición moderna. |
| **`scope`** | `Namespaced` (default), `Cluster` o `LegacyCluster` (compatibilidad v1). |
| **`spec.crossplane`** | En XRs modernos, la maquinaria interna (`compositionRef`, `resourceRefs`…) queda separada de tus campos. |
| **Managed resource namespaced** | Grupos con `.m.` (`kubernetes.m.crossplane.io`). |
| **`ClusterProviderConfig` / `ProviderConfig`** | Configuración global o por namespace. |
| **`managementPolicies`** | Qué puede hacer Crossplane con el recurso; sustituye a `deletionPolicy`. |
| **Agregación de RBAC** | Label `rbac.crossplane.io/aggregate-to-crossplane` para permitir componer otros tipos. |

## Qué está deprecado exactamente (y qué no)

| Elemento | Estado | Evidencia |
|---|---|---|
| API `CompositeResourceDefinition` **v1** | **Deprecada** | el CRD lo marca y `kubectl` avisa: *"CompositeResourceDefinition v1 is deprecated and will be removed in a future release; consider migrating to v2"* |
| Claims | Solo existen con XRD v1 (`LegacyCluster`); los XR v2 **no admiten claims** | [What's new](https://docs.crossplane.io/latest/whats-new/) |
| Managed resources cluster-scoped | Anunciado que se deprecarán y eliminarán *"at a future date"* | What's new |
| `Object` v1alpha1 (cluster-scoped) | Deprecada (el lab usa `v1alpha2`) | CRD instalado |
| Patch & transform nativo, `ControllerConfig`, external secret stores | **Ya eliminados** en 2.x | guía de upgrade |

No encontré una fecha de retirada publicada para XRD v1 ni para claims, y la guía de upgrade dice que los XRD v1 siguen funcionando con claims. Para algo **nuevo**, usa v2.

Compruébalo tú mismo:

```bash
khub get crd compositeresourcedefinitions.apiextensions.crossplane.io -o json |
  jq '.spec.versions[] | {name, deprecated, deprecationWarning}'
```

## Cómo se usa en este POC

| Pieza | v1 (claims) | v2 (namespaced) |
|---|---|---|
| XRD | [xrd-webapp.yaml](../../crossplane/xrd-webapp.yaml) | [v2/xrd-webappv2.yaml](../../crossplane/v2/xrd-webappv2.yaml) |
| Composition | [composition-webapp.yaml](../../crossplane/composition-webapp.yaml) | [v2/composition-webappv2.yaml](../../crossplane/v2/composition-webappv2.yaml) |
| Lo que aplicas | `WebApp` (claim) | `WebAppV2` (el XR) |
| CRDs generados | `webapps` + `xwebapps` | `webappv2s` |
| Identidad de los recursos | labels `crossplane.io/claim-*` | `metadata.name` / `namespace` |
| Managed resource | `Object` cluster-scoped | `Object` namespaced (`.m.`) |
| Credenciales de remote | `ProviderConfig/remote` | `ClusterProviderConfig/remote` |
| Namespace remoto que sobrevive | `deletionPolicy: Orphan` | `managementPolicies` sin `Delete` |
| HTTPRoute | envuelto en `Object` | **recurso directo** |
| Permiso para el HTTPRoute | al ServiceAccount del provider | a Crossplane core ([rbac-httproute.yaml](../../crossplane/v2/rbac-httproute.yaml)) |
| Ready del HTTPRoute | consulta CEL | lógica en go-templating |
| Hostname por defecto | `<n>.apps.lab.local` | `<n>.v2.apps.lab.local` |
| Namespace de ejemplo | `demo` | `demo-v2` |

El kind se llama `WebAppV2` solo para que ambas coexistan sin ambigüedad; con una sola API se llamaría `WebApp`.

### Lo que se observó al compararlas

- Borrando el `HTTPRoute` a mano: en v2 se recreó en **91 ms** (Crossplane observa directamente lo que compone); en v1 en **4,2 s** (depende del siguiente sondeo de provider-kubernetes, configurado a 20 s). Una medición de cada uno: indica el orden de magnitud, no un benchmark.
- `crossplane resource trace` muestra el HTTPRoute colgando directo del XR, sin columnas `SYNCED`/`READY` porque no es un managed resource.
- `remote` sigue necesitando provider-kubernetes: "componer cualquier recurso" se limita al clúster de Crossplane.
- Un XR `Namespaced` solo compone en **su propio namespace**. Por eso el HTTPRoute queda en `demo-v2`.

### Migrar de v1 a v2

No se convierte en el sitio: `group` y `names` de un XRD no se pueden cambiar, y no encontré herramienta automática de migración. El patrón es el de este repo: XRD y Composition nuevos en paralelo, mover consumidores y retirar lo antiguo. Cuidado: borrar el claim v1 **borra sus recursos**; planifica nombres y namespaces para no cortar tráfico.

## Comandos útiles para inspeccionar / debuggear

```bash
task example:apply:v2 && task test:v2
khub get webappv2 -A
khub -n demo-v2 get objects.kubernetes.m.crossplane.io,httproute
khub -n demo-v2 get webappv2 webapp -o jsonpath='{.spec.crossplane}' | jq .
./scripts/run.sh crossplane resource trace webappv2.platform.lab.local/webapp -n demo-v2 --context kind-hub
```

## Para profundizar

- <https://docs.crossplane.io/latest/whats-new/>
- <https://docs.crossplane.io/latest/guides/upgrade-to-crossplane-v2/>
