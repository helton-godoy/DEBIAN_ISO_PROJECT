#!/bin/bash
# install-system-mockup-11
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS
# Desenvolvido com Antigravity Intelligence - 2026-01-28
# MODO MOCKUP: Todas as funções reais DESATIVADAS para desenvolvimento estético

set -e

# --- Configurações do Pool ---

POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Funções de UI Aurora Aprimorada ---

# Paleta de cores Aurora

AURORA_PRIMARY=212
AURORA_SUCCESS=40
AURORA_INFO=220
AURORA_WARNING=208
AURORA_ERROR=196
AURORA_ACCENT=123

# Função para criar separadores visuais

separator() {
	gum style --foreground "$AURORA_ACCENT" --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Função para criar ícones

icon() {
	case $1 in
	"logo") echo "🌅" ;;
	"disk") echo "💾" ;;
	"settings") echo "⚙️" ;;
	"user") echo "👤" ;;
	"check") echo "✅" ;;
	"info") echo "ℹ️" ;;
	"warning") echo "⚠️" ;;
	"error") echo "❌" ;;
	"progress") echo "🔄" ;;
	"boot") echo "🚀" ;;
	*) echo "•" ;;
	esac
}

# Barra de progresso geral

progress_bar() {
	local current=$1
	local total=$2
	local width=30
	local filled=$((current * width / total))
	local empty=$((width - filled))

	local bar=""
	for ((i = 0; i < filled; i++)); do bar+="█"; done
	for ((i = 0; i < empty; i++)); do bar+="░"; done

	gum style --foreground "$AURORA_PRIMARY" "[${bar}] ${current}/${total}"
}

logo() {
	clear
	# Logo Aurora melhorado com gradiente visual
	separator
	gum style \
		--foreground "$AURORA_PRIMARY" --border-foreground "$AURORA_PRIMARY" --border double \
		--align center --width 70 --margin "1 2" --padding "1 2" \
		"$(icon logo) AURORA INSTALLER $(icon logo)" \
		"Debian ZFS NAS - High Performance Storage" \
		"" \
		"$(icon progress) Instalador Premium com Interface Avançada"
	separator
}

header() {
	echo ""
	gum style --foreground "$AURORA_ACCENT" --bold "$(icon settings) ── $1"
	separator
}

error_box() {
	echo ""
	separator
	gum style --foreground "$AURORA_ERROR" --border-foreground "$AURORA_ERROR" --border thick \
		--padding "1 2" --margin "0 1" --align center "$(icon error) ERRO: $1"
	separator
}

# --- Início do Script ---

logo

# 1. Verificações de Hardware

header "Verificando ambiente..."
gum style --foreground "$AURORA_INFO" "$(icon info) Analisando configuração do sistema..."
if [[ ! -d /sys/firmware/efi ]]; then
	error_box "O sistema não iniciou via UEFI. O Aurora requer UEFI."
	exit 1
fi
gum style --foreground "$AURORA_SUCCESS" "$(icon check) Ambiente UEFI detectado com sucesso."

# 2. Seleção de Disco style Proxmox Melhorado

header "Seleção de Disco de Destino"
echo ""
gum style --foreground "$AURORA_WARNING" --align center "$(icon warning) ATENÇÃO: Todos os dados no disco selecionado serão APAGADOS."
echo ""
separator

DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1" ("$2") - "$3}')

if [[ -z "${DISK_LIST}" ]]; then
	error_box "Nenhum disco encontrado disponível para instalação."
	exit 1
fi

gum style --foreground "$AURORA_INFO" "$(icon disk) Discos disponíveis:"
TARGET_SELECTED=$(echo "${DISK_LIST}" | gum choose --height 10 --cursor.foreground="${AURORA_PRIMARY}")
TARGET_DISK="/dev/$(echo "${TARGET_SELECTED}" | awk '{print $1}')"

gum style --foreground "$AURORA_SUCCESS" "$(icon check) Disco selecionado: ${TARGET_DISK}"

# 3. Informações do Usuário com Estética Aprimorada

logo
header "Configuração de Conta de Usuário"
separator

gum style --foreground "$AURORA_INFO" "$(icon user) Configurando credenciais de acesso..."
echo ""

ADM_USER=$(gum input --placeholder "Nome do usuário (ex: admin)" --value "helton")

header "Definição de Senha Segura"
echo ""
gum style --foreground "$AURORA_INFO" "$(icon info) A senha será usada para o usuário e root."
echo ""

while true; do
	ADM_PASS=$(gum input --password --placeholder "Digite uma senha forte")
	CONFIRM_PASS=$(gum input --password --placeholder "Confirme a senha")

	if [[ "${ADM_PASS}" = "${CONFIRM_PASS}" ]] && [[ -n "${ADM_PASS}" ]]; then
		gum style --foreground "$AURORA_SUCCESS" "$(icon check) Senha configurada com sucesso!"
		break
	fi
	gum style --foreground "$AURORA_ERROR" "$(icon error) As senhas não conferem ou estão vazias. Tente novamente."
done
separator

# 4. Confirmação Final com Cards Melhorados

