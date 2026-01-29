# Aurora UI System - Documentação da API

## Visão Geral

O Aurora UI System é uma biblioteca modular de interface de usuário (UI) para terminais TTY, desenvolvida para criar instaladores e aplicações de linha de comando com design monocromático sofisticado e elegante.

## Instalação

```bash
# Clone ou copie o arquivo aurora-ui-system.sh
cp aurora-ui-system.sh /usr/local/bin/aurora-ui.sh

# Torne executável
chmod +x aurora-ui-system.sh

# Carregue em seu script
source ./aurora-ui-system.sh
```

## Paleta de Cores

O sistema utiliza uma paleta monocromática baseada em tons de cinza/azul-acinzentado:

| Constante        | Valor | Descrição                  |
|------------------|-------|----------------------------|
| `PRIMARY`        | 236   | Fundo principal (#303030)  |
| `SECONDARY`      | 240   | Fundo secundário (#585858) |
| `ACCENT`         | 244   | Acentos sutis (#808080)    |
| `HIGHLIGHT`      | 248   | Destaques (#a8a8a8)        |
| `TEXT_PRIMARY`   | 252   | Texto principal (#d0d0d0)  |
| `TEXT_SECONDARY` | 246   | Texto secundário (#949494) |
| `TEXT_MUTED`     | 244   | Texto sutil (#808080)      |
| `SUCCESS`        | 242   | Sucesso (#585858)          |
| `WARNING`        | 242   | Aviso (#585858)            |
| `ERROR`          | 242   | Erro (#585858)             |
| `BORDER`         | 240   | Bordas (#585858)           |
| `SHADOW`         | 234   | Sombras (#1c1c1c)          |

## Sistema de Cores Dinâmico

### `get_color(base_color, opacity)`

Retorna uma cor com opacidade simulada.

**Parâmetros:**

- `base_color` (int): Cor base (código ANSI 256-color)
- `opacity` (int): Opacidade de 0 a 100

**Retorno:**

- (int): Código de cor ajustado

**Exemplo:**

```bash
local color=$(get_color $TEXT_PRIMARY 80)
echo -e "\033[38;5;${color}mTexto com opacidade\033[0m"
```

### `create_gradient(text, start_color, end_color)`

Cria um gradiente monocromático para o texto.

**Parâmetros:**

- `text` (string): Texto para aplicar gradiente
- `start_color` (int): Cor inicial
- `end_color` (int): Cor final

**Retorno:**

- (string): Texto com códigos de escape ANSI

**Exemplo:**

```bash
local gradient=$(create_gradient "AURORA" 236 252)
echo -e "$gradient"
```

## Sistema de Tipografia

### `render_text(text, level, color)`

Renderiza texto com hierarquia visual.

**Parâmetros:**

- `text` (string): Texto a renderizar
- `level` (string): Nível de hierarquia (h1, h2, h3, body, caption)
- `color` (int, opcional): Código de cor (padrão: TEXT_PRIMARY)

**Retorno:**

- (string): Texto formatado com códigos ANSI

**Exemplo:**

```bash
render_text "Título Principal" "h1" $HIGHLIGHT
render_text "Subtítulo" "h2" $TEXT_PRIMARY
render_text "Texto de corpo" "body" $TEXT_SECONDARY
render_text "Legenda" "caption" $TEXT_MUTED
```

### `vspace(lines)`

Cria espaçamento vertical.

**Parâmetros:**

- `lines` (int, opcional): Número de linhas em branco (padrão: 1)

**Exemplo:**

```bash
vspace 2  # Cria 2 linhas em branco
```

### `center_text(text, width)`

Centraliza texto em uma largura específica.

**Parâmetros:**

- `text` (string): Texto a centralizar
- `width` (int, opcional): Largura total (padrão: 80)

**Retorno:**

- (string): Texto centralizado com espaçamento

**Exemplo:**

```bash
echo "$(center_text "Texto Centralizado" 60)"
```

## Sistema de Layout

### `create_box(content, width, border_color, bg_color)`

Cria um container com bordas.

**Parâmetros:**

- `content` (string): Conteúdo do box (suporta múltiplas linhas)
- `width` (int, opcional): Largura do box (padrão: 60)
- `border_color` (int, opcional): Cor da borda (padrão: BORDER)
- `bg_color` (int, opcional): Cor de fundo (padrão: PRIMARY)

**Exemplo:**

```bash
create_box "Linha 1\nLinha 2\nLinha 3" 50 $BORDER $PRIMARY
```

### `create_grid(columns, column_width, items...)`

Cria um layout em grid.

**Parâmetros:**

- `columns` (int): Número de colunas
- `column_width` (int): Largura de cada coluna
- `items` (array): Itens a exibir

**Exemplo:**

```bash
create_grid 3 30 "Item 1" "Item 2" "Item 3" "Item 4" "Item 5" "Item 6"
```

## Sistema de Animações

### `animate_loading(text, duration)`

Exibe uma animação de loading com spinner.

**Parâmetros:**

- `text` (string): Texto a exibir
- `duration` (int, opcional): Duração em segundos (padrão: 2)

**Exemplo:**

```bash
animate_loading "Processando..." 3
```

### `animate_progress(current, total, label)`

Exibe uma barra de progresso animada.

**Parâmetros:**

- `current` (int): Valor atual
- `total` (int): Valor total
- `label` (string): Rótulo da barra de progresso

**Exemplo:**

```bash
for i in {1..100}; do
    animate_progress $i 100 "Progresso"
    sleep 0.05
done
echo ""
```

## Sistema de Componentes

### `create_card(title, content, width)`

Cria um card com sombra.

**Parâmetros:**

- `title` (string): Título do card
- `content` (string): Conteúdo do card
- `width` (int, opcional): Largura do card (padrão: 60)

**Exemplo:**

```bash
create_card "Informações" "Nome: João\nIdade: 30\nCidade: São Paulo"
```

### `create_badge(text, type)`

Cria um badge elegante.

**Parâmetros:**

- `text` (string): Texto do badge
- `type` (string, opcional): Tipo do badge (info, success, warning, error, padrão: info)

**Exemplo:**

```bash
create_badge "NOVO" "info"
create_badge "CONCLUÍDO" "success"
create_badge "ATENÇÃO" "warning"
create_badge "ERRO" "error"
```

### `create_input(placeholder, value, width)`

Cria um campo de input estilizado (apenas visual).

**Parâmetros:**

- `placeholder` (string): Texto do placeholder
- `value` (string, opcional): Valor atual (padrão: vazio)
- `width` (int, opcional): Largura do input (padrão: 40)

**Exemplo:**

```bash
create_input "Nome do usuário" "joao"
```

### `create_button(text, type)`

Cria um botão estilizado (apenas visual).

**Parâmetros:**

- `text` (string): Texto do botão
- `type` (string, opcional): Tipo do botão (primary, secondary, danger, padrão: primary)

**Exemplo:**

```bash
create_button "Confirmar" "primary"
create_button "Cancelar" "secondary"
create_button "Excluir" "danger"
```

## Logo

### `logo_animated()`

Exibe o logo com efeito de fade-in animado.

**Exemplo:**

```bash
logo_animated
```

### `logo_static()`

Exibe o logo estático.

**Exemplo:**

```bash
logo_static
```

## Sistema de Navegação

### `create_menu(title, options...)`

Cria um menu de navegação interativo.

**Parâmetros:**

- `title` (string): Título do menu
- `options` (array): Opções do menu

**Retorno:**

- (int): Índice da opção selecionada

**Exemplo:**

```bash
create_menu "Selecione uma opção" \
    "Opção 1" \
    "Opção 2" \
    "Opção 3"

local selected=$?
echo "Você selecionou: $selected"
```

## Sistema de Feedback Visual

### `show_toast(message, type, duration)`

Exibe uma notificação toast elegante.

**Parâmetros:**

- `message` (string): Mensagem a exibir
- `type` (string, opcional): Tipo (success, error, warning, info, padrão: info)
- `duration` (int, opcional): Duração em segundos (padrão: 3)

**Exemplo:**

```bash
show_toast "Operação concluída com sucesso!" "success" 2
show_toast "Erro ao processar" "error" 3
```

### `show_modal(title, message, buttons...)`

Exibe um modal dialog elegante.

**Parâmetros:**

- `title` (string): Título do modal
- `message` (string): Mensagem do modal
- `buttons` (array): Botões do modal

**Exemplo:**

```bash
show_modal "Confirmação" "Deseja continuar?" "Sim" "Não"
```

## Sistema de Progresso Multi-Etapa

### `create_step_progress(current_step, total_steps, steps...)`

Exibe uma barra de progresso com etapas.

**Parâmetros:**

- `current_step` (int): Etapa atual
- `total_steps` (int): Total de etapas
- `steps` (array): Nomes das etapas

**Exemplo:**

```bash
create_step_progress 2 5 \
    "Preparação" \
    "Download" \
    "Instalação" \
    "Configuração" \
    "Finalização"
```

## Componentes de Feedback

### `success_box(message)`

Exibe um box de sucesso.

**Parâmetros:**

- `message` (string): Mensagem de sucesso

**Exemplo:**

```bash
success_box "Operação concluída com sucesso!"
```

### `error_box(message)`

Exibe um box de erro.

**Parâmetros:**

- `message` (string): Mensagem de erro

**Exemplo:**

```bash
error_box "Erro ao processar operação"
```

### `warning_box(message)`

Exibe um box de aviso.

**Parâmetros:**

- `message` (string): Mensagem de aviso

**Exemplo:**

```bash
warning_box "Atenção: Esta operação é irreversível"
```

### `info_box(message)`

Exibe um box de informação.

**Parâmetros:**

- `message` (string): Mensagem de informação

**Exemplo:**

```bash
info_box "Para continuar, pressione Enter"
```

## Funções de Utilidade

### `clear_screen()`

Limpa a tela.

**Exemplo:**

```bash
clear_screen
```

### `pause()`

Pausa a execução aguardando Enter.

**Exemplo:**

```bash
pause
```

### `separator(width)`

Exibe um separador horizontal.

**Parâmetros:**

- `width` (int, opcional): Largura do separador (padrão: 60)

**Exemplo:**

```bash
separator 80
```

### `decorative_line(width)`

Exibe uma linha decorativa.

**Parâmetros:**

- `width` (int, opcional): Largura da linha (padrão: 60)

**Exemplo:**

```bash
decorative_line 60
```

## Exemplo Completo

```bash
#!/bin/bash
source ./aurora-ui-system.sh

# Logo animado
logo_animated

# Badge
echo ""
create_badge "MODO DEMONSTRAÇÃO" "info"

# Título
echo ""
render_text "Bem-vindo ao Aurora UI System" "h1" $HIGHLIGHT

# Card
echo ""
create_card "Informações" "Este é um exemplo de uso do Aurora UI System"

# Input
echo ""
create_input "Nome" "Usuário"

# Botões
echo ""
create_button "Confirmar" "primary"
echo ""
create_button "Cancelar" "secondary"

# Progresso
echo ""
for i in {1..100}; do
    animate_progress $i 100 "Processando"
    sleep 0.02
done
echo ""

# Toast
show_toast "Processamento concluído!" "success" 2

# Pausa
pause
```

## Melhores Práticas

1. **Consistência**: Use sempre as constantes de cores definidas
2. **Hierarquia**: Utilize os níveis de tipografia apropriados
3. **Espaçamento**: Mantenha espaçamento consistente usando `vspace()`
4. **Feedback**: Forneça feedback visual com `show_toast()` ou boxes
5. **Acessibilidade**: Mantenha alto contraste entre texto e fundo
6. **Performance**: Evite animações excessivas em operações críticas

## Limitações

- Requer terminal com suporte a 256 cores
- Algumas animações podem não funcionar corretamente em todos os terminais
- Componentes de input são apenas visuais (requer implementação separada para captura de dados)

## Contribuindo

Para contribuir com o Aurora UI System:

1. Mantenha a consistência com a paleta monocromática
2. Siga os padrões de nomenclatura existentes
3. Adicione documentação para novas funções
4. Teste em diferentes terminais

## Licença

Este projeto é desenvolvido como parte do Aurora Installer para Debian ZFS NAS.
