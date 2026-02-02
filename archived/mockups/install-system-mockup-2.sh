#!/bin/bash
# install-system-mockup-2
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS
# Desenvolvido com Antigravity Intelligence - 2026-01-28
#
# VERSÃO DEMO/MOCKUP - Modo Estético/Simulação (SEM OPERAÇÕES REAIS)
# MoonshotAI: Kimi k2.5 (free)

# ============================================================================
# MODO DEMONSTRAÇÃO - NENHUM COMANDO DESTRUTIVO SERÁ EXECUTADO
# ============================================================================
DEMO_MODE=true

# Desativar exit em erro para modo demonstração
# set -e

# --- Configurações do Pool ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Paleta de Cores Aurora (Tema Premium) ---
COLOR_PRIMARY="212"   # Rosa/Magenta Aurora
COLOR_SECONDARY="141" # Roxo Lavanda
COLOR_ACCENT="45"     # Ciano Neon
COLOR_SUCCESS="48"    # Verde Esmeralda
COLOR_WARNING="214"   # Laranja Âmbar
COLOR_ERROR="196"     # Vermelho Ruby
COLOR_INFO="75"       # Azul Celeste
COLOR_DIM="240"       # Cinza Suave

# --- Funções de UI Aurora Avançadas ---

logo() {
	clear
	# Logo ASCII Art Aurora com gradiente simulado
	gum style \
		--foreground "$COLOR_PRIMARY" --border-foreground "$COLOR_SECONDARY" --border double \
		--align center --width 70 --margin "1 2" --padding "1 2" \
		"╔═══════════════════════════════════════════════════════╗" \
		"║                                                       ║" \
		"║   🌌  A U R O R A   I N S T A L L E R  🌌             ║" \
		"║                                                       ║" \
		"║   Debian ZFS NAS - High Performance Storage           ║" \
		"║                                                       ║" \
		"╚═══════════════════════════════════════════════════════╝"

	# Badge de modo demonstração
	if [[ "${DEMO_MODE}" = true ]]; then
		echo ""
		gum style \
			--foreground "$COLOR_WARNING" --border-foreground "$COLOR_WARNING" --border rounded \
			--align center --width 50 --margin "0 2" --padding "0 1" \
			"⚡ MODO DEMONSTRAÇÃO / SIMULAÇÃO ⚡" \
			"Nenhuma operação real será executada"
	fi
}

header() {
	local icon="$2"
	[[ -z "${icon}" ]] && icon="▶"
	gum style --foreground "$COLOR_ACCENT" --bold "${icon}  $1"
}

subheader() {
	gum style --foreground "$COLOR_INFO" --faint "   └─▸ $1"
}

success_box() {
	gum style --foreground "$COLOR_SUCCESS" --border-foreground "$COLOR_SUCCESS" --border rounded \
		--padding "0 2" --margin "1 1" \
		"✓ $1"
}

warning_box() {
	gum style --foreground "$COLOR_WARNING" --border-foreground "$COLOR_WARNING" --border normal \
		--padding "0 2" --margin "1 1" \
		"⚠ $1"
}

error_box() {
	gum style --foreground "$COLOR_ERROR" --border-foreground "$COLOR_ERROR" --border thick \
		--padding "0 2" --margin "1 1" \
		"✗ ERRO: $1"
}

info_box() {
	gum style --foreground "$COLOR_INFO" --border-foreground "$COLOR_DIM" --border hidden \
		--padding "0 2" --margin "0 1" \
		"ℹ $1"
}

