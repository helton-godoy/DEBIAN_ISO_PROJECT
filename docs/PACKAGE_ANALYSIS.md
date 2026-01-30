# Análise de Pacotes: AURORA NAS Package List

**Data:** 2026-01-29  
**Objetivo:** Paridade funcional completa com FreeNAS 9.10 e TrueNAS SCALE

---

## 1. Resumo das Mudanças

O arquivo [`live_config/config/package-lists/live.list.chroot`](live_config/config/package-lists/live.list.chroot:1) foi expandido de **103 pacotes** para aproximadamente **140+ pacotes**, organizados em categorias funcionais.

---

## 2. Pacotes Adicionados por Categoria

### 2.1 ZFS Avançado & Snapshots Automáticos

```
zfs-auto-snapshot
```

**Justificativa:**

- FreeNAS 9.10 tinha snapshots automáticos configuráveis via GUI
- TrueNAS SCALE usa similar mecanismo
- `zfs-auto-snapshot` é a ferramenta Debian padrão para políticas de snapshot
- Cria snapshots com retenção (frequent, hourly, daily, weekly, monthly)

---

### 2.2 NFS v4 ACLs - Compatibilidade FreeNAS

```
nfs-common
```

**Justificativa:**

- `nfs4-acl-tools` já estava incluído (bom!)
- `nfs-common` adiciona ferramentas básicas de NFS (showmount, etc.)
- Essencial se houver necessidade de exportar NFS além de SMB
- Compatibilidade com montagens NFS de storage externo

---

### 2.3 Samba NAS Corporativo - Módulos Essenciais

```
samba-common-bin
samba-vfs-modules
samba-dsdb-modules
# libpam-smbpass - REMOVIDO: Descontinuado no Samba 4 (Debian Trixie+)
cifs-utils
```

**Justificativa:**

**⚠️ Nota sobre libpam-smbpass:**
Este pacote foi **removido** no Debian Trixie pois foi descontinuado upstream no Samba 4.
A funcionalidade de sincronização de senhas SMB/Linux agora é tratada de forma diferente
via `libpam-winbind` e configurações no `smb.conf`:
```
pam password change = yes
passwd program = /usr/bin/passwd %u
passwd chat = *Enter*new*password* %n\n *Retype*new*password* %n\n *password*updated*
```

| Pacote               | Função                                     | Necessidade                                     |
| -------------------- | ------------------------------------------ | ----------------------------------------------- |
| `samba-common-bin`   | testparm, smbpasswd, net, pdbedit          | Diagnóstico e administração                     |
| `samba-vfs-modules`  | vfs_acl_xattr, vfs_zfsacl, vfs_shadow_copy | **CRÍTICO** - Otimizações de performance e ACLs |
| `samba-dsdb-modules` | Módulos de banco de dados Samba            | Suporte a AD como membro                        |
| `libpam-smbpass`     | Sincronização senhas SMB/Linux             | **REMOVIDO** - Descontinuado no Samba 4        |
| `cifs-utils`         | mount.cifs                                 | Montar shares remotos para migração             |

**Nota sobre VFS Modules:**
O FreeNAS 9.10 usava extensivamente módulos VFS para:

- `acl_xattr` ou `zfsacl` - ACLs nativas ZFS
- `shadow_copy` - Previous Versions do Windows
- `streams_xattr` - Alternate Data Streams

---

### 2.4 Active Directory - Stack Completo Kerberos

```
krb5-user
krb5-config
ldap-utils
ldb-tools
tdb-tools
```

**Justificativa:**

| Pacote        | Função                          | Crítico?                        |
| ------------- | ------------------------------- | ------------------------------- |
| `krb5-user`   | kinit, klist, kdestroy, kpasswd | **SIM** - Autenticação Kerberos |
| `krb5-config` | Configuração base do Kerberos   | **SIM**                         |
| `ldap-utils`  | ldapsearch, ldapwhoami          | Troubleshooting AD/DNS          |
| `ldb-tools`   | ldbsearch, ldbmodify            | Debug banco Samba               |
| `tdb-tools`   | tdbdump, tdbbackup              | Manipulação caches TDB          |

