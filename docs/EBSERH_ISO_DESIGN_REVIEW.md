# Revisão Arquitetural: AURORA_ISO_DESIGN.md

**Data da Revisão:** 2026-01-29  
**Revisor:** Architect Mode  
**Contexto:** Garantir replicação do comportamento FreeNAS 9.10 sobre base Debian pura

---

## 1. Resumo Executivo

Esta revisão analisa o documento [`docs/AURORA_ISO_DESIGN.md`](docs/AURORA_ISO_DESIGN.md:1) em comparação com os requisitos do [`docs/AURORA_NAS.md`](docs/AURORA_NAS.md:1) e a implementação atual em [`live_config/config/includes.chroot/usr/local/bin/install-system`](live_config/config/includes.chroot/usr/local/bin/install-system:1).

**Status Geral:** O design arquitetural está sólido (ZFSBootMenu + live-build), mas há **gaps críticos** entre o design e a implementação atual que impedem a replicação fiel do FreeNAS 9.10.

---

## 2. Gaps Críticos Identificados

### 2.1 Tuning de Kernel Ausente

| Aspecto                                     | Status           | Impacto |
|---------------------------------------------|------------------|---------|
| [`/etc/sysctl.conf`](docs/AURORA_NAS.md:22) | NÃO IMPLEMENTADO | Alto    |

O [`install-system`](live_config/config/includes.chroot/usr/local/bin/install-system:170) atual termina sem aplicar as otimizações de kernel definidas no NAS.md:

```ini
# Parâmetros ausentes no install-system
vm.swappiness=10
vm.min_free_kbytes=65536
net.core.rmem_max=16777216
net.core.wmem_max=16777216
fs.inotify.max_user_watches=524288
```

**Risco:** Performance de rede e I/O significativamente inferior ao FreeNAS 9.10.

**Recomendação:** Adicionar bloco no chroot do install-system para gerar `/etc/sysctl.d/99-nas-performance.conf`.

---

### 2.2 Configuração Samba Inexistente

| Aspecto                             | Status     | Impacto |
|-------------------------------------|------------|---------|
| [`smb.conf`](docs/AURORA_NAS.md:74) | NÃO GERADO | CRÍTICO |

O install-system instala pacotes Samba (linha 92-95 do package-list) mas **não gera configuração**. O objetivo de "replicar funcionalidades do FreeNAS" inclui o compartilhamento SMB que é core do sistema.

**Elementos ausentes:**

- Seção `[global]` com integração AD
- Otimizações de AIO e strict sync
- IDMAP RID para mapeamento de IDs
- Configuração de VFS objects

**Recomendação:** Incluir template smb.conf no install-system com placeholders para o realm AURORA.

---

### 2.3 Integração Active Directory Incompleta

| Aspecto                               | Status              | Impacto |
|---------------------------------------|---------------------|---------|
| [`realm join`](docs/AURORA_NAS.md:60) | NÃO IMPLEMENTADO    | CRÍTICO |
| `/etc/krb5.conf`                      | NÃO CONFIGURADO     | Alto    |
| NTP/Time Sync                         | NÃO CONFIGURADO     | Alto    |
| DNS/Resolv.conf                       | CONFIGURAÇÃO BÁSICA | Médio   |

O install-system configura rede via DHCP ([systemd-networkd](live_config/config/includes.chroot/usr/local/bin/install-system:141)), mas não prepara o sistema para ingressar no domínio AURORA.

**Recomendação:** Adicionar ao install-system:

1. Instalação e configuração do `chrony` para sync de tempo
2. Template `/etc/krb5.conf` com realm AURORANET.AURORA.GOV.BR
3. Script post-install opcional para `realm join`

---

### 2.4 Suporte a RAID/Multi-Disco Ausente

| Aspecto      | Status           | Impacto |
|--------------|------------------|---------|
| Mirror/RAIDZ | NÃO IMPLEMENTADO | Médio   |

O [`install-system`](live_config/config/includes.chroot/usr/local/bin/install-system:56) permite selecionar apenas **um disco**. O FreeNAS 9.10 tipicamente operava com RAID (mirror mínimo).

**Recomendação:** Evoluir o instalador para:

1. Permitir seleção múltipla de discos (gum choose --no-limit)
2. Oferecer opções de RAID: mirror (2+ discos), raidz1 (3+), raidz2 (4+)
3. Validação de número mínimo de discos por nível

---

## 3. Decisões Arquiteturais Pendentes

### 3.1 Dilema das ACLs: POSIX vs NFSv4

O AURORA_ISO_DESIGN.md (seção 4) apresenta o dilema corretamente. A decisão impacta diretamente a migração de dados do FreeNAS.

#### Opção A: POSIX ACLs + xattr=sa (Recomendação Padrão)

```bash
zfs set acltype=posixacl rpool/dados
zfs set xattr=sa rpool/dados
```

