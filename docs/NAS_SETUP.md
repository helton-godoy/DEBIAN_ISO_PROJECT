# Guia de Implementação: Servidor NAS AURORA (Debian + ZFS + AD)

**Objetivo:** Reproduzir e modernizar as funcionalidades do servidor FreeNAS atual utilizando Debian Linux 13 (Trixie), mantendo compatibilidade total com Active Directory e alta performance.

## 1. Preparação do Sistema (Debian 13)

### A. Repositórios e ZFS

O Debian precisa dos repositórios "contrib" e "non-free" para o ZFS.

```bash
# /etc/apt/sources.list (Adicionar contrib non-free-firmware)
apt update
apt install zfs-dkms zfsutils-linux samba winbind krb5-user smbclient realmd sssd sssd-tools packagekit -y
```

### B. Tuning de Kernel (`/etc/sysctl.conf`)

Equivalente aos "Tunables" que aplicamos no FreeNAS, mas adaptados para o kernel Linux.

```ini
# Otimizações de Rede e Memória para NAS
vm.swappiness=10                 # Evitar swap agressivo (preserva RAM para ARC)
vm.min_free_kbytes=65536         # Reserva mínima para evitar travamentos de rede
net.core.rmem_max=16777216       # Buffer de leitura TCP (16MB)
net.core.wmem_max=16777216       # Buffer de escrita TCP (16MB)
fs.inotify.max_user_watches=524288 # Vital para pastas com muitos arquivos
```

---

## 2. Configuração do ZFS (Linux)

No Linux, a performance do ZFS depende da flag `xattr=sa` para interagir bem com o Samba.

```bash
# Criação do Pool (Exemplo com 4 discos em RAID10/Mirror)
zpool create -o ashift=12 tank mirror /dev/sda /dev/sdb mirror /dev/sdc /dev/sdd

# Aplicação das Otimizações (IDÊNTICAS ao FreeNAS atual)
zfs set compression=lz4 tank
zfs set atime=off tank
zfs set xattr=sa tank            # CRÍTICO no Linux: Guarda atributos no inode (performance brutal)
zfs set acltype=posixacl tank    # CRÍTICO para compatibilidade de permissões Samba
```

---

## 3. Integração Active Directory (Modern Way)

Em vez de scripts frágeis (`ix-kerberos`), usaremos `realmd`, que é o padrão ouro no Linux.

### A. Ingressar no Domínio

```bash
# Descobrir o domínio
realm discover auroranet.aurora.gov.br

# Ingressar (Cria keytabs e configura sssd/krb5 automaticamente)
realm join auroranet.aurora.gov.br -U "seu_usuario_admin" --verbose
```

### B. Configurar Winbind (Para Mapeamento de IDs)

Para que o servidor apresente arquivos com permissões corretas para o Windows, precisamos configurar o mapeamento de UIDs no `smb.conf`.

---

## 4. Configuração do Samba (`/etc/samba/smb.conf`)

Aqui portamos as otimizações de **AIO** e **Strict Sync** que forçamos no banco de dados do FreeNAS.

```ini
[global]
   workgroup = AURORANET
   security = ads
   realm = AURORANET.AURORA.GOV.BR

   # Otimizações de Performance (Portadas do FreeNAS)
   strict sync = no
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
   aio read size = 16384
   aio write size = 16384
   use sendfile = yes

   # Logs
   log file = /var/log/samba/log.%m
   log level = 1

   # Identificação AD (Winbind)
   idmap config * : backend = tdb
   idmap config * : range = 3000-7999

   # Mapeamento do Domínio Principal (RID é mais estável que AD para migrações)
   idmap config AURORANET : backend = rid
   idmap config AURORANET : range = 10000-999999

   template shell = /bin/bash
   template homedir = /home/%U
   winbind enum users = no
   winbind enum groups = no
   winbind refresh tickets = yes

   # Compatibilidade com VFS do ZFS
   vfs objects = acl_xattr
   map acl inherit = yes
   store dos attributes = yes

[Compartilhamento]
   path = /tank/dados
   read only = no
   # Força herança de permissões (Windows Style)
   inherit acls = yes
   inherit permissions = yes
```

## 5. Migração de Dados (Rsync)

Para copiar os dados mantendo permissionamento e timestamps:

```bash
rsync -avPHAX --delete root@IP_FREENAS:/mnt/tank/dados/ /tank/dados/
```

- `-A`: Preserva ACLs.
- `-X`: Preserva atributos estendidos.

## Resumo das Vantagens no Debian

1. **Sem "Caixa Preta":** Tudo é arquivo de texto (`/etc/samba/smb.conf`). Nada escondido em bancos SQLite.
2. **Network-Online.target:** O systemd garante nativamente que a rede está pronta antes de subir o Samba/Winbind, eliminando o problema que exigiu o `ad_watchdog.sh` no FreeNAS.
3. **Atualizações:** Acesso a drivers e correções de segurança muito mais ágeis que no ciclo do TrueNAS/FreeNAS.
