# Convenções de Código - DEBIAN_ISO_PROJECT

## Estilo Bash (Pure Bash Bible)

### Princípios Fundamentais

- **Evitar subshells desnecessárias**: Não usar $(cat file), use $(<file)
- **Evitar pipes quando possível**: Use redirecionamento ou process substitution
- **Usar arrays ao invés de strings concatenadas**: Melhor performance e segurança
- **Parameter expansion ao invés de awk/sed/cut**: Mais rápido e eficiente

### Exemplos de Pure Bash

```bash
# ❌ Evitar: Usando comandos externos
disk=$(echo "$line" | awk '{print $1}')

# ✅ Preferir: Parameter expansion
disk="${line%% *}"

# ❌ Evitar: Concatenação de strings
local list=""
for item in "${items[@]}"; do
    list="$list$item\n"
done

# ✅ Preferir: Arrays
local -a list=()
for item in "${items[@]}"; do
    list+=("$item")
done
local IFS=$'\n'
local list_str="${list[*]}"

# ❌ Evitar: seq + printf para repetição
printf '%s\n' "$(seq 10 | xargs -I{} echo -n '=')"

# ✅ Preferir: Loop puro
repeat_char() {
    local char="$1" count="$2"
    local result=""
    for ((i=0; i<count; i++)); do
        result+="$char"
    done
    printf '%s' "$result"
}
```

## Strict Mode

```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
```

## Nomenclatura

### Variáveis

- **Constantes/Readonly**: `UPPER_CASE` (ex: `POOL_NAME`, `ZFS_OPTS`)
- **Variáveis locais**: `lower_case` (ex: `target_disk`, `hostname`)
- **Arrays**: `lowercase_array` (ex: `zfs_opts`, `disk_array`)
- **Flags booleanas**: `true/false` (ex: `MOCK_MODE=false`)

### Funções

- **Funções privadas**: `_function_name` (com underscore)
- **Funções públicas**: `function_name`
- **Handlers**: `cleanup`, `cleanup_interrupted`

## Sistema de UI (AURORA)

### Constantes de Cores (ANSI 256)

```bash
# Fundos
readonly DS_VOID=235
readonly DS_DEPTH=237
readonly DS_ELEVATION=239

# Bordas
readonly DS_WHISPER=240
readonly DS_MIST=243

# Textos
readonly DS_FOG=245
readonly DS_HAZE=248
readonly DS_CLOUD=250
readonly DS_SILVER=252

# Acentos
readonly DS_SLATE=67
readonly DS_AURORA_PEAK=153

# Funcionais
readonly DS_SUCCESS=108
readonly DS_WARNING=179
readonly DS_ERROR=167
```

### Caracteres UI

```bash
readonly UI_H='─'           # Horizontal line
readonly UI_H_D='═'         # Double horizontal
readonly UI_ARROW='▶'       # Bullet point
readonly UI_BULLET='●'      # List bullet
readonly UI_CHECK='✓'       # Success check
readonly UI_WARN='⚠'        # Warning
```

## Estrutura de Funções

```bash
# Função com documentação implícita
function_name() {
    local arg1="$1"
    local arg2="${2:-default}"

    # Código
    if [[ condition ]]; then
        return 0
    else
        return 1
    fi
}
```

## Tratamento de Erros

```bash
# Usar error_box para erros amigáveis
error_box() {
    printf '\n'
    gum style \
        --foreground "$DS_ERROR" \
        --border-foreground "$DS_ERROR" \
        --border double \
        --padding "1 2" \
        --margin "1 2" \
        --align center \
        "$UI_WARN ERRO" \
        "" \
        "$1"
}

# Verificar erros com run_step
run_step() {
    local title="$1"
    shift

    if ! gum spin \
        --spinner minidot \
        --title "$title" \
        -- "$@"; then
        error_box "Falha ao executar: $title"
        exit 1
    fi
}
```

## Cleanup e Tratamento de Sinais

```bash
cleanup() {
    local exit_code=$?

    # Unmount em ordem reversa
    [[ -d /mnt/boot/efi ]] && umount /mnt/boot/efi 2>/dev/null || true
    [[ -d /mnt/dev ]] && umount /mnt/dev 2>/dev/null || true

    # Export pool se importado
    zpool list "$POOL_NAME" &>/dev/null && zpool export "$POOL_NAME" 2>/dev/null || true

    exit $exit_code
}

trap cleanup EXIT
trap cleanup_interrupted INT TERM
```

## Comentários

- Usar `#` para comentários inline
- Usar `##` para comentários de seção maiores
- Usar comentários em português (padrão do projeto)

## Formatação

- Indentação: 4 espaços (não tabs)
- Linha máxima: ~100 caracteres
- Separadores visuais para seções

```bash
# ═══════════════════════════════════════════════════════════════════════════════
# SEÇÃO: Nome da Seção
# ═══════════════════════════════════════════════════════════════════════════════
```

## Validação de Entrada

```bash
# Validar hostname
validate_hostname() {
    local hostname="$1"
    hostname=$(trim_string "$hostname")
    [[ -z "$hostname" ]] && return 1
    [[ ${#hostname} -gt 253 ]] && return 1
    [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]] && return 1
    return 0
}

# Trim whitespace
trim_string() {
    local tmp="$1"
    tmp="${tmp#"${tmp%%[![:space:]]*}"}"
    tmp="${tmp%%"${tmp##*[![:space:]]}"}"
    printf '%s' "$tmp"
}
```
