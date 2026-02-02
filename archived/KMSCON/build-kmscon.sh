#!/bin/bash
# =============================================================================
# Script de Build do KMSCON para Debian 13 Trixie
# =============================================================================
# Descrição: Compila e empacota o kmscon com suporte a Docker e cache multi-camada
# Autor: AURORA NAS Project
# Versão: 2.0.0
# =============================================================================

set -euo pipefail
shopt -s nullglob

# =============================================================================
# CONSTANTES E CONFIGURAÇÕES
# =============================================================================

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="2.0.0"

# Códigos de saída
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_NOT_ROOT=10
readonly EXIT_BASH_OLD=11
readonly EXIT_DEPS_MISSING=12
readonly EXIT_DOWNLOAD_FAILED=20
readonly EXIT_CHECKSUM_INVALID=21
readonly EXIT_PATCH_FAILED=30
readonly EXIT_CONFIGURE_FAILED=40
readonly EXIT_FEATURE_MISSING=41
readonly EXIT_BUILD_FAILED=50
readonly EXIT_PACKAGE_FAILED=60
readonly EXIT_INSTALL_FAILED=70
readonly EXIT_SYSTEMD_FAILED=71
readonly EXIT_CACHE_LOCK_FAILED=80
readonly EXIT_CACHE_CORRUPTED=81

# Versões
readonly KMSCON_VERSION="${KMSCON_VERSION:-9.3.0}"
readonly LIBTSM_VERSION="${LIBTSM_VERSION:-4.0.2}"

# URLs
readonly KMSCON_URL="${KMSCON_URL:-https://api.github.com/repos/kmscon/kmscon/tarball/v${KMSCON_VERSION}}"
readonly LIBTSM_URL="${LIBTSM_URL:-https://api.github.com/repos/kmscon/libtsm/tarball/v${LIBTSM_VERSION}}"

# Diretórios
readonly BUILD_ROOT="${BUILD_ROOT:-/tmp/kmscon-build}"
readonly CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/.cache}"
readonly PATCHES_DIR="${PATCHES_DIR:-${SCRIPT_DIR}/patches}"
readonly OUTPUT_DIR="${OUTPUT_DIR:-/var/cache/kmscon-build}"
readonly PACKAGE_ROOT="${BUILD_ROOT}/package/kmscon-${KMSCON_VERSION}"

# Docker/Cache Configuration
readonly KMSCON_CACHE_DIR="${KMSCON_CACHE_DIR:-/var/cache/kmscon}"
readonly KMSCON_CACHE_ENABLED="${KMSCON_CACHE_ENABLED:-1}"
readonly KMSCON_CACHE_FORCE_REFRESH="${KMSCON_CACHE_FORCE_REFRESH:-0}"
readonly KMSCON_DOCKER_MODE="${KMSCON_DOCKER_MODE:-auto}"
readonly KMSCON_PARALLEL_JOBS="${KMSCON_PARALLEL_JOBS:-auto}"
readonly KMSCON_APT_CACHE="${KMSCON_APT_CACHE:-1}"
readonly KMSCON_LOCK_TIMEOUT="${KMSCON_LOCK_TIMEOUT:-300}"
readonly KMSCON_CACHE_TTL_DAYS="${KMSCON_CACHE_TTL_DAYS:-30}"

# Cache subdirectories
readonly CACHE_SOURCES_DIR="${KMSCON_CACHE_DIR}/sources"
readonly CACHE_BUILD_DIR="${KMSCON_CACHE_DIR}/build"
readonly CACHE_PACKAGES_DIR="${KMSCON_CACHE_DIR}/packages"
readonly CACHE_DEPS_DIR="${KMSCON_CACHE_DIR}/deps"
readonly CACHE_LOCK_DIR="${KMSCON_CACHE_DIR}/lock"
readonly MANIFEST_FILE="${KMSCON_CACHE_DIR}/manifest.json"

# Opções de build
readonly PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
readonly CHECKSUM_VERIFY="${CHECKSUM_VERIFY:-1}"
readonly KEEP_BUILD="${KEEP_BUILD:-0}"

# Logging
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly LOG_FILE="${LOG_FILE:-/var/log/kmscon-build.log}"

# Systemd
readonly KMSCON_VTS="${KMSCON_VTS:-tty1 tty2}"
readonly KMSCON_SEATS="${KMSCON_SEATS:-seat0}"

# Features obrigatórias do Meson
readonly REQUIRED_FEATURES=(
	"video_drm3d"
	"renderer_gltex"
	"font_pango"
	"libinput"
	"multi_seat"
	"session_terminal"
)

# =============================================================================
# VARIÁVEIS DE ESTADO
# =============================================================================

declare -A BUILD_STATE
declare -i CURRENT_PHASE=0
declare -a PHASE_NAMES=("setup" "download" "deps" "patch" "configure" "build" "package" "install")

# Cache state
declare -A CACHE_STATE
declare -g LOCK_FD=""
declare -g DOCKER_ENV=""

# =============================================================================
# CORES E FORMATATAÇÃO
# =============================================================================

# Cores TTY
if [[ -t 2 ]]; then
	readonly COLOR_RESET='\033[0m'
	readonly COLOR_RED='\033[0;31m'
	readonly COLOR_GREEN='\033[0;32m'
	readonly COLOR_YELLOW='\033[0;33m'
	readonly COLOR_BLUE='\033[0;34m'
	readonly COLOR_MAGENTA='\033[0;35m'
	readonly COLOR_CYAN='\033[0;36m'
	readonly COLOR_BOLD='\033[1m'
else
	readonly COLOR_RESET=''
	readonly COLOR_RED=''
	readonly COLOR_GREEN=''
	readonly COLOR_YELLOW=''
	readonly COLOR_BLUE=''
	readonly COLOR_MAGENTA=''
	readonly COLOR_CYAN=''
	readonly COLOR_BOLD=''
fi

# =============================================================================
# FUNÇÕES DE LOGGING
# =============================================================================

init_logging() {
	local log_dir
	log_dir="$(dirname "${LOG_FILE}")"

	if [[ ! -d ${log_dir} ]]; then
		mkdir -p "${log_dir}" 2>/dev/null || {
			echo "Aviso: Não foi possível criar diretório de lo${: $log_}dir" >&2
		}
	fi

	# Limpa log anterior
	: >"${LOG_FILE}" 2>/dev/null || true

	log_info "Iniciando script de build do KMSCON v${SCRIPT_VERSION}"
	log_info "Log file: ${LOG_FILE}"
}

_log() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

	# Escreve no arquivo de log
	echo "[${timestamp}] [${level}] ${message}" >>"${LOG_FILE}" 2>/dev/null || true

	# Escreve no stderr com cores (se TTY)
	local color=''
	case "${level}" in
	DEBUG) color="${COLOR_CYAN}" ;;
	INFO) color="${COLOR_GREEN}" ;;
	WARN) color="${COLOR_YELLOW}" ;;
	ERROR) color="${COLOR_RED}" ;;
	FATAL) color="${COLOR_RED}$COLOR_BOLD" ;;
	esac

	printf "%b[%s]%b %s\n" "${color}" "${level}" "${COLOR_RESET}" "${message}" >&2
}

log_debug() { [[ ${LOG_LEVEL} =~ ^(DEBUG)$ ]] && _log "DEBUG" "$1"; }
log_info() { [[ ${LOG_LEVEL} =~ ^(DEBUG|INFO)$ ]] && _log "INFO" "$1"; }
log_warn() { [[ ${LOG_LEVEL} =~ ^(DEBUG|INFO|WARN)$ ]] && _log "WARN" "$1"; }
log_error() { _log "ERROR" "$1"; }
log_fatal() { _log "FATAL" "$1"; }

# =============================================================================
# FUNÇÕES DE UTILIDADE
# =============================================================================

