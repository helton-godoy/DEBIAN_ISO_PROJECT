# Patches do KMSCON para Debian 13 Trixie

Este diretório contém patches específicos aplicados automaticamente durante o build do kmscon para garantir compatibilidade e otimizações no Debian 13 Trixie.

## Estrutura dos Patches

Os patches são aplicados em ordem numérica durante a fase 4 do script de build (`scripts/build-kmscon.sh`). Cada patch segue o formato unified diff e inclui:

- Cabeçalho descritivo com autor e data
- Explicação detalhada das modificações
- Contexto suficiente para aplicação limpa
- Atualização de documentação (man pages, README)

## Lista de Patches

### 001-term-variable.patch

**Autor:** AURORA NAS Project  
**Propósito:** Configura a variável de ambiente TERM apropriadamente

**Modificações:**

- Altera `TERM=xterm-256color` para `TERM=kmscon`
- Permite que aplicações ncurses detectem corretamente o terminal
- Habilita o uso do terminfo específico do kmscon
- Adiciona fallback para `xterm-256color` se necessário
- Atualiza documentação (man page e README)

**Arquivos afetados:**

- `src/terminal.c`
- `src/kmscon_module_interface.c`
- `src/pty.c`
- `src/app.c`
- `docs/kmscon.1`
- `README.md`

**Impacto:** Melhor compatibilidade com aplicações que detectam recursos do terminal

---

### 002-plymouth-integration.patch

**Autor:** AURORA NAS Project  
**Propósito:** Coordenação suave com Plymouth durante boot/shutdown

**Problema resolvido:**
O Plymouth (boot splash) mantém o DRM Master durante o boot. Sem coordenação, o kmscon pode falhar ao tentar acessar o DRM ou causar flickering na transição.

**Modificações:**

- Adiciona função `plymouth_is_active()` para detectar Plymouth
- Implementa `wait_for_plymouth()` com exponential backoff
- Adiciona retry logic para abertura do dispositivo DRM
- Implementa `try_acquire_drm_master()` com retries
- Timeout configurável de 30 segundos (padrão)
- Adiciona delay de 100ms após Plymouth liberar recursos

**Arquivos afetados:**

- `src/video_drm3d.c`
- `src/video_drm3d.h`
- `docs/kmscon.1`

**Configurações:**

```ini
# /etc/kmscon/kmscon.conf
[drm]
plymouth-timeout=30  # segundos
```

**Impacto:** Boot mais suave sem conflitos de DRM com Plymouth

---

### 003-logind-session.patch

**Autor:** AURORA NAS Project  
**Propósito:** Prevenção de consumo excessivo de CPU com systemd-logind

**Problema resolvido:**
Bugs conhecidos causavam busy-loop (100% CPU) quando o kmscon não conseguia comunicar com o systemd-logind ou obter uma sessão de assento válida.

**Modificações:**

- Adiciona timeouts para operações dbus (5 segundos padrão)
- Implementa retry counter para evitar loops infinitos
- Adiciona modo fallback quando logind não está disponível
- Implementa `epoll_wait()` com verificação de eventos reais
- Previne requisições duplicadas de sessão
- Tratamento adequado de erros dbus
- Retry com delay para obter controle da sessão

**Arquivos afetados:**

- `src/logind.c`
- `src/logind.h`
- `src/app.c`

**Constantes configuráveis:**

```c
#define LOGIND_DBUS_TIMEOUT_MS 5000
#define LOGIND_RETRY_DELAY_US 100000
#define LOGIND_MAX_RETRIES 3
#define LOGIND_SEAT_RETRY_DELAY_MS 500
#define LOGIND_SEAT_MAX_RETRIES 10
```

**Impacto:** Elimina consumo de 100% CPU; funciona mesmo sem logind

---

### 004-font-rendering.patch

**Autor:** AURORA NAS Project  
**Propósito:** Otimização de renderização de fontes para HiDPI/4K

**Modificações:**

- Detecção automática de densidade de pixels (GDK_SCALE, QT_SCALE_FACTOR)
- Subpixel rendering RGB/BGR configurável via fontconfig
- Ajuste dinâmico de DPI baseado na densidade
- Hinting desabilitado em displays HiDPI para melhor aparência
- Cache de glyphs otimizado para alta densidade
- Suporte a configurações fontconfig personalizadas

**Arquivos afetados:**

- `src/font_pango.c`
- `src/font_pango.h`
- `src/app.c`
- `docs/kmscon.1`

**Configurações:**

```ini
# /etc/kmscon/kmscon.conf
[font]
font-name=monospace
font-size=12
font-subpixel=rgb      # rgb, bgr, vrgb, vbgr, none
font-hires=true        # habilita HiDPI auto-detection
```