**Observação:** Sem `krb5-user`, não é possível:

- Obter tickets Kerberos (kinit)
- Verificar autenticação (klist)
- Ingressar no domínio via winbind

---

### 2.5 Infraestrutura - NTP, DNS, Rede

```
chrony
dnsutils
bind9-host
ethtool
irqbalance
sysfsutils
```

**Justificativa:**

| Pacote       | Função                     | Obrigatório?                         |
| ------------ | -------------------------- | ------------------------------------ |
| `chrony`     | Sincronização de tempo NTP | **SIM** - Kerberos requer sync <5min |
| `dnsutils`   | dig, nslookup              | Troubleshooting DNS                  |
| `bind9-host` | Comando host               | Diagnóstico rápido                   |
| `ethtool`    | Configuração avançada NIC  | Tuning de rede                       |
| `irqbalance` | Distribuição interrupções  | Performance multi-core               |
| `sysfsutils` | Persistent device naming   | Estabilidade ZFS                     |

**Por que chrony e não ntpd?**

- chrony é mais moderno e preciso
- Usado por RHEL 8+, Fedora, Ubuntu
- Melhor para VMs (ajusta clock rápido após suspend)
- Menor consumo de memória

---

### 2.6 Diagnóstico de Rede & Performance

```
tcpdump
iperf3
nload
```

**Justificativa:**

- `tcpdump` - Captura de pacotes para troubleshooting Samba/AD
- `iperf3` - Teste de throughput de rede (validar tuning)
- `nload` - Monitoramento em tempo real de interfaces

---

### 2.7 Ferramentas de Sistema Adicionais

```
openssh-server
openssh-client
tree
ncdu
pv
jq
```

**Justificativa:**

- `openssh-server` - Acesso remoto essencial para NAS headless
- `ncdu` - Análise de uso de disco (mais intuitivo que du)
- `pv` - Monitoramento de progresso (útil para rsync grandes)
- `jq` - Processamento JSON (para scripts de automação)
- `plocate` - Localização de arquivos (substitui `mlocate` no Debian Trixie)

---

### 2.8 Hardware & Storage Avançado

```
firmware-bnx2
firmware-bnx2x
firmware-qlogic
hdparm
sdparm
nvme-cli
```

**Justificativa:**

- Firmware adicional para NICs Broadcom e HBAs QLogic (comum em servidores)
- `hdparm`/`sdparm` - Configuração avançada de discos
- `nvme-cli` - Gerenciamento de SSDs NVMe (increasingly common)

---

### 2.9 Compatibilidade de Sistemas de Arquivos

```
e2fsprogs
xfsprogs
btrfs-progs
ntfs-3g
exfat-fuse
exfatprogs
hfsprogs
jfsutils
reiserfsprogs
```

**Justificativa:**

- FreeNAS 9.10 suportava importação de vários FS
- Útil para:
  - Migrar dados de discos externos
  - Montar mídia de backup
  - Recuperação de dados
- `ntfs-3g` e `exfat` essenciais para mídia USB Windows

---

### 2.10 ISCSI Initiator

```
open-iscsi
```

**Justificativa:**

- FreeNAS 9.10 podia atuar como iSCSI target
- TrueNAS SCALE mantém suporte iSCSI
- `open-iscsi` permite conectar a storage SAN externo
- Opcional mas recomendado para datacenter

---

### 2.11 SNMP para Monitoramento

```
snmp
snmpd
libsnmp-base
```

**Justificativa:**

- FreeNAS 9.10 tinha suporte SNMP para monitoramento
- Essencial para integração com:
  - Zabbix
  - Nagios
  - PRTG
  - LibreNMS

---

### 2.12 Utilitários de Debug

```
strace
ltrace
```

**Justificativa:**

- Troubleshooting avançado de problemas Samba/Winbind
- `strace -p $(pgrep winbindd)` para diagnosticar hangs

---

### 2.13 Pacotes Removidos

```
# REMOVIDOS:
syslinux          # Redundante com GRUB + ZFSBootMenu
wireless-tools    # Obsoleto, iw é suficiente
```

