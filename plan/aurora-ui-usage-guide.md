# Aurora UI System - Guia de Uso e Customização

## Índice

1. [Introdução](#introdução)
2. [Instalação Rápida](#instalação-rápida)
3. [Primeiros Passos](#primeiros-passos)
4. [Customização de Cores](#customização-de-cores)
5. [Criando Componentes Personalizados](#criando-componentes-personalizados)
6. [Padrões de Design](#padrões-de-design)
7. [Exemplos Práticos](#exemplos-práticos)
8. [Solução de Problemas](#solução-de-problemas)
9. [Perguntas Frequentes](#perguntas-frequentes)

## Introdução

O Aurora UI System é uma biblioteca de interface de usuário para terminais TTY que permite criar instaladores e aplicações de linha de comando com design monocromático sofisticado e elegante.

### Características Principais

- **Design Monocromático**: Paleta de cores elegante e profissional
- **Componentes Modulares**: Sistema de componentes reutilizáveis
- **Animações Suaves**: Loading e progresso com animações elegantes
- **Fácil Customização**: Sistema de cores e temas flexível
- **Alta Performance**: Otimizado para terminais TTY

## Instalação Rápida

### Método 1: Local

```bash
# Clone ou copie o arquivo
cp aurora-ui-system.sh /usr/local/bin/aurora-ui.sh

# Torne executável
chmod +x /usr/local/bin/aurora-ui.sh

# Carregue em seu script
source /usr/local/bin/aurora-ui.sh
```

### Método 2: No Projeto

```bash
# Copie para o diretório do projeto
cp aurora-ui-system.sh ./scripts/

# Carregue no seu script
source ./scripts/aurora-ui-system.sh
```

### Verificação de Instalação

```bash
# Crie um script de teste
cat > test-aurora.sh << 'EOF'
#!/bin/bash
source ./aurora-ui-system.sh

logo_animated
echo ""
render_text "Aurora UI System instalado com sucesso!" "h1" $HIGHLIGHT
EOF

chmod +x test-aurora.sh
./test-aurora.sh
```

## Primeiros Passos

### Script Básico

```bash
#!/bin/bash
source ./aurora-ui-system.sh

# Exibe logo
logo_animated

# Adiciona espaçamento
vspace 2

# Exibe título
render_text "Meu Primeiro Script" "h1" $HIGHLIGHT

# Exibe card
echo ""
create_card "Informações" "Este é meu primeiro script usando Aurora UI System"

# Pausa
pause
```

### Script Interativo

```bash
#!/bin/bash
source ./aurora-ui-system.sh

logo_static
vspace 1

# Menu de opções
create_menu "Selecione uma opção" \
    "Ver informações do sistema" \
    "Executar teste" \
    "Sair"

local choice=$?

case $choice in
    0)
        clear
        create_card "Informações" "CPU: $(nproc) núcleos\nMemória: $(free -h | grep Mem | awk '{print $2}')"
        pause
        ;;
    1)
        clear
        animate_loading "Executando teste..." 2
        success_box "Teste concluído com sucesso!"
        pause
        ;;
    2)
        clear
        render_text "Obrigado por usar Aurora UI System!" "h1" $HIGHLIGHT
        ;;
esac
```

## Customização de Cores

### Sobrescrevendo Cores

Você pode sobrescrever as cores padrão definindo novas constantes antes de carregar o sistema:

```bash
#!/bin/bash

# Customização de cores
PRIMARY=235        # Fundo mais escuro
SECONDARY=238      # Fundo secundário mais escuro
ACCENT=246         # Acentos mais claros
HIGHLIGHT=250      # Destaques mais brilhantes
TEXT_PRIMARY=255   # Texto quase branco
TEXT_SECONDARY=248 # Texto secundário mais claro
TEXT_MUTED=246     # Texto sutil mais claro

# Carrega o sistema
source ./aurora-ui-system.sh

logo_animated
```

### Criando Temas

Crie um arquivo de tema separado:

```bash
# tema-claro.sh
PRIMARY=252        # Fundo claro
SECONDARY=248      # Fundo secundário claro
ACCENT=240         # Acentos escuros
HIGHLIGHT=236      # Destaques escuros
TEXT_PRIMARY=236   # Texto escuro
TEXT_SECONDARY=240 # Texto secundário escuro
TEXT_MUTED=244     # Texto sutil médio
```

Uso:

```bash
#!/bin/bash
source ./tema-claro.sh
source ./aurora-ui-system.sh

logo_animated
```

### Tema Azul

```bash
# tema-azul.sh
PRIMARY=17         # Azul escuro
SECONDARY=24       # Azul médio
ACCENT=31          # Azul claro
HIGHLIGHT=39       # Azul brilhante
TEXT_PRIMARY=255   # Texto branco
TEXT_SECONDARY=117 # Texto ciano claro
TEXT_MUTED=67      # Texto ciano escuro
```

### Tema Verde

```bash
# tema-verde.sh
PRIMARY=22         # Verde escuro
SECONDARY=28       # Verde médio
ACCENT=34          # Verde claro
HIGHLIGHT=46       # Verde brilhante
TEXT_PRIMARY=255   # Texto branco
TEXT_SECONDARY=120 # Texto verde claro
TEXT_MUTED=70      # Texto verde escuro
```

## Criando Componentes Personalizados

### Componente de Tabela

```bash
create_table() {
    local headers=("$@")
    local rows=()
    local col_width=20
    
    # Cabeçalho
    local header_line=""
    for header in "${headers[@]}"; do
        header_line+=$(printf "%-${col_width}s" "$header")
    done
    echo -e "\033[1;38;5;${HIGHLIGHT}m${header_line}\033[0m"
    
    # Separador
    local separator=""
    for header in "${headers[@]}"; do
        separator+=$(printf '%0.s' "-$(seq 1 $col_width)")
    done
    echo -e "\033[38;5;${BORDER}m${separator}\033[0m"
    
    # Linhas
    for row in "${rows[@]}"; do
        local row_line=""
        for cell in "${row[@]}"; do
            row_line+=$(printf "%-${col_width}s" "$cell")
        done
        echo -e "\033[38;5;${TEXT_PRIMARY}m${row_line}\033[0m"
    done
}
```

Uso:

```bash
create_table "Nome" "Idade" "Cidade"
rows=(
    ("João" "30" "São Paulo")
    ("Maria" "25" "Rio de Janeiro")
    ("Pedro" "35" "Belo Horizonte")
)
```

### Componente de Lista com Ícones

```bash
create_icon_list() {
    local items=("$@")
    
    for item in "${items[@]}"; do
        local icon="${item%%:*}"
        local text="${item#*:}"
        echo -e "\033[38;5;${HIGHLIGHT}m${icon}\033[0m \033[38;5;${TEXT_PRIMARY}m${text}\033[0m"
    done
}
```

Uso:

```bash
create_icon_list \
    "✓:Instalação concluída" \
    "⚠:Atenção necessária" \
    "✖:Erro detectado" \
    "ℹ:Informação adicional"
```

### Componente de Progresso Circular

```bash
create_circular_progress() {
    local percentage=$1
    local size=${2:-20}
    local filled=$((percentage * size / 100))
    local empty=$((size - filled))
    
    # Círculo de progresso
    local circle=""
    for ((i=0; i<size; i++)); do
        if [ $i -lt $filled ]; then
            circle+="●"
        else
            circle+="○"
        fi
    done
    
    echo -e "\033[38;5;${HIGHLIGHT}m${circle}\033[0m \033[38;5;${TEXT_PRIMARY}m${percentage}%\033[0m"
}
```

Uso:

```bash
for i in {0..100..10}; do
    clear
    create_circular_progress $i
    sleep 0.5
done
```

## Padrões de Design

### Padrão de Tela

```bash
#!/bin/bash
source ./aurora-ui-system.sh

# 1. Logo
logo_animated

# 2. Badge de status
echo ""
create_badge "MODO INSTALAÇÃO" "info"

# 3. Título principal
vspace 1
render_text "Título da Tela" "h1" $HIGHLIGHT

# 4. Conteúdo
vspace 1
create_card "Informações" "Conteúdo da tela"

# 5. Ações
vspace 1
create_button "Continuar" "primary"
echo ""
create_button "Cancelar" "secondary"

# 6. Pausa
vspace 1
pause
```

### Padrão de Feedback

```bash
# 1. Executa operação
animate_loading "Processando..." 2

# 2. Exibe feedback
show_toast "Operação concluída!" "success" 2

# 3. Continua
vspace 1
```

### Padrão de Validação

```bash
validate_input() {
    local input=$1
    local pattern=$2
    local error_msg=$3
    
    if [[ ! "$input" =~ $pattern ]]; then
        error_box "$error_msg"
        return 1
    fi
    
    success_box "Entrada válida"
    return 0
}

# Uso
while true; do
    echo -e "\033[38;5;${TEXT_MUTED}mDigite um email:\033[0m"
    read email
    
    if validate_input "$email" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "Email inválido"; then
        break
    fi
done
```

## Exemplos Práticos

### Exemplo 1: Instalador Simples

```bash
#!/bin/bash
source ./aurora-ui-system.sh

# Tela inicial
logo_animated
echo ""
create_badge "INSTALADOR v1.0" "info"

vspace 1
render_text "Bem-vindo ao Instalador" "h1" $HIGHLIGHT

vspace 1
create_card "Este instalador irá configurar seu sistema automaticamente." \
    "Passos:\n1. Verificar requisitos\n2. Baixar arquivos\n3. Instalar\n4. Configurar"

pause

# Verificação
clear
logo_static
echo ""
render_text "Verificando Requisitos" "h1" $HIGHLIGHT
vspace 1

animate_loading "Verificando espaço em disco..." 1
animate_loading "Verificando dependências..." 1
animate_loading "Verificando permissões..." 1

success_box "Todos os requisitos atendidos"
pause

# Instalação
clear
logo_static
echo ""
render_text "Instalando" "h1" $HIGHLIGHT
vspace 1

for i in {1..100}; do
    animate_progress $i 100 "Progresso da instalação"
    sleep 0.05
done
echo ""

success_box "Instalação concluída com sucesso!"
pause

# Finalização
clear
logo_static
echo ""
create_card "Instalação Concluída" "✓ Sistema instalado\n✓ Configuração aplicada\n✓ Pronto para uso"

vspace 1
show_toast "Instalação finalizada!" "success" 3
```

### Exemplo 2: Dashboard de Sistema

```bash
#!/bin/bash
source ./aurora-ui-system.sh

while true; do
    clear
    logo_static
    
    # Informações do sistema
    echo ""
    render_text "Dashboard do Sistema" "h1" $HIGHLIGHT
    vspace 1
    
    create_card "Informações" \
        "CPU: $(nproc) núcleos\nMemória: $(free -h | grep Mem | awk '{print $3}') / $(free -h | grep Mem | awk '{print $2}')\nDisco: $(df -h / | tail -1 | awk '{print $3}') / $(df -h / | tail -1 | awk '{print $2}')\nUptime: $(uptime -p)"
    
    # Menu
    echo ""
    create_menu "Selecione uma opção" \
        "Atualizar sistema" \
        "Ver logs" \
        "Reiniciar serviço" \
        "Sair"
    
    local choice=$?
    
    case $choice in
        0)
            clear
            animate_loading "Atualizando sistema..." 3
            success_box "Sistema atualizado!"
            pause
            ;;
        1)
            clear
            create_card "Logs Recentes" "$(journalctl -n 10 --no-pager)"
            pause
            ;;
        2)
            clear
            animate_loading "Reiniciando serviço..." 2
            success_box "Serviço reiniciado!"
            pause
            ;;
        3)
            clear
            render_text "Obrigado por usar o Dashboard!" "h1" $HIGHLIGHT
            exit 0
            ;;
    esac
done
```

### Exemplo 3: Assistente de Configuração

```bash
#!/bin/bash
source ./aurora-ui-system.sh

# Variáveis de configuração
CONFIG_HOSTNAME=""
CONFIG_USER=""
CONFIG_EMAIL=""

# Passo 1: Hostname
logo_static
echo ""
render_text "Configuração - Passo 1/3" "h1" $HIGHLIGHT
vspace 1

create_card "Hostname" "Digite o nome do host para o sistema"
echo ""

while [ -z "$CONFIG_HOSTNAME" ]; do
    echo -e "\033[38;5;${TEXT_MUTED}mHostname:\033[0m"
    read CONFIG_HOSTNAME
    
    if [ -z "$CONFIG_HOSTNAME" ]; then
        error_box "Hostname não pode estar vazio"
    fi
done

# Passo 2: Usuário
clear
logo_static
echo ""
render_text "Configuração - Passo 2/3" "h1" $HIGHLIGHT
vspace 1

create_card "Usuário" "Digite o nome do usuário administrador"
echo ""

while [ -z "$CONFIG_USER" ]; do
    echo -e "\033[38;5;${TEXT_MUTED}mUsuário:\033[0m"
    read CONFIG_USER
    
    if [ -z "$CONFIG_USER" ]; then
        error_box "Usuário não pode estar vazio"
    fi
done

# Passo 3: Email
clear
logo_static
echo ""
render_text "Configuração - Passo 3/3" "h1" $HIGHLIGHT
vspace 1

create_card "Email" "Digite o email do administrador"
echo ""

while [ -z "$CONFIG_EMAIL" ]; do
    echo -e "\033[38;5;${TEXT_MUTED}mEmail:\033[0m"
    read CONFIG_EMAIL
    
    if [ -z "$CONFIG_EMAIL" ]; then
        error_box "Email não pode estar vazio"
    fi
done

# Resumo
clear
logo_static
echo ""
render_text "Resumo da Configuração" "h1" $HIGHLIGHT
vspace 1

create_card "Configurações" \
    "Hostname: $CONFIG_HOSTNAME\nUsuário: $CONFIG_USER\nEmail: $CONFIG_EMAIL"

echo ""
echo -e "\033[38;5;${TEXT_MUTED}mConfirmar configuração? (s/n)\033[0m"
read confirm

if [ "$confirm" = "s" ] || [ "$confirm" = "S" ]; then
    clear
    animate_loading "Aplicando configuração..." 2
    success_box "Configuração aplicada com sucesso!"
else
    clear
    warning_box "Configuração cancelada"
fi

pause
```

## Solução de Problemas

### Cores não aparecem corretamente

**Problema**: As cores não são exibidas ou aparecem incorretamente.

**Solução**:

```bash
# Verifique se o terminal suporta 256 cores
echo $TERM

# Se necessário, defina explicitamente
export TERM=xterm-256color
```

### Animações travam

**Problema**: Animações não funcionam ou travam.

**Solução**:

```bash
# Desabilite animações para terminais lentos
ANIMATIONS_ENABLED=false

# Modifique as funções de animação
animate_loading() {
    local text=$1
    local duration=${2:-2}
    
    if [ "$ANIMATIONS_ENABLED" = "true" ]; then
        # Animação completa
        ...
    else
        # Simples loading
        echo -e "\033[38;5;${TEXT_SECONDARY}m${text}...\033[0m"
        sleep $duration
        echo -e "\033[38;5;${SUCCESS}m✓\033[0m \033[38;5;${TEXT_PRIMARY}m${text}\033[0m"
    fi
}
```

### Tamanho do terminal inadequado

**Problema**: Layout quebra em terminais pequenos.

**Solução**:

```bash
# Verifique o tamanho do terminal
check_terminal_size() {
    local min_width=80
    local min_height=24
    
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    
    if [ $term_width -lt $min_width ] || [ $term_height -lt $min_height ]; then
        error_box "Terminal muito pequeno. Mínimo: ${min_width}x${min_height}"
        exit 1
    fi
}

check_terminal_size
```

### Caracteres especiais não aparecem

**Problema**: Caracteres como ┌, ─, │ não aparecem.

**Solução**:

```bash
# Use caracteres ASCII alternativos
create_box_ascii() {
    local content=$1
    local width=${2:-60}
    
    echo "+$(printf '%0.s' "-$(seq 1 $((width-2)))+"
    while IFS= read -r line; do
        echo "| ${line}$(printf ' %.0s' $(seq 1 $((width - ${#line} - 3)))|"
    done <<< "$content"
    echo "+$(printf '%0.s' "-$(seq 1 $((width-2)))+"
}
```

## Perguntas Frequentes

### Q: Posso usar o Aurora UI System em scripts comerciais?

**R**: Sim, o Aurora UI System é desenvolvido como parte do projeto Aurora Installer e pode ser usado em projetos comerciais e pessoais.

### Q: O sistema funciona em todos os terminais?

**R**: O sistema funciona melhor em terminais que suportam 256 cores e caracteres Unicode. Para terminais mais antigos, pode ser necessário usar caracteres ASCII alternativos.

### Q: Como posso contribuir com o projeto?

**R**: Você pode contribuir criando novos componentes, melhorando a documentação, reportando bugs ou sugerindo melhorias.

### Q: É possível criar temas personalizados?

**R**: Sim, você pode criar temas personalizados sobrescrevendo as constantes de cores ou criando arquivos de tema separados.

### Q: O sistema tem dependências externas?

**R**: Não, o Aurora UI System é escrito puramente em Bash e não tem dependências externas além do próprio Bash.

### Q: Posso usar o sistema em scripts que não são instaladores?

**R**: Sim, o sistema pode ser usado em qualquer tipo de script de linha de comando que precise de uma interface visual elegante.

## Conclusão

O Aurora UI System oferece uma solução elegante e profissional para criar interfaces de usuário em terminais TTY. Com sua paleta monocromática sofisticada e sistema de componentes modulares, você pode criar instaladores e aplicações de linha de comando com uma experiência visual premium.

Para mais informações, consulte a documentação da API em [`aurora-ui-api-documentation.md`](aurora-ui-api-documentation.md) e a proposta de design em [`aurora-monochromatic-design-proposal.md`](aurora-monochromatic-design-proposal.md).
