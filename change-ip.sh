#!/bin/bash
# =============================================================================
# CDPNI — Troca de IP do servidor
# Atualiza a configuração e reaplicar apenas os roles afetados.
# Execute como root:  sudo bash change-ip.sh <novo-ip> [nova-mascara]
#
# Exemplo:
#   sudo bash change-ip.sh 172.14.29.8
#   sudo bash change-ip.sh 172.14.29.8 24
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}  ✔ $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $*${NC}"; }
err()  { echo -e "${RED}  ✘ $*${NC}"; exit 1; }
info() { echo -e "${CYAN}  → $*${NC}"; }
step() { echo -e "\n${BOLD}${BLUE}┌─ $* ${NC}"; }

[[ $EUID -ne 0 ]] && err "Execute como root: sudo bash $0 <novo-ip> [mascara]"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS_FILE="${SCRIPT_DIR}/group_vars/all.yml"

[[ -f "$VARS_FILE" ]] || err "group_vars/all.yml não encontrado. Rode o bootstrap.sh primeiro."

NOVO_IP="${1:-}"
NOVA_MASK="${2:-}"

valid_ip() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'; read -ra o <<< "$1"
    for oct in "${o[@]}"; do [[ $oct -le 255 ]] || return 1; done
}

# ── Lê configuração atual ─────────────────────────────────────────────────────
IP_ATUAL=$(grep -oP '(?<=ip:\s{1,10}")[\d.]+' "$VARS_FILE" | head -1)
MASK_ATUAL=$(grep -oP '(?<=mask:\s{1,6}")[\d]+' "$VARS_FILE" | head -1)
HOSTNAME=$(grep -oP '(?<=hostname:\s{1,4}")[\w-]+' "$VARS_FILE" | head -1)
DOMAIN=$(grep -oP '(?<=domain:\s{1,6}")[\w.-]+' "$VARS_FILE" | head -1)

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║          CDPNI — Troca de IP do servidor             ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Servidor    : ${BOLD}${HOSTNAME}.${DOMAIN}${NC}"
echo -e "  IP atual    : ${YELLOW}${IP_ATUAL}/${MASK_ATUAL}${NC}"

# ── Solicita novo IP se não passado como argumento ────────────────────────────
if [[ -z "$NOVO_IP" ]]; then
    while true; do
        echo -e "${BOLD}  Novo IP do servidor:${NC}"
        read -rp "  > " NOVO_IP
        valid_ip "$NOVO_IP" && break
        warn "IP inválido"
    done
else
    valid_ip "$NOVO_IP" || err "IP inválido: $NOVO_IP"
fi

if [[ -z "$NOVA_MASK" ]]; then
    echo -e "${BOLD}  Nova máscara CIDR [${MASK_ATUAL}]:${NC}"
    read -rp "  > " _IN
    NOVA_MASK="${_IN:-$MASK_ATUAL}"
fi

[[ "$NOVA_MASK" =~ ^[0-9]+$ ]] && [[ $NOVA_MASK -ge 1 ]] && [[ $NOVA_MASK -le 30 ]] \
    || err "Máscara inválida: $NOVA_MASK"

# Novo gateway sugerido
GW_ATUAL=$(grep -oP '(?<=gateway:\s{1,4}")[\d.]+' "$VARS_FILE" | head -1)
GW_SUG="${NOVO_IP%.*}.1"

echo -e "  Novo IP     : ${GREEN}${NOVO_IP}/${NOVA_MASK}${NC}"
echo ""
echo -e "${BOLD}  Gateway [${GW_SUG}]:${NC}"
read -rp "  > " _IN; NOVO_GW="${_IN:-$GW_SUG}"
valid_ip "$NOVO_GW" || err "Gateway inválido: $NOVO_GW"

# Nova interface (pode mudar ao migrar de rede)
IFACE_ATUAL=$(grep -oP '(?<=iface:\s{1,6}")[\w]+' "$VARS_FILE" | head -1)
echo -e "${BOLD}  Interface de rede [${IFACE_ATUAL}]:${NC}"
read -rp "  > " _IN; NOVA_IFACE="${_IN:-$IFACE_ATUAL}"

