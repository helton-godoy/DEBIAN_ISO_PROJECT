# Aurora TUI - Painel de Administração NAS

[![Go Version](https://img.shields.io/badge/go-1.21+-blue.svg)](https://golang.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Build](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

Interface TUI (Text User Interface) moderna para administração de NAS, projetada para substituir interfaces web tradicionais com foco em eficiência via SSH.

## ✨ Características

- 🎨 **Design System AURORA v2.0** - Paleta monocromática slate sofisticada
- 🧩 **Arquitetura Modular** - Sistema de plugins extensível
- 🚀 **Performance** - Otimizado para conexões SSH de alta latência
- 📊 **Dashboard em Tempo Real** - Monitoramento de recursos integrado
- 🔒 **Segurança** - Auditoria completa, RBAC, confirmações para operações destrutivas
- 🧙 **Wizards Interativos** - Assistentes para configurações complexas
- 🌐 **Integração AD/LDAP** - Autenticação centralizada

## 📸 Screenshots

```
╔════════════════════════════════════════════════════════════════╗
║           AURORA NAS ADMIN - v1.0.0                           ║
║       High Performance Storage Management                     ║
╚════════════════════════════════════════════════════════════════╝

  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
  │     CPU      │ │   Memória    │ │   ZFS ARC    │
  │  ████████░░  │ │  ██████░░░░  │ │  ████░░░░░░  │
  │     82%      │ │     56%      │ │     32%      │
  └──────────────┘ └──────────────┘ └──────────────┘

  ┌────────────────────────────────────────────────────────┐
  │  Pools ZFS                                              │
  │  ────────────────────────────────────────────────────   │
  │  ● tank      [████████████████████] 78%  7.8TB/10TB    │
  │  ● backup    [████░░░░░░░░░░░░░░░░] 12%  1.2TB/10TB    │
  │  ● archive   [████████░░░░░░░░░░░░] 45%  4.5TB/10TB    │
  └────────────────────────────────────────────────────────┘

  [F1 Ajuda]  [F2 Dashboard]  [F3 Pools]  [F4 Shares]  [Q Sair]
```

## 🚀 Instalação

### Requisitos

- Go 1.21 ou superior
- SQLite3
- ZFS (para funcionalidades de storage)
- Samba (para funcionalidades de compartilhamento)

### Compilação

```bash
# Clone o repositório
cd /home/helton/git/DEBIAN_ISO_PROJECT/aurora-tui

# Instale dependências
go mod download

# Compile
go build -o aurora ./cmd/aurora

# Instale (opcional)
sudo cp aurora /usr/local/bin/
```

### Instalação via Pacote

```bash
# Debian/Ubuntu
sudo dpkg -i aurora-nas_1.0.0_amd64.deb

# Ou via repositório
sudo apt install aurora-nas
```

## 🎯 Uso

### Iniciar aplicação

```bash
# Interface TUI
aurora

# Modo simulação (para desenvolvimento)
aurora --mock

# Debug
aurora --debug

# Configuração customizada
aurora --config /etc/aurora/config.yaml
```

### Atalhos de Teclado

| Tecla | Ação |
|-------|------|
| `F1` | Ajuda contextual |
| `F2` | Dashboard |
| `F3` | Pools ZFS |
| `F4` | Compartilhamentos |
| `F5` | Snapshots |
| `Tab` | Próximo campo/item |
| `↑/↓` | Navegar |
| `Enter` | Selecionar/Confirmar |
| `Esc` | Cancelar/Voltar |
| `q` | Sair |

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     CAMADA DE UI                            │
│         (Bubbletea + Lipgloss + Bubbles)                    │
├─────────────────────────────────────────────────────────────┤
│                     CAMADA CORE                             │
│    (Router, State, Config, Executor, Audit, EventBus)       │
├─────────────────────────────────────────────────────────────┤
│                    PLUGIN SYSTEM                            │
├─────────────────────────────────────────────────────────────┤
│  ZFS Plugin  │  Samba Plugin  │  AD Plugin  │  Monitor     │
├─────────────────────────────────────────────────────────────┤
│                    INFRAESTRUTURA                           │
│       (zpool/zfs, smbd, realmd/sssd, /proc, journal)       │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Estrutura do Projeto

```
/home/helton/git/DEBIAN_ISO_PROJECT/aurora-tui/
├── cmd/aurora/              # Ponto de entrada
├── internal/
│   ├── core/                # Núcleo da aplicação
│   ├── plugins/             # Plugins
│   │   ├── zfs/             # Gerenciamento ZFS
│   │   ├── samba/           # Compartilhamentos SMB
│   │   ├── activedir/       # Active Directory
│   │   └── monitor/         # Monitoramento
│   ├── ui/                  # Componentes de UI
│   └── models/              # Modelos de dados
├── docs/                    # Documentação
└── README.md
```

## 🔧 Configuração

### Arquivo de Configuração

```yaml
# /etc/aurora/config.yaml
server:
  host: 0.0.0.0
  port: 8080
  
storage:
  database: /var/lib/aurora/aurora.db
  audit_log: /var/log/aurora/audit.log
  
plugins:
  zfs:
    enabled: true
    properties:
      compression: lz4
      atime: off
      xattr: sa
  
  samba:
    enabled: true
    config_path: /etc/samba/smb.conf
  
  activedir:
    enabled: false
    
ui:
  theme: aurora
  refresh_interval: 5s
```

## 🧪 Desenvolvimento

### Estrutura de Plugins

Para criar um novo plugin, implemente a interface `Plugin`:

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

Veja [docs/API.md](docs/API.md) para documentação completa da API.

### Executando Testes

```bash
# Todos os testes
go test ./...

# Com coverage
go test -cover ./...

# Testes específicos
go test ./internal/plugins/zfs/...
```

## 📝 Documentação

- [Arquitetura](docs/ARCHITECTURE.md) - Visão geral da arquitetura
- [API de Plugins](docs/API.md) - Desenvolvimento de plugins
- [Design System](docs/THEME.md) - Guia de UI/UX
- [Modelos de Dados](docs/MODELS.md) - Estruturas de dados

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja [LICENSE](LICENSE) para detalhes.

## 🙏 Agradecimentos

- [Charm](https://charm.sh/) pelas bibliotecas Bubbletea, Lipgloss e Bubbles
- Design System baseado no AURORA v2.0
- Comunidade ZFS on Linux

---

**Versão:** 1.0.0  
**Desenvolvido por:** Aurora TUI Team  
**Licença:** MIT
