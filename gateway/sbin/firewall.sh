#!/bin/bash

# Rede interna
GTW=10.14.29.1
INT=10.14.29.2
STG=10.14.29.4
AD=10.14.29.3
#CLI=10.14.29.15
LAN=10.14.29.0/24

# Link Dedicado (FAKE INTERNET)
FWL1=200.50.100.10
LNK=200.50.100.0/24

# Internet
DIP=10.0.2.15
WAN=10.0.2.0/24

# Habilita o passagem de pacotes
echo 1 > /proc/sys/net/ipv4/ip_forward

# Politicas padroes do firewall
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Limpa todas chains
iptables -t nat -F
iptables -t filter -F

# Limpa as chains de usuarios
iptables -X

# Zera os contadores do iptables
iptables -Z

#####################
### INPUT SESSION ###
#####################

# 1 - Habilita o loopback
iptables -A INPUT -i lo -j ACCEPT

# 2 - Permite o retorno de conexoes estabelecidas e relacionadas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3 - Habilita a entrada do ICMP
iptables -A INPUT -p icmp --icmp-type echo-request -i enp0s8 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -i enp0s9 -j ACCEPT

# 4 - Habilita o SSH do node Cliente Interno e Externo
iptables -A INPUT -p tcp --dport 52001 -j ACCEPT
#iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 5 - Habilita o INPUT do NTP para clientes Internos e Externo
#iptables -A INPUT -p udp -i enp0s8 -s $LAN -d $GTW --dport 123 -j ACCEPT
#iptables -A INPUT -p udp -i enp0s9 -s $EXT -d $FWL1 --dport 123 -j ACCEPT

# 6 - Habilita o INPUT vindo de DNSs para o gateway
iptables -A INPUT -p udp --sport 53 -j ACCEPT

# 7 - Habilita o INPUT para o proxy. OBS: Desabilitar FORWARD para 80 e 443
#iptables -A INPUT -p tcp -i enp0s8 -s $LAN -d $GTW --dport 3128 -j ACCEPT

# 8 - Habilita o INPUT para VPN vindo do cliente Externo
#iptables -A INPUT -p udp -i enp0s9 -s $EXT -d $FWL1 --dport 1194 -j ACCEPT

# 9 - Permite requisições DHCP porta 67
iptables -A INPUT -p udp --dport 67 -j ACCEPT


######################
### OUTPUT SESSION ###
######################

# 1 - Habilita o loopback
iptables -A OUTPUT -o lo -j ACCEPT

# 2 - Permite o retorno de conexoes estabelecidas e relacionadas
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3 - Habilita o OUTPUT do ICMP
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

# 4 - Habilita o OUTPUT do NTP
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

# 5 - Habilita a resolucao de nomes 
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# 6 - Habilita o OUTPUT para HTTP e HTTPS
iptables -A OUTPUT -p tcp -o enp0s3 -s $DIP -m multiport --dports 80,443 -j ACCEPT

# 7 - Habilita o OUTPUT para autenticar no OpenLDAP
#iptables -A OUTPUT -p tcp -o enp0s8 -s $GTW --dport 389 -j ACCEPT

# 8 - Habilita o envio de logs para o node Storage
#iptables -A OUTPUT -p udp -o enp0s8 -s $GTW -d $STG --dport 514 -j ACCEPT

# 9 - SSH Cliente externo
#iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT


###############
### FORWARD ###
###############

# 1 - Permite o FORWARD do ICMP
iptables -A FORWARD -p icmp -s $LAN --icmp-type echo-request -o enp0s3 -j ACCEPT
iptables -A FORWARD -p icmp -s $LAN --icmp-type echo-request -o enp0s9 -j ACCEPT

# 2 - Permite o retorno de conexoes estabelecidas
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3 - Habilita o FORWARD da LAN para HTTP e HTTPS
iptables -A FORWARD -p tcp -s $LAN -o enp0s3 -m multiport --dports 80,443 -j ACCEPT
iptables -A FORWARD -p tcp -s $LAN -o enp0s9 -m multiport --dports 80,443 -j ACCEPT