**Justificativa:**

- `syslinux`: Não necessário pois usamos ZFSBootMenu EFI
- `wireless-tools`: Comandos `iwconfig` obsoletos, `iw` substitui

---

## 3. Matriz de Comparação com FreeNAS 9.10 / TrueNAS SCALE

| Funcionalidade     | FreeNAS 9.10 | TrueNAS SCALE | AURORA (pós mudanças)           |
| ------------------ | ------------ | ------------- | ------------------------------- |
| ZFS RAIDZ/Mirror   | Sim          | Sim           | **Sim** (zfsutils-linux)        |
| ZFS Snapshots Auto | Sim          | Sim           | **Sim** (zfs-auto-snapshot)     |
| SMB com ACLs       | Sim          | Sim           | **Sim** (samba-vfs-modules)     |
| Integração AD      | Sim          | Sim           | **Sim** (krb5, winbind, realmd) |
| NFS v4 ACLs        | Sim          | Sim           | **Sim** (nfs4-acl-tools)        |
| NTP Sync           | Sim          | Sim           | **Sim** (chrony)                |
| iSCSI              | Sim (target) | Sim           | **Sim** (open-iscsi initiator)  |
| SNMP               | Sim          | Sim           | **Sim** (snmpd)                 |
| Multi-filesystem   | Sim          | Sim           | **Sim** (ext/xfs/ntfs/etc)      |
| SSH Server         | Sim          | Sim           | **Sim** (openssh-server)        |

---

## 4. Pacotes Ponderados mas Não Incluídos

### 4.1 AFP (Apple Filing Protocol)

```
# NÃO INCLUÍDO:
netatalk
avahi-daemon
```

**Motivo:** Apple depreciou AFP em favor de SMB2/3. TrueNAS SCALE removeu suporte AFP.

### 4.2 WebDAV

```
# NÃO INCLUÍDO:
apache2
libapache2-mod-dav
```

**Motivo:** Pode ser adicionado via container se necessário.

### 4.3 UPS (Nobreak)

```
# NÃO INCLUÍDO:
nut-client
nut-server
```

**Motivo:** Recomendado instalar conforme necessidade específica de hardware.

---

## 5. Validação Pós-Instalação

Após instalação, verificar disponibilidade dos comandos críticos:

```bash
# ZFS
zpool --version
zfs --version
zfs-auto-snapshot --help

# ACLs NFSv4
nfs4_getfacl --help
nfs4_setfacl --help

# Samba
smbd --version
testparm -v
net ads info  # Após ingressar no domínio

# Kerberos
kinit --version
klist --version

# AD
wbinfo -V
realm --version
sssd --version

# NTP
chronyc --version
chronyc tracking

# Rede
dig --version
ethtool --version

# Hardware
smartctl --version
nvme --version
```

---

## 6. Tamanho Estimado da ISO

| Componente             | Tamanho Aproximado |
| ---------------------- | ------------------ |
| Base Debian Trixie     | ~800 MB            |
| Kernel + Firmware      | ~400 MB            |
| ZFS Stack              | ~200 MB            |
| Samba + AD Stack       | ~150 MB            |
| Ferramentas adicionais | ~100 MB            |
| **Total Estimado**     | **~1.6 GB**        |

**Nota:** Tamanho compatível com DVDs e pendrives modernos.

---

## 7. Referências

1. [TrueNAS SCALE Documentation - Samba](https://www.truenas.com/docs/scale/scaletutorials/shares/)
2. [Debian ZFS Wiki](https://wiki.debian.org/ZFS)
3. [Samba VFS Modules](https://www.samba.org/samba/docs/current/man-html/vfs_acl_xattr.8.html)
4. [Chrony vs NTP](https://chrony.tuxfamily.org/comparison.html)
5. [FreeNAS 9.10 Documentation Archive](https://www.ixsystems.com/documentation/freenas/9.10/freenas.html)

---

_Documento gerado para garantir paridade funcional com FreeNAS 9.10 e TrueNAS SCALE_
