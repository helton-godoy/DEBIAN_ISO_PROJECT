#!/bin/bash
# install-system-mockup-5
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS (Mockup Estético)
# Desenvolvido com Antigravity Intelligence - 2026-01-29
#
# Giga Potato (free)

set -e

# --- Configurações do Pool (Mockup) ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Funções de UI Aurora Melhoradas ---

logo() {
	clear
	# ASCII Art Aurora
	cat <<'EOF'
    █████╗ ██╗     ██████╗ ███████╗██████╗ 
   ██╔══██╗██║     ██╔══██╗██╔════╝██╔══██╗
   ███████║██║     ██████╔╝█████╗  ██████╔╝
   ██╔══██║██║     ██╔══██╗██╔══╝  ██╔══██╗
   ██║  ██║███████╗██████╔╝███████╗██║  ██║
   ╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝
EOF
	# Nota: gum style 0.14+ exige hífen para border-foreground
	gum style \
		--foreground 212 --border-foreground 212 --border double \
		--align center --width 60 --margin "1 2" --padding "0 1" \
		"AURORA INSTALLER" "Debian ZFS NAS - High Performance Storage"
}

header() {
	gum style --foreground 123 --bold ">> $1"
}

error_box() {
	# Nota: gum style 0.14+ exige hífen para border-foreground
	gum style --foreground 196 --border-foreground 196 --border normal \
		--padding "0 1" --margin "1 1" "ERRO: $1"
}

success_box() {
	gum style --foreground 40 --border-foreground 40 --border normal \
		--padding "0 1" --margin "1 1" "SUCESSO: $1"
}

# --- Simulador de Operações ---
simulate_step() {
	local title="$1"
	local duration="${2:-2}"

	# Simula progresso com delay
	gum spin --spinner dot --title "$title" -- bash -c "sleep $duration"
}

# --- Início do Script ---

logo

# 1. Verificações de Hardware (Mockup)
header "Verificando ambiente..."
simulate_step "Verificando UEFI..." 0.5
gum style --foreground 40 " [OK] Ambiente UEFI detectado."

simulate_step "Verificando memória RAM..." 0.8
gum style --foreground 40 " [OK] 16GB de RAM disponível."

simulate_step "Verificando espaço em disco..." 0.6
gum style --foreground 40 " [OK] Espaço suficiente para instalação."

# 2. Seleção de Disco style "Proxmox" (Mockup)
header "Selecione o disco de destino"
echo "OBS: Todos os dados no disco selecionado serão APAGADOS."

# Lista de discos mockup
DISK_LIST="sda (256GB) - Samsung 980 Pro
sdb (1TB) - Western Digital Blue
sdc (2TB) - Seagate Barracuda
nvme0n1 (512GB) - Samsung 990 Pro"

# Nota: gum choose 0.14+ exige PONTO para cursor.foreground
TARGET_SELECTED=$(echo "$DISK_LIST" | gum choose --height 10 --cursor.foreground 212)
TARGET_DISK="/dev/$(echo "$TARGET_SELECTED" | awk '{print $1}')"

# 3. Informações do Usuário com Estética (Mockup)
logo
header "Configuração de Conta"

ADM_USER=$(gum input --placeholder "Nome do usuário (ex: admin)" --value "helton")

header "Defina a senha para $ADM_USER e Root"
while true; do
	ADM_PASS=$(gum input --password --placeholder "Senha")
	CONFIRM_PASS=$(gum input --password --placeholder "Confirme a senha")

	if [ "$ADM_PASS" = "$CONFIRM_PASS" ] && [ -n "$ADM_PASS" ]; then
		break
	fi
	gum style --foreground 196 "As senhas não conferem ou estão vazias. Tente novamente."
done

# 4. Confirmação Final com Tabela (Mockup)
logo
header "Resumo da Instalação"
echo ""
gum join --vertical \
	"$(gum style --width 20 "Disco:") $(gum style --foreground 212 "$TARGET_DISK")" \
	"$(gum style --width 20 "Usuário:") $(gum style --foreground 212 "$ADM_USER")" \
	"$(gum style --width 20 "Hostname:") $(gum style --foreground 212 "nas-zfs")" \
	"$(gum style --width 20 "Filesystem:") $(gum style --foreground 212 "ZFS on Root (ZBM)")" \
	"$(gum style --width 20 "Pool Name:") $(gum style --foreground 212 "$POOL_NAME")"

echo ""
gum confirm "Confirmar início da instalação? O disco será formatado." --default=false \
	--affirmative "PROSSEGUIR" --negative "CANCELAR" || exit 1

# 5. Execução Técnica com Spinners (Mockup)
logo

run_step() {
	local title="$1"
	local duration="${2:-1}"
	simulate_step "$title" "$duration"
}

run_step "Limpando disco $TARGET_DISK..." 1.5

run_step "Configurando EFI (512MB)..." 1

run_step "Criando Pool ZFS ($POOL_NAME)..." 2

run_step "Criando Datasets ZFS (ROOT/debian)..." 1.8

run_step "Montando hierarquia ZFS..." 1.2

# Instalação Base (Mockup)
header "Instalando sistema base..."
run_step "Extraindo arquivos para o ZFS (isto pode demorar)..." 3

# Configurações (Mockup)
header "Configurando instância..."
run_step "Configurando rede DHCP..." 0.8

run_step "Gerando fstab..." 0.6

# ZFSBootMenu (Mockup)
header "Configurando Bootloader (ZFSBootMenu)..."
run_step "Instalando ZFSBootMenu..." 1.5

# Chroot Finalization (Mockup)
header "Finalizando no Chroot..."
run_step "Atualizando initramfs..." 2

run_step "Criando usuário $ADM_USER..." 1

run_step "Configurar senhas..." 0.5

logo
gum style --foreground 40 --border-foreground 40 --border double --padding "1 2" \
	"INSTALAÇÃO CONCLUÍDA COM SUCESSO!" \
	"Usuário: $ADM_USER" \
	"Hostname: nas-zfs" \
	"Pool ZFS: $POOL_NAME" \
	"Dica: Remova a mídia Live e reinicie o sistema."

if gum confirm "Deseja reiniciar agora?"; then
	gum style --foreground 212 "Reiniciando em 3 segundos..."
	sleep 3
fi
