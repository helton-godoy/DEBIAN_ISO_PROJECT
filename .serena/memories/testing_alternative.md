# Alternativa de Teste - QEMU Direto

## Problema

O virt-install está falhando devido a dependências Python (módulo 'gi').

## Solução Alternativa

Usar qemu-system-x86_64 diretamente para testar a ISO.

## Comando QEMU

```bash
qemu-system-x86_64 \
  -name debian-zfs-test \
  -m 4096 \
  -smp 4 \
  -boot d \
  -cdrom live_build/live-image-amd64.hybrid.iso \
  -drive file=debian-zfs-test.qcow2,format=qcow2,size=20G \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -vga std \
  -display gtk
```

## Status do Projeto

- ✅ Fase 1: Logging implementado
- ✅ Fase 2: Modo --auto implementado
- ✅ Fase 3: Race conditions corrigidas
- ✅ Fase 4: Validação de recursos adicionada
- ✅ Fase 5: Segurança melhorada
- ⏳ Fase 6: Testes pendentes devido a problema com virt-install

## Próximos Passos

1. Usar qemu diretamente, ou
2. Corrigir dependências do virt-install, ou
3. Testar manualmente a ISO
