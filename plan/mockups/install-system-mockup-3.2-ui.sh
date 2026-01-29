#!/bin/bash
# Aurora UI System - Sistema de Interface Monocromática Sofisticada
# Desenvolvido para Debian ZFS NAS Installer
# Versão: 1.0.0
# Data: 2026-01-29

# ============================================
# CONFIGURAÇÕES DE CORES MONOCROMÁTICAS
# ============================================

# Paleta de Cores (256-color terminal)
readonly PRIMARY=236        # #303030 - Fundo principal
readonly SECONDARY=240      # #585858 - Fundo secundário
readonly ACCENT=244         # #808080 - Acentos sutis
readonly HIGHLIGHT=248      # #a8a8a8 - Destaques
readonly TEXT_PRIMARY=252   # #d0d0d0 - Texto principal
readonly TEXT_SECONDARY=246 # #949494 - Texto secundário
readonly TEXT_MUTED=244     # #808080 - Texto sutil
readonly SUCCESS=242        # #585858 - Sucesso
readonly WARNING=242        # #585858 - Aviso
readonly ERROR=242          # #585858 - Erro
readonly BORDER=240         # #585858 - Bordas
readonly SHADOW=234         # #1c1c1c - Sombras

# ============================================
# SISTEMA DE CORES DINÂMICO
# ============================================

# Função para obter cor com opacidade simulada
get_color() {
	local base_color=$1
	local opacity=$2 # 0-100

	# Simula opacidade alternando entre cores mais claras/escuras
	if [ $opacity -lt 30 ]; then
		echo $((base_color - 4))
	elif [ $opacity -lt 60 ]; then
		echo $base_color
	else
		echo $((base_color + 4))
	fi
}

# Função para gradiente monocromático
create_gradient() {
	local text=$1
	local start_color=$2
	local end_color=$3
	local length=${#text}
	local step=$(((end_color - start_color) / length))

	local result=""
	for ((i = 0; i < length; i++)); do
		local color=$((start_color + (i * step)))
		result+="\033[38;5;${color}m${text:$i:1}"
	done
	echo -e "${result}\033[0m"
}

# ============================================
# SISTEMA DE TIPOGRAFIA
# ============================================

# Função para renderizar texto com hierarquia
render_text() {
	local text=$1
	local level=$2 # h1, h2, h3, body, caption
	local color=${3:-$TEXT_PRIMARY}

	case $level in
	h1)
		echo -e "\033[1;38;5;${color}m${text}\033[0m"
		;;
	h2)
		echo -e "\033[1;38;5;${color}m${text}\033[0m"
		;;
	h3)
		echo -e "\033[38;5;${color}m${text}\033[0m"
		;;
	body)
		echo -e "\033[38;5;${color}m${text}\033[0m"
		;;
	caption)
		echo -e "\033[2;38;5;${color}m${text}\033[0m"
		;;
	esac
}

# Função para espaçamento vertical
vspace() {
	local lines=${1:-1}
	for ((i = 0; i < lines; i++)); do
		echo ""
	done
}