# ── Confirmação ───────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}  ┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}  │  IP antigo : ${IP_ATUAL}/${MASK_ATUAL}$(printf '%*s' $((32-${#IP_ATUAL}-${#MASK_ATUAL})) '')│${NC}"
echo -e "${YELLOW}  │  IP novo   : ${NOVO_IP}/${NOVA_MASK}$(printf '%*s' $((32-${#NOVO_IP}-${#NOVA_MASK})) '')│${NC}"
echo -e "${YELLOW}  │  Gateway   : ${NOVO_GW}$(printf '%*s' $((35-${#NOVO_GW})) '')│${NC}"
echo -e "${YELLOW}  │  Interface : ${NOVA_IFACE}$(printf '%*s' $((35-${#NOVA_IFACE})) '')│${NC}"
echo -e "${YELLOW}  └─────────────────────────────────────────────────────┘${NC}"
echo ""
warn "A sessão SSH pode cair durante a mudança de IP."
warn "Reconecte pelo novo IP: ssh root@${NOVO_IP}"
echo ""
read -rp "  Confirmar troca? [s/N]: " _C
[[ "${_C,,}" == "s" ]] || { echo "Cancelado."; exit 0; }

# ── Atualiza group_vars/all.yml ───────────────────────────────────────────────
step "Atualizando configuração"

cp "$VARS_FILE" "${VARS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
ok "Backup salvo em ${VARS_FILE}.bak.*"

sed -i "s|ip:.*\"${IP_ATUAL}\"|ip:         \"${NOVO_IP}\"|"     "$VARS_FILE"
sed -i "s|mask:.*\"${MASK_ATUAL}\"|mask:       \"${NOVA_MASK}\"|" "$VARS_FILE"
sed -i "s|gateway:.*\"${GW_ATUAL}\"|gateway:    \"${NOVO_GW}\"|"  "$VARS_FILE"
sed -i "s|iface:.*\"${IFACE_ATUAL}\"|iface:      \"${NOVA_IFACE}\"|" "$VARS_FILE"
ok "group_vars/all.yml atualizado"

# ── Remove certificado para forçar regeneração com novo IP no SAN ─────────────
step "Renovando certificado SSL"
rm -f /etc/nginx/ssl/cdpni.crt /etc/nginx/ssl/cdpni.key 2>/dev/null || true
ok "Certificado antigo removido (será regenerado com novo IP)"

# ── Reaplica apenas os roles afetados ─────────────────────────────────────────
step "Reaplicando Ansible (network + security + samba)"
echo ""

cd "${SCRIPT_DIR}"
ansible-playbook -i inventory/hosts.ini site.yml \
    --tags network,security,samba \
    --diff \
    2>&1 | tee /var/log/cdpni_change_ip.log

echo ""
ok "Log completo em /var/log/cdpni_change_ip.log"

# ── Instruções finais ─────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║                  PRÓXIMOS PASSOS                    ║${NC}"
echo -e "${CYAN}  ╠══════════════════════════════════════════════════════╣${NC}"
printf  "${CYAN}  ║${NC}  %-51s${CYAN}║${NC}\n" "No gateway GWOS, atualize o DNS:"
printf  "${CYAN}  ║${NC}  ${BOLD}%-51s${NC}${CYAN}║${NC}\n" "  gwos dns update ${HOSTNAME} ${NOVO_IP}"
printf  "${CYAN}  ║${NC}  %-51s${CYAN}║${NC}\n" ""
printf  "${CYAN}  ║${NC}  %-51s${CYAN}║${NC}\n" "Novo acesso ao servidor:"
printf  "${CYAN}  ║${NC}  ${GREEN}%-51s${NC}${CYAN}║${NC}\n" "  https://${NOVO_IP}"
printf  "${CYAN}  ║${NC}  ${GREEN}%-51s${NC}${CYAN}║${NC}\n" "  https://${HOSTNAME}.${DOMAIN}"
printf  "${CYAN}  ║${NC}  ${GREEN}%-51s${NC}${CYAN}║${NC}\n" "  \\\\${NOVO_IP}  (Windows)"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════╝${NC}"
echo ""
