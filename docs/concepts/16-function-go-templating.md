# function-go-templating

## ¿Qué es?

Una función que genera o modifica recursos con plantillas de Go y las funciones de [Sprig](https://masterminds.github.io/sprig/), al estilo Helm, pero con acceso al estado observado y deseado.

## ¿Qué problema resuelve?

Condicionales, bucles y valores derivados. En este lab: "si no hay hostname, usa `<nombre>.apps.lab.local`".

## Conceptos clave

| Término | Definición |
|---|---|
| **`source: Inline`** | La plantilla va en la propia Composition (también `FileSystem` o `Environment`). |
| **`.observed`** | XR y recursos tal como están. |
| **`.desired`** | Acumulado de los pasos anteriores. |
| **Anotación `gotemplating.fn.crossplane.io/composition-resource-name`** | Clave del recurso emitido. Reutilizar una clave **reemplaza** el recurso. |
| **Documento del tipo del XR** | Actualiza su `status`. |
| **`ready` annotation** | Permite marcar readiness manualmente. |

## Cómo se usa en este POC

Step `hostname-and-status` de [composition-webapp.yaml](../../crossplane/composition-webapp.yaml):

1. Lee `desired["service"]` (producido por el paso 1).
2. Calcula el hostname con `dig` + `default`.
3. Toma `desired["httproute"]`, le añade `hostnames` y lo reemite con la misma clave.
4. Emite el XR con `status.hostname` y `status.clusterSetDNS`.

Dos trampas habituales:

- Un comentario de plantilla debe cerrarse pegado: `*/}}`. `*/ }}` es error de sintaxis.
- Si reemites un recurso, debes emitirlo **completo**: no se fusiona con el anterior.

## Comandos útiles para inspeccionar / debuggear

```bash
task crossplane:render
khub -n crossplane-system logs -l pkg.crossplane.io/function=function-go-templating --tail=30
khub -n demo get webapp webapp -o jsonpath='{.status}' | jq .
```

## Para profundizar

- <https://github.com/crossplane-contrib/function-go-templating>
- <https://pkg.go.dev/text/template>
