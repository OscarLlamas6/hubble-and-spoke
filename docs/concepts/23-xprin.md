# xprin (tests de Compositions)

## ¿Qué es?

Un framework de pruebas para Crossplane (`crossplane-contrib/xprin`). Describes casos en YAML y, para cada uno, ejecuta el pipeline con `render`, valida la salida con `resource validate` y evalúa aserciones. La salida se parece a `go test`. No necesita clúster, solo Docker.

## ¿Qué problema resuelve?

`render` te enseña la salida, pero alguien tiene que mirarla. Sin tests, un patch mal escrito (que se **omite en silencio**) o un `if` equivocado en una plantilla aparece al aplicar en un clúster. Con xprin la expectativa queda escrita y se comprueba en segundos.

## Conceptos clave

| Término | Definición |
|---|---|
| **Test suite** | Archivo `xprin.yaml` o `*_xprin.yaml`. |
| **`common`** | Configuración compartida por todos los casos. |
| **Input `claim` / `xr`** | El claim se convierte a XR con `xprin-helpers`. |
| **`patches.xrd`** | Aplica defaults del XRD y fija el scope (v1/v2). |
| **`crds`** | Schemas para validar (XRD, Provider, CRDs). |
| **`observed-resources`** | Estado simulado: prueba la lógica de reconciliaciones posteriores. |
| **Aserciones** | `xprin` (Count, Exists, FieldValue…), `diff`/`dyff` contra *golden files*. |
| **Hooks** | Comandos antes/después; `{{ .Outputs.Render }}` es la salida. |

## Cómo se usa en este POC

```bash
task test:unit                                  # todo
task test:unit -- tests/v2/webappv2_xprin.yaml  # un suite
task test:unit:update-goldens                   # tras un cambio intencionado
```

| Suite | Casos |
|---|---|
| [tests/v1](../../tests/v1/webapp_xprin.yaml) | claim de ejemplo · claim mínimo (defaults) · XR sin claim no compone nada · todo listo → `Ready` |
| [tests/v2](../../tests/v2/webappv2_xprin.yaml) | forma del render + golden · ruta aceptada → `Ready` · backend sin resolver → **no** `Ready` |
| [scripts/unit-test.sh](../../scripts/unit-test.sh) | dos casos negativos: el XRD rechaza `replicas: 50` y la falta de `image` |

Las entradas salen de los archivos reales del lab (el claim de ejemplo, las Compositions, la versión del Provider), así que no hay copias que se desincronicen.

Los `Object` tienen nombres con hash; [tests/lib/field.sh](../../tests/lib/field.sh) los selecciona por la anotación `composition-resource-name`.

### Qué cubre cada nivel de prueba

| Nivel | Comando | Necesita | Detecta |
|---|---|---|---|
| Unitario | `task test:unit` | Docker | lógica de la Composition, schema, defaults |
| Humo E2E | `task test` | los dos clústeres | permisos, red, controladores, tráfico real |

xprin **no** comprueba que las consultas CEL de `readiness` funcionen (las evalúa el provider) ni valida el manifiesto que va **dentro** de un `Object` (para el schema es contenido libre). De eso se encargan las aserciones y el smoke test.

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
