# Aurora Installer - Proposta de Design Monocromático Sofisticado

## Visão Geral

Este documento apresenta uma proposta para desenvolver um instalador gráfico customizado para Debian, executado via terminal puro (TTY), com uma interface visual sofisticada utilizando estratégias de design monocromático (tom sobre tom) com variações sutis de tonalidade e opacidade, hierarquia tipográfica refinada e espaçamento harmonioso.

## Análise do Script Atual

O script [`install-system-mockup-3`](install-system-mockup-3) atual utiliza a ferramenta `gum` para criar uma interface TUI colorida e funcional. No entanto, a paleta de cores atual é vibrante e não segue princípios de design monocromático. A proposta é refinar essa abordagem para criar uma identidade visual mais elegante e profissional.

## Princípios de Design

### 1. Paleta Monocromática Refinada

A paleta será baseada em tons de cinza/azul-acinzentado, criando uma identidade visual elegante e profissional:

```bash
# Paleta de Cores Monocromática (256-color terminal)
PRIMARY=236        # #303030 - Fundo principal
SECONDARY=240      # #585858 - Fundo secundário
ACCENT=244         # #808080 - Acentos sutis
HIGHLIGHT=248      # #a8a8a8 - Destaques
TEXT_PRIMARY=252   # #d0d0d0 - Texto principal
TEXT_SECONDARY=246 # #949494 - Texto secundário
TEXT_MUTED=244     # #808080 - Texto sutil
SUCCESS=242        # #585858 - Sucesso (com ícone verde)
WARNING=242        # #585858 - Aviso (com ícone amarelo)
ERROR=242          # #585858 - Erro (com ícone vermelho)
BORDER=240         # #585858 - Bordas
SHADOW=234         # #1c1c1c - Sombras
```

### 2. Hierarquia Tipográfica

Utilização de diferentes pesos e tamanhos para criar hierarquia visual:

```bash
# Níveis de Hierarquia
H1="bold,large"    # Títulos principais (ex: "AURORA INSTALLER")
H2="bold,medium"   # Seções (ex: "Etapa 1/6: Preparando Disco")
H3="normal,medium" # Subseções (ex: "Configuração de Conta")
BODY="normal"      # Texto de corpo
CAPTION="small"    # Legendas e notas
```

### 3. Espaçamento Harmonioso

Sistema de espaçamento consistente baseado em múltiplos de 4:

```bash
# Sistema de Espaçamento
SPACING_XS=1       # 1 espaço/caractere
SPACING_SM=2       # 2 espaços/caracteres
SPACING_MD=4       # 4 espaços/caracteres
SPACING_LG=8       # 8 espaços/caracteres
SPACING_XL=12      # 12 espaços/caracteres
SPACING_XXL=16     # 16 espaços/caracteres

# Margens e Padding
MARGIN_TOP=2
MARGIN_BOTTOM=2
MARGIN_LEFT=4
MARGIN_RIGHT=4
PADDING_VERTICAL=1
PADDING_HORIZONTAL=2
```

## Arquitetura do Sistema de UI

### Componentes Principais

#### 1. Sistema de Cores Dinâmico

```bash
# Função para obter cor com opacidade simulada
get_color() {
    local base_color=$1
    local opacity=$2  # 0-100

    # Simula opacidade alternando entre cores mais claras/escuras
    if [ $opacity -lt 30 ]; then
        echo $((base_color - 4))
    elif [ $opacity -lt 60 ]; then
        echo $base_color
    else
        echo $((base_color + 4))
    fi
}

# Função para gradiente monocromático
create_gradient() {
    local text=$1
    local start_color=$2
    local end_color=$3
    local length=${#text}
    local step=$(( (end_color - start_color) / length ))

    local result=""
    for ((i=0; i<length; i++)); do
        local color=$((start_color + (i * step)))
        result+="\033[38;5;${color}m${text:$i:1}"
    done
    echo -e "${result}\033[0m"
}
```

#### 2. Sistema de Tipografia

```bash
# Função para renderizar texto com hierarquia
render_text() {
    local text=$1
    local level=$2  # h1, h2, h3, body, caption
    local color=$3

    case $level in
        h1)
            echo -e "\033[1;38;5;${color}m${text}\033[0m"
            ;;
        h2)
            echo -e "\033[1;38;5;${color}m${text}\033[0m"
            ;;
        h3)
            echo -e "\033[38;5;${color}m${text}\033[0m"
            ;;
        body)
            echo -e "\033[38;5;${color}m${text}\033[0m"
            ;;
        caption)
            echo -e "\033[2;38;5;${color}m${text}\033[0m"
            ;;
    esac
}

# Função para espaçamento vertical
vspace() {
    local lines=$1
    for ((i=0; i<lines; i++)); do
        echo ""
    done
}
```

