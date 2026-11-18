Proyecto-Seguridad — Mini SOC para TiendaCR

Se diseñará y pondrá en funcionamiento un centro de operaciones de seguridad (SOC) básico para una empresa ficticia: instalarás un servidor con una aplicación web vulnerable, lo protegerás con controles de acceso, lo supervisarás mediante un IDS y un sistema de monitoreo de seguridad (SIEM/HIDS), lanzarás un ataque controlado contra él y demostrarás que tu SOC detecta y responde

 Autoría

Este proyecto fue realizado de forma individual, sin pareja asignada en el curso. Todo el diseño, la implementación, los ataques y la documentación son trabajo propio.

 Arquitectura

El escenario es la tienda en línea ficticia "TiendaCR". La arquitectura consta de tres máquinas:

| Componente | Función | Entorno |
|---|---|---|
| Máquina atacante | Kali Linux, origen de los ataques controlados | VirtualBox (laptop local) |
| Servidor objetivo (`vm-objetivo`) | Ubuntu 22.04, aplicación web vulnerable (DVWA) en Docker, IDS (Suricata) y agente de monitoreo (Wazuh) | Azure (Azure for Students) |
| Servidor SIEM (`vm-siem`) | Ubuntu 22.04, Wazuh (servidor, indexador y panel) | Azure (Azure for Students) |

Las dos VM de Azure están en la misma red virtual privada (`172.16.0.0/24`). El acceso desde internet está restringido únicamente a la IP del equipo, mediante grupos de seguridad de Azure (NSG) y firewall local (UFW) en cada VM, con política de denegación por defecto.

 Requisitos para reproducir el entorno

- Cuenta de Azure (se usó Azure for Students)
- VirtualBox con la imagen preconstruida de Kali Linux
- Cliente SSH (incluido en Windows 11)
- Acceso a internet con IP fija o verificable, para las reglas de firewall

 Despliegue (resumen)

1. Crear grupo de recursos y red virtual en Azure.
2. Crear `vm-siem` (Ubuntu 22.04 LTS, 2 vCPU / 8 GiB RAM) e instalar Wazuh con el instalador oficial (versión 4.14).
3. Crear `vm-objetivo` (mismas specs) en la misma red virtual.
4. En `vm-objetivo`: instalar Docker y levantar DVWA (`vulnerables/web-dvwa`) en el puerto 80.
5. En `vm-objetivo`: instalar Suricata 8.0.8 (repositorio OISF), configurar `HOME_NET` y el agente de Wazuh para leer `eve.json`.
6. Instalar el agente de Wazuh en `vm-objetivo`, apuntando a la IP privada del SIEM.
7. Configurar UFW en ambas VM (ver tabla de reglas abajo).

Este resumen está automatizado en los scripts de la carpeta [`scripts/`](scripts/) (ver más abajo "Cómo reproducir el entorno paso a paso"), junto con los archivos de configuración de [`configs/`](configs/) y las reglas propias de [`rules/`](rules/) y [`configs/local_rules.xml`](configs/local_rules.xml).

 Reglas de firewall (control de acceso)

| Capa | Regla | Justificación | Riesgo que mitiga |
|---|---|---|---|
| NSG `vm-siem` | Entrada denegada por defecto | Denegación por defecto | Acceso no autorizado desde internet |
| NSG `vm-siem` | 22/TCP solo desde la IP del equipo | Menor privilegio | Fuerza bruta SSH desde cualquier IP |
| NSG `vm-siem` | 443/TCP solo desde la IP del equipo | El panel solo lo ve quien administra | Exposición del panel a internet |
| NSG `vm-objetivo` | 22/TCP y 80/TCP solo desde la IP del equipo | Menor privilegio | Acceso no autorizado a la app y SSH |
| UFW `vm-siem` | Deny incoming por defecto; allow 22, 443 (IP equipo); allow 1514, 1515 (IP privada del agente) | Denegación por defecto + solo el agente autorizado | Agentes falsos, inyección de eventos |
| UFW `vm-objetivo` | Deny incoming por defecto; allow 22, 80 (IP equipo) | Denegación por defecto en el host | Exposición de servicios no previstos |

> Nota técnica: al publicar un puerto, Docker inserta sus propias reglas en iptables y se salta a UFW. El control efectivo del puerto 80 (DVWA) es el grupo de seguridad de Azure.

 Herramientas instaladas

- **Wazuh 4.14.10** — SIEM/HIDS (servidor, indexador, panel, agente)
- **Suricata 8.0.8** — IDS de red, reglas ET Open + reglas propias
- **DVWA** (`vulnerables/web-dvwa`) — aplicación web vulnerable, Apache 2.4.25

 Reglas propias

