# Aurora TUI - Arquitetura do Sistema

## Visão Geral

Aurora é uma interface TUI (Text User Interface) moderna para administração de NAS, desenvolvida em Go usando o framework Bubbletea. O sistema segue uma arquitetura modular em camadas, permitindo extensibilidade através de plugins e mantendo fidelidade ao Design System AURORA v2.0.

## Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CAMADA DE APRESENTAÇÃO                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Dashboard  │  │  Pool Mgmt   │  │  Share Mgmt  │  │    Wizard    │     │
│  │    View      │  │    View      │  │    View      │  │    View      │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                 │                 │             │
│  ┌──────┴─────────────────┴─────────────────┴─────────────────┴───────┐     │
│  │                     UI Components (Bubbletea)                      │     │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │     │
│  │  │  Header  │ │   List   │ │  Table   │ │  Form    │ │ Spinner  │  │     │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │     │
│  └───────────────────────────────┬────────────────────────────────────┘     │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼──────────────────────────────────────────┐
│                           CAMADA DE NÚCLEO                                  │
│                           (internal/core)                                   │
│  ┌───────────────────────────────┴────────────────────────────────────┐     │
│  │                        Application Core                            │     │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐       │     │
│  │  │   Router   │ │   State    │ │  Command   │ │   Config   │       │     │
│  │  │  Manager   │ │   Store    │ │  Executor  │ │  Manager   │       │     │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘       │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                      Plugin Manager                                │     │
│  │     (Carrega e gerencia plugins ZFS, Samba, AD, Monitoramento)     │     │
│  └────────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼──────────────────────────────────────────┐
│                           CAMADA DE PLUGINS                                 │
│                           (internal/plugins)                                │
│  ┌─────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ │
│  │   ZFS Plugin    │ │  Samba Plugin  │ │    AD Plugin   │ │  Mon Plugin  │ │
│  │  ┌───────────┐  │ │  ┌──────────┐  │ │  ┌──────────┐  │ │ ┌──────────┐ │ │
│  │  │ Pool API  │  │ │  │ Share API│  │ │  │ Join API │  │ │ │MetricsAPI│ │ │
│  │  │DatasetAPI │  │ │  │  User API│  │ │  │  ID Map  │  │ │ │  Logs API│ │ │
│  │  │SnapshotAPI│  │ │  │  ACL API │  │ │  │ Kerberos │  │ │ │ AlertsAPI│ │ │
│  │  └───────────┘  │ │  └──────────┘  │ │  └──────────┘  │ │ └──────────┘ │ │
│  └─────────────────┘ └────────────────┘ └────────────────┘ └──────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼──────────────────────────────────────────┐
│                           CAMADA DE INFRAESTRUTURA                          │
│                                                                             │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────┐  │
│  │   zpool/zfs    │ │  smb.conf/     │ │   realmd/      │ │  /proc,      │  │
│  │    comandos    │ │   pdbedit      │ │   sssd/        │ │  /sys,       │  │
│  │                │ │                │ │   kerberos     │ │  journald    │  │
│  └────────────────┘ └────────────────┘ └────────────────┘ └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Estrutura de Diretórios

```
/home/helton/git/DEBIAN_ISO_PROJECT/aurora-tui/
├── cmd/
│   └── aurora/              # Ponto de entrada da aplicação
│       └── main.go
├── internal/
│   ├── core/                # Núcleo da aplicação
│   │   ├── app.go           # Inicialização e lifecycle
│   │   ├── router.go        # Roteamento entre telas
│   │   ├── state.go         # Gerenciamento de estado global
│   │   ├── config.go        # Configuração (SQLite)
│   │   ├── executor.go      # Executor de comandos
│   │   └── audit.go         # Sistema de auditoria
│   ├── plugins/             # Plugins de funcionalidade
│   │   ├── zfs/
│   │   │   ├── plugin.go
│   │   │   ├── pool.go
│   │   │   ├── dataset.go
│   │   │   ├── snapshot.go
│   │   │   └── wizard.go
│   │   ├── samba/
│   │   │   ├── plugin.go
│   │   │   ├── share.go
│   │   │   ├── user.go
│   │   │   └── acl.go
│   │   ├── activedir/
│   │   │   ├── plugin.go
│   │   │   ├── join.go
│   │   │   └── idmap.go
│   │   └── monitor/
│   │       ├── plugin.go
│   │       ├── metrics.go
│   │       └── logs.go
│   ├── ui/                  # Componentes de UI
│   │   ├── theme.go         # Design System AURORA
│   │   ├── components/
│   │   │   ├── header.go
│   │   │   ├── list.go
│   │   │   ├── table.go
│   │   │   ├── form.go
│   │   │   ├── modal.go
│   │   │   ├── progress.go
│   │   │   └── spinner.go
│   │   └── views/
│   │       ├── dashboard.go
│   │       ├── pools.go
│   │       ├── datasets.go
│   │       ├── shares.go
│   │       └── wizard.go
│   └── models/              # Modelos de dados
│       ├── pool.go
│       ├── dataset.go
│       ├── share.go
│       ├── user.go
│       └── audit.go
├── pkg/                     # Bibliotecas públicas
│   └── utils/
├── docs/                    # Documentação
│   ├── ARCHITECTURE.md
│   ├── API.md
│   └── THEMES.md
├── go.mod
├── go.sum
└── README.md
```

