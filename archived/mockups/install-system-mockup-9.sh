#!/bin/bash
# install-system-mockup-9
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS
# Desenvolvido com Antigravity Intelligence - 2026-01-29
#
# MODO MOCKUP: Todas as funções reais DESATIVADAS para desenvolvimento estético
# Claude Opus 4.5 (Thinking)

# set -e DESATIVADO para permitir testes sem interrupção
# set -e

# --- Paleta de Cores Aurora ---
COLOR_PRIMARY=212   # Rosa/Roxo (cor principal Aurora)
COLOR_SECONDARY=123 # Azul ciano (secundária)
COLOR_SUCCESS=40    # Verde
COLOR_ERROR=196     # Vermelho
COLOR_WARNING=214   # Amarelo/Laranja
COLOR_ACCENT=135    # Roxo mais claro
COLOR_MUTED=245     # Cinza suave

# --- Configurações do Pool (apenas para exibição) ---
POOL_NAME="zroot"

# --- Funções de UI Aurora Premium ---

aurora_banner() {
	clear
	# ASCII Art com gradiente de cores
	gum style --foreground "$COLOR_PRIMARY" "
    ░█████╗░██╗░░░██╗██████╗░░█████╗░██████╗░░█████╗░
    ██╔══██╗██║░░░██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗
    ███████║██║░░░██║██████╔╝██║░░██║██████╔╝███████║
    ██╔══██║██║░░░██║██╔══██╗██║░░██║██╔══██╗██╔══██║
    ██║░░██║╚██████╔╝██║░░██║╚█████╔╝██║░░██║██║░░██║
    ╚═╝░░╚═╝░╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝"

	gum style \
		--foreground "$COLOR_SECONDARY" --border-foreground "$COLOR_PRIMARY" --border rounded \
		--align center --width 60 --margin "0 2" --padding "0 2" \
		"⚡ Debian ZFS NAS ⚡" \
		"High Performance Storage Solution"
}

logo() {
	clear
	gum style \
		--foreground "$COLOR_PRIMARY" --border-foreground "$COLOR_PRIMARY" --border double \
		--align center --width 60 --margin "1 2" --padding "0 1" \
		"✨ AURORA INSTALLER ✨" "Debian ZFS NAS - High Performance Storage"
}

header() {
	echo ""
	gum style --foreground "$COLOR_SECONDARY" --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	gum style --foreground "$COLOR_PRIMARY" --bold "  ▶ $1"
	gum style --foreground "$COLOR_SECONDARY" --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

subheader() {
	gum style --foreground "$COLOR_ACCENT" --italic "    ↳ $1"
}

success_msg() {
	gum style --foreground "$COLOR_SUCCESS" "  ✓ $1"
}

error_box() {
	gum style --foreground "$COLOR_ERROR" --border-foreground "$COLOR_ERROR" --border normal \
		--padding "0 1" --margin "1 1" "❌ ERRO: $1"
}

warning_box() {
	gum style --foreground "$COLOR_WARNING" --border-foreground "$COLOR_WARNING" --border normal \
		--padding "0 1" --margin "1 1" "⚠️  AVISO: $1"
}

info_box() {
	gum style --foreground "$COLOR_SECONDARY" --border-foreground "$COLOR_ACCENT" --border rounded \
		--padding "0 1" --margin "1 1" "ℹ️  $1"
}

divider() {
	gum style --foreground "$COLOR_MUTED" "  ─────────────────────────────────────────────────"
}

# Barra de progresso global
PROGRESS_CURRENT=0
PROGRESS_TOTAL=8

progress_bar() {
	local step_name="$1"
	((PROGRESS_CURRENT++))
	local pct=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))
	local filled=$((pct / 5))
	local empty=$((20 - filled))
	local bar=$(printf '█%.0s' $(seq "1 $fill"ed))$(printf '░%.0s' $(se"q 1 $e"mpty))

	gum style --foreground "$COLOR_ACCENT" "  [${bar}] ${pct}% - Etapa ${PROGRESS_CURRENT}/${PROGRESS_TOTAL}"
	gum style --foreground "$COLOR_MUTED" --italic "    ${step_name}"
}

# Spinner com simulação (MOCKUP)
run_step_mock() {
	local title="$1"
	local sleep_time="${2:-2}"
	gum spin --spinner dot --title "${title}" -- sleep "${sleep_time}"
	success_msg "Concluído:${$titl}e"
}

