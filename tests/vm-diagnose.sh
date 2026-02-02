#!/usr/bin/env bash
# =============================================================================
# vm-diagnose.sh
# =============================================================================
# Ferramenta de diagnóstico via qemu-guest-agent para executar comandos
# no guest sem necessidade de rede. Lista comandos disponíveis, executa
# comandos e verifica status do sistema.
# Requisitos: virsh, VM com qemu-guest-agent instalado
# Data: 2026-02-01
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly VM_NAME="${VM_NAME:-debian-zfs-test}"
readonly VIRSH_CONNECT="${VIRSH_CONNECT:-qemu:///session}"

# Cores
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Variáveis
VERBOSE=0
WATCH_MODE=0
WATCH_INTERVAL=5

# =============================================================================
# FUNÇÕES DE UTILIDADE
# =============================================================================

log_info() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
	echo -e "${CYAN}[STEP]${NC} $1"
}

log_debug() {
	if [[ ${VERBOSE} -eq 1 ]]; then
		echo -e "${BLUE}[DEBUG]${NC} $1"
	fi
}

log_success() {
	echo -e "${MAGENTA}[SUCCESS]${NC} $1"
}

# =============================================================================
# VERIFICAÇÕES
# =============================================================================

check_dependencies() {
	if ! command -v virsh &>/dev/null; then
		log_error "virsh não encontrado. Instale: sudo apt install libvirt-clients"
		exit 1
	fi
}

check_vm() {
	log_debug "Verificando VM '${VM_NAME}'..."

	if ! virsh --connect "${VIRSH_CONNECT}" list --all --name | grep -qx "${VM_NAME}"; then
		log_error "VM '${VM_NAME}' não encontrada!"
		exit 1
	fi

	if ! virsh --connect "${VIRSH_CONNECT}" list --name | grep -qx "${VM_NAME}"; then
		log_warn "VM '${VM_NAME}' não está rodando"
		log_info "Tentando iniciar..."
		virsh --connect "${VIRSH_CONNECT}" start "${VM_NAME}" 2>/dev/null || {
			log_error "Não foi possível iniciar a VM"
			exit 1
		}
		sleep 3
	fi
}

check_qemu_agent() {
	log_debug "Verificando qemu-guest-agent..."

	local result
	result=$(virsh --connect "${VIRSH_CONNECT}" qemu-agent-command \
		"${VM_NAME}" '{"execute": "guest-ping"}' 2>/dev/null) || {
		log_error "QEMU Guest Agent não está respondendo"
		log_info "Certifique-se de que o agente está instalado na VM"
		return 1
	}

	if echo "${result}" | grep -q '"return": {}'; then
		log_debug "QEMU Guest Agent está respondendo"
		return 0
	fi

	return 1
}

wait_for_agent() {
	log_step "Aguardando qemu-guest-agent..."

	local elapsed=0
	while [[ ${elapsed} -lt 30 ]]; do
		if check_qemu_agent &>/dev/null; then
			log_success "QEMU Guest Agent pronto!"
			return 0
		fi
		sleep 2
		elapsed=$((elapsed + 2))
		echo -n "."
	done
	echo

	log_error "Timeout aguardando qemu-guest-agent"
	return 1
}

# =============================================================================
# COMANDOS DISPONÍVEIS
# =============================================================================

list_commands() {
	log_step "Comandos disponíveis no QEMU Guest Agent"
	echo

	cat <<'EOF'
Comandos Padrão do QEMU Guest Agent:
  guest-ping                    Verifica se o agente está vivo
  guest-info                    Informações sobre o agente
  guest-shutdown                Desliga o guest
  guest-reboot                  Reinicia o guest
  guest-suspend-ram             Suspende para RAM
  guest-suspend-disk            Suspende para disco
  guest-fstrim                  Executa TRIM em filesystems
  guest-network-get-interfaces  Lista interfaces de rede
  guest-get-host-name           Retorna hostname
  guest-get-time                Retorna hora do guest
  guest-set-time                Define hora do guest
  guest-get-vcpus               Informações de CPUs
  guest-set-vcpus               Altera número de CPUs
  guest-get-memory-blocks       Informações de memória
  guest-set-memory-blocks       Altera memória
  guest-get-osinfo              Informações do sistema operacional
  guest-exec                    Executa comando no guest
  guest-exec-status             Status de execução
  guest-get-fsinfo              Informações de filesystems
  guest-get-disks               Informações de discos
  guest-get-users               Usuários logados
  guest-get-timezone            Timezone do guest
  guest-get-memory-block-info   Info de blocos de memória

Comandos de Diagnóstico do Script:
  ping              Testa comunicação com agente
  info              Informações do agente
  os                Informações do sistema operacional
  network           Informações de rede
  disks             Informações de discos
  fs                Informações de filesystems
  users             Usuários logados
  processes         Lista processos (ps aux)
  services          Status de serviços systemd
  dmesg             Mensagens do kernel
  journal           Logs do systemd
  cloud-init        Status do cloud-init
  ssh-status        Verifica se SSH está rodando
  memory            Uso de memória
  cpu               Uso de CPU
  all               Executa diagnóstico completo

EOF
}

