# KMSCON Quick Start Guide

Guia rápido de referência para uso do sistema de build do KMSCON no projeto AURORA NAS.

---

## Comandos Essenciais

### Build Completo

```bash
# Build padrão (todos os TTYs)
sudo bash scripts/build-kmscon.sh

# Build com logs detalhados
sudo LOG_LEVEL=DEBUG bash scripts/build-kmscon.sh

# Build preservando diretórios (para debug)
sudo bash scripts/build-kmscon.sh --keep

# Limpar cache e rebuild
sudo bash scripts/build-kmscon.sh --clean
```

### Gestão de Serviços

```bash
# Habilitar kmscon em TTYs 1 e 2
sudo systemctl enable kmscon-getty@tty1.service
sudo systemctl enable kmscon-getty@tty2.service

# Desabilitar getty padrão
sudo systemctl disable getty@tty1.service
sudo systemctl disable getty@tty2.service

# Iniciar imediatamente
sudo systemctl start kmscon-getty@tty1.service

# Parar serviço
sudo systemctl stop kmscon-getty@tty1.service

# Verificar status
sudo systemctl status kmscon-getty@tty1.service
```

### Verificação Rápida

```bash
# Verificar instalação
which kmscon && kmscon --version

# Verificar logs
sudo tail -f /var/log/kmscon-build.log

# Verificar serviços
systemctl list-units | grep kmscon

# Verificar configuração
cat /etc/kmscon/kmscon.conf
```

---

## Checklist de Verificação

### Pré-Build

- [ ] Sistema é Debian 13 Trixie ou compatível
- [ ] Executando como root (`sudo`)
- [ ] Bash 4.0+ instalado (`bash --version`)
- [ ] Conexão com internet disponível
- [ ] Espaço em disco: mínimo 2GB livre (`df -h /tmp`)
- [ ] Memória RAM: mínimo 2GB disponível (`free -h`)

### Dependências

```bash
# Verificar dependências rapidamente
dpkg -l | grep -E "meson|ninja|libdrm|libinput|pango|fontconfig"
```

- [ ] `meson` (>= 1.2.0)
- [ ] `ninja-build`
- [ ] `build-essential`
- [ ] `libdrm-dev`
- [ ] `libinput-dev`
- [ ] `libpango1.0-dev`
- [ ] `libfontconfig1-dev`
- [ ] `dpkg-dev`

### Durante o Build

- [ ] Download do source concluído (kmscon + libtsm)
- [ ] Todos os patches aplicados (001-005)
- [ ] Configuração meson bem-sucedida
- [ ] Features obrigatórias habilitadas:
  - [ ] video_drm3d
  - [ ] renderer_gltex
  - [ ] font_pango
  - [ ] libinput
- [ ] Compilação sem erros
- [ ] Pacote .deb gerado
- [ ] Instalação concluída

### Pós-Instalação

```bash
# Script de verificação rápida
#!/bin/bash
echo "=== Verificação KMSCON ==="

# Binário
[[ -x /usr/bin/kmscon ]] && echo "✓ Binário: OK" || echo "✗ Binário: FALTA"

# Configuração
[[ -f /etc/kmscon/kmscon.conf ]] && echo "✓ Config: OK" || echo "✗ Config: FALTA"

# Service
[[ -f /etc/systemd/system/kmscon-getty@.service ]] && echo "✓ Service: OK" || echo "✗ Service: FALTA"

# Dependências
ldd /usr/bin/kmscon | grep -q "not found" && echo "✗ Dependências: FALTANDO" || echo "✓ Dependências: OK"

echo "==========================="
```

- [ ] Binário em `/usr/bin/kmscon`
- [ ] Configuração em `/etc/kmscon/kmscon.conf`
- [ ] Service em `/etc/systemd/system/kmscon-getty@.service`
- [ ] Serviços habilitados (tty1, tty2)
- [ ] Dependências de runtime resolvidas

### Validação Final

