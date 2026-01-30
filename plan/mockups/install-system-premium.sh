#!/bin/bash
# install-system-premium
# Instalador Gráfico Premium para Debian ZFS NAS
# Design Monocromático Sofisticado com Hierarquia Tipográfica
# Refinamento feito sobre a versão 'install-system-mockup-11.sh'
# Desenvolvido com Antigravity Intelligence - 2026-01-29
# Baseado em princípios de UX Psychology e Frontend Design

set -e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SISTEMA DE CORES MONOCROMÁTICO (Tom sobre Tom)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Paleta Grayscale Sofisticada (ANSI 256)
BG_BASE=232      # Preto profundo
BG_PRIMARY=233   # Fundo primário
BG_SECONDARY=234 # Fundo secundário
BG_TERTIARY=235  # Fundo terciário

TEXT_PRIMARY=231    # Branco puro (100% opacidade)
TEXT_SECONDARY=252  # Cinza claro (88% opacidade)
TEXT_TERTIARY=244   # Cinza médio (69% opacidade)
TEXT_QUATERNARY=240 # Cinza escuro (50% opacidade)

ACCENT=231        # Branco puro para destaques
BORDER_SUBTLE=236 # Bordas sutis
BORDER_MEDIUM=238 # Bordas médias
BORDER_STRONG=241 # Bordas destacadas

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURAÇÕES DO POOL ZFS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNÇÕES DE COMPONENTES VISUAIS PREMIUM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Separador visual refinado
separator() {
	local style="${1:-medium}"
	case $style in
	"light")
		gum style --foreground $BORDER_SUBTLE "─────────────────────────────────────────────────────────────────"
		;;
	"medium")
		gum style --foreground $BORDER_MEDIUM "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		;;
	"strong")
		gum style --foreground $BORDER_STRONG "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		;;
	esac
}

# Espaçamento harmonioso (8-Point Grid)
spacing() {
	local size="${1:-medium}"
	case $size in
	"micro") printf '\n' ;;
	"small") printf '\n\n' ;;
	"medium") printf '\n\n\n' ;;
	"large") printf '\n\n\n\n' ;;
	"xlarge") printf '\n\n\n\n\n' ;;
	"xxlarge") printf '\n\n\n\n\n\n' ;;
	esac
}

# Logo com hierarquia tipográfica refinada (Display Level)
logo() {
	clear
	spacing "medium"
	separator "strong"
	spacing "micro"

	# Display: Título principal (2.618x base)
	gum style \
		--foreground $TEXT_PRIMARY \
		--border-foreground $BORDER_MEDIUM \
		--border double \
		--align center \
		--width 68 \
		--margin "0 2" \
		--padding "2 4" \
		--bold \
		"D E B I A N   Z F S" \
		"" \
		"P R E M I U M   I N S T A L L E R"

	spacing "micro"

	# H3: Subtítulo
	gum style \
		--foreground $TEXT_TERTIARY \
		--align center \
		--width 68 \
		--margin "0 2" \
		"High-Performance Storage System"

	spacing "micro"
	separator "strong"
	spacing "medium"
}

# Header de seção (H1 Level)
header() {
	spacing "small"
	gum style \
		--foreground $TEXT_PRIMARY \
		--bold \
		"▌ $1"
	spacing "micro"
	separator "light"
	spacing "micro"
}

# Subheader (H2 Level)
subheader() {
	spacing "micro"
	gum style \
		--foreground $TEXT_SECONDARY \
		--bold \
		"  $1"
	spacing "micro"
}

# Card de informação premium
info_card() {
	local title="$1"
	local content="$2"

	spacing "micro"
	gum style \
		--foreground $TEXT_TERTIARY \
		--border-foreground $BORDER_SUBTLE \
		--border rounded \
		--padding "1 2" \
		--margin "0 2" \
		--width 64 \
		"$(gum style --foreground $TEXT_SECONDARY --bold "$title")" \
		"" \
		"$(gum style --foreground $TEXT_PRIMARY "$content")"
	spacing "micro"
}

# Mensagem de aviso sofisticada
warning_box() {
	spacing "small"
	separator "medium"
	spacing "micro"
	gum style \
		--foreground $TEXT_PRIMARY \
		--border-foreground $BORDER_STRONG \
		--border thick \
		--padding "1 3" \
		--margin "0 4" \
		--align center \
		--width 60 \
		"⚠  A T E N Ç Ã O" \
		"" \
		"$1"
	spacing "micro"
	separator "medium"
	spacing "small"
}

