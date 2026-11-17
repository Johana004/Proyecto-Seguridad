#!/usr/bin/env bash
# ==============================================================================
# 05_remediacion_reevaluacion.sh
# Mini-SOC TiendaCR — Proyecto 2 (ITI-922 Seguridad de TI II)
#
# Qué hace: aplica la remediación real usada en el proyecto (actualización de
# paquetes del sistema operativo en vm-objetivo, según los hallazgos del
# módulo de detección de vulnerabilidades y SCA de Wazuh) y deja lista la
# comparación antes/después repitiendo los ataques 2 y 3.
#
# Cómo usarlo (dentro de vm-objetivo):
#   chmod +x 05_remediacion_reevaluacion.sh
#   sudo ./05_remediacion_reevaluacion.sh
#
# Después de correrlo, repetir desde Kali:
#   ./04_ataques.sh <IP_PUBLICA_VM_OBJETIVO>
# (solo los ataques 2 y 3) y comparar los resultados con los registrados
# antes del parche (ver sección "Remediación y reevaluación" del informe
# y del README).
# ==============================================================================
set -euo pipefail

echo "==> Paquetes pendientes de actualización ANTES del parche:"
apt update
apt list --upgradable

read -r -p "¿Continuar con la actualización (apt upgrade -y)? (s/n) " RESP
if [[ "$RESP" != "s" ]]; then
  echo "Cancelado."
  exit 0
fi

echo "==> Aplicando actualizaciones de seguridad pendientes"
apt upgrade -y

echo "==> Verificando que ya no queden paquetes pendientes"
apt list --upgradable

if [ -f /var/run/reboot-required ]; then
  echo "==> El sistema requiere reinicio (actualización de kernel). Reiniciar con: sudo reboot"
else
  echo "==> No se requiere reinicio (no se actualizó el kernel)."
fi

echo "=============================================================="
echo "Remediación aplicada. Siguiente paso: repetir los ataques 2"
echo "(fuerza bruta) y 3 (inyección SQL) desde Kali con 04_ataques.sh"
echo "y comparar la detección/respuesta con los resultados previos al parche."
echo ""
echo "Nota esperada: la detección y la respuesta automática NO deberían"
echo "cambiar, porque dependen del patrón de tráfico (reglas de Suricata y"
echo "Wazuh), no de la versión de los paquetes del SO. La inyección SQL"
echo "tampoco se cierra con este parche, porque es una vulnerabilidad de"
echo "la aplicación (DVWA), no del sistema operativo."
echo "=============================================================="
