#!/bin/bash
# install-system-mockup-8
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS
# Desenvolvido com Antigravity Intelligence - 2026-01-28
#
# xAI: Grok Code Fast 1 (free)

set -e

# --- Configurações do Pool ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Funções de UI Aurora ---

logo() {
	clear
	# Logo monocromático com gradiente simulado e ícones textuais
	cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                ░▒▓ AURORA INSTALLER ▓▒░                      ║
║                                                              ║
║           Debian ZFS NAS - High Performance Storage          ║
║                                                              ║
║             ┌─────────────────────────────────┐              ║
║             │    ░ Enterprise Grade  ░        │              ║
║             │    ▒ Lightning Fast    ▒        │              ║
║             │    ▓ Secure & Reliable ▓        │              ║
║             └─────────────────────────────────┘              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
	echo ""
	gum style --foreground 245 --faint "Pressione ENTER para continuar..." && read -r
}

header() {
	gum style --foreground 123 --bold ">> $1"
}

error_box() {
	gum style --foreground 196 --border-foreground 196 --border double \
		--padding "1 2" --margin "1 2" --align center \
		"❌ ERRO CRÍTICO" "$1"
}

# --- Início do Script ---

logo

# 1. Verificações de Hardware
header "Verificando ambiente..."
if [[ ! -d /sys/firmware/efi ]]; then
	error_box "O sistema não iniciou via UEFI. O Aurora requer UEFI."
	exit 1
fi
gum style --foreground 40 " [OK] Ambiente UEFI detectado."

# 2. Seleção de Disco style "Proxmox"
header "Selecione o disco de destino"
echo "OBS: Todos os dados no disco selecionado serão APAGADOS."

DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1" ("$2") - "$3}')

if [[ -z "${DISK_LIST}" ]]; then
	error_box "Nenhum disco encontrado disponível para instalação."
	exit 1
fi

# Nota: gum choose 0.14+ exige PONTO para cursor.foreground
TARGET_SELECTED=$(echo "${DISK_LIST}" | gum choose --height 10 --cursor.foreground 212)
TARGET_DISK="/dev/$(echo "${TARGET_SELECTED}" | awk '{print $1}')"

# 3. Informações do Usuário com interface aprimorada
logo
header "👤 Configuração de Conta de Administrador"

echo ""
gum style --foreground 45 --bold "🔐 Credenciais de Acesso"
echo ""

ADM_USER=$(gum input \
	--placeholder "Nome do usuário administrador (ex: admin)" \
	--value "helton" \
	--header "Usuário:" \
	--width 50)

echo ""
header "🔑 Definição de Senha Segura"
echo "A senha será usada para o usuário${'$ADM_US}ER' e conta root."
echo ""

