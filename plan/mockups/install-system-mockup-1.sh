#!/bin/bash
# install-system-mockup-1
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS (MODO DEMONSTRAÇÃO)
# Desenvolvido com Antigravity Intelligence - 2026-01-29
#
# ATENÇÃO: Este é um mockup apenas para testes estéticos. Nenhuma instalação real será executada.
# Caude Sonnet 4.5

set -e

# --- Configurações do Pool (apenas para exibição) ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Paleta de Cores Aurora ---
COLOR_PRIMARY=212 # Rosa/Magenta vibrante
COLOR_SUCCESS=40  # Verde
COLOR_INFO=123    # Ciano claro
COLOR_WARNING=214 # Laranja
COLOR_ERROR=196   # Vermelho
COLOR_ACCENT=141  # Roxo claro
COLOR_MUTED=245   # Cinza

# --- Funções de UI Aurora ---

logo() {
	clear
	gum style \
		--foreground "$COLOR_PRIMARY" --border-foreground "$COLOR_PRIMARY" --border double \
		--align center --width 70 --margin "1 2" --padding "1 2" \
		"╔═══════════════════════════════════════════════════════════╗" \
		"║            A U R O R A   I N S T A L L E R                ║" \
		"║                                                           ║" \
		"║       Debian ZFS NAS · High Performance Storage           ║" \
		"╚═══════════════════════════════════════════════════════════╝"

	gum style --foreground "$COLOR_MUTED" --align center --width 70 --margin "0 2" \
		"Versão 1.0.0 · MODO DEMONSTRAÇÃO"
	echo ""
}

banner() {
	gum style \
		--foreground "$COLOR_ACCENT" --border-foreground "$COLOR_ACCENT" --border rounded \
		--align center --width 70 --margin "1 2" --padding "0 2" \
		"$1"
}

header() {
	echo ""
	gum style --foreground "$COLOR_INFO" --bold --margin "1 0" "▶ $1"
}

subheader() {
	gum style --foreground "$COLOR_MUTED" --italic "  $1"
}

success_msg() {
	gum style --foreground "$COLOR_SUCCESS" --bold "✓ $1"
}

warning_box() {
	gum style --foreground "$COLOR_WARNING" --border-foreground "$COLOR_WARNING" --border normal \
		--padding "0 1" --margin "1 1" "⚠ ATENÇÃO: $1"
}

error_box() {
	gum style --foreground "$COLOR_ERROR" --border-foreground "$COLOR_ERROR" --border normal \
		--padding "0 1" --margin "1 1" "✗ ERRO: $1"
}

info_box() {
	gum style --foreground "$COLOR_INFO" --border-foreground "$COLOR_INFO" --border rounded \
		--padding "0 2" --margin "1 1" "$1"
}

progress_bar() {
	local current=$1
	local total=$2
	local width=50
	local filled=$((current * width / total))
	local empty=$((width - filled))
	local percent=$((current * 100 / total))

	# Construir a barra diretamente sem usar tr
	local bar="["

	# Adicionar blocos preenchidos
	for ((i = 0; i < filled; i++)); do
		bar+="█"
	done

	# Adicionar blocos vazios
	for ((i = 0; i < empty; i++)); do
		bar+="░"
	done

	bar+="] ${percent}%"

	echo "$bar"
}

# Função mockup para simular comandos (não executa nada)
mock_run_step() {
	local title="$1"
	local duration="${2:-2}" # Duração em segundos (padrão: 2s)

	gum spin --spinner dot --title "$title" -- sleep "$duration"
	success_msg "$title"
}

# --- Início do Script ---

logo

# Banner de aviso do modo demonstração
warning_box "Este é um MOCKUP para testes estéticos. Nenhuma instalação real será executada."
sleep 2

# 1. Verificações de Hardware (mockup)
header "Verificando ambiente..."
subheader "Detectando configurações de hardware e firmware"

mock_run_step "Verificando modo UEFI" 1
success_msg "Ambiente UEFI detectado"

mock_run_step "Verificando módulos ZFS" 1
success_msg "ZFS 2.2.x disponível"

mock_run_step "Verificando conectividade de rede" 1
success_msg "Rede configurada (DHCP ativo)"

echo ""
gum style --foreground "$COLOR_SUCCESS" --border-foreground "$COLOR_SUCCESS" --border rounded \
	--padding "0 2" --margin "1 2" --align center \
	"✓ Todas as verificações passaram com sucesso!"

sleep 2

# 2. Seleção de Disco com estilo "Proxmox"
logo
header "Seleção de Disco de Destino"
warning_box "Todos os dados no disco selecionado serão APAGADOS!"

# Mockup de lista de discos
DISK_LIST="sda (238.5G) - Samsung SSD 860
sdb (931.5G) - WD Blue HDD
nvme0n1 (500G) - Kingston NVMe"