# --- DADOS MOCKUP ---
mock_disk_list() {
	cat <<'EOF'
sda (500GB) - Samsung SSD 870 EVO
sdb (2TB) - Seagate IronWolf NAS
nvme0n1 (1TB) - WD Black SN850X
vda (64GB) - Virtual Disk
EOF
}

# --- Início do Script ---

aurora_banner
sleep 1

# 1. Verificações de Hardware (MOCKUP)
header "🔍 Verificando ambiente..."
run_step_mock "Detectando hardware..." 1
success_msg "Ambiente UEFI detectado."
success_msg "Controladora SATA/NVMe detectada."
success_msg "Módulos ZFS carregados."

# 2. Seleção de Disco (MOCKUP)
logo
header "💾 Selecione o disco de destino"
warning_box "Todos os dados no disco selecionado serão APAGADOS!"

echo ""
gum style --foreground "$COLOR_MUTED" "  Discos disponíveis detectados:"
divider

TARGET_SELECTED=$(mock_disk_list | gum choose --height 8 --cursor.foreground "$COLOR_PRIMARY")
TARGET_DISK="/dev/$(echo "${TARGET_SELECTED}" | awk '{print $1}')"

success_msg "Disco selecionado: ${TARGET_DISK}"

# 3. Informações do Usuário
logo
header "👤 Configuração de Conta"

subheader "Defina o nome de usuário administrador"
ADM_USER=$(gum input --placeholder "Nome do usuário (ex: admin)" --value "helton" \
	--prompt.foreground "$COLOR_PRIMARY" --cursor.foreground "$COLOR_ACCENT")

echo ""
subheader "Defina a senha para ${ADM_USER} e Root"
while true; do
	ADM_PASS=$(gum input --password --placeholder "Digite a senha" \
		--prompt.foreground "$COLOR_PRIMARY" --cursor.foreground "$COLOR_ACCENT")
	CONFIRM_PASS=$(gum input --password --placeholder "Confirme a senha" \
		--prompt.foreground "$COLOR_PRIMARY" --cursor.foreground "$COLOR_ACCENT")

	if [[ "${ADM_PASS}" = "${CONFIRM_PASS}" ]] && [[ -n "${ADM_PASS}" ]]; then
		success_msg "Senha definida com sucesso!"
		break
	fi
	gum style --foreground "$COLOR_ERROR" "  ✗ As senhas não conferem ou estão vazias. Tente novamente."
done

# 4. Hostname
logo
header "🖥️  Configuração de Rede"

subheader "Defina o hostname do sistema"
HOSTNAME=$(gum input --placeholder "Hostname (ex: nas-zfs)" --value "aurora-nas" \
	--prompt.foreground "$COLOR_PRIMARY" --cursor.foreground "$COLOR_ACCENT")

# 5. Confirmação Final com Tabela Premium
logo
header "📋 Resumo da Instalação"

echo ""
gum style --border-foreground "$COLOR_ACCENT" --border rounded --padding "1 2" --margin "1 2" \
	"$(gum join --vertical \
		"$(gum style --width 50 "$(gum style --foreground "$COLOR_MUTED" '  Disco:')        $(gum style --foreground "$COLOR_PRIMARY" --bold "${TARGET_DISK}")")" \
		"$(gum style --width 50 "$(gum style --foreground "$COLOR_MUTED" '  Tamanho:')      $(gum style --foreground "$COLOR_PRIMARY" --bold "$(echo "$TARGET_SELECTED" | awk -F'[()]' '{print $2}')")")" \
		"$(gum style --width 50 "$(gum style --foreground "$COLOR_MUTED" '  Usuário:')      $(gum style --foreground" $COLOR_PRIMAR"Y --bold ${$ADM_USE}R")")" \
		"$(gum style --width 50 "$(gum style --foreground "$COLOR_MUTED" '  Hostname:')     $(gum style --foreground "$COLOR_PRIMARY" --bold "${HOSTNAME}")")" \
		"$(gum style --width 50 "$(gum style --foreground "$COLOR_MUTED" '  Filesystem:')   $(gum style --foreground "$COLOR_PRIMARY" --bold "ZFS on Root (ZBM)")")" \
		"$(gum style --width 50 "$(gum style --foreground "$COLOR_MUTED" '  Pool:')         $(gum style --foreground "$COLOR_PRIMARY" --bold "${POOL_NAME}")")")"

