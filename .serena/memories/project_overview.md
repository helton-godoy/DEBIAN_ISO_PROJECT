# DEBIAN_ISO_PROJECT - Visão Geral

## Propósito

Projeto para construir uma ISO personalizada do Debian com ZFS on Root para sistemas NAS (Network Attached Storage), utilizando o instalador TUI AURORA.

## Stack Tecnológico

- **Linguagem**: Bash (seguindo princípios Pure Bash Bible)
- **Build System**: Docker + Debian live-build
- **Sistema de Arquivos**: ZFS on Root com ZFSBootMenu
- **Testes**: QEMU/KVM via libvirt (virsh/virt-install)
- **UI**: TUI (Terminal UI) usando `gum` (charm.sh)
- **Boot**: Suporte UEFI e BIOS/Legacy

## Estrutura de Diretórios

```
DEBIAN_ISO_PROJECT/
├── live_config/          # Configuração do live-build (source)
│   └── config/includes.chroot/usr/local/bin/install-system  # Script de instalação
├── live_build/           # Diretório de build (gerado pelo build-live.sh)
├── tests/               # Scripts de teste
│   └── vm-test.sh       # Script unificado para testar ISO e sistema instalado
├── docs/                # Documentação técnica
├── plan/                # Planejamentos e mockups
├── cache/               # Cache persistente para DKMS/ZFS
├── logs/                # Logs de build
├── build-live.sh        # Script principal de build
├── Dockerfile           # Container de build
└── entrypoint.sh        # Entrypoint do container
```

## Componentes Principais

### 1. Instalador AURORA (`install-system`)

- Local: `live_config/config/includes.chroot/usr/local/bin/install-system`
- TUI interativa usando `gum`
- 8 passos de instalação:
  1. Limpar disco (wipefs, sgdisk --zap-all)
  2. Particionamento condicional (UEFI vs BIOS)
  3. Criar pool ZFS
  4. Configurar datasets ZFS
  5. Montar hierarquia de arquivos
  6. Extrair sistema base (unsquashfs)
  7. Aplicar configurações (hostname, rede, fstab)
  8. Instalar bootloader (ZFSBootMenu para UEFI, syslinux para BIOS)

### 2. Script de Teste (`vm-test.sh`)

- Local: `tests/vm-test.sh`
- Suporta 3 modos:
  - `live`: Boot pela ISO para testar sistema live
  - `installed`: Boot pelo disco após instalação
  - `test-install`: Automação completa via QEMU Guest Agent
- Usa virsh/virt-install para gerenciar VMs
- Comunicação com VM via QEMU Guest Agent para automação

## Sistema de Design

- **Design System**: AURORA v2.0 - Monochromatic Slate
- **Paleta**: Tons de azul-acizentado (Slate Blue)
- **Características**: Hierarquia visual através de luminosidade
- **Cores Funcionais**: Sucesso (108), Aviso (179), Erro (167)

## Requisitos de Sistema

- Docker para build
- libvirt-clients, virtinst, qemu-system-x86 para testes
- Bash 4+
- Root necessário para instalação

## Credenciais Padrão

- Usuário: admin
- Senha: admin
- Autologin habilitado no live

## Dependências do Instalador

- gum (TUI)
- lsblk (detecção de discos)
- sgdisk (particionamento GPT)
- zpool/zfs (gerenciamento ZFS)
- unsquashfs (extração do sistema)
- mkfs.vfat (formatação EFI)
- efibootmgr (configuração UEFI)
- extlinux/syslinux (boot BIOS)
