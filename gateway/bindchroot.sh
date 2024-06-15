#!/bin/bash

apt update
hostnamectl set-hostname gateway.cdpni.sap
apt install openssh-server bind9 bind9utils dnsutils -y
cd /root
cp -v /root/cdpni/gateway/etc/* /etc
cp -v /root/cdpni/gateway/network/interfaces /etc/network/
cp -v /root/cdpni/gateway/ssh/sshd_config /etc/ssh/
	chattr +i /etc/resolv.conf
systemctl restart sshd	
systemctl stop named
systemctl stop apparmor
cp -v /root/cdpni/gateway/default/named /etc/default/
mkdir -pv /var/bind9/chroot/{etc,dev,var/cache/bind,var/run/named} 
	mv -v /etc/bind /var/bind9/chroot/etc
	ln -s /var/bind9/chroot/etc/bind /etc/bind
	cp -v /etc/localtime /var/bind9/chroot/etc/	
	chown bind:bind -R /var/bind9/chroot/etc/bind/rndc.key /var/bind9/chroot/var/
	chmod 775 -R /var/bind9/chroot/var/
cp -av /dev/null /var/bind9/chroot/dev/
cp -av /dev/random /var/bind9/chroot/dev/
	chmod 660 /var/bind9/chroot/dev/{null,random}
cp -av /root/cdpni/gateway/init.d/named /etc/init.d	
cp -v /root/gateway/apparmor.d/usr.sbin.named /etc/apparmor.d/	
cp -av /usr/share/dns/root.hints /var/bind9/chroot/var/cache/bind
cp -v /root/cdpni/gateway/bind_chroot/etc/bind/named.conf* /etc/bind
cp -v /root/cdpni/gateway/bind_chroot/bind/* /var/bind9/chroot/var/cache/bind
	chgrp bind /var/bind9/chroot/var/{cache/bind,run/named}
systemctl restart apparmor named
systemctl status named apparmor
echo "\$AddUnixListenSocket /var/bind9/chroot/dev/log" > /etc/rsyslog.d/bind-chroot.conf
systemctl disable firewalld
systemctl stop firewalld
systemctl enable iptables
cp /root/cdpni/gateway/sbin/firewall.sh /sbin/
	chmod 775 /sbin/firewall.sh
	firewall.sh
iptables -t nat -L
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
init 6



