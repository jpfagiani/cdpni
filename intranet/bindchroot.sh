#!/bin/bash

hostnamectl set-hostname intranet.sap.gov
apt install openssh-server bind9 bind9utils dnsutils -y
cp -v /root/cdpni/intranet/network/interfaces /etc/network/
cp -v /root/cdpni/intranet/ssh/sshd_config /etc/ssh/
#cp -v /root/cdpni/intranet/etc/hostname  /etc/
cp -v /root/cdpni/intranet/etc/hosts  /etc/
cp -v /root/cdpni/intranet/etc/hosts.allow  /etc/
cp -v /root/cdpni/intranet/etc/hosts.deny  /etc/
cp -v /root/cdpni/intranet/etc/issue  /etc/
cp -v /root/cdpni/intranet/etc/issue.net  /etc/
cp -v /root/cdpni/intranet/etc/motd  /etc/
cp -v /root/cdpni/intranet/etc/resolv.conf /etc/
	chattr +i /etc/resolv.conf
systemctl stop named
cp -v /root/cdpni/intranet/default/named /etc/default/
mkdir -pv /var/bind9/chroot/{etc,dev,var/cache/bind,var/run/named} 
	mv -v /etc/bind /var/bind9/chroot/etc
cp -av /dev/null /var/bind9/chroot/dev/
cp -av /dev/random /var/bind9/chroot/dev/
	chmod 660 /var/bind9/chroot/dev/{null,random}
ln -s /var/bind9/chroot/etc/bind /etc/bind
cp -v /etc/localtime /var/bind9/chroot/etc/
cp -v /root/cdpni/intranet/init.d/named /etc/init.d/
systemctl stop apparmor
cp -v /root/cdpni/intranet/apparmor.d/usr.sbin.named /etc/apparmor.d/
cp -av /usr/share/dns/root.hints /var/bind9/chroot/var/cache/bind
cp -v /root/cdpni/intranet/bind_chroot/etc/bind/named.conf* /etc/bind
cp -v /root/cdpni/intranet/bind_chroot/bind/* /var/bind9/chroot/var/cache/bind
chown bind:bind -R /var/bind9/chroot/etc/bind/rndc.key
chmod 775 -R /var/bind9/chroot/var/{cache/bind,run/named}
chgrp bind /var/bind9/chroot/var/{cache/bind,run/named}
systemctl restart apparmor named
echo "\$AddUnixListenSocket /var/bind9/chroot/dev/log" > /etc/rsyslog.d/bind-chroot.conf
init 6








