#!/usr/bin/env bash
# =============================================================================
# vm-capture-logs.sh
# =============================================================================
# Captura logs de boot, cloud-init e sistema da VM via qemu-guest-agent.
# Salva em arquivos para análise e identifica erros comuns automaticamente.
# Requisitos: virsh, qemu-guest-agent na VM
# Data: 2026-02-01
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly VM_NAME="${VM_NAME:-debian-zfs-test}"
readonly VIRSH_CONNECT="${VIRSH_CONNECT:-qemu:///session}"

OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/vm-logs}"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly SESSION_DIR="${OUTPUT_DIR}/${VM_NAME}_${TIMESTAMP}"

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
ANALYZE=1
QUICK_MODE=0

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
		log_warn "VM não está rodando, tentando iniciar..."
		virsh --connect "${VIRSH_CONNECT}" start "${VM_NAME}" 2>/dev/null || {
			log_error "Não foi possível iniciar a VM"
			exit 1
		}
		sleep 3
	fi
}

# =============================================================================
# CAPTURA DE LOGS
# =============================================================================

setup_output_dir() {
	log_step "Configurando diretório de saída..."

	mkdir -p "${SESSION_DIR}"
	log_info "Logs serão salvos em: ${SESSION_DIR}"

	cat >"${SESSION_DIR}/capture-info.txt" <<EOF
Captura de Logs da VM
====================
VM Name: ${VM_NAME}
Timestamp: ${TIMESTAMP}
Host: $(hostname)
User: $(whoami)
Capture Script: ${SCRIPT_NAME}

VM Info:
$(virsh --connect "${VIRSH_CONNECT}" dominfo "${VM_NAME}" 2>/dev/null || echo "N/A")
EOF
}

execute_guest_command() {
	local cmd="$1"
	local args="${2-}"

	log_debug "Executando: ${cmd} ${args}"

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
		return 1
	}

	local pid=$(echo "${result}" | grep -oP '"pid": \K[0-9]+')
	[[ -z ${pid} ]] && return 1

	sleep 0.5

	local status
	status=$(virsh --connect "${VIRSH_CONNECT}" qemu-agent-command \
		"${VM_NAME}" "{\"execute\": \"guest-exec-status\", \"arguments\": {\"pid\": ${pid}}}" 2>/dev/null) || {
		return 1
	}

	local out_data
	out_data=$(echo "${status}" | grep -oP '"out-data": "\K[^"]+' || true)

	if [[ -n ${out_data} ]]; then
		echo "${out_data}" | base64 -d 2>/dev/null || echo "${out_data}"
	fi
}

capture_dmesg() {
	log_step "Capturando dmesg..."

	local output_file="${SESSION_DIR}/dmesg.log"

	if execute_guest_command "/bin/dmesg" "--ctime" >"${output_file}" 2>/dev/null; then
		local line_count
		line_count=$(wc -l <"${output_file}")
		log_success "dmesg capturado: ${line_count} linhas"
	else
		log_warn "Falha ao capturar dmesg"
	fi
}

capture_journal() {
	log_step "Capturando journalctl..."

	local output_file="${SESSION_DIR}/journalctl.log"

	if execute_guest_command "/bin/journalctl" "--no-pager --output=short-iso -b" >"${output_file}" 2>/dev/null; then
		local line_count
		line_count=$(wc -l <"${output_file}")
		log_success "journalctl capturado: ${line_count} linhas"
	else
		log_warn "Falha ao capturar journalctl"
	fi
}

capture_cloud_init() {
	log_step "Capturando logs do cloud-init..."

	local output_file="${SESSION_DIR}/cloud-init.log"
	if execute_guest_command "/bin/cat" "/var/log/cloud-init.log" >"${output_file}" 2>/dev/null; then
		local line_count
		line_count=$(wc -l <"${output_file}")
		log_success "cloud-init.log: ${line_count} linhas"
	else
		log_warn "cloud-init.log não disponível"
	fi

	output_file="${SESSION_DIR}/cloud-init-output.log"
	if execute_guest_command "/bin/cat" "/var/log/cloud-init-output.log" >"${output_file}" 2>/dev/null; then
		local line_count
		line_count=$(wc -l <"${output_file}")
		log_success "cloud-init-output.log: ${line_count} linhas"
	else
		log_warn "cloud-init-output.log não disponível"
	fi

	output_file="${SESSION_DIR}/cloud-init-status.json"
	if execute_guest_command "/bin/cat" "/run/cloud-init/status.json" >"${output_file}" 2>/dev/null; then
		log_success "cloud-init status capturado"
	else
		log_warn "cloud-init status não disponível"
	fi
}

capture_boot_log() {
	log_step "Capturando log de boot..."

	local output_file="${SESSION_DIR}/boot.log"

	if execute_guest_command "/bin/cat" "/var/log/boot.log" >"${output_file}" 2>/dev/null; then
		log_success "boot.log capturado"
	else
		if execute_guest_command "/bin/journalctl" "--no-pager -b -k" >"${output_file}" 2>/dev/null; then
			log_success "Log de boot (via journal) capturado"
		else
			log_warn "Não foi possível capturar log de boot"
		fi
	fi
}

capture_system_info() {
	log_step "Capturando informações do sistema..."

	local output_file="${SESSION_DIR}/system-info.txt"

	{
		echo "=== Informações do Sistema ==="
		echo "Data/Hora: $(date)"
		echo

		echo "=== VM Info ==="
		virsh --connect "${VIRSH_CONNECT}" dominfo "${VM_NAME}" 2>/dev/null || echo "N/A"
		echo

		echo "=== OS Info ==="
		virsh --connect "${VIRSH_CONNECT}" qemu-agent-command \
			"${VM_NAME}" '{"execute": "guest-get-osinfo"}' 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "N/A"
		echo

		echo "=== Hostname ==="
		execute_guest_command "/bin/hostname" "-f" 2>/dev/null || echo "N/A"
		echo

		echo "=== Uptime ==="
		execute_guest_command "/bin/cat" "/proc/uptime" 2>/dev/null || echo "N/A"
		echo

		echo "=== Kernel ==="
		execute_guest_command "/bin/uname" "-a" 2>/dev/null || echo "N/A"
		echo

		echo "=== Memória ==="
		execute_guest_command "/bin/free" "-h" 2>/dev/null || echo "N/A"
		echo

		echo "=== Disco ==="
		execute_guest_command "/bin/df" "-h" 2>/dev/null || echo "N/A"
		echo

		echo "=== Interfaces ==="
		execute_guest_command "/bin/ip" "addr" 2>/dev/null || echo "N/A"
		echo

		echo "=== Rotas ==="
		execute_guest_command "/bin/ip" "route" 2>/dev/null || echo "N/A"
		echo

		echo "=== Serviços Ativos ==="
		execute_guest_command "/bin/systemctl" "list-units --type=service --state=running --no-pager --no-legend | head -20" 2>/dev/null || echo "N/A"
		echo

		echo "=== Processos (top 20) ==="
		execute_guest_command "/bin/ps" "aux --sort=-%cpu | head -20" 2>/dev/null || echo "N/A"

	} >"${output_file}"

	log_success "Informações do sistema capturadas"
}

capture_network_info() {
	log_step "Capturando informações de rede..."

	local output_file="${SESSION_DIR}/network-info.txt"

	{
		echo "=== Interfaces (qemu-ga) ==="
		virsh --connect "${VIRSH_CONNECT}" qemu-agent-command \
			"${VM_NAME}" '{"execute": "guest-network-get-interfaces"}' 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "N/A"
		echo

		echo "=== Conexões ==="
		execute_guest_command "/bin/ss" "-tunap | head -30" 2>/dev/null || echo "N/A"

	} >"${output_file}"

	log_success "Informações de rede capturadas"
}

capture_service_status() {
	log_step "Capturando status de serviços..."

	local output_file="${SESSION_DIR}/services-status.txt"
	local services="ssh sshd cloud-init cloud-final qemu-guest-agent"

	{
		echo "=== Status de Serviços ==="
		echo "Data: $(date)"
		echo

		for service in ${services}; do
			echo "--- ${service} ---"
			execute_guest_command "/bin/systemctl" "status ${service} --no-pager 2>/dev/null" || echo "N/A"
			echo
		done

		echo "=== Serviços Falhos ==="
		execute_guest_command "/bin/systemctl" "list-units --failed --no-pager --no-legend" 2>/dev/null || echo "N/A"

	} >"${output_file}"

	log_success "Status de serviços capturado"
}

# =============================================================================
# ANÁLISE DE LOGS
# =============================================================================

