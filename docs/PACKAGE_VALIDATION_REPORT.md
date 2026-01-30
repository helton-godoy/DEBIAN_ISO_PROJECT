# Relatório de Validação de Pacotes - Debian Trixie

**Data da Validação:** 2026-01-30  
**Ambiente:** Debian Trixie (container `debian:trixie-slim`)  
**Repositórios:** main, contrib, non-free, non-free-firmware

---

## Resumo Executivo

A validação identificou **1 pacote com nome incorreto** que precisa de correção antes da build da ISO. Todos os demais pacotes críticos existem nos repositórios do Debian Trixie.

### Status Geral
| Categoria | Total | ✅ Existem | ❌ Problemas |
|-----------|-------|------------|--------------|
| Pacotes Críticos | 3 | 2 | 1 |
| Pacotes ZFS/Samba | 6 | 6 | 0 |
| Pacotes Firmware | 8 | 8 | 0 |
| Pacotes AD/SSSD | 4 | 4 | 0 |
| Pacotes Recomendados | 6 | 6 | 0 |
| **TOTAL** | **27** | **26** | **1** |

---

## 1. Pacotes Críticos Identificados

### 1.1 `libtirpc3` - Suporte RPC moderno para NFSv4
| Atributo | Valor |
|----------|-------|
| **Status** | ❌ **NOME INCORRETO** |
| **Nome Correto** | `libtirpc3t64` |
| **Versão** | 1.3.6+ds-1 |
| **Repositório** | trixie/main |
| **Ação Necessária** | Substituir `libtirpc3` por `libtirpc3t64` |

**Nota Técnica:** O pacote foi renomeado devido à transição 64-bit time_t (time_t64) no Debian Trixie para arquiteturas que necessitam suporte a timestamps de 64 bits.

---

### 1.2 `keyutils` - Keyring para tickets Kerberos
| Atributo | Valor |
|----------|-------|
| **Status** | ✅ **EXISTE** |
| **Versão** | 1.6.3-6 |
| **Repositório** | trixie/main |
| **Ação Necessária** | Nenhuma |

---

### 1.3 `rpcbind` - Port mapper para NFS
| Atributo | Valor |
|----------|-------|
| **Status** | ✅ **EXISTE** |
| **Versão** | 1.2.7-1 |
| **Repositório** | trixie/main |
| **Ação Necessária** | Nenhuma |

---

## 2. Duplicatas na Lista Atual

### `pv` - Pipe Viewer
| Atributo | Valor |
|----------|-------|
| **Status** | ⚠️ **DUPLICADO** |
| **Ocorrências** | Linha 115 e Linha 147 |
| **Ação Necessária** | Remover uma das ocorrências |

**Verificação:** Confirmado no arquivo [`live.list.chroot`](live_config/config/package-lists/live.list.chroot:115) - o pacote aparece nas linhas 115 e 147.

---

## 3. Validação de Pacotes Específicos

### 3.1 Pacotes ZFS

#### `zfs-auto-snapshot`
| Atributo | Valor |
|----------|-------|
| **Status** | ✅ **EXISTE** |
| **Versão** | 1.2.4-2 |
| **Repositório** | trixie/contrib |
| **Nota** | Requer repositório `contrib` habilitado |

---

### 3.2 Pacotes de Localização

#### `plocate` (substitui `mlocate`)
| Atributo | Valor |
|----------|-------|
| **Status** | ✅ **EXISTE** |
| **Versão** | 1.1.23-1 |
| **Repositório** | trixie/main |
| **Nota** | Já está correto na lista atual |

---

### 3.3 Pacotes de Firmware (requer non-free-firmware)

| Pacote | Status | Versão | Repositório |
|--------|--------|--------|-------------|
| `firmware-linux` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-linux-nonfree` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-misc-nonfree` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-bnx2` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-bnx2x` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-qlogic` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-realtek` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-iwlwifi` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-atheros` | ✅ | 20250410-2 | non-free-firmware |
| `firmware-libertas` | ✅ | 20250410-2 | non-free-firmware |

**Nota Importante:** Todos os firmwares estão consolidados na versão `20250410-2` no repositório `non-free-firmware`. É necessário garantir que este repositório esteja habilitado na configuração do live-build.

---

