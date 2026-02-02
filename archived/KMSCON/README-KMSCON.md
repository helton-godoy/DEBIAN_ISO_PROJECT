# 🖥️ Script de Build do KMSCON para AURORA NAS

## Visão Geral

Este diretório contém scripts e configurações para compilar e empacotar o **kmscon** (console de sistema baseado em KMS/DRM) para integração na ISO Debian 13 Trixie com ZFSBootMenu.

## 📁 Estrutura de Arquivos

```
scripts/
├── build-kmscon.sh              # Script principal de build
├── kmscon-getty@.service        # Unit file systemd otimizado
├── kmscon.conf                  # Configuração otimizada para true color
├── fontconfig-local.conf        # Configuração Fontconfig (subpixel rendering)
├── patches/                     # Diretório para patches específicos
└── README-KMSCON.md            # Este arquivo
```

## 🚀 Execução Manual

### Pré-requisitos

```bash
# Instalar dependências de build
sudo apt-get install -y \
    build-essential meson ninja-build pkg-config \
    libdrm-dev libxkbcommon-dev libudev-dev libsystemd-dev \
    libpango1.0-dev libfontconfig1-dev libfreetype-dev \
    libgbm-dev libegl1-mesa-dev libgles2-mesa-dev \
    libinput-dev curl tar patch dpkg-dev
```

### Executar Build

```bash
cd scripts/
sudo ./build-kmscon.sh
```

### Opções do Script

```bash
./build-kmscon.sh [OPÇÕES]

  -h, --help          Mostra ajuda
  -v, --version       Mostra versão
  -k, --keep          Mantém diretório de build
  -c, --clean         Limpa cache antes de build
  -j, --jobs N        Número de jobs paralelos
  -l, --log-level     Nível: DEBUG, INFO, WARN, ERROR
  -o, --output DIR    Diretório de saída
```

### Variáveis de Ambiente

| Variável         | Padrão | Descrição                 |
| ---------------- | ------ | ------------------------- |
| `KMSCON_VERSION` | 9.0.0  | Versão do kmscon          |
| `LIBTSM_VERSION` | 4.0.2  | Versão do libtsm          |
| `PARALLEL_JOBS`  | auto   | Jobs paralelos            |
| `KEEP_BUILD`     | 0      | Manter diretório de build |
| `LOG_LEVEL`      | INFO   | Nível de log              |

## 📦 Integração com Live-Build

O hook de live-build está localizado em:

```
live_config/config/hooks/normal/1000-build-kmscon.chroot
```

### Como Funciona

1. **Hook executa em chroot** durante a construção da ISO
2. **Script principal** (`build-kmscon.sh`) é copiado via `includes.chroot`
3. **Build ocorre** dentro do ambiente chroot
4. **Pacote .deb** é instalado automaticamente
5. **Serviços systemd** são configurados

### Inclusão na ISO

O script é copiado automaticamente para:

```
live_config/config/includes.chroot/usr/local/share/kmscon/
```

## ⚙️ Configurações

### kmscon.conf

Configuração otimizada inclui:

- **True Color (24-bit)**: 16 milhões de cores
- **Aceleração DRM/KMS**: Renderização por hardware
- **Libinput**: Suporte a mouse/touchpad
- **Teclado ABNT2**: Layout brasileiro

### kmscon-getty@.service

Unit file systemd com:

- Fallback automático para getty em TTY3-6
- Reinício em caso de falha
- Integração com plymouth

### fontconfig-local.conf

Otimizações de fonte:

- Subpixel rendering (RGB)
- LCD filter otimizado
- Hinting leve
- Fontes monospace priorizadas

## 🔧 Features do Build

Flags Meson habilitadas:

```
-Dvideo_drm3d=enabled      # Suporte a DRM 3D
-Drenderer_gltex=enabled    # Renderizador GL texture
-Dfont_pango=enabled        # Fontes via Pango
-Dlibinput=enabled          # Suporte a libinput
-Dmulti_seat=enabled        # Múltiplos seats
-Dsession_terminal=enabled  # Terminal de sessão
-Dfont_unifont=enabled      # Fonte unifont fallback
-Dextra_debug=false         # Debug desabilitado
```

## 🛠️ Dependências

### Build

- `libdrm-dev (>= 2.4.25)`
- `libxkbcommon-dev (>= 0.5.0)`
- `libtsm-dev (>= 4.3.0)` ou build from source
- `libudev-dev (>= 183)`
- `libsystemd-dev`
- `libpango1.0-dev`
- `libfontconfig1-dev`
- `libfreetype-dev`
- `libgbm-dev`
- `libegl1-mesa-dev`
- `libgles2-mesa-dev`
- `libinput-dev`

### Runtime

- `libdrm2`, `libxkbcommon0`, `libtsm0`
- `libudev1`, `libsystemd0`
- `libpango-1.0-0`, `libfontconfig1`, `libfreetype6`
- `libgbm1`, `libegl1`, `libgles2`
- `libinput10`, `xkb-data`

## 🧪 Troubleshooting

### Build Falha - libtsm não encontrada

O script detecta automaticamente e compila libtsm do source se necessário.

### Serviço não inicia

Verifique se DRM está disponível:

```bash
ls /dev/dri/card*
```

### Fontes ruins

Regenere cache do fontconfig:

```bash
fc-cache -fv
```

## 📋 Fases do Build

1. **setup** - Verificação de ambiente
2. **download** - Download de sources
3. **deps** - Build de libtsm (se necessário)
4. **patch** - Aplicação de patches
5. **configure** - Meson setup
6. **build** - Ninja compile
7. **package** - Geração de .deb
8. **install** - Instalação e configuração systemd

## 🔒 Segurança

- Script usa `set -euo pipefail`
- Rollback automático em caso de falha
- Fallback para agetty em TTYs 3-6
- Verificação de features habilitadas

## 📝 Notas

- O script é **idempotente** (suporta re-execução)
- Suporta execução em **chroot** (live-build)
- Cache de downloads em `scripts/.cache/`
- Logs em `/var/log/kmscon-build.log`

## 📚 Referências

- [KMSCON Upstream](https://github.com/kmscon/kmscon)
- [libtsm](https://github.com/kmscon/libtsm)
- [Debian Live-Build](https://live-team.pages.debian.net/live-manual/)
