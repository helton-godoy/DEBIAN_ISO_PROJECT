#!/bin/bash
# =============================================================================
# Script de Build do KMSCON para Debian 13 Trixie
# =============================================================================
# Descrição: Compila e empacota o kmscon do repositório upstream
# Autor: AURORA NAS Project
# Versão: 1.0.0
# =============================================================================

set -euo pipefail
shopt -s nullglob

# =============================================================================
# CONSTANTES E CONFIGURAÇÕES
# =============================================================================

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"

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

# Versões
readonly KMSCON_VERSION="${KMSCON_VERSION:-9.0.0}"
readonly LIBTSM_VERSION="${LIBTSM_VERSION:-4.0.2}"

# URLs da API GitHub para verificação de releases
readonly KMSCON_API_URL="${KMSCON_API_URL:-https://api.github.com/repos/kmscon/kmscon/releases/latest}"
readonly LIBTSM_API_URL="${LIBTSM_API_URL:-https://api.github.com/repos/kmscon/libtsm/releases/latest}"

# URLs de download (serão atualizadas dinamicamente se CHECK_LATEST=1)
readonly KMSCON_URL="${KMSCON_URL:-https://api.github.com/repos/kmscon/kmscon/tarball/v${KMSCON_VERSION}}"
readonly LIBTSM_URL="${LIBTSM_URL:-https://api.github.com/repos/kmscon/libtsm/tarball/v${LIBTSM_VERSION}}"

# Opções de download idempotente
readonly CHECK_LATEST="${CHECK_LATEST:-1}"
readonly FORCE_REDOWNLOAD="${FORCE_REDOWNLOAD:-0}"
readonly DOWNLOAD_RETRY_COUNT="${DOWNLOAD_RETRY_COUNT:-3}"
readonly DOWNLOAD_RETRY_DELAY="${DOWNLOAD_RETRY_DELAY:-5}"

# Diretórios
readonly BUILD_ROOT="${BUILD_ROOT:-/tmp/kmscon-build}"
readonly CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/.cache}"
readonly PATCHES_DIR="${PATCHES_DIR:-${SCRIPT_DIR}/patches}"
OUTPUT_DIR="${OUTPUT_DIR:-/var/cache/kmscon-build}"
readonly PACKAGE_ROOT="${BUILD_ROOT}/package/kmscon-${KMSCON_VERSION}"

# Opções de build
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
readonly CHECKSUM_VERIFY="${CHECKSUM_VERIFY:-1}"
KEEP_BUILD="${KEEP_BUILD:-0}"

# Logging
LOG_LEVEL="${LOG_LEVEL:-INFO}"
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
	log_dir="$(dirname "$LOG_FILE")"

	if [[ ! -d "$log_dir" ]]; then
		mkdir -p "$log_dir" 2>/dev/null || {
			printf '%s\n' "Aviso: Não foi possível criar diretório de log: $log_dir" >&2
		}
	fi

	# Limpa log anterior
	: >"$LOG_FILE" 2>/dev/null || true

	log_info "Iniciando script de build do KMSCON v${SCRIPT_VERSION}"
	log_info "Log file: $LOG_FILE"
}

_log() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

	# Escreve no arquivo de log
	printf '%s\n' "[${timestamp}] [${level}] ${message}" >>"$LOG_FILE" 2>/dev/null || true

	# Escreve no stderr com cores (se TTY)
	local color=''
	case "$level" in
	DEBUG) color="$COLOR_CYAN" ;;
	INFO) color="$COLOR_GREEN" ;;
	WARN) color="$COLOR_YELLOW" ;;
	ERROR) color="$COLOR_RED" ;;
	FATAL) color="$COLOR_RED$COLOR_BOLD" ;;
	esac

	printf "%b[%s]%b %s\n" "$color" "$level" "$COLOR_RESET" "$message" >&2
}

log_debug() { [[ "$LOG_LEVEL" =~ ^(DEBUG)$ ]] && _log "DEBUG" "$1"; }
log_info() { [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO)$ ]] && _log "INFO" "$1"; }
log_warn() { [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO|WARN)$ ]] && _log "WARN" "$1"; }
log_error() { _log "ERROR" "$1"; }
log_fatal() { _log "FATAL" "$1"; }

# =============================================================================
# FUNÇÕES DE UTILIDADE
# =============================================================================

cleanup() {
	local exit_code=$?

	# Preserva o código de erro original antes de qualquer operação
	local original_exit=$exit_code

	if [[ $original_exit -ne 0 ]]; then
		log_error "Build falhou com código de saída: $original_exit"

		if [[ "${KEEP_BUILD:-0}" -eq 0 ]]; then
			log_info "Limpando diretório de build..."
			rm -rf "$BUILD_ROOT" || true
		else
			log_info "Mantendo diretório de build em: $BUILD_ROOT"
		fi
	fi

	# Retorna o código de erro original
	exit $original_exit
}

trap cleanup EXIT INT TERM

