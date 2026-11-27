# function-patch-and-transform

## ¿Qué es?

La función que reproduce el modelo clásico de Crossplane (plantillas base + *patches* + *transforms*) dentro de un pipeline.

## ¿Qué problema resuelve?

La mayor parte de una composición es copiar campos: "pon `spec.image` en el contenedor". Hacerlo con un lenguaje de plantillas es verboso y frágil; aquí es declarativo y con rutas tipadas.

## Conceptos clave

| Término | Definición |
|---|---|
| **`resources[].base`** | Plantilla del recurso. |
| **`FromCompositeFieldPath`** | XR → recurso. |
| **`ToCompositeFieldPath`** | Recurso → status del XR. |
| **`CombineFromComposite`** | Varios campos → uno. |
| **`transforms`** | `string`, `map`, `math`, `convert`, `match`. |
| **`patchSets`** | Patches reutilizables. |
| **`policy.fromFieldPath: Required`** | No crear el recurso hasta que exista el dato. |
| **`readinessChecks`** | Cuándo el recurso está listo (el lab usa el `readiness` del `Object`). |

## Cómo se usa en este POC

Step `base-resources` de [composition-webapp.yaml](../../crossplane/composition-webapp.yaml):

| Técnica | Dónde |
|---|---|
| `patchSet` `identity` | nombre y namespace en 4 recursos |
| `FromCompositeFieldPath` | image, replicas, port, backend del HTTPRoute |
| `CombineFromComposite` | anotación `platform.lab.local/claim: demo/webapp` |
| `transform` de tipo `string` | anotación `platform.lab.local/composite: XWebApp/<xr>` |
| `Required` | evita recursos sin nombre |

Los patches apuntan a `spec.forProvider.manifest.…` porque el objeto real va **dentro** del `Object`.

Un patch cuyo origen no existe se **omite en silencio** (política por defecto `Optional`). Si un campo "no llega", empieza por ahí.

## Comandos útiles para inspeccionar / debuggear

```bash
task crossplane:render
khub get object -o yaml | grep -B3 -A3 'platform.lab.local/claim'
kremote -n demo get svc webapp -o jsonpath='{.metadata.annotations}'
```

## Para profundizar

- <https://github.com/crossplane-contrib/function-patch-and-transform>
