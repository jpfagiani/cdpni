#!/bin/bash

hostnamectl set-hostname gateway.cdpni.sap
cp -v /root/cdpni/gateway/network/*  /etc/network/
#cp -v /root/cdpni/gateway/etc/hostname  /etc/
cp -v /root/cdpni/gateway/etc/hosts  /etc/
cp -v /root/cdpni/gateway/etc/issue  /etc/
cp -v /root/cdpni/gateway/etc/issue.net  /etc/
cp -v /root/cdpni/gateway/etc/motd  /etc/
cp -v /root/cdpni/gateway/etc/resolv.conf /etc/
	chattr +i /etc/resolv.conf
systemctl disable firewalld
systemctl stop firewalld
apt install iptables-services openssh openssh-server -y
systemctl enable iptables
cp -v /root/cdpni/gateway/ssh/sshd_config   /etc/ssh/
	systemctl restart sshd
cp /root/cdpni/gateway/sbin/firewall.sh /sbin/
	chmod 775 /sbin/firewall.sh
	firewall.sh
iptables -t nat -L
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
init 6
	










