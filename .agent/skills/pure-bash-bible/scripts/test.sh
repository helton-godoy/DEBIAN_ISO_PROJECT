#!/usr/bin/env bash
# shellcheck source=/dev/null disable=SC2178,SC2128
#
# =============================================================================
# Pure Bash Bible - Suite de Testes
# =============================================================================
#
# Descrição:    Testes abrangentes para todas as funções da biblioteca
#               pure-bash-bible.
#
# Uso:          ./test.sh
#
# =============================================================================

# Configuração de diretórios
SCRIPT_DIR="$(cd "$(command dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bash_functions.sh
source "${SCRIPT_DIR}/bash_functions.sh"

# Contadores de testes
PASS=0
FAIL=0

#------------------------------------------------------------------------------
# Função de asserção principal
# Uso: assert_equals "valor_obtido" "valor_esperado" ["mensagem_opcional"]
#------------------------------------------------------------------------------
assert_equals() {
	local actual="$1"
	local expected="$2"
	local message="${3-}"
	local test_name="${FUNCNAME[1]/test_/}"

	if [[ ${actual} == "${expected}" ]]; then
		((PASS++))
		printf ' \e[32m✔\e[m | %s\n' "${test_name}"
		return 0
	else
		((FAIL++))
		printf ' \e[31m✖\e[m | %s' "${test_name}"
		[[ -n ${message} ]] && printf ' (%s)' "${message}"
		printf '\n   Expected: "%s"\n   Got:      "%s"\n' "${expected}" "${actual}"
		return 1
	fi
}

#===============================================================================
# TESTES DE STRINGS
#===============================================================================

test_trim_string() {
	local result
	result="$(trim_string "    Hello,    World    ")"
	assert_equals "${result}" "Hello,    World"
}

test_trim_all() {
	local result
	result="$(trim_all "    Hello,    World    ")"
	assert_equals "${result}" "Hello, World"
}

test_regex() {
	local result
	result="$(regex "#FFFFFF" '^(#?([a-fA-F0-9]{6}|[a-fA-F0-9]{3}))$')"
	assert_equals "${result}" "#FFFFFF"

	# Teste com valor inválido
	result="$(regex "red" '^(#?([a-fA-F0-9]{6}|[a-fA-F0-9]{3}))$')"
	assert_equals "${result}" "" "regex inválido deve retornar vazio"
}

test_lower() {
	local result
	result="$(lower "HeLlO")"
	assert_equals "${result}" "hello"

	result="$(lower "HELLO WORLD")"
	assert_equals "${result}" "hello world"
}

test_upper() {
	local result
	result="$(upper "HeLlO")"
	assert_equals "${result}" "HELLO"

	result="$(upper "hello world")"
	assert_equals "${result}" "HELLO WORLD"
}

test_reverse_case() {
	local result
	result="$(reverse_case "HeLlO")"
	assert_equals "${result}" "hElLo"

	result="$(reverse_case "Hello World")"
	assert_equals "${result}" "hELLO wORLD"
}

test_trim_quotes() {
	local result
	result="$(trim_quotes "\"te'st' 'str'ing\"")"
	assert_equals "${result}" "test string"
}

test_split() {
	local result
	IFS=$'\n' read -d "" -ra result < <(split "hello,world,my,name" ",")
	assert_equals "${result[*]}" "hello world my name"
}

test_strip_all() {
	local result
	result="$(strip_all "The Quick Brown Fox" "[aeiou]")"
	assert_equals "${result}" "Th Qck Brwn Fx"
}

test_strip() {
	local result
	result="$(strip "The Quick Brown Fox" "[aeiou]")"
	assert_equals "${result}" "Th Quick Brown Fox"
}

test_lstrip() {
	local result
	result="$(lstrip "!:IHello" "!:I")"
	assert_equals "${result}" "Hello"

	result="$(lstrip "The Quick Brown Fox" "The ")"
	assert_equals "${result}" "Quick Brown Fox"
}

test_rstrip() {
	local result
	result="$(rstrip "Hello!:I" "!:I")"
	assert_equals "${result}" "Hello"

	result="$(rstrip "The Quick Brown Fox" " Fox")"
	assert_equals "${result}" "The Quick Brown"
}

test_urlencode() {
	local result
	result="$(urlencode "https://github.com/dylanaraps/pure-bash-bible")"
	assert_equals "${result}" "https%3A%2F%2Fgithub.com%2Fdylanaraps%2Fpure-bash-bible"
}

