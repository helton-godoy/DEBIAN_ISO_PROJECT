#!/bin/bash
# install-system-mockup-4
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS
# Desenvolvido com Antigravity Intelligence - 2026-01-28
#
# MODO DE DESENVOLVIMENTO - FUNÇÕES REAIS DESATIVADAS
# Use DRY_RUN=true para simulação visual completa
# Minimax M2.1 (free)

set -e

# --- Configurações ---
DRY_RUN="${DRY_RUN:-true}" # Define se deve simular (true) ou executar real (false)

# --- Funções de UI Aurora ---

logo() {
	clear
	gum style \
		--foreground 212 --border-foreground 212 --border double \
		--align center --width 60 --margin "1 2" --padding "0 1" \
		"AURORA INSTALLER" "Debian ZFS NAS - High Performance Storage"
}

header() {
	gum style --foreground 123 --bold ">> $1"
}

success() {
	gum style --foreground 40 "✓ $1"
}

warning() {
	gum style --foreground 214 "⚠ $1"
}

error_box() {
	gum style --foreground 196 --border-foreground 196 --border normal \
		--padding "0 1" --margin "1 1" "ERRO: $1"
}

# --- Função Simulada para Desenvolvimento ---
# Substitui run_step() quando DRY_RUN=true
simulate_step() {
	local title="$1"
	local duration="${2:-1.5}"

	# Animação de spinner com delay real
	gum spin --spinner dot --title "${title}" -- sleep "${duration}"

	# Emoji e cor baseada no tipo de etapa
	local icon="*"
	local color=123

	case "${title}" in
	*Limpando* | *limpando* | *Formatando* | *formatando*)
		icon="[CLEAN]"
		color=214
		;;
	*EFI* | *efi* | *Boot* | *boot*)
		icon="[EFI]"
		color=39
		;;
	*Pool* | *pool* | *ZFS* | *zfs*)
		icon="[ZFS]"
		color=45
		;;
	*Instalando* | *instalando* | *Extraindo* | *extraindo*)
		icon="[PKG]"
		color=141
		;;
	*Configurando* | *configurando* | *Finalizando* | *finalizando*)
		icon="[CFG]"
		color=201
		;;
	*Conclu* | *conclu*)
		icon="[OK]"
		color=40
		;;
	*)
		icon="[RUN]"
		color=123
		;;
	esac

	echo ""
	printf "  "
	gum style --foreground "${color}" "${icon} ${title}"
}

# --- Função Real (Desativada por padrão) ---
# Use run_step() diretamente se DRY_RUN=false
run_step() {
	local title="$1"
	local cmd="$2"
	if [[ "${DRY_RUN}" = "true" ]]; then
		simulate_step "${title}" 1.5
	elif ! gum spin --spinner dot --title "${title}" -- bash -c "${cmd}"; then
		error_box "Falha ao executar: ${title}"
		exit 1
	fi
}

# --- Início do Script ---

logo

if [[ "${DRY_RUN}" = "true" ]]; then
	gum style --foreground 214 --border-foreground 214 --border normal \
		--padding "1 2" --margin "1 1" \
		"🐛 MODO DE DESENVOLVIMENTO ATIVADO" \
		"Os comandos de instalação estão desativados." \
		"Este instalador está em fase de design estético."
	echo ""
fi

# 1. Verificações de Hardware
header "Verificando ambiente..."
if [[ ! -d /sys/firmware/efi ]] && [[ "${DRY_RUN}" = "false" ]]; then
	error_box "O sistema não iniciou via UEFI. O Aurora requer UEFI."
	exit 1
fi
success "Ambiente UEFI detectado."

# 2. Seleção de Disco style "Proxmox"
header "Selecione o disco de destino"
gum style --foreground 250 --italic "Todos os dados no disco selecionado serão APAGADOS."

DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1" ("$2") - "$3}')

if [[ -z "${DISK_LIST}" ]]; then
	error_box "Nenhum disco encontrado disponível para instalação."
	exit 1
fi

TARGET_SELECTED=$(echo "${DISK_LIST}" | gum choose --height 10 --cursor.foreground 212)
TARGET_DISK="/dev/$(echo "${TARGET_SELECTED}" | awk '{print $1}')"

# 3. Informações do Usuário com Estética Aprimorada
logo
header "Configuração de Conta"

# Animação de entrada para o campo de usuário
gum style --foreground 250 "Crie sua conta de administrador"
ADM_USER=$(gum input --placeholder "Nome do usuário (ex: admin)" --value "helton" \
	--prompt.foreground 123 --cursor.foreground 212)

header "Defina a senha para ${ADM_USER} e Root"
while true; do
	ADM_PASS=$(gum input --password --placeholder "Senha" --prompt "🔒 ")
	CONFIRM_PASS=$(gum input --password --placeholder "Confirme a senha" --prompt "🔒 ")

	if [[ "${ADM_PASS}" = "${CONFIRM_PASS}" ]] && [[ -n "${ADM_PASS}" ]]; then
		success "Senha definida com sucesso!"
		break
	fi
	warning "As senhas não conferem ou estão vazias. Tente novamente."
done

# 4. Confirmação Final com Tabela Estilizada
logo
header "Resumo da Instalação"

# Criar tabela visual com border
gum join --vertical \
	"$(gum style --foreground 250 --italic "─── Configuração do Sistema ───")" \
	"" \
	"$(gum join --horizontal "   💿 Disco:" "$(gum style --foreground 21${ "$TARGET_D}ISK")")" \
	"$(gum join --horizontal "   👤 Usuário:" "$(gum style --foreground 2${2 "$ADM_}USER")")" \
	"$(gum join --horizontal "   🖥️ Hostname:" "$(gum style --foreground 212 "nas-zfs")")" \
	"$(gum join --horizontal "   📁 Filesystem:" "$(gum style --foreground 212 "ZFS on Root (ZBM)")")" \
	"" \
	"$(gum style --foreground 250 --italic "─── Conformidade ───")" \
	"$(gum join --horizontal "   ⚠️ AVISO:" "$(gum style --foreground 214 "Todos os dados serão apagados!")")"

echo ""
gum confirm "Confirmar início da instalação? O disco será formatado." --default=false \
	--affirmative "PROSSEGUIR" --negative "CANCELAR" || exit 1

# 5. Execução Técnica com Spinners e Barra de Progresso
logo
header "Instalando Sistema"

# Definir etapas para barra de progresso
STEPS=(
	"Limpando disco"
	"Configurando partição EFI"
	"Criando pool ZFS"
	"Criando datasets"
	"Montando sistema"
	"Extraindo arquivos"
	"Configurando rede"
	"Instalando bootloader"
	"Finalizando chroot"
)

# Mostrar barra de progresso
for i in "${!STEPS[@]}"; do
	percent=$(((i + 1) * 100 / ${#STEPS[@]}))
	simulate_step "${STEPS[${i}]}" 0.8
done

# 6. Tela de Conclusão
logo
gum style --foreground 40 --border-foreground 40 --border double --padding "2 2" \
	"🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!" \
	"" \
	"👤 Usuár${o: $ADM_}USER" \
	"🔑 Senha: Definida" \
	"" \
	"💡 Dica: Remova a mídia Live e reinicie o sistema."

echo ""
gum style --foreground 250 "Obrigado por testar o Aurora Installer!"
echo ""

if gum confirm "Deseja executar novamente?" --default=true; then
	exec "$0" # Reinicia o script
fi
