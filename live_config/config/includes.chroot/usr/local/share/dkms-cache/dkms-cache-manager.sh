#!/usr/bin/env bash
# =============================================================================
# DKMS Cache Manager - Gerenciamento de Cache com File Locking
# =============================================================================
# Descrição: Gerencia operações de cache DKMS com proteção contra concorrência
# Uso: dkms-cache-manager.sh [operacao] [args...]
# Versão: 1.0.0
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================

readonly CACHE_BASE_DIR="${DKMS_CACHE_BASE:-/var/cache/dkms-build}"
readonly LOCK_DIR="${CACHE_BASE_DIR}/.locks"
readonly LOCK_TIMEOUT="${DKMS_LOCK_TIMEOUT:-300}"  # 5 minutos padrão
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="${CACHE_BASE_DIR}/.cache-manager.log"

# Cores para output (se terminal)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# =============================================================================
# VERIFICAÇÃO DE DEPENDÊNCIAS
# =============================================================================

check_dependencies() {
    local deps=("flock" "find" "du" "mkdir" "rm" "touch" "cat" "date")
    local missing=()

    for dep in "${deps[@]}"; do
    do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dependências faltando: ${missing[*]}"
        log_error "Instale as dependências necessárias antes de continuar."
        return 1
    fi

    return 0
}

# =============================================================================
# FUNÇÕES DE LOGGING
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    printf '%s\n' "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    if [[ -t 1 ]]; then
        case "$level" in
            ERROR) printf '%b\n' "${RED}[$level]${NC} $message" >&2 ;;
            WARN)  printf '%b\n' "${YELLOW}[$level]${NC} $message" ;;
            INFO)  printf '%s\n' "[$level] $message" ;;
            DEBUG) [[ "${DKMS_CACHE_DEBUG:-0}" == "1" ]] && printf '%s\n' "[$level] $message" ;;
        esac
    fi
}

log_error() { log "ERROR" "$@"; }
log_warn()  { log "WARN" "$@"; }
log_info()  { log "INFO" "$@"; }
log_debug() { log "DEBUG" "$@"; }

# =============================================================================
# FUNÇÕES DE LOCKING
# =============================================================================

# Cria um lock exclusivo para uma operação no cache
# Uso: acquire_lock [nome_do_lock] [timeout_segundos]
# Retorna: file descriptor do lock em stdout, ou erro
acquire_lock() {
    local lock_name="${1:-global}"
    local timeout="${2:-$LOCK_TIMEOUT}"
    local lock_file="${LOCK_DIR}/${lock_name}.lock"
    local fallback_lock_file="/tmp/dkms-cache-${lock_name}.lock"
    local lock_fd
    local used_fallback=false
    
    # Garante que diretório de locks existe (com fallback para /tmp)
    if ! mkdir -p "$LOCK_DIR" 2>/dev/null; then
        log_warn "Não foi possível criar diretório de locks: $LOCK_DIR"
        log_info "Usando diretório fallback: /tmp"
        lock_file="$fallback_lock_file"
        used_fallback=true
    fi
    
    # Verifica se diretório tem permissão de escrita
    if [[ "$used_fallback" != "true" ]] && [[ ! -w "$LOCK_DIR" ]]; then
        log_warn "Diretório de locks sem permissão de escrita: $LOCK_DIR"
        log_info "Usando diretório fallback: /tmp"
        lock_file="$fallback_lock_file"
        used_fallback=true
    fi
    
    log_debug "Tentando adquirir lock: $lock_name (timeout: ${timeout}s, fallback: $used_fallback)"
    
    # Tenta abrir/criar arquivo de lock
    exec {lock_fd}>"$lock_file" 2>/dev/null || {
        # Se falhou no diretório principal, tenta fallback
        if [[ "$used_fallback" != "true" ]]; then
            log_warn "Falha ao criar lock em $lock_file, tentando fallback..."
            lock_file="$fallback_lock_file"
            exec {lock_fd}>"$lock_file" 2>/dev/null || {
                log_error "Não foi possível criar arquivo de lock mesmo em fallback: $lock_file"
                return 1
            }
        else
            log_error "Não foi possível criar arquivo de lock: $lock_file"
            return 1
        fi
    }
    
    # Tenta adquirir lock exclusivo com timeout
    local flock_result
    if ! flock_result=$(flock -w "$timeout" -x "$lock_fd" 2>&1); then
        log_error "Timeout aguardando lock '$lock_name' após ${timeout}s: $flock_result"
        exec {lock_fd}>&- 2>/dev/null || true
        return 1
    fi
    
    log_debug "Lock adquirido: $lock_name (fd: $lock_fd, fallback: $used_fallback)"
    
    # Retorna o file descriptor para o caller usar
    printf '%s\n' "$lock_fd"
    return 0
}