## Componentes Principais

### 1. Core Application (`internal/core`)

#### 1.1 Application Manager (`app.go`)

- Inicialização da aplicação
- Carregamento de configurações
- Registro de plugins
- Gerenciamento de lifecycle

#### 1.2 Router (`router.go`)

- Navegação entre views
- Histórico de navegação
- Parâmetros entre telas
- Atalhos de teclado globais

#### 1.3 State Store (`state.go`)

- Estado global da aplicação
- Cache de dados
- Sincronização entre componentes
- Persistência de sessão

#### 1.4 Config Manager (`config.go`)

- Persistência em SQLite
- Schema versionado
- Migrações automáticas
- Backup/restore

#### 1.5 Command Executor (`executor.go`)

- Abstração de execução de comandos shell
- Validação de permissões
- Dry-run mode
- Rollback automático

#### 1.6 Audit Logger (`audit.go`)

- Log estruturado de operações
- Níveis de severidade
- Rotação de logs
- Exportação

### 2. Plugin System (`internal/plugins`)

Interface comum para todos os plugins:

```go
type Plugin interface {
    Name() string
    Version() string
    Init(core CoreAPI) error
    RegisterRoutes(router Router)
    HealthCheck() HealthStatus
    Shutdown() error
}
```

#### 2.1 ZFS Plugin

Gerenciamento completo de ZFS:

- Listagem de pools e datasets
- Criação/destruição
- Propriedades (compressão, quotas, etc.)
- Snapshots (criar, listar, rollback, destruir)
- Replicação (send/receive)
- Wizards interativos

#### 2.2 Samba Plugin

Administração SMB/CIFS:

- Compartilhamentos
- Usuários locais
- Permissões ACL
- Integração com winbind

#### 2.3 Active Directory Plugin

Integração com AD/LDAP:

- Join/leave domain
- Descoberta de domínio
- Mapeamento de identidades
- Configuração Kerberos

#### 2.4 Monitor Plugin

Monitoramento do sistema:

- CPU, memória, disco
- ZFS ARC stats
- Status de serviços
- Logs consolidados
- Alertas

### 3. UI Components (`internal/ui`)

Implementação do Design System AURORA v2.0:

#### 3.1 Theme (`theme.go`)

```go
const (
    // Fundos
    Void      = lipgloss.Color("#262626")      // 235
    Depth     = lipgloss.Color("#3a3a3a")      // 237
    Elevation = lipgloss.Color("#4e4e4e")      // 239

    // Bordas
    Whisper   = lipgloss.Color("#585858")      // 240
    Mist      = lipgloss.Color("#767676")      // 243

    // Textos
    Fog       = lipgloss.Color("#8a8a8a")      // 245
    Haze      = lipgloss.Color("#a8a8a8")      // 248
    Cloud     = lipgloss.Color("#bcbcbc")      // 250
    Silver    = lipgloss.Color("#d0d0d0")      // 252

    // Acentos
    SlateDim  = lipgloss.Color("#5f875f")      // 66
    Slate     = lipgloss.Color("#5f87af")      // 67
    SlateGlow = lipgloss.Color("#5f87d7")      // 68
    Peak      = lipgloss.Color("#afd7ff")      // 153

    // Funcionais
    Success   = lipgloss.Color("#87af87")      // 108
    Warning   = lipgloss.Color("#d7af5f")      // 179
    Error     = lipgloss.Color("#d75f5f")      // 167
)
```

#### 3.2 Componentes Base

| Componente  | Descrição                           |
| ----------- | ----------------------------------- |
| `Header`    | Cabeçalho com navegação hierárquica |
| `List`      | Lista selecionável com navegação    |
| `Table`     | Tabela de dados com ordenação       |
| `Form`      | Formulários com validação           |
| `Modal`     | Diálogos modais                     |
| `Progress`  | Barras de progresso                 |
| `Spinner`   | Indicadores de carregamento         |
| `StatusBar` | Barra de status inferior            |

### 4. Data Models (`internal/models`)

#### 4.1 Pool

```go
type Pool struct {
    Name        string
    Health      HealthStatus
    Size        uint64
    Allocated   uint64
    Free        uint64
    Fragmentation float64
    Datasets    []Dataset
    Properties  map[string]string
}
```

#### 4.2 Dataset

```go
type Dataset struct {
    Name       string
    Pool       string
    Type       DatasetType // filesystem, volume, snapshot
    Used       uint64
    Available  uint64
    Referenced uint64
    Compression string
    Quota      uint64
    Mountpoint string
}
```

#### 4.3 Share

