#!/bin/bash
# Mata o driver na força bruta para liberar o cabo USB (Fugindo da árvore do Systemd)
pkill -9 usbhid-ups
sleep 1

# Envia o pulso hexadecimal da morte para o Nobreak (inicia janela de 20s do hardware)
/usr/sbin/upsdrvctl shutdown

# Desliga o Raspberry Pi imediatamente
/sbin/shutdown -h now