logo
header "Resumo da Instalação"
separator
gum style --foreground "$AURORA_INFO" "$(icon info) Revise as configurações antes de prosseguir:"
echo ""

# Cards de informação

gum join --vertical \
	"$(gum style --foreground "$AURORA_ACCENT" --bold "$(icon disk) Disco de Destino:") $(gum style --foreground "$AURORA_PRIMARY" "${TARGET_DISK}")" \
	"$(gum style --foreground "$AURORA_ACCENT" --bold "$(icon user) Usuário Admin:") $(gum style --foreground" $AURORA_PRIMAR"Y ${$ADM_USE}R")" \
	"$(gum style --foreground "$AURORA_ACCENT" --bold "$(icon settings) Hostname:") $(gum style --foreground "$AURORA_PRIMARY" "nas-zfs")" \
	"$(gum style --foreground "$AURORA_ACCENT" --bold "$(icon boot) Sistema de Arquivos:") $(gum style --foreground "$AURORA_PRIMARY" "ZFS on Root (ZBM)")"

echo ""
separator
gum style --foreground "$AURORA_WARNING" --align center "$(icon warning) ESTA OPERAÇÃO IRÁ APAGAR TODOS OS DADOS DO DISCO!"
echo ""
gum confirm "Confirmar início da instalação?" --default=false \
	--affirmative "🚀 PROSSEGUIR" --negative "❌ CANCELAR" || exit 1

# 5. Execução Técnica com Spinners e Progresso

logo
header "Iniciando Processo de Instalação"
separator

# Variável de controle de progresso

STEP_CURRENT=0
STEP_TOTAL=8

# Função para exibir progresso geral

show_progress() {
	echo ""
	gum style --foreground "$AURORA_ACCENT" --bold "Progresso Geral:"
	progress_bar "$STEP_CURRENT" "$STEP_TOTAL"
	echo ""
}

# Função para simular comandos com spinner e timer

run_step() {
	local title="$1"
	local duration=${2:-3}

	((STEP_CURRENT++))
	show_progress

	gum style --foreground "$AURORA_INFO" "$(icon progress) ${title}"
	gum spin --spinner minidot --title "Processando..." -- sleep "$duration"
	gum style --foreground "$AURORA_SUCCESS" "$(icon check) ${title} - Concluído"
	separator
}

run_step 'Limpando disco $TARGET_DISK...' 2

run_step 'Configurando partição EFI (512MB)...' 3

run_step 'Criando Pool ZFS ($POOL_NAME)...' 4

run_step 'Configurando Datasets ZFS...' 3

run_step 'Montando sistema de arquivos...' 2

# Instalação Base (Simulação)

header "Instalando Sistema Base"
gum style --foreground "$AURORA_INFO" "$(icon info) Simulando extração do sistema base..."
run_step 'Extraindo arquivos para o ZFS...' 5

# Configurações (Simulação)

header "Configurando Instância"
gum style --foreground "$AURORA_INFO" "$(icon settings) Configurando hostname, rede e fstab..."
sleep 2
gum style --foreground "$AURORA_SUCCESS" "$(icon check) Configurações do sistema aplicadas"
separator

# ZFSBootMenu (Simulação)

header "Configurando Bootloader"
gum style --foreground "$AURORA_INFO" "$(icon boot) Baixando e configurando ZFSBootMenu..."
run_step 'Instalando bootloader EFI...' 3
gum style --foreground "$AURORA_SUCCESS" "$(icon check) Bootloader configurado com sucesso"
separator

# Chroot Finalization (Simulação)

header "Finalizando Configurações"
gum style --foreground "$AURORA_INFO" "$(icon user) Configurando usuário e sistema final..."
run_step 'Aplicando configurações finais...' 4
gum style --foreground "$AURORA_SUCCESS" "$(icon check) Sistema finalizado com sucesso"
separator

# Tela de Sucesso Aprimorada

logo
separator
gum style --foreground "$AURORA_SUCCESS" --border-foreground "$AURORA_SUCCESS" --border double --padding "2 3" --align center \
	"$(icon check) INSTALAÇÃO CONCLUÍDA COM SUCESSO!" \
	"" \
	"$(icon user) Usuário:${$ADM_USE}R" \
	"$(icon info) Dica: Remova a mídia Live e reinicie o sistema."
separator

# Progresso final

show_progress
gum style --foreground "$AURORA_SUCCESS" --bold "$(icon check) Todas as etapas concluídas com êxito!"
echo ""

if gum confirm "Deseja reiniciar agora?" --affirmative "🚀 REINICIAR" --negative "❌ SAIR"; then
	gum style --foreground "$AURORA_INFO" "$(icon info) Simulação concluída. Reinício simulado."
	sleep 3
	clear
	logo
	separator
	gum style --foreground "$AURORA_INFO" --border-foreground "$AURORA_INFO" --border double --padding "2 3" --align center \
		"$(icon info) MODO DEMONSTRAÇÃO" \
		"" \
		"Este é um instalador simulado para fins estéticos." \
		"Nenhuma modificação real foi realizada no sistema." \
		"" \
		"$(icon logo) Obrigado por testar o Aurora Installer!"
	separator
fi
