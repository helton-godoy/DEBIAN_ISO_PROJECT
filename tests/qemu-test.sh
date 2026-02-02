#!/usr/bin/env bash
# Teste simplificado usando QEMU direto

set -euo pipefail

ISO_PATH="/home/helton/git/DEBIAN_ISO_PROJECT/live_build/live-image-amd64.hybrid.iso"
DISK_PATH="/home/helton/git/DEBIAN_ISO_PROJECT/debian-zfs-test.qcow2"

# Criar disco se não existir
if [[ ! -f ${DISK_PATH} ]]; then
	echo "Criando disco virtual..."
	qemu-img create -f qcow2 "${DISK_PATH}" 20G
fi

echo "Iniciando VM com QEMU..."
echo "ISO: ${ISO_PATH}"
echo "Disco: ${DISK_PATH}"
echo ""
echo "Comandos disponíveis na VM live:"
echo "  sudo install-system --auto --disk /dev/vda --user admin --password admin --hostname test-nas"
echo ""
echo "Iniciando..."

qemu-system-x86_64 \
	-name debian-zfs-test \
	-m 4096 \
	-smp 4 \
	-boot d \
	-cdrom "${ISO_PATH}" \
	-drive file="${DISK_PATH}",format=qcow2,if=virtio \
	-netdev user,id=net0 \
	-device virtio-net-pci,netdev=net0 \
	-vga std \
	-display gtk 2>&1 &

QEMU_PID=$!
echo "QEMU iniciado com PID: ${QEMU_PID}"
echo "Aguardando 60 segundos para boot..."
sleep 60

# Verificar se QEMU ainda está rodando
if ps -p "${QEMU_PID}" >/dev/null; then
	echo "✓ QEMU está rodando"
	echo "Para conectar à VM, use um VNC viewer ou a interface gráfica"
	echo "PID do QEMU: ${QEMU_PID}"
else
	echo "✗ QEMU encerrou inesperadamente"
	exit 1
fi
