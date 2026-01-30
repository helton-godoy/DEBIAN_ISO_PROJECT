# Correções Recomendadas para Lista de Pacotes AURORA

**Arquivo Alvo:** [`live_config/config/package-lists/live.list.chroot`](live_config/config/package-lists/live.list.chroot:1)

---

## Resumo das Correções

### 1. Remover Duplicado
- **Linha 147:** Remover `pv` (já existe na linha 115)

### 2. Adicionar Pacotes CRÍTICOS

```
# === RPC Support (CRÍTICO para NFS em Debian Trixie) =========================
libtirpc3
rpcbind
```

Local sugerido: Após a seção "ZFS Support Completo"

### 3. Adicionar Pacotes RECOMENDADOS

```
# === Kerberos Keyring Persistence (RECOMENDADO para AD) ======================
keyutils
libnss-systemd

# === Database Tools (RECOMENDADO para debug Samba) ===========================
db-util

# === Entropia para VMs (RECOMENDADO para Kerberos/TLS) =======================
haveged

# === Ferramentas Adicionais (RECOMENDADO) ====================================
lsscsi
netcat-openbsd
debian-security-support
```

---

## Arquivo Corrigido Completo

Abaixo está a lista completa com todas as correções aplicadas:

```
# =============================================================================
# AURORA NAS - Package List para Debian ZFS Live ISO
# Objetivo: Paridade funcional com FreeNAS 9.10 / TrueNAS SCALE
# =============================================================================

# === Extração do Sistema =====================================================
squashfs-tools

# === Particionamento & Boot ==================================================
gdisk
parted
dosfstools
efibootmgr

# === Live System Base ========================================================
live-boot
live-config
live-config-systemd

# Secure Boot Support
shim-signed
mokutil
sbsigntool

# === Kernel & Módulos =========================================================
linux-image-amd64
linux-headers-amd64
initramfs-tools
dkms

# === Firmware (CRÍTICO para Hardware Real) ===================================
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree
firmware-realtek
firmware-iwlwifi
firmware-atheros
firmware-libertas
firmware-bnx2
firmware-bnx2x
firmware-qlogic

# === ZFS Support Completo ====================================================
zfs-dkms
zfsutils-linux
zfs-initramfs
zfs-zed
zfs-auto-snapshot

# === RPC Support (CRÍTICO para NFS em Debian Trixie) =========================
libtirpc3
rpcbind

# === NFS v4 ACLs & Compatibilidade FreeNAS ===================================
nfs4-acl-tools
nfs-common
acl
attr

# === Samba NAS Corporativo ===================================================
samba
samba-common-bin
samba-vfs-modules
samba-dsdb-modules
winbind
libnss-winbind
libpam-winbind
# NOTA: libpam-smbpass removido - pacote descontinuado no Samba 4 (Debian Trixie)
cifs-utils

# === Integração Active Directory (realmd/sssd + winbind) =====================
realmd
sssd
sssd-tools
adcli
packagekit
krb5-user
krb5-config
ldap-utils
ldb-tools
tdb-tools

# === Kerberos Keyring Persistence (RECOMENDADO para AD) ======================
keyutils
libnss-systemd

# === Infraestrutura Essencial (NTP, DNS, Rede) ===============================
chrony
dnsutils
bind9-host
ethtool
irqbalance
sysfsutils

# === Database Tools (RECOMENDADO para debug Samba) ===========================
db-util

# === Network Manager & Wi-Fi =================================================
network-manager
wpasupplicant
iw

# === Diagnóstico de Rede & Performance =======================================
tcpdump
iperf3
nload

# === Ferramentas de Sistema & Administração ==================================
bash-completion
sudo
tzdata
locales
kexec-tools
ca-certificates
openssl
openssh-server
openssh-client
curl
wget
rsync
perl
zstd
pigz
ncdu
tree
pv

# === Debian Tools ============================================================
debootstrap
dpkg-dev
debian-archive-keyring
apt-utils

# === Hardware Monitoring & Diagnóstico =======================================
smartmontools
lm-sensors
pciutils
usbutils
lsof
hdparm
sdparm
nvme-cli

# === Ferramentas de Recuperação & Debug ======================================
gum
htop
screen
nano
vim-tiny
console-setup
keyboard-configuration
strace
ltrace

# === Utilitários Adicionais ==================================================
bc
jq
unzip
xz-utils
bzip2
gzip
tar
less
man-db
uuid-runtime
whois
logrotate
# NOTA: plocate substitui mlocate (Debian Trixie)
plocate

# === Entropia para VMs (RECOMENDADO para Kerberos/TLS) =======================
haveged

# === Sistema de Arquivos Adicionais (para compatibilidade) ===================
e2fsprogs
xfsprogs
btrfs-progs
ntfs-3g
exfat-fuse
exfatprogs
hfsprogs
jfsutils
reiserfsprogs

# === ISCSI Initiator (se necessário para storage externo) ====================
open-iscsi

# === SNMP (para monitoramento) ===============================================
snmp
snmpd
libsnmp-base

# === Ferramentas Adicionais (RECOMENDADO) ====================================
lsscsi
netcat-openbsd
debian-security-support

# === Postfix (null client para notificações por email) =======================
# postfix (descomente se precisar de notificações por email)
```