#### 3. Sistema de Layout

```bash
# Função para criar container com bordas
create_box() {
    local content=$1
    local width=$2
    local border_color=$3
    local bg_color=$4

    # Linha superior
    echo -e "\033[48;5;${bg_color}m\033[38;5;${border_color}m┌$(printf '─%.0s' $(seq 1 $((width-2))))┐\033[0m"

    # Conteúdo
    while IFS= read -r line; do
        local padding=$((width - ${#line} - 2))
        echo -e "\033[48;5;${bg_color}m\033[38;5;${border_color}m│\033[38;5;${TEXT_PRIMARY}m ${line}$(printf ' %.0s' $(seq 1 $padding))\033[38;5;${border_color}m│\033[0m"
    done <<< "$content"

    # Linha inferior
    echo -e "\033[48;5;${bg_color}m\033[38;5;${border_color}m└$(printf '─%.0s' $(seq 1 $((width-2))))┘\033[0m"
}

# Função para grid layout
create_grid() {
    local items=("$@")
    local columns=3
    local column_width=30

    for ((i=0; i<${#items[@]}; i+=columns)); do
        local row=""
        for ((j=0; j<columns && i+j<${#items[@]}; j++)); do
            row+="${items[$i+j]}$(printf ' %.0s' $(seq 1 $((column_width - ${#items[$i+j]}))))"
        done
        echo "$row"
    done
}
```

#### 4. Sistema de Animações

```bash
# Animação de loading elegante
animate_loading() {
    local text=$1
    local duration=${2:-2}
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local end_time=$((SECONDS + duration))

    while [ $SECONDS -lt $end_time ]; do
        printf "\r\033[38;5;${HIGHLIGHT}m%s\033[0m \033[38;5;${TEXT_SECONDARY}m%s\033[0m" "${chars:$i:1}" "$text"
        i=$(((i + 1) % ${#chars}))
        sleep 0.1
    done
    printf "\r\033[38;5;${SUCCESS}m✓\033[0m \033[38;5;${TEXT_PRIMARY}m%s\033[0m\n" "$text"
}

# Animação de progresso suave
animate_progress() {
    local current=$1
    local total=$2
    local label=$3
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))

    # Barra de progresso com gradiente
    printf "\r\033[38;5;${TEXT_SECONDARY}m%s:\033[0m [" "$label"

    # Parte preenchida com gradiente
    for ((i=0; i<filled; i++)); do
        local color=$((244 + (i * 2 / filled)))
        printf "\033[38;5;${color}m█\033[0m"
    done

    # Parte vazia
    printf "\033[38;5;${SECONDARY}m%*s\033[0m" $empty | tr ' ' '░'
    printf "] \033[38;5;${HIGHLIGHT}m%d%%\033[0m" $percentage
}
```

#### 5. Sistema de Componentes

```bash
# Card com sombra
create_card() {
    local title=$1
    local content=$2
    local width=60

    # Sombra
    echo -e "\033[38;5;${SHADOW}m$(printf ' %.0s' $(seq 1 $((width+2))))\033[0m"

    # Card
    create_box "$content" $width $BORDER $PRIMARY

    # Título
    echo -e "\033[38;5;${HIGHLIGHT}m${title}\033[0m"
}

# Badge elegante
create_badge() {
    local text=$1
    local type=$2  # info, success, warning, error

    local bg_color
    local fg_color

    case $type in
        info)
            bg_color=240
            fg_color=252
            ;;
        success)
            bg_color=242
            fg_color=252
            ;;
        warning)
            bg_color=242
            fg_color=252
            ;;
        error)
            bg_color=242
            fg_color=252
            ;;
    esac

    echo -e "\033[48;5;${bg_color}m\033[38;5;${fg_color}m ${text} \033[0m"
}

# Input field estilizado
create_input() {
    local placeholder=$1
    local value=$2
    local width=40

    echo -e "\033[38;5;${TEXT_MUTED}m${placeholder}\033[0m"
    echo -e "\033[38;5;${BORDER}m┌$(printf '─%.0s' $(seq 1 $((width-2))))┐\033[0m"
    echo -e "\033[38;5;${BORDER}m│\033[0m \033[38;5;${TEXT_PRIMARY}m${value}$(printf ' %.0s' $(seq 1 $((width - ${#value} - 3))))\033[38;5;${BORDER}m│\033[0m"
    echo -e "\033[38;5;${BORDER}m└$(printf '─%.0s' $(seq 1 $((width-2))))┘\033[0m"
}

# Button estilizado
create_button() {
    local text=$1
    local type=$2  # primary, secondary, danger

    local bg_color
    local fg_color

    case $type in
        primary)
            bg_color=244
            fg_color=236
            ;;
        secondary)
            bg_color=240
            fg_color=252
            ;;
        danger)
            bg_color=242
            fg_color=252
            ;;
    esac

    local padding=2
    local text_length=${#text}
    local total_width=$((text_length + padding * 2))

    echo -e "\033[48;5;${bg_color}m\033[38;5;${fg_color}m$(printf ' %.0s' $(seq 1 $padding))${text}$(printf ' %.0s' $(seq 1 $padding))\033[0m"
}
```

