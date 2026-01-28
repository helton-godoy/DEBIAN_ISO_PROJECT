#!/bin/bash
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
if ! command -v virt-install &> /dev/null; then
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
echo "Criando VM $VM_NAME..."
echo "  - RAM: ${RAM}MB"
echo "  - CPU: ${VCPUS}"
echo "  - Disco: ${DISK_SIZE}GB"
echo "  - ISO: $ISO_PATH"

# Nota: Usamos --network network=default para NAT. 
# Para AD, idealmente usaríamos --network bridge=br0 se disponível, 
# mas NAT permite acesso à internet (e ao AD se houver roteamento).

virt-install \
  --name "$VM_NAME" \
  --memory "$RAM" \
  --vcpus "$VCPUS" \
  --boot uefi \
  --disk size="$DISK_SIZE",format=qcow2,bus=virtio \
  --cdrom "$ISO_PATH" \
  --os-variant debian12 \
  --graphics none \
  --console pty,target_type=serial \
  --network network=default,model=virtio \
  --noautoconsole

echo -e "${GREEN}VM Criada!${NC}"
echo "Para acessar o console (boot log):"
echo "  virsh console $VM_NAME"
echo ""
echo "Para conectar via SSH (após instalação):"
echo "  1. Descubra o IP: virsh domifaddr $VM_NAME"
echo "  2. Conecte: ssh admin@IP_DA_VM"