| Archivo | Herramienta | Detecta |
|---|---|---|
| `rules/local.rules` | Suricata | Inyección SQL (UNION SELECT en URI) — `sid:1000001` |
| `rules/local.rules` | Suricata | Fuerza bruta web, 5+ POST en 10s por IP — `sid:1000002` |
| `configs/local_rules.xml` | Wazuh | Fuerza bruta web (basada en logs de Apache) — reglas `100100`/`100101` |

 Ataques realizados

|  | Ataque | Herramienta | Detección | Técnica MITRE |
|---|---|---|---|---|
| 1 | Escaneo de puertos y servicios | Nmap | ET SCAN Nmap Scripting Engine (Suricata) | T1046 |
| 2 | Fuerza bruta contra login de DVWA | Hydra | Regla propia Suricata + regla propia Wazuh | T1110 |
| 3 | Inyección SQL (UNION SELECT) | curl / navegador | Regla propia Suricata | T1190 |
| 4 | Persistencia vía cron (modificación de archivo) | manual | Wazuh FIM (regla 554) | T1053.003 |

 Respuesta automática

Wazuh ejecuta `firewall-drop` (Active Response) cuando se dispara la regla propia `100101` (fuerza bruta), bloqueando la IP de origen en `vm-objetivo` durante 300 segundos. Se verificó en pruebas reales: el ataque de fuerza bruta provocó el bloqueo de la IP del equipo, confirmado por la pérdida de conectividad SSH y HTTP, y la recuperación automática pasado el tiempo configurado.

Riesgo documentado: una respuesta automática puede bloquear tráfico legítimo (incluido el del propio administrador), como se demostró en la prueba.

 Remediación y reevaluación

El módulo de detección de vulnerabilidades de Wazuh encontró en `vm-objetivo` 19 vulnerabilidades críticas, 617 altas, 1217 medias y 211 bajas (concentradas en `linux-azure` y `lxd`), y la evaluación de configuración (SCA) contra el benchmark CIS Ubuntu 22.04 LTS dio un puntaje de 49% (98 controles aprobados, 99 fallidos).

Como remediación inmediata se aplicaron las actualizaciones de seguridad pendientes del sistema operativo en `vm-objetivo`:

```
sudo apt update
apt list --upgradable   # distro-info, python3-distro-info, sosreport
sudo apt upgrade -y
```

El kernel ya estaba al día, por lo que no fue necesario reiniciar la VM. Tras el parche se repitieron los ataques 2 (fuerza bruta) y 3 (inyección SQL) con los mismos parámetros, para comparar la detección antes y después:

| Ataque | Antes del parche | Después del parche |
|---|---|---|
| Inyección SQL (UNION SELECT) | Detectada por `sid:1000001` (13/nov/2026) | Detectada de nuevo por `sid:1000001` + regla ET por defecto (17/nov/2026, 14:30–14:34 UTC) |
| Fuerza bruta (Hydra) | Detectada por reglas 100100/100101; Active Response bloqueó la IP | Comportamiento idéntico: reglas 100100/100101 se dispararon de nuevo (14:50:43 UTC) y el Active Response volvió a bloquear la IP |

**Conclusión:** la detección y la respuesta automática no se vieron afectadas por el parche del sistema operativo, porque las reglas detectan el patrón del tráfico de ataque y no dependen de la versión de los paquetes del SO. El parche tampoco cerró la inyección SQL en sí, ya que esa vulnerabilidad vive en la aplicación (DVWA), no en el sistema operativo — DVWA está hecha a propósito para seguir siendo vulnerable.

**Riesgo residual (matriz de riesgos actualizada).** Después del parche, se volvió a revisar el módulo de detección de vulnerabilidades y el SCA de Wazuh sobre `vm-objetivo`, para actualizar con datos reales los dos riesgos de la matriz de riesgos directamente afectados:

| Métrica (Wazuh, `vm-objetivo`) | Antes del parche (13/nov) | Después del parche (17/nov, 21:37 UTC) | Cambio |
|---|---|---|---|
| Vulnerabilidades críticas | 19 | 17 | -2 |
| Vulnerabilidades altas | 617 | 619 | +2 |
| Vulnerabilidades medias | 1217 | 1215 | -2 |
| Vulnerabilidades bajas | 211 | 211 | Sin cambio |
| Paquete `linux-azure` (kernel) | 2555 | 2555 | Sin cambio |
| Paquete `lxd` | 11 | 11 | Sin cambio |
| Puntaje SCA (CIS Ubuntu 22.04 LTS) | 49% (98 aprobados / 99 fallidos) | 49% (98 aprobados / 99 fallidos) | Sin cambio |