**Vantagens:**

- Integração nativa com ferramentas Linux (getfacl, setfacl)
- Samba vfs_acl_xattr é estável e bem testado
- Sem curva de aprendizado para admins Linux

**Desvantagens:**

- Migração de FreeNAS (NFSv4 ACLs) pode perder granularidade
- Mapeamento de ACLs complexas do Windows é aproximado

#### Opção B: NFSv4 ACLs (Compatibilidade FreeNAS)

```bash
zfs set acltype=nfsv4 rpool/dados
```

**Vantagens:**

- Compatibilidade perfeita com dados migrados do FreeNAS
- Suporte nativo a ACLs ricas do Windows

**Desvantagens:**

- Ferramentas Linux padrão não reconhecem (usar nfs4_getfacl)
- Menos documentação para troubleshooting

#### Recomendação de Revisão

Para o objetivo específico de **replicar FreeNAS 9.10**, recomendo a **Opção B (NFSv4 ACLs)** para o dataset de dados. Isso garante:

1. Migração `rsync -A -X` preserva 100% das ACLs
2. Comportamento idêntico ao FreeNAS para usuários finais
3. Documentação deve incluir comandos nfs4_getfacl/nfs4_setfacl

---

### 3.2 Estratégia de Integração AD: realmd vs Winbind Puro

O package-list atual inclui **ambos** realmd/sssd e winbind, criando potencial conflito.

#### Opção A: realmd + sssd (Abordagem "Moderna")

```bash
realm join auroranet.aurora.gov.br -U admin
```

**Vantagens:**

- Configuração automática de krb5, sssd, pam
- Recomendado por Red Hat/Debian hoje

**Desvantagens:**

- Mapeamento de IDs pode diferir do FreeNAS 9.10
- Menos controle granular

#### Opção B: Winbind Puro (Abordagem "FreeNAS-Compatible")

Configuração manual de:

- `/etc/krb5.conf`
- `/etc/samba/smb.conf` com idmap rid
- `/etc/nsswitch.conf`

**Vantagens:**

- Replicação fiel do comportamento FreeNAS 9.10
- IDMAP RID garante IDs consistentes entre reinstalações

**Desvantagens:**

- Mais complexo configurar

#### Recomendação de Revisão

Para **replicação fiel do FreeNAS 9.10**, usar **Opção B (Winbind Puro)**. Isso garante:

1. IDs idênticos ao FreeNAS original (usando rid backend)
2. Sem dependência de realmd (menor "caixa preta")
3. Compatibilidade com scripts de migração existentes

---

## 4. Oportunidades de Melhoria

### 4.1 Separação de Datasets

O install-system atual cria apenas:

- `rpool/ROOT/debian`
- `rpool/home`
- `rpool/home/root`

**Recomendação:** Adicionar dataset dedicado para dados:

```bash
zfs create -o mountpoint=/srv/dados rpool/dados
```

**Benefícios:**

1. Snapshots independentes de sistema vs dados
2. Boot environments não afetam dados
3. Diferentes políticas de compressão (lz4 vs zstd)

### 4.2 Script de Migração Automatizado

Incluir script auxiliar `migrate-from-freenas.sh` que execute:

```bash
rsync -avPHAX --delete root@IP_FREENAS:/mnt/tank/dados/ /srv/dados/
```

**Nota:** Flags `-A` (ACLs) e `-X` (xattr) são críticas para preservar permissões.

### 4.3 Configuração de Logs

O install-system não configura rotação de logs do Samba. Adicionar:

- `/etc/logrotate.d/samba` customizado
- Configuração de log level no smb.conf

### 4.4 Hooks de ZFS

Considerar inclusão de scripts em `/etc/zfs/zed.d/` para:

- Notificações de falha de disco
- Snapshots automáticos (similar ao FreeNAS)

---

## 5. Inconsistências no Código Atual

### 5.1 Redundância de Pacotes

O [`package-list`](live_config/config/package-lists/live.list.chroot:91) inclui:

- `realmd`, `sssd`, `sssd-tools`
- `winbind`, `libnss-winbind`, `libpam-winbind`

**Problema:** Após decisão arquitetural (seção 3.2), metade desses pacotes será desnecessária.

### 5.2 ZFSBootMenu vs Secure Boot

O package-list inclui `shim-signed`, `mokutil`, mas o ZFSBootMenu EFI pode ter problemas com Secure Boot habilitado.

**Recomendação:** Documentar requisito de desabilitar Secure Boot ou usar MOK.

### 5.3 Pool Name Inconsistente

- NAS.md usa `tank`
- ISO Design usa `rpool`
- install-system usa `zroot`

**Recomendação:** Padronizar para `rpool` (convenção ZFS on Linux) ou permitir escolha no instalador.

---

## 6. Diagrama de Fluxo Recomendado

