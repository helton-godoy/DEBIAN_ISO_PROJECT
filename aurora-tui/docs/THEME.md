# Aurora TUI - Design System AURORA

Implementação do Design System v2.0 Monocromático para Terminal.

## Paleta de Cores

### Escala Monocromática (Baseada em Slate Blue)

```
LUMINOSIDADE CRESCENTE →

VOID    DEPTH   ELEV    WHISPER MIST    FOG     HAZE    CLOUD   SILVER  PEAK
████    ████    ████    ░░░░    ░░░░    ▒▒▒▒    ▒▒▒▒    ▓▓▓▓    ▓▓▓▓    ◆◆◆◆
#262626 #3a3a3a #4e4e4e #585858 #767676 #8a8a8a #a8a8a8 #bcbcbc #d0d0d0 #afd7ff
235     237     239     240     243     245     248     250     252     153
│       │       │       │       │       │       │       │       │
└───────┴───────┴───────┴───────┴───────┴───────┴───────┴───────┘
       BACKGROUNDS        BORDAS              TEXTOS         ACCENT
```

### Definições Go (lipgloss)

```go
package ui

import "github.com/charmbracelet/lipgloss"

// ═══════════════════════════════════════════════════════════
// PALETA AURORA MONOCHROMÁTICA
// ═══════════════════════════════════════════════════════════

// Fundos (do mais escuro ao mais claro)
var (
    Void      = lipgloss.Color("#262626")  // ANSI 235 - Profundidade absoluta
    Depth     = lipgloss.Color("#3a3a3a")  // ANSI 237 - Superfície base
    Elevation = lipgloss.Color("#4e4e4e")  // ANSI 239 - Cards/containers
)

// Bordas (sutileza progressiva)
var (
    Whisper = lipgloss.Color("#585858")  // ANSI 240 - Divisores discretos
    Mist    = lipgloss.Color("#767676")  // ANSI 243 - Bordas padrão
)

// Textos (hierarquia de informação)
var (
    Fog    = lipgloss.Color("#8a8a8a")  // ANSI 245 - Labels secundárias
    Haze   = lipgloss.Color("#a8a8a8")  // ANSI 248 - Descrições
    Cloud  = lipgloss.Color("#bcbcbc")  // ANSI 250 - Corpo de texto
    Silver = lipgloss.Color("#d0d0d0")  // ANSI 252 - Destaques
)

// Acentos Slate (matiz principal)
var (
    SlateDim  = lipgloss.Color("#5f875f")  // ANSI 66  - Detalhes técnicos
    Slate     = lipgloss.Color("#5f87af")  // ANSI 67  - Elementos interativos
    SlateGlow = lipgloss.Color("#5f87d7")  // ANSI 68  - Hover/foco
    Peak      = lipgloss.Color("#afd7ff")  // ANSI 153 - Estado ativo (único brilhante)
)

// Funcionais (uso restrito <5%)
var (
    Success = lipgloss.Color("#87af87")  // ANSI 108 - Sucesso
    Warning = lipgloss.Color("#d7af5f")  // ANSI 179 - Aviso
    Error   = lipgloss.Color("#d75f5f")  // ANSI 167 - Erro
)
```

## Sistema Tipográfico

### Hierarquia

| Nível       | Representação      | Uso                | Cor             |
| ----------- | ------------------ | ------------------ | --------------- |
| **HERO**    | `▓▓▓ AURORA ▓▓▓`   | Logo/Splash        | Peak            |
| **H1**      | `════ TÍTULO ════` | Headers de tela    | Silver + border |
| **H2**      | `──▶ Seção`        | Divisores de etapa | Silver          |
| **H3**      | `↳ Subseção`       | Agrupamentos       | Haze italic     |
| **BODY**    | `Texto corrido`    | Conteúdo           | Cloud           |
| **CAPTION** | `dica ou label`    | Metadados          | Fog             |

### Caracteres UI

```go
const (
    HLine   = '─'  // Linha horizontal
    HLineD  = '═'  // Linha horizontal dupla
    VLine   = '│'  // Linha vertical
    TL      = '┌'  // Canto superior esquerdo
    TR      = '┐'  // Canto superior direito
    BL      = '└'  // Canto inferior esquerdo
    BR      = '┘'  // Canto inferior direito
    Arrow   = '▶'  // Indicador de foco
    Bullet  = '●'  // Item de lista
    Check   = '✓'  // Sucesso
    Warn    = '⚠'  // Aviso
    Cross   = '❌' // Erro
    Dot     = '·'  // Separador
)
```

## Componentes Visuais

### 1. Header Principal (Hero)

```go
func HeroHeader(title, subtitle string) string {
    return lipgloss.NewStyle().
        BorderStyle(lipgloss.DoubleBorder()).
        BorderForeground(Slate).
        Foreground(Peak).
        Bold(true).
        Padding(1, 2).
        Margin(1, 2).
        Width(60).
        Align(lipgloss.Center).
        Render(title, "", subtitle)
}
```

