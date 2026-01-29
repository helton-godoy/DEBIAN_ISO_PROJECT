#!/usr/bin/env bash
# vm-start-system-installed.sh
# Objetivo: Bootar a VM a partir do disco (pós-instalação) para validação
# Data: 2026-01-28

VM_NAME="debian-zfs-lab"
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Bootando Sistema Instalado (Validação) ===${NC}"

# 1. Parar a VM se estiver rodando (Force off)
if virsh list --name | grep -q "^$VM_NAME$"; then
	echo "Parando VM ativa..."
	virsh destroy "$VM_NAME" >/dev/null
fi

# 2. Ejetar a ISO (Garantir que não boote o LiveCD de novo)
# Identificar o dispositivo de CDROM (normalmente sda ou hda quando disco principal é vda)
ISO_DEV=$(virsh domblklist "$VM_NAME" | grep ".iso" | awk '{print $1}')

if [ -n "$ISO_DEV" ]; then
	echo "Ejetando ISO do dispositivo $ISO_DEV..."
	virsh change-media "$VM_NAME" "$ISO_DEV" --eject --config >/dev/null 2>&1
	# Se falhar porque já está ejetado, ignoramos
else
	echo "ISO já parece estar desconectada ou não encontrada."
fi

# 3. Iniciar a VM
echo "Iniciando $VM_NAME..."
virsh start "$VM_NAME" >/dev/null

# 4. Conectar ao Console
echo -e "${GREEN}Conectando ao console serial...${NC}"
echo "(Pressione Ctrl+] para sair do console a qualquer momento)"
echo "---------------------------------------------------------"
virsh console "$VM_NAME"
