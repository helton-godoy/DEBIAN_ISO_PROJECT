# Aurora TUI - API de Plugins

## Visão Geral

A Aurora TUI utiliza um sistema de plugins extensível que permite adicionar funcionalidades de forma modular. Este documento define a interface `Plugin` e as APIs disponíveis para desenvolvimento de plugins.

## Interface Plugin

```go
package core

// Plugin é a interface que todos os plugins devem implementar
type Plugin interface {
    // Metadados
    Name() string
    Version() string
    Description() string
    
    // Lifecycle
    Init(core CoreAPI) error
    Shutdown() error
    
    // Registro
    RegisterRoutes(router Router)
    RegisterMenu(menu Menu)
    
    // Status
    HealthCheck() HealthStatus
    
    // Capabilities
    Capabilities() []Capability
}

// HealthStatus representa o estado de saúde de um plugin
type HealthStatus struct {
    Healthy bool
    Message string
    Details map[string]interface{}
}

// Capability representa uma funcionalidade oferecida pelo plugin
type Capability string

const (
    CapStorage     Capability = "storage"
    CapSharing     Capability = "sharing"
    CapAuth        Capability = "auth"
    CapMonitoring  Capability = "monitoring"
    CapNetwork     Capability = "network"
    CapSystem      Capability = "system"
)
```

## Core API

A `CoreAPI` é a interface principal que o core disponibiliza para os plugins.

```go
package core

type CoreAPI interface {
    // Configuração
    Config() ConfigManager
    
    // Logging
    Logger() Logger
    Audit() AuditLogger
    
    // Comandos
    Executor() CommandExecutor
    
    // Estado
    State() StateStore
    
    // UI
    UIManager() UIManager
    
    // Eventos
    EventBus() EventBus
    
    // Plugins
    PluginManager() PluginManager
}
```

### ConfigManager

```go
type ConfigManager interface {
    // Leitura
    Get(key string) (string, error)
    GetInt(key string) (int, error)
    GetBool(key string) (bool, error)
    GetObject(key string, target interface{}) error
    
    // Escrita
    Set(key string, value interface{}) error
    SetObject(key string, value interface{}) error
    
    // Escopo de plugin
    PluginConfig(pluginName string) PluginConfig
    
    // Persistência
    Save() error
    Load() error
}

type PluginConfig interface {
    Get(key string) (string, error)
    GetObject(key string, target interface{}) error
    Set(key string, value interface{}) error
    SetObject(key string, value interface{}) error
    All() map[string]interface{}
}
```

### Logger

```go
type Logger interface {
    Debug(msg string, fields ...Field)
    Info(msg string, fields ...Field)
    Warn(msg string, fields ...Field)
    Error(msg string, fields ...Field)
    Fatal(msg string, fields ...Field)
    
    WithFields(fields ...Field) Logger
    WithError(err error) Logger
}

type Field struct {
    Key   string
    Value interface{}
}
```

### AuditLogger

```go
type AuditLogger interface {
    Log(entry AuditEntry) error
    Query(filter AuditFilter) ([]AuditEntry, error)
    Export(format string, w io.Writer) error
}

type AuditFilter struct {
    StartTime   *time.Time
    EndTime     *time.Time
    User        string
    Action      AuditAction
    Resource    AuditResource
    Status      AuditStatus
    Limit       int
    Offset      int
}
```

### CommandExecutor

```go
type CommandExecutor interface {
    // Execução básica
    Execute(ctx context.Context, cmd Command) (Result, error)
    ExecuteShell(ctx context.Context, script string) (Result, error)
    
    // Com validação
    ExecuteValidated(ctx context.Context, cmd Command, validator Validator) (Result, error)
    
    // Batch
    ExecuteBatch(ctx context.Context, commands []Command) ([]Result, error)
    
    // Dry-run
    DryRun(cmd Command) (string, error)
}

type Command struct {
    Name        string
    Args        []string
    WorkingDir  string
    Env         map[string]string
    Stdin       io.Reader
    Timeout     time.Duration
    Sensitive   bool  // Se true, não loga args
    
    // Para rollback
    Rollback    *Command
}

type Result struct {
    ExitCode int
    Stdout   string
    Stderr   string
    Duration time.Duration
}

type Validator interface {
    Validate(cmd Command) error
    ValidateResult(result Result) error
}
```

### StateStore

```go
type StateStore interface {
    // Global
    Get(key string) (interface{}, bool)
    Set(key string, value interface{})
    Delete(key string)
    
    // Scoped por plugin
    PluginScope(pluginName string) StateScope
    
    // Eventos
    Subscribe(key string, handler Handler) Subscription
    
    // Persistência (sessão)
    Persist() error
    Restore() error
}

type StateScope interface {
    Get(key string) (interface{}, bool)
    Set(key string, value interface{})
    Delete(key string)
    All() map[string]interface{}
}
```

### UIManager