echo ""
subheader "Discos disponíveis no sistema:"
echo ""

TARGET_SELECTED=$(echo "$DISK_LIST" | gum choose --height 10 --cursor.foreground "$COLOR_PRIMARY" --header "Use ↑↓ para navegar, Enter para selecionar")
TARGET_DISK="/dev/$(echo "$TARGET_SELECTED" | awk '{print $1}')"

info_box "Disco selecionado: $TARGET_DISK
$(echo "$TARGET_SELECTED" | cut -d'-' -f2-)"

sleep 2

# 3. Informações do Usuário com Estética Premium
logo
banner "Configuração de Conta de Administrador"

header "Informações do Usuário"
subheader "Defina as credenciais para o administrador do sistema"
echo ""

ADM_USER=$(gum input --placeholder "Nome do usuário (ex: admin)" --value "helton" \
	--prompt "👤 " --prompt.foreground "$COLOR_PRIMARY")

header "Definição de Senha"
subheader "A senha será usada para $ADM_USER e para o usuário root"
echo ""

while true; do
	ADM_PASS=$(gum input --password --placeholder "Digite a senha" \
		--prompt "🔒 " --prompt.foreground "$COLOR_PRIMARY")
	CONFIRM_PASS=$(gum input --password --placeholder "Confirme a senha" \
		--prompt "🔒 " --prompt.foreground "$COLOR_PRIMARY")

	if [ "$ADM_PASS" = "$CONFIRM_PASS" ] && [ -n "$ADM_PASS" ]; then
		success_msg "Senhas conferem!"
		break
	fi
	error_box "As senhas não conferem ou estão vazias. Tente novamente."
	sleep 1
done

sleep 1

# 4. Configurações Adicionais
logo
banner "Configurações do Sistema"

header "Hostname do Servidor"
subheader "Nome que identificará este servidor na rede"
echo ""

HOSTNAME=$(gum input --placeholder "Nome do host (ex: nas-zfs)" --value "nas-zfs" \
	--prompt "🖥️  " --prompt.foreground "$COLOR_PRIMARY")

header "Timezone"
subheader "Fuso horário do sistema"
echo ""

TIMEZONE=$(echo -e "America/Sao_Paulo\nAmerica/New_York\nEurope/London\nAsia/Tokyo" |
	gum choose --cursor.foreground "$COLOR_PRIMARY" --header "Selecione o timezone")

success_msg "Timezone: $TIMEZONE"

sleep 1

# 5. Confirmação Final com Tabela Estilizada
logo
banner "Resumo da Instalação"

echo ""
gum style --foreground "$COLOR_ACCENT" --bold --align center "Revise as configurações antes de prosseguir"
echo ""

# Tabela de resumo com bordas
gum join --vertical \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Disco de Destino:") $(gum style --foreground "$COLOR_PRIMARY" --bold "$TARGET_DISK")" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Tamanho:") $(gum style --foreground "$COLOR_INFO" "$(echo "$TARGET_SELECTED" | awk '{print $2}')")" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Modelo:") $(gum style --foreground "$COLOR_INFO" "$(echo "$TARGET_SELECTED" | cut -d'-' -f2-)")" \
	"" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Usuário Admin:") $(gum style --foreground "$COLOR_PRIMARY" --bold "$ADM_USER")" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Hostname:") $(gum style --foreground "$COLOR_PRIMARY" --bold "$HOSTNAME")" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Timezone:") $(gum style --foreground "$COLOR_INFO" "$TIMEZONE")" \
	"" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Filesystem:") $(gum style --foreground "$COLOR_SUCCESS" --bold "ZFS on Root")" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Bootloader:") $(gum style --foreground "$COLOR_SUCCESS" --bold "ZFSBootMenu (ZBM)")" \
	"$(gum style --width 25 --foreground "$COLOR_MUTED" "Compressão:") $(gum style --foreground "$COLOR_INFO" "LZ4")"

echo ""
warning_box "O disco será completamente formatado. Esta ação é IRREVERSÍVEL!"
echo ""

gum confirm "Confirmar início da instalação?" --default=false \
	--affirmative "✓ PROSSEGUIR" --negative "✗ CANCELAR" || {
	error_box "Instalação cancelada pelo usuário."
	exit 0
}

# 6. Simulação de Instalação com Progresso Visual
logo
banner "Instalação em Progresso"

# Fase 1: Preparação do Disco
header "Fase 1/5: Preparação do Disco"
echo ""

mock_run_step "Limpando tabela de partições em $TARGET_DISK" 2
mock_run_step "Criando partição EFI (512MB, FAT32)" 1.5
mock_run_step "Criando partição ZFS (restante do disco)" 1.5
mock_run_step "Formatando partição EFI" 1

echo ""
success_msg "Disco preparado com sucesso!"
sleep 1

