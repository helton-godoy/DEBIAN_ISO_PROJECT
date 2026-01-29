#!/bin/bash
# install-system-mockup-10
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS
# Desenvolvido com Antigravity Intelligence - 2026-01-28
#
# cline:kwaipilot/kat-code-pro

set -e

# --- Configurações do Pool ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Funções de UI Aurora ---

logo() {
	clear
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

# --- Início do Script ---

logo

# 1. Verificações de Hardware
header "Verificando ambiente..."
if [ ! -d /sys/firmware/efi ]; then
	error_box "O sistema não iniciou via UEFI. O Aurora requer UEFI."
	exit 1
fi
gum style --foreground 40 " [OK] Ambiente UEFI detectado."

# 2. Seleção de Disco style "Proxmox"
header "Selecione o disco de destino"
echo "OBS: Todos os dados no disco selecionado serão APAGADOS."

DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1" ("$2") - "$3}')

if [ -z "$DISK_LIST" ]; then
	error_box "Nenhum disco encontrado disponível para instalação."
	exit 1
fi

# Nota: gum choose 0.14+ exige PONTO para cursor.foreground
TARGET_SELECTED=$(echo "$DISK_LIST" | gum choose --height 10 --cursor.foreground 212)
TARGET_DISK="/dev/$(echo "$TARGET_SELECTED" | awk '{print $1}')"

# 3. Informações do Usuário com Estética
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

# 4. Confirmação Final com Tabela
logo
header "Resumo da Instalação"
echo ""
gum join --vertical \
	"$(gum style --width 20 "Disco:") $(gum style --foreground 212 "$TARGET_DISK")" \
	"$(gum style --width 20 "Usuário:") $(gum style --foreground 212 "$ADM_USER")" \
	"$(gum style --width 20 "Hostname:") $(gum style --foreground 212 "nas-zfs")" \
	"$(gum style --width 20 "Filesystem:") $(gum style --foreground 212 "ZFS on Root (ZBM)")"

echo ""
gum confirm "Confirmar início da instalação? O disco será formatado." --default=false \
	--affirmative "PROSSEGUIR" --negative "CANCELAR" || exit 1

# 5. Execução Técnica com Spinners
logo

# Função para executar comandos com spinner e verificar saída
run_step() {
	local title="$1"
	local cmd="$2"
	# Desativado para trabalhar apenas na estética
	# if ! gum spin --spinner dot --title "$title" -- bash -c "$cmd"; then
	# 	error_box "Falha ao executar: $title"
	# 	exit 1
	# fi
	echo "Simulação: $title"
}

# Simulação dos passos de instalação (sem execução real)
run_step "Limpando disco $TARGET_DISK..."
sleep 1

run_step "Configurando EFI (512MB)..."
sleep 1

run_step "Criando Pool ZFS ($POOL_NAME)..."
sleep 1

run_step "Criando Datasets ZFS (ROOT/debian)..."
sleep 1

run_step "Montando hierarquia ZFS..."
sleep 1

# Instalação Base (Clonagem)
header "Instalando sistema base..."
sleep 1

run_step "Extraindo arquivos para o ZFS (isto pode demorar)..."
sleep 2

# Configurações
header "Configurando instância..."
sleep 1

# Correção machine-id: Apaga para gerar de forma limpa no chroot
sleep 1

header "Configurando Bootloader (ZFSBootMenu)..."
sleep 1

# Chroot Finalization
header "Finalizando no Chroot..."
sleep 2

logo
gum style --foreground 40 --border-foreground 40 --border double --padding "1 2" \
	"INSTALAÇÃO CONCLUÍDA COM SUCESSO!" \
	"Usuário: $ADM_USER" \
	"Dica: Remova a mídia Live e reinicie o sistema."

if gum confirm "Deseja reiniciar agora?"; then
	reboot
fi
