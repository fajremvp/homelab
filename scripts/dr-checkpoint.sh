#!/usr/bin/env bash
# Homelab - DR Checkpoint
# Foco: Extração de VZDumps e Configurações para acelerar a reconstrução manual da infraestrutura.

set -euo pipefail

START_TIME=$(date +%s)

# Criação do Checkpoint
DATE=$(date +%Y-%m-%d_%H-%M-%S)
CHECKPOINT_DIR="/mnt/backup-hd/dr-checkpoint-$DATE"

# Inventário
PROXMOX="root@192.168.1.200"
MANAGEMENT="root@10.10.10.10"
ADGUARD="root@10.10.30.5"
DOCKERHOST="fajre@10.10.30.10"
ORANGESHADOW="fajre@10.10.30.20"

echo "Iniciando DR Checkpoint - $DATE"
echo "Destino: $CHECKPOINT_DIR"
echo "------------------------------------------------------"

mkdir -p "$CHECKPOINT_DIR"/{vms-baremetal,configs}

# ==========================================
# PREPARAÇÃO DE DUMPS CONSISTENTES
# ==========================================
echo "=> [1/3] Garantindo consistência de bancos de dados locais..."
ssh $DOCKERHOST "sudo bash -c 'docker exec authentik-postgres pg_dump -U authentik authentik > /opt/auth/authentik/authentik_dump.sql'"

# ==========================================
# PROXMOX: VZDUMP (WORKLOAD COMPLETO)
# ==========================================
echo "=> [2/3] Extraindo imagem de todas as VMs para qmrestore/pct restore..."
ssh $PROXMOX "vzdump 100 101 102 105 107 --mode snapshot --compress zstd --dumpdir /var/lib/vz/dump"

echo "   - Copiando dumps (.vma.zst) para o disco local..."
rsync -avh --progress $PROXMOX:/var/lib/vz/dump/ "$CHECKPOINT_DIR/vms-baremetal/"

echo "   - Limpando host Proxmox..."
ssh $PROXMOX "rm -f /var/lib/vz/dump/*.vma.zst /var/lib/vz/dump/*.tar.zst /var/lib/vz/dump/*.log"

# ==========================================
# CONFIGURAÇÕES: HYPERVISOR E INVENTÁRIO
# ==========================================
echo "=> [3/3] Extraindo templates de configuração para o Bootstrap manual..."

# PROXMOX HOST
echo "   - Extraindo Proxmox Host (Separação por Criticidade)..."
mkdir -p "$CHECKPOINT_DIR/configs/proxmox-host/core"
mkdir -p "$CHECKPOINT_DIR/configs/proxmox-host/auxiliary"

# CORE
rsync -avh -R \
    $PROXMOX:/etc/pve/storage.cfg \
    $PROXMOX:/etc/pve \
    $PROXMOX:/etc/network/interfaces \
    $PROXMOX:/etc/hosts \
    $PROXMOX:/etc/hostname \
    $PROXMOX:/etc/fstab \
    "$CHECKPOINT_DIR/configs/proxmox-host/core/"

# Auxiliares de Bootstrap
rsync -avh -R \
    $PROXMOX:/etc/crypttab \
    $PROXMOX:/etc/kernel/cmdline \
    $PROXMOX:/etc/fail2ban/jail.d \
    "$CHECKPOINT_DIR/configs/proxmox-host/auxiliary/"

# DOCKERHOST (105)
echo "   - Extraindo DockerHost..."
mkdir -p "$CHECKPOINT_DIR/configs/dockerhost"
rsync -avh --rsync-path="sudo rsync" --exclude="*.log" --exclude="*.sqlite3-wal" \
    $DOCKERHOST:/opt/services $DOCKERHOST:/opt/auth $DOCKERHOST:/opt/monitoring \
    $DOCKERHOST:/opt/security $DOCKERHOST:/opt/utils \
    "$CHECKPOINT_DIR/configs/dockerhost/"

# SYNCTHING
echo "   - Extraindo Syncthing..."
mkdir -p "$CHECKPOINT_DIR/syncthing"

rsync -avh --progress --rsync-path="sudo rsync" \
    $DOCKERHOST:/mnt/syncthing/ \
    "$CHECKPOINT_DIR/syncthing/"

# ADGUARD (101)
echo "   - Extraindo AdGuard..."
mkdir -p "$CHECKPOINT_DIR/configs/adguard"
rsync -avh --rsync-path="sudo rsync" --exclude="*.log" \
    $ADGUARD:/opt/AdGuardHome \
    "$CHECKPOINT_DIR/configs/adguard/"

# MANAGEMENT (102)
echo "   - Extraindo Management..."
mkdir -p "$CHECKPOINT_DIR/configs/management"
rsync -avh --rsync-path="sudo rsync" --exclude=".git" \
    $MANAGEMENT:/opt/homelab $MANAGEMENT:/root/.ssh $MANAGEMENT:/root/.config/sops/age \
    "$CHECKPOINT_DIR/configs/management/"

# ORANGESHADOW (107)
echo "   - Extraindo OrangeShadow..."
mkdir -p "$CHECKPOINT_DIR/configs/orangeshadow"
rsync -avh -R \
    $ORANGESHADOW:/home/fajre/.bitcoin/bitcoin.conf \
    $ORANGESHADOW:/etc/systemd/system/bitcoind.service \
    $ORANGESHADOW:/etc/tor/torrc \
    $ORANGESHADOW:/home/fajre/.electrs/config.toml \
    $ORANGESHADOW:/etc/systemd/system/electrs.service \
    $ORANGESHADOW:/home/fajre/.bitmonero/bitmonero.conf \
    $ORANGESHADOW:/etc/systemd/system/monerod.service \
    "$CHECKPOINT_DIR/configs/orangeshadow/"

echo "------------------------------------------------------"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))
SECONDS_REMAINING=$((ELAPSED % 60))

CHECKPOINT_SIZE=$(du -sh "$CHECKPOINT_DIR" | cut -f1)

echo "✅ DR Checkpoint ($DATE) concluído."
echo
echo "📂 Local: $CHECKPOINT_DIR"
echo "📦 Tamanho: $CHECKPOINT_SIZE"
echo "⏱️ Tempo decorrido: ${HOURS}h ${MINUTES}m ${SECONDS_REMAINING}s"
echo
echo "💾 Espaço livre no HD:"
df -h "$CHECKPOINT_DIR" | tail -1 | awk '{print "   Disponível: " $4 " / Total: " $2}'
