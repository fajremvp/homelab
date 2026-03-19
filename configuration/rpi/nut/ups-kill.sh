#!/bin/bash

# Baseado no tempo de shutdown real do Proxmox (77s) + 63s de margem de segurança.
# Garante que o OPNsense, Vault, AdGuard, DockerHost e OrangeShadow sejam desligados e o ZFS seja exportado com segurança.
sleep 140

# Mata o driver na força bruta para liberar o cabo USB (Fugindo da árvore do Systemd)
pkill -9 usbhid-ups
sleep 1

# Envia o pulso hexadecimal da morte para o Nobreak (inicia janela de 20s do hardware)
/usr/sbin/upsdrvctl shutdown

# Desliga o Raspberry Pi imediatamente
/sbin/shutdown -h now