---

## Diff das Alterações

```diff
--- a/live_config/config/package-lists/live.list.chroot
+++ b/live_config/config/package-lists/live.list.chroot
@@ -46,6 +46,10 @@ zfsutils-linux
 zfs-initramfs
 zfs-zed
 zfs-auto-snapshot
+
+# === RPC Support (CRÍTICO para NFS em Debian Trixie) =========================
+libtirpc3
+rpcbind
 
 # === NFS v4 ACLs & Compatibilidade FreeNAS ===================================
 nfs4-acl-tools
@@ -75,6 +79,10 @@ ldap-utils
 ldb-tools
 tdb-tools
 
+# === Kerberos Keyring Persistence (RECOMENDADO para AD) ======================
+keyutils
+libnss-systemd
+
 # === Infraestrutura Essencial (NTP, DNS, Rede) ===============================
 chrony
 dnsutils
@@ -83,6 +91,10 @@ ethtool
 irqbalance
 sysfsutils
 
+# === Database Tools (RECOMENDADO para debug Samba) ===========================
+db-util
+
 # === Network Manager & Wi-Fi =================================================
 network-manager
 wpasupplicant
@@ -140,9 +152,8 @@ strace
 ltrace
 
 # === Utilitários Adicionais ==================================================
 bc
 jq
-pv
 unzip
 xz-utils
 bzip2
@@ -156,6 +167,10 @@ logrotate
 # NOTA: plocate substitui mlocate (Debian Trixie)
 plocate
 
+# === Entropia para VMs (RECOMENDADO para Kerberos/TLS) =======================
+haveged
+
 # === Sistema de Arquivos Adicionais (para compatibilidade) ===================
 e2fsprogs
 xfsprogs
@@ -176,3 +191,8 @@ open-iscsi
 snmp
 snmpd
 libsnmp-base
+
+# === Ferramentas Adicionais (RECOMENDADO) ====================================
+lsscsi
+netcat-openbsd
+debian-security-support
```

---

## Notas de Implementação

1. **Ordem dos Pacotes:** Mantenha a organização por seções para facilitar manutenção
2. **Comentários:** Use comentários para documentar mudanças significativas
3. **Dependências:** O APT resolverá automaticamente dependências adicionais
4. **Tamanho:** As adições aumentam o tamanho da ISO em aproximadamente 5-10 MB

---

## Validação Após Aplicação

Execute após rebuild da ISO:

```bash
# Verificar pacotes CRÍTICOS
dpkg -l | grep -E "(libtirpc3|keyutils|rpcbind)"

# Verificar pacotes RECOMENDADOS
dpkg -l | grep -E "(libnss-systemd|db-util|haveged|lsscsi|netcat-openbsd|debian-security-support)"

# Testar funcionalidades
rpcinfo -p localhost        # Deve mostrar serviços RPC
keyctl list @s              # Deve mostrar keyring
haveged --version           # Deve mostrar versão
```

---

*Arquivo gerado como parte da Revisão Técnica de Pacotes AURORA NAS*