## Implementação do Logo Animado

```bash
# Logo com efeito de fade-in monocromático
logo_animated() {
    clear

    local colors=(236 240 244 248 252)
    local text="AURORA INSTALLER"
    local subtitle="Debian ZFS NAS - High Performance Storage"

    # Efeito de fade-in
    for i in {0..4}; do
        clear
        vspace 2

        # Título principal
        echo -e "\033[38;5;${colors[$i]}m$(center_text "$text" 60)\033[0m"
        vspace 1

        # Subtítulo
        echo -e "\033[38;5;${colors[$i]}m$(center_text "$subtitle" 60)\033[0m"
        vspace 2

        # Linha decorativa
        echo -e "\033[38;5;${colors[$i]}m$(center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 60)\033[0m"

        sleep 0.15
    done

    # Versão final estável
    clear
    vspace 2
    echo -e "\033[1;38;5;${HIGHLIGHT}m$(center_text "$text" 60)\033[0m"
    vspace 1
    echo -e "\033[38;5;${TEXT_SECONDARY}m$(center_text "$subtitle" 60)\033[0m"
    vspace 2
    echo -e "\033[38;5;${BORDER}m$(center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 60)\033[0m"
    vspace 1

    # Badge de modo
    echo -e "\033[48;5;${SECONDARY}m\033[38;5;${TEXT_PRIMARY}m$(center_text "⚠  MODO MOCKUP - Simulação Apenas" 60)\033[0m"
    vspace 2
}

# Função auxiliar para centralizar texto
center_text() {
    local text=$1
    local width=$2
    local text_length=${#text}
    local padding=$(((width - text_length) / 2))
    printf "%${padding}s%s" "" "$text"
}
```

## Sistema de Navegação

```bash
# Menu de navegação elegante
create_menu() {
    local title=$1
    shift
    local options=("$@")
    local selected=0

    while true; do
        clear
        logo_animated
        vspace 1

        # Título do menu
        echo -e "\033[1;38;5;${HIGHLIGHT}m${title}\033[0m"
        vspace 1

        # Opções
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "\033[48;5;${ACCENT}m\033[38;5;${PRIMARY}m▶ ${options[$i]}\033[0m"
            else
                echo -e "\033[38;5;${TEXT_SECONDARY}m  ${options[$i]}\033[0m"
            fi
        done

        vspace 2
        echo -e "\033[38;5;${TEXT_MUTED}mUse ↑/↓ para navegar, Enter para selecionar\033[0m"

        # Captura de tecla
        read -rsn1 key
        case $key in
            $'\x1b')  # Sequência de escape
                read -rsn2 -t 0.1 key
                case $key in
                    '[A')  # Seta para cima
                        selected=$(((selected - 1 + ${#options[@]}) % ${#options[@]}))
                        ;;
                    '[B')  # Seta para baixo
                        selected=$(((selected + 1) % ${#options[@]}))
                        ;;
                esac
                ;;
            '')  # Enter
                return $selected
                ;;
        esac
    done
}
```

## Sistema de Feedback Visual

