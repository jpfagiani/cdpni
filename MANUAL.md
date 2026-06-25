# Manual do Servidor de Arquivos Samba — CDPNI

## Visão Geral

Servidor de arquivos Windows (SMB/CIFS) instalado via Ansible.  
Inclui: RAID de dados, Samba 4, painel web de administração (PHP) e portal de autocadastro (Flask).

- **IP padrão:** 172.14.29.11
- **Painel web:** `https://172.14.29.11:8443`
- **Compartilhamentos:** `\\172.14.29.11\NomeDoShare`

---

## 1. Instalação do Zero

### Pré-requisitos

- Debian 12 ou 13 (instalação mínima)
- Pelo menos 2 discos extras além do disco do SO (para o RAID)
- Acesso root
- Conexão com a internet (para baixar pacotes)

### Passo a Passo

```bash
# 1. Instalar git e clonar o repositório
apt install -y git
git clone https://github.com/jpfagiani/smb.git /opt/smb
cd /opt/smb

# 2. Executar o bootstrap (detecta rede/discos e faz perguntas)
bash bootstrap.sh
```

O bootstrap faz automaticamente:
1. Detecta interfaces de rede e sugere a correta
2. Detecta discos disponíveis e exibe tamanho/modelo
3. Pergunta: IP fixo, máscara, gateway, DNS, hostname, domínio
4. Pergunta: login do administrador, senha Samba, senha do painel
5. Pergunta: quais discos usar no RAID e qual nível (1/5/6/10)
6. Mostra resumo e pede confirmação antes de iniciar
7. Executa o Ansible e instala tudo

> **Atenção:** todos os dados nos discos selecionados para o RAID serão apagados.

### Níveis de RAID disponíveis

| Nível | Mínimo de discos | Capacidade útil | Tolera falhas |
|-------|-----------------|-----------------|---------------|
| 1     | 2               | 1× disco        | N-1 discos    |
| 5     | 3               | (N-1)× disco    | 1 disco       |
| 6     | 4               | (N-2)× disco    | 2 discos      |
| 10    | 4 (par)         | N/2× disco      | 1 por par     |

### Reaplicar após mudanças no código

```bash
cd /opt/smb
git pull origin main
ansible-playbook -i inventory/hosts.ini site.yml
```

Para aplicar apenas parte da instalação:

```bash
# Só Samba (compartilhamentos, usuários)
ansible-playbook -i inventory/hosts.ini site.yml --tags samba

# Só firewall
ansible-playbook -i inventory/hosts.ini site.yml --tags security

# Só painel web
ansible-playbook -i inventory/hosts.ini site.yml --tags php_panel
```

---

## 2. Compartilhamentos

### Estrutura de acesso

| Tipo | Quem acessa |
|------|-------------|
| `regular` | Grupo do share + jpfagiani + rcborges + supervisao + admin |
| `restricted` | Grupo do share + jpfagiani + rcborges + admin (sem supervisao) |
| `guest` | Qualquer um, sem senha, visível na rede |
| `guest_hidden` | Qualquer um, sem senha, oculto na listagem |

### Lista de compartilhamentos

| Compartilhamento | Grupo Linux | Tipo | Observação |
|-----------------|-------------|------|------------|
| Administrativo | grp_administrativo | regular | |
| Aevp | grp_aevp | regular | |
| Almoxarifado | grp_almoxarifado | regular | |
| Cadastro | grp_cadastro | regular | |
| Canil | grp_canil | regular | |
| Chefia_Turno_I | grp_chefia1 | regular | |
| Chefia_Turno_II | grp_chefia2 | regular | |
| Chefia_Turno_III | grp_chefia3 | regular | |
| Chefia_Turno_IV | grp_chefia4 | regular | |
| Cipa | grp_cipa | regular | |
| Conexao_Familiar | grp_conexao | regular | |
| Csd | grp_csd | regular | |
| Educacao | grp_educacao | regular | |
| Financas | grp_financas | regular | |
| Inclusao | grp_inclusao | regular | |
| Infraestrutura | grp_infra | regular | |
| Nucleo_de_Pessoal | grp_npessoal | regular | |
| Planilhas | grp_planilhas | regular | |
| Portaria_Turno_I | grp_portaria1 | regular | |
| Portaria_Turno_II | grp_portaria2 | regular | |
| Portaria_Turno_III | grp_portaria3 | regular | |
| Portaria_Turno_IV | grp_portaria4 | regular | |
| Rol_de_Visitas | grp_rol | regular | |
| Saude | grp_saude | regular | |
| Simic | grp_simic | regular | |
| Sindicancia | grp_sindicancia | regular | |
| Supervisao | grp_supervisao | regular | |
| Diretoria_Geral | grp_dg | restricted | Sem acesso para supervisao |
| Publico | grp_publico | guest | Sem senha |
| Scanner | grp_scanner | guest | Sem senha |
| Papel_de_Parede | grp_papel_de_parede | guest | Sem senha |
| CPD | grp_cpd | guest_hidden | Sem senha, oculto na listagem |

### Caminho dos arquivos no servidor

```
/mnt/raid/shares/NomeDoShare/
/mnt/raid/recycle/          ← lixeira global
```

---

## 3. Usuários e Permissões

### Usuários especiais (pré-criados)

| Usuário | Acesso |
|---------|--------|
| `jpfagiani` | Todos os compartilhamentos + admin Samba |
| `rcborges` | Todos os compartilhamentos |
| `cpd` | Todos os compartilhamentos + admin Samba |
| `supervisao` | Todos exceto Diretoria_Geral |
| `sambadmin` (ou nome escolhido) | Admin Samba (bypass de permissões) |

