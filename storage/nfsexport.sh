#!/bin/bash

apt install nfs-common nfs-kernel-server -y
systemctl start nfs-server
systemctl enable nfs-server
for i in homes drivers lixeiras administrativo aevp almoxarifado canil cimic cpd dcsd educacao financas inclusao infraestrutura publico saude scanner sindicancia supervisao wallpaper;  do echo -e "/srv/samba/$i  \t\t 10.14.29.0/24(rw,no_root_squash,no_subtree_check)" >> /etc/exports; done
for i in chefia_turno_I chefia_turno_II chefia_turno_III chefia_turno_IV conexao_familiar diretoria_geral diretoria_de_centro nucleo_de_pessoal;  do echo -e "/srv/samba/$i  \t\t 10.14.29.0/24(rw,no_root_squash,no_subtree_check)" >> /etc/exports; done
for i in portaria_turno_I portaria_turno_II portaria_turno_III portaria_turno_IV rol_de_visitas; do echo -e "/srv/samba/$i  \t\t 10.14.29.0/24(rw,no_root_squash,no_subtree_check)" >> /etc/exports; done
exportfs -r
# ou systemctl restart nfs-server
showmount -e 10.14.29.11
