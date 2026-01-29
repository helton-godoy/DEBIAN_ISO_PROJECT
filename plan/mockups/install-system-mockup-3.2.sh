#!/bin/bash
# Aurora Installer - Exemplo de Implementação Monocromática
# Baseado no install-system-mockup-3 com design monocromático sofisticado
# Desenvolvido com Antigravity Intelligence - 2026-01-29

set -e

# Carrega o sistema de UI
source ./aurora-ui-system.sh

# --- Configurações do Pool ---
POOL_NAME="zroot"
ZFS_OPTS="-o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O mountpoint=none -O canmount=off -O devices=off"

# --- Variáveis Globais ---
MOCK_MODE=true
TARGET_DISK=""
ADM_USER=""
ADM_PASS=""
INSTALLATION_LOG=()

# --- Funções de Simulação ---

# Simula verificação de hardware
mock_check_hardware() {
    add_log "Iniciando verificação de hardware..."
    animate_loading "Detectando sistema UEFI..." 2
    add_log "✓ UEFI detectado com sucesso"
    sleep 0.5

    echo -e "\033[38;5;${SUCCESS}m [✓] Ambiente UEFI detectado.\033[0m"
    sleep 0.5

    # Simula verificação de memória
    animate_loading "Verificando memória disponível..." 1
    add_log "✓ Memória: 16GB disponível"
    echo -e "\033[38;5;${SUCCESS}m [✓] Memória: 16GB disponível\033[0m"
    sleep 0.5

    # Simula verificação de CPU
    animate_loading "Verificando processador..." 1
    add_log "✓ CPU: 8 núcleos detectados"
    echo -e "\033[38;5;${SUCCESS}m [✓] CPU: 8 núcleos detectados\033[0m"
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
        animate_progress $i $total_steps "Extraindo arquivos"
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
        echo -e "\033[38;5;${ERROR}m✗ Nome de usuário não pode estar vazio\033[0m"
        return 1
    fi

    # Verifica comprimento
    if [ ${#username} -lt 3 ]; then
        echo -e "\033[38;5;${ERROR}m✗ Nome de usuário deve ter pelo menos 3 caracteres\033[0m"
        return 1
    fi

    # Verifica caracteres inválidos
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "\033[38;5;${ERROR}m✗ Nome de usuário contém caracteres inválidos\033[0m"
        return 1
    fi

    # Verifica se é um nome reservado
    local reserved=("root" "admin" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody")
    for reserved_name in "${reserved[@]}"; do
        if [ "$username" = "$reserved_name" ]; then
            echo -e "\033[38;5;${ERROR}m✗ '$username' é um nome de usuário reservado\033[0m"
            return 1
        fi
    done

    echo -e "\033[38;5;${SUCCESS}m✓ Nome de usuário válido\033[0m"
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
        echo -e "\033[38;5;${ERROR}mForça: Muito fraca\033[0m"
        for msg in "${feedback[@]}"; do
            echo -e "\033[38;5;${ERROR}m  • $msg\033[0m"
        done
        return 1
        ;;
    2)
        echo -e "\033[38;5;${WARNING}mForça: Fraca\033[0m"
        for msg in "${feedback[@]}"; do
            echo -e "\033[38;5;${WARNING}m  • $msg\033[0m"
        done
        return 1
        ;;
    3)
        echo -e "\033[38;5;${HIGHLIGHT}mForça: Média\033[0m"
        for msg in "${feedback[@]}"; do
            echo -e "\033[38;5;${HIGHLIGHT}m  • $msg\033[0m"
        done
        return 0
        ;;
    4)
        echo -e "\033[38;5;${SUCCESS}mForça: Forte\033[0m"
        return 0
        ;;
    5)
        echo -e "\033[38;5;${SUCCESS}mForça: Muito forte\033[0m"
        return 0
        ;;
    esac
}

# Adicionar ao log
add_log() {
    local timestamp=$(date '+%H:%M:%S')
    INSTALLATION_LOG+=("[$timestamp] $1")
}

# Exibir painel de logs
show_logs() {
    clear
    logo_static
    
    echo -e "\033[1;38;5;${HIGHLIGHT}m$(center_text "📋 LOGS DA INSTALAÇÃO" 60)\033[0m"
    echo ""

    for log in "${INSTALLATION_LOG[@]}"; do
        echo -e "\033[38;5;${TEXT_MUTED}m${log}\033[0m"
    done

    echo ""
    pause
}

# --- Início do Script ---

# Logo animado
logo_animated

# Badge de modo mockup
echo ""
create_badge "⚠  MODO MOCKUP - Simulação Apenas" "warning"
echo ""

# 1. Verificações de Hardware (Simulado)
echo -e "\033[1;38;5;${HIGHLIGHT}m▶ Verificando ambiente...\033[0m"
echo ""
mock_check_hardware

echo ""
echo -e "\033[38;5;${TEXT_MUTED}mPressione Enter para continuar...\033[0m"
read

