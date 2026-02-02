#!/usr/bin/env bash
# =============================================================================
# vm-test.sh - Script Unificado para Teste de ISO e Sistema Instalado
# =============================================================================
#
# PROPÓSITO:
#   Este é o ÚNICO script necessário para testar a imagem ISO do projeto.
#   Suporta dois modos de operação:
#
#   1. MODO LIVE (padrão): Testa a ISO recém-criada pelo live-build
#      - Cria VM nova
#      - Faz boot pela ISO (CD-ROM)
#      - Permite testar o instalador e o sistema live
#
#   2. MODO INSTALLED: Testa o sistema após instalação
#      - Ejeta a ISO
#      - Faz boot pelo disco (sistema instalado)
#      - Permite validar o sistema instalado
#
# USO:
#   ./vm-test.sh              # Modo live (padrão)
#   ./vm-test.sh live         # Modo live (explícito)
#   ./vm-test.sh installed    # Modo installed (pós-instalação)
#   ./vm-test.sh --help       # Ajuda completa
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# VM Configuration
readonly VM_NAME="${VM_NAME:-debian-zfs-test}"
readonly VM_RAM="${VM_RAM:-4096}"
readonly VM_CPUS="${VM_CPUS:-4}"
readonly VM_DISK_SIZE="${VM_DISK_SIZE:-20}"
readonly VIRSH_CONNECT="qemu:///session"

# Paths
readonly ISO_PATH="${PROJECT_DIR}/live_build/live-image-amd64.hybrid.iso"
readonly DISK_PATH="${PROJECT_DIR}/${VM_NAME}.qcow2"

# Timing
readonly BOOT_WAIT_LIVE=45
readonly BOOT_WAIT_INSTALLED=30

# Interface Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# =============================================================================
# FUNÇÕES DE INTERFACE
# =============================================================================

print_header() {
	local mode="$1"
	clear
	echo
	echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"
	case "$mode" in
	live)
		echo -e "${BLUE}║${NC}  ${BOLD}${CYAN}🧪 TESTE DA ISO LIVE${NC}                                            ${BLUE}║${NC}"
		echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"
		echo -e "${BLUE}║${NC}  Boot pela ISO para testar o sistema live e o instalador        ${BLUE}║${NC}"
		;;
	installed)
		echo -e "${BLUE}║${NC}  ${BOLD}${CYAN}✅ TESTE DO SISTEMA INSTALADO${NC}                                 ${BLUE}║${NC}"
		echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"
		echo -e "${BLUE}║${NC}  Boot pelo disco para validar o sistema pós-instalação          ${BLUE}║${NC}"
		;;
	test-install)
		echo -e "${BLUE}║${NC}  ${BOLD}${CYAN}🤖 TESTE AUTOMATIZADO DO INSTALADOR${NC}                           ${BLUE}║${NC}"
		echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"
		echo -e "${BLUE}║${NC}  Executa install-system --auto via QEMU Guest Agent             ${BLUE}║${NC}"
		;;
	esac
	echo -e "${BLUE}║${NC}                                                                  ${BLUE}║${NC}"
	echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
	echo
}

print_step() {
	local step_num="$1"
	local total="$2"
	local step_msg="$3"
	echo -e "${CYAN}[${step_num}/${total}]${NC} ${step_msg}"
}

print_success() {
	echo -e "${GREEN}    ✓${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}    ⚠${NC} $1"
}

print_error() {
	echo -e "${RED}    ✗${NC} $1" >&2
}

print_info() {
	echo -e "${BLUE}    ℹ${NC} $1"
}