- [ ] TTY1 mostra kmscon (não getty padrão)
- [ ] Cores true color funcionam (`echo -e "\e[38;2;255;0;0mTeste\e[0m"`)
- [ ] Fontes renderizam corretamente
- [ ] Touchpad responde (se aplicável)
- [ ] Teclado ABNT2 funcionando
- [ ] Switch entre TTYs funciona (Ctrl+Alt+F1-F6)

---

## Alterações Comuns

### Alterar Tamanho da Fonte

```bash
# Editar configuração
sudo nano /etc/kmscon/kmscon.conf

[general]
font-size=20  # Padrão: 16

# Reiniciar serviço
sudo systemctl restart kmscon-getty@tty1.service
```

### Alterar Layout do Teclado

```bash
# Editar configuração
sudo nano /etc/kmscon/kmscon.conf

[input]
xkb-layout=us      # ou br, de, fr, etc.
xkb-variant=       # ou abnt2 para BR

# Reiniciar
sudo systemctl restart kmscon-getty@tty1.service
```

### Adicionar Mais TTYs

```bash
# Habilitar em tty3
sudo systemctl disable getty@tty3.service
sudo systemctl enable kmscon-getty@tty3.service
sudo systemctl start kmscon-getty@tty3.service
```

### Configurar HiDPI

```bash
# Opção 1: Variáveis de ambiente
sudo systemctl edit kmscon-getty@tty1.service

[Service]
Environment="GDK_SCALE=2"
Environment="QT_SCALE_FACTOR=2"

# Opção 2: Aumentar fonte
sudo nano /etc/kmscon/kmscon.conf
font-size=24
```

### Desabilitar KMSCON (Fallback)

```bash
# Restaurar getty padrão em todos os TTYs
for vt in tty1 tty2 tty3 tty4 tty5 tty6; do
    sudo systemctl stop kmscon-getty@${vt}.service
    sudo systemctl disable kmscon-getty@${vt}.service
    sudo systemctl enable getty@${vt}.service
    sudo systemctl start getty@${vt}.service
done
```

---

## FAQ

### Q: O build falha com "meson não encontrado"

```bash
# Instalar meson e ninja
sudo apt-get update
sudo apt-get install meson ninja-build
```

### Q: Erro "Cannot open DRM device"

**Causas comuns:**

1. Executando em VM sem aceleração 3D
2. Drivers GPU não carregados
3. Plymouth ainda ativo

**Soluções:**

```bash
# Verificar módulos DRM
lsmod | grep drm

# Verificar dispositivos
ls -la /dev/dri/

# Verificar Plymouth
sudo systemctl status plymouth

# Em VM: habilitar aceleração 3D nas configurações
```

### Q: Fontes aparecem borradas ou pixeladas

```bash
# Instalar fontconfig local
sudo cp scripts/fontconfig-local.conf /etc/fonts/local.conf

# Recarregar cache
sudo fc-cache -f -v

# Aumentar tamanho da fonte
sudo nano /etc/kmscon/kmscon.conf
font-size=18
```

### Q: Touchpad não funciona

```bash
# Verificar se libinput detecta
sudo libinput list-devices

# Verificar se kmscon foi compilado com libinput
kmscon --help | grep -i libinput

# Rebuild se necessário
sudo bash scripts/build-kmscon.sh --clean
```

### Q: Consumo de 100% CPU

Isso foi resolvido pelo patch 003. Se persistir:

```bash
# Verificar se patch foi aplicado
grep -r "fallback_mode" /tmp/kmscon-build/src/ 2>/dev/null

# Verificar logs
sudo journalctl -u kmscon-getty@tty1.service -f

# Workaround: desabilitar logind
sudo nano /etc/kmscon/kmscon.conf
[session]
session-terminal=disabled
```

### Q: Como voltar para getty em caso de problema?

```bash
# Acessar TTY3 (ainda usa getty)
Ctrl+Alt+F3

# Fazer login

# Desabilitar kmscon
sudo systemctl stop kmscon-getty@tty1.service
sudo systemctl disable kmscon-getty@tty1.service
sudo systemctl enable getty@tty1.service
sudo systemctl start getty@tty1.service
```

