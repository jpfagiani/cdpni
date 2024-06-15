#!/bin/bash

#Definir as interfaces de rede

INTERNA=eth1
EXTERNA=eth0

#Definir as redes
REDE_IP_INTERNA=172.16.0.0/24
REDE_IP_EXTERNA=192.168.25.0/24

#Habilitar roteamento
echo 1 > /proc/sys/net/ipv4/ip_forward

#Habilitar TCP SynCookie
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

#Habilitar proteção ip spoofing
for i in /proc/sys/net/ipv4/conf/*/rp_filter
do
echo 1 > $i
done

#LIMPAR AS TABELAS
iptables -t filter -F
iptables -t filter -X
iptables -t filter -Z

iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z

iptables -t mangle -F
iptables -t mangle -X
iptables -t mangle -Z

# Definir política padrão
iptables -t filter -P INPUT DROP
iptables -t filter -P FORWARD DROP
iptables -t filter -P OUTPUT ACCEPT

#Realizar NAT
iptables -t nat -A POSTROUTING -s $REDE_IP_INTERNA -o $EXTERNA -j MASQUERADE

# Bloquear pacotes inválidos
iptables -t filter -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -t filter -A FORWARD -m conntrack --ctstate INVALID -j DROP

# Bloquear algumas tentativas de scanner
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,SYN -j DROP

#Permitir a máquina com IP 172.17.0.2 realizar ping para a interface do firewall
iptables -t filter -A INPUT -s 172.16.0.2/32 -d 172.16.0.1 -p icmp --icmp-type echo-request -m limit --limit 1/m -j ACCEPT
iptables -t filter -A INPUT -s 172.16.0.2/32 -d 172.16.0.1 -p icmp --icmp-type echo-request -j REJECT

# Permitir tráfego na interface de loopback
iptables -t filter -A INPUT -i lo -j ACCEPT

#Permitir acesso ao facebook para o MAC
iptables -t filter -A FORWARD -d www.facebook.com -m mac --mac-source 08:00:27:E7:6F:26 -j ACCEPT

# Bloquear facebook para todos
iptables -t filter -A FORWARD -d www.facebook.com -j LOG --log-prefix "Bloqueio-Facebook"

iptables -t filter -A FORWARD -d www.facebook.com -j DROP

#Bloquear download de arquivos .exe
iptables -t filter -A FORWARD -p tcp -m multiport --dport 20,21,80,443 -m string --string ".exe" --algo bm -j LOG --log-prefix "Download arquivo executável"

iptables -t filter -I FORWARD -m string --string "facebook" --algo bm -j DROP

#Permitir a rede interna acessar os serviços DNS, ftp, http e https
iptables -t filter -A FORWARD -p udp --dport 53 -j ACCEPT
iptables -t filter -A FORWARD -p tcp -m multiport --dport 20,21,80,443 -j ACCEPT

#Permitir a rede interna realizar ping para Internet
iptables -t filter -A FORWARD -s $REDE_IP_INTERNA -p icmp --icmp-type echo-request -j ACCEPT

#Permitir pacotes relacionados
iptables -t filter -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t filter -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#permissão no Terminal
#chmod 770 /etc/init.d/firewall.sh
#executar
#/etc/init.d/firewall.sh
#saber se deu erro
#iptables -nvL

#sempre ficar salvo
#terminal: update-rc.d firewall.sh defaults
------------

Squid
#configuração da placa de rede
#eth0 DHCP
#eth1
#172.16.0.1

#Configuração Básica
http_port 172.16.0.1:3128
visible_hostname Servidor-Proxy-ColegioSuperIncentivo
error_directory /usr/share/squid/errors/pt-br

cache_log /var/log/squid/cache.log
access_log daemon:/var/log/squid/acess.log squid

#Definições de cache do proxy
cache_mem 512 MB
maximum_object_size_in_memory 128 KB
cache_dir ufs /var/spool/squid 1000 16 256
maximum_object_size 1024 KB
minimum_object_size 0 KB
cache_swap_low 90
cache_swap_high 95

#Autenticação - necessario apache2-utils para gerar credenciais dos usuários
auth_param basic realm Servidor-Proxy-ColegioSuprIncentivo (Digite usuário | Senha)
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/usuarios.txt
auth_param basic children 5
authenticate_ttl 1 hour

# Lista de controle de acesso, ainda não está permitindo ou bloqueando
acl SSL_ports port 443
acl Safe_ports port 80 21 443
acl purge method PURGE
acl connect method CONNECT
acl redelocal src 172.16.0.0/24 #esse IP tem que ser o mesmo em todos os roteadores? o que seria /24?

# Lista de controle personalizada
acl redes_sociais1 dstdomain .linkedin.com .instagram.com .facebook.com
acl redes_sociais2 url_regex -i "/etc/squid/redes_sociais2.txt"
acl downloads_proibidos url_regex -i "/etc/squid/extensoes_proibidas.txt"
acl equipe_suporte src 172.16.0.2
acl recreio1 time MTWHFAS 10:15-10:30
acl recreio2 time MTWHFAS 15:15-15:30
acl autenticados proxy_auth REQUERID
acl professor proxy_auth professor

# Controle de acesso Customizado - Permissões - Sempre Permitir antes que Bloquear 1:03 video
http_access allow professor
http_access allow equipe_suporte downloads_proibidos
http_access allow redes_sociais1 recreio1
http_access allow redes_sociais2 recreio1
http_access allow redes_sociais1 recreio2
http_access allow redes_sociais2 recreio2


# Controle de acesso Customizado - Bloqueios#42:04 DO VIDEO
http_access deny redes_sociais1
http_access deny redes_sociais2
http_access deny downloads_proibidos
http_access allow autenticados


# Controle de acesso padrão
http_access allow localhost manager
http_access deny manager
http_access allow localhost purge
http_access deny purge
http_access deny !Safe_ports
http_access deny connect !SSL_ports
http_access allow redelocal

http_access deny all