# =============================================================================
# EXECUÇÃO DE COMANDOS
# =============================================================================

execute_agent_command() {
	local command="$1"
	shift
	local args="${*-}"

	log_debug "Executando: ${command}"

	local json_cmd="{\"execute\": \"${command}\"}"

	if [[ -n ${args} ]]; then
		json_cmd="{\"execute\": \"${command}\", \"arguments\": ${args}}"
	fi

	virsh --connect "${VIRSH_CONNECT}" qemu-agent-command "${VM_NAME}" "${json_cmd}" 2>/dev/null || {
		log_error "Falha ao executar comando: ${command}"
		return 1
	}
}

execute_guest_command() {
	local cmd="$1"
	local args="${2-}"

	log_debug "Executando no guest: ${cmd} ${args}"

	local arg_json="["
	if [[ -n ${args} ]]; then
		local first=1
		for arg in ${args}; do
			[[ ${first} -eq 0 ]] && arg_json+=", "
			arg_json+="\"${arg}\""
			first=0
		done
	fi
	arg_json+="]"

	local exec_cmd="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"${cmd}\", \"arg\": ${arg_json}, \"capture-output\": true}}"

	local result
	result=$(virsh --connect "${VIRSH_CONNECT}" qemu-agent-command "${VM_NAME}" "${exec_cmd}" 2>/dev/null) || {
		log_error "Falha ao iniciar comando"
		return 1
	}

	local pid
	pid=$(echo "${result}" | grep -oP '"pid": \K[0-9]+')
	[[ -z ${pid} ]] && return 1

	sleep 0.5

	local status
	status=$(virsh --connect "${VIRSH_CONNECT}" qemu-agent-command \
		"${VM_NAME}" "{\"execute\": \"guest-exec-status\", \"arguments\": {\"pid\": ${pid}}}" 2>/dev/null) || {
		log_error "Falha ao obter status"
		return 1
	}

	local exit_code
	exit_code=$(echo "${status}" | grep -oP '"exitcode": \K[0-9]+' || echo "unknown")

	local out_data
	out_data=$(echo "${status}" | grep -oP '"out-data": "\K[^"]+' || true)

	local err_data
	err_data=$(echo "${status}" | grep -oP '"err-data": "\K[^"]+' || true)

	if [[ -n ${out_data} ]]; then
		echo "${out_data}" | base64 -d 2>/dev/null || echo "${out_data}"
	fi

	if [[ -n ${err_data} ]]; then
		echo "[STDERR]:"
		echo "${err_data}" | base64 -d 2>/dev/null || echo "${err_data}"
	fi

	return "${exit_code:-0}"
}

# =============================================================================
# COMANDOS DE DIAGNÓSTICO
# =============================================================================

cmd_ping() {
	echo "Testando comunicação com QEMU Guest Agent..."
	if check_qemu_agent; then
		log_success "Comunicação OK!"
	else
		log_error "Sem comunicação"
		return 1
	fi
}

cmd_info() {
	log_step "Informações do Guest Agent"
	execute_agent_command "guest-info" | python3 -m json.tool 2>/dev/null ||
		execute_agent_command "guest-info"
}

cmd_os() {
	log_step "Informações do Sistema Operacional"
	local result
	result=$(execute_agent_command "guest-get-osinfo")
	echo "${result}" | python3 -m json.tool 2>/dev/null || echo "${result}"
}