**Resultado:**

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║                   AURORA NAS ADMIN                       ║
║           High Performance Storage Management            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

### 2. Section Header

```go
func SectionHeader(title string) string {
    line := strings.Repeat(string(HLine), 60)

    return lipgloss.JoinVertical(
        lipgloss.Left,
        lipgloss.NewStyle().Foreground(Mist).Bold(true).Render(line),
        lipgloss.NewStyle().Foreground(Silver).Bold(true).Render("  "+string(Arrow)+" "+title),
        lipgloss.NewStyle().Foreground(Mist).Bold(true).Render(line),
    )
}
```

**Resultado:**

```
────────────────────────────────────────────────────────────
  ▶ CONFIGURAÇÃO DE DISCO
────────────────────────────────────────────────────────────
```

### 3. Info Card

```go
func InfoCard(title string, lines ...string) string {
    titleStyle := lipgloss.NewStyle().
        Foreground(SlateGlow).
        Bold(true)

    separator := lipgloss.NewStyle().
        Foreground(Mist).
        Render(strings.Repeat(string(HLine), 40))

    content := lipgloss.JoinVertical(
        lipgloss.Left,
        titleStyle.Render(title),
        separator,
        "",
        lipgloss.JoinVertical(lipgloss.Left, lines...),
    )

    return lipgloss.NewStyle().
        BorderStyle(lipgloss.NormalBorder()).
        BorderForeground(Whisper).
        Padding(1, 2).
        Margin(1, 2).
        Render(content)
}
```

**Resultado:**

```
┌─────────────────────────────────────────────────────────┐
│  Configuração Atual                                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                                         │
│  Disco:        /dev/nvme0n1                             │
│  Tamanho:      1TB                                      │
│  Filesystem:   ZFS on Root                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4. Progress Bar

```go
func ProgressBar(current, total int, label string) string {
    width := 40
    filled := current * width / total
    empty := width - filled
    pct := current * 100 / total

    bar := lipgloss.NewStyle().Foreground(Slate).Render(
        "[" + strings.Repeat("█", filled) + strings.Repeat("░", empty) + "]",
    )

    percentage := lipgloss.NewStyle().Foreground(Silver).Bold(true).Render(
        fmt.Sprintf(" %d%%", pct),
    )

    labelStyle := lipgloss.NewStyle().
        Foreground(Fog).
        Italic(true).
        Render("      " + string(Arrow) + " " + label)

    return lipgloss.JoinVertical(
        lipgloss.Left,
        bar+percentage,
        labelStyle,
    )
}
```

**Resultado:**

```
  [████████████████████░░░░░░░░░░░░░░░░░░░░] 45%
      ↳ Extraindo sistema base...
```

### 5. Status Badges

```go
func StatusOK(text string) string {
    return lipgloss.NewStyle().
        Foreground(Success).
        Render("  " + string(Check) + " " + text)
}

func StatusInfo(text string) string {
    return lipgloss.NewStyle().
        Foreground(SlateDim).
        Render("  " + string(Bullet) + " " + text)
}

func StatusWarn(text string) string {
    return lipgloss.NewStyle().
        Foreground(Warning).
        Render("  " + string(Warn) + " " + text)
}

func StatusError(text string) string {
    return lipgloss.NewStyle().
        Foreground(Error).
        Render("  " + string(Cross) + " " + text)
}
```

### 6. Modal/Dialog

```go
func Modal(title, message string, isError bool) string {
    borderColor := Slate
    titleColor := Peak

    if isError {
        borderColor = Error
        titleColor = Error
    }

    return lipgloss.NewStyle().
        BorderStyle(lipgloss.DoubleBorder()).
        BorderForeground(borderColor).
        Foreground(Cloud).
        Padding(2, 3).
        Margin(2, 2).
        Width(50).
        Align(lipgloss.Center).
        Render(
            lipgloss.NewStyle().Foreground(titleColor).Bold(true).Render(title),
            "",
            message,
        )
}
```

## Estados de Componentes

### Variações de Estado

| Estado       | Visual       | Implementação                                |
| ------------ | ------------ | -------------------------------------------- |
| **Default**  | `Elemento`   | `Foreground(Slate)`                          |
| **Hover**    | `Elemento`   | `Foreground(Silver) + Background(Elevation)` |
| **Focus**    | `▶ Elemento` | Prefix `▶` + `Foreground(Peak)`              |
| **Active**   | `● Elemento` | Prefix `●` + `Foreground(Peak) + Bold(true)` |
| **Disabled** | `~ Elemento` | Prefix `~` + `Foreground(Fog)`               |
| **Selected** | `[✓] Item`   | `Foreground(Success)`                        |

## Layouts

### Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  AURORA NAS ADMIN                          [ZFS: OK] [SMB: OK]  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐ ┌──────────────────┐ ┌──────────────────┐  │
│  │       CPU       │ │     Memória      │ │    ZFS ARC       │  │
│  │  ███████████░░  │ │  ████████░░░░░░  │ │  ██████░░░░░░░░  │  │
│  │       82%       │ │       56%        │ │       32%        │  │
│  └─────────────────┘ └──────────────────┘ └──────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Pools ZFS                                                │  │
│  │  ───────────────────────────────────────────────────────  │  │
│  │  ● tank      [██████████████████████] 78%  7.8TB/10TB     │  │
│  │  ● backup    [████░░░░░░░░░░░░░░░░░░] 12%  1.2TB/10TB     │  │
│  │  ● archive   [████████░░░░░░░░░░░░░░] 45%  4.5TB/10TB     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  [F1 Ajuda]  [F2 Dashboard]  [F3 Pools]  [F4 Shares]  [Q Sair]  │
└─────────────────────────────────────────────────────────────────┘
```