### Usuários por compartilhamento

Cada share tem um usuário Linux/Samba com nome em minúsculas (igual ao share) e um **grupo** com prefixo `grp_`:

| Share | Usuário Linux | Grupo Linux |
|-------|--------------|-------------|
| Administrativo | administrativo | grp_administrativo |
| Chefia_Turno_I | chefia_turno_i | grp_chefia1 |
| Chefia_Turno_II | chefia_turno_ii | grp_chefia2 |
| Chefia_Turno_III | chefia_turno_iii | grp_chefia3 |
| Chefia_Turno_IV | chefia_turno_iv | grp_chefia4 |
| Conexao_Familiar | conexao_familiar | grp_conexao |
| Diretoria_Geral | diretoria_geral | grp_dg |
| Infraestrutura | infraestrutura | grp_infra |
| Nucleo_de_Pessoal | nucleo_de_pessoal | grp_npessoal |
| Portaria_Turno_I | portaria_turno_i | grp_portaria1 |
| Portaria_Turno_II | portaria_turno_ii | grp_portaria2 |
| Portaria_Turno_III | portaria_turno_iii | grp_portaria3 |
| Portaria_Turno_IV | portaria_turno_iv | grp_portaria4 |
| Rol_de_Visitas | rol_de_visitas | grp_rol |
| *(demais)* | `<share | lower>` | `grp_<share | lower>` |

Esses usuários são para acesso direto ao compartilhamento específico.

### Gerenciar usuários via painel web

Acesse `https://IP:8443` e use o menu **Usuários**.

### Gerenciar usuários via linha de comando

```bash
# Adicionar usuário ao Samba (deve existir no Linux primeiro)
smbpasswd -a nomedousuario

# Alterar senha Samba de um usuário
smbpasswd nomedousuario

# Desativar usuário no Samba
smbpasswd -d nomedousuario

# Reativar usuário no Samba
smbpasswd -e nomedousuario

# Listar usuários Samba cadastrados
pdbedit -L

# Listar com detalhes
pdbedit -Lv
```

---

## 4. Painel Web de Administração

- **URL:** `https://IP_DO_SERVIDOR:8443`
- **Login padrão:** `admin`
- **Senha:** definida no bootstrap

### Funcionalidades

- **Dashboard:** conexões ativas em tempo real (smbstatus), últimos acessos com data/hora, status do RAID
- **Compartilhamentos:** criar, editar, remover; ver último acesso, badge de compartilhamento guest
- **Usuários:** criar, definir senha, ver grupos
- **Grupos:** criar e gerenciar grupos

> O certificado SSL é autoassinado — o navegador vai alertar; clique em "Avançado" e "Continuar".

---

## 5. RAID

### Verificar status

```bash
cat /proc/mdstat
mdadm --detail /dev/md0
```

### Substituir um disco com falha

```bash
# 1. Marcar como falho (se ainda não estiver)
mdadm /dev/md0 --fail /dev/sdX

# 2. Remover do array
mdadm /dev/md0 --remove /dev/sdX

# 3. Substituir o disco fisicamente, depois adicionar o novo
mdadm /dev/md0 --add /dev/sdX

# 4. Acompanhar reconstrução
watch cat /proc/mdstat
```

### Verificar uso de espaço

```bash
df -h /mnt/raid
du -sh /mnt/raid/shares/*
```

---

## 6. Firewall (nftables)

Tabela `cdpni` — aceita conexões apenas de redes internas (10.x, 172.x, 192.168.x).

| Porta | Protocolo | Serviço |
|-------|-----------|---------|
| 22 | TCP | SSH (rate-limit: 4 conn/min por IP) |
| 139, 445 | TCP | Samba SMB/CIFS |
| 137, 138 | UDP | NetBIOS |
| 80, 443, 8443 | TCP | Painel web |

```bash
# Ver regras ativas
nft list ruleset

# Reaplicar firewall
ansible-playbook -i inventory/hosts.ini site.yml --tags security
```

---

## 7. Logs e Diagnóstico

```bash
# Conexões ativas agora
smbstatus

# Sessões abertas por share
smbstatus -S

# Log do Samba
tail -50 /var/log/samba/log.smbd

# Auditoria de acesso (quem abriu/leu/escreveu o quê)
grep smbd_audit /var/log/syslog | tail -30

# Status dos serviços
systemctl status smbd nmbd

# Reiniciar Samba
systemctl restart smbd nmbd
```

---

## 8. Procedimentos Comuns

### Acessar compartilhamento pelo Windows

No Windows Explorer:
```
\\172.14.29.11\NomeDoShare
```

Ou mapear unidade: clique direito em "Este PC" → "Mapear unidade de rede".

### Acessar compartilhamentos guest (sem senha)

Basta navegar para `\\172.14.29.11` — Publico, Scanner e Papel_de_Parede aparecem sem pedir senha.

### Adicionar novo usuário a um compartilhamento

```bash
# Criar usuário Linux (sem home, sem shell)
useradd -M -s /sbin/nologin -G nome_do_grupo novodeusuario

# Registrar no Samba com senha
smbpasswd -a novodeusuario
```

### Alterar senha de um usuário

```bash
smbpasswd nomedousuario
```

### Acessar lixeira

```
\\172.14.29.11\Recycle
```

Somente `sambadmin`, `jpfagiani` e `cpd` têm acesso.

---

## 9. Backup

O RAID protege contra falha de disco mas **não substitui backup**. Faça cópias externas regularmente.

```bash
# Backup manual para outro servidor
rsync -av /mnt/raid/shares/ usuario@destino:/backup/samba/
```