### Q: Build demora muito

```bash
# Usar mais jobs paralelos
sudo bash scripts/build-kmscon.sh --jobs $(nproc)

# Ou
sudo PARALLEL_JOBS=8 bash scripts/build-kmscon.sh
```

### Q: Posso usar em Debian 12 (Bookworm)?

Possível, mas requer ajustes:

- libtsm pode precisar de build manual
- systemd pode ter diferenças na API logind
- Meson pode ser versão mais antiga

Recomendado: usar Debian 13 Trixie.

### Q: Funciona em hardware ARM (Raspberry Pi)?

Sim, desde que:

- GPU tenha drivers DRM/KMS (vc4, v3d)
- Kernel compilado com DRM
- `dtoverlay=vc4-kms-v3d` no config.txt

```bash
# Verificar no Raspberry Pi
ls /dev/dri/
# Deve mostrar card0
```

---

## Tabela de Atalhos

### Navegação

| Atalho        | Ação                          |
| ------------- | ----------------------------- |
| `Ctrl+Alt+F1` | Ir para TTY1 (kmscon)         |
| `Ctrl+Alt+F2` | Ir para TTY2 (kmscon)         |
| `Ctrl+Alt+F3` | Ir para TTY3 (getty fallback) |
| `Ctrl+Alt+F6` | Ir para TTY6 (getty fallback) |

### KMSCON Interno

| Atalho                   | Ação                             |
| ------------------------ | -------------------------------- |
| `Ctrl+Shift+F1-F12`      | Trocar sessão                    |
| `Ctrl+Shift+PgUp/PgDown` | Scrollback                       |
| `Ctrl+Shift+C`           | Copiar seleção                   |
| `Ctrl+Shift+V`           | Colar                            |
| `Ctrl+Alt+Bksp`          | Terminar sessão (se configurado) |

---

## Variáveis de Ambiente Rápidas

```bash
# Build
export KMSCON_VERSION=9.0.0
export LIBTSM_VERSION=4.0.2
export PARALLEL_JOBS=4
export LOG_LEVEL=INFO
export KEEP_BUILD=0

# Runtime
export GDK_SCALE=2
export QT_SCALE_FACTOR=2
export TERM=kmscon
export COLORTERM=truecolor
```

---

## Caminhos Importantes

| Caminho                                     | Descrição                     |
| ------------------------------------------- | ----------------------------- |
| `/usr/bin/kmscon`                           | Binário principal             |
| `/etc/kmscon/kmscon.conf`                   | Configuração                  |
| `/etc/systemd/system/kmscon-getty@.service` | Service systemd               |
| `/var/log/kmscon-build.log`                 | Logs de build                 |
| `/tmp/kmscon-build/`                        | Diretório de build temporário |
| `/var/cache/kmscon-build/`                  | Pacotes .deb gerados          |
| `scripts/build-kmscon.sh`                   | Script de build               |
| `scripts/patches/`                          | Patches específicos           |

---

## Comandos de Diagnóstico

```bash
# Informações completas
kmscon --version
kmscon --help

# Verificar DRM
ls -la /dev/dri/
drm_info 2>/dev/null || echo "drm_info não instalado"

# Verificar fontes
fc-list | head -10
fc-match monospace

# Verificar input
sudo libinput list-devices

# Verificar systemd
systemctl --version
loginctl show-session 1

# Logs em tempo real
sudo journalctl -f -u kmscon-getty@tty1.service
```

---

**Referência Rápida**: [`KMSCON_INTEGRATION_GUIDE.md`](KMSCON_INTEGRATION_GUIDE.md)  
**API do Script**: [`KMSCON_SCRIPT_API.md`](KMSCON_SCRIPT_API.md)  
**Patches**: [`scripts/patches/README.md`](../scripts/patches/README.md)