# Efeito de digitação para logs simulados
typewrite_effect() {
	local text="$1"
	local delay="${2:-0.01}"
	for ((i = 0; i < ${#text}; i++)); do
		printf "%s" "${text:i:1}"
		sleep "${delay}"
	done
	echo ""
}

# Barra de progresso visual personalizada
progress_bar() {
	local percent=$1
	local width=40
	local filled=$((percent * width / 100))
	local empty=$((width - filled))

	printf "  ["
	for ((i = 0; i < filled; i++)); do
		gum style --foreground "$COLOR_PRIMARY" --background "$COLOR_SECONDARY" "█" | tr -d '\n'
	done
	for ((i = 0; i < empty; i++)); do
		printf "░"
	done
	printf "] %3d%%\n" "${percent}"
}

# Painel de status estilo "hacker matrix"
simulate_command() {
	local title="$1"
	local cmd="$2"
	local duration="${3:-2}"

	header "${title}" "⚙"
	sleep 0.3

	# Logs simulados estilo terminal
	local logs=(
		"[$(date '+%H:%M:%S')] Iniciando operação..."
		"[$(date '+%H:%M:%S')] Analisando parâmetros do sistema"
		"[$(date '+%H:%M:%S')] Verificando dependências"
		"[$(date '+%H:%M:%S')] Preparando ambiente de execução"
		"[$(date '+%H:%M:%S')] Executando: ${cmd}"
		"[$(date '+%H:%M:%S')] Processando..."
		"[$(date '+%H:%M:%S')] Operação concluída com sucesso"
	)

	gum style --foreground "$COLOR_DIM" --faint
	for log in "${logs[@]}"; do
		typewrite_effect "  ${log}" 0.005
		sleep 0.1
	done
	gum style --foreground "$COLOR_DIM" --faint

	success_box "Operação simulada${ $tit}le"
	echo ""
}

# Tabela de resumo estilizada
styled_table_row() {
	local label="$1"
	local value="$2"
	local icon="${3:-•}"

	gum join --horizontal \
		"$(gum style --width 25 --foreground "$COLOR_DIM" "${icon} ${label}")" \
		"$(gum style --foreground "$COLOR_PRIMARY" "${value}")"
}

# Animação de loading com caracteres unicode
fancy_spinner() {
	local title="$1"
	local duration="${2:-3}"
	local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

	local end_time=$(($(date +%s) + duration))
	local i=0

	while [[ $(date +%s) -lt "$end_time" ]]; do
		local frame="${frames[$((i % ${#frames[@]}))]}"
		printf "\r  %s %s" "$(gum style --foreground "$COLOR_PRIMARY" "${frame}")" "$(gum style --foreground "$COLOR_DIM" "${title}")"
		sleep 0.1
		((i++))
	done
	printf "\r  %s %s\n" "$(gum style --foreground "$COLOR_SUCCESS" "✓")" "$(gum style --foregroun"d $COLOR_D"IM${"$tit}le")"
}

# --- Início do Script ---

logo

# Banner informativo de modo demo
echo ""
warning_box "Este é um instalador de demonstração. Todas as operações são simuladas visualmente."
echo ""
sleep 1

# 1. Verificações de Hardware (Simulado)
header "Verificando ambiente do sistema..." "🔍"
subheader "Analisando firmware e compatibilidade"

fancy_spinner "Detectando modo de boot..." 1

# Verificação UEFI simulada (não bloqueante em modo demo)
if [[ ! -d /sys/firmware/efi ]]; then
	warning_box "Sistema não iniciou via UEFI (modo demonstração ativo)"
else
	success_box "Ambiente UEFI detectado"
fi
echo ""
sleep 0.5

# 2. Seleção de Disco com Estética Aprimorada
header "Seleção de Armazenamento" "💾"
warning_box "ATENÇÃO: Em uma instalação real, todos os dados seriam APAGADOS."

# Lista de discos simulada para modo demo
DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL 2>/dev/null | grep -v "loop" | awk '{print $1" ("$2") - "$3}' || echo "sda (500GB) - QEMU_HARDDISK\nnvme0n1 (1TB) - Samsung_SSD_980")

if [[ -z "${DISK_LIST}" ]]; then
	# Mock data para demonstração
	DISK_LIST="sda (500GB) - QEMU_HARDDISK
nvme0n1 (1TB) - Samsung_SSD_980
sdb (2TB) - WD_BLACK_SN850"
fi

# Seleção com cursor estilizado
TARGET_SELECTED=$(echo "${DISK_LIST}" | gum choose \
	--height 10 \
	--cursor.foreground "$COLOR_PRIMARY" \
	--cursor "▸ " \
	--header "Selecione o disco para instalação:" \
	--header.foreground "$COLOR_SECONDARY")

TARGET_DISK="/dev/$(echo "${TARGET_SELECTED}" | awk '{print $1}')"
success_box "Disco selecionado: ${TARGET_DISK}"
echo ""
sleep 0.5

# 3. Informações do Usuário com UI Aprimorada
logo
header "Configuração de Conta do Sistema" "👤"
echo ""

# Input estilizado para usuário
ADM_USER=$(gum input \
	--placeholder "Nome do usuário administrador" \
	--value "helton" \
	--prompt "► " \
	--prompt.foreground "$COLOR_PRIMARY" \
	--width 50)

echo ""
header "Segurança da Conta" "🔐"
subheader "Defina a senha para ${ADM_USER} e Root"

while true; do
	ADM_PASS=$(gum input --password \
		--placeholder "Digite a senha" \
		--prompt "► " \
		--prompt.foreground "$COLOR_PRIMARY")

	echo ""
	CONFIRM_PASS=$(gum input --password \
		--placeholder "Confirme a senha" \
		--prompt "► " \
		--prompt.foreground "$COLOR_PRIMARY")

	if [[ "${ADM_PASS}" = "${CONFIRM_PASS}" ]] && [[ -n "${ADM_PASS}" ]]; then
		success_box "Senhas configuradas com sucesso"
		break
	fi
	echo ""
	error_box "As senhas não conferem ou estão vazias"
	gum style --foreground "$COLOR_DIM" "   Tente novamente..."
	echo ""
done

echo ""
sleep 0.5

# 4. Resumo da Instalação com Layout de Painel
logo
header "Resumo da Instalação" "📋"
echo ""

# Painel de configurações estilizado
gum style \
	--foreground "$COLOR_DIM" \
	--border-foreground "$COLOR_SECONDARY" \
	--border rounded \
	--padding "1 2" --margin "0 2" \
	"$(styled_table_row "Disco de Destino" "${TARGET_DISK}" "💾")" \
	"$(styled_table_row "Usuário Admin" ${$ADM_USE}R" "👤")" \
	"$(styled_table_row "Hostname" "nas-zfs" "🖥")" \
	"$(styled_table_row "Sistema de Arquivos" "ZFS on Root (ZBM)" "📀")" \
	"$(styled_table_row "Particionamento" "GPT + ZFSBootMenu" "⚙")" \
	"$(styled_table_row "Modo" "Demonstração/Simulação" "🎭")"