cleanup() {
	local exit_code=$?

	# Release cache lock if held
	if [[ -n ${LOCK_FD} ]] && [[ -e "/proc/$$/fd/${LOCK_FD}" ]]; then
		cache_release_lock 2>/dev/null || true
	fi

	if [[ ${exit_code} -ne 0 ]]; then
		log_error "Build falhou com código de saída${ $exit_co}de"

		if [[ ${KEEP_BUILD:-0} -eq 0 ]]; then
			log_info "Limpando diretório de build..."
			rm -rf "${BUILD_ROOT}"
		else
			log_info "Mantendo diretório de build em:${$BUILD_ROO}T"
		fi
	fi

	exit "$exit_code"
}

trap cleanup EXIT INT TERM

# Verifica versão mínima de um comando
version_gte() {
	local current="$1"
	local required="$2"

	if [[ ${current} == "${required}" ]]; then
		return 0
	fi

	local IFS=.
	local -a current_parts=(${current})
	local -a required_parts=(${required})

	for ((i = 0; i < ${#required_parts[@]}; i++)); do
		local c="${current_parts[${i}]:-0}"
		local r="${required_parts[${i}]:-0}"

		if ((c > r)); then
			return 0
		elif ((c < r)); then
			return 1
		fi
	done

	return 0
}

# Extrai versão de comando
get_version() {
	local cmd="$1"
	local version_flag="${2:---version}"

	"${cmd}" "$version_flag" 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Barra de progresso simples
progress() {
	local current="$1"
	local total="$2"
	local width=50

	local percent=$((current * 100 / total))
	local filled=$((current * width / total))

	printf "\r[" >&2
	for ((i = 0; i < filled; i++)); do printf "=" >&2; done
	for ((i = filled; i < width; i++)); do printf " " >&2; done
	printf "] %3d%%" "${percent}" >&2
}

# Calcula SHA256 de arquivo ou diretório
calculate_sha256() {
	local target="$1"

	if [[ -f ${target} ]]; then
		sha256sum "${target}" | awk '{print $1}'
	elif [[ -d ${target} ]]; then
		find "${target}" -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | awk '{print $1}'
	else
		echo ""
	fi
}

# Calcula hash de múltiplos arquivos combinados
hash_combined() {
	local combined=""
	for item in "$@"; do
		if [[ -e ${item} ]]; then
			combined+="$(calculate_sha256 "${item}")"
		fi
	done
	echo -n "${combined}" | sha256sum | awk '{print $1}'
}

# =============================================================================
# DOCKER ENVIRONMENT DETECTION
# =============================================================================

detect_docker_environment() {
	log_info "Detectando ambiente Docker..."

	# Check if explicitly disabled
	if [[ ${KMSCON_DOCKER_MODE} == "no" ]]; then
		DOCKER_ENV=""
		log_info "Modo Docker: desabilitado manualmente"
		return 0
	fi

	# Check for Docker-specific files
	if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
		DOCKER_ENV="docker"
		log_info "Ambiente Docker detectado (container)"
	# Check cgroup for container indicators
	elif [[ -f /proc/1/cgroup ]] && grep -qE 'docker|containerd|kubepod' /proc/1/cgroup 2>/dev/null; then
		DOCKER_ENV="docker"
		log_info "Ambiente Docker detectado (cgroup)"
	# Check for container environment variables
	elif [[ -n "${CONTAINER_ID-}" ]] || [[ -n "${KUBERNETES_SERVICE_HOST-}" ]]; then
		DOCKER_ENV="docker"
		log_info "Ambiente containerizado detectado (env vars)"
	elif [[ ${KMSCON_DOCKER_MODE} == "yes" ]]; then
		DOCKER_ENV="docker"
		log_info "Modo Docker: forçado via variável de ambiente"
	else
		DOCKER_ENV=""
		log_debug "Ambiente nativo detectado"
	fi

	# Detect container runtime details
	if [[ -n ${DOCKER_ENV} ]]; then
		local container_runtime="unknown"
		if [[ -f /run/.containerenv ]]; then
			container_runtime="podman"
		elif [[ -n "${KUBERNETES_SERVICE_HOST-}" ]]; then
			container_runtime="kubernetes"
		elif [[ -f /.dockerenv ]]; then
			container_runtime="docker"
		fi

		log_info "Runtime do container: ${container_runtime}"
		BUILD_STATE[container_runtime]="${container_runtime}"
	fi

	BUILD_STATE[docker_detected]="${DOCKER_ENV:+1}"
	return 0
}

setup_docker_optimizations() {
	[[ -z ${DOCKER_ENV} ]] && return 0

	log_info "Configurando otimizações para Docker..."

	# Adjust parallel jobs based on container limits
	if [[ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]] && [[ -f /sys/fs/cgroup/cpu/cpu.cfs_period_us ]]; then
		local quota period cpus
		quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null || echo -1)
		period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null || echo 100000)

		if [[ ${quota} != "-1" ]] && [[ ${period} -gt 0 ]]; then
			cpus=$((quota / period))
			if [[ ${cpus} -gt 0 ]]; then
				PARALLEL_JOBS="${cpus}"
				log_info "Jobs paralelos ajustados para limites do container: ${PARALLEL_JOBS}"
			fi
		fi
	fi

	# Check memory limits
	if [[ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
		local mem_limit
		mem_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo 0)
		# If limit is less than 1GB, adjust build settings
		if [[ ${mem_limit} -lt 1073741824 ]] && [[ ${mem_limit} -gt 0 ]]; then
			log_warn "Limite de memória baixo detectado: $((mem_limit / 1024 / 1024))MB"
			log_warn "Build pode ser mais lento devido a restrições de memória"
		fi
	fi

	# Setup apt caching in container
	if [[ ${KMSCON_APT_CACHE} -eq 1 ]] && [[ -d ${CACHE_DEPS_DIR} ]]; then
		log_info "Configurando cache de apt..."

		# Create apt cache directories
		mkdir -p "${CACHE_DEPS_DIR}/apt-cache/archives" \
			"${CACHE_DEPS_DIR}/apt-cache/lists" \
			"${CACHE_DEPS_DIR}/apt-cache/src"

		# Configure apt to use cache
		mkdir -p /etc/apt/apt.conf.d/
		cat >/etc/apt/apt.conf.d/99-kmscon-cache <<EOF
Dir::Cache::Archives "${CACHE_DEPS_DIR}/apt-cache/archives";
Dir::State::Lists "${CACHE_DEPS_DIR}/apt-cache/lists";
Acquire::Queue-Mode "access";
Acquire::Retries "3";
EOF
	fi

	log_info "Otimizações Docker configuradas"
	return 0
}

docker_setup_volumes() {
	log_info "Configurando volumes de cache..."

	# Create cache directory structure
	mkdir -p "${CACHE_SOURCES_DIR}/kmscon" \
		"${CACHE_SOURCES_DIR}/libtsm" \
		"${CACHE_BUILD_DIR}" \
		"${CACHE_PACKAGES_DIR}" \
		"${CACHE_DEPS_DIR}/apt-cache" \
		"${CACHE_LOCK_DIR}"

	# Ensure proper permissions in Docker
	if [[ -n ${DOCKER_ENV} ]]; then
		# Handle UID/GID mapping
		local host_uid="${HOST_UID:-$(stat -c %u "${KMSCON_CACHE_DIR}" 2>/dev/null || echo 0)}"
		local host_gid="${HOST_GID:-$(stat -c %g "${KMSCON_CACHE_DIR}" 2>/dev/null || echo 0)}"

		if [[ ${host_uid} -ne 0 ]] && [[ ${EUID} -eq 0 ]]; then
			log_debug "Ajustando permissões para UID${$host_ui}d, GID${$host_gi}d"
			chown -R "${host_uid}:${host_gid}" "${KMSCON_CACHE_DIR}" 2>/dev/null || true
		fi
	fi

	log_info "Estrutura de cache criada"
	return 0
}

docker_fix_permissions() {
	[[ -z ${DOCKER_ENV} ]] && return 0

	local path="${1:-${KMSCON_CACHE_DIR}}"
	local host_uid="${HOST_UID:-1000}"
	local host_gid="${HOST_GID:-1000}"

	if [[ ${EUID} -eq 0 ]] && [[ -e ${path} ]]; then
		chown -R "${host_uid}:${host_gid}" "${path}" 2>/dev/null || true
	fi
}

# =============================================================================
# CACHE SYSTEM
# =============================================================================

cache_init() {
	[[ ${KMSCON_CACHE_ENABLED} -eq 0 ]] && return 0

	log_info "Inicializando sistema de cache..."

	# Create cache directory structure
	docker_setup_volumes

	# Initialize or validate manifest
	if [[ -f ${MANIFEST_FILE} ]]; then
		if ! manifest_validate; then
			log_warn "Manifesto corrompido, criando novo..."
			manifest_create
		fi
	else
		manifest_create
	fi

	# Cleanup expired cache entries
	cache_cleanup_expired

	log_info "Sistema de cache inicializado"
	return 0
}

cache_calculate_hashes() {
	local component="${1:-kmscon}"
	declare -gA CACHE_HASHES

	log_debug "Calculando hashes para ${component}..."

	case "${component}" in
	kmscon)
		# Source hash: version + URL content
		local source_file="${CACHE_SOURCES_DIR}/kmscon/kmscon-${KMSCON_VERSION}.tar.gz"
		if [[ -f ${source_file} ]]; then
			CACHE_HASHES[source]=$(calculate_sha256 "${source_file}")
		else
			CACHE_HASHES[source]="${KMSCON_VERSION}"
		fi

		# Patches hash: all patches combined
		if [[ -d ${PATCHES_DIR} ]] && [[ -n "$(ls -A "${PATCHES_DIR}"/*.patch 2>/dev/null)" ]]; then
			CACHE_HASHES[patches]=$(hash_combined "${PATCHES_DIR}"/*.patch)
		else
			CACHE_HASHES[patches]="no-patches"
		fi

		# Config hash: build options
		CACHE_HASHES[config]=$(echo -n "${REQUIRED_FEATURES[*]}|${PARALLEL_JOBS}" | sha256sum | awk '{print $1}')

		# Deps hash: meson, gcc, lib versions
		local meson_ver gcc_ver
		meson_ver=$(get_version meson 2>/dev/null || echo "unknown")
		gcc_ver=$(gcc --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
		CACHE_HASHES[deps]=$(echo -n "meson:${meson_ver}|gcc:${gcc_ver}|libtsm:${LIBTSM_VERSION}" | sha256sum | awk '{print $1}')

		# Combined hash
		CACHE_HASHES[combined]=$(echo -n "${CACHE_HASHES[source]}:${CACHE_HASHES[patches]}:${CACHE_HASHES[config]}:${CACHE_HASHES[deps]}" | sha256sum | awk '{print $1}')
		;;

	libtsm)
		local source_file="${CACHE_SOURCES_DIR}/libtsm/libtsm-${LIBTSM_VERSION}.tar.gz"
		if [[ -f ${source_file} ]]; then
			CACHE_HASHES[source]=$(calculate_sha256 "${source_file}")
		else
			CACHE_HASHES[source]="${LIBTSM_VERSION}"
		fi

		CACHE_HASHES[patches]="no-patches"
		CACHE_HASHES[config]=$(echo -n "release|${PARALLEL_JOBS}" | sha256sum | awk '{print $1}')

		local gcc_ver
		gcc_ver=$(gcc --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
		CACHE_HASHES[deps]=$(echo -n "gcc:${gcc_ver}" | sha256sum | awk '{print $1}')

		CACHE_HASHES[combined]=$(echo -n "${CACHE_HASHES[source]}:${CACHE_HASHES[config]}:${CACHE_HASHES[deps]}" | sha256sum | awk '{print $1}')
		;;
	esac

	log_debug "Hashes calculados para ${component}:"
	log_debug "  Source: ${CACHE_HASHES[source]:0:16}..."
	log_debug "  Patches: ${CACHE_HASHES[patches]:0:16}..."
	log_debug "  Config: ${CACHE_HASHES[config]:0:16}..."
	log_debug "  Deps: ${CACHE_HASHES[deps]:0:16}..."
	log_debug "  Combined: ${CACHE_HASHES[combined]:0:16}..."
}

cache_acquire_lock() {
	[[ ${KMSCON_CACHE_ENABLED} -eq 0 ]] && return 0

	local lock_file="${CACHE_LOCK_DIR}/build.lock"
	local timeout="${1:-${KMSCON_LOCK_TIMEOUT}}"

	log_debug "Tentando adquirir lock de cache (timeout: ${timeout}s)..."

	# Create lock directory if needed
	mkdir -p "${CACHE_LOCK_DIR}"

	# Try to acquire lock with timeout
	local start_time
	start_time=$(date +%s)

	while true; do
		# Try to acquire lock
		exec {LOCK_FD}>"${lock_file}"
		if flock -n "${LOCK_FD}"; then
			log_debug "Lock adquirido com sucesso (fd: ${LOCK_FD})"
			return 0
		fi

		# Check timeout
		local current_time
		current_time=$(date +%s)
		if ((current_time - start_time >= timeout)); then
			log_warn "Timeout ao adquirir lock de cache"
			LOCK_FD=""
			# Graceful degradation: continue without cache locking
			return 0
		fi

		log_debug "Lock em uso, aguardando..."
		sleep 1
	done
}

cache_release_lock() {
	[[ -z ${LOCK_FD} ]] && return 0

	log_debug "Liberando lock de cache (fd: ${LOCK_FD})..."

	exec {LOCK_FD}>&- || true
	LOCK_FD=""
}

cache_check_hit() {
	local component="${1:-kmscon}"

	[[ ${KMSCON_CACHE_ENABLED} -eq 0 ]] && return 1
	[[ ${KMSCON_CACHE_FORCE_REFRESH} -eq 1 ]] && return 1

	log_info "Verificando cache para ${component}..."

	# Calculate current hashes
	cache_calculate_hashes "${component}"

	# Read manifest entry
	local entry
	entry=$(manifest_read "${component}")

	if [[ -z ${entry} ]] || [[ ${entry} == "null" ]]; then
		log_info "Cache miss: nenhuma entrada no manifesto para ${component}"
		return 1
	fi

	# Check if entry is valid
	local valid
	valid=$(echo "${entry}" | jq -r '.valid // false')
	if [[ ${valid} != "true" ]]; then
		log_info "Cache miss: entrada inválida no manifesto"
		return 1
	fi

	# Compare hashes
	local cached_combined
	cached_combined=$(echo "${entry}" | jq -r '.combined_hash // ""')

	if [[ ${cached_combined} != "${CACHE_HASHES[combined]}" ]]; then
		log_info "Cache miss: hash não corresponde"
		log_debug "  Cached: ${cached_combined:0:16}..."
		log_debug "  Current: ${CACHE_HASHES[combined]:0:16}..."
		return 1
	fi

	# Check if cached package exists
	local cached_deb
	cached_deb=$(echo "${entry}" | jq -r '.cached_deb // ""')
	if [[ -z ${cached_deb} ]] || [[ ! -f "${KMSCON_CACHE_DIR}/${cached_deb}" ]]; then
		log_info "Cache miss: pacote não encontrado"
		return 1
	fi

	# Verify package integrity
	local cached_pkg_hash
	cached_pkg_hash=$(echo "${entry}" | jq -r '.package_hash // ""')
	local current_pkg_hash
	current_pkg_hash=$(calculate_sha256 "${KMSCON_CACHE_DIR}/${cached_deb}")

	if [[ ${cached_pkg_hash} != "${current_pkg_hash}" ]]; then
		log_warn "Cache corrupted: hash do pacote não corresponde"
		return 1
	fi

	log_info "Cache HIT para ${component}: ${cached_deb}"
	CACHE_STATE["${component}_cached_deb"]="${KMSCON_CACHE_DIR}/${cached_deb}"
	return 0
}

cache_save_package() {
	local component="${1:-kmscon}"
	local deb_path="$2"
	local build_time="${3:-0}"

	[[ ${KMSCON_CACHE_ENABLED} -eq 0 ]] && return 0

	log_info "Salvando pacote em cache: ${component}"

	# Calculate package hash
	local package_hash
	package_hash=$(calculate_sha256 "${deb_path}")

	# Generate cache filename
	local arch
	arch=$(dpkg --print-architecture)
	local cached_name="${component}_${KMSCON_VERSION}_${arch}.deb"
	local cached_path="${CACHE_PACKAGES_DIR}/${cached_name}"

	# Copy package to cache
	cp "${deb_path}" "${cached_path}"

	# Update manifest
	manifest_update "${component}" "${cached_name}" "${package_hash}" "${build_time}"

	log_info "Pacote salvo em cache: ${cached_path}"
	return 0
}

cache_restore_package() {
	local component="${1:-kmscon}"
	local dest_dir="${2:-${OUTPUT_DIR}}"

	[[ ${KMSCON_CACHE_ENABLED} -eq 0 ]] && return 1

	local cached_deb="${CACHE_STATE[${component}_cached_deb]}"

	if [[ -z ${cached_deb} ]] || [[ ! -f ${cached_deb} ]]; then
		return 1
	fi

	log_info "Restaurando pacote do cache: ${component}"

	mkdir -p "${dest_dir}"
	cp "${cached_deb}" "${dest_dir}/"

	local deb_name
	deb_name=$(basename "${cached_deb}")
	BUILD_STATE[deb_path]="${dest_dir}/${deb_name}"

	log_info "Pacote restaurado: ${BUILD_STATE[deb_path]}"
	return 0
}

cache_cleanup_expired() {
	[[ ${KMSCON_CACHE_ENABLED} -eq 0 ]] && return 0

	log_debug "Limpando entradas de cache expiradas..."

	local max_age_days="${KMSCON_CACHE_TTL_DAYS}"
	local cutoff_date
	cutoff_date=$(date -d "-${max_age_days} days" +%s 2>/dev/null || echo 0)

	if [[ ! -f ${MANIFEST_FILE} ]] || [[ ${cutoff_date} -eq 0 ]]; then
		return 0
	fi

	# Read manifest and check each entry
	local manifest_content
	manifest_content=$(cat "${MANIFEST_FILE}")

	local entries
	entries=$(echo "${manifest_content}" | jq -r '.entries | keys[]' 2>/dev/null || echo "")

	for entry in ${entries}; do
		local entry_date
		entry_date=$(echo "${manifest_content}" | jq -r ".entries[\"${entry}\"].created_at // \"\"" 2>/dev/null)

		if [[ -n ${entry_date} ]]; then
			local entry_timestamp
			entry_timestamp=$(date -d "${entry_date}" +%s 2>/dev/null || echo 0)

			if [[ ${entry_timestamp} -lt ${cutoff_date} ]]; then
				log_info "Removendo entrada de cache expirada: ${entry}"

				# Remove cached package
				local cached_deb
				cached_deb=$(echo "${manifest_content}" | jq -r ".entries[\"${entry}\"].cached_deb // \"\"" 2>/dev/null)
				if [[ -n ${cached_deb} ]] && [[ -f "${KMSCON_CACHE_DIR}/${cached_deb}" ]]; then
					rm -f "${KMSCON_CACHE_DIR}/${cached_deb}"
				fi

				# Mark entry as invalid in manifest
				manifest_invalidate "${entry}"
			fi
		fi
	done
}

# =============================================================================
# MANIFEST SYSTEM
# =============================================================================

manifest_create() {
	log_debug "Criando novo manifesto..."

	mkdir -p "$(dirname "${MANIFEST_FILE}")"

	cat >"${MANIFEST_FILE}" <<EOF
{
  "version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "entries": {}
}
EOF

	log_debug "Manifesto criado: ${MANIFEST_FILE}"
}

manifest_read() {
	local component="$1"

	if [[ ! -f ${MANIFEST_FILE} ]]; then
		echo "null"
		return 1
	fi

	jq -r ".entries[\"${component}\"] // null" "${MANIFEST_FILE}" 2>/dev/null || echo "null"
}

manifest_update() {
	local component="$1"
	local cached_deb="$2"
	local package_hash="$3"
	local build_time="${4:-0}"

	if [[ ! -f ${MANIFEST_FILE} ]]; then
		manifest_create
	fi

	log_debug "Atualizando manifesto para ${component}..."

	# Create temporary file for atomic update
	local temp_manifest="${MANIFEST_FILE}.tmp.$$"

	jq --arg component "${component}" \
		--arg source_hash "${CACHE_HASHES[source]}" \
		--arg patches_hash "${CACHE_HASHES[patches]}" \
		--arg config_hash "${CACHE_HASHES[config]}" \
		--arg deps_hash "${CACHE_HASHES[deps]}" \
		--arg combined_hash "${CACHE_HASHES[combined]}" \
		--arg cached_deb "${cached_deb}" \
		--arg package_hash "${package_hash}" \
		--argjson build_time "${build_time}" \
		--arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		'.entries[$component] = {
           "source_hash": $source_hash,
           "patches_hash": $patches_hash,
           "config_hash": $config_hash,
           "deps_hash": $deps_hash,
           "combined_hash": $combined_hash,
           "cached_deb": $cached_deb,
           "package_hash": $package_hash,
           "build_time": $build_time,
           "valid": true,
           "created_at": $timestamp
       } | .updated_at = $timestamp' \
		"${MANIFEST_FILE}" >"${temp_manifest}"

	# Atomic move
	mv "${temp_manifest}" "${MANIFEST_FILE}"

	log_debug "Manifesto atualizado"
}

manifest_validate() {
	if [[ ! -f ${MANIFEST_FILE} ]]; then
		return 1
	fi

	# Check if valid JSON
	if ! jq empty "${MANIFEST_FILE}" 2>/dev/null; then
		return 1
	fi

	# Check required fields
	local version
	version=$(jq -r '.version // ""' "${MANIFEST_FILE}")
	if [[ ${version} != "1.0" ]]; then
		return 1
	fi

	return 0
}

manifest_invalidate() {
	local component="$1"

	[[ ! -f ${MANIFEST_FILE} ]] && return 0

	local temp_manifest="${MANIFEST_FILE}.tmp.$$"

	jq --arg component "${component}" \
		--arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		'.entries[$component].valid = false | .updated_at = $timestamp' \
		"${MANIFEST_FILE}" >"${temp_manifest}"

	mv "${temp_manifest}" "${MANIFEST_FILE}"
}

# =============================================================================
# FASE 1: VERIFICAÇÃO DE AMBIENTE
# =============================================================================

check_environment() {
	log_info "=== Fase 1: Verificação de Ambiente ==="

	# Detect Docker environment
	detect_docker_environment

	# Setup Docker optimizations
	setup_docker_optimizations

	# Initialize cache system
	cache_init

	# Verifica se está rodando como root
	if [[ ${EUID} -ne 0 ]]; then
		log_fatal "Este script deve ser executado como root"
		return "$EXIT_NOT_ROOT"
	fi
	log_debug "Executando como root: OK"

	# Verifica versão do Bash
	local bash_version="${BASH_VERSION%%.*}"
	if ((bash_version < 4)); then
		log_fatal "Bash 4.0+ é necessário (encontrado${ $BASH_VERSI}ON)"
		return "$EXIT_BASH_OLD"
	fi
	log_debug "Bash version: ${BASH_VERSION} (OK)"

	# Verifica se está em ambiente chroot
	if [[ -f /proc/1/root/. ]] && [[ /proc/1/root/. -ef / ]]; then
		log_debug "Ambiente: Não está em chroot"
	else
		log_debug "Ambiente: Chroot detectado"
	fi

	# Cria diretórios necessários
	mkdir -p "${BUILD_ROOT}" "${CACHE_DIR}" "${OUTPUT_DIR}" || {
		log_fatal "Falha ao criar diretórios de build"
		return "$EXIT_ERROR"
	}

	BUILD_STATE[env_checked]=1
	log_info "Ambiente verificado com sucesso"
	return "$EXIT_SUCCESS"
}

# =============================================================================
# VERIFICAÇÃO DE DEPENDÊNCIAS
# =============================================================================

check_dependencies() {
	log_info "Verificando dependências de build..."

	local -a required_cmds=(
		"meson:0.55.0"
		"ninja:0"
		"gcc:0"
		"pkg-config:0"
		"dpkg-deb:0"
		"curl:0"
		"tar:0"
		"patch:0"
		"jq:0"
	)

	local -a missing=()
	local -a version_issues=()

	for cmd_spec in "${required_cmds[@]}"; do
		local cmd="${cmd_spec%%:*}"
		local min_version="${cmd_spec##*:}"

		if ! command -v "${cmd}" &>/dev/null; then
			missing+=("${cmd}")
		elif [[ ${min_version} != "0" ]]; then
			local version
			version=$(get_version "${cmd}" 2>/dev/null || echo "0")
			if ! version_gte "${version}" "${min_version}"; then
				version_issues+=("${cmd}: ${version} < ${min_version}")
			fi
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Comandos não encontrados: ${missing[*]}"
		log_info "Instale com: apt-get install build-essential meson ninja-build pkg-config dpkg-dev curl tar patch jq"
		return "$EXIT_DEPS_MISSING"
	fi

	if [[ ${#version_issues[@]} -gt 0 ]]; then
		log_error "Versões incompatíveis:"
		for issue in "${version_issues[@]}"; do
			log_error "  - ${issue}"
		done
		return "$EXIT_DEPS_MISSING"
	fi

	log_info "Dependências de build: OK"

	# Verifica dependências de bibliotecas
	local -a lib_deps=(
		"libdrm"
		"xkbcommon"
		"udev"
		"systemd"
		"pango"
		"fontconfig"
		"freetype2"
		"gbm"
		"egl"
		"glesv2"
		"libinput"
	)

	local -a missing_libs=()
	for lib in "${lib_deps[@]}"; do
		if ! pkg-config --exists "${lib}" 2>/dev/null; then
			missing_libs+=("${lib}")
		fi
	done

	if [[ ${#missing_libs[@]} -gt 0 ]]; then
		log_warn "Bibliotecas faltando: ${missing_libs[*]}"
		log_info "Tentando instalar dependências..."
		install_build_deps || return "$EXIT_DEPS_MISSING"
	fi

	# Verifica libtsm especificamente
	if ! check_libtsm_version; then
		log_warn "libtsm >= 4.3.0 não encontrada, será necessário build"
		BUILD_STATE[need_libtsm_build]=1
	fi

	BUILD_STATE[deps_checked]=1
	log_info "Todas as dependências verificadas"
	return "$EXIT_SUCCESS"
}

install_build_deps() {
	log_info "Instalando dependências de build..."

	local -a deps=(
		build-essential
		meson
		ninja-build
		pkg-config
		dpkg-dev
		curl
		tar
		patch
		jq
		libdrm-dev
		libxkbcommon-dev
		libudev-dev
		libsystemd-dev
		libpango1.0-dev
		libfontconfig1-dev
		libfreetype-dev
		libgbm-dev
		libegl1-mesa-dev
		libgles2-mesa-dev
		libinput-dev
	)

	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq || {
		log_error "Falha ao atualizar apt"
		return 1
	}

	apt-get install -y -qq "${deps[@]}" || {
		log_error "Falha ao instalar dependências"
		return 1
	}

	log_info "Dependências instaladas com sucesso"
	return 0
}

check_libtsm_version() {
	if ! pkg-config --exists libtsm 2>/dev/null; then
		return 1
	fi

	local version
	version=$(pkg-config --modversion libtsm 2>/dev/null || echo "0")

	if version_gte "${version}" "4.3.0"; then
		log_info "libtsm version: ${version} (OK)"
		return 0
	else
		log_warn "libtsm version: ${version} (requer >= 4.3.0)"
		return 1
	fi
}

# =============================================================================
# FASE 2: DOWNLOAD
# =============================================================================

phase_download() {
	log_info "=== Fase 2: Download de Sources ==="
	CURRENT_PHASE=2

	# Acquire cache lock for download phase
	cache_acquire_lock

	# Download kmscon
	if ! download_kmscon; then
		cache_release_lock
		return "$EXIT_DOWNLOAD_FAILED"
	fi

	# Download libtsm se necessário
	if [[ ${BUILD_STATE[need_libtsm_build]:-0} -eq 1 ]]; then
		if ! download_libtsm; then
			cache_release_lock
			return "$EXIT_DOWNLOAD_FAILED"
		fi
	fi

	cache_release_lock
	BUILD_STATE[download_complete]=1
	log_info "Fase de download concluída"
	return "$EXIT_SUCCESS"
}

download_kmscon() {
	local url="${KMSCON_URL}"
	local filename="kmscon-${KMSCON_VERSION}.tar.gz"
	local cache_file="${CACHE_SOURCES_DIR}/kmscon/${filename}"

	log_info "Baixando kmscon ${KMSCON_VERSION}..."

	# Verifica cache
	if [[ -f ${cache_file} ]] && [[ ${CHECKSUM_VERIFY} -eq 0 ]]; then
		log_info "Usando cache: ${cache_file}"
	else
		# Download
		log_info "Baixando de: ${url}"
		mkdir -p "$(dirname "${cache_file}")"
		if ! curl -fsSL --retry 3 --retry-delay 5 -o "${cache_file}.tmp" "${url}"; then
			log_error "Falha ao baixar kmscon"
			rm -f "${cache_file}.tmp"
			return 1
		fi
		mv "${cache_file}.tmp" "${cache_file}"
	fi

	# Extrai
	local extract_dir="${BUILD_ROOT}/src/kmscon-${KMSCON_VERSION}"
	rm -rf "${extract_dir}"
	mkdir -p "${extract_dir}"

	log_info "Extraindo ${filename}..."
	if ! tar -xf "${cache_file}" -C "${BUILD_ROOT}/src/" --strip-components=1 2>/dev/null; then
		# Tenta extrair mantendo estrutura
		tar -xf "${cache_file}" -C "${BUILD_ROOT}/src/"
		# Move para estrutura esperada
		if [[ -d "${BUILD_ROOT}/src/kmscon-${KMSCON_VERSION}" ]]; then
			mv "${BUILD_ROOT}/src/kmscon-${KMSCON_VERSION}" "${BUILD_ROOT}/src/kmscon" 2>/dev/null || true
		fi
	fi

	BUILD_STATE[kmscon_src]="${BUILD_ROOT}/src"
	log_info "kmscon extraído em: ${BUILD_STATE[kmscon_src]}"
	return 0
}

download_libtsm() {
	local url="${LIBTSM_URL}"
	local filename="libtsm-${LIBTSM_VERSION}.tar.gz"
	local cache_file="${CACHE_SOURCES_DIR}/libtsm/${filename}"

	log_info "Baixando libtsm ${LIBTSM_VERSION}..."

	if [[ -f ${cache_file} ]] && [[ ${CHECKSUM_VERIFY} -eq 0 ]]; then
		log_info "Usando cache: ${cache_file}"
	else
		log_info "Baixando de: ${url}"
		mkdir -p "$(dirname "${cache_file}")"
		if ! curl -fsSL --retry 3 --retry-delay 5 -o "${cache_file}.tmp" "${url}"; then
			# Fallback para git clone
			log_warn "Download falhou, tentando git clone..."
			if ! clone_libtsm_from_git; then
				log_error "Falha ao obter libtsm"
				return 1
			fi
			return 0
		fi
		mv "${cache_file}.tmp" "${cache_file}"
	fi

	# Extrai
	local extract_dir="${BUILD_ROOT}/src/libtsm-${LIBTSM_VERSION}"
	rm -rf "${extract_dir}"
	mkdir -p "${extract_dir}"

	log_info "Extraindo ${filename}..."
	tar -xf "${cache_file}" -C "${BUILD_ROOT}/src/" || {
		log_error "Falha ao extrair libtsm"
		return 1
	}

	BUILD_STATE[libtsm_src]="${BUILD_ROOT}/src/libtsm-${LIBTSM_VERSION}"
	log_info "libtsm extraído em: ${BUILD_STATE[libtsm_src]}"
	return 0
}

clone_libtsm_from_git() {
	local dest="${BUILD_ROOT}/src/libtsm"
	rm -rf "${dest}"

	log_info "Clonando libtsm do git..."
	if ! git clone --depth 1 --branch "v${LIBTSM_VERSION}" \
		"https://github.com/kmscon/libtsm.git" "${dest}" 2>/dev/null; then
		# Tenta master se tag não existe
		git clone --depth 1 \
			"https://github.com/kmscon/libtsm.git" "${dest}"
	fi

	BUILD_STATE[libtsm_src]="${dest}"
	return 0
}

# =============================================================================
# FASE 3: DEPENDÊNCIAS (BUILD LIBTSM)
# =============================================================================

phase_deps() {
	log_info "=== Fase 3: Build de Dependências ==="
	CURRENT_PHASE=3

	if [[ ${BUILD_STATE[need_libtsm_build]:-0} -eq 1 ]]; then
		# Check cache for libtsm
		if cache_check_hit "libtsm"; then
			log_info "Usando libtsm do cache"
			# Restore from cache if needed
		else
			if ! build_libtsm; then
				return "$EXIT_BUILD_FAILED"
			fi
		fi
	fi

	BUILD_STATE[deps_complete]=1
	log_info "Fase de dependências concluída"
	return "$EXIT_SUCCESS"
}

build_libtsm() {
	local src_dir="${BUILD_STATE[libtsm_src]}"
	local build_dir="${BUILD_ROOT}/build/libtsm"

	log_info "Compilando libtsm..."

	rm -rf "${build_dir}"
	mkdir -p "${build_dir}"

	cd "${src_dir}" || return 1

	# Configura
	log_info "Configurando libtsm com meson..."
	meson setup "${build_dir}" \
		--prefix=/usr \
		--buildtype=release \
		-Ddocs=false \
		-Dtests=false || {
		log_error "Falha na configuração do libtsm"
		return 1
	}

	# Build
	log_info "Compilando libtsm com ninja..."
	ninja -C "${build_dir}" -j "${PARALLEL_JOBS}" || {
		log_error "Falha no build do libtsm"
		return 1
	}

	# Instala no sistema (necessário para build do kmscon)
	log_info "Instalando libtsm no sistema..."
	ninja -C "${build_dir}" install || {
		log_error "Falha ao instalar libtsm"
		return 1
	}

	# Atualiza cache do pkg-config
	ldconfig

	log_info "libtsm instalado com sucesso"
	return 0
}

# =============================================================================
# FASE 4: PATCHES
# =============================================================================

phase_patch() {
	log_info "=== Fase 4: Aplicação de Patches ==="
	CURRENT_PHASE=4

	local src_dir="${BUILD_STATE[kmscon_src]}"

	if [[ ! -d ${PATCHES_DIR} ]]; then
		log_info "Nenhum diretório de patches encontrado, pulando"
		BUILD_STATE[patch_complete]=1
		return "$EXIT_SUCCESS"
	fi

	cd "${src_dir}" || return 1

	local -a patches=("${PATCHES_DIR}"/*.diff "${PATCHES_DIR}"/*.patch)
	local applied=0
	local failed=0

	for patch in "${patches[@]}"; do
		[[ -f ${patch} ]] || continue

		local patch_name
		patch_name=$(basename "${patch}")
		log_info "Aplicando patch: ${patch_name}"

		# Testa primeiro
		if patch -p1 --dry-run <"${patch}" &>/dev/null; then
			if patch -p1 <"${patch}"; then
				log_info "Patch aplicado: ${patch_name}"
				((applied++))
			else
				log_warn "Falha ao aplicar patch: ${patch_name}"
				((failed++))
			fi
		else
			log_warn "Patch não aplicável (pode já estar aplicado${: $patch_n}ame"
		fi
	done

	log_info "Patches aplicados: ${applied}, falhas: ${failed}"
	BUILD_STATE[patch_complete]=1
	return "$EXIT_SUCCESS"
}

# =============================================================================
# FASE 5: CONFIGURAÇÃO
# =============================================================================

phase_configure() {
	log_info "=== Fase 5: Configuração do Build ==="
	CURRENT_PHASE=5

	local src_dir="${BUILD_STATE[kmscon_src]}"
	local build_dir="${BUILD_ROOT}/build/kmscon"

	rm -rf "${build_dir}"
	mkdir -p "${build_dir}"

	cd "${src_dir}" || return 1

	log_info "Configurando meson..."
	log_debug "Flags: video_drm3d=enabled, renderer_gltex=enabled, font_pango=enabled"

	# Configura meson com todas as flags obrigatórias
	meson setup "${build_dir}" \
		--prefix=/usr \
		--buildtype=release \
		-Dvideo_drm3d=enabled \
		-Drenderer_gltex=enabled \
		-Dfont_pango=enabled \
		-Dlibinput=enabled \
		-Dmulti_seat=enabled \
		-Dsession_terminal=enabled \
		-Dfont_unifont=enabled \
		-Dextra_debug=false || {
		log_error "Falha na configuração do meson"
		return "$EXIT_CONFIGURE_FAILED"
	}

	# Verifica se features foram habilitadas
	if ! verify_features "${build_dir}"; then
		return "$EXIT_FEATURE_MISSING"
	fi

	BUILD_STATE[configure_complete]=1
	BUILD_STATE[build_dir]="${build_dir}"
	log_info "Configuração concluída"
	return "$EXIT_SUCCESS"
}

verify_features() {
	local build_dir="$1"
	local info_file="${build_dir}/meson-info/build-info.json"

	log_info "Verificando features habilitadas..."

	if [[ ! -f ${info_file} ]]; then
		log_warn "Arquivo de info do meson não encontrado, pulando verificação"
		return 0
	fi

	local all_ok=true
	for feature in "${REQUIRED_FEATURES[@]}"; do
		# Verifica no meson-logs ou no introspect
		if grep -q "${feature}=enabled" "${info_file}" 2>/dev/null ||
			meson introspect "${build_dir}" --buildoptions 2>/dev/null | grep -q "${feature}.*enabled"; then
			log_info "  �${ $featu}re: enabled"
		else
			log_warn "  �${ $featu}re: não habilitado"
			all_ok=false
		fi
	done

	if [[ ${all_ok} == "false" ]]; then
		log_error "Algumas features obrigatórias não foram habilitadas"
		return 1
	fi

	return 0
}

# =============================================================================
# FASE 6: BUILD
# =============================================================================

phase_build() {
	log_info "=== Fase 6: Compilação ==="
	CURRENT_PHASE=6

	local build_dir="${BUILD_STATE[build_dir]}"

	log_info "Iniciando build com ninja (jobs: ${PARALLEL_JOBS})..."

	if ! ninja -C "${build_dir}" -j "${PARALLEL_JOBS}" 2>&1 | tee -a "${LOG_FILE}"; then
		log_error "Falha na compilação"
		return "$EXIT_BUILD_FAILED"
	fi

	# Verifica se binário foi criado
	if [[ ! -f "${build_dir}/kmscon" ]]; then
		# Tenta encontrar o binário
		local binary
		binary=$(find "${build_dir}" -name "kmscon" -type f -executable 2>/dev/null | head -1)
		if [[ -z ${binary} ]]; then
			log_error "Binário kmscon não encontrado após build"
			return "$EXIT_BUILD_FAILED"
		fi
		BUILD_STATE[binary_path]="${binary}"
	else
		BUILD_STATE[binary_path]="${build_dir}/kmscon"
	fi

	log_info "Build concluído: ${BUILD_STATE[binary_path]}"
	BUILD_STATE[build_complete]=1
	return "$EXIT_SUCCESS"
}

# =============================================================================
# FASE 7: EMPACOTAMENTO
# =============================================================================

phase_package() {
	log_info "=== Fase 7: Empacotamento ==="
	CURRENT_PHASE=7

	if ! create_deb_structure; then
		return "$EXIT_PACKAGE_FAILED"
	fi

	if ! generate_control; then
		return "$EXIT_PACKAGE_FAILED"
	fi

	if ! copy_build_artifacts; then
		return "$EXIT_PACKAGE_FAILED"
	fi

	if ! build_deb; then
		return "$EXIT_PACKAGE_FAILED"
	fi

	BUILD_STATE[package_complete]=1
	log_info "Fase de empacotamento concluída"
	return "$EXIT_SUCCESS"
}

create_deb_structure() {
	log_info "Criando estrutura de pacote DEB..."

	rm -rf "${PACKAGE_ROOT}"
	mkdir -p "${PACKAGE_ROOT}/DEBIAN"
	mkdir -p "${PACKAGE_ROOT}/usr/bin"
	mkdir -p "${PACKAGE_ROOT}/usr/lib"
	mkdir -p "${PACKAGE_ROOT}/etc/kmscon"
	mkdir -p "${PACKAGE_ROOT}/etc/systemd/system"
	mkdir -p "${PACKAGE_ROOT}/usr/share/doc/kmscon"
	mkdir -p "${PACKAGE_ROOT}/usr/share/kmscon"

	return 0
}

generate_control() {
	log_info "Gerando arquivo DEBIAN/control..."

	local arch
	arch=$(dpkg --print-architecture)

	cat >"${PACKAGE_ROOT}/DEBIAN/control" <<EOF
Package: kmscon
Version: ${KMSCON_VERSION}
Section: utils
Priority: optional
Architecture: ${arch}
Depends: libdrm2, libxkbcommon0, libudev1, libsystemd0, libpango-1.0-0, libfontconfig1, libfreetype6, libgbm1, libegl1, libgles2, libinput10, xkb-data, libc6
Suggests: libtsm0 (>= 4.3.0)
Maintainer: AURORA NAS Project <aurora@local>
Description: KMS/DRM based system console
 kmscon is a system console for Linux that uses Kernel Mode Setting (KMS)
 and Direct Rendering Manager (DRM) to provide a fast, hardware-accelerated
 terminal experience with full support for modern features like 24-bit color,
 hardware cursor, and smooth scrolling.
 .
 This package provides the kmscon binary and systemd service files.
EOF

	# Gera postinst
	cat >"${PACKAGE_ROOT}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e

# Atualiza cache de fontes
if command -v fc-cache &>/dev/null; then
    fc-cache -f /usr/share/fonts/truetype 2>/dev/null || true
fi

# Recarrega systemd
deb-systemd-helper unmask kmscon-getty@.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

exit 0
EOF
	chmod 755 "${PACKAGE_ROOT}/DEBIAN/postinst"

	# Gera prerm
	cat >"${PACKAGE_ROOT}/DEBIAN/prerm" <<'EOF'
#!/bin/bash
set -e

# Para serviços kmscon
for vt in tty1 tty2 tty3 tty4 tty5 tty6; do
    deb-systemd-invoke stop "kmscon-getty@${vt}.service" 2>/dev/null || true
    deb-systemd-helper disable "kmscon-getty@${vt}.service" 2>/dev/null || true
done

exit 0
EOF
	chmod 755 "${PACKAGE_ROOT}/DEBIAN/prerm"

	# Gera conffiles
	cat >"${PACKAGE_ROOT}/DEBIAN/conffiles" <<EOF
/etc/kmscon/kmscon.conf
EOF

	# Gera copyright
	cat >"${PACKAGE_ROOT}/usr/share/doc/kmscon/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: kmscon
Source: https://github.com/kmscon/kmscon

Files: *
Copyright: 2011-2013 David Herrmann <dh.herrmann@gmail.com>
License: MIT

License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a
 copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included
 in all copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOF

	return 0
}

copy_build_artifacts() {
	log_info "Copiando artefatos de build..."

	local build_dir="${BUILD_STATE[build_dir]}"

	# Copia binário principal
	if [[ -f "${build_dir}/kmscon" ]]; then
		cp "${build_dir}/kmscon" "${PACKAGE_ROOT}/usr/bin/"
		chmod 755 "${PACKAGE_ROOT}/usr/bin/kmscon"
	else
		log_error "Binário kmscon não encontrado"
		return 1
	fi

	# Copia bibliotecas se houver
	for lib in "${build_dir}"/*.so*; do
		[[ -f ${lib} ]] || continue
		cp "${lib}" "${PACKAGE_ROOT}/usr/lib/"
	done

	# Copia arquivos de configuração
	if [[ -f "${SCRIPT_DIR}/kmscon.conf" ]]; then
		cp "${SCRIPT_DIR}/kmscon.conf" "${PACKAGE_ROOT}/etc/kmscon/"
		chmod 644 "${PACKAGE_ROOT}/etc/kmscon/kmscon.conf"
	fi

	# Copia service file
	if [[ -f "${SCRIPT_DIR}/kmscon-getty@.service" ]]; then
		cp "${SCRIPT_DIR}/kmscon-getty@.service" "${PACKAGE_ROOT}/etc/systemd/system/"
		chmod 644 "${PACKAGE_ROOT}/etc/systemd/system/kmscon-getty@.service"
	fi

	return 0
}

build_deb() {
	log_info "Construindo pacote .deb..."

	local arch
	arch=$(dpkg --print-architecture)
	local deb_name="kmscon_${KMSCON_VERSION}_${arch}.deb"
	local deb_path="${OUTPUT_DIR}/${deb_name}"

	mkdir -p "${OUTPUT_DIR}"

	# Constrói o pacote
	if ! dpkg-deb --build "${PACKAGE_ROOT}" "${deb_path}"; then
		log_error "Falha ao construir pacote .deb"
		return 1
	fi

	BUILD_STATE[deb_path]="${deb_path}"
	log_info "Pacote criado: ${deb_path}"

	# Save to cache if enabled
	if [[ ${KMSCON_CACHE_ENABLED} -eq 1 ]]; then
		cache_acquire_lock
		cache_save_package "kmscon" "${deb_path}" 0
		cache_release_lock
	fi

	# Verifica pacote
	if command -v lintian &>/dev/null; then
		log_info "Verificando pacote com lintian..."
		lintian "${deb_path}" 2>/dev/null || log_warn "Lintian reportou warnings"
	fi

	return 0
}

# =============================================================================
# FASE 8: INSTALAÇÃO
# =============================================================================

phase_install() {
	log_info "=== Fase 8: Instalação ==="
	CURRENT_PHASE=8

	local deb_path="${BUILD_STATE[deb_path]}"

	if ! install_package "${deb_path}"; then
		return "$EXIT_INSTALL_FAILED"
	fi

	if ! configure_systemd; then
		return "$EXIT_SYSTEMD_FAILED"
	fi

	if ! verify_installation; then
		return "$EXIT_INSTALL_FAILED"
	fi

	BUILD_STATE[install_complete]=1
	log_info "Instalação concluída com sucesso!"
	return "$EXIT_SUCCESS"
}

install_package() {
	local deb_path="$1"

	log_info "Instalando pacote: ${deb_path}"

	if ! dpkg -i "${deb_path}"; then
		log_warn "dpkg reportou erros, tentando corrigir dependências..."
		apt-get install -f -y || {
			log_error "Falha ao instalar pacote e corrigir dependências"
			return 1
		}
	fi

	log_info "Pacote instalado com sucesso"
	return 0
}

configure_systemd() {
	log_info "Configurando serviços systemd..."

	# Recarrega systemd
	systemctl daemon-reload 2>/dev/null || {
		log_warn "Não foi possível recarregar systemd (pode estar em chroot)"
	}

	# Habilita kmscon nos TTYs configurados
	for vt in ${KMSCON_VTS}; do
		log_info "Configurando ${vt} para usar kmscon..."

		# Desabilita getty neste TTY
		systemctl disable "getty@${vt}.service" 2>/dev/null || true

		# Habilita kmscon
		systemctl enable "kmscon-getty@${vt}.service" 2>/dev/null || {
			log_warn "Não foi possível habilitar kmscon@${vt} (pode estar em chroot)"
		}
	done

	# Mantém getty em TTYs superiores como fallback
	for vt in tty3 tty4 tty5 tty6; do
		systemctl enable "getty@${vt}.service" 2>/dev/null || true
	done

	log_info "Serviços systemd configurados"
	return 0
}

verify_installation() {
	log_info "Verificando instalação..."

	# Verifica binário
	if [[ ! -x /usr/bin/kmscon ]]; then
		log_error "Binário /usr/bin/kmscon não encontrado ou não executável"
		return 1
	fi

	# Testa execução (apenas --help, não inicia)
	if ! /usr/bin/kmscon --help &>/dev/null && ! /usr/bin/kmscon --version &>/dev/null; then
		log_warn "Não foi possível verificar execução do kmscon (pode requerer DRM)"
	else
		log_info "Binário kmscon executável: OK"
	fi

	# Verifica service file
	if [[ ! -f /etc/systemd/system/kmscon-getty@.service ]]; then
		log_warn "Service file não encontrado em /etc/systemd/system/"
	else
		log_info "Service file: OK"
	fi

	# Verifica configuração
	if [[ -f /etc/kmscon/kmscon.conf ]]; then
		log_info "Arquivo de configuração: OK"
	fi

	log_info "Verificação de instalação concluída"
	return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

show_usage() {
	cat <<EOF
Uso: ${SCRIPT_NAME} [OPÇÕES]

Script de build do KMSCON para Debian 13 Trixie com suporte Docker e cache multi-camada

OPÇÕES:
    -h, --help               Mostra esta ajuda
    -v, --version            Mostra versão do script
    -k, --keep               Mantém diretório de build após conclusão
    -c, --clean              Limpa cache e build antes de iniciar
    -j, --jobs N             Número de jobs paralelos (padrão: auto)
    -l, --log-level          Nível de log: DEBUG, INFO, WARN, ERROR (padrão: INFO)
    -o, --output DIR         Diretório de saída para o pacote .deb
    --cache-only             Apenas verifica cache, não compila
    --force-refresh          Força rebuild ignorando cache

VARIÁVEIS DE AMBIENTE DOCKER/CACHE:
    KMSCON_CACHE_DIR         Diretório de cache (padrão: /var/cache/kmscon)
    KMSCON_CACHE_ENABLED     Habilitar cache (1=sim, 0=não, padrão: 1)
    KMSCON_CACHE_FORCE_REFRESH  Forçar rebuild (1=sim, 0=não, padrão: 0)
    KMSCON_DOCKER_MODE       Modo Docker: auto|yes|no (padrão: auto)
    KMSCON_PARALLEL_JOBS     Jobs de compilação (padrão: auto)
    KMSCON_APT_CACHE         Usar cache de apt (1=sim, 0=não, padrão: 1)
    KMSCON_LOCK_TIMEOUT      Timeout para lock (segundos, padrão: 300)
    KMSCON_CACHE_TTL_DAYS    TTL do cache em dias (padrão: 30)
    HOST_UID                 UID do host (para permissões Docker)
    HOST_GID                 GID do host (para permissões Docker)

VARIÁVEIS DE AMBIENTE BUILD:
    KMSCON_VERSION           Versão do kmscon (padrão: ${KMSCON_VERSION})
    LIBTSM_VERSION           Versão do libtsm (padrão: ${LIBTSM_VERSION})
    PARALLEL_JOBS            Jobs paralelos (padrão: auto)
    KEEP_BUILD               Manter build (1=sim, 0=não)
    LOG_LEVEL                Nível de log

EXEMPLOS:
    ${SCRIPT_NAME}                          # Build completo
    ${SCRIPT_NAME} -j 4                     # Build com 4 jobs
    ${SCRIPT_NAME} -c -k                    # Limpa cache, mantém build
    ${SCRIPT_NAME} --cache-only             # Apenas verifica cache
    KMSCON_DOCKER_MODE=yes ${SCRIPT_NAME}   # Força modo Docker

EOF
}

show_version() {
	echo "${SCRIPT_NAME} versão ${SCRIPT_VERSION}"
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			show_usage
			exit 0
			;;
		-v | --version)
			show_version
			exit 0
			;;
		-k | --keep)
			KEEP_BUILD=1
			shift
			;;
		-c | --clean)
			log_info "Limpando cache e diretórios de build..."
			rm -rf "${CACHE_DIR}" "${BUILD_ROOT}" "${OUTPUT_DIR}"
			shift
			;;
		-j | --jobs)
			PARALLEL_JOBS="$2"
			shift 2
			;;
		-l | --log-level)
			LOG_LEVEL="$2"
			shift 2
			;;
		-o | --output)
			OUTPUT_DIR="$2"
			shift 2
			;;
		--cache-only)
			BUILD_STATE[cache_only]=1
			shift
			;;
		--force-refresh)
			KMSCON_CACHE_FORCE_REFRESH=1
			shift
			;;
		*)
			log_error "Opção desconhecida: $1"
			show_usage
			exit 1
			;;
		esac
	done
}

main() {
	parse_args "$@"

	# Inicializa logging
	init_logging

	log_info "================================================"
	log_info "KMSCON Build Script v${SCRIPT_VERSION}"
	log_info "================================================"
	log_info "KMSCON_VERSION: ${KMSCON_VERSION}"
	log_info "LIBTSM_VERSION: ${LIBTSM_VERSION}"
	log_info "PARALLEL_JOBS: ${PARALLEL_JOBS}"
	log_info "OUTPUT_DIR: ${OUTPUT_DIR}"
	log_info "CACHE_DIR: ${KMSCON_CACHE_DIR}"
	log_info "DOCKER_MODE: ${KMSCON_DOCKER_MODE}"
	log_info "================================================"

	# Fase 1: Ambiente
	check_environment || exit $?

	# Check cache-only mode
	if [[ ${BUILD_STATE[cache_only]:-0} -eq 1 ]]; then
		log_info "Modo cache-only: verificando cache..."
		if cache_check_hit "kmscon"; then
			log_info "Cache HIT: pacote disponível"
			cache_restore_package "kmscon" "${OUTPUT_DIR}"
			log_info "Pacote restaurado em: ${BUILD_STATE[deb_path]}"
			exit "$EXIT_SUCCESS"
		else
			log_info "Cache MISS: pacote precisa ser compilado"
			exit "$EXIT_ERROR"
		fi
	fi

	# Check for cached package before full build
	if cache_check_hit "kmscon"; then
		log_info "Cache HIT para kmscon! Usando pacote pré-compilado."

		# Restore package from cache
		if cache_restore_package "kmscon" "${OUTPUT_DIR}"; then
			BUILD_STATE[deb_path]="${OUTPUT_DIR}/$(basename "${CACHE_STATE[kmscon_cached_deb]}")"

			# Skip to installation
			log_info "Pulando para instalação..."
			phase_install || exit $?

			log_info "================================================"
			log_info "BUILD CONCLUÍDO VIA CACHE!"
			log_info "================================================"
			log_info "Pacote: ${BUILD_STATE[deb_path]}"
			log_info "Binário: /usr/bin/kmscon"
			log_info "================================================"

			exit "$EXIT_SUCCESS"
		fi
	fi

	log_info "Cache MISS: executando build completo..."

	# Fase 2: Dependências
	check_dependencies || exit $?

	# Fase 3: Download
	phase_download || exit $?

	# Fase 4: Build de dependências (libtsm)
	phase_deps || exit $?

	# Fase 5: Patches
	phase_patch || exit $?

	# Fase 6: Configuração
	phase_configure || exit $?

	# Fase 7: Build
	phase_build || exit $?

	# Fase 8: Empacotamento
	phase_package || exit $?

	# Fase 9: Instalação
	phase_install || exit $?

	log_info "================================================"
	log_info "BUILD CONCLUÍDO COM SUCESSO!"
	log_info "================================================"
	log_info "Pacote: ${BUILD_STATE[deb_path]}"
	log_info "Binário: /usr/bin/kmscon"
	log_info "Config: /etc/kmscon/kmscon.conf"
	log_info "================================================"

	return "$EXIT_SUCCESS"
}

# Executa main
main "$@"