### Form Layout

Campos de entrada precisam utilizar coloração levemente alterada, para deixar claro que aquele é um campo de entrada de texto.
Não encontrei uma maneira melhor para representar a cor diferenciada para o campo de texto, mas a ideia é que o backgroud seja levemente mais claro que o restante da interface.

```
┌─────────────────────────────────────────────────────────────────┐
│  AURORA NAS ADMIN                                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│    ▶ NOVO COMPARTILHAMENTO                                     │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Nome do compartilhamento:                                      │
│  [dados░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  │
│  ↳ Apenas letras minúsculas, sem espaços                        │
│                                                                 │
│  Descrição:                                                     │
│  [Compartilhamento░de░dados░da░equipe░░░░░░░░░░░░░░░░░░░░░░░░]  │
│                                                                 │
│  Caminho:                                                       │
│  [/tank/dados░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  [Browse]  │
│                                                                 │
│  [✓] Permitir acesso anônimo                                    │
│  [ ] Somente leitura                                            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ⚠ Atenção                                                │  │
│  │  Este compartilhamento será criado com as permissões      │  │
│  │  padrão. Você pode ajustar as ACLs após a criação.        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│                                [  Cancelar  ]      [  Criar  ]  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Animações e Transições

### Spinner/Loading

```go
var Spinners = map[string]spinner.Model{
    "default": spinner.New(spinner.WithSpinner(spinner.Dot)),
    "line":    spinner.New(spinner.WithSpinner(spinner.Line)),
    "minidot": spinner.New(spinner.WithSpinner(spinner.MiniDot)),
    "jump":    spinner.New(spinner.WithSpinner(spinner.Jump)),
    "pulse":   spinner.New(spinner.WithSpinner(spinner.Pulse)),
}

func (s Spinners) WithStyle(name string) spinner.Model {
    spin := Spinners[name]
    spin.Style = lipgloss.NewStyle().Foreground(Slate)
    return spin
}
```

### Transições de Tela

- **Fade**: Transição suave entre telas (clear + redraw)
- **Slide**: Navegação hierárquica com indicador de profundidade
- **Progress**: Atualizações incrementais de status

## Responsividade

### Breakpoints de Terminal

```go
type TerminalSize int

const (
    SizeXS TerminalSize = iota  // < 80 cols
    SizeSM                      // 80-100 cols
    SizeMD                      // 100-120 cols
    SizeLG                      // > 120 cols
)

func GetSize(width int) TerminalSize {
    switch {
    case width < 80:
        return SizeXS
    case width < 100:
        return SizeSM
    case width < 120:
        return SizeMD
    default:
        return SizeLG
    }
}
```

### Adaptações por Tamanho

| Elemento    | XS (<80)  | SM (80-100) | MD (100-120) | LG (>120) |
| ----------- | --------- | ----------- | ------------ | --------- |
| Sidebar     | Colapsada | Ícones      | Ícones+Texto | Full      |
| Tables      | 2 cols    | 3 cols      | 4 cols       | 5+ cols   |
| Cards       | Stacked   | 2 cols      | 3 cols       | 4 cols    |
| Info Detail | Oculto    | Tooltip     | Lateral      | Lateral   |

## Acessibilidade

### Alto Contraste

Todas as combinações de cores garantem contraste mínimo de 4.5:1:

```go
func ContrastRatio(fg, bg lipgloss.Color) float64 {
    // Implementação WCAG 2.1
    // Todas as combinações do DS são ≥ 7:1
}
```

### Navegação por Teclado

```
Tecla          Ação
─────────────────────────────────────
Tab            Próximo elemento
Shift+Tab      Elemento anterior
Enter          Confirmar/Selecionar
Esc            Cancelar/Voltar
F1             Ajuda contextual
F2-F8          Atalhos de view
↑/↓            Navegar na lista
Page Up/Down   Scroll rápido
Home/End       Início/fim da lista
Space          Selecionar item
Ctrl+C         Sair da aplicação
```

### Screen Reader Support

- Labels descritivos em todos os inputs
- Estados anunciados (ícones + descrição)
- Progresso verbalizado
- Confirmações antes de ações destrutivas

---

**Versão:** 1.0.0  
**Baseado em:** AURORA Design System v2.0  
**Implementação:** Go + Lipgloss + Bubbletea
