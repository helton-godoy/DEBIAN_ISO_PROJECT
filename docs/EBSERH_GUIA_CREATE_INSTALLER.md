# Passos Necessários para Ativar Funcionalidades Reais no 'install-system'

Com base na análise comparativa entre o novo script [`install-system`](install-system:1) (AURORA v2.0 - modo simulação) e o antigo script em [`live_config/config/includes.chroot/usr/local/bin/install-system`](live_config/config/includes.chroot/usr/local/bin/install-system:1) (Aurora - modo real), aqui estão os passos necessários para ativar a instalação real:

## 1. Desativar Modo de Simulação

Alterar a flag [`MOCK_MODE`](install-system:16) na linha 16:

```bash
MOCK_MODE=false  # Alterar de 'true' para 'false'
```

## 2. Ativar Verificação de Hardware e Detecção de Modo de Boot

Substituir a verificação rígida de UEFI (linhas 309-312) pela detecção dinâmica de modo de boot na função [`check_hardware()`](install-system:302):

```bash
# Detectar modo de boot (BIOS vs UEFI)
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="UEFI"
    status_ok "Modo UEFI detectado"
else
    BOOT_MODE="BIOS"
    status_warn "Modo BIOS/Legacy detectado"
fi
```

> **Nota**: O instalador agora suporta **ambos os modos de boot** (UEFI e BIOS/Legacy). A variável `BOOT_MODE` será usada em passos subsequentes para aplicar a lógica condicional apropriada.

## 3. Substituir Detecção Mock de Discos

Na função [`select_disk()`](install-system:325), substituir o bloco mock (linhas 335-346) pela detecção real:

```bash
DISK_LIST=$(lsblk -dno NAME,SIZE,MODEL | grep -v "loop" | awk '{print $1" ("$2") - "$3}')
```

## 4. Implementar 8 Passos de Instalação Real (com Suporte BIOS/UEFI)

Na função [`run_installation()`](install-system:450), substituir as chamadas [`run_step_mock()`](install-system:94) por [`run_step()`](install-system:572) com os comandos reais adaptados do script antigo. A instalação agora deve usar lógica condicional baseada na variável `BOOT_MODE`:

### 4.1. Passos 1-7 (Comuns a Ambos os Modos)

| Passo            | Comando Real Necessário (adaptado do script antigo)                                                                   |
|------------------|-----------------------------------------------------------------------------------------------------------------------|
| 1 - Limpar disco | `wipefs -a $TARGET_DISK && sgdisk --zap-all $TARGET_DISK`                                                             |
| 3 - Pool ZFS     | `sgdisk -n 2:0:0 -t 2:BF01 $TARGET_DISK && partprobe && zpool create -f $ZFS_OPTS -R /mnt $POOL_NAME ${TARGET_DISK}2` |
| 4 - Datasets     | `zfs create` para ROOT/debian, home, home/root                                                                        |
| 5 - Montagem     | `zpool export/import`, `zfs mount -a`                                                                                 |
| 6 - Extração     | `unsquashfs -f -d /mnt /run/live/medium/live/filesystem.squashfs`                                                     |
| 7 - Configuração | Criar hostname, hosts, fstab, rede, machine-id                                                                        |

### 4.2. Passo 2 - Particionamento Condicional (BIOS vs UEFI)

Adicionar lógica condicional para criar o esquema de partições apropriado:

```bash
if [ "$BOOT_MODE" = "UEFI" ]; then
    # UEFI: Partição EFI de 512MB
    sgdisk -n 1:1M:+512M -t 1:EF00 $TARGET_DISK
    mkfs.vfat -F 32 -n EFI ${TARGET_DISK}1
else
    # BIOS: Partição BIOS boot de 1MB (opcional para ZFS, recomendado para compatibilidade)
    sgdisk -n 1:0:+1M -t 1:EF02 $TARGET_DISK
fi
```

| Modo | Partição 1 | Tipo | Comando sgdisk            | Formatação        |
|------|------------|------|---------------------------|-------------------|
| UEFI | EFI System | EF00 | `-n 1:1M:+512M -t 1:EF00` | `mkfs.vfat -F 32` |
| BIOS | BIOS Boot  | EF02 | `-n 1:0:+1M -t 1:EF02`    | Não formatada     |

### 4.3. Passo 5 - Montagem Condicional

```bash
# Montagem do pool ZFS
zpool export $POOL_NAME
zpool import -N -R /mnt $POOL_NAME
zfs mount -a

# Montar EFI apenas no modo UEFI
if [ "$BOOT_MODE" = "UEFI" ]; then
    mkdir -p /mnt/boot/efi
    mount ${TARGET_DISK}1 /mnt/boot/efi
fi
```

### 4.4. Passo 8 - Bootloader Condicional (BIOS vs UEFI)

O instalador deve usar abordagens diferentes para instalar o bootloader conforme o modo:

```bash
if [ "$BOOT_MODE" = "UEFI" ]; then
    # UEFI: Copiar ZFSBootMenu EFI para partição EFI
    mkdir -p /mnt/boot/efi/EFI/ZBM
    cp /usr/local/bin/zfsbootmenu.efi /mnt/boot/efi/EFI/ZBM/VMLINUZ.EFI
    # Configurar entrada UEFI
    efibootmgr --create --disk $TARGET_DISK --part 1 \
        --label "ZFSBootMenu" --loader "\EFI\ZBM\VMLINUZ.EFI"
else
    # BIOS: Instalar syslinux ou GRUB no MBR
    # Opção 1: Usar syslinux/extlinux para ZFS
    extlinux --install /mnt/boot/syslinux
    dd if=/usr/lib/syslinux/mbr.bin of=$TARGET_DISK bs=440 count=1
    
    # Ou Opção 2: Usar GRUB legacy
    # grub-install --target=i386-pc $TARGET_DISK
fi
```

| Modo | Bootloader      | Localização/Target               | Comando Principal                      |
|------|-----------------|----------------------------------|----------------------------------------|
| UEFI | ZFSBootMenu EFI | `/boot/efi/EFI/ZBM/`             | `efibootmgr --create`                  |
| BIOS | Syslinux/GRUB   | MBR do disco + `/boot/syslinux/` | `extlinux --install` + `dd if=mbr.bin` |

## 5. Adicionar Finalização no Chroot

Replicar o bloco `chroot` do script antigo (linhas 170-180) no final da instalação para:

- Executar `systemd-machine-id-setup` e `zgenhostid`
- Configurar cache ZFS e `update-initramfs`
- Criar usuário administrador e definir senhas (root e usuário)
- Remover usuário padrão "user" se existir

## 6. Diferenças BIOS vs UEFI - Guia de Implementação

Esta seção documenta as diferenças técnicas entre os modos de boot que o instalador deve considerar:

### 6.1. Detecção do Modo de Boot

```bash
# Lógica de detecção implementada na função check_hardware()
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE="BIOS"
fi

# Exibir com gum style
if [ "$BOOT_MODE" = "UEFI" ]; then
    status_ok "Modo UEFI detectado"
else
    status_warn "Modo BIOS/Legacy detectado"
fi
```

### 6.2. Tabela Comparativa: BIOS vs UEFI

| Aspecto                 | UEFI                           | BIOS/Legacy                  |
|-------------------------|--------------------------------|------------------------------|
| **Detecção**            | `[ -d /sys/firmware/efi ]`     | Ausência do diretório acima  |
| **Partição 1**          | EFI System (EF00) - 512MB      | BIOS Boot (EF02) - 1MB       |
| **Formatação P1**       | VFAT (mkfs.vfat -F 32)         | Não formatada (raw)          |
| **Montagem P1**         | `/boot/efi`                    | Não montada                  |
| **Bootloader**          | ZFSBootMenu EFI                | Syslinux/GRUB legacy         |
| **Local do Bootloader** | `/boot/efi/EFI/ZBM/`           | MBR + `/boot/syslinux/`      |
| **Comando Instalação**  | `efibootmgr` + copiar arquivos | `extlinux` + `dd mbr.bin`    |
| **Compatibilidade**     | Sistemas modernos (2010+)      | Sistemas antigos, VMs legacy |

### 6.3. Considerações sobre Compatibilidade

1. **ZFS com BIOS**: O ZFS on Root funciona em modo BIOS, mas requer:
   - Partição BIOS boot (EF02) para grub-bios ou syslinux
   - Configuração adequada do pool ZFS (devices=off recomendado)
   - Kernel e initramfs acessíveis pelo bootloader

2. **Limitações BIOS**:
   - Não suporta secure boot
   - Limitado a partições MBR em alguns casos (usar GPT + BIOS boot)
   - Bootloader no MBR tem limitações de tamanho

3. **Recomendação**: Sempre que possível, prefira UEFI para:
   - Melhor suporte a ZFSBootMenu
   - Recursos de recuperação mais robustos
   - Compatibilidade com secure boot (futuro)

### 6.4. Variável Global BOOT_MODE

A variável `BOOT_MODE` deve ser:

- Definida na função `check_hardware()`
- Exportada ou passada para funções que precisam dela
- Usada em condicionais nos passos 2, 5 e 8

```bash
# Exemplo de uso no run_installation()
run_installation() {
    # ...
    if [ "$BOOT_MODE" = "UEFI" ]; then
        # Lógica UEFI
    else
        # Lógica BIOS
    fi
    # ...
}
```

## 7. Adicionar Opção de Reinicialização

Na função [`show_completion()`](install-system:540), adicionar confirmação para reiniciar o sistema (adaptado do script antigo, linhas 188-190).

Incluir no resumo final o modo de boot detectado:

```bash
info_card "Configurações Selecionadas" \
    "$(list_item "Disco de destino" "$TARGET_DISK")" \
    "$(list_item "Modo de boot" "$BOOT_MODE")" \
    "$(list_item "Filesystem" "ZFS on Root (ZBM)")" \
    # ... outros campos
```

## 8. Copiar para Destino Final

Após as modificações:

```bash
cp install-system live_config/config/includes.chroot/usr/local/bin/install-system
chmod +x live_config/config/includes.chroot/usr/local/bin/install-system
```

## Pontos de Atenção Críticos

⚠️ **Verificações de segurança a manter:**

- Verificar existência do arquivo squashfs antes da extração
- Confirmar explicitamente antes de apagar dados do disco
- Validar senhas coincidem antes de aplicar
- Tratar erros em cada comando crítico via [`run_step()`](install-system:572)

⚠️ **Suporte a BIOS e UEFI:**
O instalador agora suporta **ambos os modos de boot** (BIOS/Legacy e UEFI). A detecção é feita automaticamente na função `check_hardware()` e a lógica condicional deve ser aplicada nos passos de particionamento, montagem e instalação do bootloader.

⚠️ **Testes necessários em ambos os modos:**

- Testar instalação em VM com modo UEFI (ovmf)
- Testar instalação em VM com modo BIOS (seabios)
- Verificar se o bootloader funciona corretamente em cada modo

⚠️ **Dependências do ambiente live:**
As ferramentas `gum`, `sgdisk`, `wipefs`, `partprobe`, `zpool`, `zfs` e `unsquashfs` devem estar disponíveis no ambiente live.

Para modo BIOS, dependências adicionais podem ser necessárias:

- `syslinux-common` e `syslinux` (para extlinux)
- Ou `grub-pc-bin` (para GRUB legacy)

A estrutura do novo script já está preparada para o modo real - a função [`run_step()`](install-system:572) já suporta execução real quando `MOCK_MODE=false`. A transição principal é substituir os comandos simulados na [`run_installation()`](install-system:450) pelos comandos reais do script antigo, preservando o novo Design System Monochromatic Slate e os componentes de UI premium.
