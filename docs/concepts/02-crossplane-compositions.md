# Crossplane Compositions (XRD + Composition)

## ¿Qué es?

Es el mecanismo para **inventar tu propia API de Kubernetes sin escribir un operador**. Se divide en dos piezas:

- El **XRD** (`CompositeResourceDefinition`) define el *contrato*: nombre de la API, campos, tipos, defaults, validaciones. Piensa en la firma de una función.
- La **Composition** define la *implementación*: qué recursos reales se crean y cómo se rellenan a partir de esos campos. El cuerpo de la función.

Separarlas permite tener varias implementaciones para el mismo contrato (por ejemplo, "WebApp en kind" y "WebApp en EKS") sin que el consumidor cambie su YAML.

## ¿Qué problema resuelve?

Sin esto, cada equipo copia 5 manifiestos y necesita saber de Submariner, `ProviderConfig`, `ServiceImport` y `readiness`. Alternativas habituales y su límite:

| Alternativa | Límite |
|---|---|
| Chart de Helm | Renderiza una vez; no hay API tipada en el clúster ni reconciliación del conjunto. |
| Operador propio en Go | Potentísimo, pero hay que escribir, probar y mantener un controlador. |
| Módulo de Terraform | Sin API en Kubernetes ni corrección continua de drift. |

## Conceptos clave

| Término | Definición |
|---|---|
| **XRD** | Define el tipo compuesto; Crossplane genera los CRDs a partir de él. |
| **XR (Composite Resource)** | Instancia del tipo compuesto (`XWebApp`). |
| **Claim** | Proxy namespaced del XR (`WebApp`) → [03](03-crossplane-claims.md). |
| **Composition** | Receta que transforma un XR en recursos compuestos. |
| **Composed resource** | Cada recurso generado (aquí, 5 `Object`). |
| **composition-resource-name** | Clave estable de cada recurso dentro del pipeline; así Crossplane sabe que "el deployment de hoy es el de ayer". |
| **CompositionRevision** | Copia inmutable de cada versión de una Composition; permite actualizar XRs de forma controlada. |

## Cómo se usa en este POC

```
xrd-webapp.yaml ──genera──► CRD xwebapps (XR)  +  CRD webapps (Claim)
                                  │
webapp-claim.yaml ──► WebApp ──► XWebApp ──(composition-webapp.yaml)──► 5 Object
```

### El contrato: [xrd-webapp.yaml](../../crossplane/xrd-webapp.yaml)

| Campo | Tipo | Default | Notas |
|---|---|---|---|
| `spec.image` | string | — | obligatorio |
| `spec.replicas` | integer | 1 | 1–5 |
| `spec.port` | integer | 80 | puerto del contenedor |
| `spec.hostname` | string | `<nombre>.apps.lab.local` | validado con regex |
| `status.hostname` | string | — | lo escribe la Composition |
| `status.clusterSetDNS` | string | — | lo escribe la Composition |

La validación la hace el API server, antes de que Crossplane intervenga:

```bash
khub -n demo patch webapp webapp --type=merge -p '{"spec":{"replicas":50}}'
# → rechazado: spec.replicas ... should be less than or equal to 5
```

### La implementación: [composition-webapp.yaml](../../crossplane/composition-webapp.yaml)

| Recurso compuesto | Clúster | `readiness` | Por qué esa política |
|---|---|---|---|
| `remote-namespace` | remote | `SuccessfulCreate` | existir basta |
| `deployment` | remote | CEL sobre `availableReplicas` | creado ≠ funcionando |
| `service` | remote | `SuccessfulCreate` | existir basta |
| `service-export` | remote | `DeriveFromObject` | publica condición `Ready` al sincronizar con el broker |
| `httproute` | hub | CEL sobre `status.parents` | debe estar `Accepted` **y** `ResolvedRefs` |

Dos decisiones que conviene entender:

1. **`deletionPolicy: Orphan` en el namespace.** Dos claims en `demo` generan dos `Object` que apuntan al mismo Namespace. Si borrar uno eliminase el namespace, se llevaría las apps del otro.
2. **El namespace de `hub` no se compone.** Ya existe: ahí vive el claim.

## Comandos útiles para inspeccionar / debuggear

```bash
khub get xrd                                   # ESTABLISHED / OFFERED
khub explain webapp.spec                       # tu API, documentada como cualquier otra
khub get compositions,compositionrevisions
task crossplane:render                         # ejecutar la receta sin clúster
khub get xwebapp -o yaml                       # spec.resourceRefs = lo que compuso
```

## Para profundizar

- <https://docs.crossplane.io/latest/composition/composite-resource-definitions/>
- <https://docs.crossplane.io/latest/composition/compositions/>
