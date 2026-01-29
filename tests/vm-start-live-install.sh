#!/usr/bin/env bash
# vm-start-live-install.sh
# Objetivo: Criar VM para testar a ISO do Debian ZFS recém-criada
# Requisitos: libvirt-daemon-system, virtinst, qemu-kvm
# Data: 2026-01-28

VM_NAME="debian-zfs-lab"
ISO_PATH="./live_build/live-image-amd64.hybrid.iso"
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
DISK_SIZE="20" # GB
RAM="4096"
VCPUS="4"

# Cores
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Configuração de Ambiente de Testes (Virsh/KVM) ===${NC}"

# 1. Verificações
if ! command -v virt-install &>/dev/null; then
	echo "ERRO: virt-install não encontrado. Instale: sudo apt install virtinst"
	exit 1
fi

if [ ! -f "$ISO_PATH" ]; then
	echo "ALERTA: ISO não encontrada em $ISO_PATH."
	echo "Certifique-se de rodar o ./build_live.sh primeiro."
	read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 1; fi
fi

# 2. Limpeza de VM anterior
if virsh list --all | grep -q "$VM_NAME"; then
	echo "Removendo VM anterior ($VM_NAME)..."
	virsh destroy "$VM_NAME" 2>/dev/null
	virsh undefine "$VM_NAME" --nvram --remove-all-storage 2>/dev/null
fi

# 3. Criação da VM
echo "
  Criando VM $VM_NAME...
  - RAM: ${RAM}MB
  - CPU: ${VCPUS}
  - Disco: ${DISK_SIZE}GB
  - ISO: $ISO_PATH
"

# Nota: Usamos User Mode Networking (SLIRP) para funcionar sem root/sudo.
# Mapeamos a porta 2222 do host para a 22 da VM para acesso SSH.

virt-install \
	--name "$VM_NAME" \
	--memory "$RAM" \
	--vcpus "$VCPUS" \
	--boot uefi \
	--disk size="$DISK_SIZE",format=qcow2,bus=virtio \
	--location "$ISO_PATH" \
	--os-variant debian12 \
	--graphics none \
	--console pty,target_type=serial \
	--network network=default,model=virtio \
	--extra-args "console=ttyS0,115200n8 serial" \
	--noautoconsole

echo -e "${GREEN}VM Criada!${NC}"
echo "
  Para acessar o console (boot log):
    virsh console $VM_NAME

  Para conectar via SSH (após instalação):
    Comando: ssh -p 2222 helton@localhost
    (Senha padrão definida na ISO ou 'live'/'live' se for live system)
    "
