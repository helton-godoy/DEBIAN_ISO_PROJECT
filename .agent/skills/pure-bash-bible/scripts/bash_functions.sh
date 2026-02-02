#!/usr/bin/env bash
# shellcheck disable=SC2162,SC2034
#
# =============================================================================
# Pure Bash Bible - Biblioteca de Funções Bash
# =============================================================================
#
# Descrição:    Coleção completa de funções Bash puras, sem dependências
#               externas. Baseado no projeto pure-bash-bible de Dylan Araps.
#
# Autor:        Dylan Araps (original), Adaptado para skill
# Licença:      MIT
# Versão Bash:  4.0+ (algumas funções funcionam em 3.2+)
#
# Uso:          source bash_functions.sh
#               ou: ./bash_functions.sh
#
# =============================================================================

# =============================================================================
# SEÇÃO 1: MANIPULAÇÃO DE STRINGS
# =============================================================================

#------------------------------------------------------------------------------
# trim_string - Remove espaços em branco do início e fim da string
# Uso: trim_string "   exemplo   string    "
# Retorna: "exemplo   string"
#------------------------------------------------------------------------------
trim_string() {
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%%"${_##*[![:space:]]}"}"
    printf '%s\n' "${_}"
}

#------------------------------------------------------------------------------
# trim_all - Remove todos os espaços em branco extras da string
# Uso: trim_all "   exemplo   string    "
# Retorna: "exemplo string"
#------------------------------------------------------------------------------
# shellcheck disable=SC2086,SC2048
trim_all() {
    set -f
    set -- $*
    printf '%s\n' "$*"
    set +f
}

