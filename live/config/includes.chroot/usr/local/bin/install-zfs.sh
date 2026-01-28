#!/bin/bash
# install-zfs.sh
# Instalador Personalizado: Debian 13 "Trixie" com ZFS Boot Menu e Samba AD
# Data: 2026-01-28

set -e

# Configurações do Pool
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

echo "=== Instalador Debian ZFS NAS ==="
echo "ATENÇÃO: Este script apagará TODOS os dados do disco selecionado."
read -p "Digite o disco de destino (ex: /dev/sda): " TARGET_DISK

if [ ! -b "$TARGET_DISK" ]; then
    echo "Erro: Disco inválido."
    exit 1
fi

echo "Iniciando particionamento em $TARGET_DISK..."

# 1. Limpeza e Particionamento
wipefs -a "$TARGET_DISK"
sgdisk --zap-all "$TARGET_DISK"
# Partição 1: ESP (EFI System Partition) - 512MB
sgdisk -n 1:1M:+512M -t 1:EF00 "$TARGET_DISK"
# Partição 2: ZFS Pool - Resto do disco
sgdisk -n 2:0:0 -t 2:BF01 "$TARGET_DISK"

partprobe "$TARGET_DISK"
sleep 2

# 2. Formatação e Criação do Pool
mkfs.vfat -F 32 -n EFI "${TARGET_DISK}1"

echo "Criando Pool ZFS ($POOL_NAME)..."
zpool create -f $ZFS_OPTS -R /mnt "$POOL_NAME" "${TARGET_DISK}2"

# 3. Criação dos Datasets (Hierarquia Boot Environment)
zfs create -o mountpoint=none "$POOL_NAME/ROOT"
zfs create -o mountpoint=/ -o canmount=noauto "$POOL_NAME/ROOT/debian"
zfs create -o mountpoint=/home "$POOL_NAME/home"
zfs create -o mountpoint=/root "$POOL_NAME/home/root"

# Exportar Pool e Reimportar para montar corretamente
zpool export "$POOL_NAME"
zpool import -R /mnt "$POOL_NAME"
zfs mount "$POOL_NAME/ROOT/debian"
zfs mount -a

# Montar ESP
mkdir -p /mnt/boot/efi
mount "${TARGET_DISK}1" /mnt/boot/efi

# 4. Instalação Offline (SquashFS Clone)
echo "Instalando sistema base (Clonagem via SquashFS)..."

# Localizar a mídia de instalação
LIVE_MEDIA="/run/live/medium"
SQUASHFS="$LIVE_MEDIA/live/filesystem.squashfs"

if [ ! -f "$SQUASHFS" ]; then
    # Fallback: tentar encontrar montando devices se não estiver em /run
    # (Simplificação para este POC)
    echo "ERRO: filesystem.squashfs não encontrado em $SQUASHFS"
    exit 1
fi

echo "Descompactando imagem do sistema ($SQUASHFS)..."
# Excluir /boot/* do squashfs pois vamos popular o ESP e o ZBM separadamente se necessario,
# mas aqui vamos manter simples e descompactar tudo, depois ajustamos.
unsquashfs -f -d /mnt "$SQUASHFS"

# 5. Configuração Pós-Clonagem
echo "Configurando nova instância..."
echo "nas-zfs" > /mnt/etc/hostname
echo "127.0.0.1	localhost" > /mnt/etc/hosts
echo "127.0.1.1	nas-zfs" >> /mnt/etc/hosts

# Gerar novos machine-id para não ser um clone identico
rm -f /mnt/etc/machine-id /mnt/var/lib/dbus/machine-id
dbus-uuidgen --ensure=/mnt/etc/machine-id

# Gerar config de Rede simples (DHCP)
cat <<EOF > /mnt/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

cat <<EOF > /mnt/etc/fstab
# /etc/fstab: static file system information.
proc /proc proc defaults 0 0
# ZFS gerencia montagens, exceto EFI
UUID=$(blkid -s UUID -o value "${TARGET_DISK}1") /boot/efi vfat defaults 0 0
EOF

# 6. Reinstalação do Bootloader (Chroot)
# Como clonamos o sistema "Live", ele tem kernels e grub instalados, mas
# precisamos reconfigurar o GRUB/ZBM para o ZFS real e não o LiveCD.

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

echo "Entrando no chroot para configurar ZFSBootMenu..."
chroot /mnt /bin/bash <<CHROOT_EOF
update-initramfs -u -k all
# Aqui configuraríamos o ZBM ou GRUB final
# zfsbootmenu-generate ...
CHROOT_EOF

echo "Instalação Offline Concluída."

