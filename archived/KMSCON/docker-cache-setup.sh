#!/bin/bash
# =============================================================================
# Script de Setup Docker Cache para KMSCON
# =============================================================================
# Descrição: Configura volumes e permissões para cache multi-camada do kmscon
# Autor: AURORA NAS Project
# Versão: 1.0.0
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"

# Cores
if [[ -t 2 ]]; then
	readonly COLOR_RESET='\033[0m'
	readonly COLOR_RED='\033[0;31m'
	readonly COLOR_GREEN='\033[0;32m'
	readonly COLOR_YELLOW='\033[0;33m'
	readonly COLOR_BLUE='\033[0;34m'
	readonly COLOR_BOLD='\033[1m'
else
	readonly COLOR_RESET=''
	readonly COLOR_RED=''
	readonly COLOR_GREEN=''
	readonly COLOR_YELLOW=''
	readonly COLOR_BLUE=''
	readonly COLOR_BOLD=''
fi

# Configurações padrão
readonly DEFAULT_CACHE_DIR="/var/cache/kmscon"
readonly DEFAULT_VOLUME_NAME="kmscon-cache"
readonly DEFAULT_HOST_CACHE_DIR="${HOME}/.cache/kmscon-build"

# =============================================================================
# FUNÇÕES DE LOGGING
# =============================================================================

log_info() {
	printf "%b[INFO]%b %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$1" >&2
}

log_warn() {
	printf "%b[WARN]%b %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$1" >&2
}

log_error() {
	printf "%b[ERROR]%b %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$1" >&2
}

log_debug() {
	[[ ${DEBUG:-0} -eq 1 ]] && printf "%b[DEBUG]%b %s\n" "${COLOR_BLUE}" "${COLOR_RESET}" "$1" >&2
}

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO
# =============================================================================

check_docker_installed() {
	if ! command -v docker &>/dev/null; then
		log_error "Docker não encontrado. Instale o Docker primeiro:"
		log_error "  curl -fsSL https://get.docker.com | sh"
		return 1
	fi

	# Check if docker daemon is running
	if ! docker info &>/dev/null; then
		log_error "Docker daemon não está rodando ou usuário não tem permissões"
		log_error "Tente: sudo systemctl start docker"
		return 1
	fi

	log_info "Docker encontrado: $(docker --version)"
	return 0
}

check_docker_compose() {
	if command -v docker-compose &>/dev/null; then
		log_info "Docker Compose encontrado: $(docker-compose --version)"
		return 0
	elif docker compose version &>/dev/null; then
		log_info "Docker Compose plugin encontrado"
		return 0
	else
		log_warn "Docker Compose não encontrado. Será necessário para docker-compose.cache.yml"
		return 1
	fi
}

check_disk_space() {
	local required_gb="${1:-5}"
	local cache_dir="${2:-${DEFAULT_CACHE_DIR}}"

	log_info "Verificando espaço em disco (mínimo: ${required_gb}GB)..."

	# Get available space in KB
	local available_kb
	if [[ -d ${cache_dir} ]]; then
		available_kb=$(df -k "${cache_dir}" | awk 'NR==2 {print $4}')
	else
		# Check parent directory
		local parent
		parent=$(dirname "${cache_dir}")
		available_kb=$(df -k "${parent}" | awk 'NR==2 {print $4}')
	fi

	local available_gb=$((available_kb / 1024 / 1024))

	if [[ ${available_gb} -lt ${required_gb} ]]; then
		log_error "Espaço em disco insuficiente: ${available_gb}GB disponível, ${required_gb}GB necessário"
		return 1
	fi

	log_info "Espaço em disco: ${available_gb}GB disponível"
	return 0
}

# =============================================================================
# FUNÇÕES DE SETUP
# =============================================================================

setup_volume_named() {
	local volume_name="${1:-${DEFAULT_VOLUME_NAME}}"

	log_info "Configurando volume nomeado Docker: ${volume_name}"

	# Check if volume exists
	if docker volume inspect "${volume_name}" &>/dev/null; then
		log_info "Volume '${volume_name}' já existe"
	else
		log_info "Criando volume Docker: ${volume_name}"
		docker volume create "${volume_name}" || {
			log_error "Falha ao criar volume Docker"
			return 1
		}
	fi

	# Show volume info
	log_info "Informações do volume:"
	docker volume inspect "${volume_name}" --format '  - Mountpoint: {{.Mountpoint}}' || true
	docker volume inspect "${volume_name}" --format '  - Tamanho: {{.Options.size}}' 2>/dev/null || true

	return 0
}

