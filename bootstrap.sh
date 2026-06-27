#!/bin/bash
# =============================================================================
# CDPNI — Bootstrap
# Detecta rede/discos, coleta configuração e executa o Ansible playbook.
# Execute como root:  sudo bash bootstrap.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
DIM='\033[2m'

banner() {
cat << 'BANNER'

   ██████╗██████╗ ██████╗ ███╗   ██╗██╗
  ██╔════╝██╔══██╗██╔══██╗████╗  ██║██║
  ██║     ██║  ██║██████╔╝██╔██╗ ██║██║
  ██║     ██║  ██║██╔═══╝ ██║╚██╗██║██║
  ╚██████╗██████╔╝██║     ██║ ╚████║██║
   ╚═════╝╚═════╝ ╚═╝     ╚═╝  ╚═══╝╚═╝

BANNER
echo -e "${CYAN}  Servidor de Arquivos Samba — Instalador Ansible${NC}"
echo -e "${DIM}  RAID · Samba 4 · Portal Web · Painel Admin${NC}"
echo ""
}

step()  { echo -e "\n${BOLD}${BLUE}┌─ $* ${NC}"; }
ok()    { echo -e "${GREEN}  ✔ $*${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ $*${NC}"; }
err()   { echo -e "${RED}  ✘ $*${NC}"; exit 1; }
info()  { echo -e "${CYAN}  → $*${NC}"; }
ask()   { echo -e "${BOLD}  $*${NC}"; }

[[ $EUID -ne 0 ]] && err "Execute como root: sudo bash $0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

banner

# =============================================================================
# PRÉ-REQUISITOS
# =============================================================================
step "Verificando pré-requisitos"

command -v python3 &>/dev/null || { apt-get install -y -qq python3; ok "python3 instalado"; }
ok "python3 $(python3 --version | cut -d' ' -f2)"

if ! command -v ansible-playbook &>/dev/null; then
    info "Instalando Ansible..."
    apt-get update -qq
    apt-get install -y -qq ansible
fi
ok "ansible $(ansible --version | head -1 | grep -oP '[\d.]+')"

# =============================================================================
# DETECÇÃO DE REDE
# =============================================================================
step "Interfaces de rede detectadas"

echo ""
printf "  ${CYAN}%-5s %-14s %-18s %-6s %-20s${NC}\n" "Nº" "INTERFACE" "IP ATUAL" "CIDR" "REDE"
echo -e "  ${DIM}$(printf '─%.0s' {1..68})${NC}"

declare -A IFACE_IP IFACE_CIDR
declare -a IFACE_LIST=()