# Libera um lock previamente adquirido
# Uso: release_lock [file_descriptor]
release_lock() {
    local lock_fd="$1"
    
    if [[ -n "$lock_fd" ]] && [[ "$lock_fd" =~ ^[0-9]+$ ]]; then
        log_debug "Liberando lock (fd: $lock_fd)"
        flock -u "$lock_fd" 2>/dev/null || true
        exec {lock_fd}>&- 2>/dev/null || true
    fi
}

# Executa um comando com lock automático
# Uso: with_lock [nome_do_lock] [comando...]
with_lock() {
    local lock_name="$1"
    shift
    local lock_fd
    local exit_code=0
    
    if ! lock_fd=$(acquire_lock "$lock_name"); then
        return 1
    fi
    
    # Executa o comando com lock ativo
    set +e
    "$@"
    exit_code=$?
    set -e
    
    release_lock "$lock_fd"
    
    return $exit_code
}

# =============================================================================
# FUNÇÕES DE CACHE
# =============================================================================

# Inicializa estrutura de diretórios do cache
init_cache_structure() {
    log_info "Inicializando estrutura de cache DKMS..."
    
    local dirs=(
        "${CACHE_BASE_DIR}/ccache"
        "${CACHE_BASE_DIR}/dkms"
        "${CACHE_BASE_DIR}/modules"
        "${CACHE_BASE_DIR}/headers"
        "${CACHE_BASE_DIR}/.locks"
        "${CACHE_BASE_DIR}/.metadata"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || {
                log_error "Falha ao criar diretório: $dir"
                return 1
            }
            log_debug "Diretório criado: $dir"
        fi
    done
    
    # Configura permissões
    chmod 755 "$CACHE_BASE_DIR"
    chmod 750 "${CACHE_BASE_DIR}/.locks"
    
    log_info "Estrutura de cache inicializada em: $CACHE_BASE_DIR"
    return 0
}

# Retorna o caminho do cache para um módulo/kernel específico
get_cache_path() {
    local module_name="$1"
    local module_version="$2"
    local kernel_version="${3:-$(uname -r)}"

    printf '%s\n' "${CACHE_BASE_DIR}/modules/${module_name}/${module_version}/${kernel_version}"
}

# Verifica se existe cache válido para um módulo
has_cached_module() {
    local module_name="$1"
    local module_version="$2"
    local kernel_version="${3:-$(uname -r)}"
    local cache_path
    cache_path=$(get_cache_path "$module_name" "$module_version" "$kernel_version")
    
    [[ -d "$cache_path" ]] && [[ -f "${cache_path}/.valid" ]]
}

# Marca cache como válido
mark_cache_valid() {
    local cache_path="$1"
    local checksum="${2:-}"
    
    touch "${cache_path}/.valid"
    
    if [[ -n "$checksum" ]]; then
        printf '%s\n' "$checksum" > "${cache_path}/.checksum"
    fi
    
    # Registra metadados
    cat > "${cache_path}/.metadata" << EOF
{"cached_at": "$(date -Iseconds)", "by": "${SCRIPT_NAME}", "host": "$(hostname)"}
EOF
}

# Marca cache como inválido
mark_cache_invalid() {
    local cache_path="$1"
    
    rm -f "${cache_path}/.valid"
    rm -f "${cache_path}/.checksum"
}

# Limpa entradas de cache antigas (mais de N dias)
cleanup_old_cache() {
    local max_age_days="${1:-30}"
    local deleted_count=0
    
    log_info "Limpando cache com mais de $max_age_days dias..."
    
    # Procura por diretórios de módulos e remove os antigos
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]]; then
            log_debug "Removendo cache antigo: $dir"
            rm -rf "$dir"
            ((deleted_count++)) || true
        fi
    done < <(find "${CACHE_BASE_DIR}/modules" -type d -mtime "+${max_age_days}" -print0 2>/dev/null || true)
    
    log_info "Limpeza concluída. $deleted_count entradas removidas."
    return 0
}