setup_host_cache_dir() {
	local cache_dir="${1:-${DEFAULT_HOST_CACHE_DIR}}"

	log_info "Configurando diretório de cache no host:${$cache_di}r"

	# Create directory structure
	mkdir -p "${cache_dir}"/{sources/{kmscon,libtsm},build,packages,deps/apt-cache,lock}

	# Set permissions (allow all users to read/write for Docker compatibility)
	chmod -R 777 "${cache_dir}" 2>/dev/null || {
		log_warn "Não foi possível ajustar permissões. Pode ser necessário sudo."
	}

	log_info "Estrutura de cache criada:"
	find "${cache_dir}" -maxdepth 2 -type d | sed 's/^/  /'

	return 0
}

setup_permissions() {
	local cache_dir="$1"
	local uid="${2:-$(id -u)}"
	local gid="${3:-$(id -g)}"

	log_info "Configurando permissões (UID${$ui}d, GID${$gi}d)..."

	if [[ ${EUID} -eq 0 ]]; then
		# Running as root, can set ownership
		chown -R "${uid}:${gid}" "${cache_dir}" 2>/dev/null || {
			log_warn "Não foi possível alterar ownership"
		}
	else
		# Not root, just ensure directory is writable
		chmod -R u+rwx "${cache_dir}" 2>/dev/null || true
	fi

	# Verify write access
	if [[ -w ${cache_dir} ]]; then
		log_info "Permissões configuradas com sucesso"
		return 0
	else
		log_error "Sem permissão de escrita em:${$cache_di}r"
		return 1
	fi
}

# =============================================================================
# FUNÇÕES DE PRÉ-VALIDAÇÃO
# =============================================================================

prevalidate_environment() {
	log_info "=== Pré-validação do Ambiente Docker ==="

	local errors=0

	# Check Docker
	if ! check_docker_installed; then
		((errors++))
	fi

	# Check Docker Compose (optional)
	check_docker_compose || true

	# Check disk space
	if ! check_disk_space 5; then
		((errors++))
	fi

	# Check for potential permission issues
	if [[ ${EUID} -ne 0 ]] && ! groups | grep -qE 'docker|sudo'; then
		log_warn "Usuário não está no grupo 'docker'. Pode ser necessário sudo."
	fi

	if [[ ${errors} -gt 0 ]]; then
		log_error "Pré-validação falhou c${m $err}ors erro(s)"
		return 1
	fi

	log_info "Pré-validação concluída com sucesso"
	return 0
}

# =============================================================================
# FUNÇÕES DE LIMPEZA
# =============================================================================