#------------------------------------------------------------------------------
# regex - Aplica regex em uma string e retorna o primeiro grupo capturado
# Uso: regex "string" "padrão_regex"
# Retorna: Grupo capturado ou vazio se não houver match
# AVISO: Depende do motor regex do sistema. Use POSIX regex para compatibilidade.
#------------------------------------------------------------------------------
regex() {
    [[ $1 =~ $2 ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}

#------------------------------------------------------------------------------
# split - Divide uma string em um array usando delimitador
# Uso: split "string" "delimitador"
# Retorna: Elementos do array, um por linha
# Requer: Bash 4+
#------------------------------------------------------------------------------
split() {
    IFS=$'\n' read -d "" -ra arr <<< "${1//$2/$'\n'}"
    printf '%s\n' "${arr[@]}"
}

#------------------------------------------------------------------------------
# lower - Converte string para minúsculas
# Uso: lower "STRING"
# Retorna: "string"
# Requer: Bash 4+
#------------------------------------------------------------------------------
lower() {
    printf '%s\n' "${1,,}"
}

#------------------------------------------------------------------------------
# upper - Converte string para maiúsculas
# Uso: upper "string"
# Retorna: "STRING"
# Requer: Bash 4+
#------------------------------------------------------------------------------
upper() {
    printf '%s\n' "${1^^}"
}

#------------------------------------------------------------------------------
# reverse_case - Inverte o case de cada caractere
# Uso: reverse_case "HeLlO"
# Retorna: "hElLo"
# Requer: Bash 4+
#------------------------------------------------------------------------------
reverse_case() {
    # shellcheck disable=SC2295
    printf '%s\n' "${1~~}"
}

#------------------------------------------------------------------------------
# trim_quotes - Remove aspas simples e duplas de uma string
# Uso: trim_quotes "'Hello', \"World\""
# Retorna: "Hello, World"
#------------------------------------------------------------------------------
trim_quotes() {
    : "${1//\'}"
    printf '%s\n' "${_//\"}"
}

#------------------------------------------------------------------------------
# strip_all - Remove todas as ocorrências de um padrão da string
# Uso: strip_all "The Quick Brown Fox" "[aeiou]"
# Retorna: "Th Qck Brwn Fx"
#------------------------------------------------------------------------------
strip_all() {
    printf '%s\n' "${1//$2}"
}

#------------------------------------------------------------------------------
# strip - Remove a primeira ocorrência de um padrão da string
# Uso: strip "The Quick Brown Fox" "[aeiou]"
# Retorna: "Th Quick Brown Fox"
#------------------------------------------------------------------------------
strip() {
    printf '%s\n' "${1/$2}"
}

#------------------------------------------------------------------------------
# lstrip - Remove padrão do início da string (left strip)
# Uso: lstrip "The Quick Brown Fox" "The "
# Retorna: "Quick Brown Fox"
#------------------------------------------------------------------------------
lstrip() {
    printf '%s\n' "${1##"$2"}"
}

#------------------------------------------------------------------------------
# rstrip - Remove padrão do final da string (right strip)
# Uso: rstrip "The Quick Brown Fox" " Fox"
# Retorna: "The Quick Brown"
#------------------------------------------------------------------------------
rstrip() {
    printf '%s\n' "${1%%"$2"}"
}

#------------------------------------------------------------------------------
# urlencode - Codifica uma string para URL (percent-encoding)
# Uso: urlencode "https://github.com/user/repo"
# Retorna: "https%3A%2F%2Fgithub.com%2Fuser%2Frepo"
#------------------------------------------------------------------------------
urlencode() {
    local LC_ALL=C
    for ((i = 0; i < ${#1}; i++)); do
        : "${1:i:1}"
        case "${_}" in
            [a-zA-Z0-9.~_-])
                printf '%s' "${_}"
                ;;
            *)
                printf '%%%02X' "'${_}"
                ;;
        esac
    done
    printf '\n'
}

#------------------------------------------------------------------------------
# urldecode - Decodifica uma string URL-encoded
# Uso: urldecode "https%3A%2F%2Fgithub.com%2Fuser%2Frepo"
# Retorna: "https://github.com/user/repo"
#------------------------------------------------------------------------------
urldecode() {
    : "${1//+/ }"
    printf '%b\n' "${_//%/\\x}"
}

# =============================================================================
# SEÇÃO 2: MANIPULAÇÃO DE ARRAYS
# =============================================================================

#------------------------------------------------------------------------------
# reverse_array - Inverte a ordem dos elementos de um array
# Uso: reverse_array "${array[@]}"
# Retorna: Elementos em ordem reversa, um por linha
# AVISO: Requer 'shopt -s compat44' em Bash 5.0+
#------------------------------------------------------------------------------
reverse_array() {
    shopt -s extdebug
    f()(printf '%s\n' "${BASH_ARGV[@]}")
    f "$@"
    shopt -u extdebug
}

#------------------------------------------------------------------------------
# remove_array_dups - Remove elementos duplicados de um array
# Uso: remove_array_dups "${array[@]}"
# Retorna: Elementos únicos (ordem não garantida)
# Requer: Bash 4+
#------------------------------------------------------------------------------
remove_array_dups() {
    declare -A tmp_array
    for i in "$@"; do
        [[ -n ${i} ]] && IFS=" " tmp_array["${i:- }"]=1
    done
    printf '%s\n' "${!tmp_array[@]}"
}

#------------------------------------------------------------------------------
# random_array_element - Retorna um elemento aleatório do array
# Uso: random_array_element "${array[@]}"
# Retorna: Elemento aleatório
#------------------------------------------------------------------------------
random_array_element() {
    local arr=("$@")
    printf '%s\n' "${arr[RANDOM % $#]}"
}

#------------------------------------------------------------------------------
# cycle - Percorre um array ciclicamente a cada chamada
# Uso: arr=(a b c d); cycle; cycle; cycle
# Retorna: Próximo elemento do array a cada chamada
# Requer: Variável 'arr' definida no escopo e 'i' inicializada
#------------------------------------------------------------------------------
# Exemplo de uso:
#   arr=(a b c d)
#   cycle() { printf '%s ' "${arr[${i:=0}]}"; ((i=i>=${#arr[@]}-1?0:++i)); }
# Nota: Esta função requer definição específica conforme necessidade
#------------------------------------------------------------------------------
cycle() {
    printf '%s ' "${arr[${i:=0}]}"
    ((i = i >= ${#arr[@]} - 1 ? 0 : ++i))
}

# =============================================================================
# SEÇÃO 3: MANIPULAÇÃO DE ARQUIVOS
# =============================================================================

#------------------------------------------------------------------------------
# head - Retorna as primeiras N linhas de um arquivo
# Uso: head 5 "arquivo.txt"
# Retorna: Primeiras 5 linhas
# Requer: Bash 4+
#------------------------------------------------------------------------------
head() {
    mapfile -tn "$1" line < "$2"
    printf '%s\n' "${line[@]}"
}

#------------------------------------------------------------------------------
# tail - Retorna as últimas N linhas de um arquivo
# Uso: tail 5 "arquivo.txt"
# Retorna: Últimas 5 linhas
# Requer: Bash 4+
#------------------------------------------------------------------------------
tail() {
    mapfile -tn 0 line < "$2"
    printf '%s\n' "${line[@]: -$1}"
}

#------------------------------------------------------------------------------
# lines - Conta o número de linhas em um arquivo
# Uso: lines "arquivo.txt"
# Retorna: Número de linhas
# Requer: Bash 4+
#------------------------------------------------------------------------------
lines() {
    mapfile -tn 0 lines < "$1"
    printf '%s\n' "${#lines[@]}"
}

#------------------------------------------------------------------------------
# lines_loop - Conta linhas usando loop (compatível com Bash 3)
# Uso: lines_loop "arquivo.txt"
# Retorna: Número de linhas
# Nota: Mais lento para arquivos grandes, mas usa menos memória
#------------------------------------------------------------------------------
lines_loop() {
    local count=0
    while IFS= read -r _; do
        ((count++))
    done < "$1"
    printf '%s\n' "${count}"
}

#------------------------------------------------------------------------------
# count - Conta argumentos passados (útil para contar arquivos)
# Uso: count /caminho/* ou count /caminho/*/
# Retorna: Número de itens
#------------------------------------------------------------------------------
count() {
    printf '%s\n' "$#"
}

#------------------------------------------------------------------------------
# extract - Extrai linhas entre dois marcadores
# Uso: extract "arquivo.txt" "marcador_inicio" "marcador_fim"
# Retorna: Linhas entre os marcadores (exclusivo)
#------------------------------------------------------------------------------
extract() {
    local extract
    while IFS=$'\n' read -r line; do
        [[ -n ${extract} && ${line} != "$3" ]] && printf '%s\n' "${line}"
        [[ ${line} == "$2" ]] && extract=1
        [[ ${line} == "$3" ]] && extract=
    done < "$1"
}

# =============================================================================
# SEÇÃO 4: MANIPULAÇÃO DE CAMINHOS
# =============================================================================

#------------------------------------------------------------------------------
# dirname - Retorna o diretório de um caminho (alternativa ao comando dirname)
# Uso: dirname "/home/user/pictures/photo.jpg"
# Retorna: "/home/user/pictures"
#------------------------------------------------------------------------------
dirname() {
    local tmp=${1:-.}

    [[ ${tmp} != *[!/]* ]] && {
        printf '/\n'
        return
    }

    tmp=${tmp%%"${tmp##*[!/]}"}

    [[ ${tmp} != */* ]] && {
        printf '.\n'
        return
    }

    tmp=${tmp%/*}
    tmp=${tmp%%"${tmp##*[!/]}"}

    printf '%s\n' "${tmp:-/}"
}

#------------------------------------------------------------------------------
# basename - Retorna o nome base de um caminho (alternativa ao comando basename)
# Uso: basename "/home/user/pictures/photo.jpg"
#        basename "/home/user/pictures/photo.jpg" ".jpg"
# Retorna: "photo.jpg" ou "photo"
#------------------------------------------------------------------------------
basename() {
    local tmp

    tmp=${1%"${1##*[!/]}"}
    tmp=${tmp##*/}
    tmp=${tmp%"${2/"${tmp}"}"}

    printf '%s\n' "${tmp:-/}"
}

# =============================================================================
# SEÇÃO 5: CONVERSÃO DE CORES
# =============================================================================

#------------------------------------------------------------------------------
# hex_to_rgb - Converte cor hexadecimal para RGB
# Uso: hex_to_rgb "#FFFFFF" ou hex_to_rgb "000000"
# Retorna: "255 255 255" ou "0 0 0"
#------------------------------------------------------------------------------
hex_to_rgb() {
    : "${1/\#}"
    ((r = 16#${_:0:2}, g = 16#${_:2:2}, b = 16#${_:4:2}))
    printf '%s\n' "${r} ${g} ${b}"
}

#------------------------------------------------------------------------------
# rgb_to_hex - Converte RGB para cor hexadecimal
# Uso: rgb_to_hex 255 255 255
# Retorna: "#FFFFFF"
#------------------------------------------------------------------------------
rgb_to_hex() {
    printf '#%02x%02x%02x\n' "$1" "$2" "$3"
}

# =============================================================================
# SEÇÃO 6: DATA E TEMPO
# =============================================================================

#------------------------------------------------------------------------------
# date - Formata data usando strftime (alternativa ao comando date)
# Uso: date "%Y-%m-%d %H:%M:%S"
# Retorna: Data formatada
# Requer: Bash 4+
#------------------------------------------------------------------------------
date() {
    printf "%($1)T\\n" "-1"
}

#------------------------------------------------------------------------------
# read_sleep - Sleep usando read (alternativa ao comando sleep)
# Uso: read_sleep 1 ou read_sleep 0.5
# Retorna: Nada (pausa execução)
# Requer: Bash 4+
#------------------------------------------------------------------------------
read_sleep() {
    read -rt "$1" <> <(:) || :
}

# =============================================================================
# SEÇÃO 7: INTERFACE DE USUÁRIO
# =============================================================================

#------------------------------------------------------------------------------
# bar - Desenha uma barra de progresso
# Uso: bar 50 10 (50% de progresso, 10 caracteres de largura)
# Retorna: Barra de progresso formatada (usar \r para atualizar)
#------------------------------------------------------------------------------
bar() {
    ((elapsed = $1 * $2 / 100))
    printf -v prog "%${elapsed}s"
    printf -v total "%$(($2 - elapsed))s"
    printf '%s\r' "[${prog// /-}${total}]"
}

#------------------------------------------------------------------------------
# get_functions - Lista todas as funções definidas no script atual
# Uso: get_functions
# Retorna: Nomes das funções, uma por linha
#------------------------------------------------------------------------------
get_functions() {
    IFS=$'\n' read -d "" -ra functions < <(declare -F)
    printf '%s\n' "${functions[@]//declare -f }"
}

# =============================================================================
# SEÇÃO 8: UTILITÁRIOS DE PROCESSOS
# =============================================================================

#------------------------------------------------------------------------------
# bkr - Executa um comando em background (background run)
# Uso: bkr ./script.sh
# Retorna: Nada (processo executa em background)
# Nota: Ignora SIGHUP, output redirecionado para /dev/null
#------------------------------------------------------------------------------
bkr() {
    (nohup "$@" &>/dev/null &)
}

# =============================================================================
# SEÇÃO 9: INFORMAÇÕES DO TERMINAL
# =============================================================================

#------------------------------------------------------------------------------
# get_term_size - Obtém o tamanho do terminal em linhas e colunas
# Uso: get_term_size
# Retorna: "LINHAS COLUNAS" (ex: "24 80")
#------------------------------------------------------------------------------
get_term_size() {
    shopt -s checkwinsize
    (:;:)
    printf '%s\n' "${LINES} ${COLUMNS}"
}

#------------------------------------------------------------------------------
# get_cursor_pos - Obtém a posição atual do cursor
# Uso: get_cursor_pos
# Retorna: "X Y" (ex: "1 8")
# Nota: Útil para criar TUIs em Bash puro
#------------------------------------------------------------------------------
get_cursor_pos() {
    IFS='[;' read -p $'\e[6n' -d R -rs _ y x _
    printf '%s\n' "${x} ${y}"
}

# =============================================================================
# SEÇÃO 10: FUNÇÕES ADICIONAIS ÚTEIS
# =============================================================================

#------------------------------------------------------------------------------
# uuid - Gera um UUID v4 (não criptograficamente seguro)
# Uso: uuid
# Retorna: UUID v4 (ex: "d5b6c731-1310-4c24-9fe3-55d556d44374")
# AVISO: Não use para fins de segurança/criptografia
#------------------------------------------------------------------------------
uuid() {
    local C="89ab"
    local N B

    for ((N = 0; N < 16; ++N)); do
        B="$((RANDOM % 256))"

        case "${N}" in
            6) printf '4%x' "$((B % 16))" ;;
            8) printf '%c%x' "${C:${RANDOM} % ${#C}:1}" "$((B % 16))" ;;
            3 | 5 | 7 | 9) printf '%02x-' "${B}" ;;
            *) printf '%02x' "${B}" ;;
        esac
    done

    printf '\n'
}

#------------------------------------------------------------------------------
# is_command - Verifica se um comando existe no PATH
# Uso: is_command "git"
# Retorna: 0 se existe, 1 se não existe
#------------------------------------------------------------------------------
is_command() {
    command -v "$1" &>/dev/null
}

#------------------------------------------------------------------------------
# get_username - Obtém o nome do usuário atual
# Uso: get_username
# Retorna: Nome do usuário
# Requer: Bash 4.4+
#------------------------------------------------------------------------------
get_username() {
    : \\u
    printf '%s\n' "${_@@P}"
}

# =============================================================================
# FIM DA BIBLIOTECA
# =============================================================================

# Se executado diretamente, mostrar ajuda
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cat <<'EOF'
Uso: source bash_functions.sh

Pure Bash Bible - Biblioteca de Funções Bash

Esta biblioteca fornece funções úteis escritas em Bash puro,
sem dependências externas.

Categorias de funções:
  1. Manipulação de Strings: trim_string, trim_all, lower, upper, etc.
  2. Manipulação de Arrays: reverse_array, remove_array_dups, etc.
  3. Manipulação de Arquivos: head, tail, lines, extract, etc.
  4. Manipulação de Caminhos: dirname, basename
  5. Conversão de Cores: hex_to_rgb, rgb_to_hex
  6. Data e Tempo: date, read_sleep
  7. UI: bar (progress bar), get_functions
  8. Processos: bkr (background run)
  9. Terminal: get_term_size, get_cursor_pos
  10. Utilitários: uuid, is_command, get_username

Para ver a documentação completa de cada função, leia os comentários
no código fonte.

Execute './test.sh' para rodar a suite de testes.
EOF
fi