# Obtém estatísticas do cache
get_cache_stats() {
    local total_size
    local module_count
    
    total_size=$(du -sh "$CACHE_BASE_DIR" 2>/dev/null | cut -f1 || echo "N/A")
    module_count=$(find "${CACHE_BASE_DIR}/modules" -name ".valid" 2>/dev/null | wc -l)
    
    cat << EOF
{
    "cache_base": "$CACHE_BASE_DIR",
    "total_size": "$total_size",
    "cached_modules": $module_count,
    "timestamp": "$(date -Iseconds)"
}
EOF
}

# =============================================================================
# COMANDOS PRINCIPAIS
# =============================================================================

cmd_init() {
    with_lock "global" init_cache_structure
}

cmd_stats() {
    get_cache_stats
}

cmd_cleanup() {
    local days="${1:-30}"
    with_lock "global" cleanup_old_cache "$days"
}

cmd_check() {
    local module_name="$1"
    local module_version="$2"
    local kernel_version="${3:-$(uname -r)}"

    if has_cached_module "$module_name" "$module_version" "$kernel_version"; then
        printf '%s\n' "CACHED: $(get_cache_path "$module_name" "$module_version" "$kernel_version")"
        return 0
    else
        printf '%s\n' "MISS: ${module_name}-${module_version}@${kernel_version}"
        return 1
    fi
}

cmd_invalidate() {
    local module_name="$1"
    local module_version="$2"
    local kernel_version="${3:-}"
    
    if [[ -z "$kernel_version" ]]; then
        # Invalida todas as versões do kernel para este módulo
        local module_base="${CACHE_BASE_DIR}/modules/${module_name}/${module_version}"
        if [[ -d "$module_base" ]]; then
            with_lock "${module_name}" rm -rf "$module_base"
            log_info "Cache invalidado para ${module_name}-${module_version} (todas versões de kernel)"
        fi
    else
        local cache_path
        cache_path=$(get_cache_path "$module_name" "$module_version" "$kernel_version")
        if [[ -d "$cache_path" ]]; then
            with_lock "${module_name}" mark_cache_invalid "$cache_path"
            log_info "Cache invalidado para ${module_name}-${module_version}@${kernel_version}"
        fi
    fi
}

# =============================================================================
# USAGE E MAIN
# =============================================================================

usage() {
    cat << EOF
Uso: $SCRIPT_NAME [comando] [args...]

Comandos:
    init                    Inicializa estrutura de cache
    stats                   Mostra estatísticas do cache
    cleanup [dias]          Remove entradas mais antigas que N dias (padrão: 30)
    check <mod> <ver> [kv]  Verifica se módulo está em cache
    invalidate <mod> <ver> [kv]  Invalida cache de um módulo
    help                    Mostra esta ajuda

Variáveis de ambiente:
    DKMS_CACHE_BASE         Diretório base do cache (padrão: /var/cache/dkms-build)
    DKMS_LOCK_TIMEOUT       Timeout para aquisição de locks em segundos (padrão: 300)
    DKMS_CACHE_DEBUG        Habilita logs de debug (0/1, padrão: 0)

Exemplos:
    $SCRIPT_NAME init
    $SCRIPT_NAME check zfs-dkms 2.2.7 6.12.12-amd64
    $SCRIPT_NAME invalidate zfs-dkms 2.2.7
    $SCRIPT_NAME cleanup 7
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    # Verificar dependências antes de executar qualquer comando
    check_dependencies || exit 1

    local command="$1"
    shift

    case "$command" in
        init)
            cmd_init
            ;;
        stats)
            cmd_stats
            ;;
        cleanup)
            cmd_cleanup "${1:-30}"
            ;;
        check)
            if [[ $# -lt 2 ]]; then
                log_error "Uso: check <module_name> <module_version> [kernel_version]"
                exit 1
            fi
            cmd_check "$@"
            ;;
        invalidate)
            if [[ $# -lt 2 ]]; then
                log_error "Uso: invalidate <module_name> <module_version> [kernel_version]"
                exit 1
            fi
            cmd_invalidate "$@"
            ;;
        help|--help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Comando desconhecido: $command"
            usage
            exit 1
            ;;
    esac
}

# Exporta funções para uso por outros scripts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
