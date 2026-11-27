# function-auto-ready

## ¿Qué es?

Una función mínima que marca como listos los recursos deseados cuya versión observada tiene `Ready=True`, de modo que el XR pueda pasar a `Ready`.

## ¿Qué problema resuelve?

En modo pipeline, alguien tiene que decir qué recursos están listos. Si un paso no lo hace, el XR puede quedarse en `Creating` aunque todo funcione.

## Conceptos clave

| Término | Definición |
|---|---|
| **Ready del recurso** | Condición del managed resource (la calcula su Provider). |
| **Ready deseado** | Lo que las funciones declaran sobre cada recurso. |
| **Ready del XR** | Verdadero cuando todos los compuestos lo están. |
| **Orden** | Debe ir **al final** del pipeline. |

## Cómo se usa en este POC

Step `ready` de [composition-webapp.yaml](../../crossplane/composition-webapp.yaml), sin `input`. Es importante porque el paso 2 reemite el HTTPRoute.

La calidad del resultado depende del `readiness` de cada `Object`: con el default (`SuccessfulCreate`), un Deployment en `ImagePullBackOff` se vería "listo". Por eso la Composition usa consultas CEL.

Prueba:

```bash
task example:apply FILE=<claim con una imagen inexistente>
./scripts/run.sh crossplane resource trace webapp.platform.lab.local/<nombre> -n demo --context kind-hub
# Solo el Object del Deployment aparecerá READY=False
```

## Comandos útiles para inspeccionar / debuggear

```bash
khub get xwebapp                       # columna READY
khub describe xwebapp | grep -i unready
khub get object
```

## Para profundizar

- <https://github.com/crossplane-contrib/function-auto-ready>