# Mensagem de erro elegante
error_box() {
	spacing "small"
	separator "strong"
	spacing "micro"
	gum style \
		--foreground $TEXT_PRIMARY \
		--border-foreground $BORDER_STRONG \
		--border thick \
		--padding "2 4" \
		--margin "0 4" \
		--align center \
		--width 60 \
		"✗  E R R O" \
		"" \
		"$1"
	spacing "micro"
	separator "strong"
	spacing "small"
}

# Mensagem de sucesso refinada
success_box() {
	spacing "small"
	separator "medium"
	spacing "micro"
	gum style \
		--foreground $TEXT_PRIMARY \
		--border-foreground $BORDER_MEDIUM \
		--border double \
		--padding "2 4" \
		--margin "0 4" \
		--align center \
		--width 60 \
		"✓  S U C E S S O" \
		"" \
		"$1"
	spacing "micro"
	separator "medium"
	spacing "small"
}

# Barra de progresso sofisticada
progress_bar() {
	local current=$1
	local total=$2
	local width=50
	local filled=$((current * width / total))
	local empty=$((width - filled))
	local percentage=$((current * 100 / total))

	local bar=""
	for ((i = 0; i < filled; i++)); do bar+="━"; done
	for ((i = 0; i < empty; i++)); do bar+="─"; done

	spacing "micro"
	gum style --foreground $TEXT_TERTIARY "PROGRESSO GERAL"
	spacing "micro"
	gum style --foreground $TEXT_PRIMARY "$bar  $percentage%"
	spacing "micro"
	gum style --foreground $TEXT_QUATERNARY "Etapa $current de $total"
	spacing "micro"
}

# Lista de seleção refinada
select_item() {
	local prompt="$1"
	shift
	local items=("$@")

	subheader "$prompt"
	spacing "micro"

	echo "${items[@]}" | tr ' ' '\n' | gum choose \
		--height 10 \
		--cursor.foreground="$TEXT_PRIMARY" \
		--item.foreground="$TEXT_SECONDARY" \
		--selected.foreground="$TEXT_PRIMARY"
}

# Input refinado
input_field() {
	local prompt="$1"
	local placeholder="$2"
	local default="${3:-}"

	gum style --foreground $TEXT_SECONDARY "$prompt"
	spacing "micro"
	gum input \
		--placeholder "$placeholder" \
		--value "$default" \
		--prompt.foreground="$TEXT_TERTIARY" \
		--cursor.foreground="$TEXT_PRIMARY"
}

# Input de senha refinado
password_field() {
	local prompt="$1"
	local placeholder="$2"

	gum style --foreground $TEXT_SECONDARY "$prompt"
	spacing "micro"
	gum input \
		--password \
		--placeholder "$placeholder" \
		--prompt.foreground="$TEXT_TERTIARY" \
		--cursor.foreground="$TEXT_PRIMARY"
}

# Confirmação refinada
confirm_action() {
	local message="$1"
	local affirmative="${2:-PROSSEGUIR}"
	local negative="${3:-CANCELAR}"

	spacing "small"
	gum style --foreground $TEXT_SECONDARY --align center "$message"
	spacing "micro"

	gum confirm \
		--default=false \
		--affirmative "▸ $affirmative" \
		--negative "✗ $negative" \
		--prompt.foreground="$TEXT_PRIMARY" \
		--selected.foreground="$TEXT_PRIMARY" \
		--unselected.foreground="$TEXT_QUATERNARY"
}

# Spinner minimalista
run_step() {
	local title="$1"
	local duration=${2:-3}

	((STEP_CURRENT++))
	progress_bar $STEP_CURRENT $STEP_TOTAL
	spacing "micro"

	gum style --foreground $TEXT_SECONDARY "▸ $title"
	gum spin \
		--spinner dot \
		--title "Processando..." \
		--title.foreground="$TEXT_QUATERNARY" \
		--spinner.foreground="$TEXT_TERTIARY" \
		-- sleep $duration

	gum style --foreground $TEXT_PRIMARY "✓ $title"
	spacing "micro"
	separator "light"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INÍCIO DO INSTALADOR
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

logo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. VERIFICAÇÕES DE AMBIENTE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

header "Verificação de Ambiente"

gum style --foreground $TEXT_SECONDARY "Analisando configuração do sistema..."
spacing "micro"

if [ ! -d /sys/firmware/efi ]; then
	error_box "O sistema não iniciou via UEFI.\nEste instalador requer boot UEFI."
	exit 1
fi

gum style --foreground $TEXT_PRIMARY "✓ Ambiente UEFI detectado com sucesso"
spacing "small"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. SELEÇÃO DE DISCO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

logo
header "Seleção de Disco de Destino"

warning_box "Todos os dados no disco selecionado serão APAGADOS.\nEsta operação é IRREVERSÍVEL."

DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1" ("$2") - "$3}')

