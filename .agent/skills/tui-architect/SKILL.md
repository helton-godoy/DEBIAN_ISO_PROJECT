---
name: tui-architect
description: Especialista em arquitetura e design de interfaces de terminal (TUI) usando o ecossistema Charm (bubbletea, lipgloss).
---

# Skill: Arquiteto de TUIs 🏗️

Esta skill define os padrões para o desenvolvimento de aplicações de terminal robustas, esteticamente modernas e arquiteturalmente organizadas em Go.

## 🏛️ Princípios Arquiteturais

### 1. Composição Hierárquica (Sub-modelos)

Evite modelos gigantes. Decompunha a interface em sub-modelos independentes e reutilizáveis.

- **Exemplo**: `sidebarModel`, `listModel`, `dashboardModel`.
- Cada sub-modelo deve implementar sua própria lógica de `Init`, `Update` e `View`.

### 2. Gestão de Estado Centralizada

O modelo pai (`MainModel`) coordena o estado global e a navegação.

- Use um `sessionState` (via `iota`) para controlar qual componente está ativo ou focado.
- O pai delega mensagens (`tea.Msg`) aos filhos e coleta os comandos (`tea.Cmd`).

### 3. Roteamento de Mensagens

O método `Update` do modelo principal atua como um roteador:

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		// Atalhos globais (ex: Ctrl+C)
	case tea.WindowSizeMsg:
		// Propagar redimensionamento para todos os filhos
	}

	// Delegar para o modelo ativo
	var cmd tea.Cmd
	m.activeModel, cmd = m.activeModel.Update(msg)
	return m, cmd
}
```

### 4. Layouts Adaptativos

Sempre trate `tea.WindowSizeMsg`. Calcule dimensões usando `lipgloss` para garantir que a interface se adapte ao terminal.

## 🎨 Diretrizes de Design (Lip Gloss)

- **Estética Moderna**: Use bordas (`RoundedBorder`), padding e cores harmoniosas.
- **Alinhamento**: Use `lipgloss.Place` para centralizar elementos se necessário.
- **Layout**: Utilize `lipgloss.JoinHorizontal` e `lipgloss.JoinVertical` para construir a grade da TUI.
- **Hierarquia Visual**: Diferencie títulos e labels usando estilos de texto (Bold, Faint, Foreground colors).

## 🚀 Padrão de Geração de Código

Toda nova TUI deve seguir esta sequência:

1. **Constantes de Estado**: Definição dos tipos de visão.
2. **Estrutura do Main Model**: Incluindo instâncias dos sub-modelos.
3. **Init**: Inicialização em lote (`tea.Batch`).
4. **View Orquestrada**: Montagem do layout final unindo as `View()` dos sub-modelos.

---

_Mantenha o código limpo, tipado e focado na experiência do usuário de terminal._
