# CDPNI — Manual de Instalação e Operação

**Plataforma Corporativa de Gestão de Arquivos e Usuários**  
Samba 4 · RAID · Portal Web · Painel Admin · nftables

---

## Índice

1. [Visão Geral do Sistema](#1-visão-geral-do-sistema)
2. [Requisitos](#2-requisitos)
3. [Instalação](#3-instalação)
4. [Primeiro Acesso](#4-primeiro-acesso)
5. [Endereços e Portas](#5-endereços-e-portas)
6. [Painel Admin — Uso Diário](#6-painel-admin--uso-diário)
7. [Portal de Arquivos](#7-portal-de-arquivos)
8. [Compartilhamentos e Permissões](#8-compartilhamentos-e-permissões)
9. [Acesso via Windows / Linux / Mac](#9-acesso-via-windows--linux--mac)
10. [Administração via Terminal](#10-administração-via-terminal)
11. [RAID — Monitoramento e Recuperação](#11-raid--monitoramento-e-recuperação)
12. [Backup e Restauração](#12-backup-e-restauração)
13. [Firewall nftables](#13-firewall-nftables)
14. [Fail2ban](#14-fail2ban)
15. [Reconfigurar / Re-executar o Ansible](#15-reconfigurar--re-executar-o-ansible)
16. [Diagnóstico e Solução de Problemas](#16-diagnóstico-e-solução-de-problemas)
17. [Referência Rápida de Comandos](#17-referência-rápida-de-comandos)

---

## 1. Visão Geral do Sistema

```
┌─────────────────────────────────────────────────────────┐
│                   REDE CORPORATIVA (LAN)                  │
│                                                           │
│   Clientes Windows/Linux/Mac                              │
│          │                                                │
│          ▼                                                │
│  ┌───────────────────────────────────────────────────┐   │
│  │          GATEWAY GWOS (nftables, BIND, Squid)     │   │
│  └───────────────────┬───────────────────────────────┘   │
│                      │                                    │
│          ┌───────────▼───────────────────────────────┐   │
│          │         SERVIDOR CDPNI                    │   │
│          │                                           │   │
│          │  ┌──────────┐  ┌─────────────────────┐   │   │
│          │  │ Samba 4  │  │   Portal Flask       │   │   │
│          │  │ SMB/CIFS │  │   https://IP         │   │   │
│          │  │ porta 445│  │   porta 443          │   │   │
│          │  └──────────┘  └─────────────────────┘   │   │
│          │                                           │   │
│          │  ┌──────────────────────────────────┐    │   │
│          │  │   Painel Admin PHP               │    │   │
│          │  │   https://IP:8443                │    │   │
│          │  └──────────────────────────────────┘    │   │
│          │                                           │   │
│          │  ┌──────────────────────────────────┐    │   │
│          │  │   RAID 5 (mdadm) — /mnt/raid     │    │   │
│          │  │   XFS — /mnt/raid/shares         │    │   │
│          │  └──────────────────────────────────┘    │   │
│          └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Componentes

| Componente | Tecnologia | Função |
|---|---|---|
| Servidor de arquivos | Samba 4 + tdbsam | Compartilhamentos SMB/CIFS para Windows/Linux/Mac |
| Armazenamento | mdadm RAID 5/6/10/1 + XFS | Redundância e desempenho |
| Portal de arquivos | Flask 3.1 + Gunicorn + PAM | Browser: navegar, upload, download, renomear |
| Painel administrativo | PHP 8.3-FPM + Nginx | Browser: gerenciar usuários, grupos, shares, backup |
| Firewall | nftables | Mesma stack do gateway — LAN only |
| Proteção brute-force | Fail2ban | Bloqueia IPs após tentativas falhas |
| Integridade dos discos | S.M.A.R.T. (smartd) | Alerta precoce de falha física |
| Automação da instalação | Ansible (bootstrap.sh) | Instalação idempotente e repetível |

---

## 2. Requisitos

### Hardware mínimo

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU | 2 núcleos | 4 núcleos |
| RAM | 4 GB | 8 GB |
| Disco do SO | 40 GB (SSD) | 60 GB (SSD) |
| Discos de dados | 3 × qualquer tamanho (RAID 5) | 5 × mesmo fabricante/tamanho |
| Rede | 100 Mbps | 1 Gbps |

### Sistema operacional

- **Debian 11 / 12** ou **Ubuntu 22.04 / 24.04 LTS**
- Acesso root ou sudo
- Conexão com a internet durante a instalação

### Rede

- IP fixo disponível na faixa da LAN corporativa
- Integração com o Gateway GWOS já implantado

---

## 3. Instalação

### 3.1 Baixar o projeto

```bash
# Opção A — clonar do GitHub
git clone https://github.com/jpfagiani/cdpni.git
cd cdpni

# Opção B — copiar do pendrive / pasta compartilhada
cp -r /media/pendrive/cdpni /opt/cdpni
cd /opt/cdpni
```

### 3.2 Executar o instalador

```bash
sudo bash bootstrap.sh
```

O instalador faz automaticamente:

1. Instala Python 3 e Ansible se ausentes
2. Detecta todas as interfaces de rede privadas (10.x, 172.16-31.x, 192.168.x)
3. Sugere um IP livre baseado na rede detectada
4. Lista todos os discos — identifica o disco do SO com `[SO]` (não pode ser selecionado)
5. Permite escolher quais discos usará e qual nível de RAID
6. Exibe resumo completo antes de iniciar — pede confirmação

### 3.3 Exemplo de sessão de instalação

```
┌─ Interfaces de rede detectadas
  INTERFACE      IP ATUAL           CIDR   REDE
  ────────────────────────────────────────────────────────────
  enp3s0         192.168.1.10       /24    192.168.1.0/24

  → IP sugerido: 192.168.1.11

  IP fixo do servidor [192.168.1.11]:
  > [Enter]                            ← aceita o sugerido

  Máscara CIDR [24]:
  > [Enter]

  Gateway [192.168.1.1]:
  > [Enter]

  DNS (Enter = gateway) [192.168.1.1]:
  > [Enter]

  Nome do servidor [cdpni]:
  > cdpni

  Domínio local [cdpni.local]:
  > cdpni.local

  Login do administrador [sambadmin]:
  > sambadmin

┌─ Discos detectados
  Nº    DISPOSITIVO  TAMANHO    MODELO                    STATUS
  ─────────────────────────────────────────────────────────────────
  [SO]  /dev/sda     120G       SAMSUNG SSD 860           Sistema
  [1]   /dev/sdb     2.0T       WDC WD20EZRZ              Disponível
  [2]   /dev/sdc     2.0T       WDC WD20EZRZ              Disponível
  [3]   /dev/sdd     2.0T       WDC WD20EZRZ              Disponível
  [4]   /dev/sde     2.0T       WDC WD20EZRZ              Disponível
  [5]   /dev/sdf     2.0T       WDC WD20EZRZ              Disponível

  Discos para o RAID (Enter = todos):
  > [Enter]                            ← usa sdb, sdc, sdd, sde, sdf

  Níveis disponíveis para 5 disco(s):
  [1]  RAID 1  — espelho         capacidade: 1×disco    tolera: 4 falha(s)
  [5]  RAID 5  — paridade        capacidade: 4×disco    tolera: 1 falha
  [6]  RAID 6  — dupla paridade  capacidade: 3×disco    tolera: 2 falhas

  Nível de RAID [5]:
  > [Enter]

╔══════════════════════════════════════════════════════╗
║              CONFIGURAÇÃO A SER APLICADA             ║
╠══════════════════════════════════════════════════════╣
║  IP / Máscara:           192.168.1.11/24             ║
║  Gateway:                192.168.1.1                 ║
║  DNS:                    192.168.1.1                 ║
║  Interface:              enp3s0                      ║
║  Hostname:               cdpni.cdpni.local           ║
║  Admin:                  sambadmin                   ║
║  RAID 5:                 sdb, sdc, sdd, sde, sdf     ║
╠══════════════════════════════════════════════════════╣
║  ⚠  TODOS OS DADOS NOS DISCOS SERÃO APAGADOS!        ║
╚══════════════════════════════════════════════════════╝

  Iniciar instalação? [s/N]: s
```

### 3.4 O que o Ansible instala (em ordem)

| Fase | Role | O que faz |
|---|---|---|
| 1 | `common` | Pacotes base, hostname, NTP (chrony), logrotate |
| 2 | `network` | IP estático em `/etc/network/interfaces`, DNS |
| 3 | `storage` | Zera discos, cria RAID, formata XFS, monta, cria pastas |
| 4 | `samba` | Samba 4, smb.conf com 32 shares, 29 grupos, 26 usuários |
| 5 | `security` | nftables, Fail2ban (nftables backend), smartd, SSL |
| 6 | `php_panel` | Nginx, PHP 8.3-FPM, painel admin em `/var/www/samba-panel` |
| 7 | `flask_portal` | Python venv, Flask, Gunicorn, portal em `/opt/cdpni-portal` |

### 3.5 Duração e log

A instalação leva entre **10 e 30 minutos** dependendo do hardware e velocidade da internet.

```bash
# Acompanhar o log em tempo real (outro terminal)
tail -f /var/log/cdpni_ansible.log

# Ver o log completo após instalação
less /var/log/cdpni_ansible.log
```

### 3.6 Sincronização do RAID

Após a instalação, o RAID levará horas para sincronizar completamente (normal).  
Durante a sincronização o servidor funciona normalmente.

```bash
# Verificar progresso (atualiza a cada 2s)
watch -n2 cat /proc/mdstat

# Saída típica durante sync:
# md0 : active raid5 sdb[0] sdc[1] sdd[2] sde[3] sdf[4]
#       7814037504 blocks super 1.2 level 5
#       [5/5] [UUUUU]
#       [=========>........]  resync = 53.2% (1040512/1953511) finish=47.8min speed=318K/sec
```

---

## 4. Primeiro Acesso

### 4.1 Trocar as senhas padrão imediatamente

> **ATENÇÃO:** Troque todas as senhas abaixo antes de colocar o servidor em produção.

| Serviço | Usuário | Senha padrão | Como trocar |
|---|---|---|---|
| Portal de arquivos (Flask) | `sambadmin` | `1234` | Acessar portal → menu Admin → Minha Senha |
| Painel Admin (PHP) | `admin` | `admin` | Acessar painel → tela de login → forçará troca automática na primeira vez |
| Samba (todos os usuários) | vários | `1234` | Painel Admin → Usuários → botão Senha |

### 4.2 Instalar o certificado SSL no navegador

O servidor usa certificado autoassinado. Para evitar alertas:

1. Acesse `https://IP_DO_SERVIDOR/cdpni-ca.crt`
2. O navegador baixará o certificado
3. Instale no **Windows**: duplo clique → Instalar certificado → Autoridades de Certificação Raiz Confiáveis
4. Instale no **Firefox**: Configurações → Privacidade → Certificados → Importar

---

## 5. Endereços e Portas

| Serviço | URL / Endereço | Porta | Usuário |
|---|---|---|---|
| Portal de Arquivos (web) | `https://192.168.1.11` | 443 | qualquer usuário do sistema |
| Painel Administrativo (web) | `https://192.168.1.11:8443` | 8443 | `admin` |
| Compartilhamentos Samba | `\\192.168.1.11` | 445 | qualquer usuário do sistema |
| SSH | `ssh root@192.168.1.11` | 22 | apenas da LAN |
| Download do CA | `https://192.168.1.11/cdpni-ca.crt` | 443 | — |

> Substitua `192.168.1.11` pelo IP configurado na sua instalação.

---

## 6. Painel Admin — Uso Diário

Acesse `https://IP:8443` com o usuário `admin`.

### 6.1 Dashboard

Exibe em tempo real:
- Status dos serviços (smbd, nmbd, RAID)
- Espaço usado / disponível
- Número de usuários e compartilhamentos
- Conexões ativas no momento
- Uptime do servidor

### 6.2 Criar um novo usuário

1. Menu lateral → **Usuários** → botão **+ Novo Usuário**
2. Preencher:
   - **Login**: apenas letras minúsculas, números e `_` (ex: `joao_silva`)
   - **Nome Completo**: nome para exibição
   - **Senha inicial**: mínimo 4 caracteres (o usuário trocará no primeiro acesso)
   - **Grupo Principal**: define quais pastas o usuário acessa
3. Clicar **Criar**

O usuário é criado simultaneamente no sistema Linux e no Samba.

### 6.3 Bloquear / desbloquear usuário

1. Menu lateral → **Usuários**
2. Na linha do usuário, botão **⏸ Bloquear** ou **▶ Ativar**

O bloqueio desativa o acesso ao Samba (SMB) mas não apaga dados.

### 6.4 Resetar senha de usuário

1. Menu lateral → **Usuários** → botão **🔑 Senha** na linha do usuário
2. Digite a nova senha (mínimo 4 caracteres)
3. Clicar **Salvar**

### 6.5 Excluir usuário permanentemente

1. Menu lateral → **Usuários** → botão **🗑** na linha do usuário
2. Confirmar no modal — ação **não pode ser desfeita**
3. O usuário é removido do Samba, do Linux e sua lixeira pessoal é apagada

### 6.6 Criar grupo

1. Menu lateral → **Grupos** → botão **+ Novo Grupo**
2. Digite o nome (será prefixado com `grp_` automaticamente)
3. Clicar **Criar**

### 6.7 Adicionar / remover membros de um grupo

- **Adicionar**: na tabela de grupos, botão **+ Membro** → digitar o login
- **Remover**: clicar no `×` ao lado do nome do membro na coluna Membros

### 6.8 Criar novo compartilhamento

1. Menu lateral → **Compartilhamentos** → botão **+ Novo Share**
2. Preencher:
   - **Nome**: sem espaços (ex: `Financeiro_2025`)
   - **Grupo**: grupo que terá acesso
   - **Descrição**: opcional
   - **Gravável**: sim/não
   - **Visível**: se o share aparece na listagem de rede
3. Clicar **Criar** — o smb.conf é atualizado e o Samba reinicia automaticamente

### 6.9 Excluir compartilhamento

1. Menu lateral → **Compartilhamentos** → botão **🗑 Excluir**
2. Marcar "Também excluir os arquivos" se quiser apagar o diretório
3. Confirmar

### 6.10 Auditoria

1. Menu lateral → **Auditoria**
2. Use o campo de filtro para pesquisar por usuário ou ação
3. Botão **⬇ Exportar CSV** baixa o log completo em planilha

O log registra: login, criação/exclusão de usuários, alteração de grupos, criação/exclusão de shares, mudança de senha.

### 6.11 Backup pelo painel

1. Menu lateral → **Backup**
2. Seção **Executar Backup**:
   - Marcar o que incluir (compartilhamentos e/ou configuração Samba)
   - Clicar **💾 Iniciar backup agora**
3. O arquivo `.tar.gz` aparece no **Histórico de backups**

Backup automático ocorre todo dia às **02:00** e mantém os últimos **7 dias**.

---

## 7. Portal de Arquivos

Acesse `https://IP` com qualquer usuário do sistema.

### 7.1 Login

Use o mesmo login e senha do Samba/sistema Linux.

### 7.2 Navegar nos compartilhamentos

Após o login, são exibidos apenas os compartilhamentos que o usuário tem permissão de acesso (definido pelos grupos).

### 7.3 Upload de arquivos

1. Entrar no compartilhamento desejado
2. Clicar **⬆ Upload**
3. Selecionar um ou mais arquivos
4. Clicar **Enviar**

### 7.4 Download de arquivos

Na listagem, clicar no botão **⬇ Baixar** ao lado do arquivo.

### 7.5 Criar pasta

1. Clicar **📁 Nova Pasta**
2. Digitar o nome
3. Clicar **Criar**

### 7.6 Renomear arquivo ou pasta

Clicar no botão **✏ Renomear**, digitar o novo nome, confirmar.

### 7.7 Excluir arquivo ou pasta

Clicar no botão **🗑**, confirmar no alerta.  
> Pastas são excluídas com todo o conteúdo — não há lixeira no portal web.

### 7.8 Funções de administrador do portal

Usuários `sambadmin`, `cpd` e `supervisao` têm acesso ao menu **⚙ Admin**:

- **Aviso/Notícia**: exibe texto na página inicial para todos os usuários
- **Banner**: imagem no topo (JPG/PNG/GIF/WebP, máx. 200px de altura)
- **Resetar senha de usuário**: altera senha de qualquer conta
- **Minha senha**: altera a própria senha

---

## 8. Compartilhamentos e Permissões

### 8.1 Lista de compartilhamentos

| Share | Grupo principal | Acesso extra | Obs. |
|---|---|---|---|
| Administrativo | grp_administrativo | supervisao, admin | — |
| Aevp | grp_aevp | supervisao, admin | — |
| Almoxarifado | grp_almoxarifado | supervisao, admin | — |
| Canil | grp_canil | supervisao, admin | — |
| Cipa | grp_cipa | supervisao, admin | — |
| Conexao_Familiar | grp_conexao_familiar | supervisao, admin | — |
| Educacao | grp_educacao | supervisao, admin | — |
| Financas | grp_financas | supervisao, admin | — |
| Inclusao | grp_inclusao | supervisao, admin | — |
| Infraestrutura | grp_infraestrutura | supervisao, admin | — |
| Nucleo_de_Pessoal | grp_nucleo_pessoal | supervisao, admin | — |
| Planilhas | grp_planilhas | supervisao, admin | — |
| Rol_de_Visitas | grp_rol_visitas | supervisao, admin | — |
| Saude | grp_saude | supervisao, admin | — |
| Sindicancia | grp_sindicancia | supervisao, admin | — |
| Chefia_Turno_I | grp_chefia_1 | cpd, dg, supervisao, sindicancia, admin | — |
| Chefia_Turno_II | grp_chefia_2 | cpd, dg, supervisao, sindicancia, admin | — |
| Chefia_Turno_III | grp_chefia_3 | cpd, dg, supervisao, sindicancia, admin | — |
| Chefia_Turno_IV | grp_chefia_4 | cpd, dg, supervisao, sindicancia, admin | — |
| csd | grp_csd | supervisao, dg, cpd, admin | — |
| Simic | grp_simic + grp_cadastro | supervisao, admin | Acesso cruzado |
| Cadastro | grp_cadastro + grp_simic | supervisao, admin | Acesso cruzado |
| Supervisao | grp_supervisao | admin | — |
| Publico | **todos os grupos** | — | Aberto à LAN |
| Scanner | **todos os grupos** | — | Aberto à LAN |
| Papel_de_Parede | **todos os grupos** | — | Aberto à LAN |
| CPD | **todos os grupos** | — | **Oculto** na rede |
| Diretoria_Geral | grp_diretoria | apenas admin | **supervisao NÃO tem acesso** |
| Portaria_Turno_I | grp_portaria | supervisao, cpd, admin | — |
| Portaria_Turno_II | grp_portaria | supervisao, cpd, admin | — |
| Portaria_Turno_III | grp_portaria | supervisao, cpd, admin | — |
| Portaria_Turno_IV | grp_portaria | supervisao, cpd, admin | — |

### 8.2 Usuários pré-criados

| Login | Descrição | Acesso |
|---|---|---|
| `cpd` | CPD — Acesso Total | Todos os shares exceto Diretoria_Geral (via usuário) |
| `supervisao` | Supervisão Geral | Todos os shares exceto Diretoria_Geral |
| `dg` | Diretoria Geral | Diretoria_Geral + chefias + csd |
| `chefia1–4` | Chefes de Turno | Share do turno respectivo |
| `simic` | SIMIC | Simic + Cadastro |
| `cadastro` | Cadastro | Cadastro + Simic |
| `csd` | CSD | Share csd |
| `adm`, `aevp`, `almoxarifado`, etc. | Setores | Share do setor |

> Todos os usuários são criados com senha `1234`. **Troque imediatamente após a instalação.**

---

## 9. Acesso via Windows / Linux / Mac

### 9.1 Windows

**Via explorador de arquivos:**

1. Abrir o **Explorador de Arquivos**
2. Na barra de endereço, digitar: `\\192.168.1.11`
3. Inserir login e senha quando solicitado
4. As pastas com permissão aparecerão listadas

**Mapear unidade de rede (persistente):**

```
Clique direito em "Este Computador" → Mapear unidade de rede
  Unidade: Z: (ou qualquer letra disponível)
  Pasta:   \\192.168.1.11\NomeDaShare
  ☑ Reconectar durante o logon
  ☑ Conectar usando credenciais diferentes
```

**Via linha de comando (cmd):**

```cmd
rem Mapear a unidade Z: para o share Administrativo
net use Z: \\192.168.1.11\Administrativo /user:adm /persistent:yes

rem Listar unidades mapeadas
net use

rem Desconectar
net use Z: /delete
```

**Adicionar ao hosts para acessar por nome:**

```
Arquivo: C:\Windows\System32\drivers\etc\hosts
Adicionar a linha:
192.168.1.11    cdpni cdpni.cdpni.local
```

Depois de adicionar, acessar com `\\cdpni` em vez do IP.

### 9.2 Linux

```bash
# Instalar cliente Samba
sudo apt install smbclient cifs-utils

# Listar shares disponíveis
smbclient -L //192.168.1.11 -U adm

# Acessar interativamente (shell de arquivo)
smbclient //192.168.1.11/Administrativo -U adm

# Montar permanentemente em /etc/fstab
echo "//192.168.1.11/Administrativo /mnt/adm cifs credentials=/etc/.smbcreds,uid=1000,gid=1000,iocharset=utf8 0 0" | sudo tee -a /etc/fstab

# Criar arquivo de credenciais (não deixar senha exposta)
sudo bash -c 'cat > /etc/.smbcreds << EOF
username=adm
password=SuaSenha
domain=WORKGROUP
EOF'
sudo chmod 600 /etc/.smbcreds

# Montar agora
sudo mount -a
```

### 9.3 macOS

```
Finder → Ir → Conectar ao servidor (⌘K)
  smb://192.168.1.11/Administrativo
  Inserir usuário e senha
```

Ou via terminal:

```bash
# Montar share
mount -t smbfs //adm:senha@192.168.1.11/Administrativo /Volumes/Administrativo
```

---

## 10. Administração via Terminal

Acesse o servidor via SSH:

```bash
ssh root@192.168.1.11
```

### 10.1 Usuários Samba

```bash
# Listar todos os usuários Samba
pdbedit -L

# Listar com detalhes (grupos, flags)
pdbedit -L -v

# Criar usuário Linux + Samba
useradd -m -s /usr/sbin/nologin -g grp_administrativo novo_usuario
echo "novo_usuario:senha123" | chpasswd
printf 'senha123\nsenha123\n' | smbpasswd -s -a novo_usuario
smbpasswd -e novo_usuario

# Alterar senha Samba
smbpasswd nome_usuario

# Bloquear usuário no Samba
smbpasswd -d nome_usuario

# Desbloquear usuário no Samba
smbpasswd -e nome_usuario

# Remover usuário do Samba (mantém Linux)
smbpasswd -x nome_usuario

# Remover usuário completamente (Linux + Samba)
smbpasswd -x nome_usuario
userdel -r nome_usuario
```

### 10.2 Grupos

```bash
# Criar grupo
groupadd grp_novo_setor

# Adicionar usuário a grupo
usermod -aG grp_novo_setor nome_usuario

# Remover usuário de grupo
gpasswd -d nome_usuario grp_novo_setor

# Ver grupos de um usuário
id nome_usuario

# Ver membros de um grupo
getent group grp_administrativo
```

### 10.3 Serviços Samba

```bash
# Status dos serviços
systemctl status smbd nmbd

# Reiniciar
systemctl restart smbd nmbd

# Recarregar configuração (sem desconectar clientes)
systemctl reload smbd

# Ver conexões ativas
smbstatus

# Ver arquivos abertos
smbstatus -L

# Testar configuração smb.conf
testparm

# Testar configuração sem pausas
testparm -s
```

### 10.4 Editar compartilhamentos manualmente

```bash
# Editar configuração
nano /etc/samba/smb.conf

# Testar antes de aplicar
testparm

# Aplicar sem derrubar conexões ativas
systemctl reload smbd
```

### 10.5 Portal Flask

```bash
# Status do portal
systemctl status cdpni-portal

# Reiniciar o portal
systemctl restart cdpni-portal

# Ver logs de acesso
tail -f /var/log/cdpni_portal_access.log

# Ver logs de erro
tail -f /var/log/cdpni_portal_error.log
```

### 10.6 Painel PHP / Nginx

```bash
# Status
systemctl status nginx php8.3-fpm

# Reiniciar
systemctl restart nginx php8.3-fpm

# Recarregar Nginx (sem downtime)
systemctl reload nginx

# Ver log de acesso do Nginx
tail -f /var/log/nginx/access.log

# Ver erros do Nginx
tail -f /var/log/nginx/error.log
```

### 10.7 Log de auditoria do painel

```bash
# Ver log em tempo real
tail -f /var/log/samba_panel.log

# Buscar ações de um usuário específico
grep '\[adm\]' /var/log/samba_panel.log

# Ver últimas 50 ações
tail -50 /var/log/samba_panel.log
```

---

## 11. RAID — Monitoramento e Recuperação

### 11.1 Verificar estado do RAID

```bash
# Estado atual (mostra progresso se estiver sincronizando)
cat /proc/mdstat

# Informações detalhadas
mdadm --detail /dev/md0

# Estado resumido de todos os arrays
mdadm --detail --scan
```

### 11.2 Interpretando /proc/mdstat

```
# Saudável:
md0 : active raid5 sdb[0] sdc[1] sdd[2] sde[3] sdf[4]
      7814037504 blocks super 1.2 level 5
      [5/5] [UUUUU]        ← 5 de 5 discos OK

# Com 1 disco falhado (degradado):
md0 : active raid5 sdb[0] sdc[1] sdd[2] sde[3]
      [5/4] [UUUU_]        ← 1 disco ausente (degradado, mas funcional no RAID 5)

# Reconstruindo após troca de disco:
[5/5] [UUUUU]
[=========>........]  resync = 53.2% finish=47.8min speed=318K/sec
```

### 11.3 Substituir disco com falha

```bash
# 1. Identificar qual disco falhou
mdadm --detail /dev/md0 | grep -E "State|RaidDevice"

# 2. Marcar disco com falha (se ainda não foi marcado automaticamente)
mdadm /dev/md0 --fail /dev/sdc

# 3. Remover o disco do array
mdadm /dev/md0 --remove /dev/sdc

# 4. --- DESLIGAR O SERVIDOR, TROCAR FISICAMENTE O DISCO ---

# 5. Adicionar o novo disco (mesmo slot)
mdadm /dev/md0 --add /dev/sdc

# 6. Acompanhar a reconstrução
watch -n5 cat /proc/mdstat
```

### 11.4 Verificação de integridade (cron semanal)

O RAID roda uma verificação automática toda semana. Para forçar manualmente:

```bash
# Iniciar verificação manual
echo check > /sys/block/md0/md/sync_action

# Ver progresso
cat /proc/mdstat

# Resultado da última verificação
cat /sys/block/md0/md/last_check_events_total 2>/dev/null || \
  grep -i "check" /var/log/syslog | tail -5
```

### 11.5 S.M.A.R.T. — saúde física dos discos

```bash
# Teste rápido (2 minutos)
smartctl -t short /dev/sdb

# Teste longo (horas, não-disruptivo)
smartctl -t long /dev/sdb

# Ver resultado
smartctl -a /dev/sdb

# Verificar todos os discos de uma vez
for disk in /dev/sd[b-f]; do
    echo "=== $disk ==="; smartctl -H $disk | grep -E "SMART|result"
done
```

---

## 12. Backup e Restauração

### 12.1 Backup automático

O cron executa todo dia às 02:00:

```bash
# Ver agendamento
crontab -l | grep cdpni

# Forçar backup manual via terminal
DEST=/backup/samba/backup_$(date +%Y-%m-%d_%H-%M).tar.gz
tar -czf "$DEST" /mnt/raid/shares /etc/samba/smb.conf
echo "Backup criado: $DEST ($(du -sh "$DEST" | cut -f1))"
```

### 12.2 Listar backups disponíveis

```bash
ls -lh /backup/samba/backup_*.tar.gz
```

### 12.3 Restaurar backup completo

```bash
# ATENÇÃO: Para restauração completa, parar os serviços primeiro
systemctl stop smbd nmbd cdpni-portal

# Restaurar (substitui os arquivos atuais)
tar -xzf /backup/samba/backup_2026-06-18_02-00.tar.gz -C /

# Reiniciar serviços
systemctl start smbd nmbd cdpni-portal
```

### 12.4 Restaurar arquivo ou pasta específica

```bash
# Listar conteúdo do backup sem extrair
tar -tzf /backup/samba/backup_2026-06-18_02-00.tar.gz | grep "Financas"

# Extrair apenas um arquivo (para diretório atual)
tar -xzf /backup/samba/backup_2026-06-18_02-00.tar.gz \
    mnt/raid/shares/Financas/relatorio.xlsx

# Extrair pasta inteira
tar -xzf /backup/samba/backup_2026-06-18_02-00.tar.gz \
    --strip-components=3 \
    -C /tmp/restore \
    mnt/raid/shares/Financas/
```

### 12.5 Backup externo (recomendado)

```bash
# Copiar backups para servidor externo via rsync+SSH
rsync -avz /backup/samba/ backup@servidor-externo:/backup/cdpni/

# Agendar no cron (executa às 03:00, após o backup local das 02:00)
echo "0 3 * * * rsync -az /backup/samba/ backup@servidor-externo:/backup/cdpni/ >> /var/log/rsync_backup.log 2>&1" | crontab -
```

---

## 13. Firewall nftables

O servidor usa nftables, a mesma stack do Gateway GWOS, garantindo consistência na infraestrutura.

### 13.1 Ver regras ativas

```bash
# Exibir todas as regras
nft list ruleset

# Apenas a chain de entrada
nft list chain inet filter input
```

### 13.2 Estado e saída típica

```bash
nft list ruleset
# table inet filter {
#     chain input {
#         type filter hook input priority filter; policy drop;
#         ct state invalid drop
#         ct state { established, related } accept
#         iifname "lo" accept
#         ip protocol icmp accept
#         tcp dport 22 ip saddr 192.168.1.0/24 accept
#         tcp dport { 139, 445 } ip saddr 192.168.1.0/24 accept
#         udp dport { 137, 138 } ip saddr 192.168.1.0/24 accept
#         tcp dport { 80, 443, 8443 } ip saddr 192.168.1.0/24 accept
#         limit rate 5/minute log prefix "nft-drop: " flags all drop
#     }
# }
```

### 13.3 Recarregar regras após edição

```bash
# Editar configuração
nano /etc/nftables.conf

# Testar sintaxe (sem aplicar)
nft -c -f /etc/nftables.conf && echo "Sintaxe OK"

# Aplicar
systemctl reload nftables
# ou
nft -f /etc/nftables.conf
```

### 13.4 Adicionar exceção temporária

```bash
# Permitir IP específico temporariamente (memória, não persiste)
nft add rule inet filter input ip saddr 10.0.0.50 accept

# Para tornar permanente, editar /etc/nftables.conf e recarregar
```

### 13.5 Ver log de pacotes bloqueados

```bash
# Últimos bloqueios (prefixo nft-drop)
journalctl -k --grep="nft-drop" | tail -20

# Em tempo real
journalctl -kf | grep "nft-drop"
```

---

## 14. Fail2ban

O Fail2ban usa nftables como backend (consistente com o firewall).

### 14.1 Status geral

```bash
fail2ban-client status
# Saída:
# Status
# |- Number of jail: 2
# `- Jail list: samba, cdpni-portal
```

### 14.2 Ver IPs banidos

```bash
# Todos os jails
fail2ban-client status samba
fail2ban-client status cdpni-portal

# Ver regras criadas pelo Fail2ban no nftables
nft list table inet fail2ban 2>/dev/null || echo "Sem bans ativos"
```

### 14.3 Desbanir IP manualmente

```bash
# Desbanir no jail do Samba
fail2ban-client set samba unbanip 192.168.1.99

# Desbanir no jail do portal
fail2ban-client set cdpni-portal unbanip 192.168.1.99
```

### 14.4 Banir IP manualmente

```bash
fail2ban-client set samba banip 10.0.0.50
```

### 14.5 Ver log do Fail2ban

```bash
tail -f /var/log/fail2ban.log | grep -E "Ban|Unban"
```

---

## 15. Reconfigurar / Re-executar o Ansible

### 15.1 Re-executar tudo (idempotente — seguro)

```bash
cd /caminho/para/cdpni
sudo ansible-playbook -i inventory/hosts.ini site.yml --diff
```

### 15.2 Aplicar apenas uma role específica

```bash
# Só o Samba (ex: após editar smb.conf.j2)
sudo ansible-playbook -i inventory/hosts.ini site.yml --tags samba

# Só segurança/firewall
sudo ansible-playbook -i inventory/hosts.ini site.yml --tags firewall

# Só o portal Flask
sudo ansible-playbook -i inventory/hosts.ini site.yml --tags portal

# Só o painel PHP
sudo ansible-playbook -i inventory/hosts.ini site.yml --tags panel

# Só rede (CUIDADO: pode perder acesso SSH se IP errado)
sudo ansible-playbook -i inventory/hosts.ini site.yml --tags network
```

### 15.3 Adicionar share no YAML e re-aplicar

Edite `roles/samba/vars/main.yml` e adicione o share na lista `samba_shares`:

```yaml
samba_shares:
  # ... shares existentes ...
  - name: Novo_Setor
    group: grp_novo_setor
    browseable: yes
```

Depois aplique:

```bash
sudo ansible-playbook -i inventory/hosts.ini site.yml --tags samba
```

### 15.4 Ver o que mudaria sem aplicar (dry-run)

```bash
sudo ansible-playbook -i inventory/hosts.ini site.yml --check --diff
```

---

## 16. Diagnóstico e Solução de Problemas

### Samba não responde

```bash
# Verificar se os serviços estão rodando
systemctl status smbd nmbd

# Verificar porta 445
ss -tlnp | grep 445

# Testar conectividade do próprio servidor
smbclient -L //localhost -U sambadmin

# Ver log de erro do Samba
tail -50 /var/log/samba/log.smbd
```

### Usuário não consegue acessar o share

```bash
# Verificar se o usuário existe no Samba
pdbedit -L | grep nome_usuario

# Verificar grupos do usuário
id nome_usuario

# Testar o share diretamente
smbclient //localhost/NomeDoShare -U nome_usuario

# Verificar se o usuário está no valid users do share
testparm -s 2>/dev/null | grep -A5 "\[NomeDoShare\]"
```

### Portal web não abre

```bash
# Verificar status do serviço
systemctl status cdpni-portal

# Verificar se está escutando na porta 5000 (interno)
ss -tlnp | grep 5000

# Verificar Nginx
systemctl status nginx
nginx -t

# Ver log de erro
tail -30 /var/log/cdpni_portal_error.log
tail -30 /var/log/nginx/error.log
```

### Painel admin não abre (porta 8443)

```bash
systemctl status nginx php8.3-fpm
nginx -t
tail -30 /var/log/nginx/error.log
php8.3-fpm -t
```

### RAID degradado

```bash
# Ver quais discos falharam
mdadm --detail /dev/md0

# Ver eventos recentes
mdadm --query --detail /dev/md0 | grep -E "State|Avail|Failed"

# Verificar log do kernel
dmesg | grep -i "md\|raid\|error" | tail -20
```

### IP mudou / servidor não responde

```bash
# No console físico ou KVM:
ip addr show
# Editar configuração de rede
nano /etc/network/interfaces
systemctl restart networking
```

### Disco cheio

```bash
# Ver uso geral
df -h

# Ver uso por share
du -sh /mnt/raid/shares/*

# Encontrar arquivos grandes
find /mnt/raid/shares -size +1G -printf '%s %p\n' | sort -n | tail -10

# Ver lixeiras (arquivos deletados via Samba)
du -sh /mnt/raid/recycle/*
```

---

## 17. Referência Rápida de Comandos

### Serviços

```bash
systemctl {start|stop|restart|reload|status} smbd
systemctl {start|stop|restart|reload|status} nmbd
systemctl {start|stop|restart|status} cdpni-portal
systemctl {start|stop|restart|reload|status} nginx
systemctl {start|stop|restart|status} php8.3-fpm
systemctl {start|stop|restart|status} fail2ban
systemctl {start|stop|restart|status} nftables
```

### Samba

```bash
pdbedit -L                          # listar usuários Samba
pdbedit -L -v                       # listar com detalhes
smbpasswd -a usuario                # adicionar usuário ao Samba
smbpasswd -e usuario                # habilitar
smbpasswd -d usuario                # desabilitar
smbpasswd -x usuario                # remover do Samba
smbstatus                           # conexões ativas
testparm -s                         # testar smb.conf
```

### RAID

```bash
cat /proc/mdstat                    # estado do RAID
mdadm --detail /dev/md0             # detalhes completos
mdadm /dev/md0 --fail /dev/sdX     # marcar disco como falho
mdadm /dev/md0 --remove /dev/sdX   # remover disco
mdadm /dev/md0 --add /dev/sdX      # adicionar disco
echo check > /sys/block/md0/md/sync_action  # verificação manual
```

### Firewall

```bash
nft list ruleset                    # ver todas as regras
systemctl reload nftables           # recarregar regras
journalctl -k --grep="nft-drop"    # ver pacotes bloqueados
fail2ban-client status              # status dos jails
fail2ban-client set samba unbanip IP  # desbanir IP
```

### Backup

```bash
# Backup manual
tar -czf /backup/samba/manual_$(date +%F_%H-%M).tar.gz /mnt/raid/shares /etc/samba/smb.conf

# Listar backups
ls -lh /backup/samba/

# Restaurar arquivo específico
tar -xzf /backup/samba/ARQUIVO.tar.gz mnt/raid/shares/NomeShare/arquivo.ext
```

### Diagnóstico rápido

```bash
smbstatus                           # quem está conectado agora
df -h /mnt/raid                     # espaço disponível
cat /proc/mdstat                    # saúde do RAID
tail -f /var/log/samba_panel.log    # log de auditoria em tempo real
tail -f /var/log/cdpni_portal_access.log  # acessos ao portal
journalctl -u smbd -f               # log do Samba em tempo real
```

---

*Manual CDPNI — versão 1.0 · Infraestrutura: nftables · Samba 4 · Flask 3.1 · PHP 8.3 · Ansible*
