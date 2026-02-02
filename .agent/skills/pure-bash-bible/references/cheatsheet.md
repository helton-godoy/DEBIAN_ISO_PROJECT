# Pure Bash Bible - Guia de Referência Rápida

> Referência completa de expansão de parâmetros, operadores e funções para Bash puro.

---

## 📋 Tabela de Conteúdo

1. [Expansão de Parâmetros](#expansão-de-parâmetros)
2. [Operadores Condicionais](#operadores-condicionais)
3. [Operadores Aritméticos](#operadores-aritméticos)
4. [Sequências de Escape ANSI](#sequências-de-escape-ansi)
5. [Variáveis Internas Úteis](#variáveis-internas-úteis)
6. [Compatibilidade por Versão](#compatibilidade-por-versão)
7. [Expansão de Chaves](#expansão-de-chaves)

---

## Expansão de Parâmetros

### Substituição e Remoção

| Sintaxe                   | Descrição                    | Exemplo                |
| ------------------------- | ---------------------------- | ---------------------- |
| `${VAR#PATTERN}`          | Remove menor match do início | `${x#*.}` → `tar.gz`   |
| `${VAR##PATTERN}`         | Remove maior match do início | `${x##*.}` → `gz`      |
| `${VAR%PATTERN}`          | Remove menor match do final  | `${x%.*}` → `file.tar` |
| `${VAR%%PATTERN}`         | Remove maior match do final  | `${x%%.*}` → `file`    |
| `${VAR/PATTERN/REPLACE}`  | Substitui primeiro match     | `${x/foo/bar}`         |
| `${VAR//PATTERN/REPLACE}` | Substitui todos matches      | `${x//o/a}`            |
| `${VAR/PATTERN}`          | Remove primeiro match        | `${x/foo}`             |
| `${VAR//PATTERN}`         | Remove todos matches         | `${x//o}`              |

### Substrings e Comprimento

| Sintaxe                 | Descrição                        | Exemplo (VAR="Hello World") |
| ----------------------- | -------------------------------- | --------------------------- |
| `${#VAR}`               | Comprimento da string            | `${#VAR}` → `11`            |
| `${VAR:OFFSET}`         | Remove primeiros N caracteres    | `${VAR:6}` → `World`        |
| `${VAR:OFFSET:LENGTH}`  | Substring (posição, comprimento) | `${VAR:0:5}` → `Hello`      |
| `${VAR::OFFSET}`        | Primeiros N caracteres           | `${VAR::5}` → `Hello`       |
| `${VAR: -OFFSET}`       | Últimos N caracteres             | `${VAR: -5}` → `World`      |
| `${VAR:: -OFFSET}`      | Remove últimos N caracteres      | `${VAR:: -6}` → `Hello`     |
| `${VAR:OFFSET:-OFFSET}` | Corta início e fim               | `${VAR:6:-3}` → `Wo`        |

> **Nota:** `${VAR: -OFFSET}` requer espaço antes do `-` para diferenciar do operador `:-`

### Modificação de Case (Bash 4+)

| Sintaxe    | Descrição                | Exemplo (VAR="Hello World") |
| ---------- | ------------------------ | --------------------------- |
| `${VAR^}`  | Primeiro char maiúsculo  | `${VAR^}` → `Hello World`   |
| `${VAR^^}` | Tudo maiúsculo           | `${VAR^^}` → `HELLO WORLD`  |
| `${VAR,}`  | Primeiro char minúsculo  | `${VAR,}` → `hello World`   |
| `${VAR,,}` | Tudo minúsculo           | `${VAR,,}` → `hello world`  |
| `${VAR~}`  | Inverte case do primeiro | `${VAR~}` → `hELLO World`   |
| `${VAR~~}` | Inverte case de todos    | `${VAR~~}` → `hELLO wORLD`  |

### Valores Padrão

| Sintaxe           | Descrição                            | Quando Aplica        |
| ----------------- | ------------------------------------ | -------------------- |
| `${VAR:-DEFAULT}` | Usa DEFAULT se VAR vazio/unset       | vazio ou unset       |
| `${VAR-DEFAULT}`  | Usa DEFAULT se VAR unset             | apenas unset         |
| `${VAR:=DEFAULT}` | Seta VAR para DEFAULT se vazio/unset | vazio ou unset       |
| `${VAR=DEFAULT}`  | Seta VAR para DEFAULT se unset       | apenas unset         |
| `${VAR:+VALUE}`   | Usa VALUE se VAR não-vazio           | não-vazio            |
| `${VAR+VALUE}`    | Usa VALUE se VAR set                 | set (qualquer valor) |
| `${VAR:?ERROR}`   | Exibe erro e sai se vazio/unset      | vazio ou unset       |
| `${VAR?ERROR}`    | Exibe erro e sai se unset            | apenas unset         |

**Exemplos:**

```bash
name="${USER:-unknown}"      # Usa $USER ou "unknown"
: ${count:=0}                # Inicializa count com 0 se não existir
path="${1:?Error: caminho necessário}"  # Sai com erro se $1 não fornecido
```

### Indireção

| Sintaxe    | Descrição                                  |
| ---------- | ------------------------------------------ |
| `${!VAR}`  | Acessa variável cujo nome está em VAR      |
| `${!VAR*}` | Lista nomes de variáveis começando com VAR |
| `${!VAR@}` | Lista nomes (quoted, separados por espaço) |

```bash
# Exemplo de indireção
foo="hello"
ref="foo"
echo "${!ref}"  # → hello

# Bash 4.3+ (nameref)
declare -n ref=foo
echo "$ref"   # → hello
```

---

## Operadores Condicionais

### Testes de Arquivos

| Operador     | Testa se arquivo...                 |
| ------------ | ----------------------------------- |
| `-e`         | Existe                              |
| `-f`         | Existe e é arquivo regular          |
| `-d`         | Existe e é diretório                |
| `-h` ou `-L` | Existe e é symlink                  |
| `-r`         | Existe e é legível                  |
| `-w`         | Existe e é gravável                 |
| `-x`         | Existe e é executável               |
| `-s`         | Existe e tem tamanho > 0            |
| `-b`         | É dispositivo de bloco              |
| `-c`         | É dispositivo de caractere          |
| `-p`         | É named pipe (FIFO)                 |
| `-S`         | É socket                            |
| `-t FD`      | FD está aberto em terminal          |
| `-N`         | Foi modificado desde última leitura |
| `-O`         | Pertence ao UID efetivo             |
| `-G`         | Pertence ao GID efetivo             |

### Comparação de Arquivos

| Expressão         | Significado                |
| ----------------- | -------------------------- |
| `file1 -nt file2` | file1 mais novo que file2  |
| `file1 -ot file2` | file1 mais velho que file2 |
| `file1 -ef file2` | Mesmo inode/dispositivo    |

### Testes de Variáveis

| Operador | Significado                    |
| -------- | ------------------------------ |
| `-z VAR` | Comprimento zero (vazia)       |
| `-n VAR` | Comprimento não-zero           |
| `-v VAR` | Variável está setada           |
| `-R VAR` | Variável é nameref             |
| `-o OPT` | Opção de shell está habilitada |

### Comparação de Strings

| Operador    | Significado         |
| ----------- | ------------------- |
| `=` ou `==` | Igual               |
| `!=`        | Diferente           |
| `<`         | Menor (ordem ASCII) |
| `>`         | Maior (ordem ASCII) |
| `=~`        | Match regex         |

### Comparação Numérica

| Operador | Significado              |
| -------- | ------------------------ |
| `-eq`    | Igual (equal)            |
| `-ne`    | Diferente (not equal)    |
| `-lt`    | Menor que (less than)    |
| `-le`    | Menor ou igual           |
| `-gt`    | Maior que (greater than) |
| `-ge`    | Maior ou igual           |

### Operadores Combinados

| Sintaxe                | Descrição        |
| ---------------------- | ---------------- |
| `[[ $a == *texto* ]]`  | Contém substring |
| `[[ $a == prefixo* ]]` | Começa com       |
| `[[ $a == *sufixo ]]`  | Termina com      |
| `[[ $a =~ regex ]]`    | Match de regex   |

---

## Operadores Aritméticos

### Aritmética Básica

| Operador | Descrição       | Exemplo              |
| -------- | --------------- | -------------------- |
| `+`      | Adição          | `((x = 5 + 3))`      |
| `-`      | Subtração       | `((x = 5 - 3))`      |
| `*`      | Multiplicação   | `((x = 5 * 3))`      |
| `/`      | Divisão inteira | `((x = 5 / 2))` → 2  |
| `**`     | Exponenciação   | `((x = 2 ** 3))` → 8 |
| `%`      | Módulo (resto)  | `((x = 5 % 2))` → 1  |

### Atribuição Composta

| Operador | Equivalente | Descrição  |
| -------- | ----------- | ---------- |
| `+=`     | `x = x + y` | Incrementa |
| `-=`     | `x = x - y` | Decrementa |
| `*=`     | `x = x * y` | Multiplica |
| `/=`     | `x = x / y` | Divide     |
| `%=`     | `x = x % y` | Módulo     |

### Incremento/Decremento

| Sintaxe   | Descrição      |
| --------- | -------------- |
| `((x++))` | Pós-incremento |
| `((++x))` | Pré-incremento |
| `((x--))` | Pós-decremento |
| `((--x))` | Pré-decremento |

### Bitwise

| Operador | Descrição   |
| -------- | ----------- |
| `<<`     | Shift left  |
| `>>`     | Shift right |
| `&`      | AND         |
| `\|`     | OR          |
| `^`      | XOR         |
| `~`      | NOT         |

### Lógicos

| Operador | Descrição |
| -------- | --------- | ----------------------- |
| `!`      | NOT       |
| `&&`     | AND       |
| `\|\|`   | OR        |
| `?:`     | Ternário  | `((x = y > z ? y : z))` |

---

## Sequências de Escape ANSI

### Cores de Texto (256 cores)

| Escape           | Descrição                   |
| ---------------- | --------------------------- |
| `\e[38;5;Nm`     | Cor foreground (N=0-255)    |
| `\e[48;5;Nm`     | Cor background (N=0-255)    |
| `\e[38;2;R;G;Bm` | Foreground RGB (True Color) |
| `\e[48;2;R;G;Bm` | Background RGB (True Color) |

### Cores Básicas (8 cores)

| Código   | Cor      |
| -------- | -------- |
| `\e[30m` | Preto    |
| `\e[31m` | Vermelho |
| `\e[32m` | Verde    |
| `\e[33m` | Amarelo  |
| `\e[34m` | Azul     |
| `\e[35m` | Magenta  |
| `\e[36m` | Ciano    |
| `\e[37m` | Branco   |
| `\e[39m` | Padrão   |

> Adicione `1;` para versão brilhante: `\e[1;31m` (vermelho brilhante)
> Adicione `4;` para background: `\e[40m`-`\e[47m`

### Atributos de Texto

| Escape  | Efeito                     |
| ------- | -------------------------- |
| `\e[0m` | Reset todas as formatações |
| `\e[1m` | Negrito/brilhante          |
| `\e[2m` | Fraco/dim                  |
| `\e[3m` | Itálico                    |
| `\e[4m` | Sublinhado                 |
| `\e[5m` | Piscando                   |
| `\e[7m` | Invertido (reverse video)  |
| `\e[8m` | Escondido                  |
| `\e[9m` | Tachado                    |

> Adicione `2` após o código para desligar: `\e[22m` (desliga negrito)

### Movimento do Cursor

| Escape              | Ação                                  |
| ------------------- | ------------------------------------- |
| `\e[H` ou `\e[1;1H` | Home (0,0)                            |
| `\e[L;CH`           | Posição absoluta (linha, coluna)      |
| `\e[nA`             | Sobe n linhas                         |
| `\e[nB`             | Desce n linhas                        |
| `\e[nC`             | Direita n colunas                     |
| `\e[nD`             | Esquerda n colunas                    |
| `\e[s`              | Salva posição                         |
| `\e[u`              | Restaura posição                      |
| `\e[6n`             | Query posição (retorna `\e[row;colR`) |

### Limpeza de Tela

| Escape      | Ação                       |
| ----------- | -------------------------- |
| `\e[K`      | Limpa até fim da linha     |
| `\e[1K`     | Limpa até início da linha  |
| `\e[2K`     | Limpa linha inteira        |
| `\e[J`      | Limpa até fim da tela      |
| `\e[1J`     | Limpa até início da tela   |
| `\e[2J`     | Limpa tela inteira         |
| `\e[2J\e[H` | Limpa tela e vai para home |

---

## Variáveis Internas Úteis

| Variável            | Descrição                       |
| ------------------- | ------------------------------- |
| `$BASH`             | Caminho do executável bash      |
| `$BASH_VERSION`     | Versão do bash (string)         |
| `$BASH_VERSINFO[@]` | Versão do bash (array)          |
| `$BASHPID`          | PID do processo bash atual      |
| `$BASH_REMATCH[@]`  | Resultado do último match regex |
| `$EDITOR`           | Editor preferido do usuário     |
| `$EUID`             | ID efetivo do usuário           |
| `$FUNCNAME[@]`      | Nomes das funções na pilha      |
| `$GROUPS[@]`        | Grupos do usuário               |
| `$HOME`             | Diretório home                  |
| `$HOSTNAME`         | Nome da máquina                 |
| `$HOSTTYPE`         | Arquitetura (ex: x86_64)        |
| `$IFS`              | Separador de campo interno      |
| `$LINENO`           | Número da linha atual           |
| `$MACHTYPE`         | Tipo de máquina completo        |
| `$OLDPWD`           | Diretório anterior              |
| `$OSTYPE`           | Tipo de SO (ex: linux-gnu)      |
| `$PATH`             | Caminho de busca de executáveis |
| `$PIPESTATUS[@]`    | Status dos comandos no pipe     |
| `$PPID`             | PID do processo pai             |
| `$PWD`              | Diretório atual                 |
| `$RANDOM`           | Número aleatório (0-32767)      |
| `$REPLY`            | Resposta padrão do read         |
| `$SECONDS`          | Segundos desde início do shell  |
| `$SHELLOPTS`        | Opções habilitadas do shell     |
| `$SHLVL`            | Nível de shell (aninhamento)    |
| `$UID`              | ID real do usuário              |

### Variáveis de Posição

| Variável         | Descrição                           |
| ---------------- | ----------------------------------- |
| `$0`             | Nome do script                      |
| `$1` ... `${10}` | Argumentos posicionais              |
| `$#`             | Número de argumentos                |
| `$@`             | Todos os argumentos (quoted)        |
| `$*`             | Todos os argumentos (IFS-separated) |
| `$_`             | Último argumento do último comando  |

---

## Compatibilidade por Versão

### Bash 3.2 (macOS padrão)

✅ Disponível:

- Expansão de parâmetros básica
- Arrays indexados
- Aritmética
- Substrings `${var:offset:length}`

❌ Não disponível:

- Case modification `${var,,}` `${var^^}`
- Arrays associativos
- `mapfile`/`readarray`
- `printf '%(fmt)T'`

### Bash 4.0+

✅ Adições:

- Case modification (`${var,,}` etc.)
- Arrays associativos (`declare -A`)
- `mapfile`/`readarray`
- Heredocs com `<<<` (já existia)
- `coproc`

### Bash 4.2+

✅ Adições:

- Substring com índices negativos: `${var: -offset}`
- `printf '%(fmt)T'` para datas

### Bash 4.3+

✅ Adições:

- Namerefs (`declare -n`)
- `-v` para teste de variável setada

### Bash 4.4+

✅ Adições:

- `${var@P}` para expandir como prompt string
- `${var@Q}` para quoted string
- Associative array slice

### Bash 5.0+

✅ Adições:

- `$EPOCHSECONDS` e `$EPOCHREALTIME`
- `${var@u}` uppercase first
- `${var@L}` lowercase
- `${var@K}` para debug

---

## Expansão de Chaves

### Ranges Numéricos

```bash
# Sintaxe: {inicio..fim}
echo {1..5}        # 1 2 3 4 5
echo {0..100}      # 0 a 100

# Com padding (Bash 4+)
echo {01..10}      # 01 02 03 ... 10
echo {001..100}    # 001 002 ... 100

# Com incremento (Bash 4+)
echo {1..10..2}    # 1 3 5 7 9
echo {100..1..-5}  # 100 95 90 ... 5
```

### Ranges de Caracteres

```bash
echo {a..z}        # a b c ... z
echo {A..Z}        # A B C ... Z

# Nesting
echo {A..Z}{0..9}  # A0 A1 ... Z9
```

### Listas de Strings

```bash
echo {apple,orange,pear}
# apple orange pear

# Expansão em comandos
mkdir -p projeto/{src,test,docs}/{2023,2024}
# Cria: projeto/src/2023 projeto/src/2024 ...

# Com prefixo/sufixo
echo file.{txt,md,json}
# file.txt file.md file.json
```

---

## Dicas Rápidas

### One-liners Úteis

```bash
# Loop C-style curto
for((i=0;i<10;i++)){ echo $i;}

# If curto (cuidado com exit status)
[[ $x == yes ]] && echo sim || echo não

# Default value em uma linha
: ${VAR:=default}

# Subshell silencioso
(cmd)>/dev/null 2>&1

# Here-string para input
read a b c <<< "1 2 3"

# Process substitution
while read line; do ... done < <(command)

# Grouping com output
{ cmd1; cmd2; } > output.txt
```

### Performance

```bash
# Desabilitar Unicode para performance
LC_ALL=C
LANG=C

# Usar built-ins em vez de comandos externos
# ❌ $(cat file)
# ✅ $(<file)

# Evitar subshells quando possível
# ❌ var=$(echo "$x" | tr 'a-z' 'A-Z')
# ✅ var="${x^^}"

# Usar [[ ]] em vez de [ ]
# Mais rápido e menos propenso a erros
```

---

## Referência

- **Pure Bash Bible**: https://github.com/dylanaraps/pure-bash-bible
- **Bash Manual**: https://www.gnu.org/software/bash/manual/
- **Shellcheck**: https://www.shellcheck.net/

---

_Última atualização: 2026-01-31_
