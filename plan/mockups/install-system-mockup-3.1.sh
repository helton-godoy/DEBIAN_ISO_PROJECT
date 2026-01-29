#!/bin/bash
# install-system-mockup-3
# "Aurora" - Instalador TUI Premium para Debian ZFS NAS (MOCKUP MODE)
# Desenvolvido com Antigravity Intelligence - 2026-01-29
#
# MODO MOCKUP: Todas as operações são simuladas para fins de demonstração estética
# Z.AI: GLM 4.7 (free)

set -e

# --- Configurações do Pool ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Variáveis Globais ---
MOCK_MODE=true
TARGET_DISK=""
ADM_USER=""
ADM_PASS=""
INSTALLATION_LOG=()

# --- Funções de UI Aurora Aprimoradas ---

# Animação de loading
animate_loading() {
	local text="$1"
	local duration=${2:-2}
	local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
	local i=0
	local end_time=$((SECONDS + duration))

	while [ $SECONDS -lt $end_time ]; do
		printf "\r\033[38;5;212m%s\033[0m %s" "${chars:$i:1}" "$text"
		i=$(((i + 1) % ${#chars}))
		sleep 0.1
	done
	printf "\r\033[38;5;40m✓\033[0m %s\n" "$text"
}

# Logo animado com efeito de gradiente
logo() {
	clear
	local colors=("38;5;93" "38;5;129" "38;5;165" "38;5;201" "38;5;213")
	local color_index=0

	# Efeito de fade-in
	for i in {1..3}; do
		clear
		gum style \
			--foreground "${colors[$color_index]}" --border-foreground "${colors[$color_index]}" --border double \
			--align center --width 60 --margin "1 2" --padding "0 1" \
			"AURORA INSTALLER" "Debian ZFS NAS - High Performance Storage"
		sleep 0.2
		color_index=$(((color_index + 1) % ${#colors[@]}))
	done

	# Versão final estável
	clear
	gum style \
		--foreground 212 --border-foreground 212 --border double \
		--align center --width 60 --margin "1 2" --padding "0 1" \
		"AURORA INSTALLER" "Debian ZFS NAS - High Performance Storage"

	# Badge de modo mockup
	gum style \
		--foreground 226 --background 94 --bold \
		--align center --width 60 --margin "0 2" \
		"⚠️  MODO MOCKUP - Simulação Apenas"
}

# Header com ícone
header() {
	echo ""
	gum style --foreground 123 --bold "▶ $1"
	echo ""
}

# Error box com animação
error_box() {
	gum style --foreground 196 --border-foreground 196 --border thick \
		--padding "1 2" --margin "1 1" \
		"✖ ERRO: $1"
}

# Success box
success_box() {
	gum style --foreground 40 --border-foreground 40 --border double \
		--padding "1 2" --margin "1 1" \
		"✓ $1"
}

# Info box
info_box() {
	gum style --foreground 39 --border-foreground 39 --border normal \
		--padding "0 1" --margin "0 1" \
		"ℹ $1"
}

# Barra de progresso animada
progress_bar() {
	local current=$1
	local total=$2
	local label=$3
	local percentage=$((current * 100 / total))
	local filled=$((percentage / 2))
	local empty=$((50 - filled))

	printf "\r\033[38;5;123m%s:\033[0m [" "$label"
	printf "\033[38;5;212m%*s\033[0m" $filled | tr ' ' '█'
	printf "\033[38;5;240m%*s\033[0m" $empty | tr ' ' '░'
	printf "] %d%%" $percentage
}

# Adicionar ao log
add_log() {
	local timestamp=$(date '+%H:%M:%S')
	INSTALLATION_LOG+=("[$timestamp] $1")
}

# Exibir painel de logs
show_logs() {
	clear
	gum style --foreground 212 --bold --border double --padding "1 2" \
		"📋 LOGS DA INSTALAÇÃO"
	echo ""

	for log in "${INSTALLATION_LOG[@]}"; do
		gum style --foreground 244 "$log"
	done

	echo ""
	gum confirm "Pressione Enter para continuar..."
}

# --- Funções de Simulação ---

# Simula verificação de hardware
mock_check_hardware() {
	add_log "Iniciando verificação de hardware..."
	animate_loading "Detectando sistema UEFI..." 2
	add_log "✓ UEFI detectado com sucesso"
	sleep 0.5

	gum style --foreground 40 " [✓] Ambiente UEFI detectado."
	sleep 0.5

	# Simula verificação de memória
	animate_loading "Verificando memória disponível..." 1
	add_log "✓ Memória: 16GB disponível"
	gum style --foreground 40 " [✓] Memória: 16GB disponível"
	sleep 0.5

	# Simula verificação de CPU
	animate_loading "Verificando processador..." 1
	add_log "✓ CPU: 8 núcleos detectados"
	gum style --foreground 40 " [✓] CPU: 8 núcleos detectados"
}

# Simula listagem de discos
mock_list_disks() {
	add_log "Escaneando dispositivos de armazenamento..."
	animate_loading "Buscando discos disponíveis..." 2

	# Lista de discos simulados
	echo "nvme0n1 (512GB) - Samsung SSD 970 EVO"
	echo "sda (1TB) - Western Digital Blue"
	echo "sdb (2TB) - Seagate Barracuda"

	add_log "✓ 3 discos encontrados"
}

# Simula formatação de disco
mock_format_disk() {
	local disk="$1"
	add_log "Iniciando formatação do disco $disk..."

	# Simula wipefs
	animate_loading "Limpando tabela de partições..." 2
	add_log "✓ Tabela de partições limpa"

	# Simula criação de partição EFI
	animate_loading "Criando partição EFI (512MB)..." 2
	add_log "✓ Partição EFI criada"

	# Simula formatação EFI
	animate_loading "Formatando partição EFI (FAT32)..." 2
	add_log "✓ Partição EFI formatada"

	# Simula criação de partição ZFS
	animate_loading "Criando partição ZFS..." 2
	add_log "✓ Partição ZFS criada"
}

# Simula criação de pool ZFS
mock_create_zfs_pool() {
	add_log "Iniciando criação do pool ZFS..."

	animate_loading "Criando pool ZFS ($POOL_NAME)..." 3
	add_log "✓ Pool ZFS criado com sucesso"

	animate_loading "Configurando datasets ZFS..." 2
	add_log "✓ Datasets ROOT/debian criados"
	add_log "✓ Datasets home/root criados"

	animate_loading "Configurando propriedades ZFS..." 1
	add_log "✓ Propriedades configuradas"
}

# Simula montagem de sistema
mock_mount_system() {
	add_log "Montando hierarquia ZFS..."

	animate_loading "Exportando e importando pool..." 2
	add_log "✓ Pool importado em /mnt"

	animate_loading "Montando datasets..." 1
	add_log "✓ ROOT/debian montado em /"
	add_log "✓ home montado em /home"

	animate_loading "Montando partição EFI..." 1
	add_log "✓ EFI montado em /boot/efi"
}

# Simula extração de sistema
mock_extract_system() {
	add_log "Iniciando extração do sistema base..."

	local total_steps=10
	for i in $(seq 1 $total_steps); do
		progress_bar $i $total_steps "Extraindo arquivos"
		sleep 0.3
	done
	printf "\n"

	add_log "✓ Sistema base extraído (4.2GB)"
}

# Simula configuração do sistema
mock_configure_system() {
	add_log "Configurando sistema..."

	animate_loading "Configurando hostname..." 1
	add_log "✓ Hostname definido: nas-zfs"

	animate_loading "Configurando rede..." 1
	add_log "✓ Configuração DHCP aplicada"

	animate_loading "Configurando fstab..." 1
	add_log "✓ fstab configurado"

	animate_loading "Gerando machine-id..." 1
	add_log "✓ machine-id gerado"
}

# Simula instalação do bootloader
mock_install_bootloader() {
	add_log "Instalando ZFSBootMenu..."

	animate_loading "Baixando ZFSBootMenu..." 2
	add_log "✓ ZFSBootMenu baixado"

	animate_loading "Instalando EFI..." 1
	add_log "✓ EFI instalado em /boot/efi/EFI/ZBM"

	animate_loading "Configurando boot..." 1
	add_log "✓ Boot configurado"
}

# Simula finalização no chroot
mock_chroot_finalize() {
	add_log "Finalizando instalação no chroot..."

	animate_loading "Montando sistemas de arquivos..." 1
	add_log "✓ /dev, /proc, /sys montados"

	animate_loading "Configurando usuários..." 2
	add_log "✓ Usuário $ADM_USER criado"
	add_log "✓ Senhas configuradas"

	animate_loading "Gerando initramfs..." 3
	add_log "✓ initramfs gerado"

	animate_loading "Configurando ZFS cache..." 1
	add_log "✓ zpool.cache configurado"
}

# --- Funções de Validação ---

# Valida nome de usuário
validate_username() {
	local username="$1"

	# Verifica se está vazio
	if [ -z "$username" ]; then
		gum style --foreground 196 "✗ Nome de usuário não pode estar vazio"
		return 1
	fi

	# Verifica comprimento
	if [ ${#username} -lt 3 ]; then
		gum style --foreground 196 "✗ Nome de usuário deve ter pelo menos 3 caracteres"
		return 1
	fi

	# Verifica caracteres inválidos
	if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
		gum style --foreground 196 "✗ Nome de usuário contém caracteres inválidos"
		return 1
	fi

	# Verifica se é um nome reservado
	local reserved=("root" "admin" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody")
	for reserved_name in "${reserved[@]}"; do
		if [ "$username" = "$reserved_name" ]; then
			gum style --foreground 196 "✗ '$username' é um nome de usuário reservado"
			return 1
		fi
	done

	gum style --foreground 40 "✓ Nome de usuário válido"
	return 0
}

# Valida força da senha
validate_password_strength() {
	local password="$1"
	local strength=0
	local feedback=()

	# Comprimento mínimo
	if [ ${#password} -ge 8 ]; then
		strength=$((strength + 1))
	else
		feedback+=("Mínimo 8 caracteres")
	fi

	# Letras maiúsculas
	if [[ "$password" =~ [A-Z] ]]; then
		strength=$((strength + 1))
	else
		feedback+=("Adicione letras maiúsculas")
	fi

	# Letras minúsculas
	if [[ "$password" =~ [a-z] ]]; then
		strength=$((strength + 1))
	else
		feedback+=("Adicione letras minúsculas")
	fi

	# Números
	if [[ "$password" =~ [0-9] ]]; then
		strength=$((strength + 1))
	else
		feedback+=("Adicione números")
	fi

	# Caracteres especiais
	if [[ "$password" =~ [^a-zA-Z0-9] ]]; then
		strength=$((strength + 1))
	else
		feedback+=("Adicione caracteres especiais")
	fi

	# Exibe feedback
	case $strength in
	0 | 1)
		gum style --foreground 196 "Força: Muito fraca"
		for msg in "${feedback[@]}"; do
			gum style --foreground 196 "  • $msg"
		done
		return 1
		;;
	2)
		gum style --foreground 208 "Força: Fraca"
		for msg in "${feedback[@]}"; do
			gum style --foreground 208 "  • $msg"
		done
		return 1
		;;
	3)
		gum style --foreground 226 "Força: Média"
		for msg in "${feedback[@]}"; do
			gum style --foreground 226 "  • $msg"
		done
		return 0
		;;
	4)
		gum style --foreground 40 "Força: Forte"
		return 0
		;;
	5)
		gum style --foreground 46 "Força: Muito forte"
		return 0
		;;
	esac
}

# --- Início do Script ---

logo

# 1. Verificações de Hardware (Simulado)
header "Verificando ambiente..."
mock_check_hardware

echo ""
gum confirm "Continuar com a instalação?" --default=true \
	--affirmative "SIM" --negative "NÃO" || exit 1

# 2. Seleção de Disco (Simulado)
logo
header "Selecione o disco de destino"
info_box "OBS: Todos os dados no disco selecionado serão APAGADOS."
echo ""

DISK_LIST=$(mock_list_disks)

TARGET_SELECTED=$(echo "$DISK_LIST" | gum choose --height 10 --cursor.foreground 212)
TARGET_DISK="/dev/$(echo "$TARGET_SELECTED" | awk '{print $1}')"

add_log "Disco selecionado: $TARGET_DISK"

# 3. Informações do Usuário com Validação
logo
header "Configuração de Conta"

while true; do
	ADM_USER=$(gum input --placeholder "Nome do usuário (ex: admin)" --value "helton")

	if validate_username "$ADM_USER"; then
		break
	fi

	if ! gum confirm "Tentar novamente?" --default=true; then
		exit 1
	fi
done

header "Defina a senha para $ADM_USER e Root"
while true; do
	echo ""
	ADM_PASS=$(gum input --password --placeholder "Senha")

	if ! validate_password_strength "$ADM_PASS"; then
		if ! gum confirm "Usar esta senha mesmo assim?" --default=false; then
			continue
		fi
	fi

	CONFIRM_PASS=$(gum input --password --placeholder "Confirme a senha")

	if [ "$ADM_PASS" = "$CONFIRM_PASS" ] && [ -n "$ADM_PASS" ]; then
		break
	fi

	gum style --foreground 196 "✗ As senhas não conferem ou estão vazias. Tente novamente."
done

# 4. Confirmação Final com Tabela Detalhada
logo
header "Resumo da Instalação"
echo ""

gum join --vertical \
	"$(gum style --width 20 "Disco:") $(gum style --foreground 212 "$TARGET_DISK")" \
	"$(gum style --width 20 "Usuário:") $(gum style --foreground 212 "$ADM_USER")" \
	"$(gum style --width 20 "Hostname:") $(gum style --foreground 212 "nas-zfs")" \
	"$(gum style --width 20 "Filesystem:") $(gum style --foreground 212 "ZFS on Root (ZBM)")" \
	"$(gum style --width 20 "Pool ZFS:") $(gum style --foreground 212 "$POOL_NAME")" \
	"$(gum style --width 20 "Compressão:") $(gum style --foreground 212 "lz4")" \
	"$(gum style --width 20 "Modo:") $(gum style --foreground 226 "MOCKUP (Simulação)")"

echo ""
info_box "⚠️  Este é um modo de simulação. Nenhuma alteração real será feita no sistema."
echo ""

if ! gum confirm "Confirmar início da instalação?" --default=false \
	--affirmative "PROSSEGUIR" --negative "CANCELAR"; then
	exit 1
fi

# 5. Execução Técnica Simulada com Animações
logo
header "Iniciando Instalação (Modo Simulação)"
echo ""

# Etapa 1: Formatação
header "Etapa 1/6: Preparando Disco"
mock_format_disk "$TARGET_DISK"
success_box "Disco preparado com sucesso"
sleep 1

# Etapa 2: Pool ZFS
logo
header "Etapa 2/6: Criando Pool ZFS"
mock_create_zfs_pool
success_box "Pool ZFS criado com sucesso"
sleep 1

# Etapa 3: Montagem
logo
header "Etapa 3/6: Montando Sistema"
mock_mount_system
success_box "Sistema montado com sucesso"
sleep 1

# Etapa 4: Extração
logo
header "Etapa 4/6: Instalando Sistema Base"
mock_extract_system
success_box "Sistema base instalado"
sleep 1

# Etapa 5: Configuração
logo
header "Etapa 5/6: Configurando Sistema"
mock_configure_system
success_box "Sistema configurado"
sleep 1

# Etapa 6: Bootloader
logo
header "Etapa 6/6: Instalando Bootloader"
mock_install_bootloader
success_box "Bootloader instalado"
sleep 1

# Etapa 7: Finalização
logo
header "Finalizando Instalação"
mock_chroot_finalize
success_box "Instalação finalizada"
sleep 1

# 6. Tela de Sucesso
logo
gum style --foreground 40 --border-foreground 40 --border double --padding "1 2" \
	"✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!" \
	"" \
	"Usuário: $ADM_USER" \
	"Hostname: nas-zfs" \
	"Pool ZFS: $POOL_NAME" \
	"" \
	"⚠️  MODO MOCKUP: Nenhuma alteração real foi feita" \
	"" \
	"Dica: Para instalação real, use o script sem modo mockup"

echo ""

# Opções pós-instalação
CHOICE=$(gum choose \
	"📋 Ver logs da instalação" \
	"🔄 Reiniciar sistema (simulado)" \
	"🚪 Sair")

case "$CHOICE" in
"📋 Ver logs da instalação")
	show_logs
	;;
"🔄 Reiniciar sistema (simulado)")
	animate_loading "Reiniciando sistema..." 3
	clear
	gum style --foreground 40 --border double --padding "1 2" \
		"✓ Sistema reiniciado (simulação)"
	;;
"🚪 Sair")
	clear
	gum style --foreground 212 --bold "Obrigado por testar o Aurora Installer!"
	;;
esac

echo ""
gum style --foreground 244 "Pressione Enter para sair..."
read