# Função para centralizar texto
center_text() {
	local text=$1
	local width=${2:-80}
	local text_length=${#text}
	local padding=$(((width - text_length) / 2))
	printf "%${padding}s%s" "" "$text"
}

# ============================================
# SISTEMA DE LAYOUT
# ============================================

# Função para criar container com bordas
create_box() {
	local content=$1
	local width=${2:-60}
	local border_color=${3:-$BORDER}
	local bg_color=${4:-$PRIMARY}

	# Linha superior
	echo -e "\033[48;5;${bg_color}m\033[38;5;${border_color}m┌$(printf '─%.0s' $(seq 1 $((width - 2))))┐\033[0m"

	# Conteúdo
	while IFS= read -r line; do
		local padding=$((width - ${#line} - 2))
		echo -e "\033[48;5;${bg_color}m\033[38;5;${border_color}m│\033[38;5;${TEXT_PRIMARY}m ${line}$(printf ' %.0s' $(seq 1 $padding))\033[38;5;${border_color}m│\033[0m"
	done <<<"$content"

	# Linha inferior
	echo -e "\033[48;5;${bg_color}m\033[38;5;${border_color}m└$(printf '─%.0s' $(seq 1 $((width - 2))))┘\033[0m"
}

# Função para grid layout
create_grid() {
	local items=("$@")
	local columns=${1:-3}
	local column_width=${2:-30}
	shift 2

	for ((i = 0; i < ${#items[@]}; i += columns)); do
		local row=""
		for ((j = 0; j < columns && i + j < ${#items[@]}; j++)); do
			row+="${items[$i + j]}$(printf ' %.0s' $(seq 1 $((column_width - ${#items[$i + j]}))))"
		done
		echo "$row"
	done
}

# ============================================
# SISTEMA DE ANIMAÇÕES
# ============================================

# Animação de loading elegante
animate_loading() {
	local text=$1
	local duration=${2:-2}
	local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
	local i=0
	local end_time=$((SECONDS + duration))

	while [ $SECONDS -lt $end_time ]; do
		printf "\r\033[38;5;${HIGHLIGHT}m%s\033[0m \033[38;5;${TEXT_SECONDARY}m%s\033[0m" "${chars:$i:1}" "$text"
		i=$(((i + 1) % ${#chars}))
		sleep 0.1
	done
	printf "\r\033[38;5;${SUCCESS}m✓\033[0m \033[38;5;${TEXT_PRIMARY}m%s\033[0m\n" "$text"
}

# Animação de progresso suave
animate_progress() {
	local current=$1
	local total=$2
	local label=$3
	local percentage=$((current * 100 / total))
	local filled=$((percentage / 2))
	local empty=$((50 - filled))

	# Barra de progresso com gradiente
	printf "\r\033[38;5;${TEXT_SECONDARY}m%s:\033[0m [" "$label"

	# Parte preenchida com gradiente
	for ((i = 0; i < filled; i++)); do
		local color=$((244 + (i * 2 / filled)))
		printf "\033[38;5;${color}m█\033[0m"
	done

	# Parte vazia
	printf "\033[38;5;${SECONDARY}m%*s\033[0m" $empty | tr ' ' '░'
	printf "] \033[38;5;${HIGHLIGHT}m%d%%\033[0m" $percentage
}

# ============================================
# SISTEMA DE COMPONENTES
# ============================================

# Card com sombra
create_card() {
	local title=$1
	local content=$2
	local width=${3:-60}

	# Sombra
	echo -e "\033[38;5;${SHADOW}m$(printf ' %.0s' $(seq 1 $((width + 2))))\033[0m"

	# Título
	echo -e "\033[38;5;${HIGHLIGHT}m${title}\033[0m"
	vspace 1

	# Card
	create_box "$content" $width $BORDER $PRIMARY
}

# Badge elegante
create_badge() {
	local text=$1
	local type=${2:-info} # info, success, warning, error

	local bg_color
	local fg_color

	case $type in
	info)
		bg_color=$SECONDARY
		fg_color=$TEXT_PRIMARY
		;;
	success)
		bg_color=$ACCENT
		fg_color=$PRIMARY
		;;
	warning)
		bg_color=$ACCENT
		fg_color=$PRIMARY
		;;
	error)
		bg_color=$ACCENT
		fg_color=$PRIMARY
		;;
	esac

	echo -e "\033[48;5;${bg_color}m\033[38;5;${fg_color}m ${text} \033[0m"
}

# Input field estilizado
create_input() {
	local placeholder=$1
	local value=${2:-""}
	local width=${3:-40}

	echo -e "\033[38;5;${TEXT_MUTED}m${placeholder}\033[0m"
	echo -e "\033[38;5;${BORDER}m┌$(printf '─%.0s' $(seq 1 $((width - 2))))┐\033[0m"
	echo -e "\033[38;5;${BORDER}m│\033[0m \033[38;5;${TEXT_PRIMARY}m${value}$(printf ' %.0s' $(seq 1 $((width - ${#value} - 3))))\033[38;5;${BORDER}m│\033[0m"
	echo -e "\033[38;5;${BORDER}m└$(printf '─%.0s' $(seq 1 $((width - 2))))┘\033[0m"
}

# Button estilizado
create_button() {
	local text=$1
	local type=${2:-primary} # primary, secondary, danger

	local bg_color
	local fg_color

	case $type in
	primary)
		bg_color=$ACCENT
		fg_color=$PRIMARY
		;;
	secondary)
		bg_color=$SECONDARY
		fg_color=$TEXT_PRIMARY
		;;
	danger)
		bg_color=$ACCENT
		fg_color=$PRIMARY
		;;
	esac

	local padding=2
	local text_length=${#text}
	local total_width=$((text_length + padding * 2))

	echo -e "\033[48;5;${bg_color}m\033[38;5;${fg_color}m$(printf ' %.0s' $(seq 1 $padding))${text}$(printf ' %.0s' $(seq 1 $padding))\033[0m"
}

# ============================================
# LOGO ANIMADO
# ============================================

# Logo com efeito de fade-in monocromático
logo_animated() {
	clear

	local colors=($PRIMARY $SECONDARY $ACCENT $HIGHLIGHT $TEXT_PRIMARY)
	local text="AURORA INSTALLER"
	local subtitle="Debian ZFS NAS - High Performance Storage"

	# Efeito de fade-in
	for i in {0..4}; do
		clear
		vspace 2

		# Título principal
		echo -e "\033[38;5;${colors[$i]}m$(center_text "$text" 60)\033[0m"
		vspace 1

		# Subtítulo
		echo -e "\033[38;5;${colors[$i]}m$(center_text "$subtitle" 60)\033[0m"
		vspace 2

		# Linha decorativa
		echo -e "\033[38;5;${colors[$i]}m$(center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 60)\033[0m"

		sleep 0.15
	done

	# Versão final estável
	clear
	vspace 2
	echo -e "\033[1;38;5;${HIGHLIGHT}m$(center_text "$text" 60)\033[0m"
	vspace 1
	echo -e "\033[38;5;${TEXT_SECONDARY}m$(center_text "$subtitle" 60)\033[0m"
	vspace 2
	echo -e "\033[38;5;${BORDER}m$(center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 60)\033[0m"
	vspace 1
}

# Logo estático
logo_static() {
	clear
	vspace 2

	local text="AURORA INSTALLER"
	local subtitle="Debian ZFS NAS - High Performance Storage"

	echo -e "\033[1;38;5;${HIGHLIGHT}m$(center_text "$text" 60)\033[0m"
	vspace 1
	echo -e "\033[38;5;${TEXT_SECONDARY}m$(center_text "$subtitle" 60)\033[0m"
	vspace 2
	echo -e "\033[38;5;${BORDER}m$(center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 60)\033[0m"
	vspace 1
}

# ============================================
# SISTEMA DE NAVEGAÇÃO
# ============================================

# Menu de navegação elegante
create_menu() {
	local title=$1
	shift
	local options=("$@")
	local selected=0

	while true; do
		clear
		logo_static
		vspace 1

		# Título do menu
		echo -e "\033[1;38;5;${HIGHLIGHT}m${title}\033[0m"
		vspace 1

		# Opções
		for i in "${!options[@]}"; do
			if [ $i -eq $selected ]; then
				echo -e "\033[48;5;${ACCENT}m\033[38;5;${PRIMARY}m▶ ${options[$i]}\033[0m"
			else
				echo -e "\033[38;5;${TEXT_SECONDARY}m  ${options[$i]}\033[0m"
			fi
		done

		vspace 2
		echo -e "\033[38;5;${TEXT_MUTED}mUse ↑/↓ para navegar, Enter para selecionar\033[0m"

		# Captura de tecla
		read -rsn1 key
		case $key in
		$'\x1b') # Sequência de escape
			read -rsn2 -t 0.1 key
			case $key in
			'[A') # Seta para cima
				selected=$(((selected - 1 + ${#options[@]}) % ${#options[@]}))
				;;
			'[B') # Seta para baixo
				selected=$(((selected + 1) % ${#options[@]}))
				;;
			esac
			;;
		'') # Enter
			return $selected
			;;
		esac
	done
}

# ============================================
# SISTEMA DE FEEDBACK VISUAL
# ============================================

# Toast notification elegante
show_toast() {
	local message=$1
	local type=${2:-info} # success, error, warning, info
	local duration=${3:-3}

	local icon
	local color

	case $type in
	success)
		icon="✓"
		color=$SUCCESS
		;;
	error)
		icon="✖"
		color=$ERROR
		;;
	warning)
		icon="⚠"
		color=$WARNING
		;;
	info)
		icon="ℹ"
		color=$ACCENT
		;;
	esac

	# Salva posição do cursor
	tput sc

	# Move para a linha inferior
	tput cup $(($(tput lines) - 3)) 0

	# Renderiza toast
	local width=${#message}
	local total_width=$((width + 8))

	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${color}m┌$(printf '─%.0s' $(seq 1 $((total_width - 2))))┐\033[0m"
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${color}m│ ${icon} ${message}$(printf ' %.0s' $(seq 1 $((total_width - ${#message} - 6))))│\033[0m"
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${color}m└$(printf '─%.0s' $(seq 1 $((total_width - 2))))┘\033[0m"

	# Aguarda
	sleep $duration

	# Restaura cursor
	tput rc
}

# Modal dialog elegante
show_modal() {
	local title=$1
	local message=$2
	shift 2
	local buttons=("$@")

	local width=60
	local height=10

	# Calcula posição central
	local term_width=$(tput cols)
	local term_height=$(tput lines)
	local start_col=$(((term_width - width) / 2))
	local start_row=$(((term_height - height) / 2))

	# Move cursor para posição
	tput cup $start_row $start_col

	# Renderiza modal
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m┌$(printf '─%.0s' $(seq 1 $((width - 2))))┐\033[0m"

	# Título
	tput cup $((start_row + 1)) $start_col
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m \033[1;38;5;${HIGHLIGHT}m${title}\033[0m$(printf ' %.0s' $(seq 1 $((width - ${#title} - 4))))\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m"

	# Separador
	tput cup $((start_row + 2)) $start_col
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m├$(printf '─%.0s' $(seq 1 $((width - 2))))┤\033[0m"

	# Mensagem
	tput cup $((start_row + 4)) $start_col
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m \033[38;5;${TEXT_PRIMARY}m${message}\033[0m$(printf ' %.0s' $(seq 1 $((width - ${#message} - 4))))\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m"

	# Separador
	tput cup $((start_row + 6)) $start_col
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m├$(printf '─%.0s' $(seq 1 $((width - 2))))┤\033[0m"

	# Botões
	local button_row=$((start_row + 8))
	local button_col=$((start_col + 2))
	for button in "${buttons[@]}"; do
		tput cup $button_row $button_col
		echo -e "\033[48;5;${ACCENT}m\033[38;5;${PRIMARY}m ${button} \033[0m"
		button_col=$((button_col + ${#button} + 4))
	done

	# Linha inferior
	tput cup $((start_row + 9)) $start_col
	echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m└$(printf '─%.0s' $(seq 1 $((width - 2))))┘\033[0m"
}

# ============================================
# SISTEMA DE PROGRESSO MULTI-ETAPA
# ============================================

# Barra de progresso com etapas
create_step_progress() {
	local current_step=$1
	local total_steps=$2
	shift 2
	local steps=("$@")

	local width=60
	local step_width=$((width / total_steps))

	echo -e "\033[38;5;${TEXT_MUTED}mProgresso da Instalação\033[0m"
	echo ""

	for ((i = 0; i < total_steps; i++)); do
		local step_text="${steps[$i]}"
		local step_text_short="${step_text:0:10}"

		if [ $i -lt $current_step ]; then
			# Etapa concluída
			echo -e "\033[48;5;${ACCENT}m\033[38;5;${PRIMARY}m${step_text_short}$(printf ' %.0s' $(seq 1 $((step_width - ${#step_text_short}))))\033[0m"
		elif [ $i -eq $current_step ]; then
			# Etapa atual
			echo -e "\033[48;5;${HIGHLIGHT}m\033[38;5;${PRIMARY}m${step_text_short}$(printf ' %.0s' $(seq 1 $((step_width - ${#step_text_short}))))\033[0m"
		else
			# Etapa pendente
			echo -e "\033[48;5;${SECONDARY}m\033[38;5;${TEXT_MUTED}m${step_text_short}$(printf ' %.0s' $(seq 1 $((step_width - ${#step_text_short}))))\033[0m"
		fi
	done

	echo ""
	local percentage=$((current_step * 100 / total_steps))
	echo -e "\033[38;5;${TEXT_SECONDARY}mEtapa ${current_step}/${total_steps} (${percentage}%)\033[0m"
}

# ============================================
# COMPONENTES DE FEEDBACK
# ============================================

# Success box
success_box() {
	local message=$1
	create_card "✓ Sucesso" "$message"
}

# Error box
error_box() {
	local message=$1
	create_card "✖ Erro" "$message"
}

# Warning box
warning_box() {
	local message=$1
	create_card "⚠ Aviso" "$message"
}

# Info box
info_box() {
	local message=$1
	create_card "ℹ Informação" "$message"
}

# ============================================
# FUNÇÕES DE UTILIDADE
# ============================================

# Limpa a tela
clear_screen() {
	clear
}

# Pausa para leitura
pause() {
	echo ""
	echo -e "\033[38;5;${TEXT_MUTED}mPressione Enter para continuar...\033[0m"
	read
}

# Exibe separador
separator() {
	local width=${1:-60}
	echo -e "\033[38;5;${BORDER}m$(center_text "$(printf '─%.0s' $(seq 1 $width))" $width)\033[0m"
}

# Exibe linha decorativa
decorative_line() {
	local width=${1:-60}
	echo -e "\033[38;5;${BORDER}m$(center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $width)\033[0m"
}