```mermaid
flowchart TD
    A[Boot ISO Live] --> B[install-system TUI]
    B --> C{Modo Boot}
    C -->|UEFI| D[Partição EFI 512MB]
    C -->|BIOS| E[Partição BIOS Boot 1MB]
    D --> F[Criar Pool ZFS]
    E --> F
    F --> G{RAID Level}
    G -->|Single| H[zpool create rpool /dev/sdX]
    G -->|Mirror| I[zpool create rpool mirror /dev/sdX /dev/sdY]
    G -->|RAIDZ1| J[zpool create rpool raidz1 disk1 disk2 disk3]
    H --> K[Criar Datasets]
    I --> K
    J --> K
    K --> L[rpool/ROOT/debian]
    K --> M[rpool/dados /srv/dados]
    L --> N[Extrair SquashFS]
    M --> N
    N --> O[Configurar no Chroot]
    O --> P[/etc/sysctl.d/99-nas.conf]
    O --> Q[/etc/samba/smb.conf]
    O --> R[/etc/krb5.conf]
    O --> S[Usuários/Senhas]
    P --> T[Instalar Bootloader]
    Q --> T
    R --> T
    S --> T
    T --> U[Concluir]
```

---

## 7. Checklist de Implementação

Para alinhar implementação com objetivo de replicação FreeNAS 9.10:

### Prioridade CRÍTICA

- [ ] Adicionar tuning de kernel no install-system
- [ ] Gerar smb.conf otimizado no install-system
- [ ] Configurar krb5.conf e nsswitch.conf
- [ ] Instalar e configurar NTP (chrony)

### Prioridade ALTA

- [ ] Implementar seleção múltipla de discos no install-system
- [ ] Oferecer opções de RAID (mirror, raidz1)
- [ ] Criar dataset separado para /srv/dados
- [ ] Decidir e implementar estratégia de ACLs (NFSv4 vs POSIX)

### Prioridade MÉDIA

- [ ] Script auxiliar de migração rsync
- [ ] Configuração logrotate Samba
- [ ] Hooks ZED para notificações
- [ ] Documentação de troubleshooting AD

### Prioridade BAIXA

- [ ] Suporte a VLANs na configuração de rede
- [ ] Integração com SNMP para monitoramento
- [ ] Dashboard web simples (alternativa ao FreeNAS GUI)

---

## 8. Conclusão

O design arquitetural do AURORA_ISO_DESIGN.md é **tecnicamente sólido** e representa uma base Debian pura bem projetada. No entanto, a implementação atual no `install-system` está **incompleta** em relação aos requisitos de replicação do FreeNAS 9.10.

### Pontos Fortes do Design

1. Uso do ZFSBootMenu para boot environments
2. Abordagem live-build pura (sem "gambiarras")
3. Estrutura de datasets ZFS bem pensada
4. Suporte a BIOS e UEFI (no guia)

### Pontos que Precisam de Atenção Imediata

1. **Gaps críticos de funcionalidade** (Samba, AD, tuning)
2. **Decisões arquiteturais pendentes** (ACLs, integração AD)
3. **RAID não implementado** no instalador

### Recomendação Final

Aprovar o design arquitetural com as seguintes condições:

1. **Adotar NFSv4 ACLs** para compatibilidade máxima com FreeNAS
2. **Usar Winbind puro** para replicação fiel da integração AD
3. **Implementar gaps críticos** antes de considerar o projeto "funcional"
4. **Documentar decisões** para futuras manutenções

O projeto tem potencial para superar o FreeNAS 9.10 em:

- **Transparência:** Tudo em arquivos de texto, sem SQLite
- **Atualizações:** Acesso a kernel/drivers mais recentes
- **Flexibilidade:** Base Debian pura, fácil de customizar

---

## Anexos

### A. Referências Cruzadas

| Requisito NAS.md | Status no ISO Design | Status no install-system |
|------------------|----------------------|--------------------------|
| ZFS + lz4        | Documentado          | Implementado             |
| xattr=sa         | Documentado          | Implementado             |
| Samba AD         | Documentado          | **Ausente**              |
| Kernel tuning    | Documentado          | **Ausente**              |
| RAID/Mirror      | Documentado          | **Ausente**              |
| realmd join      | Documentado          | **Ausente**              |
| ZFSBootMenu      | Documentado          | Implementado             |

### B. Comandos de Validação Recomendados

```bash
# Verificar tuning de kernel
cat /proc/sys/vm/swappiness
cat /proc/sys/net/core/rmem_max

# Verificar ACLs
zfs get acltype rpool/dados
zfs get xattr rpool/dados

# Verificar integração AD
wbinfo -t  # Teste trust
wbinfo -u  # Listar usuários
getent passwd "AURORANET\\usuario"

# Verificar Samba
smbclient -L localhost -U usuario
```

---

*Documento gerado durante revisão arquitetural - 2026-01-29*