```bash
# Toast notification elegante
show_toast() {
    local message=$1
    local type=$2  # success, error, warning, info
    local duration=${3:-3}

    local icon
    local color

    case $type in
        success)
            icon="✓"
            color=$SUCCESS
            ;;
        error)
            icon="✖"
            color=$ERROR
            ;;
        warning)
            icon="⚠"
            color=$WARNING
            ;;
        info)
            icon="ℹ"
            color=$ACCENT
            ;;
    esac

    # Salva posição do cursor
    tput sc

    # Move para a linha inferior
    tput cup $(($(tput lines) - 3)) 0

    # Renderiza toast
    local width=${#message}
    local total_width=$((width + 8))

    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${color}m┌$(printf '─%.0s' $(seq 1 $((total_width-2))))┐\033[0m"
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${color}m│ ${icon} ${message}$(printf ' %.0s' $(seq 1 $((total_width - ${#message} - 6))))│\033[0m"
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${color}m└$(printf '─%.0s' $(seq 1 $((total_width-2))))┘\033[0m"

    # Aguarda
    sleep $duration

    # Restaura cursor
    tput rc
}

# Modal dialog elegante
show_modal() {
    local title=$1
    local message=$2
    local buttons=("${@:3}")

    local width=60
    local height=10

    # Calcula posição central
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local start_col=$(((term_width - width) / 2))
    local start_row=$(((term_height - height) / 2))

    # Move cursor para posição
    tput cup $start_row $start_col

    # Renderiza modal
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m┌$(printf '─%.0s' $(seq 1 $((width-2))))┐\033[0m"

    # Título
    tput cup $((start_row + 1)) $start_col
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m \033[1;38;5;${HIGHLIGHT}m${title}\033[0m$(printf ' %.0s' $(seq 1 $((width - ${#title} - 4))))\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m"

    # Separador
    tput cup $((start_row + 2)) $start_col
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m├$(printf '─%.0s' $(seq 1 $((width-2))))┤\033[0m"

    # Mensagem
    tput cup $((start_row + 4)) $start_col
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m \033[38;5;${TEXT_PRIMARY}m${message}\033[0m$(printf ' %.0s' $(seq 1 $((width - ${#message} - 4))))\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m│\033[0m"

    # Separador
    tput cup $((start_row + 6)) $start_col
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m├$(printf '─%.0s' $(seq 1 $((width-2))))┤\033[0m"

    # Botões
    local button_row=$((start_row + 8))
    local button_col=$((start_col + 2))
    for button in "${buttons[@]}"; do
        tput cup $button_row $button_col
        echo -e "\033[48;5;${ACCENT}m\033[38;5;${PRIMARY}m ${button} \033[0m"
        button_col=$((button_col + ${#button} + 4))
    done

    # Linha inferior
    tput cup $((start_row + 9)) $start_col
    echo -e "\033[48;5;${PRIMARY}m\033[38;5;${BORDER}m└$(printf '─%.0s' $(seq 1 $((width-2))))┘\033[0m"
}
```

## Sistema de Progresso Multi-Etapa

```bash
# Barra de progresso com etapas
create_step_progress() {
    local current_step=$1
    local total_steps=$2
    local steps=("${@:3}")

    local width=60
    local step_width=$((width / total_steps))

    echo -e "\033[38;5;${TEXT_MUTED}mProgresso da Instalação\033[0m"
    echo ""

    for ((i=0; i<total_steps; i++)); do
        local step_text="${steps[$i]}"
        local step_text_short="${step_text:0:10}"

        if [ $i -lt $current_step ]; then
            # Etapa concluída
            echo -e "\033[48;5;${ACCENT}m\033[38;5;${PRIMARY}m${step_text_short}$(printf ' %.0s' $(seq 1 $((step_width - ${#step_text_short}))))\033[0m"
        elif [ $i -eq $current_step ]; then
            # Etapa atual
            echo -e "\033[48;5;${HIGHLIGHT}m\033[38;5;${PRIMARY}m${step_text_short}$(printf ' %.0s' $(seq 1 $((step_width - ${#step_text_short}))))\033[0m"
        else
            # Etapa pendente
            echo -e "\033[48;5;${SECONDARY}m\033[38;5;${TEXT_MUTED}m${step_text_short}$(printf ' %.0s' $(seq 1 $((step_width - ${#step_text_short}))))\033[0m"
        fi
    done

    echo ""
    local percentage=$((current_step * 100 / total_steps))
    echo -e "\033[38;5;${TEXT_SECONDARY}mEtapa ${current_step}/${total_steps} (${percentage}%)\033[0m"
}
```

## Benefícios do Design Monocromático

1. **Elegância e Profissionalismo**: Tons sutis criam uma aparência sofisticada
2. **Foco no Conteúdo**: Cores neutras não distraem o usuário
3. **Acessibilidade**: Alto contraste entre texto e fundo
4. **Consistência**: Paleta unificada em toda a interface
5. **Performance**: Menos overhead de renderização em TTY
6. **Identidade Visual Forte**: Design memorável e distinto

## Próximos Passos

1. Implementar o sistema de UI completo
2. Criar biblioteca de componentes reutilizáveis
3. Desenvolver sistema de temas para fácil customização
4. Adicionar suporte a diferentes tamanhos de terminal
5. Implementar testes de acessibilidade
6. Documentar API do sistema de UI
7. Criar exemplos de uso para cada componente

## Conclusão

Esta proposta apresenta um sistema de UI TUI sofisticado e elegante, utilizando princípios de design monocromático para criar uma experiência de instalação premium. O sistema é modular, extensível e focado em usabilidade e estética.