while true; do
	ADM_PASS=$(gum input --password \
		--placeholder "Digite uma senha forte (mínimo 8 caracteres)" \
		--header "Senha:" \
		--width 50)

	CONFIRM_PASS=$(gum input --password \
		--placeholder "Confirme a senha" \
		--header "Confirmação:" \
		--width 50)

	if [[ "${ADM_PASS}" = "${CONFIRM_PASS}" ]] && [[ -n "${ADM_PASS}" ]] && [[ ${#ADM_PASS} -ge 8 ]]; then
		gum style --foreground 40 "✅ Senha configurada com sucesso!"
		break
	else
		gum style --foreground 196 --border normal --padding "0 1" \
			"❌ Erro: Senhas não conferem ou são muito curtas (mínimo 8 caracteres)"
		echo ""
	fi
done

# 4. Confirmação Final com Tabela
logo
header "Resumo da Instalação"
echo ""
gum join --vertical \
	"$(gum style --width 20 "Disco:") $(gum style --foreground 212 "${TARGET_DISK}")" \
	"$(gum style --width 20 "Usuário:") $(gum style --foreground 212 ${$ADM_USE}R")" \
	"$(gum style --width 20 "Hostname:") $(gum style --foreground 212 "nas-zfs")" \
	"$(gum style --width 20 "Filesystem:") $(gum style --foreground 212 "ZFS on Root (ZBM)")"

echo ""
gum confirm "Confirmar início da instalação? O disco será formatado." --default=false \
	--affirmative "PROSSEGUIR" --negative "CANCELAR" || exit 1

# 5. Execução Técnica com interface aprimorada
logo

header "⚡ Iniciando Processo de Instalação Aurora"
echo ""
gum style --foreground 39 "Esta é uma simulação estética. Nenhuma operação real será executada."
echo ""

# Barra de progresso simulada
gum style --foreground 45 --bold "📊 Progresso da Instalação:"
echo ""

# Função para simular comandos com spinner (desativado para foco estético)
run_step() {
	local title="$1"
	local cmd="$2"
	gum spin --spinner dot --title "${title} (SIMULAÇÃO)" -- sleep 2
	gum style --foreground 40 " [SIMULADO] ${title}"
}

run_step "Limpando disco ${TARGET_DISK}..." "wipefs -a ${TARGET_DISK} && sgdisk --zap-all ${TARGET_DISK}"

run_step "Configurando EFI (512MB)..." "sgdisk -n 1:1M:+512M -t 1:EF00 ${TARGET_DISK} && mkfs.vfat -F 32 -n EFI ${TARGET_DISK}1"

run_step "Criando Pool ZFS (${POOL_NAME})..." "sgdisk -n 2:0:0 -t 2:BF01 ${TARGET_DISK} && \
            partprobe ${TARGET_DISK} && sleep 2 && \
            zpool create -f ${ZFS_OPTS} -R /mnt ${POOL_NAME} ${TARGET_DISK}2"

run_step "Criando Datasets ZFS (ROOT/debian)..." "zfs create -o mountpoint=none ${POOL_NAME}/ROOT && \
            zfs create -o mountpoint=/ -o canmount=noauto -o org.zfsbootmenu:commandline='quiet splash' ${POOL_NAME}/ROOT/debian && \
            zfs create -o mountpoint=/home ${POOL_NAME}/home && \
            zfs create -o mountpoint=/root ${POOL_NAME}/home/root && \
            zpool set bootfs=${POOL_NAME}/ROOT/debian ${POOL_NAME}"

run_step "Montando hierarquia ZFS..." "zpool export ${POOL_NAME} && zpool import -R /mnt ${POOL_NAME} && zfs mount ${POOL_NAME}/ROOT/debian && zfs mount -a && mkdir -p /mnt/boot/efi && mount ${TARGET_DISK}1 /mnt/boot/efi"

# Instalação Base (Clonagem)
header "Instalando sistema base..."
SQUASHFS="/run/live/medium/live/filesystem.squashfs"
if [[ ! -f "${SQUASHFS}" ]]; then
	error_box "Imagem SquashFS não encontrada."
	exit 1
fi

run_step "Extraindo arquivos para o ZFS (isto pode demorar)..." "unsquashfs -f -d /mnt ${SQUASHFS}"

# Configurações
header "Configurando instância..."
echo "nas-zfs" >/mnt/etc/hostname
cat <<EOF >/mnt/etc/hosts
127.0.0.1	localhost
127.0.1.1	nas-zfs
EOF

# Correção machine-id: Apaga para gerar de forma limpa no chroot
rm -f /mnt/etc/machine-id /mnt/var/lib/dbus/machine-id

cat <<EOF >/mnt/etc/systemd/network/20-wired.network
[Match]
Name=e*
[Network]
DHCP=yes
EOF

cat <<EOF >/mnt/etc/fstab
proc /proc proc defaults 0 0
UUID=$(blkid -s UUID -o value "${TARGET_DISK}1") /boot/efi vfat defaults 0 0
EOF

# ZFSBootMenu
header "Configurando Bootloader (ZFSBootMenu)..."
mkdir -p /mnt/boot/efi/EFI/ZBM
if [[ -f "/usr/local/bin/zfsbootmenu.efi" ]]; then
	cp /usr/local/bin/zfsbootmenu.efi /mnt/boot/efi/EFI/ZBM/zfsbootmenu.efi
else
	curl -L "https://get.zfsbootmenu.org/efi/master" -o /mnt/boot/efi/EFI/ZBM/zfsbootmenu.efi
fi
mkdir -p /mnt/boot/efi/EFI/BOOT
cp /mnt/boot/efi/EFI/ZBM/zfsbootmenu.efi /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI

# Chroot Finalization
header "Finalizando no Chroot..."
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

chroot /mnt /bin/bash <<EOF
# Gerar identificadores únicos para o sistema e para o ZFS
systemd-machine-id-setup
zgenhostid
zpool set cachefile=/etc/zfs/zpool.cache ${POOL_NAME}
update-initramfs -u -k all
useradd -m -s /bin/bash -G sudo "${ADM_USER}"
echo "${ADM_USER}:${ADM_PASS}" | chpasswd
echo "root:${ADM_PASS}" | chpasswd
if getent passwd user >/dev/null; then userdel -r user; fi
EOF

logo
gum style --foreground 40 --border-foreground 40 --border double --padding "1 2" \
	"INSTALAÇÃO CONCLUÍDA COM SUCESSO!" \
	"Usuário:${$ADM_USE}R" \
	"Dica: Remova a mídia Live e reinicie o sistema."

if gum confirm "Deseja reiniciar agora?"; then
	reboot
fi