# 2. Seleção de Disco (Simulado)
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}m▶ Selecione o disco de destino\033[0m"
echo ""
info_box "OBS: Todos os dados no disco selecionado serão APAGADOS."
echo ""

DISK_LIST=$(mock_list_disks)

# Simula seleção de disco (para demonstração)
TARGET_DISK="/dev/nvme0n1"
echo -e "\033[38;5;${HIGHLIGHT}mDisco selecionado: $TARGET_DISK\033[0m"
add_log "Disco selecionado: $TARGET_DISK"

echo ""
pause

# 3. Informações do Usuário com Validação
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}m▶ Configuração de Conta\033[0m"
echo ""

while true; do
    echo -e "\033[38;5;${TEXT_MUTED}mNome do usuário (ex: admin):\033[0m"
    read -p "> " ADM_USER

    if validate_username "$ADM_USER"; then
        break
    fi

    echo ""
    echo -e "\033[38;5;${TEXT_MUTED}mTentar novamente? (s/n)\033[0m"
    read -p "> " retry
    if [ "$retry" != "s" ] && [ "$retry" != "S" ]; then
        exit 1
    fi
done

echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}m▶ Defina a senha para $ADM_USER e Root\033[0m"
echo ""
while true; do
    echo ""
    echo -e "\033[38;5;${TEXT_MUTED}mSenha:\033[0m"
    read -s ADM_PASS
    echo ""

    if ! validate_password_strength "$ADM_PASS"; then
        echo ""
        echo -e "\033[38;5;${TEXT_MUTED}mUsar esta senha mesmo assim? (s/n)\033[0m"
        read -p "> " use_weak
        if [ "$use_weak" != "s" ] && [ "$use_weak" != "S" ]; then
            continue
        fi
    fi

    echo ""
    echo -e "\033[38;5;${TEXT_MUTED}mConfirme a senha:\033[0m"
    read -s CONFIRM_PASS
    echo ""

    if [ "$ADM_PASS" = "$CONFIRM_PASS" ] && [ -n "$ADM_PASS" ]; then
        break
    fi

    echo -e "\033[38;5;${ERROR}m✗ As senhas não conferem ou estão vazias. Tente novamente.\033[0m"
done

# 4. Confirmação Final com Tabela Detalhada
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}m▶ Resumo da Instalação\033[0m"
echo ""

create_card "Configurações" "Disco: $TARGET_DISK
Usuário: $ADM_USER
Hostname: nas-zfs
Filesystem: ZFS on Root (ZBM)
Pool ZFS: $POOL_NAME
Compressão: lz4
Modo: MOCKUP (Simulação)"

echo ""
info_box "⚠️  Este é um modo de simulação. Nenhuma alteração real será feita no sistema."
echo ""

echo -e "\033[38;5;${TEXT_MUTED}mConfirmar início da instalação? (s/n)\033[0m"
read -p "> " confirm
if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    exit 1
fi

# 5. Execução Técnica Simulada com Animações
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}m▶ Iniciando Instalação (Modo Simulação)\033[0m"
echo ""

# Etapa 1: Formatação
echo -e "\033[1;38;5;${HIGHLIGHT}mEtapa 1/6: Preparando Disco\033[0m"
echo ""
mock_format_disk "$TARGET_DISK"
success_box "Disco preparado com sucesso"
sleep 1

# Etapa 2: Pool ZFS
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}mEtapa 2/6: Criando Pool ZFS\033[0m"
echo ""
mock_create_zfs_pool
success_box "Pool ZFS criado com sucesso"
sleep 1

# Etapa 3: Montagem
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}mEtapa 3/6: Montando Sistema\033[0m"
echo ""
mock_mount_system
success_box "Sistema montado com sucesso"
sleep 1

# Etapa 4: Extração
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}mEtapa 4/6: Instalando Sistema Base\033[0m"
echo ""
mock_extract_system
success_box "Sistema base instalado"
sleep 1

# Etapa 5: Configuração
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}mEtapa 5/6: Configurando Sistema\033[0m"
echo ""
mock_configure_system
success_box "Sistema configurado"
sleep 1

# Etapa 6: Bootloader
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}mEtapa 6/6: Instalando Bootloader\033[0m"
echo ""
mock_install_bootloader
success_box "Bootloader instalado"
sleep 1

# Etapa 7: Finalização
logo_static
echo ""
echo -e "\033[1;38;5;${HIGHLIGHT}mFinalizando Instalação\033[0m"
echo ""
mock_chroot_finalize
success_box "Instalação finalizada"
sleep 1

# 6. Tela de Sucesso
logo_static
echo ""
create_card "Instalação Concluída" "✓ Sistema instalado com sucesso
✓ Usuário: $ADM_USER
✓ Hostname: nas-zfs
✓ Pool ZFS: $POOL_NAME

⚠️  MODO MOCKUP: Nenhuma alteração real foi feita

Dica: Para instalação real, use o script sem modo mockup"

echo ""

# Opções pós-instalação
echo -e "\033[38;5;${TEXT_MUTED}mSelecione uma opção:\033[0m"
echo ""
echo "1) 📋 Ver logs da instalação"
echo "2) 🔄 Reiniciar sistema (simulado)"
echo "3) 🚪 Sair"
echo ""
read -p "> " choice

case "$choice" in
1)
    show_logs
    ;;
2)
    animate_loading "Reiniciando sistema..." 3
    clear
    success_box "Sistema reiniciado (simulação)"
    ;;
3)
    clear
    echo -e "\033[1;38;5;${HIGHLIGHT}mObrigado por testar o Aurora Installer!\033[0m"
    ;;
esac

echo ""
pause