```go
type UIManager interface {
    // Notificações
    ShowNotification(msg Notification) error
    HideNotification(id string) error
    
    // Modais
    ShowModal(modal Modal) (ModalResult, error)
    HideModal(id string) error
    
    // Progresso
    ShowProgress(id string, title string) error
    UpdateProgress(id string, percent int, message string) error
    HideProgress(id string) error
    
    // Confirmação
    Confirm(options ConfirmOptions) (bool, error)
    
    // Input
    Input(options InputOptions) (string, error)
    Select(options SelectOptions) (int, error)
}

type Notification struct {
    ID      string
    Type    NotificationType
    Title   string
    Message string
    Timeout time.Duration
}

type NotificationType string

const (
    InfoNotification    NotificationType = "info"
    SuccessNotification NotificationType = "success"
    WarningNotification NotificationType = "warning"
    ErrorNotification   NotificationType = "error"
)

type ConfirmOptions struct {
    Title       string
    Message     string
    Affirmative string
    Negative    string
    Dangerous   bool
}

type InputOptions struct {
    Title       string
    Placeholder string
    Value       string
    Password    bool
    Validate    func(string) error
}

type SelectOptions struct {
    Title   string
    Options []string
    Default int
}
```

### EventBus

```go
type EventBus interface {
    Publish(event Event) error
    Subscribe(eventType string, handler EventHandler) Subscription
    SubscribePattern(pattern string, handler EventHandler) Subscription
    Unsubscribe(sub Subscription)
}

type Event struct {
    Type      string
    Source    string
    Timestamp time.Time
    Payload   interface{}
}

type EventHandler func(event Event) error
type Subscription interface {
    Unsubscribe()
}
```

## Router

```go
type Router interface {
    // Registro de rotas
    Register(path string, view View) Route
    RegisterWithParams(path string, view ViewWithParams) Route
    
    // Navegação
    Navigate(path string) error
    NavigateWithParams(path string, params map[string]interface{}) error
    Back() error
    
    // Estado atual
    CurrentRoute() RouteInfo
    RouteHistory() []RouteInfo
    
    // Middleware
    Use(middleware Middleware)
}

type Route interface {
    Name(name string) Route
    Title(title string) Route
    Icon(icon string) Route
    RequireAuth() Route
    RequirePermission(permission string) Route
}

type View interface {
    tea.Model
    Title() string
}

type ViewWithParams interface {
    tea.Model
    Title() string
    SetParams(params map[string]interface{})
}

type RouteInfo struct {
    Path   string
    Title  string
    Params map[string]interface{}
}

type Middleware func(next tea.Model) tea.Model
```

## Menu System

```go
type Menu interface {
    // Seções
    AddSection(id string, label string, icon string) MenuSection
    
    // Items
    AddItem(item MenuItem)
    
    // Ordenação
    Order(ids []string)
}

type MenuSection interface {
    ID() string
    Label() string
    
    // Items
    AddItem(item MenuItem) MenuSection
    
    // Ordenação
    Order(ids []string)
}

type MenuItem struct {
    ID          string
    Label       string
    Icon        string
    Route       string
    Shortcut    string
    Description string
    Disabled    bool
    Badge       string
}
```

## Implementação de Exemplo

### Plugin ZFS