analyze_logs() {
	[[ ${ANALYZE} -eq 0 ]] && return 0

	log_step "Analisando logs..."

	local report_file="${SESSION_DIR}/analysis-report.txt"
	local errors_found=0

	{
		echo "=== Análise de Logs ==="
		echo "Data: $(date)"
		echo

		local error_patterns="error|failed|failure|fatal|critical|segfault|oom|panic"
		local warning_patterns="warning|warn|deprecated|obsolete|not found|permission denied|timeout"

		echo "=== ERROS ==="
		echo

		for logfile in "${SESSION_DIR}"/*.log; do
			[[ -f ${logfile} ]] || continue

			local basename
			basename=$(basename "${logfile}")
			local errors_in_file=""

			errors_in_file=$(grep -i -E "${error_patterns}" "${logfile}" 2>/dev/null | head -20)

			if [[ -n ${errors_in_file} ]]; then
				echo "--- ${basename} ---"
				echo "${errors_in_file}"
				echo
				errors_found=$((errors_found + 1))
			fi
		done

		if [[ ${errors_found} -eq 0 ]]; then
			echo "Nenhum erro crítico encontrado!"
		fi

		echo
		echo "=== AVISOS ==="
		echo

		local warnings_found=0
		for logfile in "${SESSION_DIR}"/*.log; do
			[[ -f ${logfile} ]] || continue

			local basename
			basename=$(basename "${logfile}")
			local warnings_in_file=""

			warnings_in_file=$(grep -i -E "${warning_patterns}" "${logfile}" 2>/dev/null | grep -iv "${error_patterns}" | head -10)

			if [[ -n ${warnings_in_file} ]]; then
				echo "--- ${basename} ---"
				echo "${warnings_in_file}"
				echo
				warnings_found=$((warnings_found + 1))
			fi
		done

		if [[ ${warnings_found} -eq 0 ]]; then
			echo "Nenhum aviso significativo!"
		fi

		echo
		echo "=== Resumo ==="
		echo "Arquivos com erros: ${errors_found}"
		echo "Arquivos com avisos: ${warnings_found}"

	} >"${report_file}"

	log_success "Análise concluída: ${report_file}"

	echo
	echo "=== RESUMO ==="
	grep -A 20 "=== Resumo ===" "${report_file}"
}

# =============================================================================
# COMPACTAÇÃO
# =============================================================================

compress_logs() {
	log_step "Compactando logs..."

	local archive_name="${VM_NAME}_${TIMESTAMP}.tar.gz"
	local archive_path="${OUTPUT_DIR}/${archive_name}"

	if tar -czf "${archive_path}" -C "${OUTPUT_DIR}" "$(basename "${SESSION_DIR}")" 2>/dev/null; then
		local archive_size
		archive_size=$(du -h "${archive_path}" | cut -f1)
		log_success "Logs compactados: ${archive_name} (${archive_size})"
		echo "${archive_path}"
	else
		log_warn "Falha ao compactar logs"
	fi
}

# =============================================================================
# FLUXO PRINCIPAL
# =============================================================================

main() {
	echo "================================================================"
	echo "  VM Capture Logs - Captura e Análise de Logs"
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
		--quick | -q)
			QUICK_MODE=1
			shift
			;;
		--no-analyze)
			ANALYZE=0
			shift
			;;
		--output | -o)
			OUTPUT_DIR="$2"
			shift 2
			;;
		--vm)
			VM_NAME="$2"
			shift 2
			;;
		*)
			log_error "Opção desconhecida: $1"
			echo "Use --help para ver opções disponíveis"
			exit 1
			;;
		esac
	done

	check_dependencies
	check_vm
	setup_output_dir

	if [[ ${QUICK_MODE} -eq 1 ]]; then
		log_info "Modo rápido"
		capture_system_info
		capture_cloud_init 2>/dev/null || true
		capture_journal 2>/dev/null || true
	else
		capture_system_info
		capture_network_info
		capture_dmesg
		capture_journal
		capture_cloud_init
		capture_boot_log
		capture_service_status
	fi

	if [[ ${ANALYZE} -eq 1 ]]; then
		analyze_logs
	fi

	compress_logs

	echo
	log_success "Captura concluída!"
	log_info "Logs salvos em: ${SESSION_DIR}"
}

show_help() {
	cat <<EOF
Uso: ${SCRIPT_NAME} [OPÇÕES]

Captura logs da VM via QEMU Guest Agent para análise offline.

Variáveis de ambiente:
  VM_NAME              Nome da VM (padrão: debian-zfs-lab)
  VIRSH_CONNECT        URI de conexão (padrão: qemu:///session)
  OUTPUT_DIR           Diretório de saída (padrão: ./vm-logs)

Opções:
  -h, --help                 Mostra esta ajuda
  -v, --verbose              Modo verbose
  -q, --quick                Modo rápido
      --no-analyze           Não analisa logs
  -o, --output DIR           Diretório de saída
      --vm NOME              Nome da VM

Logs Capturados:
  - system-info.txt      Informações gerais
  - dmesg.log            Mensagens do kernel
  - journalctl.log       Logs do systemd
  - cloud-init.log       Log do cloud-init
  - network-info.txt     Configuração de rede
  - services-status.txt  Status de serviços
  - analysis-report.txt  Análise de erros

Exemplos:
  ${SCRIPT_NAME}                    # Captura completa
  ${SCRIPT_NAME} --quick            # Apenas essenciais
  ${SCRIPT_NAME} -o /tmp/logs       # Diretório customizado

EOF
}

cleanup() {
	echo
	log_info "Operação interrompida"
	exit 0
}

trap cleanup SIGINT SIGTERM

main "$@"
