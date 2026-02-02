# Checklist de Conclusão de Tarefas - DEBIAN_ISO_PROJECT

## Antes de Considerar a Tarefa Concluída

### 1. Testes

- [ ] A ISO foi construída com sucesso? (`./build-live.sh`)
- [ ] O modo live funciona? (`./tests/vm-test.sh live`)
- [ ] O instalador executa sem erros?
- [ ] A instalação completa todos os 8 passos?
- [ ] O sistema instalado inicializa? (`./tests/vm-test.sh installed`)
- [ ] O ZFS on Root está funcionando corretamente?
- [ ] O bootloader (ZFSBootMenu/syslinux) está instalado?

### 2. Validação do Sistema Instalado

- [ ] Pool ZFS está online (`zpool status`)
- [ ] Datasets estão montados (`zfs list`)
- [ ] Usuário administrador foi criado corretamente
- [ ] Senha root está configurada
- [ ] Hostname está correto
- [ ] Rede (DHCP) está funcionando
- [ ] Sistema de arquivos root está no ZFS

### 3. Logs e Diagnóstico

- [ ] Verificar `/var/log/install-system.log` na VM
- [ ] Não há erros críticos no log
- [ ] Todos os comandos retornaram exit code 0
- [ ] Mensagens de sucesso aparecem corretamente

### 4. Scripts de Teste

- [ ] `./tests/vm-test.sh` funciona corretamente
- [ ] Modo `live` cria VM e boota pela ISO
- [ ] Modo `installed` ejecta ISO e boota pelo disco
- [ ] Modo `test-install` executa automação completa (se aplicável)

### 5. Código

- [ ] Código segue convenções Pure Bash Bible
- [ ] Strict mode (`set -euo pipefail`) está ativo
- [ ] Não há comandos externos desnecessários
- [ ] Tratamento de erros está implementado
- [ ] Cleanup é executado em caso de falha

## Quando Concluir

A tarefa só deve ser considerada **CONCLUÍDA** quando:

1. O script `./tests/vm-test.sh test-install` executa a instalação completa com sucesso
2. O sistema operacional inicializa corretamente a partir do disco virtual
3. Todos os logs mostram execução bem-sucedida
4. O sistema ZFS on Root está operacional
5. Não há regressões em funcionalidades existentes

## Comandos de Validação Final

```bash
# 1. Build da ISO
./build-live.sh

# 2. Teste automatizado completo
./tests/vm-test.sh test-install

# 3. Se sucesso, verificar boot
./tests/vm-test.sh installed

# 4. Verificar status
./tests/vm-test.sh --status
```

## Critérios de Falha (Não Concluir)

NÃO concluir a tarefa se:

- A instalação falha em qualquer um dos 8 passos
- O sistema não inicializa após instalação
- O pool ZFS não é importado automaticamente
- O bootloader não é instalado corretamente
- Há erros no log que não foram investigados
- O teste automatizado falha

## Documentação

Se foram feitas alterações significativas:

- [ ] Atualizar comentários no código
- [ ] Documentar novas funcionalidades
- [ ] Atualizar guias se necessário