if [ -z "$DISK_LIST" ]; then
	error_box "Nenhum disco disponível encontrado para instalação."
	exit 1
fi

subheader "Discos disponíveis:"
spacing "micro"

TARGET_SELECTED=$(echo "$DISK_LIST" | gum choose \
	--height 10 \
	--cursor.foreground="$TEXT_PRIMARY" \
	--item.foreground="$TEXT_SECONDARY" \
	--selected.foreground="$TEXT_PRIMARY")

TARGET_DISK="/dev/$(echo "$TARGET_SELECTED" | awk '{print $1}')"

spacing "small"
info_card "Disco selecionado" "$TARGET_DISK"
spacing "small"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. CONFIGURAÇÃO DE USUÁRIO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

logo
header "Configuração de Conta de Usuário"

subheader "Nome do usuário administrador"
ADM_USER=$(input_field "" "Nome do usuário (ex: admin)" "helton")

spacing "small"
subheader "Definição de senha segura"
spacing "micro"
gum style --foreground $TEXT_QUATERNARY "A senha será usada para o usuário e root"

spacing "small"

while true; do
	ADM_PASS=$(password_field "" "Digite uma senha forte")
	CONFIRM_PASS=$(password_field "" "Confirme a senha")

	if [ "$ADM_PASS" = "$CONFIRM_PASS" ] && [ -n "$ADM_PASS" ]; then
		spacing "micro"
		gum style --foreground $TEXT_PRIMARY "✓ Senha configurada com sucesso"
		break
	fi

	spacing "micro"
	gum style --foreground $TEXT_PRIMARY "✗ As senhas não conferem ou estão vazias. Tente novamente."
	spacing "small"
done

spacing "small"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. RESUMO E CONFIRMAÇÃO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

logo
header "Resumo da Instalação"

subheader "Revise as configurações antes de prosseguir"
spacing "small"

info_card "Disco de Destino" "$TARGET_DISK"
info_card "Usuário Administrador" "$ADM_USER"
info_card "Hostname" "nas-zfs"
info_card "Sistema de Arquivos" "ZFS on Root (ZBM)"

spacing "small"
warning_box "ESTA OPERAÇÃO IRÁ APAGAR TODOS OS DADOS DO DISCO!"

if ! confirm_action "Confirmar início da instalação?" "PROSSEGUIR" "CANCELAR"; then
	exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. PROCESSO DE INSTALAÇÃO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

logo
header "Processo de Instalação"

STEP_CURRENT=0
STEP_TOTAL=8

run_step "Limpando disco $TARGET_DISK" 2
run_step "Configurando partição EFI (512MB)" 3
run_step "Criando Pool ZFS ($POOL_NAME)" 4
run_step "Configurando Datasets ZFS" 3
run_step "Montando sistema de arquivos" 2

spacing "small"
header "Instalando Sistema Base"
gum style --foreground $TEXT_SECONDARY "Extraindo arquivos para o ZFS..."
run_step "Instalação do sistema base" 5

spacing "small"
header "Configurando Sistema"
gum style --foreground $TEXT_SECONDARY "Aplicando configurações de hostname, rede e fstab..."
sleep 2
gum style --foreground $TEXT_PRIMARY "✓ Configurações aplicadas com sucesso"
spacing "micro"
separator "light"

spacing "small"
header "Configurando Bootloader"
gum style --foreground $TEXT_SECONDARY "Baixando e configurando ZFSBootMenu..."
run_step "Instalação do bootloader EFI" 3

spacing "small"
header "Finalizando Instalação"
gum style --foreground $TEXT_SECONDARY "Aplicando configurações finais do sistema..."
run_step "Configurações finais" 4

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. CONCLUSÃO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

logo
success_box "INSTALAÇÃO CONCLUÍDA COM SUCESSO!\n\nUsuário: $ADM_USER\n\nRemova a mídia Live e reinicie o sistema."

progress_bar $STEP_TOTAL $STEP_TOTAL
spacing "small"

if confirm_action "Deseja reiniciar agora?" "REINICIAR" "SAIR"; then
	gum style --foreground $TEXT_SECONDARY "Simulação concluída. Reinício simulado."
	sleep 3
	clear
	logo
	spacing "small"

	gum style \
		--foreground $TEXT_SECONDARY \
		--border-foreground $BORDER_MEDIUM \
		--border double \
		--padding "2 4" \
		--margin "0 4" \
		--align center \
		--width 60 \
		"M O D O   D E M O N S T R A Ç Ã O" \
		"" \
		"Este é um instalador simulado para fins estéticos." \
		"Nenhuma modificação real foi realizada no sistema." \
		"" \
		"Obrigado por testar o Debian ZFS Premium Installer!"

	spacing "medium"
fi
