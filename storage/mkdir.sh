#!/bin/bash

for i in homes drivers lixeiras administrativo aevp almoxarifado canil cimic cpd dcsd educacao financas inclusao infraestrutura publico saude scanner sindicancia supervisao wallpaper 
chefia_turno_I chefia_turno_II chefia_turno_III chefia_turno_IV conexao_familiar diretoria_geral diretoria_de_centro nucleo_de_pessoal
portaria_turno_I portaria_turno_II portaria_turno_III portaria_turno_IV rol_de_visitas; do mkdir -pv /srv/samba/$i; done
chmod a+w /srv/samba/*
