#!/usr/bin/env bash
# ==============================================================================
# 03_configurar_reglas_wazuh.sh
# Mini-SOC TiendaCR — Proyecto 2 (ITI-922 Seguridad de TI II)
#
# Qué hace: instala en vm-siem la regla propia de Wazuh para fuerza bruta web
# (100100/100101, basada en logs de Apache de DVWA) y la respuesta automática
# (Active Response con firewall-drop) asociada a la regla 100101.
#
# Requiere: configs/local_rules.xml y configs/active-response-snippet.xml
# (incluidos en este repo).
#
# Cómo usarlo: copiar este script junto con la carpeta configs/ a vm-siem y
# correr como:
#   chmod +x 03_configurar_reglas_wazuh.sh
#   sudo ./03_configurar_reglas_wazuh.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs"

echo "==> Respaldando configuración actual de Wazuh"
cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.bak 2>/dev/null || true
cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak

echo "==> Instalando reglas propias (100100/100101 — fuerza bruta web)"
cp "$CONFIGS_DIR/local_rules.xml" /var/ossec/etc/rules/local_rules.xml

echo "==> Agregando el bloque de Active Response (firewall-drop sobre la regla 100101)"
echo "    Revisar manualmente que el bloque de abajo esté dentro de <ossec_config> en ossec.conf:"
echo "    -------------------------------------------------------------"
cat "$CONFIGS_DIR/active-response-snippet.xml"
echo "    -------------------------------------------------------------"
read -r -p "¿El bloque ya fue agregado a /var/ossec/etc/ossec.conf? (s/n) " RESP
if [[ "$RESP" != "s" ]]; then
  echo "Abrir /var/ossec/etc/ossec.conf, pegar el bloque de arriba dentro de <ossec_config>, y volver a correr este script o reiniciar manualmente el manager."
  exit 1
fi

echo "==> Validando sintaxis de las reglas"
/var/ossec/bin/wazuh-logtest -t </dev/null || true

echo "==> Reiniciando el manager de Wazuh"
systemctl restart wazuh-manager

echo "==> Listo. Verificar con: tail -f /var/ossec/logs/ossec.log"
echo "    Las reglas se pueden probar disparando el ataque de fuerza bruta (ver 04_ataque_fuerza_bruta.sh)"