cleanup_cache() {
	local cache_dir="${1:-${DEFAULT_CACHE_DIR}}"
	local volume_name="${2:-${DEFAULT_VOLUME_NAME}}"
	local mode="${3:-soft}"

	log_info "=== Limpando Cache (${mode}) ==="

	case "${mode}" in
	soft)
		log_info "Removendo apenas pacotes .deb antigos..."
		if [[ -d "${cache_dir}/packages" ]]; then
			find "${cache_dir}/packages" -name "*.deb" -mtime +30 -delete 2>/dev/null || true
			log_info "Pacotes antigos removidos"
		fi
		;;
	hard)
		log_info "Removendo todo o conteúdo do cache..."
		if [[ -d ${cache_dir} ]]; then
			rm -rf "${cache_dir:?}"/*
			log_info "Cache limpo"
		fi
		;;
	volume)
		log_info "Removendo volume Docker..."
		docker volume rm "${volume_name}" 2>/dev/null || {
			log_warn "Volume não encontrado ou em uso"
		}
		;;
	all)
		log_info "Removendo tudo (diretório + volume)..."
		rm -rf "${cache_dir:?}" 2>/dev/null || true
		docker volume rm "${volume_name}" 2>/dev/null || true
		log_info "Tudo removido"
		;;
	esac

	return 0
}

# =============================================================================
# FUNÇÕES DE STATUS
# =============================================================================

show_status() {
	local cache_dir="${1:-${DEFAULT_CACHE_DIR}}"
	local volume_name="${2:-${DEFAULT_VOLUME_NAME}}"

	log_info "=== Status do Cache KMSCON ==="

	# Host directory
	echo ""
	echo "Diretório de cache no host:"
	if [[ -d ${cache_dir} ]]; then
		echo "  Local: ${cache_dir}"
		echo "  Tamanho: $(du -sh "${cache_dir}" 2>/dev/null | cut -f1 || echo 'N/A')"
		echo "  Conteúdo:"
		find "${cache_dir}" -maxdepth 2 -type f -exec ls -lh {} \; 2>/dev/null | sed 's/^/    /' || echo '    (vazio)'
	else
		echo "  Não configurado"
	fi

	# Docker volume
	echo ""
	echo "Volume Docker:"
	if docker volume inspect "${volume_name}" &>/dev/null; then
		docker volume inspect "${volume_name}" | sed 's/^/  /'
	else
		echo "  Não criado"
	fi

	# Manifest
	echo ""
	echo "Manifesto:"
	local manifest="${cache_dir}/manifest.json"
	if [[ -f ${manifest} ]]; then
		echo "  Local: ${manifest}"
		echo "  Entradas:"
		jq -r '.entries | keys[]' "${manifest}" 2>/dev/null | sed 's/^/    - /' || echo '    (vazio)'
	else
		echo "  Não encontrado"
	fi

	return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

show_usage() {
	cat <<EOF
Uso: ${SCRIPT_NAME} [COMANDO] [OPÇÕES]

Script de setup Docker Cache para KMSCON

COMANDOS:
    setup              Configura cache completo (padrão)
    setup-volume       Configura apenas volume Docker nomeado
    setup-host         Configura apenas diretório de cache no host
    validate           Pré-valida ambiente
    cleanup [modo]     Limpa cache (soft|hard|volume|all)
    status             Mostra status do cache
    help               Mostra esta ajuda

OPÇÕES:
    -d, --cache-dir    Diretório de cache (padrão${ $DEFAULT_HOST_CACHE_D}IR)
    -v, --volume       Nome do volume Docker (padrão:${$DEFAULT_VOLUME_NAM}E)
    -u, --uid          UID para permissões (padrão: atual)
    -g, --gid          GID para permissões (padrão: atual)
    --debug            Modo debug verboso

EXEMPLOS:
    # Setup completo
    ${SCRIPT_NAME} setup

    # Usar diretório específico
    ${SCRIPT_NAME} setup -d /mnt/cache/kmscon

    # Apenas validar ambiente
    ${SCRIPT_NAME} validate

    # Limpar cache antigo
    ${SCRIPT_NAME} cleanup soft

    # Ver status
    ${SCRIPT_NAME} status

EOF
}

main() {
	local command="${1:-setup}"
	local cache_dir="${DEFAULT_HOST_CACHE_DIR}"
	local volume_name="${DEFAULT_VOLUME_NAME}"
	local uid=""
	local gid=""

	# Parse arguments
	shift || true
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-d | --cache-dir)
			cache_dir="$2"
			shift 2
			;;
		-v | --volume)
			volume_name="$2"
			shift 2
			;;
		-u | --uid)
			uid="$2"
			shift 2
			;;
		-g | --gid)
			gid="$2"
			shift 2
			;;
		--debug)
			DEBUG=1
			shift
			;;
		-h | --help)
			show_usage
			exit 0
			;;
		*)
			# Pass through to command
			break
			;;
		esac
	done

	# Default UID/GID if not specified
	uid="${uid:-$(id -u)}"
	gid="${gid:-$(id -g)}"

	log_info "================================================"
	log_info "KMSCON Docker Cache Setup v${SCRIPT_VERSION}"
	log_info "================================================"
	log_info "Cache Dir: ${cache_dir}"
	log_info "Volume: ${volume_name}"
	log_info "UID/GID: ${uid}/${gid}"
	log_info "================================================"

	case "${command}" in
	setup | install)
		prevalidate_environment || exit 1
		setup_host_cache_dir "${cache_dir}"
		setup_permissions "${cache_dir}" "${uid}" "${gid}"
		setup_volume_named "${volume_name}"
		log_info "================================================"
		log_info "Setup concluído com sucesso!"
		log_info "================================================"
		log_info "Para usar o cache em containers:"
		log_info "  docker run -v ${volume_name}:/var/cache/kmscon ..."
		log_info "Ou com bind mount:"
		log_info "  docker run -v ${cache_dir}:/var/cache/kmscon ..."
		;;
	setup-volume)
		check_docker_installed || exit 1
		setup_volume_named "${volume_name}"
		;;
	setup-host)
		setup_host_cache_dir "${cache_dir}"
		setup_permissions "${cache_dir}" "${uid}" "${gid}"
		;;
	validate)
		prevalidate_environment
		;;
	cleanup | clean)
		local mode="${1:-soft}"
		cleanup_cache "${cache_dir}" "${volume_name}" "${mode}"
		;;
	status | info)
		show_status "${cache_dir}" "${volume_name}"
		;;
	help | --help | -h)
		show_usage
		;;
	*)
		log_error "Comando desconhecido: ${command}"
		show_usage
		exit 1
		;;
	esac
}

# Executa main
main "$@"