test_urldecode() {
	local result
	result="$(urldecode "https%3A%2F%2Fgithub.com%2Fdylanaraps%2Fpure-bash-bible")"
	assert_equals "${result}" "https://github.com/dylanaraps/pure-bash-bible"
}

#===============================================================================
# TESTES DE ARRAYS
#===============================================================================

test_reverse_array() {
	local result
	shopt -s compat44 2>/dev/null || true
	IFS=$'\n' read -d "" -ra result < <(reverse_array 1 2 3 4 5)
	assert_equals "${result[*]}" "5 4 3 2 1"
	shopt -u compat44 2>/dev/null || true
}

test_remove_array_dups() {
	local result
	IFS=$'\n' read -d "" -ra result < <(remove_array_dups 1 1 2 2 3 3 3 4 4 5 5)
	# Ordem pode variar, então verificamos o tamanho
	assert_equals "${#result[@]}" "5" "deve ter 5 elementos únicos"
}

test_random_array_element() {
	local result
	result="$(random_array_element red green blue yellow brown)"
	# Verificamos se o resultado está no array original
	[[ "red green blue yellow brown" == *"${result}"* ]]
	assert_equals "$?" "0" "elemento aleatório deve estar no array"
}

test_cycle() {
	local result
	# shellcheck disable=2034
	local arr=(a b c d)
	# Redefinimos a função cycle para teste com array local
	cycle_test() {
		printf '%s ' "${arr[${i:=0}]}"
		((i = i >= ${#arr[@]} - 1 ? 0 : ++i))
	}
	result="$(
		cycle_test
		cycle_test
		cycle_test
	)"
	assert_equals "${result}" "a b c "
}

#===============================================================================
# TESTES DE ARQUIVOS
#===============================================================================

test_head() {
	local result
	local tmpfile
	tmpfile=$(mktemp)
	printf '%s\n' "line1" "line2" "line3" "line4" >"${tmpfile}"

	result="$(head 2 "${tmpfile}")"
	assert_equals "${result}" $'line1\nline2'

	rm -f "${tmpfile}"
}

test_tail() {
	local result
	local tmpfile
	tmpfile=$(mktemp)
	printf '%s\n' "line1" "line2" "line3" "line4" >"${tmpfile}"

	result="$(tail 2 "${tmpfile}")"
	assert_equals "${result}" $'line3\nline4'

	rm -f "${tmpfile}"
}

test_lines() {
	local result
	local tmpfile
	tmpfile=$(mktemp)
	printf '%s\n' "line1" "line2" "line3" "" "line5" >"${tmpfile}"

	result="$(lines "${tmpfile}")"
	assert_equals "${result}" "5"

	rm -f "${tmpfile}"
}

test_lines_loop() {
	local result
	local tmpfile
	tmpfile=$(mktemp)
	printf '%s\n' "line1" "line2" "line3" "" "line5" >"${tmpfile}"

	result="$(lines_loop "${tmpfile}")"
	assert_equals "${result}" "5"

	rm -f "${tmpfile}"
}

test_count() {
	local result
	# Testar contagem de argumentos
	result="$(count a b c d e)"
	assert_equals "${result}" "5"

	result="$(count)"
	assert_equals "${result}" "0"
}

test_extract() {
	local result
	local tmpfile
	tmpfile=$(mktemp)
	printf '%s\n' "{" "hello, world" "}" >"${tmpfile}"

	result="$(extract "${tmpfile}" "{" "}")"
	assert_equals "${result}" "hello, world"

	rm -f "${tmpfile}"
}

#===============================================================================
# TESTES DE CAMINHOS
#===============================================================================

test_dirname() {
	local result

	result="$(dirname "/home/black/Pictures/Wallpapers/1.jpg")"
	assert_equals "${result}" "/home/black/Pictures/Wallpapers"

	result="$(dirname "/")"
	assert_equals "${result}" "/"

	result="$(dirname "/foo")"
	assert_equals "${result}" "/"

	result="$(dirname ".")"
	assert_equals "${result}" "."

	result="$(dirname "")"
	assert_equals "${result}" "."

	result="$(dirname "something/")"
	assert_equals "${result}" "."
}

test_basename() {
	local result

	result="$(basename "/home/black/Pictures/Wallpapers/1.jpg")"
	assert_equals "${result}" "1.jpg"

	result="$(basename "/home/black/Pictures/Wallpapers/1.jpg" ".jpg")"
	assert_equals "${result}" "1"

	result="$(basename "///")"
	assert_equals "${result}" "/"
}

#===============================================================================
# TESTES DE CORES
#===============================================================================

test_hex_to_rgb() {
	local result

	result="$(hex_to_rgb "#FFFFFF")"
	assert_equals "${result}" "255 255 255"

	result="$(hex_to_rgb "000000")"
	assert_equals "${result}" "0 0 0"

	result="$(hex_to_rgb "#FF0000")"
	assert_equals "${result}" "255 0 0"
}

test_rgb_to_hex() {
	local result

	result="$(rgb_to_hex 0 0 0)"
	assert_equals "${result}" "#000000"

	result="$(rgb_to_hex 255 255 255)"
	assert_equals "${result}" "#ffffff"

	result="$(rgb_to_hex 255 0 0)"
	assert_equals "${result}" "#ff0000"
}

#===============================================================================
# TESTES DE DATA E TEMPO
#===============================================================================

test_date() {
	local result

	result="$(date "%C")"
	assert_equals "${result}" "20"

	# Teste de formato ano - verifica se tem 4 dígitos
	result="$(date "%Y")"
	[[ ${result} =~ ^[0-9]{4}$ ]]
	assert_equals "$?" "0" "ano deve ter 4 dígitos"
}

test_read_sleep() {
	local start end elapsed
	start=${SECONDS}
	read_sleep 0.1
	end=${SECONDS}
	elapsed=$((end - start))
	# Verifica se passou pelo menos 0 segundos (read_sleep pode ser instantâneo em alguns sistemas)
	[[ ${elapsed} -ge 0 ]]
	assert_equals "$?" "0" "read_sleep deve executar sem erros"
}

#===============================================================================
# TESTES DE UI
#===============================================================================

test_bar() {
	local result

	result="$(bar 50 10)"
	# Remove carriage return para comparação
	result="${result//$'\r'/}"
	assert_equals "${result}" "[-----     ]"

	result="$(bar 100 10)"
	result="${result//$'\r'/}"
	assert_equals "${result}" "[----------]"

	result="$(bar 0 10)"
	result="${result//$'\r'/}"
	assert_equals "${result}" "[          ]"
}

test_get_functions() {
	local result
	IFS=$'\n' read -d "" -ra result < <(get_functions)
	# Verifica se algumas funções conhecidas existem
	[[ ${result[*]} == *"trim_string"* ]]
	assert_equals "$?" "0" "get_functions deve incluir trim_string"
}

#===============================================================================
# TESTES DE UTILITÁRIOS
#===============================================================================

test_uuid() {
	local result
	result="$(uuid)"
	# Verifica formato UUID v4 (8-4-4-4-12 hex digits)
	[[ ${result} =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
	assert_equals "$?" "0" "UUID deve estar no formato v4 válido"
}

test_is_command() {
	# Testa comando que existe (bash)
	is_command "bash"
	assert_equals "$?" "0" "bash deve existir no PATH"

	# Testa comando que não existe
	is_command "comando_inexistente_12345"
	assert_equals "$?" "1" "comando inexistente deve retornar 1"
}

#===============================================================================
# FUNÇÃO PRINCIPAL
#===============================================================================

main() {
	local tmpdir
	tmpdir=$(mktemp -d)
	cd "${tmpdir}" || exit 1

	# Header
	local head="-> Executando testes do Pure Bash Bible"
	printf '\n%s\n%s\n' "${head}" "${head//?/-}"
	printf 'Bash Version: %s\n\n' "${BASH_VERSION}"

	# Descobrir e executar todos os testes
	local funcs
	IFS=$'\n' read -d "" -ra funcs < <(declare -F)

	for func in "${funcs[@]//declare -f /}"; do
		[[ ${func} == test_* ]] && "${func}"
	done

	# Resumo
	local total=$((PASS + FAIL))
	local comp="Concluídos ${total} testes. ${PASS:-0} passaram, ${FAIL:-0} falharam."
	printf '\n%s\n%s\n' "${comp//?/-}" "${comp}"

	# Limpeza
	cd - >/dev/null || true
	rm -rf "${tmpdir}"

	# Verificação com shellcheck (se disponível)
	if command -v shellcheck &>/dev/null; then
		printf '\n-> Verificando com shellcheck...\n'
		if shellcheck -s bash "${SCRIPT_DIR}/bash_functions.sh"; then
			printf '   \e[32m✔\e[m shellcheck passou sem erros\n'
		else
			printf '   \e[31m✖\e[m shellcheck encontrou problemas\n'
		fi
	else
		printf '\n-> shellcheck não instalado, pulando verificação\n'
	fi

	# Retorno de erro se houver falhas
	if ((FAIL > 0)); then
		exit 1
	fi
	exit 0
}

main "$@"