```go
type Share struct {
    Name        string
    Path        string
    Comment     string
    ReadOnly    bool
    Browseable  bool
    GuestOK     bool
    ValidUsers  []string
    ACLs        []ACL
}
```

#### 4.4 AuditEntry

```go
type AuditEntry struct {
    ID        int64
    Timestamp time.Time
    User      string
    Action    string
    Resource  string
    Details   string
    Status    string // success, error
}
```

## Fluxo de Dados

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Usuário    │────▶│     View     │────▶│    Update    │────▶│   Command    │
│  (Input)     │      │   (Bubbletea)│      │   (Lógica)   │      │  (Executor)  │
└──────────────┘      └──────────────┘      └──────────────┘      └──────┬───────┘
                                                                         │
                                                                         ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Render     │◀────│     View     │◀────│    Model     │◀────│   System     │
│   (Tela)     │      │   (Bubbletea)│      │   (Dados)    │      │   (ZFS/AD)   │
└──────────────┘      └──────────────┘      └──────────────┘      └──────────────┘
```

## Navegação

### Estrutura de Menus

```
┌─────────────────────────────────────────────────────────────────┐
│  AURORA NAS ADMIN                                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ▶ Dashboard                        [F1] Ajuda                 │
│  ─────────────────────────────────                              │
│  ▶ Storage (ZFS)                    [F2] Dashboard             │
│    ├── Pools                         [F3] Pools                 │
│    ├── Datasets                      [F4] Datasets              │
│    └── Snapshots                     [F5] Shares                │
│  ─────────────────────────────────                              │
│  ▶ Sharing (SMB)                    [F6] Active Directory      │
│    ├── Shares                        [F7] Logs                  │
│    ├── Users                         [F8] Settings              │
│    └── ACLs                          [F9/Tab] Menu              │
│  ─────────────────────────────────   [Q/Esc] Sair               │
│  ▶ Active Directory                                            │
│  ▶ Monitoring                                                  │
│    ├── Resources                                                │
│    ├── Services                                                 │
│    └── Logs                                                     │
│  ─────────────────────────────────                              │
│  ▶ System                                                      │
│    ├── Settings                                                 │
│    └── Audit Log                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Segurança

### 1. Validação de Comandos

- Todos os comandos passam por validação sintática
- Permissões verificadas antes da execução
- Sanitização de inputs

### 2. Operações Destrutivas

- Confirmação multi-nível para destroy/remove
- Snapshot automático antes de alterações ZFS
- Dry-run mode disponível

### 3. Auditoria

- Log de todas as operações administrativas
- Rastreabilidade completa
- Retenção configurável

## Performance

### Otimizações para SSH de Alta Latência

- Cache local de dados ZFS
- Updates incrementais
- Redução de chamadas shell
- Compressão de output
- Atualizações em batch

## Extensibilidade

### Criando um Novo Plugin

```go
package myplugin

import (
    "aurora/internal/core"
)

type MyPlugin struct {
    core core.CoreAPI
}

func (p *MyPlugin) Name() string {
    return "myplugin"
}

func (p *MyPlugin) Version() string {
    return "1.0.0"
}

func (p *MyPlugin) Init(c core.CoreAPI) error {
    p.core = c
    return nil
}

func (p *MyPlugin) RegisterRoutes(r core.Router) {
    r.Register("/myplugin", p.myView)
}

func (p *MyPlugin) HealthCheck() core.HealthStatus {
    return core.HealthStatus{Healthy: true}
}

func (p *MyPlugin) Shutdown() error {
    return nil
}
```

## Dependências

### Principais

- `github.com/charmbracelet/bubbletea` - Framework TUI
- `github.com/charmbracelet/lipgloss` - Estilização
- `github.com/charmbracelet/bubbles` - Componentes pré-fabricados
- `github.com/mattn/go-sqlite3` - Persistência

### Desenvolvimento

- `github.com/stretchr/testify` - Testes
- `github.com/golangci/golangci-lint` - Linting

## Roadmap de Implementação

### Fase 1: MVP (Core + ZFS Básico)

- [ ] Estrutura base do projeto
- [ ] Core (app, router, config, executor)
- [ ] Design System AURORA
- [ ] Dashboard básico
- [ ] ZFS Plugin (listar pools/datasets)
- [ ] Wizard de criação de pool

### Fase 2: ZFS Completo + Samba

- [ ] Snapshots e replicação
- [ ] Propriedades ZFS avançadas
- [ ] Samba Plugin (shares, usuários)
- [ ] ACLs básicas

### Fase 3: Active Directory

- [ ] AD Plugin
- [ ] Join/leave domain
- [ ] Mapeamento de identidades

### Fase 4: Monitoramento e Polish

- [ ] Monitor Plugin completo
- [ ] Sistema de logs
- [ ] Alertas
- [ ] Documentação final

---

**Versão:** 1.0.0  
**Última Atualização:** 2026-01-30  
**Autor:** Aurora TUI Team
