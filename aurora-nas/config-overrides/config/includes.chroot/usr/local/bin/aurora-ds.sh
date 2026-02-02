#!/bin/bash
# AURORA NAS - Core Setup Script (Debian 13 Trixie)
# Foco: Performance, ZFS NFSv4 ACLs e Winbind RID

# 1. Tuning de Kernel (Paridade FreeNAS/Performance)
# Resolve o Gap 2.1 identificado na revisão
cat <<EOF > /etc/sysctl.d/99-nas-performance.conf
# Otimizações para preservação de ARC e vazão de rede
vm.swappiness=10
vm.min_free_kbytes=65536
net.core.rmem_max=16777216
net.core.wmem_max=16777216
fs.inotify.max_user_watches=524288
EOF
sysctl --system

# 2. Configuração de Rede e Tempo (Crítico para AD/Kerberos)
# Resolve o Gap 2.3
apt update && apt install chrony -y
systemctl enable --now chrony
# Nota: O chrony garante o sync necessário para evitar falhas de ticket Kerberos

# 3. Preparação do Dataset ZFS (NFSv4 ACLs)
# Aplica a Recomendação 3.1 da Revisão Arquitetural
# Assume-se que o pool 'rpool' já existe via install-system
zfs create -o mountpoint=/srv/dados rpool/dados
zfs set compression=lz4 rpool/dados
zfs set atime=off rpool/dados
zfs set xattr=sa rpool/dados # Melhora performance de atributos estendidos no Linux
zfs set acltype=nfsv4 rpool/dados # Garante paridade com ACLs do FreeNAS/Windows

# 4. Template de Configuração Samba (Winbind RID)
# Resolve o Gap 2.2 e aplica a recomendação de Winbind Puro
cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = AURORANET
   security = ads
   realm = AURORANET.AURORA.GOV.BR
   server string = Aurora NAS (Debian Trixie)

   # Tuning de Performance Portado do FreeNAS
   strict sync = no
   aio read size = 16384
   aio write size = 16384
   use sendfile = yes
   socket options = TCP_NODELAY IPTOS_LOWDELAY

   # Log e Diagnóstico
   log file = /var/log/samba/log.%m
   log level = 1

   # Mapeamento de IDs Determinístico (RID)
   # Garante que os IDs sejam consistentes em caso de reinstalação
   idmap config * : backend = tdb
   idmap config * : range = 3000-7999
   idmap config AURORANET : backend = rid
   idmap config AURORANET : range = 10000-999999

   # Integração VFS para ZFS e Windows Style ACLs
   vfs objects = acl_xattr
   map acl inherit = yes
   store dos attributes = yes

[Dados]
   path = /srv/dados
   read only = no
   inherit acls = yes
   inherit permissions = yes
   browseable = yes
EOF

# Reinicia serviços para aplicar base
systemctl restart smbd nmbd winbind 