**Variáveis de ambiente:**

- `GDK_SCALE` - Escala do GTK (ex: 2 para 2x)
- `QT_SCALE_FACTOR` - Fator de escala Qt

**Impacto:** Fontes nítidas e legíveis em displays de alta resolução

---

### 005-libinput-touchpad.patch

**Autor:** AURORA NAS Project  
**Propósito:** Configurações otimizadas de touchpad via libinput

**Modificações:**

- Habilita tap-to-click por padrão
- Configura natural scrolling (direção invertida)
- Habilita tap-and-drag
- Configura aceleração de ponteiro adaptativa
- Palm detection para evitar toques acidentais
- Disable-while-typing durante digitação
- Detecção automática de touchpads por nome/padrões

**Arquivos afetados:**

- `src/input_libinput.c`
- `src/input_libinput.h`
- `src/kmscon.conf`
- `docs/kmscon.1`
- `README.md`

**Configurações:**

```ini
# /etc/kmscon/kmscon.conf
[input]
tap-to-click=true
natural-scroll=true
accel-speed=0.0
disable-while-typing=true
middle-emulation=false
left-handed=false
tap-drag=true
```

**Padrões de detecção de touchpad:**

- touchpad, TouchPad, Touchpad
- TrackPad, trackpad
- Synaptics, ALPS, ELAN, bcm
- ClickPad, clickpad

**Impacto:** Experiência de touchpad consistente com laptops modernos

---

## Aplicação dos Patches

O script `build-kmscon.sh` aplica os patches automaticamente:

```bash
# Fase 4: Aplicação de Patches
phase_patch() {
    for patch in "$PATCHES_DIR"/*.diff "$PATCHES_DIR"/*.patch; do
        # Testa primeiro com --dry-run
        if patch -p1 --dry-run < "$patch" &>/dev/null; then
            patch -p1 < "$patch"
        fi
    done
}
```

### Ordem de Aplicação

1. `001-term-variable.patch`
2. `002-plymouth-integration.patch`
3. `003-logind-session.patch`
4. `004-font-rendering.patch`
5. `005-libinput-touchpad.patch`

### Testando Patches Manualmente

```bash
# Download e extração do source
cd /tmp/kmscon-build/src/kmscon-9.0.0

# Testar aplicação (dry-run)
patch -p1 --dry-run < scripts/patches/001-term-variable.patch

# Aplicar patch
patch -p1 < scripts/patches/001-term-variable.patch

# Reverter patch
patch -p1 -R < scripts/patches/001-term-variable.patch
```

## Manutenção dos Patches

### Atualizando para Nova Versão do KMSCON

1. Baixe o novo source do kmscon
2. Tente aplicar cada patch com `--dry-run`
3. Se houver falhas, atualize o contexto do patch
4. Regenere o patch se necessário:

```bash
# Após modificar os arquivos
cd kmscon-source/
git diff > ../scripts/patches/XXX-description.patch
```

### Verificando Status dos Patches

```bash
# Listar patches aplicados
ls -la scripts/patches/

# Verificar se patches aplicaram corretamente
grep -r "PATCH APPLIED" /var/log/kmscon-build.log
```

## Compatibilidade

| Patch                          | KMSCON 9.0 | Debian 13 | Testing  |
| ------------------------------ | ---------- | --------- | -------- |
| 001-term-variable.patch        | ✓          | ✓         | Aplicado |
| 002-plymouth-integration.patch | ✓          | ✓         | Aplicado |
| 003-logind-session.patch       | ✓          | ✓         | Aplicado |
| 004-font-rendering.patch       | ✓          | ✓         | Aplicado |
| 005-libinput-touchpad.patch    | ✓          | ✓         | Aplicado |

## Referências

- [KMSCON Source](https://github.com/kmscon/kmscon)
- [libtsm Source](https://github.com/kmscon/libtsm)
- [systemd-logind Documentation](https://www.freedesktop.org/wiki/Software/systemd/logind/)
- [libinput Documentation](https://wayland.freedesktop.org/libinput/doc/latest/)
- [Plymouth Documentation](https://www.freedesktop.org/wiki/Software/Plymouth/)

## Changelog

### v1.0.0 (2026-01-31)

- Release inicial com 5 patches para Debian 13 Trixie
- Patches 001-005 implementados e testados
- Documentação completa adicionada

---

**Nota:** Estes patches são específicos para a versão 9.0 do kmscon e foram desenvolvidos para o Debian 13 Trixie. Podem requerer ajustes para outras versões ou distribuições.
