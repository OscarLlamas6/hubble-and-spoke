# Decisiones de diseño

Cada decisión, su motivo y lo que se sacrificó.

| # | Decisión | Motivo | Alternativas descartadas / coste |
|---|---|---|---|
| 1 | **Taskfile + bash + YAML** como automatización | cada comando real queda visible y comentado; sin estado extra | **Terraform:** duplicaría el papel de Crossplane y añadiría un state; **Ansible:** no hay máquinas que configurar; **solo Makefile:** menos legible |
| 2 | CLIs fijadas en `./.bin` | reproducible y sin `sudo` | descarga inicial |
| 3 | Kubeconfig propio del repo | imposible afectar otros clústeres | hay que hacer `source scripts/env.sh` |
| 4 | Un nodo por clúster | no exige cambiar límites del kernel | no se ve el salto VXLAN hacia el gateway node |
| 5 | CIDRs distintos, sin Globalnet | datapath sin NAT, más fácil de entender | no practica CIDRs solapados |
| 6 | Cable driver libreswan | default y cifrado | depuración algo más opaca que `vxlan` |
| 7 | NodePort + `extraPortMappings` | permanente y sin procesos abiertos | no hay `LoadBalancer` como en cloud |
| 8 | Claims con XRD `v1` en Crossplane 2.x | el objetivo incluye estudiar claims | API en deprecación |
| 9 | Functions: P&T + go-templating + auto-ready | declarativo donde basta, lógica donde hace falta | tres paquetes en vez de uno |
| 10 | `backendRef` a `ServiceImport` (no FQDN) | es el camino estándar MCS y el soportado por Envoy Gateway | Envoy no ve pods individuales de `remote` |
| 11 | Todo vía `Object`, también el HTTPRoute en `hub` | un solo modelo mental y readiness CEL | requiere RBAC y un segundo ProviderConfig |
| 12 | Namespace remoto con `Orphan` | varios claims lo comparten | queda tras borrar el último claim |
| 13 | `traefik/whoami` | la respuesta dice qué pod contestó: prueba que cruzó de clúster | — |
| 14 | Commits por fase | repasar la evolución con `git log` | — |
| 15 | `Makefile` además del Taskfile | compatibilidad con la especificación original | dos puertas de entrada (una solo delega) |