```go
package zfs

import (
    "aurora/internal/core"
    "aurora/internal/ui"
)

type ZFSPlugin struct {
    core core.CoreAPI
    log  core.Logger
}

func New() *ZFSPlugin {
    return &ZFSPlugin{}
}

func (p *ZFSPlugin) Name() string {
    return "zfs"
}

func (p *ZFSPlugin) Version() string {
    return "1.0.0"
}

func (p *ZFSPlugin) Description() string {
    return "Gerenciamento ZFS - Pools, datasets e snapshots"
}

func (p *ZFSPlugin) Init(c core.CoreAPI) error {
    p.core = c
    p.log = c.Logger().WithFields(core.Field{Key: "plugin", Value: "zfs"})
    
    // Verifica se ZFS está disponível
    if _, err := p.core.Executor().Execute(context.Background(), core.Command{
        Name: "zpool",
        Args: []string{"list"},
    }); err != nil {
        return fmt.Errorf("zfs não disponível: %w", err)
    }
    
    p.log.Info("Plugin ZFS inicializado")
    return nil
}

func (p *ZFSPlugin) Shutdown() error {
    p.log.Info("Plugin ZFS finalizado")
    return nil
}

func (p *ZFSPlugin) RegisterRoutes(r core.Router) {
    // Dashboard
    r.Register("/storage", p.dashboardView()).
        Name("storage").
        Title("Storage")
    
    // Pools
    r.Register("/storage/pools", p.poolsView()).
        Name("pools").
        Title("Pools ZFS")
    
    r.RegisterWithParams("/storage/pools/:name", p.poolDetailView()).
        Name("pool-detail").
        Title("Detalhes do Pool")
    
    // Datasets
    r.Register("/storage/datasets", p.datasetsView()).
        Name("datasets").
        Title("Datasets")
    
    // Snapshots
    r.Register("/storage/snapshots", p.snapshotsView()).
        Name("snapshots").
        Title("Snapshots")
    
    // Wizards
    r.Register("/storage/wizards/create-pool", p.createPoolWizard()).
        Name("create-pool").
        Title("Novo Pool")
}

func (p *ZFSPlugin) RegisterMenu(m core.Menu) {
    section := m.AddSection("storage", "Storage", "💾")
    
    section.AddItem(core.MenuItem{
        ID:          "pools",
        Label:       "Pools ZFS",
        Route:       "/storage/pools",
        Shortcut:    "F3",
        Description: "Gerenciar pools de armazenamento",
    })
    
    section.AddItem(core.MenuItem{
        ID:          "datasets",
        Label:       "Datasets",
        Route:       "/storage/datasets",
        Shortcut:    "",
        Description: "Gerenciar datasets ZFS",
    })
    
    section.AddItem(core.MenuItem{
        ID:          "snapshots",
        Label:       "Snapshots",
        Route:       "/storage/snapshots",
        Shortcut:    "",
        Description: "Gerenciar snapshots",
        Badge:       "Auto",
    })
}

func (p *ZFSPlugin) HealthCheck() core.HealthStatus {
    _, err := p.core.Executor().Execute(context.Background(), core.Command{
        Name: "zpool",
        Args: []string{"list"},
    })
    
    if err != nil {
        return core.HealthStatus{
            Healthy: false,
            Message: "ZFS não responde",
        }
    }
    
    return core.HealthStatus{
        Healthy: true,
        Message: "ZFS operacional",
    }
}

func (p *ZFSPlugin) Capabilities() []core.Capability {
    return []core.Capability{
        core.CapStorage,
    }
}

// Views implementation...
func (p *ZFSPlugin) dashboardView() core.View {
    return NewDashboardView(p.core)
}

func (p *ZFSPlugin) poolsView() core.View {
    return NewPoolsView(p.core)
}

func (p *ZFSPlugin) poolDetailView() core.ViewWithParams {
    return NewPoolDetailView(p.core)
}

func (p *ZFSPlugin) datasetsView() core.View {
    return NewDatasetsView(p.core)
}

func (p *ZFSPlugin) snapshotsView() core.View {
    return NewSnapshotsView(p.core)
}

func (p *ZFSPlugin) createPoolWizard() core.View {
    return NewCreatePoolWizard(p.core)
}
```

## Eventos do Sistema

```go
// Eventos padrão emitidos pelo core
const (
    // Sistema
    EventSystemStarted    = "system:started"
    EventSystemShutdown   = "system:shutdown"
    EventConfigChanged    = "config:changed"
    
    // Navegação
    EventRouteChanged     = "route:changed"
    EventModalOpened      = "modal:opened"
    EventModalClosed      = "modal:closed"
    
    // Plugins
    EventPluginLoaded     = "plugin:loaded"
    EventPluginUnloaded   = "plugin:unloaded"
    
    // Storage
    EventPoolCreated      = "zfs:pool:created"
    EventPoolDestroyed    = "zfs:pool:destroyed"
    EventDatasetCreated   = "zfs:dataset:created"
    EventSnapshotCreated  = "zfs:snapshot:created"
    
    // Sharing
    EventShareCreated     = "smb:share:created"
    EventShareModified    = "smb:share:modified"
    
    // Auth
    EventUserLogin        = "auth:login"
    EventUserLogout       = "auth:logout"
    EventDomainJoined     = "ad:joined"
    EventDomainLeft       = "ad:left"
)
```

## Boas Práticas

1. **Isolamento**: Plugins não devem depender de outros plugins diretamente
2. **Eventos**: Use o EventBus para comunicação entre plugins
3. **Erros**: Sempre retorne erros descritivos e logue operações importantes
4. **Recursos**: Libere recursos no método `Shutdown()`
5. **Validação**: Valide todas as entradas antes de executar comandos
6. **Auditoria**: Logue operações administrativas via `Audit()`
7. **Configuração**: Use `PluginConfig()` para configurações específicas
8. **Estado**: Prefira o `StateStore` a variáveis globais

## Registro de Plugin

Para registrar um plugin, adicione-o no arquivo de configuração ou registro dinâmico:

```go
// No arquivo main.go ou ponto de inicialização
func main() {
    app := core.NewApp()
    
    // Registra plugins
    app.RegisterPlugin(zfs.New())
    app.RegisterPlugin(samba.New())
    app.RegisterPlugin(activedir.New())
    app.RegisterPlugin(monitor.New())
    
    // Inicia aplicação
    if err := app.Run(); err != nil {
        log.Fatal(err)
    }
}
```

---

**Versão:** 1.0.0  
**Atualizado:** 2026-01-30
