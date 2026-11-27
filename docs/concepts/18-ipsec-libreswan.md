# IPsec y libreswan

## ¿Qué es?

**IPsec** es un conjunto de protocolos para cifrar y autenticar tráfico en la capa IP. **libreswan** es una implementación en Linux: negocia las claves (IKE) y las instala en el kernel, que hace el cifrado (marco XFRM). Es el *cable driver* por defecto de Submariner.

## ¿Qué problema resuelve?

El tráfico entre clústeres suele cruzar redes que no controlas. Sin cifrado en el túnel, cualquier intermediario puede leerlo, salvo que cada aplicación use TLS.

## Conceptos clave

| Término | Definición |
|---|---|
| **IKE** | Negociación de claves (UDP 500/4500). |
| **PSK** | Clave precompartida; aquí viaja en `broker-info.subm`. |
| **ESP** | Protocolo que transporta los datos cifrados. |
| **SA** | Asociación de seguridad: claves y parámetros en una dirección. |
| **XFRM policy / state** | Qué tráfico cifrar / con qué claves. |
| **Modo túnel** | El paquete original entero va dentro de otro. |
| **NAT-T** | Encapsula ESP en UDP para atravesar NAT (desactivado aquí). |
| **cable driver** | Alternativas: `wireguard`, `vxlan`. |

## Cómo se usa en este POC

`--cable-driver libreswan --natt=false` en [scripts/submariner.sh](../../scripts/submariner.sh).

Lo que se ve en el nodo `hub`:

```
src 10.10.0.0/16 dst 10.20.0.0/16
    dir out
    tmpl src <nodo-hub> dst <nodo-remote>
        proto esp mode tunnel
```

con `aead rfc4106(gcm(aes))` (AES-GCM) en `ip xfrm state`.

No busques una interfaz `ipsec0`: el modo usado es *policy based*; las políticas XFRM interceptan el tráfico.

Nota: `ip xfrm state` imprime las claves de sesión. No lo compartas tal cual.

## Comandos útiles para inspeccionar / debuggear

```bash
docker exec hub-control-plane ip xfrm policy
docker exec hub-control-plane ip -s xfrm state          # ¡contiene claves!
khub -n submariner-operator logs ds/submariner-gateway --tail=40
docker exec hub-control-plane sh -c 'command -v tcpdump || (apt-get update && apt-get install -y tcpdump)'
docker exec hub-control-plane tcpdump -ni eth0 esp      # tráfico cifrado mientras haces curl
```

## Para profundizar

- <https://libreswan.org/wiki/Main_Page>
- <https://submariner.io/operations/nat-traversal/>