echo ""
gum confirm "🚀 Confirmar início da instalação? O disco será formatado." --default=false \
	--affirmative "✓ PROSSEGUIR" --negative "✗ CANCELAR" \
	--prompt.foreground "${COLOR_PRIMARY}" --selected.background "${COLOR_PRIMARY}" || exit 1

# 6. Execução Técnica com Spinners (MOCKUP)
logo
header "⚙️  Executando Instalação..."

echo ""
info_box "MODO MOCKUP: Nenhuma operação real será executada"
echo ""

progress_bar "Preparando disco"
run_step_mock "Limpando disco ${TARGET_DISK}..." 1
run_step_mock "Verificando integridade do dispositivo..." 0.5

progress_bar "Particionamento"
run_step_mock "Configurando partição EFI (512MB)..." 1
run_step_mock "Criando partição ZFS (restante)..." 1

progress_bar "Pool ZFS"
run_step_mock "Criando Pool ZFS (${POOL_NAME})..." 2
subheader "Opções: ashift=12, compression=lz4, acltype=posixacl"

progress_bar "Datasets ZFS"
run_step_mock "Criando dataset ROOT/debian..." 1
run_step_mock "Criando dataset /home..." 0.5
run_step_mock "Criando dataset /root..." 0.5
run_step_mock "Configurando propriedades bootfs..." 0.5

progress_bar "Montagem do sistema"
run_step_mock "Montando hierarquia ZFS em /mnt..." 1
run_step_mock "Montando partição EFI em /mnt/boot/efi..." 0.5

progress_bar "Sistema base"
run_step_mock "Extraindo arquivos do SquashFS (simulando 4.2GB)..." 5
subheader "Total: 65.432 arquivos extraídos"

progress_bar "Configuração do sistema"
run_step_mock "Configurando hostname (${HOSTNAME})..." 0.5
run_step_mock "Configurando rede (DHCP)..." 0.5
run_step_mock "Gerando machine-id único..." 0.5
run_step_mock "Criando usuário${$ADM_USE}R..." 0.5

progress_bar "Bootloader"
run_step_mock "Instalando ZFSBootMenu..." 2
run_step_mock "Configurando entrada UEFI..." 1
run_step_mock "Atualizando initramfs..." 2

# 7. Tela de Conclusão Premium
clear
gum style --foreground "$COLOR_SUCCESS" "
    ██████╗░░█████╗░███╗░░██╗███████╗██╗
    ██╔══██╗██╔══██╗████╗░██║██╔════╝██║
    ██║░░██║██║░░██║██╔██╗██║█████╗░░██║
    ██║░░██║██║░░██║██║╚████║██╔══╝░░╚═╝
    ██████╔╝╚█████╔╝██║░╚███║███████╗██╗
    ╚═════╝░░╚════╝░╚═╝░░╚══╝╚══════╝╚═╝"

echo ""
gum style --foreground "$COLOR_SUCCESS" --border-foreground "$COLOR_SUCCESS" --border double \
	--padding "1 3" --margin "1 2" --align center \
	"✨ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✨" \
	"" \
	"Usuário:${$ADM_USE}R" \
	"Hostname: ${HOSTNAME}" \
	"Filesystem: ZFS on Root" \
	"" \
	"💡 Dica: Remova a mídia Live e reinicie o sistema."

echo ""
gum style --foreground "$COLOR_MUTED" --italic "  [MOCKUP] Sistema não modificado - apenas demonstração visual"
echo ""

if gum confirm "🔄 Deseja reiniciar agora?" \
	--affirmative "Sim, reiniciar" --negative "Não, voltar ao terminal" \
	--prompt.foreground "${COLOR_PRIMARY}" --selected.background "${COLOR_PRIMARY}"; then
	gum style --foreground "$COLOR_PRIMARY" "  Reiniciando... (simulado)"
	sleep 2
	gum style --foreground "$COLOR_SUCCESS" "  [MOCKUP] Reinício simulado concluído!"
fi

echo ""
gum style --foreground "$COLOR_ACCENT" "  ═══════════════════════════════════════════════════════"
gum style --foreground "$COLOR_PRIMARY" --bold "  Obrigado por usar o Aurora Installer!"
gum style --foreground "$COLOR_ACCENT" "  ═══════════════════════════════════════════════════════"
echo ""