print_credentials() {
	echo -e "
			${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}
			${GREEN}║${NC}  ${BOLD}CREDENCIAIS DE ACESSO${NC}                                          ${GREEN}║${NC}
			${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}
			${GREEN}║${NC}                                                                  ${GREEN}║${NC}
			${GREEN}║${NC}   Usuário: ${BOLD}admin${NC}                                                 ${GREEN}║${NC}
			${GREEN}║${NC}   Senha:   ${BOLD}admin${NC}                                                 ${GREEN}║${NC}
			${GREEN}║${NC}                                                                  ${GREEN}║${NC}
			${GREEN}║${NC}   ${YELLOW}O login deve ser automático (autologin)${NC}                      ${GREEN}║${NC}
			${GREEN}║${NC}                                                                  ${GREEN}║${NC}
			${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}
			${GREEN}║${NC}  ${BOLD}COMO SAIR DO CONSOLE:${NC}                                          ${GREEN}║${NC}
			${GREEN}║${NC}                                                                  ${GREEN}║${NC}
			${GREEN}║${NC}   Pressione: ${BOLD}Ctrl + ]${NC} (Ctrl e colchete direito)                  ${GREEN}║${NC}
			${GREEN}║${NC}   Alternativa: ${BOLD}Ctrl + 5${NC}                                          ${GREEN}║${NC}
			${GREEN}║${NC}                                                                  ${GREEN}║${NC}
			${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}
			"
}

# =============================================================================
# VERIFICAÇÕES
# =============================================================================

