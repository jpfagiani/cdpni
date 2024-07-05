#!/bin/bash

apt update 
hostnamectl set-hostname ad.cdpni.sap
apt install openssh-server nfs-client samba krb5-config winbind krb5-user smbclient -y
cp -v /root/cdpni/samba/network/interfaces /etc/network
cp -v /root/cdpni/samba/ssh/sshd_config /etc/ssh
	systemctl restart networking sshd
cp -v /root/cdpni/samba/etc/hostname  /etc/
cp -v /root/cdpni/samba/etc/hosts  /etc/
cp -v /root/cdpni/samba/etc/hosts.allow  /etc/
cp -v /root/cdpni/samba/etc/hosts.deny  /etc/
cp -v /root/cdpni/samba/etc/issue  /etc/
cp -v /root/cdpni/samba/etc/issue.net  /etc/
cp -v /root/cdpni/samba/etc/motd  /etc/
cp -v /root/cdpni/samba/etc/resolv.conf /etc/
	chattr +i /etc/resolv.conf
 mv /etc/samba/smb.conf smb.conf.old
 samba-tool domain provision --use-rfc2307 --interactive
cp -v /root/cdpni/samba/samba/smb.conf /etc/samba/
cp -v /root/cdpni/samba/etc/fstab /etc/
cp -v /root/cdpni/samba/etc/krb5.conf /etc/
