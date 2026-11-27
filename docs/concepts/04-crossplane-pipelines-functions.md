# Compositions en modo Pipeline y Composition Functions

## ¿Qué es?

En `mode: Pipeline`, una Composition no describe los recursos directamente: describe **una cadena de programas** que los calculan. Cada eslabón (*step*) invoca una **Composition Function**, un servidor gRPC instalado como paquete.

Todas las funciones comparten un **Desired State**: cada una recibe lo que dejaron las anteriores, lo modifica y lo devuelve. Al terminar, Crossplane compara ese resultado con lo que existe y crea, actualiza o borra.

## ¿Qué problema resuelve?

El modelo legacy (`spec.resources` con `patches`, hoy **eliminado** en Crossplane 2.x) era YAML declarando transformaciones: sin condicionales, sin bucles, sin forma limpia de decir "si no viene el hostname, calcúlalo". Cada necesidad nueva exigía una feature nueva en el core. Con funciones, la lógica es un paquete intercambiable en el lenguaje que quieras (plantillas Go, KCL, Python, Go).

## Conceptos clave

| Término | Definición |
|---|---|
| **Pipeline / step** | Lista ordenada; cada step tiene `step`, `functionRef` e `input`. |
| **Function** | Paquete OCI que corre como Deployment y atiende `RunFunction` por gRPC. |
| **Observed state** | Foto actual del XR y de los recursos compuestos existentes. |
| **Desired state** | Lo que la cadena quiere que exista; se acumula step a step. |
| **Input** | Configuración propia de cada función (tiene su `apiVersion`/`kind`, pero no se crea en el clúster). |
| **Context** | Mapa efímero para pasar datos entre funciones que no son recursos. |
| **Results** | Eventos que una función emite; `fatal` aborta la reconciliación. |

## Cómo se usa en este POC

[composition-webapp.yaml](../../crossplane/composition-webapp.yaml), con las funciones declaradas en [functions.yaml](../../crossplane/functions.yaml):

```
                 ┌──────────────────────────── Desired State ───────────────────────────┐
 XR observado    │                                                                      │
      │          │  vacío          +5 recursos            HTTPRoute completado     listo│
      ▼          ▼                      │                        │                  │  │
 [1] patch-and-transform ───────────────┘                        │                  │  │
 [2] go-templating  ── lee desired["service"] ───────────────────┘ + status del XR  │  │
 [3] auto-ready     ── marca Ready ─────────────────────────────────────────────────┘  │
                                                                                      ▼
                                                                          Crossplane aplica
```

| Step | Función | Qué hace aquí | Doc |
|---|---|---|---|
| `base-resources` | `function-patch-and-transform` | Los 5 `Object` desde plantillas + patches | [15](15-function-patch-and-transform.md) |
| `hostname-and-status` | `function-go-templating` | Hostname por defecto, completa HTTPRoute, escribe status | [16](16-function-go-templating.md) |
| `ready` | `function-auto-ready` | `Ready` del XR | [17](17-function-auto-ready.md) |

### Cómo el output de un paso alimenta al siguiente

El paso 2 **no** vuelve a leer el claim para saber el nombre del Service: lee lo que el paso 1 dejó en el Desired State.

```gotemplate
{{- $svc := (index .desired.resources "service").resource.spec.forProvider.manifest }}
{{- $name := $svc.metadata.name }}
...
{{- $route := (index $desired "httproute").resource }}
{{- $_ := set $route.spec.forProvider.manifest.spec "hostnames" (list $hostname) }}
```

Si mañana el paso 1 cambia la convención de nombres, el paso 2 se adapta solo.

### Tres reglas que ahorran horas de depuración

1. **El pipeline corre en cada reconciliación**, no solo al crear. Debe ser determinista (nada de nombres aleatorios ni timestamps).
2. **Si un recurso desaparece del Desired State, Crossplane lo borra.** Un `if` mal puesto elimina cosas reales.
3. **El orden de los steps importa**; el orden de los recursos no (se aplican todos y convergen por reintentos).

## Comandos útiles para inspeccionar / debuggear

```bash
task crossplane:render                    # salida del pipeline sin clúster
task crossplane:render -- --include-context
khub get functions                        # INSTALLED / HEALTHY
khub -n crossplane-system logs -l pkg.crossplane.io/function=function-go-templating --tail=30
khub describe xwebapp                     # Events: errores "fatal" de funciones
```

`render` usa [render/xr.yaml](../../crossplane/render/xr.yaml). Edítalo (por ejemplo añade `hostname`) y mira cómo cambia la salida: es la forma más rápida de aprender.

## Para profundizar

- <https://docs.crossplane.io/latest/composition/compositions/>
- <https://github.com/crossplane-contrib/function-go-templating>
