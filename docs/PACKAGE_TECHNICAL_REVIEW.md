# Relatório Técnico: Revisão Crítica da Lista de Pacotes AURORA NAS

**Data:** 2026-01-30  
**Objetivo:** Validação e otimização da lista de pacotes para NAS Debian Trixie  
**Referência:** [`live_config/config/package-lists/live.list.chroot`](live_config/config/package-lists/live.list.chroot:1)

---

## 1. Resumo Executivo

A lista de pacotes está **bem estruturada** e cobre os requisitos essenciais para paridade funcional com FreeNAS 9.10/TrueNAS SCALE. Foram identificados:

| Categoria | Quantidade |
|-----------|------------|
| 🐛 **DUPLICADOS** | 1 |
| 🔴 **CRÍTICO - Adicionar** | 3 |
| 🟡 **RECOMENDADO - Adicionar** | 6 |
| 🟢 **OPCIONAL - Considerar** | 5 |
| ⚪ **REMOVER** | 0 |

---

## 2. Achados por Categoria

### 2.1 [CRÍTICO] Pacotes Essenciais Faltando

#### 🔴 `libtirpc3` - Suporte a RPC moderno
```
# ADICIONAR:
libtirpc3
```
**Justificativa:** O Debian Trixie migrou o stack RPC para libtirpc. Sem este pacote, funcionalidades NFS podem falhar silenciosamente.

**Impacto:** Falhas em montagens NFS e exports.

---

#### 🔴 `keyutils` - Keyring persistente para Kerberos
```
# ADICIONAR:
keyutils
```
**Justificativa:** O keyutils é necessário para keyring persistente do Kerberos entre sessões. Sem ele, tickets Kerberos não persistem corretamente após logout.

**Impacto:** Autenticação AD instável, requer re-login frequente.

---

#### 🔴 `rpcbind` - Port mapper para NFS
```
# ADICIONAR:
rpcbind
```
**Justificativa:** Embora `nfs-common` traga algumas dependências, o `rpcbind` é necessário explícito para exports NFS server funcionarem corretamente.

**Impacto:** NFS server não inicia corretamente.

---

### 2.2 [RECOMENDADO] Melhorias Significativas

#### 🟡 `libnss-systemd` - Resolução de nomes via systemd
```
# ADICIONAR:
libnss-systemd
```
**Justificativa:** Permite resolução de nomes via systemd-resolved, essencial para integração DNS moderna e descoberta de domínio AD.

---

#### 🟡 `db-util` ou `db5.3-util` - Manipulação de databases
```
# ADICIONAR (um dos dois):
db-util
# ou
db5.3-util
```
**Justificativa:** Ferramentas para manipular os databases TDB do Samba quando necessário para troubleshooting avançado.

---

#### 🟡 `haveged` ou `rng-tools5` - Gerador de entropia
```
# ADICIONAR (escolher um):
haveged
# ou
rng-tools5
```
**Justificativa:** Servidores virtuais e alguns hardwares físicos têm baixa entropia. Isso afeta a geração de chaves Kerberos, TLS e ZFS encryption.

**Preferência:** `haveged` é mais simples; `rng-tools5` é mais moderno e eficiente.

---

#### 🟡 `debian-security-support` - Verificação de segurança
```
# ADICIONAR:
debian-security-support
```
**Justificativa:** Ferramenta que verifica se há pacotes instalados com vulnerabilidades conhecidas não corrigidas.

---

#### 🟡 `lsscsi` - Listagem de dispositivos SCSI/SATA
```
# ADICIONAR:
lsscsi
```
**Justificativa:** Mais confiável que `ls /dev/sd*` para identificar drives conectados via diferentes controladoras.

---

#### 🟡 `netcat-openbsd` - Ferramenta de rede
```
# ADICIONAR:
netcat-openbsd
```
**Justificativa:** Versátil para testes de conectividade, troubleshooting Samba/AD ports, e scripts de automação.

---

### 2.3 [OPCIONAL] Nice to Have

#### 🟢 `mc` - Midnight Commander
```
# OPCIONAL:
mc
```
**Justificativa:** Gerenciador de arquivos TUI que facilita navegação em sistema live/recovery.

