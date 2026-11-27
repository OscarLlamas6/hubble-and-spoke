# xprin (tests de Compositions)

## ¿Qué es?

Un framework de pruebas para Crossplane ([crossplane-contrib/xprin](https://github.com/crossplane-contrib/xprin)). El nombre combina *Crossplane* con el griego *prin* ("antes"): probar **antes** de que Crossplane actúe sobre un clúster.

Describes casos en un YAML: "con esta entrada y esta Composition, espero esto". Para cada caso, xprin ejecuta el pipeline de verdad (las mismas Composition Functions, en contenedores Docker), valida la salida contra los schemas y comprueba tus expectativas. La salida se parece a `go test`. **No necesita clúster.**

No sustituye a `crossplane composition render` ni a `crossplane resource validate`: los **orquesta**.

## ¿Qué problema resuelve?

`render` te enseña la salida, pero alguien tiene que mirarla. Sin tests, un patch mal escrito (que se **omite en silencio**) o un `if` equivocado en una plantilla aparece al aplicar en un clúster. Con xprin la expectativa queda escrita y se comprueba en segundos.

## Conceptos clave

| Término | Definición |
|---|---|
| **Test suite** | Archivo `xprin.yaml` o `*_xprin.yaml`; solo así lo descubre. |
| **Test case** | Un elemento de `tests`: nombre, entradas, expectativas. |
| **`common`** | Configuración compartida por todos los casos del archivo. |
| **`inputs.claim` / `inputs.xr`** | La entrada. Un claim se convierte a XR con `xprin-helpers`. |
| **`patches.xrd`** | Aplica defaults del XRD y fija el scope (v1 o v2). |
| **`inputs.crds`** | Schemas para validar (XRD, Provider, CRDs). |
| **`inputs.observed-resources`** | Estado simulado, para probar reconciliaciones posteriores. |
| **Aserciones `xprin`** | `Count`, `Exists`, `NotExists`, `FieldValue`… |
| **Aserciones `diff` / `dyff`** | Comparan contra un *golden file* (salida de referencia). |
| **Hooks** | Comandos antes o después; `{{ .Outputs.Render }}` es la salida. |

## Cómo se usa en este POC

### Ejecutarlo

```bash
task test:unit                                  # todo
task test:unit -- tests/v2/webappv2_xprin.yaml  # un solo suite (sin los negativos)
task test:unit:update-goldens                   # tras un cambio intencionado
```

### Todos los archivos involucrados

| Archivo | Qué es |
|---|---|
| [versions.env](../../versions.env) | `XPRIN_VERSION`, `YQ_VERSION`, `GATEWAY_API_VERSION` |
| [scripts/tools.sh](../../scripts/tools.sh) | descarga `xprin`, `xprin-helpers` y `yq` a `.bin/` con checksum |
| [Taskfile.yml](../../Taskfile.yml) | tareas `test:unit` y `test:unit:update-goldens` |
| [scripts/unit-test.sh](../../scripts/unit-test.sh) | prepara entradas, genera la config, lanza xprin y los casos negativos |
| [tests/lib/field.sh](../../tests/lib/field.sh) | helper: comprobar un campo de un recurso por su `composition-resource-name` |
| **v1** | |
| [tests/v1/webapp_xprin.yaml](../../tests/v1/webapp_xprin.yaml) | el suite |
| [tests/v1/xr-without-claim.yaml](../../tests/v1/xr-without-claim.yaml) | entrada: XR sin labels de claim |
| [tests/v1/observed-all-ready.yaml](../../tests/v1/observed-all-ready.yaml) | estado simulado: todo listo |
| [tests/v1/claim-invalid.yaml](../../tests/v1/claim-invalid.yaml) | entrada inválida (`replicas: 50`) |
| **v2** | |
| [tests/v2/webappv2_xprin.yaml](../../tests/v2/webappv2_xprin.yaml) | el suite |
| [tests/v2/golden-render.yaml](../../tests/v2/golden-render.yaml) | salida de referencia (generada; no editar a mano) |
| [tests/v2/observed-route-ok.yaml](../../tests/v2/observed-route-ok.yaml) | estado simulado: ruta aceptada y resuelta |
| [tests/v2/observed-route-unresolved.yaml](../../tests/v2/observed-route-unresolved.yaml) | estado simulado: backend sin resolver |
| [tests/v2/xr-invalid.yaml](../../tests/v2/xr-invalid.yaml) | entrada inválida (sin `image`) |
| `tests/.cache/` | generado, ignorado por git: claim extraído, `Provider`, CRD de HTTPRoute, config de xprin, schemas |

**Lo que se está probando** (no son copias; son los archivos reales): las dos Compositions, los dos XRD, [functions.yaml](../../crossplane/functions.yaml), el claim de ejemplo y [render/xr.yaml](../../crossplane/v2/render/xr.yaml).

### Qué ocurre al ejecutar `task test:unit`

1. `unit-test.sh` extrae del ejemplo real el claim, y de [provider-kubernetes.yaml](../../crossplane/provider-kubernetes.yaml) el `Provider`; descarga el CRD de HTTPRoute; escribe `tests/.cache/xprin-config.yaml`.
2. Por cada caso, xprin:
   1. copia las entradas a un directorio temporal,
   2. convierte el claim en XR (si la entrada es un claim),
   3. ejecuta `crossplane composition render` con la versión de Crossplane del clúster,
   4. ejecuta `crossplane resource validate` contra los schemas,
   5. evalúa las aserciones,
   6. ejecuta los hooks `post-test`.
3. `unit-test.sh` ejecuta los dos casos negativos.

### Anatomía de un caso

```yaml
common:                                  # compartido por todos los casos
  inputs:
    composition: ../../crossplane/composition-webapp.yaml   # lo que se prueba
    functions: ../../crossplane/functions.yaml
    crds:                                                   # para validar
      - ../../crossplane/xrd-webapp.yaml
      - ../.cache/provider.yaml
  patches:
    xrd: ../../crossplane/xrd-webapp.yaml                   # defaults + scope

tests:
  - name: "claim mínimo: aplican los defaults"
    inputs:
      claim: ../../crossplane/examples/webapp-claim-minimal.yaml
    assertions:
      xprin:
        - { name: "5 Object", type: Count, resource: Object, value: 5 }
    hooks:
      post-test:
        - name: "replicas=1 por defecto"
          run: ../lib/field.sh '{{ .Outputs.Render }}' deployment .spec.forProvider.manifest.spec.replicas 1
```

### Casos actuales

| Caso | Qué protege |
|---|---|
| v1 · claim de ejemplo | 5 recursos, valores del usuario, ruta hacia `ServiceImport`, namespace `Orphan` |
| v1 · claim mínimo | defaults del XRD y hostname calculado |
| v1 · XR sin claim | no se crean recursos sin nombre |
| v1 · todo listo | el XR llega a `Ready` |
| v2 · forma del render | 4 `Object` modernos, HTTPRoute directo, golden, sin política `Delete` |
| v2 · ruta resuelta | `Ready=True` |
| v2 · backend sin resolver | `Ready=False` culpando a `httproute` |
| negativos | el XRD rechaza `replicas: 50` y la falta de `image` |

### Añadir un caso

1. Agrega un elemento a `tests:` en el suite (o crea otro `*_xprin.yaml` y añádelo a la lista de `targets` en `unit-test.sh`).
2. Empieza con una aserción `Count` y ejecútalo con `task test:unit`.
3. **Comprueba que falla** rompiendo a propósito la Composition. Un test que nunca has visto fallar no demuestra nada.

### Qué cubre cada nivel de prueba

| Nivel | Comando | Necesita | Detecta |
|---|---|---|---|
| Unitario | `task test:unit` | Docker | lógica de la Composition, schema, defaults |
| Humo E2E | `task test` | los dos clústeres | permisos, red, controladores, tráfico real |

xprin **no** comprueba que las consultas CEL de `readiness` funcionen (las evalúa el provider) ni valida el manifiesto que va **dentro** de un `Object` (para el schema es contenido libre).

### Cosas aprendidas

- La documentación de la rama `main` describe `assertions.errors`, que **no existe en la v0.7.0** publicada. Por eso los negativos se hacen en el script.
- La reutilización de contenedores de funciones (activada por defecto) colgaba el render en la máquina donde se construyó el lab; se usa `--no-container-reuse`. No se investigó la causa raíz.
- Si matas una ejecución, pueden quedar un contenedor y una red `xprin-net-*` (`docker network ls`).

## Comandos útiles para inspeccionar / debuggear

```bash
source scripts/env.sh
xprin check -c tests/.cache/xprin-config.yaml   # tras un primer task test:unit
xprin test tests/v2/webappv2_xprin.yaml -c tests/.cache/xprin-config.yaml -v --show-all --no-container-reuse
git diff tests/v2/golden-render.yaml            # revisa SIEMPRE un golden regenerado
```

## Para profundizar

- <https://github.com/crossplane-contrib/xprin/blob/v0.7.0/docs/getting-started.md>
- <https://github.com/crossplane-contrib/xprin/blob/v0.7.0/docs/assertions.md>