| Riesgo | Riesgo inicial (Fase 1) | Riesgo residual (después de 2.8) | Justificación |
|---|---|---|---|
| R12 — Actualizaciones de seguridad pendientes | Probabilidad media, impacto alto | Probabilidad media, impacto alto — **prácticamente sin cambio** | Se parcharon los 3 únicos paquetes pendientes (`distro-info`, `python3-distro-info`, `sosreport`), lo que bajó las críticas de 19 a 17, pero el 99.6% de los hallazgos (2,555 de 2,566) siguen siendo del kernel `linux-azure`, que no se pudo actualizar porque el sistema ya estaba en la última versión disponible por ese canal |
| R1 — Software desactualizado (Apache 2.4.25 / DVWA, inyección SQL) | Probabilidad alta, impacto alto | Probabilidad alta, impacto alto — **sin cambio** | Apache no estaba entre los paquetes actualizados; se confirmó repitiendo el ataque 3, que extrajo los mismos datos antes y después del parche |

El puntaje SCA (49% antes y después, mismos 99 controles fallidos, como la falta de `nodev/nosuid/noexec` en `/tmp` y `/var`) confirma que la remediación fue de parcheo de paquetes, no de hardening de configuración — ese trabajo queda pendiente para un próximo ciclo, junto con la actualización del kernel cuando Azure la publique.

 Cómo reproducir el entorno paso a paso

Toda la configuración manual descrita arriba quedó automatizada en scripts, para que el entorno se pueda reconstruir corriendo comandos en lugar de copiarlos a mano. Orden sugerido:

| Paso | Script | Dónde se corre | Qué hace |
|---|---|---|---|
| 1 | [`scripts/01_setup_vm_objetivo.sh`](scripts/01_setup_vm_objetivo.sh) | `vm-objetivo` | Instala Docker + DVWA, Suricata con `rules/local.rules`, UFW y el agente de Wazuh |
| 2 | [`scripts/02_setup_vm_siem.sh`](scripts/02_setup_vm_siem.sh) | `vm-siem` | Instala Wazuh (servidor, indexador, panel) y UFW |
| 3 | [`scripts/03_configurar_reglas_wazuh.sh`](scripts/03_configurar_reglas_wazuh.sh) | `vm-siem` | Instala `configs/local_rules.xml` (reglas 100100/100101) y guía la adición del bloque de Active Response de `configs/active-response-snippet.xml` |
| 4 | [`scripts/04_ataques.sh`](scripts/04_ataques.sh) | Kali (atacante) | Ejecuta, uno por uno con pausas, los 4 ataques controlados (Nmap, Hydra, inyección SQL, persistencia vía cron) |
| 5 | [`scripts/05_remediacion_reevaluacion.sh`](scripts/05_remediacion_reevaluacion.sh) | `vm-objetivo` | Aplica el parche de sistema operativo y deja lista la comparación antes/después repitiendo los ataques 2 y 3 |

Cada script pide los parámetros que necesita (IPs) como argumentos y muestra en pantalla qué está haciendo antes de ejecutarlo. Los dos primeros requieren permisos de superusuario (`sudo`).

Diagramas, configuraciones y capturas de referencia:

- **Diagramas**: [`arquitectura_red_detallada.png`](arquitectura_red_detallada.png) (arquitectura completa de las 3 máquinas y sus componentes internos), [`flujo_deteccion_respuesta.png`](flujo_deteccion_respuesta.png) (flujo de detección y respuesta ante fuerza bruta) y [`remediacion_reevaluacion.png`](remediacion_reevaluacion.png) (flujo de la fase de remediación y reevaluación).
- **Archivos de configuración**: [`configs/local_rules.xml`](configs/local_rules.xml) (reglas Wazuh) y [`configs/active-response-snippet.xml`](configs/active-response-snippet.xml) (Active Response).
- **Reglas propias**: [`rules/local.rules`](rules/local.rules) (Suricata).
- **Scripts**: carpeta [`scripts/`](scripts/), descritos en la tabla de arriba.
- **Capturas**: ver carpeta de capturas del proyecto (evidencia de cada ataque, cada detección y la reevaluación post-parche), adjuntas en la entrega del informe.

 Declaración de uso de IA

Se utilizó Claude (Anthropic) como asistente durante el desarrollo del proyecto, para: guiar la configuración paso a paso de Azure, Wazuh, Suricata y UFW; depurar errores de sintaxis en reglas personalizadas. Todas las decisiones de diseño, la ejecución de comandos y la verificación de resultados fueron realizadas por la autora.