cmd_network() {
	log_step "Interfaces de Rede"
	local result
	result=$(execute_agent_command "guest-network-get-interfaces")
	echo "${result}" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for iface in data.get('return', []):
        print(f\"Interface: {iface.get('name', 'unknown')}\")
        print(f\"  Hardware: {iface.get('hardware-address', 'N/A')}\")
        for ip in iface.get('ip-addresses', []):
            print(f\"  IP: {ip.get('ip-address', 'N/A')}/{ip.get('prefix', 'N/A')} ({ip.get('ip-address-type', 'N/A')})\")
        print()
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "${result}"
}

cmd_disks() {
	log_step "Informações de Discos"
	local result
	result=$(execute_agent_command "guest-get-disks")
	echo "${result}" | python3 -m json.tool 2>/dev/null || echo "${result}"
}

cmd_fs() {
	log_step "Filesystems"
	local result
	result=$(execute_agent_command "guest-get-fsinfo")
	echo "${result}" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for fs in data.get('return', []):
        print(f\"{fs.get('name', 'unknown')}: {fs.get('total-bytes', 0)//1024//1024}MB total, {fs.get('used-bytes', 0)//1024//1024}MB usado\")
        print(f\"  Mount: {fs.get('mountpoint', 'N/A')}, Type: {fs.get('type', 'N/A')}\")
        print()
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "${result}"
}

cmd_users() {
	log_step "Usuários Logados"
	local result
	result=$(execute_agent_command "guest-get-users")
	echo "${result}" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for user in data.get('return', []):
        print(f\"{user.get('user', 'unknown')} em {user.get('domain', 'local')} desde {user.get('login-time', 'N/A')}\")
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "${result}"
}

cmd_processes() {
	log_step "Processos em Execução"
	execute_guest_command "/bin/ps" "aux --sort=-%mem"
}

cmd_services() {
	log_step "Status de Serviços Systemd"
	execute_guest_command "/bin/systemctl" "list-units --type=service --state=running --no-pager --no-legend" | head -30
}

cmd_dmesg() {
	log_step "Mensagens do Kernel (dmesg)"
	execute_guest_command "/bin/dmesg" "--ctime --level=warn,err | tail -50"
}

cmd_journal() {
	log_step "Logs do Systemd"
	execute_guest_command "/bin/journalctl" "--no-pager -n 50 --output=short"
}

cmd_cloud_init() {
	log_step "Status do Cloud-Init"

	execute_guest_command "/bin/cat" "/run/cloud-init/status.json" 2>/dev/null || {
		log_warn "Arquivo de status não encontrado"
	}

	echo
	log_info "Resultado do cloud-init:"
	execute_guest_command "/bin/cat" "/run/cloud-init/result.json" 2>/dev/null || {
		log_warn "Arquivo de resultado não encontrado"
	}
}

cmd_ssh_status() {
	log_step "Status do SSH"
	execute_guest_command "/bin/systemctl" "status ssh --no-pager" 2>/dev/null ||
		execute_guest_command "/bin/systemctl" "status sshd --no-pager" 2>/dev/null || {
		log_warn "Serviço SSH não encontrado ou não está rodando"
	}
}

cmd_memory() {
	log_step "Uso de Memória"
	execute_guest_command "/bin/free" "-h"
}

cmd_cpu() {
	log_step "Uso de CPU"
	execute_guest_command "/bin/top" "-bn1 | head -20"
}

cmd_all() {
	log_step "Diagnóstico Completo"
	echo "======================================"

	cmd_ping
	echo
	cmd_os
	echo
	cmd_network
	echo
	cmd_memory
	echo
	cmd_fs
	echo
	cmd_services
	echo
	cmd_cloud_init 2>/dev/null || true

	echo "======================================"
	log_success "Diagnóstico completo finalizado"
}

# =============================================================================
# MODO WATCH
# =============================================================================

watch_mode() {
	log_info "Modo watch ativado (atualização a cada ${WATCH_INTERVAL}s)"
	log_info "Pressione Ctrl+C para sair"
	echo

	while true; do
		clear
		echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitoramento da VM: ${VM_NAME}"
		echo "================================================================"

		echo "MEMORY:"
		execute_guest_command "/bin/free" "-h" 2>/dev/null | head -2 || echo "N/A"

		echo
		echo "DISK USAGE:"
		execute_guest_command "/bin/df" "-h / /home" 2>/dev/null | head -3 || echo "N/A"

		echo
		echo "LOAD AVERAGE:"
		execute_guest_command "/bin/cat" "/proc/loadavg" 2>/dev/null | awk '{print "  1min:", $1, " 5min:", $2, " 15min:", $3}' || echo "N/A"

		echo
		echo "NETWORK INTERFACES:"
		local result
		result=$(execute_agent_command "guest-network-get-interfaces" 2>/dev/null)
		echo "${result}" | grep -oP '"ip-address": "\K[0-9.]+' | grep -v "^127\." | head -5 | sed 's/^/  /' || echo "  N/A"

		echo
		echo "================================================================"
		echo "Próxima atualização em ${WATCH_INTERVAL}s..."

		sleep "${WATCH_INTERVAL}"
	done
}

# =============================================================================
# FLUXO PRINCIPAL
# =============================================================================

main() {
	echo "================================================================"
	echo "  VM Diagnose - Diagnóstico via QEMU Guest Agent"
	echo "================================================================"
	echo

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		--verbose | -v)
			VERBOSE=1
			shift
			;;
		--watch | -w)
			WATCH_MODE=1
			[[ $2 =~ ^[0-9]+$ ]] && {
				WATCH_INTERVAL="$2"
				shift
			}
			shift
			;;
		--vm)
			VM_NAME="$2"
			shift 2
			;;
		list | commands | help)
			list_commands
			exit 0
			;;
		*)
			break
			;;
		esac
	done

	check_dependencies
	check_vm

	if ! check_qemu_agent; then
		wait_for_agent || exit 1
	fi

	if [[ ${WATCH_MODE} -eq 1 ]]; then
		watch_mode
		exit 0
	fi

	local command="${1:-all}"

	case "${command}" in
	ping) cmd_ping ;;
	info) cmd_info ;;
	os) cmd_os ;;
	network | net) cmd_network ;;
	disks | disk) cmd_disks ;;
	fs | filesystem) cmd_fs ;;
	users) cmd_users ;;
	processes | ps) cmd_processes ;;
	services) cmd_services ;;
	dmesg) cmd_dmesg ;;
	journal | logs) cmd_journal ;;
	cloud-init) cmd_cloud_init ;;
	ssh-status | ssh) cmd_ssh_status ;;
	memory | mem) cmd_memory ;;
	cpu) cmd_cpu ;;
	all | "") cmd_all ;;
	exec)
		shift
		if [[ $# -eq 0 ]]; then
			log_error "Comando não especificado para exec"
			echo "Uso: ${SCRIPT_NAME} exec <comando> [args...]"
			exit 1
		fi
		execute_guest_command "$@"
		;;
	*)
		log_error "Comando desconhecido: ${command}"
		log_info "Execute '${SCRIPT_NAME} list' para ver comandos disponíveis"
		exit 1
		;;
	esac
}

