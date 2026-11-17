#!/usr/bin/env bash
# ==============================================================================
# 02_setup_vm_siem.sh
# Mini-SOC TiendaCR — Proyecto 2 (ITI-922 Seguridad de TI II)
#
# Qué hace: instala Wazuh (servidor, indexador y panel) en vm-siem y aplica
# el firewall local (UFW) que solo permite el acceso del equipo administrador
# y del agente instalado en vm-objetivo.
#
# Cómo usarlo: copiar a vm-siem y correr como:
#   chmod +x 02_setup_vm_siem.sh
#   sudo ./02_setup_vm_siem.sh <IP_PUBLICA_ADMIN> <IP_PRIVADA_VM_OBJETIVO>
#
# Ejemplo:
#   sudo ./02_setup_vm_siem.sh 190.211.114.109 172.16.0.5
# ==============================================================================
set -euo pipefail

ADMIN_IP="${1:?Falta la IP pública del equipo administrador}"
VM_OBJETIVO_IP="${2:?Falta la IP privada de vm-objetivo, ej: 172.16.0.5}"

echo "==> Actualizando el sistema"
apt update && apt upgrade -y

echo "==> Descargando e instalando Wazuh (instalador oficial, todo en uno: servidor + indexador + panel)"
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
bash wazuh-install.sh -a

echo "==> Guardando las credenciales generadas en /root/wazuh-credenciales.txt (revisar y resguardar)"
echo "Las credenciales del admin del dashboard quedan en la salida del instalador."

echo "==> Configurando UFW"
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$ADMIN_IP" to any port 22
ufw allow from "$ADMIN_IP" to any port 443
ufw allow from "$VM_OBJETIVO_IP" to any port 1514
ufw allow from "$VM_OBJETIVO_IP" to any port 1515
ufw --force enable

echo "==> Listo. El panel de Wazuh queda disponible en https://<IP_PUBLICA_VM_SIEM>"
echo "    (acceso restringido por NSG de Azure y UFW solo a $ADMIN_IP)"