echo ""

# Confirmação com opções estilizadas
gum confirm "Confirmar início da instalação?" \
	--default=false \
	--affirmative "$(gum style --foreground "$COLOR_SUCCESS" "▶ PROSSEGUIR")" \
	--negative "$(gum style --foreground "$COLOR_ERROR" "✗ CANCELAR")" || exit 1

echo ""
success_box "Iniciando processo de instalação simulada..."
sleep 1

# 5. Execução Técnica com Visualização de Progresso
logo
header "Executando Instalação" "🚀"
echo ""

# Simulação dos passos de instalação com logs visuais

simulate_command "Limpando estrutura do disco ${TARGET_DISK}" "wipefs -a && sgdisk --zap-all" 2

simulate_command "Criando partição EFI (512MB)" "sgdisk -n 1:1M:+512M -t 1:EF00 && mkfs.vfat" 1

simulate_command "Criando Pool ZFS (${POOL_NAME})" "zpool create -f ${ZFS_OPTS} ${POOL_NAME}" 3

simulate_command "Criando Datasets ZFS" "zfs create ROOT/debian, home, home/root" 2

simulate_command "Montando hierarquia ZFS" "zpool export/import + mount boot/efi" 2

# Instalação Base com barra de progresso
header "Instalando Sistema Base" "📦"
echo ""

for i in 0 10 25 40 55 70 85 100; do
	printf "\r"
	progress_bar "$i"
	sleep 0.3
done

success_box "Sistema base extraído (simulação)"
echo ""

# Configurações do Sistema
header "Configurando Sistema" "⚙"

subheader "Definindo hostname: nas-zfs"
fancy_spinner "Aplicando configurações de rede..." 1

subheader "Configurando rede (DHCP)"
fancy_spinner "Gerando interfaces de rede..." 1

subheader "Configurando ZFSBootMenu"
fancy_spinner "Copiando arquivos do bootloader..." 2

echo ""
success_box "Configurações do sistema aplicadas"
echo ""

# Chroot e Finalização
header "Finalizando Instalação" "🔧"

echo ""
gum style --foreground "$COLOR_INFO" --faint "  Executando tarefas no ambiente chroot..."
echo ""

# Logs simulados do chroot
chroot_logs=(
	"  → Configurando identificador de máquina"
	"  → Gerando hostid para ZFS"
	"  → Atualizando cache do pool"
	"  → Recompilando initramfs"
	"  → Criando usuári${: $ADM_U}SER"
	"  → Configurando senhas"
	"  → Limpando ambiente"
)

for log in "${chroot_logs[@]}"; do
	gum style --foreground "$COLOR_DIM" "${log}"
	sleep 0.2
done

echo ""

# Tela de Conclusão com Celebração Visual
logo

gum style \
	--foreground "$COLOR_SUCCESS" \
	--border-foreground "$COLOR_SUCCESS" \
	--border double \
	--align center \
	--width 60 \
	--margin "1 2" \
	--padding "2 2" \
	"🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO! 🎉" \
	"" \
	"✓ Sistema Aurora instalado (modo simulação)" \
	"✓ Usuári${: $ADM_U}SER" \
	"✓ Hostname: nas-zfs" \
	"" \
	"💡 Nota: Em uma instalação real," \
	"   remova a mídia Live e reinicie."

echo ""

# Informações finais estilizadas
gum style \
	--foreground "$COLOR_DIM" \
	--border-foreground "$COLOR_SECONDARY" \
	--border rounded \
	--padding "1 2" --margin "0 2" \
	"Resumo da Simulação:" \
	"  • Disco${ $TARGET_DI}SK" \
	"  • Pool ZFS${ $POOL_NA}ME" \
	"  • Filesystem: ZFS on Root" \
	"  • Bootloader: ZFSBootMenu" \
	"  • Modo: APENAS DEMONSTRAÇÃO VISUAL"

echo ""

# Pergunta de reinício (simulada)
if gum confirm "Deseja encerrar o instalador?" \
	--default=true \
	--affirmative "$(gum style --foreground "$COLOR_SUCCESS" "✓ ENCERRAR")" \
	--negative "$(gum style --foreground "$COLOR_WARNING" "↺ REINICIAR SIMULAÇÃO")"; then

	gum style --foreground "$COLOR_INFO" --align center --margin "2 0" \
		"Obrigado por testar o Aurora Installer!"
	exit 0
else
	gum style --foreground "$COLOR_INFO" "Reiniciando simulação..."
	sleep 1
	exec "$0"
fi