---

#### 🟢 `sg3-utils` - Utilitários SCSI genéricos
```
# OPCIONAL:
sg3-utils
```
**Justificativa:** Ferramentas avançadas para controle de dispositivos SCSI/SATA. Útil para troubleshooting de HBAs.

---

#### 🟢 `ledmon` - Monitoramento de LEDs Intel
```
# OPCIONAL:
ledmon
```
**Justificativa:** Se o hardware usar controladoras Intel RAID, este pacote gerencia os LEDs de status dos drives.

---

#### 🟢 `partclone` - Clonagem de partições
```
# OPCIONAL:
partclone
```
**Justificativa:** Mais eficiente que `dd` para clonagem de partições específicas, preservando filesystems.

---

#### 🟢 `gddrescue` - Recuperação de dados
```
# OPCIONAL:
gddrescue
```
**Justificativa:** Ferramenta especializada para recuperação de dados de drives com bad sectors.

---

### 2.4 [CORRIGIR] Duplicados

#### ⚠️ `pv` - Duplicado nas linhas 115 e 147
```
# LINHA 115:
pv

# LINHA 147 (REMOVER - duplicado):
pv
```
**Ação:** Remover uma das ocorrências.

---

## 3. Análise por Stack

### 3.1 ZFS Stack - ✅ COMPLETO

| Componente | Status | Pacote |
|------------|--------|--------|
| Módulos DKMS | ✅ | `zfs-dkms` |
| Utilitários | ✅ | `zfsutils-linux` |
| Initramfs | ✅ | `zfs-initramfs` |
| Event Daemon | ✅ | `zfs-zed` |
| Snapshots Auto | ✅ | `zfs-auto-snapshot` |

**Avaliação:** Stack ZFS está completo e adequado para paridade com FreeNAS.

---

### 3.2 Active Directory - ✅ COMPLETO

| Componente | Status | Pacote(s) |
|------------|--------|-----------|
| Ingresso Domínio | ✅ | `realmd`, `adcli` |
| Autenticação | ✅ | `sssd`, `sssd-tools` |
| Mapeamento IDs | ✅ | `winbind`, `libnss-winbind`, `libpam-winbind` |
| Kerberos | ✅ | `krb5-user`, `krb5-config` |
| Debug | ✅ | `ldap-utils`, `ldb-tools`, `tdb-tools` |
| Dependências | ✅ | `packagekit` |

**Nota:** O `libpam-smbpass` foi corretamente removido (descontinuado no Samba 4).

**Recomendação:** Adicionar `keyutils` para keyring persistente de Kerberos.

---

### 3.3 Samba NAS - ✅ COMPLETO

| Componente | Status | Pacote |
|------------|--------|--------|
| Servidor SMB | ✅ | `samba` |
| Ferramentas Admin | ✅ | `samba-common-bin` |
| VFS Modules | ✅ | `samba-vfs-modules` |
| DSDB Modules | ✅ | `samba-dsdb-modules` |
| Mount CIFS | ✅ | `cifs-utils` |

**Avaliação:** A inclusão de `samba-vfs-modules` é **crítica** para compatibilidade ZFS ACLs (vfs_acl_xattr, vfs_shadow_copy).

---

### 3.4 Infraestrutura - ✅ ADEQUADO

| Componente | Status | Pacote |
|------------|--------|--------|
| NTP | ✅ | `chrony` |
| DNS Tools | ✅ | `dnsutils`, `bind9-host` |
| Tuning Rede | ✅ | `ethtool` |
| Performance | ✅ | `irqbalance` |
| Device Naming | ✅ | `sysfsutils` |

**Nota:** A escolha de `chrony` sobre `ntpd` é correta para Debian moderno.

---

### 3.5 Firmware - ✅ ADEQUADO

| Categoria | Cobertura |
|-----------|-----------|
| Base | ✅ `firmware-linux`, `firmware-linux-nonfree` |
| NICs Realtek | ✅ `firmware-realtek` |
| NICs Intel WiFi | ✅ `firmware-iwlwifi` |
| NICs Broadcom | ✅ `firmware-bnx2`, `firmware-bnx2x` |
| HBAs QLogic | ✅ `firmware-qlogic` |
| Outros | ✅ `firmware-atheros`, `firmware-libertas`, `firmware-misc-nonfree` |