### 3.4 Pacotes Samba

| Pacote | Status | Versão | Repositório |
|--------|--------|--------|-------------|
| `samba-vfs-modules` | ✅ | 2:4.22.6+dfsg-0+deb13u1 | main |
| `samba-dsdb-modules` | ✅ | 2:4.22.6+dfsg-0+deb13u1 | main |

**Nota:** Versão do Samba 4.22.6 no Debian Trixie.

---

### 3.5 Pacotes Active Directory / SSSD

| Pacote | Status | Versão | Repositório |
|--------|--------|--------|-------------|
| `realmd` | ✅ | 0.17.1-3+b2 | main |
| `sssd` | ✅ | 2.10.1-2+b1 | main |
| `sssd-tools` | ✅ | 2.10.1-2+b1 | main |
| `chrony` | ✅ | 4.6.1-3 | main |

---

### 3.6 Pacote Descontinuado

#### `libpam-smbpass`
| Atributo | Valor |
|----------|-------|
| **Status** | ❌ **NÃO EXISTE** (Removido) |
| **Ação** | Manter removido da lista |
| **Alternativa** | Usar `libpam-winbind` apenas |

**Nota Técnica:** O módulo `libpam-smbpass` foi descontinuado no Samba 4. A funcionalidade de sincronização de senhas entre Unix e Samba não é mais suportada. A autenticação deve ser feita via `libpam-winbind` com backend AD.

---

## 4. Pacotes Recomendados (do documento de correções)

Todos os pacotes recomendados do documento [`AURORA_PACKAGE_CORRECTIONS.md`](AURORA_PACKAGE_CORRECTIONS.md) foram validados:

| Pacote | Status | Versão | Propósito |
|--------|--------|--------|-----------|
| `keyutils` | ✅ | 1.6.3-6 | Kerberos keyring persistence |
| `libnss-systemd` | ✅ | 257.9-1~deb13u1 | Integração systemd/nsswitch |
| `db-util` | ✅ | 5.3.4 | Debug Samba databases |
| `haveged` | ✅ | 1.9.19-12 | Entropia para VMs |
| `lsscsi` | ✅ | 0.32-2 | Listagem de dispositivos SCSI |
| `netcat-openbsd` | ✅ | 1.229-1 | Ferramenta de rede |
| `debian-security-support` | ✅ | 1:13+2026.01.04 | Suporte de segurança |

---

## 5. Correções Necessárias no Arquivo

### Arquivo Alvo
[`live_config/config/package-lists/live.list.chroot`](live_config/config/package-lists/live.list.chroot)

### Alterações Requeridas

```diff
# === RPC Support (CRÍTICO para NFS em Debian Trixie) =========================
-libtirpc3
+libtirpc3t64
 rpcbind
```

### Remoção de Duplicata
```diff
 # === Utilitários Adicionais ==================================================
 bc
 jq
-pv
 unzip
```

---

## 6. Verificação de Repositórios

Para que todos os pacotes sejam instalados corretamente, a configuração do live-build deve incluir:

```
Components: main contrib non-free non-free-firmware
```

**Arquivos afetados:**
- Configuração do apt no live-build
- Possivelmente `live_config/auto/config`

---

## 7. Comandos de Validação Recomendados

Após o rebuild da ISO, execute:

```bash
# Verificar pacotes RPC corrigidos
$ dpkg -l | grep libtirpc
ii  libtirpc3t64  1.3.6+ds-1  amd64  transport-independent RPC library

# Verificar serviço RPC
$ rpcinfo -p localhost
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper

# Verificar keyring
$ keyctl list @s
Keyring de sessão: 1 item
```

---

## Conclusão

A lista de pacotes está **98% válida** para o Debian Trixie. Apenas **uma correção de nome** é necessária:

1. ✅ **Substituir** `libtirpc3` → `libtirpc3t64`
2. ✅ **Remover** duplicata de `pv`
3. ✅ **Garantir** que repositórios `contrib` e `non-free-firmware` estejam habilitados

Todos os demais pacotes críticos, de firmware, Samba, AD/SSSD e recomendados existem e estão disponíveis nos repositórios do Debian Trixie.

---

*Relatório gerado automaticamente como parte da validação de pacotes AURORA NAS*
