#!/bin/bash

apt install slapd ldap-utils -y
systemctl stop slapd
cp -pv /root/cdpni/intranet/ldap/slapd.conf  /etc/ldap/slapd.conf
slapppasswd >> /etc/ldap/slapd.conf
mv /etc/ldap/slapd.d /etc/ldap/slapd.d.old
mkdir /etc/ldap/slapd.d
chown openldap:openldap -R /var/lib/ldap /etc/ldap/slapd.d
systemctl restart slapd
slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
chown openldap:openldap -R /var/lib/ldap /etc/ldap/slapd.d
systemctl restart slapd
slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
systemctl status slapd
systemctl enable slapd
ss -ntpl
groupadd -g 5000 cpd
useradd -m -k /etc/skel/ -s /bin/bash -u 5000 -g cpd -G cpd jean
apt install migrationtools -y
cd /usr/share/migrationtools
vim /usr/share/migrationtools/migrate_common.ph
vim /usr/share/migrationtools/migrate_base.pl
vim /usr/share/migrationtools/migrate_passwd.pl
vim /usr/share/migrationtools/migrate_group.pl


	