# 4 - Habilita o FORWARD para DNSs
iptables -A FORWARD -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -p udp --sport 53 -j ACCEPT

# 5 - Habilita o FORWARD da LAN para MTAs
iptables -A FORWARD -p tcp -s $LAN -m multiport --dports 25,110,143,587,993,995 -j ACCEPT

# 6 - Habilita o FORWARD da LAN para FTPs
iptables -A FORWARD -p tcp -s $LAN -o enp0s3 -m multiport --dports 20,21 -j ACCEPT 

# 7 - Habilita a passagem do SSH entre cliente Externo e Interno
#iptables -A FORWARD -p tcp -i enp0s9 -s $EXT -d $CLI --dport 52015 -j ACCEPT

# 8 - Habilita o FORWARD para acesso ao MTA
#iptables -A FORWARD -p tcp -i enp0s9 -s $LNK -d $DTC -m multiport --dports 25,110,143,465,587,993,995 -j ACCEPT

# 9 - Habilita o FORWARD para acesso ao WWW
#iptables -A FORWARD -p tcp -i enp0s9 -s $LNK -d $STG -m multiport --dports 80,443 -j ACCEPT

# 10 - Habilita o FORWARD para autenticacao externa no LDAP
#iptables -A FORWARD -p tcp -i enp0s9 -s $LNK --dport 389 -j ACCEPT

#ssh PORT 2010,52011,52012,52015
iptables -A FORWARD -p tcp -m multiport --dports 52010,52011,52012,52015 -j ACCEPT


###################
### NAT SESSION ###
###################

# 1 - Habilita o acesso a internet para LAN
iptables -t nat -A POSTROUTING -s $LAN -o enp0s3 -j MASQUERADE

# 2 - Habilita a resolucao de nomes do cliente Externo
#iptables -t nat -A PREROUTING -p udp -i enp0s9 -s $LNK -d $FWL1 --dport 53 -j DNAT --to-destination $INT:53
#iptables -t nat -A PREROUTING -p udp -i enp0s9 -s $LNK -d $FWL2 --dport 53 -j DNAT --to-destination $DTC:53

# 3 - Habilita o acesso SSH do cliente externo para o node Interno
#iptables -t nat -A PREROUTING -p tcp -i enp0s9 -s $EXT -d $FWL1 --dport 52020 -j DNAT --to-destination $CLI:52015

# 4 - Habilita acesso do cliente Externo a aplicacao
#for WEB in 80 443
#    do
#        iptables -t nat -A PREROUTING -p tcp -i enp0s9 -s $LNK -d $FWL1 --dport $WEB -j DNAT --to-destination $STG:$WEB
#done 

# 5 - Habilita acesso do clente Externo ao MTA
#for MAIL in 25 110 143 587 993 995 465
#    do
#        iptables -t nat -A PREROUTING -p tcp -d $FWL2 --dport $MAIL -j DNAT --to-destination $DTC:$MAIL
#done

# 6 - Habilita autenticacao LDAP para cliente Externo
#iptables -t nat -A PREROUTING -p tcp -i enp0s9 -s $LNK -d $FWL2 --dport 389 -j DNAT --to-destination $DTC:389

# 7 - Habilita acesso via SSH pelo host fisico
iptables -t nat -A PREROUTING -p tcp -i enp0s9 -d $FWL1 --dport 52002 -j DNAT --to-destination $INT:52002
iptables -t nat -A PREROUTING -p tcp -i enp0s9 -d $FWL1 --dport 52004 -j DNAT --to-destination $STG:52004
iptables -t nat -A PREROUTING -p tcp -i enp0s9 -d $FWL1 --dport 52003 -j DNAT --to-destination $AD:52003
iptables -t nat -A PREROUTING -p tcp -i enp0s9 -d $FWL1 --dport 52015 -j DNAT --to-destination $INT:52015

if [ $? == 0 ] ; then 
  service iptables save
  mkdir -p /etc/firewall
  iptables-save > /etc/firewall/firewall.sh
fi