# Fase 2: Criação do Pool ZFS
logo
banner "Instalação em Progresso"
header "Fase 2/5: Criação do Pool ZFS"
subheader "Configurando pool '$POOL_NAME' com compressão LZ4"
echo ""

mock_run_step "Criando pool ZFS '$POOL_NAME'" 2
mock_run_step "Configurando propriedades do pool (ashift=12, compression=lz4)" 1.5
mock_run_step "Criando dataset ROOT/debian" 1
mock_run_step "Criando dataset home" 1
mock_run_step "Criando dataset home/root" 1
mock_run_step "Definindo bootfs=$POOL_NAME/ROOT/debian" 1

echo ""
success_msg "Pool ZFS criado e configurado!"
sleep 1

# Fase 3: Instalação do Sistema Base
logo
banner "Instalação em Progresso"
header "Fase 3/5: Instalação do Sistema Base"
subheader "Extraindo sistema Debian a partir da imagem SquashFS"
echo ""

# Simulação de progresso com barra
for i in {1..10}; do
	clear
	logo
	banner "Instalação em Progresso"
	header "Fase 3/5: Instalação do Sistema Base"
	echo ""
	gum style --foreground "$COLOR_INFO" "Extraindo arquivos do sistema..."
	echo ""
	progress_bar $i 10
	sleep 0.5
done

echo ""
success_msg "Sistema base instalado (1.2 GB extraídos)"
sleep 1

# Fase 4: Configuração do Sistema
logo
banner "Instalação em Progresso"
header "Fase 4/5: Configuração do Sistema"
echo ""

mock_run_step "Configurando hostname: $HOSTNAME" 1
mock_run_step "Configurando timezone: $TIMEZONE" 1
mock_run_step "Configurando rede (DHCP automático)" 1
mock_run_step "Gerando machine-id único" 1
mock_run_step "Configurando fstab para partição EFI" 1
mock_run_step "Criando usuário '$ADM_USER' com privilégios sudo" 1.5
mock_run_step "Configurando senhas (root e $ADM_USER)" 1

echo ""
success_msg "Sistema configurado!"
sleep 1

# Fase 5: Bootloader
logo
banner "Instalação em Progresso"
header "Fase 5/5: Instalação do Bootloader"
subheader "Configurando ZFSBootMenu para boot UEFI"
echo ""

mock_run_step "Baixando ZFSBootMenu (versão master)" 2
mock_run_step "Instalando ZFSBootMenu.efi em /boot/efi/EFI/ZBM" 1.5
mock_run_step "Criando entrada BOOTX64.EFI" 1
mock_run_step "Gerando hostid ZFS" 1
mock_run_step "Atualizando initramfs" 2
mock_run_step "Configurando cache do pool ZFS" 1

echo ""
success_msg "Bootloader instalado e configurado!"
sleep 2

# 7. Conclusão com Estilo
logo

gum style \
	--foreground "$COLOR_SUCCESS" --border-foreground "$COLOR_SUCCESS" --border double \
	--padding "2 4" --margin "2 2" --align center --width 70 \
	"╔═══════════════════════════════════════════════════════════╗" \
	"║                                                           ║" \
	"║       ✓  INSTALAÇÃO CONCLUÍDA COM SUCESSO!                ║" \
	"║                                                           ║" \
	"╚═══════════════════════════════════════════════════════════╝" \
	"" \
	"Sistema: Debian 13 (Trixie) com ZFS on Root" \
	"Usuário: $ADM_USER" \
	"Hostname: $HOSTNAME" \
	"" \
	"Próximos passos:" \
	"  1. Remova a mídia de instalação (USB/DVD)" \
	"  2. Reinicie o sistema" \
	"  3. Faça login com as credenciais configuradas"

echo ""
info_box "💡 Dica: No primeiro boot, o ZFSBootMenu permitirá selecionar snapshots
e configurações avançadas de boot. Use as setas para navegar."

echo ""

if gum confirm "Deseja simular reinicialização agora?" --affirmative "✓ Reiniciar" --negative "✗ Sair"; then
	logo
	gum style --foreground "$COLOR_PRIMARY" --align center --width 70 \
		"Reiniciando o sistema..."

	gum spin --spinner pulse --title "Desligando serviços" -- sleep 2
	gum spin --spinner pulse --title "Desmontando filesystems" -- sleep 1
	gum spin --spinner pulse --title "Reiniciando..." -- sleep 2

	clear
	gum style --foreground "$COLOR_SUCCESS" --align center --width 70 --margin "10 0" \
		"Sistema reiniciado (simulação)" \
		"" \
		"Mockup finalizado com sucesso!"
else
	clear
	gum style --foreground "$COLOR_INFO" --align center --width 70 --margin "10 0" \
		"Mockup finalizado!" \
		"" \
		"Nenhuma alteração real foi feita no sistema."
fi