# Verifica versão mínima de um comando
version_gte() {
	local current="$1"
	local required="$2"

	if [[ "$current" == "$required" ]]; then
		return 0
	fi

	local IFS=.
	local -a current_parts=($current)
	local -a required_parts=($required)

	for ((i = 0; i < ${#required_parts[@]}; i++)); do
		local c="${current_parts[$i]:-0}"
		local r="${required_parts[$i]:-0}"

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

	"$cmd" $version_flag 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# =============================================================================
# FUNÇÕES DE VERIFICAÇÃO DE VERSÃO VIA API GITHUB
# =============================================================================

# Verifica a última versão disponível no GitHub via API
# Retorna: tag_name, download_url, tarball_url
# Uso: eval "$(check_latest_version "kmscon" "$KMSCON_API_URL")"
check_latest_version() {
	local project="$1"
	local api_url="$2"
	local timeout="${3:-30}"

	log_debug "Verificando última versão de $project via API GitHub..."
	log_debug "API URL: $api_url"

	local api_response
	local curl_exit_code

	# Faz a requisição à API com timeout e retry implícito do curl
	api_response=$(curl -fsSL \
		--max-time "$timeout" \
		--retry 2 \
		--retry-delay 3 \
		-H "Accept: application/vnd.github.v3+json" \
		-H "User-Agent: KMSCON-Build-Script" \
		"$api_url" 2>&1) || {
		curl_exit_code=$?

		# Verificar se é rate limit (HTTP 403/429)
		if [[ "$api_response" =~ "403" ]] || [[ "$api_response" =~ "429" ]]; then
			log_warn "GitHub API rate limit atingido para $project"
			log_info "Usando versão padrão configurada"
			return 1 # Retorna erro para usar versão padrão
		fi

		log_warn "Falha ao consultar API GitHub para $project (exit: $curl_exit_code)"
		log_warn "Resposta: $api_response"
		return 1
	}

	# Extrai informações da API
	local tag_name
	local tarball_url

	tag_name=$(echo "$api_response" | grep -oP '"tag_name":\s*"\K[^"]+' 2>/dev/null || echo "")
	tarball_url=$(echo "$api_response" | grep -oP '"tarball_url":\s*"\K[^"]+' 2>/dev/null || echo "")

	if [[ -z "$tag_name" ]]; then
		log_warn "Não foi possível extrair tag_name da API para $project"
		return 1
	fi

	# Remove prefixo 'v' da versão se presente
	local version="${tag_name#v}"

	log_info "Última versão de $project: $tag_name (v$version)"
	log_info "Download URL (API): $tarball_url"

	# Exporta variáveis para o caller
	# Usar tarball_url da API como fonte principal (sempre disponível)
	echo "LATEST_VERSION='$version'"
	echo "LATEST_TAG='$tag_name'"
	echo "LATEST_URL='${tarball_url}'"
	echo "TARBALL_URL='${tarball_url}'"

	return 0
}

# Compara duas versões semânticas
# Retorna 0 se v1 >= v2, 1 caso contrário
# Uso: compare_semantic_versions "9.0.0" "8.2.1"
compare_semantic_versions() {
	local v1="$1"
	local v2="$2"

	# Remove prefixo 'v' se presente
	v1="${v1#v}"
	v2="${v2#v}"

	# Converte para arrays
	local IFS='.'
	local -a v1_parts=($v1)
	local -a v2_parts=($v2)

	local max_len=$((${#v1_parts[@]} > ${#v2_parts[@]} ? ${#v1_parts[@]} : ${#v2_parts[@]}))

	for ((i = 0; i < max_len; i++)); do
		local p1="${v1_parts[$i]:-0}"
		local p2="${v2_parts[$i]:-0}"

		# Remove sufixos como '-rc1', '-beta', etc. para comparação numérica
		p1="${p1%%-*}"
		p2="${p2%%-*}"

		# Garante que são números
		p1="${p1//[^0-9]/}"
		p2="${p2//[^0-9]/}"
		p1="${p1:-0}"
		p2="${p2:-0}"

		if ((p1 > p2)); then
			return 0 # v1 > v2
		elif ((p1 < p2)); then
			return 1 # v1 < v2
		fi
	done

	return 0 # v1 == v2
}

# Verifica se URL está acessível via HEAD request
# Uso: validate_url "$url" || log_error "URL inválida"
validate_url() {
	local url="$1"
	local timeout="${2:-10}"

	log_debug "Validando URL: $url"

	local http_code
	http_code=$(curl -o /dev/null -fsSL \
		--max-time "$timeout" \
		--retry 2 \
		--retry-delay 2 \
		-w "%{http_code}" \
		-I "$url" 2>&1) || {
		log_warn "URL não acessível: $url"
		return 1
	}

	# Verificar rate limiting (403/429)
	if [[ "$http_code" == "403" ]] || [[ "$http_code" == "429" ]]; then
		log_warn "Rate limit detectado (HTTP $http_code): $url"
		return 2 # Código especial para rate limit
	fi

	if [[ "$http_code" =~ ^(200|301|302|307|308)$ ]]; then
		log_debug "URL válida (HTTP $http_code): $url"
		return 0
	else
		log_warn "URL retornou HTTP $http_code: $url"
		return 1
	fi
}

# Download com retry e backoff exponencial
# Uso: download_with_retry "$url" "$output_file" || return 1
download_with_retry() {
	local url="$1"
	local output_file="$2"
	local max_retries="${3:-$DOWNLOAD_RETRY_COUNT}"
	local base_delay="${4:-$DOWNLOAD_RETRY_DELAY}"

	local attempt=1
	local delay=$base_delay

	while [[ $attempt -le $max_retries ]]; do
		log_info "Download tentativa $attempt/$max_retries: $url"

		if curl -fsSL \
			--max-time 120 \
			--retry 0 \
			-o "$output_file.tmp" \
			"$url" 2>&1 | tee -a "$LOG_FILE"; then

			# Verifica se arquivo foi baixado e não está vazio
			if [[ -s "$output_file.tmp" ]]; then
				mv "$output_file.tmp" "$output_file"
				log_info "Download concluído: $output_file"
				return 0
			else
				log_warn "Arquivo baixado está vazio"
				rm -f "$output_file.tmp"
			fi
		fi

		log_warn "Download falhou na tentativa $attempt"

		if [[ $attempt -lt $max_retries ]]; then
			log_info "Aguardando ${delay}s antes de retry..."
			sleep $delay
			# Backoff exponencial: 5s, 10s, 20s
			delay=$((delay * 2))
		fi

		((attempt++))
	done

	log_error "Download falhou após $max_retries tentativas: $url"
	rm -f "$output_file.tmp"
	return 1
}

# Lê versão de um arquivo de versão salvo
# Uso: get_cached_version "$cache_file"
get_cached_version() {
	local cache_file="$1"
	if [[ -f "$cache_file" ]]; then
		cat "$cache_file" 2>/dev/null || echo ""
	else
		echo ""
	fi
}

# Salva versão em arquivo de cache
# Uso: save_cached_version "$cache_file" "$version"
save_cached_version() {
	local cache_file="$1"
	local version="$2"
	local cache_dir
	cache_dir="$(dirname "$cache_file")"

	mkdir -p "$cache_dir" 2>/dev/null || true
	echo "$version" >"$cache_file" 2>/dev/null || true
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
	printf "] %3d%%" "$percent" >&2
}

# =============================================================================
# FASE 1: VERIFICAÇÃO DE AMBIENTE
# =============================================================================

check_environment() {
	log_info "=== Fase 1: Verificação de Ambiente ==="

	# Verifica se está rodando como root
	if [[ $EUID -ne 0 ]]; then
		log_fatal "Este script deve ser executado como root"
		return $EXIT_NOT_ROOT
	fi
	log_debug "Executando como root: OK"

	# Verifica versão do Bash
	local bash_version="${BASH_VERSION%%.*}"
	if ((bash_version < 4)); then
		log_fatal "Bash 4.0+ é necessário (encontrado: $BASH_VERSION)"
		return $EXIT_BASH_OLD
	fi
	log_debug "Bash version: $BASH_VERSION (OK)"

	# Verifica se está em ambiente chroot
	if [[ -f /proc/1/root/. ]] && [[ /proc/1/root/. -ef / ]]; then
		log_debug "Ambiente: Não está em chroot"
	else
		log_debug "Ambiente: Chroot detectado"
	fi

	# Cria diretórios necessários
	mkdir -p "$BUILD_ROOT" "$CACHE_DIR" "$OUTPUT_DIR" || {
		log_fatal "Falha ao criar diretórios de build"
		return $EXIT_ERROR
	}

	# Definir permissões seguras para diretórios de build
	chmod 755 "$BUILD_ROOT" || {
		log_fatal "Falha ao definir permissões do diretório BUILD_ROOT"
		return $EXIT_ERROR
	}
	chmod 755 "$CACHE_DIR" || {
		log_fatal "Falha ao definir permissões do diretório CACHE_DIR"
		return $EXIT_ERROR
	}
	chmod 755 "$OUTPUT_DIR" || {
		log_fatal "Falha ao definir permissões do diretório OUTPUT_DIR"
		return $EXIT_ERROR
	}

	BUILD_STATE[env_checked]=1
	log_info "Ambiente verificado com sucesso"
	return $EXIT_SUCCESS
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
	)

	local -a missing=()
	local -a version_issues=()

	for cmd_spec in "${required_cmds[@]}"; do
		local cmd="${cmd_spec%%:*}"
		local min_version="${cmd_spec##*:}"

		if ! command -v "$cmd" &>/dev/null; then
			missing+=("$cmd")
		elif [[ "$min_version" != "0" ]]; then
			local version
			version=$(get_version "$cmd" 2>/dev/null || echo "0")
			if ! version_gte "$version" "$min_version"; then
				version_issues+=("$cmd: $version < $min_version")
			fi
		fi
	done

	# Tenta instalar dependências automaticamente se comandos estiverem faltando
	if [[ ${#missing[@]} -gt 0 ]]; then
		log_warn "Comandos não encontrados: ${missing[*]}"
		log_info "Tentando instalar dependências de build automaticamente..."

		if install_build_deps; then
			log_info "Dependências instaladas com sucesso, verificando novamente..."
			# Re-verifica se os comandos agora existem
			missing=()
			for cmd_spec in "${required_cmds[@]}"; do
				local cmd="${cmd_spec%%:*}"
				if ! command -v "$cmd" &>/dev/null; then
					missing+=("$cmd")
				fi
			done

			if [[ ${#missing[@]} -gt 0 ]]; then
				log_error "Ainda faltam comandos após instalação: ${missing[*]}"
				log_info "Instale manualmente com: apt-get install build-essential meson ninja-build pkg-config dpkg-dev curl tar patch"
				return $EXIT_DEPS_MISSING
			fi
		else
			log_error "Falha ao instalar dependências automaticamente"
			log_info "Instale manualmente com: apt-get install build-essential meson ninja-build pkg-config dpkg-dev curl tar patch"
			return $EXIT_DEPS_MISSING
		fi
	fi

	if [[ ${#version_issues[@]} -gt 0 ]]; then
		log_error "Versões incompatíveis:"
		for issue in "${version_issues[@]}"; do
			log_error "  - $issue"
		done
		return $EXIT_DEPS_MISSING
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
		if ! pkg-config --exists "$lib" 2>/dev/null; then
			missing_libs+=("$lib")
		fi
	done

	if [[ ${#missing_libs[@]} -gt 0 ]]; then
		log_warn "Bibliotecas faltando: ${missing_libs[*]}"
		log_info "Tentando instalar dependências..."
		install_build_deps || return $EXIT_DEPS_MISSING
	fi

	# Verifica libtsm especificamente
	if ! check_libtsm_version; then
		log_warn "libtsm >= 4.3.0 não encontrada, será necessário build"
		BUILD_STATE[need_libtsm_build]=1
	fi

	BUILD_STATE[deps_checked]=1
	log_info "Todas as dependências verificadas"
	return $EXIT_SUCCESS
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

	if version_gte "$version" "4.3.0"; then
		log_info "libtsm version: $version (OK)"
		return 0
	else
		log_warn "libtsm version: $version (requer >= 4.3.0)"
		return 1
	fi
}

# =============================================================================
# FASE 2: DOWNLOAD
# =============================================================================

phase_download() {
	log_info "=== Fase 2: Download de Sources ==="
	CURRENT_PHASE=2

	# Verifica e obtém versões mais recentes se habilitado
	if [[ "$CHECK_LATEST" -eq 1 ]]; then
		log_info "Verificando versões mais recentes via API GitHub..."

		# Verifica kmscon
		local kmscon_api_output
		kmscon_api_output=$(check_latest_version "kmscon" "$KMSCON_API_URL" 2>/dev/null)
		if [[ -n "$kmscon_api_output" ]]; then
			# Extrai versão e URL do output
			local latest_version=$(echo "$kmscon_api_output" | grep "^LATEST_VERSION=" | cut -d'"' -f2)
			local latest_url=$(echo "$kmscon_api_output" | grep "^LATEST_URL=" | cut -d'"' -f2)

			if [[ -n "$latest_version" ]]; then
				BUILD_STATE[kmscon_latest_version]="$latest_version"
				BUILD_STATE[kmscon_latest_url]="$latest_url"

				# Compara versões
				if compare_semantic_versions "$latest_version" "$KMSCON_VERSION"; then
					if [[ "$latest_version" != "$KMSCON_VERSION" ]]; then
						log_warn "Nova versão do kmscon disponível: v${latest_version} (local: v$KMSCON_VERSION)"
						log_info "Usando versão mais recente: v${latest_version}"
					else
						log_info "kmscon já está na versão mais recente: v$KMSCON_VERSION"
					fi
				fi
			else
				log_warn "Não foi possível extrair versão da API do kmscon"
			fi
		else
			log_warn "Não foi possível verificar versão mais recente do kmscon, usando v$KMSCON_VERSION"
		fi

		# Verifica libtsm se necessário
		if [[ "${BUILD_STATE[need_libtsm_build]:-0}" -eq 1 ]]; then
			local libtsm_api_output
			libtsm_api_output=$(check_latest_version "libtsm" "$LIBTSM_API_URL" 2>/dev/null)
			if [[ -n "$libtsm_api_output" ]]; then
				# Extrai versão e URL do output
				local latest_version=$(echo "$libtsm_api_output" | grep "^LATEST_VERSION=" | cut -d'"' -f2)
				local latest_url=$(echo "$libtsm_api_output" | grep "^LATEST_URL=" | cut -d'"' -f2)

				if [[ -n "$latest_version" ]]; then
					BUILD_STATE[libtsm_latest_version]="$latest_version"
					BUILD_STATE[libtsm_latest_url]="$latest_url"

					if compare_semantic_versions "$latest_version" "$LIBTSM_VERSION"; then
						if [[ "$latest_version" != "$LIBTSM_VERSION" ]]; then
							log_warn "Nova versão do libtsm disponível: v${latest_version} (local: v$LIBTSM_VERSION)"
							log_info "Usando versão mais recente: v${latest_version}"
						else
							log_info "libtsm já está na versão mais recente: v$LIBTSM_VERSION"
						fi
					fi
				else
					log_warn "Não foi possível extrair versão da API do libtsm"
				fi
			else
				log_warn "Não foi possível verificar versão mais recente do libtsm, usando v$LIBTSM_VERSION"
			fi
		fi
	fi

	# Download kmscon
	if ! download_kmscon; then
		return $EXIT_DOWNLOAD_FAILED
	fi

	# Download libtsm se necessário
	if [[ "${BUILD_STATE[need_libtsm_build]:-0}" -eq 1 ]]; then
		if ! download_libtsm; then
			return $EXIT_DOWNLOAD_FAILED
		fi
	fi

	BUILD_STATE[download_complete]=1
	log_info "Fase de download concluída"
	return $EXIT_SUCCESS
}

download_kmscon() {
	# Determina qual versão usar
	local effective_version="${BUILD_STATE[kmscon_latest_version]:-$KMSCON_VERSION}"
	local effective_url="${BUILD_STATE[kmscon_latest_url]:-$KMSCON_URL}"

	# Atualiza URL se versão mudou
	if [[ -n "${BUILD_STATE[kmscon_latest_version]:-}" ]]; then
		effective_url="${BUILD_STATE[kmscon_latest_url]}"
	fi

	# Usar formato .tar.gz (formato do tarball_url da API GitHub)
	local filename="kmscon-${effective_version}.tar.gz"
	local cache_file="${CACHE_DIR}/${filename}"
	local version_file="${CACHE_DIR}/.kmscon_version"

	log_info "=== Download do KMSCON ==="
	log_info "Versão configurada: $KMSCON_VERSION"
	log_info "Versão efetiva: $effective_version"
	log_info "URL: $effective_url"

	# Verifica versão em cache
	local cached_version
	cached_version=$(get_cached_version "$version_file")

	# Lógica idempotente: verifica se precisa re-baixar
	local should_download=false

	if [[ "$FORCE_REDOWNLOAD" -eq 1 ]]; then
		log_info "FORCE_REDOWNLOAD=1: Forçando novo download"
		should_download=true
	elif [[ ! -f "$cache_file" ]]; then
		log_info "Arquivo não encontrado em cache, será necessário download"
		should_download=true
	elif [[ "$cached_version" != "$effective_version" ]]; then
		log_info "Versão em cache ($cached_version) diferente da desejada ($effective_version)"
		should_download=true
	elif [[ ! -s "$cache_file" ]]; then
		log_warn "Arquivo em cache está vazio, será necessário novo download"
		should_download=true
	else
		log_info "Usando cache existente: $cache_file (v$cached_version)"
	fi

	# Se precisa baixar, limpa arquivos antigos
	if [[ "$should_download" == true ]]; then
		# Limpa arquivos antigos de versões diferentes
		if [[ -n "$cached_version" && "$cached_version" != "$effective_version" ]]; then
			local old_filename="kmscon-${cached_version}.tar.gz"
			local old_cache_file="${CACHE_DIR}/${old_filename}"

			if [[ -f "$old_cache_file" ]]; then
				log_info "Removendo arquivo de versão anterior: $old_cache_file"
				rm -f "$old_cache_file"
			fi

			# Limpa diretório de build anterior
			local old_build_dir="${BUILD_ROOT}/src"
			if [[ -d "$old_build_dir" ]]; then
				log_info "Limpando diretório de build anterior: $old_build_dir"
				rm -rf "$old_build_dir"
			fi
		fi

		# Download via tarball_url da API (forma oficial, sempre disponível)
		log_info "Iniciando download de kmscon v${effective_version} via API GitHub..."
		if ! download_with_retry "$effective_url" "$cache_file"; then
			log_error "Falha ao baixar kmscon via API GitHub"
			return 1
		fi

		# Salva versão no cache
		save_cached_version "$version_file" "$effective_version"
		log_info "Download concluído e salvo em cache"
	fi

	# Verifica integridade do arquivo (tamanho mínimo)
	local file_size
	file_size=$(stat -c%s "$cache_file" 2>/dev/null || echo "0")
	if [[ $file_size -lt 1024 ]]; then
		log_error "Arquivo baixado muito pequeno (${file_size} bytes), possivelmente corrompido"
		rm -f "$cache_file"
		return 1
	fi

	log_info "Arquivo em cache: $cache_file ($file_size bytes)"

	# Extrai
	local extract_dir="${BUILD_ROOT}/src"
	rm -rf "$extract_dir"
	mkdir -p "$extract_dir"

	log_info "Extraindo ${filename}..."
	# Extrai o tarball .tar.gz da API (mantém estrutura original)
	if ! tar -xzf "$cache_file" -C "$extract_dir" 2>/dev/null; then
		log_error "Falha ao extrair arquivo: $cache_file"
		return 1
	fi

	# O tarball da API extrai como "kmscon-kmscon-XXXXXXX/" (inclui hash do commit)
	# Encontra o diretório real e reorganiza para estrutura esperada
	local extracted_subdir
	extracted_subdir=$(find "$extract_dir" -maxdepth 1 -type d -name "*kmscon*" 2>/dev/null | head -1)
	if [[ -n "$extracted_subdir" && "$extracted_subdir" != "$extract_dir/kmscon" ]]; then
		log_info "Reorganizando estrutura extraída: $(basename "$extracted_subdir") -> kmscon/"
		mv "$extracted_subdir" "$extract_dir/kmscon" 2>/dev/null || true
	fi

	# Verifica se extração foi bem-sucedida
	if [[ ! -f "$extract_dir/meson.build" && ! -f "$extract_dir/kmscon/meson.build" ]]; then
		log_error "Extração parece ter falhado: meson.build não encontrado"
		return 1
	fi

	BUILD_STATE[kmscon_src]="$extract_dir"
	BUILD_STATE[kmscon_version]="$effective_version"
	log_info "kmscon v${effective_version} extraído com sucesso em: $extract_dir"
	return 0
}

download_libtsm() {
	# Determina qual versão usar
	local effective_version="${BUILD_STATE[libtsm_latest_version]:-$LIBTSM_VERSION}"
	local effective_url="${BUILD_STATE[libtsm_latest_url]:-$LIBTSM_URL}"

	# Atualiza URL se versão mudou
	if [[ -n "${BUILD_STATE[libtsm_latest_version]:-}" ]]; then
		effective_url="${BUILD_STATE[libtsm_latest_url]}"
	fi

	# Usar formato .tar.gz (formato do tarball_url da API GitHub)
	local filename="libtsm-${effective_version}.tar.gz"
	local cache_file="${CACHE_DIR}/${filename}"
	local version_file="${CACHE_DIR}/.libtsm_version"

	log_info "=== Download do LIBTSM ==="
	log_info "Versão configurada: $LIBTSM_VERSION"
	log_info "Versão efetiva: $effective_version"
	log_info "URL: $effective_url"

	# Verifica versão em cache
	local cached_version
	cached_version=$(get_cached_version "$version_file")

	# Lógica idempotente: verifica se precisa re-baixar
	local should_download=false

	if [[ "$FORCE_REDOWNLOAD" -eq 1 ]]; then
		log_info "FORCE_REDOWNLOAD=1: Forçando novo download"
		should_download=true
	elif [[ ! -f "$cache_file" ]]; then
		log_info "Arquivo não encontrado em cache, será necessário download"
		should_download=true
	elif [[ "$cached_version" != "$effective_version" ]]; then
		log_info "Versão em cache ($cached_version) diferente da desejada ($effective_version)"
		should_download=true
	elif [[ ! -s "$cache_file" ]]; then
		log_warn "Arquivo em cache está vazio, será necessário novo download"
		should_download=true
	else
		log_info "Usando cache existente: $cache_file (v$cached_version)"
	fi

	# Se precisa baixar, limpa arquivos antigos
	if [[ "$should_download" == true ]]; then
		# Limpa arquivos antigos de versões diferentes
		if [[ -n "$cached_version" && "$cached_version" != "$effective_version" ]]; then
			local old_filename="libtsm-${cached_version}.tar.gz"
			local old_cache_file="${CACHE_DIR}/${old_filename}"

			if [[ -f "$old_cache_file" ]]; then
				log_info "Removendo arquivo de versão anterior: $old_cache_file"
				rm -f "$old_cache_file"
			fi
		fi

		# Limpa diretório de build anterior
		local old_build_dir="${BUILD_ROOT}/src/libtsm-${cached_version}"
		if [[ -d "$old_build_dir" ]]; then
			log_info "Limpando diretório de build anterior: $old_build_dir"
			rm -rf "$old_build_dir"
		fi

		# Download via tarball_url da API (forma oficial, sempre disponível)
		log_info "Iniciando download de libtsm v${effective_version} via API GitHub..."
		if ! download_with_retry "$effective_url" "$cache_file"; then
			log_error "Falha ao baixar libtsm via API GitHub"
			return 1
		fi

		# Salva versão no cache
		save_cached_version "$version_file" "$effective_version"
		log_info "Download concluído e salvo em cache"
	fi

	# Verifica integridade do arquivo
	local file_size
	file_size=$(stat -c%s "$cache_file" 2>/dev/null || echo "0")
	if [[ $file_size -lt 1024 ]]; then
		log_error "Arquivo baixado muito pequeno (${file_size} bytes), possivelmente corrompido"
		rm -f "$cache_file"
		return 1
	fi

	log_info "Arquivo em cache: $cache_file ($file_size bytes)"

	# Extrai
	local extract_dir="${BUILD_ROOT}/src"
	rm -rf "${extract_dir}/libtsm-${effective_version}"
	mkdir -p "$extract_dir"

	log_info "Extraindo ${filename}..."
	if ! tar -xzf "$cache_file" -C "$extract_dir" 2>/dev/null; then
		log_error "Falha ao extrair libtsm"
		return 1
	fi

	# O tarball da API extrai com nome tipo "kmscon-libtsm-XXXXXXX/" (inclui hash do commit)
	# Precisamos encontrar o diretório real que foi criado
	local extracted_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "*libtsm*" 2>/dev/null | head -1)

	if [[ -z "$extracted_dir" ]]; then
		log_error "Diretório extraído não encontrado"
		return 1
	fi

	log_info "Diretório extraído: $(basename "$extracted_dir")"

	# Verifica se extração foi bem-sucedida
	if [[ ! -f "$extracted_dir/meson.build" ]]; then
		log_error "Extração parece ter falhado: meson.build não encontrado em $extracted_dir"
		return 1
	fi

	BUILD_STATE[libtsm_src]="$extracted_dir"
	BUILD_STATE[libtsm_version]="$effective_version"
	log_info "libtsm v${effective_version} extraído com sucesso em: $extracted_dir"
	return 0
}

clone_libtsm_from_git() {
	local effective_version="${BUILD_STATE[libtsm_latest_version]:-$LIBTSM_VERSION}"
	local dest="${BUILD_ROOT}/src/libtsm"

	rm -rf "$dest"
	mkdir -p "$(dirname "$dest")"

	log_info "Clonando libtsm v${effective_version} do git (fallback)..."

	# Tenta clonar a tag específica primeiro (kmscon/libtsm é o repositório oficial)
	local git_url="https://github.com/kmscon/libtsm.git"
	local fallback_url="https://github.com/Aetf/libtsm.git"

	if git clone --depth 1 --branch "v${effective_version}" \
		"$git_url" "$dest" 2>/dev/null; then
		log_info "Clone bem-sucedido de $git_url (tag v${effective_version})"
	elif git clone --depth 1 --branch "v${effective_version}" \
		"$fallback_url" "$dest" 2>/dev/null; then
		log_info "Clone bem-sucedido de $fallback_url (tag v${effective_version})"
	else
		# Fallback para master/main se tag não existe
		log_warn "Tag v${effective_version} não encontrada, tentando branch padrão..."

		if git clone --depth 1 "$git_url" "$dest" 2>/dev/null; then
			log_info "Clone bem-sucedido do branch padrão"
		elif git clone --depth 1 "$fallback_url" "$dest" 2>/dev/null; then
			log_info "Clone bem-sucedido do branch padrão (fallback)"
		else
			log_error "Falha ao clonar libtsm de qualquer fonte"
			return 1
		fi
	fi

	BUILD_STATE[libtsm_src]="$dest"
	BUILD_STATE[libtsm_version]="$effective_version"
	log_info "libtsm clonado em: $dest"
	return 0
}

# Clona kmscon do repositório git (fallback quando download falha)
clone_kmscon_from_git() {
	local effective_version="${1:-$KMSCON_VERSION}"
	local dest="${BUILD_ROOT}/src"

	rm -rf "$dest"
	mkdir -p "$dest"

	log_info "Clonando kmscon v${effective_version} do git (fallback)..."

	# Repositórios a tentar (ordem de preferência)
	local -a git_urls=(
		"https://github.com/Aetf/kmscon.git"   # Fork ativo com atualizações
		"https://github.com/kmscon/kmscon.git" # Repositório oficial
	)

	local cloned=false

	for git_url in "${git_urls[@]}"; do
		log_info "Tentando clonar de: $git_url"

		# Tenta clonar a tag específica
		if git clone --depth 1 --branch "v${effective_version}" \
			"$git_url" "$dest" 2>/dev/null; then
			log_info "Clone bem-sucedido de $git_url (tag v${effective_version})"
			cloned=true
			break
		fi

		# Tenta branch master/main se tag não existe
		log_warn "Tag não encontrada, tentando branch padrão..."
		if git clone --depth 1 "$git_url" "$dest" 2>/dev/null; then
			log_info "Clone bem-sucedido do branch padrão de $git_url"
			cloned=true
			break
		fi
	done

	if [[ "$cloned" != "true" ]]; then
		log_error "Falha ao clonar kmscon de qualquer fonte"
		return 1
	fi

	# Verifica se extração foi bem-sucedida
	if [[ ! -f "$dest/meson.build" ]]; then
		# Tenta encontrar subdiretório
		local subdir
		subdir=$(find "$dest" -maxdepth 2 -name "meson.build" -printf "%h\n" 2>/dev/null | head -1)
		if [[ -n "$subdir" && "$subdir" != "$dest" ]]; then
			log_info "Reorganizando estrutura clonada..."
			mv "$subdir"/* "$dest/" 2>/dev/null || true
		elif [[ ! -f "$dest/meson.build" ]]; then
			log_error "meson.build não encontrado após clone"
			return 1
		fi
	fi

	BUILD_STATE[kmscon_src]="$dest"
	BUILD_STATE[kmscon_version]="$effective_version"
	log_info "kmscon v${effective_version} clonado com sucesso em: $dest"
	return 0
}

# =============================================================================
# FASE 3: DEPENDÊNCIAS (BUILD LIBTSM)
# =============================================================================

phase_deps() {
	log_info "=== Fase 3: Build de Dependências ==="
	CURRENT_PHASE=3

	if [[ "${BUILD_STATE[need_libtsm_build]:-0}" -eq 1 ]]; then
		if ! build_libtsm; then
			return $EXIT_BUILD_FAILED
		fi
	fi

	BUILD_STATE[deps_complete]=1
	log_info "Fase de dependências concluída"
	return $EXIT_SUCCESS
}

build_libtsm() {
	local src_dir="${BUILD_STATE[libtsm_src]}"
	local build_dir="${BUILD_ROOT}/build/libtsm"

	log_info "Compilando libtsm..."

	rm -rf "$build_dir"
	mkdir -p "$build_dir"

	cd "$src_dir" || return 1

	# Configura
	log_info "Configurando libtsm com meson..."
	meson setup "$build_dir" \
		--prefix=/usr \
		--buildtype=release \
		-Ddocs=false \
		-Dtests=false || {
		log_error "Falha na configuração do libtsm"
		return 1
	}

	# Build
	log_info "Compilando libtsm com ninja..."
	ninja -C "$build_dir" -j "$PARALLEL_JOBS" || {
		log_error "Falha no build do libtsm"
		return 1
	}

	# Instala no sistema (necessário para build do kmscon)
	log_info "Instalando libtsm no sistema..."
	ninja -C "$build_dir" install || {
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

	if [[ ! -d "$PATCHES_DIR" ]]; then
		log_info "Nenhum diretório de patches encontrado, pulando"
		BUILD_STATE[patch_complete]=1
		return $EXIT_SUCCESS
	fi

	cd "$src_dir" || return 1

	local -a patches=("$PATCHES_DIR"/*.diff "$PATCHES_DIR"/*.patch)
	local applied=0
	local failed=0

	for patch in "${patches[@]}"; do
		[[ -f "$patch" ]] || continue

		local patch_name
		patch_name=$(basename "$patch")
		log_info "Aplicando patch: $patch_name"

		# Testa primeiro
		if patch -p1 --dry-run <"$patch" &>/dev/null; then
			if patch -p1 <"$patch"; then
				log_info "Patch aplicado: $patch_name"
				((applied++))
			else
				log_warn "Falha ao aplicar patch: $patch_name"
				((failed++))
			fi
		else
			log_warn "Patch não aplicável (pode já estar aplicado): $patch_name"
		fi
	done

	log_info "Patches aplicados: $applied, falhas: $failed"
	BUILD_STATE[patch_complete]=1
	return $EXIT_SUCCESS
}

# =============================================================================
# FASE 5: CONFIGURAÇÃO
# =============================================================================

phase_configure() {
	log_info "=== Fase 5: Configuração do Build ==="
	CURRENT_PHASE=5

	local src_dir="${BUILD_STATE[kmscon_src]}"
	local build_dir="${BUILD_ROOT}/build/kmscon"

	rm -rf "$build_dir"
	mkdir -p "$build_dir"

	cd "$src_dir" || return 1

	log_info "Configurando meson..."
	log_debug "Flags: video_drm3d=enabled, renderer_gltex=enabled, font_pango=enabled"

	# Configura meson com todas as flags obrigatórias
	meson setup "$build_dir" \
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
		return $EXIT_CONFIGURE_FAILED
	}

	# Verifica se features foram habilitadas
	if ! verify_features "$build_dir"; then
		return $EXIT_FEATURE_MISSING
	fi

	BUILD_STATE[configure_complete]=1
	BUILD_STATE[build_dir]="$build_dir"
	log_info "Configuração concluída"
	return $EXIT_SUCCESS
}

verify_features() {
	local build_dir="$1"
	local info_file="${build_dir}/meson-info/build-info.json"

	log_info "Verificando features habilitadas..."

	if [[ ! -f "$info_file" ]]; then
		log_warn "Arquivo de info do meson não encontrado, pulando verificação"
		return 0
	fi

	local all_ok=true
	for feature in "${REQUIRED_FEATURES[@]}"; do
		# Verifica no meson-logs ou no introspect
		if grep -q "${feature}=enabled" "$info_file" 2>/dev/null ||
			meson introspect "$build_dir" --buildoptions 2>/dev/null | grep -q "${feature}.*enabled"; then
			log_info "  ✓ $feature: enabled"
		else
			log_warn "  ✗ $feature: não habilitado"
			all_ok=false
		fi
	done

	if [[ "$all_ok" == "false" ]]; then
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

	log_info "Iniciando build com ninja (jobs: $PARALLEL_JOBS)..."

	if ! ninja -C "$build_dir" -j "$PARALLEL_JOBS" 2>&1 | tee -a "$LOG_FILE"; then
		log_error "Falha na compilação"
		return $EXIT_BUILD_FAILED
	fi

	# Verifica se binário foi criado
	if [[ ! -f "${build_dir}/kmscon" ]]; then
		# Tenta encontrar o binário
		local binary
		binary=$(find "$build_dir" -name "kmscon" -type f -executable 2>/dev/null | head -1)
		if [[ -z "$binary" ]]; then
			log_error "Binário kmscon não encontrado após build"
			return $EXIT_BUILD_FAILED
		fi
		BUILD_STATE[binary_path]="$binary"
	else
		BUILD_STATE[binary_path]="${build_dir}/kmscon"
	fi

	log_info "Build concluído: ${BUILD_STATE[binary_path]}"
	BUILD_STATE[build_complete]=1
	return $EXIT_SUCCESS
}

# =============================================================================
# FASE 7: EMPACOTAMENTO
# =============================================================================

phase_package() {
	log_info "=== Fase 7: Empacotamento ==="
	CURRENT_PHASE=7

	if ! create_deb_structure; then
		return $EXIT_PACKAGE_FAILED
	fi

	if ! generate_control; then
		return $EXIT_PACKAGE_FAILED
	fi

	if ! copy_build_artifacts; then
		return $EXIT_PACKAGE_FAILED
	fi

	if ! build_deb; then
		return $EXIT_PACKAGE_FAILED
	fi

	BUILD_STATE[package_complete]=1
	log_info "Fase de empacotamento concluída"
	return $EXIT_SUCCESS
}

create_deb_structure() {
	log_info "Criando estrutura de pacote DEB..."

	rm -rf "$PACKAGE_ROOT"
	mkdir -p "${PACKAGE_ROOT}/DEBIAN"
	mkdir -p "${PACKAGE_ROOT}/usr/bin"
	mkdir -p "${PACKAGE_ROOT}/usr/lib"
	mkdir -p "${PACKAGE_ROOT}/etc/kmscon"
	mkdir -p "${PACKAGE_ROOT}/etc/systemd/system"
	mkdir -p "${PACKAGE_ROOT}/usr/share/doc/kmscon"
	mkdir -p "${PACKAGE_ROOT}/usr/share/kmscon"

	# Definir permissões seguras para estrutura de pacote
	chmod 755 "${PACKAGE_ROOT}" || {
		log_error "Falha ao definir permissões do diretório PACKAGE_ROOT"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/DEBIAN" || {
		log_error "Falha ao definir permissões do diretório DEBIAN"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/usr/bin" || {
		log_error "Falha ao definir permissões do diretório usr/bin"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/usr/lib" || {
		log_error "Falha ao definir permissões do diretório usr/lib"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/etc/kmscon" || {
		log_error "Falha ao definir permissões do diretório etc/kmscon"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/etc/systemd/system" || {
		log_error "Falha ao definir permissões do diretório etc/systemd/system"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/usr/share/doc/kmscon" || {
		log_error "Falha ao definir permissões do diretório usr/share/doc/kmscon"
		return 1
	}
	chmod 755 "${PACKAGE_ROOT}/usr/share/kmscon" || {
		log_error "Falha ao definir permissões do diretório usr/share/kmscon"
		return 1
	}

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
		[[ -f "$lib" ]] || continue
		cp "$lib" "${PACKAGE_ROOT}/usr/lib/"
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

	mkdir -p "$OUTPUT_DIR"

	# Constrói o pacote
	if ! dpkg-deb --build "$PACKAGE_ROOT" "$deb_path"; then
		log_error "Falha ao construir pacote .deb"
		return 1
	fi

	BUILD_STATE[deb_path]="$deb_path"
	log_info "Pacote criado: $deb_path"

	# Verifica pacote
	if command -v lintian &>/dev/null; then
		log_info "Verificando pacote com lintian..."
		lintian "$deb_path" 2>/dev/null || log_warn "Lintian reportou warnings"
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

	if ! install_package "$deb_path"; then
		return $EXIT_INSTALL_FAILED
	fi

	if ! configure_systemd; then
		return $EXIT_SYSTEMD_FAILED
	fi

	if ! verify_installation; then
		return $EXIT_INSTALL_FAILED
	fi

	BUILD_STATE[install_complete]=1
	log_info "Instalação concluída com sucesso!"
	return $EXIT_SUCCESS
}

install_package() {
	local deb_path="$1"

	log_info "Instalando pacote: $deb_path"

	if ! dpkg -i "$deb_path"; then
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
	for vt in $KMSCON_VTS; do
		log_info "Configurando $vt para usar kmscon..."

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

Script de build do KMSCON para Debian 13 Trixie
Com suporte a download idempotente e verificação de versão via API GitHub

OPÇÕES:
    -h, --help          Mostra esta ajuda
    -v, --version       Mostra versão do script
    -k, --keep          Mantém diretório de build após conclusão
    -c, --clean         Limpa cache e build antes de iniciar
    -f, --force         Força re-download das fontes
    -j, --jobs N        Número de jobs paralelos (padrão: auto)
    -l, --log-level     Nível de log: DEBUG, INFO, WARN, ERROR (padrão: INFO)
    -o, --output DIR    Diretório de saída para o pacote .deb
    --no-check-latest   Desabilita verificação de versão via API GitHub

VARIÁVEIS DE AMBIENTE:
    KMSCON_VERSION          Versão do kmscon (padrão: ${KMSCON_VERSION})
    LIBTSM_VERSION          Versão do libtsm (padrão: ${LIBTSM_VERSION})
    KMSCON_URL              URL alternativa para download do kmscon
    LIBTSM_URL              URL alternativa para download do libtsm
    PARALLEL_JOBS           Jobs paralelos (padrão: auto)
    KEEP_BUILD              Manter build (1=sim, 0=não)
    LOG_LEVEL               Nível de log
    CHECK_LATEST            Verificar última versão via API (1=sim, 0=não, padrão: 1)
    FORCE_REDOWNLOAD        Forçar re-download (1=sim, 0=não, padrão: 0)
    DOWNLOAD_RETRY_COUNT    Número de tentativas de download (padrão: 3)
    DOWNLOAD_RETRY_DELAY    Delay inicial entre retries em segundos (padrão: 5)

EXEMPLOS:
    ${SCRIPT_NAME}                    # Build completo
    ${SCRIPT_NAME} -j 4               # Build com 4 jobs
    ${SCRIPT_NAME} -c -k              # Limpa cache, mantém build
    ${SCRIPT_NAME} -f                 # Força re-download das fontes
    CHECK_LATEST=0 ${SCRIPT_NAME}     # Desabilita check de versão

EOF
}

show_version() {
	printf '%s\n' "${SCRIPT_NAME} versão ${SCRIPT_VERSION}"
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
			rm -rf "$CACHE_DIR" "$BUILD_ROOT" "$OUTPUT_DIR"
			shift
			;;
		-f | --force)
			FORCE_REDOWNLOAD=1
			log_info "Forçando re-download das fontes"
			shift
			;;
		--no-check-latest)
			CHECK_LATEST=0
			log_info "Verificação de versão via API desabilitada"
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
	log_info "CHECK_LATEST: ${CHECK_LATEST}"
	log_info "FORCE_REDOWNLOAD: ${FORCE_REDOWNLOAD}"
	log_info "DOWNLOAD_RETRY_COUNT: ${DOWNLOAD_RETRY_COUNT}"
	log_info "CACHE_DIR: ${CACHE_DIR}"
	log_info "================================================"

	# Fase 1: Ambiente
	check_environment || exit $?

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
	if [[ -n "${BUILD_STATE[kmscon_version]:-}" ]]; then
		log_info "Versão KMSCON: ${BUILD_STATE[kmscon_version]}"
	fi
	if [[ -n "${BUILD_STATE[libtsm_version]:-}" ]]; then
		log_info "Versão LIBTSM: ${BUILD_STATE[libtsm_version]}"
	fi
	log_info "================================================"

	return $EXIT_SUCCESS
}

# Executa main
main "$@"