**Recomendação:** Considerar `firmware-ralink` se houver uso de hardware Ralink/Mediatek.

---

## 4. Mudanças de Nome no Debian Trixie

| Pacote Antigo | Pacote Novo | Status na Lista |
|---------------|-------------|-----------------|
| `mlocate` | `plocate` | ✅ Correto |
| `ntp` | `chrony`/`ntpsec` | ✅ Correto (chrony) |
| `libpam-smbpass` | *(removido)* | ✅ Correto (removido) |
| `wireless-tools` | `iw` | ✅ Correto (iw presente) |
| `netcat-traditional` | `netcat-openbsd` | ⚠️ Recomendar adicionar |

---

## 5. Recomendações de Ajuste

### 5.1 Correção Imediata

```diff
# Remover duplicado (linha 147):
- pv

# Adicionar pacotes CRÍTICOS:
+ libtirpc3
+ keyutils
+ rpcbind
```

### 5.2 Melhorias Recomendadas

```diff
# Adicionar pacotes RECOMENDADOS:
+ libnss-systemd
+ db-util
+ haveged
+ debian-security-support
+ lsscsi
+ netcat-openbsd
```

### 5.3 Considerações Opcionais

```diff
# Adicionar se espaço permitir:
+ mc
+ sg3-utils
+ ledmon
+ partclone
+ gddrescue
```

---

## 6. Matriz de Compatibilidade FreeNAS/TrueNAS

| Funcionalidade | FreeNAS 9.10 | TrueNAS SCALE | AURORA (Atual) | AURORA (Pós Correções) |
|----------------|--------------|---------------|----------------|------------------------|
| ZFS RAIDZ/Mirror | ✅ | ✅ | ✅ | ✅ |
| ZFS Auto Snapshots | ✅ | ✅ | ✅ | ✅ |
| SMB com ACLs | ✅ | ✅ | ✅ | ✅ |
| Integração AD | ✅ | ✅ | ✅ | ✅ |
| NFS v4 ACLs | ✅ | ✅ | ✅ | ✅* |
| NTP Sync | ✅ | ✅ | ✅ | ✅ |
| iSCSI Initiator | ✅ | ✅ | ✅ | ✅ |
| SNMP | ✅ | ✅ | ✅ | ✅ |
| Multi-filesystem | ✅ | ✅ | ✅ | ✅ |
| SSH Server | ✅ | ✅ | ✅ | ✅ |

*Após adicionar `libtirpc3` e `rpcbind`

---

## 7. Checklist de Validação

Após aplicar as correções, validar:

```bash
# ZFS
zpool version
zfs version
zfs-auto-snapshot --help

# RPC/NFS
rpcinfo -p localhost

# Kerberos
kinit --version
keyctl list @s

# Samba
smbd --version
testparm -v

# AD
wbinfo -V
realm --version
sssd --version

# Hardware
lsscsi
nvme version
smartctl --version
```

---

## 8. Conclusão

A lista de pacotes AURORA NAS está **bem estruturada** e atinge a paridade funcional desejada com FreeNAS 9.10/TrueNAS SCALE.

### Pontos Fortes:
- ✅ Stack ZFS completo com auto-snapshot
- ✅ Samba VFS modules incluídos
- ✅ Stack Active Directory completo
- ✅ `libpam-smbpass` corretamente removido
- ✅ `plocate` atualizado para Trixie

### Ações Necessárias:
1. **Remover** duplicado `pv`
2. **Adicionar** 3 pacotes CRÍTICOS (`libtirpc3`, `keyutils`, `rpcbind`)
3. **Considerar** 6 pacotes RECOMENDADOS para robustez

### Tamanho Estimado Pós-Correções:
- Adição: ~5-10 MB (pacotes pequenos)
- Impacto mínimo no tamanho total da ISO (~1.6 GB)

---

*Documento gerado para validação técnica da infraestrutura AURORA NAS*
