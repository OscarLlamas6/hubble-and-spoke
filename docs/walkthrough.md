# Recorrido guiado: aprende el lab fase por fase

`task up` es cómodo pero oculta el aprendizaje. Aquí vas fase a fase: **ejecutas, observas y experimentas**. Calcula 2–3 horas.

Antes de empezar:

```bash
task down            # si ya estaba levantado
task check-deps
source scripts/env.sh    # en cada terminal nueva: da khub, kremote y las CLIs fijadas
```

---

## Fase 1 — Dos clústeres

Lee [clusters/kind-hub.yaml](../clusters/kind-hub.yaml) y el concepto [kind](concepts/06-kind.md).

```bash
task clusters
docker ps                                    # los "nodos" son contenedores
khub get nodes -o wide ; kremote get nodes -o wide
khub cluster-info dump | grep -m1 -- '--cluster-cidr'
```

**Experimenta:** intenta llegar desde `hub` a un pod de `remote` por su IP. No hay ruta todavía.

```bash
kremote run web --image=traefik/whoami:v1.11.0 && kremote wait --for=condition=Ready pod/web
IP=$(kremote get pod web -o jsonpath='{.status.podIP}')
docker exec hub-control-plane curl -m 3 -s $IP || echo "sin conectividad (esperado)"
```

✅ Deberías poder explicar: por qué cada clúster tiene CIDRs distintos.

## Fase 2 — Submariner

Lee [submariner/README.md](../submariner/README.md) y [10-submariner](concepts/10-submariner.md).

```bash
task submariner
docker exec hub-control-plane curl -m 3 -s $IP        # ahora sí responde
docker exec hub-control-plane ip route show table 150
docker exec hub-control-plane ip xfrm policy
kremote delete pod web
KEEP=1 task submariner:verify
khub -n sm-test get serviceimport,endpointslices
khub -n kube-system get cm coredns -o yaml
```

**Experimenta:** borra el export y mira cómo desaparece el import.

```bash
kremote -n sm-test delete serviceexport whoami
khub -n sm-test get serviceimport
khub delete ns sm-test ; kremote delete ns sm-test
```

✅ Explica: qué viaja por el broker y qué viaja por el túnel.

## Fase 3 — Crossplane

Lee [01-crossplane](concepts/01-crossplane.md) y [05-provider-kubernetes](concepts/05-provider-kubernetes.md).

```bash
task crossplane
khub get providers,functions
khub get providerconfigs.kubernetes.crossplane.io
```

**Experimenta:** crea tu primer `Object` y provoca drift.

```bash
khub apply -f crossplane/smoke-namespace.yaml
kremote get ns crossplane-smoke-test
kremote delete ns crossplane-smoke-test      # lo borras "a mano"
kremote get ns -w                            # en menos de ~1 min reaparece (Ctrl+C)
kremote get ns crossplane-smoke-test         # Crossplane lo repuso
khub delete -f crossplane/smoke-namespace.yaml
```

✅ Explica: diferencia entre Provider y ProviderConfig.

## Fase 4 — Tu API: XRD y Composition

Lee [02](concepts/02-crossplane-compositions.md), [03](concepts/03-crossplane-claims.md), [04](concepts/04-crossplane-pipelines-functions.md) y la [Composition](../crossplane/composition-webapp.yaml) completa.

```bash
task crossplane:render        # antes de tocar el clúster
task api
khub get crd | grep platform.lab.local     # dos CRDs de un solo XRD
khub explain webapp.spec
```

**Experimenta:** añade `hostname: prueba.local` en [render/xr.yaml](../crossplane/render/xr.yaml), vuelve a renderizar y compara. Después reviértelo.

✅ Explica: qué hace cada step y qué lee el 2 de lo que produjo el 1.

## Fase 5 — Gateway API, Envoy y xDS

Lee [07](concepts/07-gateway-api.md), [08](concepts/08-envoy-gateway.md).

```bash
task gateway
khub get gatewayclass,gateway -A
khub -n envoy-gateway-system get deploy,svc,pods   # nadie escribió estos YAML
curl -i http://localhost:8080/                     # 404: no hay rutas
task xds                                           # hay listener, no hay rutas
```

**Guarda esa salida**: la compararás en la fase 6.

## Fase 6 — Un solo YAML

```bash
task example:apply
# en otra terminal mientras aplica:
watch -n1 './scripts/run.sh kubectl --context kind-hub get webapp,xwebapp,object,httproute,serviceimport -A'
```

```bash
./scripts/run.sh crossplane resource trace webapp.platform.lab.local/webapp -n demo --context kind-hub
task status
task test:v1
task xds            # ahora aparecen RDS, CDS y EDS
```

Lee [09-envoy-xds](concepts/09-envoy-xds.md) con la salida delante.

## Fase 6b — La misma plataforma en Crossplane v2

Lee [22-crossplane-v2](concepts/22-crossplane-v2.md) y compara las dos Compositions lado a lado.

```bash
task crossplane:render:v2
task example:apply:v2
task test:v2
./scripts/run.sh crossplane resource trace webappv2.platform.lab.local/webapp -n demo-v2 --context kind-hub
khub get crd | grep platform.lab.local          # 2 CRDs de v1, 1 de v2
khub -n demo-v2 get webappv2 webapp -o yaml     # mira spec.crossplane
task xds                                        # ahora hay dos virtual hosts
```

**Experimenta:** borra el HTTPRoute en `demo` y en `demo-v2` y compara cuánto tarda cada uno en volver.

✅ Explica: por qué v2 no necesita claim ni `Object` para el HTTPRoute, pero sí para `remote`.

## Fase 6c — Tests sin clúster

Lee [23-xprin](concepts/23-xprin.md).

```bash
task test:unit
```

**Experimenta:** cambia una letra del hostname por defecto en la Composition v2, vuelve a ejecutar, lee los dos fallos (hook y golden) y revierte.

✅ Explica: qué detecta `test:unit` que no detecta `test`, y al revés.

## Fase 7 — Rompe cosas

Es donde más se aprende. Cada caso está explicado en [troubleshooting.md](troubleshooting.md#escenarios-reproducidos).

| Reto | Comando | Pregunta |
|---|---|---|
| Drift | `kremote -n demo scale deploy webapp --replicas=5` | ¿cuánto tarda en volver a 2? |
| Imagen mala | cambia `image` en una copia del claim | ¿qué recurso queda `Ready=False`? |
| Sin export | pausa el `Object` y borra el `ServiceExport` | ¿qué código HTTP y qué condición? |
| Segundo claim | `task example:apply FILE=crossplane/examples/webapp-claim-minimal.yaml` | ¿qué comparten ambos? |
| Borrado | `task example:delete` | ¿qué sobrevive en `remote` y por qué? |

## Ejercicios propuestos

1. Añade al XRD un campo `env` (mapa) e inyéctalo en el contenedor.
2. Publica un status `replicasListas` leyendo el estado observado en el paso 2.
3. Añade un segundo `backendRef` con pesos para un canary.
4. Añade timeouts con `HTTPRoute.spec.rules[].timeouts`.
5. Añade a `tests/` un caso que cubra el campo `env` del ejercicio 1.
6. Cambia el cable driver a `wireguard` o `vxlan` y compara `ip xfrm` / `ip link`.
