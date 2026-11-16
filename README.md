 Proyecto-Seguridad — Mini SOC para TiendaCR

A basic security operations center (SOC) will be designed and operated for a fictional company: you will deploy a server with a vulnerable web application, protect it with access controls, monitor it using an IDS and a security monitoring system (SIEM/HIDS), launch a controlled attack against it, and demonstrate that your SOC detects and responds.

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

 Declaración de uso de IA

Se utilizó Claude (Anthropic) como asistente durante el desarrollo del proyecto, para: guiar la configuración paso a paso de Azure, Wazuh, Suricata y UFW; depurar errores de sintaxis en reglas personalizadas. Todas las decisiones de diseño, la ejecución de comandos y la verificación de resultados fueron realizadas por la autora.