while IFS= read -r _line; do
    _iface=$(awk '{print $1}' <<< "$_line")
    _cidr=$(awk '{print $2}' <<< "$_line")
    _ip="${_cidr%%/*}"; _prefix="${_cidr##*/}"
    _net=$(python3 -c "import ipaddress; print(str(ipaddress.ip_interface('${_cidr}').network))" 2>/dev/null || echo "-")
    IFACE_LIST+=("$_iface")
    IFACE_IP[$_iface]="$_ip"
    IFACE_CIDR[$_iface]="$_prefix"
    _idx=${#IFACE_LIST[@]}
    printf "  ${GREEN}[%-2s]${NC} %-14s %-18s /%-5s %-20s\n" "$_idx" "$_iface" "$_ip" "$_prefix" "$_net"
done < <(ip -4 addr show 2>/dev/null | awk '
    /^[0-9]+:/ { iface=$2; gsub(/:$/,"",iface) }
    /inet / {
        ip=$2
        if (ip ~ /^10\./ || ip ~ /^172\.(1[6-9]|2[0-9]|3[01])\./ || ip ~ /^192\.168\./)
            print iface, ip
    }
' | grep -v '^lo ')

# Verifica se detectou alguma interface
if [[ ${#IFACE_LIST[@]} -eq 0 ]]; then
    warn "Nenhuma interface privada detectada."
    echo ""
    ask "Informe manualmente a interface de rede (ex: eth0, ens18):"
    read -rp "  > " _MANUAL_IFACE
    SERVER_IFACE="${_MANUAL_IFACE:-eth0}"
    _BEST_IP=""; _BEST_MASK="24"
    IFACE_LIST+=("$SERVER_IFACE")
    IFACE_IP[$SERVER_IFACE]=""
    IFACE_CIDR[$SERVER_IFACE]="24"
else
    # Escolha de interface
    echo ""
    if [[ ${#IFACE_LIST[@]} -eq 1 ]]; then
        SERVER_IFACE="${IFACE_LIST[0]}"
        _BEST_IP="${IFACE_IP[$SERVER_IFACE]}"
        _BEST_MASK="${IFACE_CIDR[$SERVER_IFACE]}"
        info "Usando interface ${SERVER_IFACE} (única detectada)"
    else
        # Pré-seleciona a melhor (preferência: 192.168.x > 172.x > 10.x)
        _BEST_IDX=1
        for _i in "${!IFACE_LIST[@]}"; do
            _ip="${IFACE_IP[${IFACE_LIST[$_i]}]}"
            if echo "$_ip" | grep -qE '^192\.168\.'; then
                _BEST_IDX=$(( _i + 1 )); break
            elif echo "$_ip" | grep -qE '^172\.(1[6-9]|2[0-9]|3[01])\.'; then
                _BEST_IDX=$(( _i + 1 ))
            fi
        done

        echo ""
        while true; do
            ask "Selecione a interface de rede a usar [${_BEST_IDX}]:"
            read -rp "  > " _IN
            _SEL_IDX="${_IN:-$_BEST_IDX}"
            if [[ "$_SEL_IDX" =~ ^[0-9]+$ ]] && \
               [[ $_SEL_IDX -ge 1 ]] && \
               [[ $_SEL_IDX -le ${#IFACE_LIST[@]} ]]; then
                SERVER_IFACE="${IFACE_LIST[$((_SEL_IDX-1))]}"
                _BEST_IP="${IFACE_IP[$SERVER_IFACE]}"
                _BEST_MASK="${IFACE_CIDR[$SERVER_IFACE]}"
                break
            fi
            warn "Número inválido. Digite entre 1 e ${#IFACE_LIST[@]}"
        done
    fi
fi

ok "Interface selecionada: ${SERVER_IFACE}  (IP atual: ${_BEST_IP:-não configurado})"

# Sugestão de IP para o servidor (.11 na mesma sub-rede)
if [[ -n "${_BEST_IP:-}" ]]; then
    _NET_PFX="${_BEST_IP%.*}"
    _IP_SUG="${_NET_PFX}.11"
else
    _IP_SUG="192.168.0.11"
    _BEST_MASK="24"
fi

# =============================================================================
# DETECÇÃO DE DISCOS
# =============================================================================
step "Discos detectados"

_SRC=$(findmnt -n -o SOURCE / 2>/dev/null || echo "")
_PKNAME=$(lsblk -no PKNAME "$_SRC" 2>/dev/null | head -1 || true)
SYS_DISK="/dev/${_PKNAME:-$(basename "${_SRC:-sda}" | sed 's/[0-9]*$//')}"

echo ""
printf "  ${CYAN}%-5s %-12s %-10s %-24s %-10s${NC}\n" "Nº" "DISPOSITIVO" "TAMANHO" "MODELO" "STATUS"
echo -e "  ${DIM}$(printf '─%.0s' {1..65})${NC}"

declare -a AVAIL_DISKS=()
while IFS= read -r _disk; do
    _size=$(lsblk -dno SIZE "$_disk" 2>/dev/null || echo "?")
    _model=$(cat /sys/block/"$(basename "$_disk")"/device/model 2>/dev/null | xargs 2>/dev/null || echo "N/D")
    if [[ "$_disk" == "$SYS_DISK" ]]; then
        printf "  ${YELLOW}%-5s %-12s %-10s %-24s %-10s${NC}\n" "[SO]" "$_disk" "$_size" "${_model:0:22}" "Sistema"
    else
        AVAIL_DISKS+=("$_disk")
        _idx=${#AVAIL_DISKS[@]}
        printf "  ${GREEN}%-5s${NC} %-12s %-10s %-24s %-10s\n" "[$_idx]" "$_disk" "$_size" "${_model:0:22}" "Disponível"
    fi
done < <(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}' | sort)

[[ ${#AVAIL_DISKS[@]} -eq 0 ]] && err "Nenhum disco disponível para o RAID"

# =============================================================================
# CONFIGURAÇÃO INTERATIVA
# =============================================================================
step "Configuração"
echo ""

valid_ip() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'; read -ra o <<< "$ip"
    for oct in "${o[@]}"; do [[ $oct -le 255 ]] || return 1; done
    return 0
}

valid_pass() {
    local p="$1"
    [[ ${#p} -ge 8 ]] || return 1
    [[ "$p" =~ [A-Z] ]] || return 1
    [[ "$p" =~ [a-z] ]] || return 1
    [[ "$p" =~ [0-9] ]] || return 1
    return 0
}

# IP do servidor
while true; do
    ask "IP fixo do servidor [${_IP_SUG}]:"
    read -rp "  > " _IN; SAMBA_IP="${_IN:-$_IP_SUG}"
    valid_ip "$SAMBA_IP" && break
    warn "IP inválido"
done

# Máscara
while true; do
    ask "Máscara CIDR [${_BEST_MASK}]:"
    read -rp "  > " _IN; SAMBA_MASK="${_IN:-$_BEST_MASK}"
    [[ "$SAMBA_MASK" =~ ^[0-9]+$ ]] && [[ $SAMBA_MASK -ge 1 ]] && [[ $SAMBA_MASK -le 30 ]] && break
    warn "CIDR inválido (1-30)"
done

# Gateway
_GW_SUG="${SAMBA_IP%.*}.1"
while true; do
    ask "Gateway [${_GW_SUG}]:"
    read -rp "  > " _IN; GATEWAY="${_IN:-$_GW_SUG}"
    valid_ip "$GATEWAY" && break
    warn "Gateway inválido"
done

# DNS
ask "DNS (Enter = gateway) [${GATEWAY}]:"
read -rp "  > " _IN; DNS="${_IN:-$GATEWAY}"

# Hostname
while true; do
    ask "Nome do servidor [cdpni]:"
    read -rp "  > " _IN; HOSTNAME="${_IN:-cdpni}"
    [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] && break
    warn "Hostname inválido (letras, dígitos, hífen)"
done

# Domínio
ask "Domínio local [cdpni.local]:"
read -rp "  > " _IN; DOMAIN="${_IN:-cdpni.local}"

# Admin user
while true; do
    ask "Login do administrador [sambadmin]:"
    read -rp "  > " _IN; ADMIN_USER="${_IN:-sambadmin}"
    [[ "$ADMIN_USER" =~ ^[a-z][a-z0-9_-]{1,31}$ ]] && break
    warn "Username inválido (letras minúsculas, dígitos, _, -)"
done

# Senha do Samba (digitada, não exibida)
echo ""
echo -e "  ${DIM}Requisitos: mínimo 8 caracteres, letras maiúsculas, minúsculas e números.${NC}"
while true; do
    ask "Senha padrão dos usuários Samba:"
    read -rsp "  > " SAMBA_PASS; echo ""
    if ! valid_pass "$SAMBA_PASS"; then
        warn "Senha fraca. Use ao menos 8 chars com maiúsc., minúsc. e número."
        continue
    fi
    ask "Confirme a senha:"
    read -rsp "  > " _PASS2; echo ""
    [[ "$SAMBA_PASS" == "$_PASS2" ]] && break
    warn "Senhas não coincidem"
done
ok "Senha Samba definida"

# Senha do painel web (digitada, não exibida)
echo ""
while true; do
    ask "Senha do painel web (admin) [porta 8443]:"
    read -rsp "  > " PANEL_PASS; echo ""
    if ! valid_pass "$PANEL_PASS"; then
        warn "Senha fraca. Use ao menos 8 chars com maiúsc., minúsc. e número."
        continue
    fi
    ask "Confirme a senha:"
    read -rsp "  > " _PASS2; echo ""
    [[ "$PANEL_PASS" == "$_PASS2" ]] && break
    warn "Senhas não coincidem"
done
ok "Senha do painel definida"

# Seleção de discos para RAID
echo ""
ask "Discos para o RAID (números separados por espaço, Enter = todos):"
echo -e "${DIM}  Disponíveis: $(IFS=' '; echo "${AVAIL_DISKS[*]}")${NC}"
while true; do
    read -rp "  > " _SEL
    RAID_DISKS=()
    if [[ -z "$_SEL" ]]; then
        RAID_DISKS=("${AVAIL_DISKS[@]}")
    else
        _ok=true
        for _n in $_SEL; do
            if [[ "$_n" =~ ^[0-9]+$ ]] && [[ $_n -ge 1 ]] && [[ $_n -le ${#AVAIL_DISKS[@]} ]]; then
                RAID_DISKS+=("${AVAIL_DISKS[$((_n-1))]}")
            else
                warn "Número inválido: $_n"; _ok=false; break
            fi
        done
        [[ "$_ok" == false ]] && continue
        mapfile -t RAID_DISKS < <(printf '%s\n' "${RAID_DISKS[@]}" | awk '!seen[$0]++')
    fi
    [[ ${#RAID_DISKS[@]} -ge 2 ]] && break
    warn "Mínimo 2 discos"
done

# Nível RAID
N=${#RAID_DISKS[@]}
echo ""
echo -e "  ${BOLD}Níveis disponíveis para ${N} disco(s):${NC}"
declare -a RAID_OPTS=()
[[ $N -ge 2 ]] && { RAID_OPTS+=(1);  echo -e "  ${CYAN}[1]${NC}  RAID 1  — espelho        capacidade: 1×disco   tolera: $((N-1)) falha(s)"; }
[[ $N -ge 3 ]] && { RAID_OPTS+=(5);  echo -e "  ${CYAN}[5]${NC}  RAID 5  — paridade        capacidade: $((N-1))×disco   tolera: 1 falha"; }
[[ $N -ge 4 ]] && { RAID_OPTS+=(6);  echo -e "  ${CYAN}[6]${NC}  RAID 6  — dupla paridade  capacidade: $((N-2))×disco   tolera: 2 falhas"; }
(( N >= 4 && N % 2 == 0 )) && { RAID_OPTS+=(10); echo -e "  ${CYAN}[10]${NC} RAID 10 — espelho+stripe  capacidade: $((N/2))×disco   tolera: 1/par"; }
[[ $N -ge 4 ]] && _DEF_RAID=5 || _DEF_RAID=1

while true; do
    ask "Nível de RAID [${_DEF_RAID}]:"
    read -rp "  > " _IN; RAID_LEVEL="${_IN:-$_DEF_RAID}"
    _found=false
    for _o in "${RAID_OPTS[@]}"; do [[ "$_o" == "$RAID_LEVEL" ]] && _found=true && break; done
    [[ "$_found" == true ]] && break
    warn "Nível inválido para ${N} disco(s). Opções: ${RAID_OPTS[*]}"
done

# Atualiza SERVER_IFACE caso o IP digitado seja de outra sub-rede
for _if in "${!IFACE_IP[@]}"; do
    _net_pfx="${IFACE_IP[$_if]%.*}"
    [[ "${SAMBA_IP%.*}" == "$_net_pfx" ]] && SERVER_IFACE="$_if"
done

# =============================================================================
# CONFIRMAÇÃO
# =============================================================================
echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║              CONFIGURAÇÃO A SER APLICADA             ║${NC}"
echo -e "${CYAN}  ╠══════════════════════════════════════════════════════╣${NC}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "IP / Máscara:"   "${SAMBA_IP}/${SAMBA_MASK}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "Gateway:"         "${GATEWAY}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "DNS:"             "${DNS}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "Interface:"       "${SERVER_IFACE}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "Hostname:"        "${HOSTNAME}.${DOMAIN}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "Admin:"           "${ADMIN_USER}"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "Senha Samba:"     "$(printf '*%.0s' {1..${#SAMBA_PASS}})"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "Senha Painel:"    "$(printf '*%.0s' {1..${#PANEL_PASS}})"
printf  "${CYAN}  ║${NC}  %-24s %-27s${CYAN}║${NC}\n" "RAID ${RAID_LEVEL}:" "$(IFS=', '; echo "${RAID_DISKS[*]}")"
echo -e "${CYAN}  ╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}  ║${NC}  ${RED}⚠  TODOS OS DADOS NOS DISCOS SERÃO APAGADOS!${NC}       ${CYAN}║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════╝${NC}"
echo ""
read -rp "  Iniciar instalação? [s/N]: " _CONF
[[ "${_CONF,,}" == "s" ]] || { echo "Cancelado."; exit 0; }

# =============================================================================
# GERA group_vars/all.yml
# =============================================================================
mkdir -p "${SCRIPT_DIR}/group_vars"

_DISKS_YAML=""
for _d in "${RAID_DISKS[@]}"; do _DISKS_YAML+="    - ${_d}"$'\n'; done

cat > "${SCRIPT_DIR}/group_vars/all.yml" << YAML
# Gerado por bootstrap.sh em $(date)
server:
  ip:         "${SAMBA_IP}"
  mask:       "${SAMBA_MASK}"
  gateway:    "${GATEWAY}"
  dns:        "${DNS}"
  hostname:   "${HOSTNAME}"
  domain:     "${DOMAIN}"
  admin_user: "${ADMIN_USER}"
  iface:      "${SERVER_IFACE}"

raid:
  level:   ${RAID_LEVEL}
  mount:   /mnt/raid
  device:  /dev/md0
  devices:
${_DISKS_YAML}
samba:
  workgroup:    "WORKGROUP"
  default_pass: "${SAMBA_PASS}"
  log_dir:      /var/log/samba
  extra_admins: []

portal:
  dir:  /opt/cdpni-portal
  user: cdpni
  port: 5000

ssl:
  dir:      /etc/nginx/ssl
  cert:     /etc/nginx/ssl/cdpni.crt
  key:      /etc/nginx/ssl/cdpni.key
  days:     3650
  country:  BR
  state:    SP
  org:      CDPNI

panel:
  dir:  /var/www/samba-panel
  user: admin
  pass: "${PANEL_PASS}"
YAML

ok "group_vars/all.yml gerado"

# =============================================================================
# EXECUTA ANSIBLE
# =============================================================================
step "Executando Ansible playbook"
echo ""

cd "${SCRIPT_DIR}"
# Configura rotação do log do Ansible
cat > /etc/logrotate.d/cdpni-ansible << 'LOGROTATE'
/var/log/cdpni_ansible.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
LOGROTATE

ansible-playbook -i inventory/hosts.ini site.yml \
    --diff \
    2>&1 | tee /var/log/cdpni_ansible.log

echo ""
ok "Log completo em /var/log/cdpni_ansible.log"
