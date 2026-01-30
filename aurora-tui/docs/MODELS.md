# Aurora TUI - Modelos de Dados

## Visão Geral

Este documento define os modelos de dados utilizados na aplicação Aurora TUI para administração de NAS.

## Índice

1. [Pool](#pool)
2. [Dataset](#dataset)
3. [Snapshot](#snapshot)
4. [Share](#share)
5. [User](#user)
6. [ACL](#acl)
7. [Service](#service)
8. [AuditEntry](#auditentry)

---

## Pool

Representa um pool ZFS.

```go
type Pool struct {
    // Identificação
    Name        string    `json:"name" db:"name"`
    ID          string    `json:"id" db:"id"`
    
    // Status
    Health      HealthStatus `json:"health" db:"health"`
    Status      string       `json:"status" db:"status"`
    
    // Capacidade
    Size        uint64  `json:"size" db:"size"`
    Allocated   uint64  `json:"allocated" db:"allocated"`
    Free        uint64  `json:"free" db:"free"`
    Available   uint64  `json:"available" db:"available"`
    
    // Estatísticas
    Fragmentation float64 `json:"fragmentation" db:"fragmentation"`
    DedupRatio    float64 `json:"dedup_ratio" db:"dedup_ratio"`
    
    // Configuração
    AltRoot     string            `json:"altroot,omitempty" db:"altroot"`
    ReadOnly    bool              `json:"readonly" db:"readonly"`
    AutoExpand  bool              `json:"autoexpand" db:"autoexpand"`
    Properties  map[string]string `json:"properties,omitempty" db:"-"`
    
    // Relacionamentos
    VDevs       []VDev    `json:"vdevs,omitempty" db:"-"`
    Datasets    []Dataset `json:"datasets,omitempty" db:"-"`
    
    // Metadados
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    ScannedAt   time.Time `json:"scanned_at" db:"scanned_at"`
}

type HealthStatus string

const (
    HealthOnline   HealthStatus = "ONLINE"
    HealthDegraded HealthStatus = "DEGRADED"
    HealthFaulted  HealthStatus = "FAULTED"
    HealthOffline  HealthStatus = "OFFLINE"
    HealthUnavail  HealthStatus = "UNAVAIL"
    HealthRemoved  HealthStatus = "REMOVED"
)

type VDev struct {
    Name      string       `json:"name"`
    Type      string       `json:"type"`  // mirror, raidz1, raidz2, raidz3, disk
    Health    HealthStatus `json:"health"`
    Size      uint64       `json:"size"`
    Allocated uint64       `json:"allocated"`
    Free      uint64       `json:"free"`
    Disks     []Disk       `json:"disks"`
}

type Disk struct {
    Name     string       `json:"name"`
    Device   string       `json:"device"`
    Health   HealthStatus `json:"health"`
    Size     uint64       `json:"size"`
    Model    string       `json:"model,omitempty"`
    Serial   string       `json:"serial,omitempty"`
    ReadErrs uint64       `json:"read_errors"`
    WriteErrs uint64      `json:"write_errors"`
    CkSumErrs uint64      `json:"cksum_errors"`
}
```

---

## Dataset

Representa um dataset ZFS (filesystem, volume ou snapshot).

```go
type DatasetType string

const (
    DatasetFilesystem DatasetType = "filesystem"
    DatasetVolume     DatasetType = "volume"
    DatasetSnapshot   DatasetType = "snapshot"
    DatasetBookmark   DatasetType = "bookmark"
)

type Dataset struct {
    // Identificação
    Name      string      `json:"name" db:"name"`
    Pool      string      `json:"pool" db:"pool"`
    Type      DatasetType `json:"type" db:"type"`
    
    // Hierarquia
    Parent    string      `json:"parent,omitempty" db:"parent"`
    Children  []string    `json:"children,omitempty" db:"-"`
    
    // Uso
    Used       uint64 `json:"used" db:"used"`
    Available  uint64 `json:"available" db:"available"`
    Referenced uint64 `json:"referenced" db:"referenced"`
    CompressRatio float64 `json:"compress_ratio" db:"compress_ratio"`
    
    // Propriedades
    Mountpoint  string `json:"mountpoint" db:"mountpoint"`
    Compression string `json:"compression" db:"compression"`
    Quota       uint64 `json:"quota" db:"quota"`
    RefQuota    uint64 `json:"ref_quota" db:"ref_quota"`
    Reservation uint64 `json:"reservation" db:"reservation"`
    RefReservation uint64 `json:"ref_reservation" db:"ref_reservation"`
    
    // Atributos
    ReadOnly    bool   `json:"readonly" db:"readonly"`
    Exec        bool   `json:"exec" db:"exec"`
    SetUID      bool   `json:"setuid" db:"setuid"`
    Devices     bool   `json:"devices" db:"devices"`
    ATime       bool   `json:"atime" db:"atime"`
    
    // ACL
    ACLType     string `json:"acl_type" db:"acl_type"`
    ACLInherit  bool   `json:"acl_inherit" db:"acl_inherit"`
    
    // Relacionamentos
    Snapshots   []Snapshot `json:"snapshots,omitempty" db:"-"`
    
    // Metadados
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
}
```

---

## Snapshot

Representa um snapshot ZFS.

```go
type Snapshot struct {
    // Identificação
    Name        string `json:"name" db:"name"`
    Dataset     string `json:"dataset" db:"dataset"`
    Pool        string `json:"pool" db:"pool"`
    
    // Nome completo: pool/dataset@name
    FullName    string `json:"full_name" db:"full_name"`
    
    // Uso
    Used        uint64  `json:"used" db:"used"`
    Referenced  uint64  `json:"referenced" db:"referenced"`
    CompressRatio float64 `json:"compress_ratio" db:"compress_ratio"`
    
    // Reclones (se usado para clone)
    Clones      []string `json:"clones,omitempty" db:"-"`
    
    // Metadados
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    
    // Tags para organização
    Tags        []string `json:"tags,omitempty" db:"-"`
    Description string   `json:"description,omitempty" db:"description"`
    
    // Retenção
    Retention   time.Duration `json:"retention,omitempty" db:"retention"`
    ExpiresAt   *time.Time    `json:"expires_at,omitempty" db:"expires_at"`
}

// SnapshotConfig para políticas automáticas
type SnapshotConfig struct {
    Dataset     string        `json:"dataset" db:"dataset"`
    Prefix      string        `json:"prefix" db:"prefix"`
    Frequency   time.Duration `json:"frequency" db:"frequency"`
    Retention   int           `json:"retention" db:"retention"`  // Quantidade a manter
    Recursive   bool          `json:"recursive" db:"recursive"`
    Enabled     bool          `json:"enabled" db:"enabled"`
    LastRun     *time.Time    `json:"last_run,omitempty" db:"last_run"`
    NextRun     *time.Time    `json:"next_run,omitempty" db:"next_run"`
}
```

---

## Share

Representa um compartilhamento SMB/CIFS.

```go
type Share struct {
    // Identificação
    Name        string `json:"name" db:"name"`
    ID          string `json:"id" db:"id"`
    
    // Caminho
    Path        string `json:"path" db:"path"`
    Dataset     string `json:"dataset,omitempty" db:"dataset"`
    
    // Configuração básica
    Comment     string `json:"comment,omitempty" db:"comment"`
    Browseable  bool   `json:"browseable" db:"browseable"`
    ReadOnly    bool   `json:"readonly" db:"readonly"`
    GuestOK     bool   `json:"guest_ok" db:"guest_ok"`
    GuestOnly   bool   `json:"guest_only" db:"guest_only"`
    
    // Visibilidade
    Hidden      bool   `json:"hidden" db:"hidden"`
    
    // Acesso
    ValidUsers  []string `json:"valid_users,omitempty" db:"-"`
    InvalidUsers []string `json:"invalid_users,omitempty" db:"-"`
    ReadList    []string `json:"read_list,omitempty" db:"-"`
    WriteList   []string `json:"write_list,omitempty" db:"-"`
    AdminUsers  []string `json:"admin_users,omitempty" db:"-"`
    
    // ACLs
    ACLs        []ACL `json:"acls,omitempty" db:"-"`
    
    // Permissões avançadas
    InheritPermissions bool `json:"inherit_permissions" db:"inherit_permissions"`
    InheritACLs        bool `json:"inherit_acls" db:"inherit_acls"`
    
    // Performance
    StrictSync  bool   `json:"strict_sync" db:"strict_sync"`
    AIOReadSize uint64 `json:"aio_read_size" db:"aio_read_size"`
    AIOWriteSize uint64 `json:"aio_write_size" db:"aio_write_size"`
    
    // Status
    Enabled     bool   `json:"enabled" db:"enabled"`
    Online      bool   `json:"online" db:"online"`
    
    // Estatísticas
    Connections int    `json:"connections" db:"connections"`
    
    // Metadados
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}
```

---

## User

Representa um usuário do sistema ou do domínio.

```go
type UserType string

const (
    UserLocal UserType = "local"
    UserAD    UserType = "activedirectory"
    UserLDAP  UserType = "ldap"
    UserSystem UserType = "system"
)

type User struct {
    // Identificação
    Username    string   `json:"username" db:"username"`
    UID         int      `json:"uid" db:"uid"`
    Type        UserType `json:"type" db:"type"`
    
    // Identidade
    FullName    string   `json:"full_name,omitempty" db:"full_name"`
    Email       string   `json:"email,omitempty" db:"email"`
    
    // Local
    HomeDir     string   `json:"home_dir" db:"home_dir"`
    Shell       string   `json:"shell" db:"shell"`
    
    // Grupos
    PrimaryGroup string   `json:"primary_group" db:"primary_group"`
    GID         int      `json:"gid" db:"gid"`
    Groups      []string `json:"groups,omitempty" db:"-"`
    
    // Domínio (para AD/LDAP)
    Domain      string   `json:"domain,omitempty" db:"domain"`
    SID         string   `json:"sid,omitempty" db:"sid"`
    
    // Status
    Locked      bool     `json:"locked" db:"locked"`
    PasswordExpired bool `json:"password_expired" db:"password_expired"`
    Disabled    bool     `json:"disabled" db:"disabled"`
    
    // SMB específico
    SMBPassword string   `json:"-" db:"smb_password"`  // Nunca expor
    SMBEnabled  bool     `json:"smb_enabled" db:"smb_enabled"`
    
    // Metadados
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
    LastLogin   *time.Time `json:"last_login,omitempty" db:"last_login"`
}
```

---

## ACL

Representa uma entrada de Access Control List.

```go
type ACLEntryType string

const (
    ACLUser       ACLEntryType = "user"
    ACLGroup      ACLEntryType = "group"
    ACLOwner      ACLEntryType = "owner"
    ACLGroupOwner ACLEntryType = "groupowner"
    ACLEveryone   ACLEntryType = "everyone"
)

type ACLPermission string

const (
    ACLNone  ACLPermission = "none"
    ACLRead  ACLPermission = "read"
    ACLWrite ACLPermission = "write"
    ACLFull  ACLPermission = "full_control"
)

type ACL struct {
    // Identificação
    ID          string       `json:"id" db:"id"`
    Resource    string       `json:"resource" db:"resource"`  // caminho
    
    // Entidade
    Type        ACLEntryType `json:"type" db:"type"`
    Name        string       `json:"name" db:"name"`  // username ou groupname
    SID         string       `json:"sid,omitempty" db:"sid"`
    
    // Permissões (Windows-style)
    Permissions ACLPermission `json:"permissions" db:"permissions"`
    
    // Permissões detalhadas
    ReadData        bool `json:"read_data" db:"read_data"`
    WriteData       bool `json:"write_data" db:"write_data"`
    AppendData      bool `json:"append_data" db:"append_data"`
    ReadExtended    bool `json:"read_extended" db:"read_extended"`
    WriteExtended   bool `json:"write_extended" db:"write_extended"`
    Execute         bool `json:"execute" db:"execute"`
    ReadAttributes  bool `json:"read_attributes" db:"read_attributes"`
    WriteAttributes bool `json:"write_attributes" db:"write_attributes"`
    Delete          bool `json:"delete" db:"delete"`
    ReadPermissions bool `json:"read_permissions" db:"read_permissions"`
    ChangePermissions bool `json:"change_permissions" db:"change_permissions"`
    TakeOwnership   bool `json:"take_ownership" db:"take_ownership"`
    
    // Herança
    Inherit         bool `json:"inherit" db:"inherit"`
    InheritOnly     bool `json:"inherit_only" db:"inherit_only"`
    NoPropagate     bool `json:"no_propagate" db:"no_propagate"`
    
    // Flags
    Inherited       bool `json:"inherited" db:"inherited"`
    Default         bool `json:"default" db:"default"`  // ACL default para novos arquivos
}
```

---

## Service

Representa o status de um serviço do sistema.

```go
type ServiceStatus string

const (
    ServiceRunning    ServiceStatus = "running"
    ServiceStopped    ServiceStatus = "stopped"
    ServiceStarting   ServiceStatus = "starting"
    ServiceStopping   ServiceStatus = "stopping"
    ServiceError      ServiceStatus = "error"
    ServiceDisabled   ServiceStatus = "disabled"
    ServiceNotInstalled ServiceStatus = "not_installed"
)

type Service struct {
    // Identificação
    Name        string        `json:"name" db:"name"`
    DisplayName string        `json:"display_name" db:"display_name"`
    Description string        `json:"description" db:"description"`
    
    // Status
    Status      ServiceStatus `json:"status" db:"status"`
    Enabled     bool          `json:"enabled" db:"enabled"`
    
    // Configuração
    AutoStart   bool          `json:"auto_start" db:"auto_start"`
    
    // Processo
    PID         int           `json:"pid" db:"pid"`
    Uptime      time.Duration `json:"uptime" db:"uptime"`
    
    // Recursos
    MemoryUsage uint64        `json:"memory_usage" db:"memory_usage"`
    CPUUsage    float64       `json:"cpu_usage" db:"cpu_usage"`
    
    // Último erro
    LastError   string        `json:"last_error,omitempty" db:"last_error"`
    LastErrorAt *time.Time    `json:"last_error_at,omitempty" db:"last_error_at"`
    
    // Dependências
    DependsOn   []string      `json:"depends_on,omitempty" db:"-"`
    
    // Metadados
    UpdatedAt   time.Time     `json:"updated_at" db:"updated_at"`
}
```

---

## AuditEntry

Representa uma entrada de log de auditoria.

```go
type AuditAction string

const (
    ActionCreate  AuditAction = "create"
    ActionRead    AuditAction = "read"
    ActionUpdate  AuditAction = "update"
    ActionDelete  AuditAction = "delete"
    ActionExecute AuditAction = "execute"
    ActionLogin   AuditAction = "login"
    ActionLogout  AuditAction = "logout"
    ActionConfig  AuditAction = "config"
)

type AuditResource string

const (
    ResourcePool     AuditResource = "pool"
    ResourceDataset  AuditResource = "dataset"
    ResourceSnapshot AuditResource = "snapshot"
    ResourceShare    AuditResource = "share"
    ResourceUser     AuditResource = "user"
    ResourceGroup    AuditResource = "group"
    ResourceACL      AuditResource = "acl"
    ResourceService  AuditResource = "service"
    ResourceSystem   AuditResource = "system"
    ResourceConfig   AuditResource = "config"
)

type AuditStatus string

const (
    AuditSuccess AuditStatus = "success"
    AuditFailure AuditStatus = "failure"
    AuditDenied  AuditStatus = "denied"
)

type AuditEntry struct {
    // Identificação
    ID        int64     `json:"id" db:"id"`
    Timestamp time.Time `json:"timestamp" db:"timestamp"`
    
    // Ator
    User      string    `json:"user" db:"user"`
    UserType  UserType  `json:"user_type" db:"user_type"`
    IPAddress string    `json:"ip_address" db:"ip_address"`
    SessionID string    `json:"session_id" db:"session_id"`
    
    // Ação
    Action    AuditAction   `json:"action" db:"action"`
    Resource  AuditResource `json:"resource" db:"resource"`
    ResourceID string       `json:"resource_id" db:"resource_id"`
    
    // Detalhes
    Details   string        `json:"details" db:"details"`
    OldValue  string        `json:"old_value,omitempty" db:"old_value"`
    NewValue  string        `json:"new_value,omitempty" db:"new_value"`
    
    // Status
    Status    AuditStatus   `json:"status" db:"status"`
    Error     string        `json:"error,omitempty" db:"error"`
    
    // Metadados
    Duration  time.Duration `json:"duration" db:"duration"`
}
```

---

## DomainInfo

Informações sobre integração com Active Directory/LDAP.

```go
type DomainInfo struct {
    // Configuração
    Realm           string `json:"realm" db:"realm"`
    Workgroup       string `json:"workgroup" db:"workgroup"`
    DomainControllers []string `json:"domain_controllers,omitempty" db:"-"`
    
    // Status
    Joined          bool   `json:"joined" db:"joined"`
    JoinedAt        *time.Time `json:"joined_at,omitempty" db:"joined_at"`
    
    // Conectividade
    Connected       bool   `json:"connected" db:"connected"`
    LastSync        *time.Time `json:"last_sync,omitempty" db:"last_sync"`
    
    // DNS
    DNSDomain       string `json:"dns_domain,omitempty" db:"dns_domain"`
    DNSServers      []string `json:"dns_servers,omitempty" db:"-"`
    
    // Kerberos
    KDCServer       string `json:"kdc_server,omitempty" db:"kdc_server"`
    KeytabPresent   bool   `json:"keytab_present" db:"keytab_present"`
    
    // Erros
    LastError       string `json:"last_error,omitempty" db:"last_error"`
    LastErrorAt     *time.Time `json:"last_error_at,omitempty" db:"last_error_at"`
}
```

---

## SystemMetrics

Métricas de recursos do sistema.

```go
type SystemMetrics struct {
    Timestamp time.Time `json:"timestamp" db:"timestamp"`
    
    // CPU
    CPU struct {
        UsagePercent    float64   `json:"usage_percent"`
        UserPercent     float64   `json:"user_percent"`
        SystemPercent   float64   `json:"system_percent"`
        IOWaitPercent   float64   `json: