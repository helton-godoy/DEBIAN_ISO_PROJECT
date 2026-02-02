# Comandos Sugeridos - DEBIAN_ISO_PROJECT

## Build

### Construir a ISO

```bash
./build-live.sh
```

- Gera ISO em: `live_build/live-image-amd64.hybrid.iso`
- Logs em: `logs/build_iso_YYYYMMDD_HHMMSS.log`

## Testes

### Testar ISO no modo live (boot pela ISO)

```bash
./tests/vm-test.sh live
```

- Cria VM nova com a ISO
- Permite testar o sistema live e o instalador

### Testar sistema instalado (boot pelo disco)

```bash
./tests/vm-test.sh installed
```

- Ejeta ISO e boota pelo disco
- Valida sistema pós-instalação

### Teste automatizado completo

```bash
./tests/vm-test.sh test-install
```

- Inicia VM live
- Espera QEMU Guest Agent
- Injeta script atualizado do install-system
- Executa instalação automaticamente
- Monitora logs em /var/log/install-system.log
- Salva log completo em install-system-latest.log

### Comandos auxiliares do vm-test.sh

```bash
./tests/vm-test.sh --status    # Ver status da VM
./tests/vm-test.sh --stop      # Parar VM
./tests/vm-test.sh --remove    # Remover VM completamente
./tests/vm-test.sh --connect   # Reconectar ao console
./tests/vm-test.sh --help      # Ajuda completa
```

## Gerenciamento de VM

### Via virsh (libvirt)

```bash
# Listar VMs
virsh --connect qemu:///session list --all

# Iniciar VM
virsh --connect qemu:///session start debian-zfs-test

# Parar VM
virsh --connect qemu:///session destroy debian-zfs-test

# Conectar ao console
virsh --connect qemu:///session console debian-zfs-test

# Remover VM
virsh --connect qemu:///session undefine debian-zfs-test --nvram
```

## Instalador

### Executar instalador manualmente (dentro da VM live)

```bash
sudo install-system
# ou
sudo aurora-installer  # symlink
```

### Modo automático (sem interação)

```bash
sudo install-system --auto
```

## Debug e Logs

### Logs na VM

```bash
# Log do instalador
tail -f /var/log/install-system.log

# Log do sistema
journalctl -f

# Verificar pool ZFS
zpool status
zfs list

# Verificar partições
lsblk
sgdisk -p /dev/vda
```

### Logs no host

```bash
# Logs de build
ls -la logs/
tail -f logs/build_iso_*.log

# Log da última instalação automatizada
cat install-system-latest.log
```

## Sair do Console da VM

```
Ctrl + ]    # (Ctrl e colchete direito)
# ou
Ctrl + 5
```

## Variáveis de Ambiente para Testes

```bash
export VM_NAME=debian-zfs-test
export VM_RAM=4096
export VM_CPUS=4
export VM_DISK_SIZE=20
```

## Docker

### Rebuild da imagem de build

```bash
docker build -t debian-live-builder .
```

### Limpar cache de build

```bash
sudo rm -rf live_build/cache
```

## Análise da ISO

### Montar ISO para inspeção

```bash
sudo mount -o loop live_build/live-image-amd64.hybrid.iso /mnt/iso
ls /mnt/iso
```

### Verificar SquashFS

```bash
ls /mnt/iso/live/filesystem.squashfs
unsquashfs -l /mnt/iso/live/filesystem.squashfs | head
```
