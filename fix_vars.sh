#!/bin/bash
# Completa o group_vars/all.yml gerado pelo bootstrap com as secoes faltantes.
# Execute apos git pull quando o bootstrap ja foi rodado anteriormente.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS="${SCRIPT_DIR}/group_vars/all.yml"

if [ ! -f "$VARS" ]; then
    echo "ERRO: $VARS nao encontrado. Execute bootstrap.sh primeiro."
    exit 1
fi

add_if_missing() {
    local key="$1"
    local block="$2"
    if ! grep -q "^${key}:" "$VARS"; then
        echo "" >> "$VARS"
        echo "$block" >> "$VARS"
        echo "  adicionado: ${key}"
    else
        echo "  ja existe:  ${key}"
    fi
}

echo "Verificando variaveis em group_vars/all.yml..."

add_if_missing "samba" "samba:
  workgroup:    \"WORKGROUP\"
  default_pass: \"Cdpni@2025\"
  log_dir:      /var/log/samba"

add_if_missing "portal" "portal:
  dir:  /opt/cdpni-portal
  user: cdpni
  port: 5000"

add_if_missing "ssl" "ssl:
  dir:      /etc/nginx/ssl
  cert:     /etc/nginx/ssl/cdpni.crt
  key:      /etc/nginx/ssl/cdpni.key
  days:     3650
  country:  BR
  state:    SP
  org:      CDPNI"

add_if_missing "panel" "panel:
  dir:  /var/www/samba-panel
  user: admin
  pass: admin"

echo ""
echo "Pronto. Execute:"
echo "  ansible-playbook -i inventory/hosts.ini site.yml --tags samba,security,php_panel,flask_portal"