show_help() {
	cat <<EOF
Uso: ${SCRIPT_NAME} [OPÇÕES] [COMANDO]

Ferramenta de diagnóstico via QEMU Guest Agent. Permite executar
comandos no guest e obter informações do sistema sem necessidade de rede.

Variáveis de ambiente:
  VM_NAME              Nome da VM (padrão: debian-zfs-lab)
  VIRSH_CONNECT        URI de conexão (padrão: qemu:///session)

Opções:
  -h, --help                 Mostra esta ajuda
  -v, --verbose              Modo verbose
  -w, --watch [SEGUNDOS]     Modo monitor contínuo
      --vm NOME              Especifica nome da VM

Comandos de Diagnóstico:
  ping              Testa comunicação com agente
  info              Informações do guest agent
  os                Informações do SO
  network           Interfaces de rede
  disks             Informações de discos
  fs                Informações de filesystems
  users             Usuários logados
  processes         Lista processos
  services          Status de serviços
  dmesg             Mensagens do kernel
  journal           Logs do systemd
  cloud-init        Status do cloud-init
  ssh-status        Status do serviço SSH
  memory            Uso de memória
  cpu               Uso de CPU
  all               Diagnóstico completo (padrão)
  exec <cmd> [args] Executa comando arbitrário no guest
  list              Lista comandos disponíveis

Exemplos:
  ${SCRIPT_NAME}                    # Diagnóstico completo
  ${SCRIPT_NAME} network            # Info de rede
  ${SCRIPT_NAME} exec uname -a      # Executa comando
  ${SCRIPT_NAME} --watch 5          # Monitor a cada 5s

EOF
}

cleanup() {
	echo
	log_info "Encerrando..."
	exit 0
}

trap cleanup SIGINT SIGTERM

main "$@"
