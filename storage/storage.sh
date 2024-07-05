#!/bin/bash

hostnamectl set-hostname storage.cdpni.gov
cp -v /root/cdpni/storage/network/interfaces /etc/network/
cp -v /root/cdpni/storage/etc/*  /etc/
	chattr +i /etc/resolv.conf
apt install openssh-server mdadm -y
cp -v /root/cdpni/storage/ssh/sshd_config /etc/ssh/
	systemctl restart networking sshd
mdadm --create /dev/md0 --level=5 --raid-devices=4 /dev/sdb /dev/sdc /dev/sdd /dev/sde
mkfs -t ext4 /dev/md0
tune2fs -L samba /dev/md0
mkdir -pv /srv/samba/
echo -e "LABEL=samba \t\t /srv/samba/ \t\t ext4  defaults 0 0"  >> /etc/fstab
mount -a
for i in homes drivers lixeiras administrativo aevp almoxarifado canil cimic cpd dcsd educacao financas inclusao infraestrutura publico saude scanner sindicancia supervisao wallpaper; do mkdir -pv /srv/samba/$i; done
for i in chefia_turno_I chefia_turno_II chefia_turno_III chefia_turno_IV conexao_familiar diretoria_geral diretoria_de_centro nucleo_de_pessoal; do mkdir -pv /srv/samba/$i; done
for i in portaria_turno_I portaria_turno_II portaria_turno_III portaria_turno_IV rol_de_visitas; do mkdir -pv /srv/samba/$i; done
chmod a+w /srv/samba/*