check_dependencies() {
	print_step "1" "4" "Verificando dependências..."

	local missing=()

	command -v virsh &>/dev/null || missing+=("virsh (libvirt-clients)")
	command -v virt-install &>/dev/null || missing+=("virt-install (virtinst)")
	command -v qemu-system-x86_64 &>/dev/null || missing+=("qemu-system-x86_64 (qemu-system-x86)")
	command -v script &>/dev/null || missing+=("script (bsdutils)")
	command -v jq &>/dev/null || missing+=("jq")

	if [[ ${#missing[@]} -gt 0 ]]; then
		print_error "Dependências ausentes!"
		echo -e "

		    Instale com:
		    ${CYAN}sudo apt install libvirt-clients virtinst qemu-system-x86 bsdutils${NC}
		
		"
		exit 1
	fi

	print_success "Todas as dependências instaladas"
}

check_iso_exists() {
	print_step "2" "4" "Verificando ISO..."

	if [[ ! -f $ISO_PATH ]]; then
		print_error "ISO não encontrada!"
		echo -e "
			Caminho esperado: $ISO_PATH
		
		    Para criar a ISO, execute:
		    ${CYAN}./build-live.sh${NC}
			
			"
		exit 1
	fi

	local iso_size
	iso_size=$(du -h "$ISO_PATH" | cut -f1)
	print_success "ISO encontrada ($iso_size)"
}

check_vm_exists() {
	virsh --connect "$VIRSH_CONNECT" list --all --name 2>/dev/null | grep -qx "$VM_NAME"
}

check_vm_running() {
	virsh --connect "$VIRSH_CONNECT" list --name 2>/dev/null | grep -qx "$VM_NAME"
}

check_disk_exists() {
	[[ -f $DISK_PATH ]]
}

# =============================================================================
# MODO LIVE - Teste da ISO
# =============================================================================

mode_live() {
	print_header "live"

	check_dependencies
	check_iso_exists

	# Preparar ambiente
	print_step "3" "4" "Preparando ambiente..."

	if check_vm_exists; then
		print_info "Removendo VM anterior..."
		virsh --connect "$VIRSH_CONNECT" destroy "$VM_NAME" 2>/dev/null || true
		virsh --connect "$VIRSH_CONNECT" undefine "$VM_NAME" --nvram 2>/dev/null || true
		print_success "VM anterior removida"
	fi

	if check_disk_exists; then
		rm -f "$DISK_PATH"
		print_success "Disco anterior removido"
	fi

	# Criar VM
	print_step "4" "4" "Criando VM e iniciando boot pela ISO..."
	echo
	print_info "Configuração:"
	echo "        Nome: $VM_NAME"
	echo "        RAM: ${VM_RAM}MB | CPUs: $VM_CPUS | Disco: ${VM_DISK_SIZE}GB"
	echo

	virt-install \
		--connect "$VIRSH_CONNECT" \
		--name "$VM_NAME" \
		--memory "$VM_RAM" \
		--vcpus "$VM_CPUS" \
		--boot uefi,loader_secure=no,cdrom,hd \
		--disk "path=$DISK_PATH,size=$VM_DISK_SIZE,format=qcow2,bus=virtio" \
		--cdrom "$ISO_PATH" \
		--os-variant debian12 \
		--network user,model=virtio \
		--graphics none \
		--serial pty \
		--console pty,target_type=serial \
		--channel unix,mode=bind,target_type=virtio,name=org.qemu.guest_agent.0 \
		--noautoconsole \
		--quiet

	print_success "VM criada e iniciada"

	# Se chamado com "no_console", retorna aqui (usado pelo modo de teste automatizado)
	if [[ ${1-} == "no_console" ]]; then
		return 0
	fi

	# Aguardar boot
	wait_for_boot "$BOOT_WAIT_LIVE"

	# Conectar
	connect_to_console
}

# =============================================================================
# MODO INSTALLED - Teste pós-instalação
# =============================================================================

mode_installed() {
	print_header "installed"

	check_dependencies

	# Verificar se VM existe
	print_step "1" "3" "Verificando VM existente..."

	if ! check_vm_exists; then
		print_error "VM '$VM_NAME' não encontrada!"
		echo
		echo "    Para testar o sistema instalado, primeiro você precisa:"
		echo -e "    1. Executar o modo live: ${CYAN}./vm-test.sh live${NC}"
		echo "    2. Realizar a instalação do sistema"
		echo -e "    3. Depois executar: ${CYAN}./vm-test.sh installed${NC}"
		exit 1
	fi

	if ! check_disk_exists; then
		print_error "Disco da VM não encontrado!"
		echo "    Caminho esperado: $DISK_PATH"
		exit 1
	fi

	local disk_size
	disk_size=$(du -h "$DISK_PATH" | cut -f1)
	print_success "VM encontrada (disco: $disk_size)"

	# Parar VM se estiver rodando
	print_step "2" "3" "Preparando boot pelo disco..."

	if check_vm_running; then
		print_info "Parando VM..."
		virsh --connect "$VIRSH_CONNECT" destroy "$VM_NAME" 2>/dev/null || true
		sleep 2
	fi

	# Ejetar ISO
	local iso_dev
	iso_dev=$(virsh --connect "$VIRSH_CONNECT" domblklist "$VM_NAME" 2>/dev/null | grep "\.iso" | awk '{print $1}' || true)

	if [[ -n $iso_dev ]]; then
		print_info "Ejetando ISO do dispositivo $iso_dev..."
		virsh --connect "$VIRSH_CONNECT" change-media "$VM_NAME" "$iso_dev" --eject --config 2>/dev/null || true
	fi

	print_success "Configurado para boot pelo disco"

	# Iniciar VM
	print_step "3" "3" "Iniciando sistema instalado..."

	virsh --connect "$VIRSH_CONNECT" start "$VM_NAME" 2>/dev/null
	print_success "VM iniciada"

	# Aguardar boot
	wait_for_boot "$BOOT_WAIT_INSTALLED"

	# Conectar
	connect_to_console
}

# =============================================================================
# MODO TEST-INSTALL - Automação via QEMU Guest Agent
# =============================================================================

vm_exec() {
	local cmd="$1"
	local timeout="${2:-30}"

	# Construir payload JSON para guest-exec
	local payload
	payload=$(jq -n --arg cmd "$cmd" '{execute:"guest-exec", arguments:{path:"/bin/bash", arg:["-c", $cmd], "capture-output":true}}')

	local out
	out=$(virsh --connect "$VIRSH_CONNECT" qemu-agent-command "$VM_NAME" "$payload" 2>/dev/null)
	local ret=$?

	if [[ $ret -ne 0 ]]; then return 1; fi

	local pid
	pid=$(echo "$out" | jq -r '.return.pid')

	if [[ $pid == "null" ]]; then return 1; fi

	# Polling status
	local start_time=$(date +%s)
	while true; do
		local check
		check=$(virsh --connect "$VIRSH_CONNECT" qemu-agent-command "$VM_NAME" "{\"execute\":\"guest-exec-status\", \"arguments\":{\"pid\":$pid}}")

		local exited
		exited=$(echo "$check" | jq -r '.return.exited')

		if [[ $exited == "true" ]]; then
			local b64
			b64=$(echo "$check" | jq -r '.return."out-data"')
			if [[ $b64 != "null" ]]; then
				echo "$b64" | base64 -d
			fi

			local exitcode
			exitcode=$(echo "$check" | jq -r '.return.exitcode')
			return "$exitcode"
		fi

		local current_time=$(date +%s)
		if ((current_time - start_time > timeout)); then
			return 124 # timeout
		fi

		sleep 1
	done
}

wait_for_agent() {
	print_step "4" "6" "Aguardando QEMU Guest Agent..."
	local max_attempts=150
	local attempt=0

	# Pequena espera inicial para o qemu processar o boot
	sleep 5

	while ((attempt < max_attempts)); do
		if virsh --connect "$VIRSH_CONNECT" qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' &>/dev/null; then
			print_success "Agente detectado!"
			return 0
		fi
		echo -n "."
		sleep 2
		((attempt++))
	done

	print_error "Timeout aguardando agente guest."
	return 1
}

mode_test_install() {
	print_header "test-install"
	check_dependencies

	echo -e "${YELLOW}Este modo é para agentes LLM ou testes automatizados.${NC}"
	echo -e "${YELLOW}Para teste interativo manual, use: ./vm-test.sh live${NC}"
	echo

	# 1. Start Live VM (sem conectar console)
	mode_live "no_console"

	# 2. Aguardar Agente
	wait_for_agent

	# 3. Inject updated install-system
	print_step "5" "6" "Injetando versão atualizada do install-system..."
	local local_script="${PROJECT_DIR}/live_config/config/includes.chroot/usr/local/bin/install-system"

	if [[ -f $local_script ]]; then
		# Compress and encode to avoid size limits and shell escaping issues
		# Using gzip then base64 (w0 to remove newlines)
		local payload_b64
		payload_b64=$(gzip -c "$local_script" | base64 -w0)

		# Upload and extract in one go
		# We assume the payload fits in the command line (usually 128KB+ is fine for 30KB script gzipped)
		if vm_exec "echo '$payload_b64' | base64 -d | gunzip > /usr/local/bin/install-system" 20; then
			vm_exec "chmod +x /usr/local/bin/install-system" 5
			print_success "Script atualizado injetado com sucesso."
		else
			print_error "Falha ao injetar script atualizado."
			return 1
		fi
	else
		print_warning "Script local não encontrado ($local_script), usando versão da ISO."
	fi

	# 4. Disparando instalação automática...
	print_step "5" "6" "Disparando instalação automática..."
	sleep 2

	# 5. Trigger Install (Async - nohup)

	# Usamos nohup para garantir que continue rodando
	vm_exec "nohup install-system --auto > /dev/null 2>&1 &" 10

	# 5. Monitor Log
	print_step "6" "6" "Monitorando instalação..."
	echo "    (Pressione Ctrl+C para cancelar - a VM continuará rodando)"
	echo
	echo -e "${YELLOW}--- LOG START ---${NC}"

	local success=false
	local failure=false

	# Loop de monitoramento (timeout 20 min)
	local start_time=$(date +%s)
	local timeout=1200

	while true; do
		# Ler logs novos
		local log_content
		# Ler ultimas 50 linhas
		log_content=$(vm_exec "tail -n 50 /var/log/install-system.log" 5)

		# Check Success Marker via guest agent
		if vm_exec "test -f /var/log/install-success" 5; then
			success=true
			break
		fi

		# Check explicit failure (if log contains ERRO or FALHA)
		if echo "$log_content" | grep -qiE "(ERRO|FALHA|ERROR|FAIL)"; then
			failure=true
			# Não sair imediatamente - continuar monitorando para capturar log completo
		fi

		# Show log (simplified)
		echo -e "$log_content" | tail -n 5

		local current_time=$(date +%s)
		if ((current_time - start_time > timeout)); then
			print_error "Timeout na instalação!"
			failure=true
			break
		fi

		# Se detectou falha, dar mais alguns segundos para capturar logs e sair
		if [[ $failure == true ]]; then
			sleep 3
			break
		fi

		sleep 5
	done

	echo -e "${YELLOW}--- LOG END ---${NC}"
	echo

	if [[ $success == true ]]; then
		print_success "Instalação concluída com sucesso!"

		# Dump full log to host for review
		local full_log
		full_log=$(vm_exec "cat /var/log/install-system.log" 60)
		echo "$full_log" >"install-system-latest.log"
		print_info "Log completo salvo em install-system-latest.log"

		return 0
	else
		print_error "Instalação falhou ou timeout."
		exit 1
	fi
}

# =============================================================================
# FUNÇÕES COMPARTILHADAS
# =============================================================================

wait_for_boot() {
	local wait_time="$1"

	echo
	echo -n "    Aguardando sistema inicializar "

	local elapsed=0
	while [[ $elapsed -lt $wait_time ]]; do
		echo -n "."
		sleep 1
		elapsed=$((elapsed + 1))
	done

	echo " OK!"
}

connect_to_console() {
	print_credentials

	echo -e "${BOLD}Conectando ao console em 3 segundos...${NC}"
	sleep 3

	echo
	echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
	echo -e "${YELLOW}  VOCÊ ESTÁ ENTRANDO NO SISTEMA LINUX${NC}"
	echo -e "${YELLOW}  Se a tela estiver em branco, pressione ENTER${NC}"
	echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
	echo

	# Usa 'script' para criar pseudo-TTY
	exec script -q -c "virsh --connect $VIRSH_CONNECT console $VM_NAME" /dev/null
}

# =============================================================================
# COMANDOS AUXILIARES
# =============================================================================

cmd_status() {
	echo
	echo -e "${BOLD}Status da VM de Teste${NC}"
	echo "─────────────────────────────────────"

	if check_vm_exists; then
		local state
		state=$(virsh --connect "$VIRSH_CONNECT" domstate "$VM_NAME" 2>/dev/null || echo "desconhecido")

		echo -e "Nome:   ${CYAN}$VM_NAME${NC}"
		echo -e "Estado: ${GREEN}$state${NC}"

		if check_disk_exists; then
			local disk_size
			disk_size=$(du -h "$DISK_PATH" 2>/dev/null | cut -f1)
			echo -e "Disco:  $disk_size"
		fi

		# Mostra se tem ISO anexada
		local iso_attached
		iso_attached=$(virsh --connect "$VIRSH_CONNECT" domblklist "$VM_NAME" 2>/dev/null | grep "\.iso" || true)
		if [[ -n $iso_attached ]]; then
			echo -e "ISO:    ${GREEN}Anexada${NC}"
		else
			echo -e "ISO:    ${YELLOW}Não anexada (boot pelo disco)${NC}"
		fi
	else
		echo -e "VM:     ${YELLOW}Não existe${NC}"
		echo
		echo "Para criar a VM, execute:"
		echo -e "  ${CYAN}./vm-test.sh live${NC}"
	fi
	echo
}

cmd_stop() {
	echo "Parando VM..."
	if virsh --connect "$VIRSH_CONNECT" destroy "$VM_NAME" 2>/dev/null; then
		print_success "VM parada"
	else
		print_warning "VM não estava rodando ou não existe"
	fi
}

cmd_remove() {
	echo "Removendo VM completamente..."

	virsh --connect "$VIRSH_CONNECT" destroy "$VM_NAME" 2>/dev/null || true
	virsh --connect "$VIRSH_CONNECT" undefine "$VM_NAME" --nvram 2>/dev/null || true
	rm -f "$DISK_PATH"

	print_success "VM removida completamente"
}

cmd_connect() {
	if ! check_vm_running; then
		print_error "VM não está rodando!"
		echo
		echo "Para iniciar a VM, execute:"
		echo -e "  ${CYAN}./vm-test.sh live${NC}      # Para testar a ISO"
		echo -e "  ${CYAN}./vm-test.sh installed${NC} # Para testar o sistema instalado"
		exit 1
	fi

	print_credentials
	exec script -q -c "virsh --connect $VIRSH_CONNECT console $VM_NAME" /dev/null
}

show_help() {
	echo -e "
${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}
${BOLD}║              VM-TEST - Script Unificado de Teste                 ║${NC}
${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}

${BOLD}USO:${NC}
    $SCRIPT_NAME [MODO|COMANDO]

${BOLD}MODOS DE OPERAÇÃO:${NC}

    ${CYAN}live${NC}        Testa a ISO recém-criada (padrão)
                - Cria uma nova VM
                - Faz boot pela ISO (CD-ROM)
                - Use para testar o sistema live e o instalador

    ${CYAN}installed${NC}   Testa o sistema após instalação
                - Ejeta a ISO e faz boot pelo disco
                - Use após instalar o sistema pelo modo live

    ${CYAN}test-install${NC} Tenta realizar a instalação automaticamente
                - Inicia modo live
                - Espera QEMU Agent
                - Executa install-system --auto
                - Monitora logs


${BOLD}COMANDOS AUXILIARES:${NC}

    ${CYAN}--status${NC}    Mostra status da VM
    ${CYAN}--stop${NC}      Para a VM
    ${CYAN}--remove${NC}    Remove a VM completamente
    ${CYAN}--connect${NC}   Reconecta ao console de uma VM rodando
    ${CYAN}--help${NC}      Mostra esta ajuda

${BOLD}EXEMPLOS:${NC}

    # Testar a ISO recém-criada
    $SCRIPT_NAME live

    # Testar sistema instalado (após instalar pela ISO)
    $SCRIPT_NAME installed

    # Ver status
    $SCRIPT_NAME --status

    # Reconectar ao console
    $SCRIPT_NAME --connect

${BOLD}FLUXO TÍPICO DE TESTE:${NC}

    1. Construir a ISO:
       ${CYAN}./build-live.sh${NC}

    2. Testar a ISO (modo live):
       ${CYAN}./tests/vm-test.sh live${NC}

    3. Dentro da VM, executar o instalador:
       ${CYAN}sudo aurora-installer${NC}

    4. Após instalação, sair do console:
       ${CYAN}Ctrl + ]${NC}

    5. Testar o sistema instalado:
       ${CYAN}./tests/vm-test.sh installed${NC}

${BOLD}CREDENCIAIS:${NC}
    Usuário: admin
    Senha:   admin

${BOLD}COMO SAIR DO CONSOLE:${NC}
    Pressione Ctrl+] (ou Ctrl+5)
"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
	local command="${1:-live}"

	case "$command" in
	live | --live | -l)
		mode_live
		;;
	installed | --installed | -i | disk | system)
		mode_installed
		;;
	test-install | --test | test | auto)
		mode_test_install
		;;

	--status | status | -s)
		cmd_status
		;;
	--stop | stop)
		cmd_stop
		;;
	--remove | remove | --delete | delete)
		cmd_remove
		;;
	--connect | connect | -c)
		cmd_connect
		;;
	--help | -h | help)
		show_help
		;;
	*)
		print_error "Comando desconhecido: $command"
		echo
		echo "Use ${CYAN}$SCRIPT_NAME --help${NC} para ver opções disponíveis"
		exit 1
		;;
	esac
}

# Tratamento de sinais
trap 'echo; echo "Interrompido pelo usuário"; exit 0' SIGINT SIGTERM

# Executa
main "$@"
