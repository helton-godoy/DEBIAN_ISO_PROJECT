Para criar uma imagem ISO personalizada do Debian Trixie (atual Stable em 2026) que reproduza as capacidades de armazenamento e compartilhamento SMB do TrueNAS SCALE, você precisará de um conjunto específico de pacotes.

É importante ressaltar que o **TrueNAS SCALE** utiliza um _middleware_ proprietário (desenvolvido em Python) e uma interface Web específica que não estão disponíveis nos repositórios do Debian. Portanto, ao criar um "Debian Puro", você estará instalando os **serviços de backend** que o TrueNAS orquestra.

Para reproduzir o comportamento funcional (Samba, ZFS, ACLs avançadas), inclua os seguintes pacotes na sua configuração do `live-build`.

### 1. Sistema de Arquivos e Gerenciamento de Volume (O Coração)

O TrueNAS é construído sobre o **OpenZFS**. No Debian, o suporte ao ZFS reside nos repositórios `contrib` (certifique-se de habilitá-los na sua configuração do live-build).

- **`zfs-linux`**: O meta-pacote principal para suporte ZFS.
- **`zfs-dkms`**: Essencial para garantir que os módulos do kernel ZFS sejam compilados para o kernel que sua ISO live utilizará.
- **`zfsutils-linux`**: Ferramentas de linha de comando (`zpool`, `zfs`) para gerenciar os discos.
- **`zfs-zed`**: ZFS Event Daemon. No TrueNAS, é isso que monitora a saúde dos discos e dispara ações automáticas (como _hot-spares_).
- **`sanoid`** ou **`zfs-auto-snapshot`**: O TrueNAS possui um motor robusto de snapshots. No Debian puro, esses pacotes são as melhores alternativas para automatizar snapshots e retenção.

### 2. Compartilhamento SMB (Samba) e ACLs

Para replicar a compatibilidade do TrueNAS com Windows e o sistema de permissões, você precisa de mais do que apenas o servidor Samba básico.

- **`samba`**: O servidor SMB/CIFS.
- **`winbind`**: Necessário se você pretende integrar esse servidor a um Active Directory ou gerenciar usuários/grupos de forma similar ao TrueNAS.
- **`smbclient`**: Ferramentas de cliente para teste e verificação.
- **`cifs-utils`**: Utilitários para montar compartilhamentos SMB no sistema (útil para migração de dados).
- **`nfs4-acl-tools`**: **Crítico**. O TrueNAS utiliza ACLs NFSv4 sobre o ZFS para gerenciar permissões granulares compatíveis com Windows. Sem este pacote, você não conseguirá manipular as permissões avançadas (ACLs) da mesma forma que o TrueNAS faz.
- **`attr`**: Ferramentas para manipulação de atributos estendidos do sistema de arquivos (necessário para metadados SMB avançados).

### 3. Outros Serviços de Armazenamento (Paridade de Recursos)

O TrueNAS SCALE é uma plataforma unificada (File, Block, Object). Para ter esses recursos:

- **`nfs-kernel-server`**: Para compartilhamentos NFS (Unix/Linux).
- **`rsync`**: Para tarefas de replicação e sincronização de dados.

### 4. Monitoramento e Hardware

O TrueNAS fornece relatórios detalhados sobre o hardware.

- **`smartmontools`**: Para monitoramento S.M.A.R.T. de integridade de discos.
- **`lm-sensors`**: Para monitoramento de temperatura da CPU e placa-mãe.
- **`hdparm`** e **`sdparm`**: Para ajuste de parâmetros de disco.
- **`ipmitool`**: Essencial para gerenciamento de servidores via IPMI, muito comum em hardware compatível com TrueNAS.
- **`numactl`**: Para otimização em sistemas com múltiplos processadores (NUMA), relevante para ZFS e VMs.

### Resumo para o `package-lists` do live-build

Aqui está um bloco consolidado para adicionar à sua lista de pacotes do `live-build`:

```text
# Kernel e ZFS (Requer repositório contrib habilitado)
linux-image-amd64
linux-headers-amd64
zfs-linux
zfs-dkms
zfsutils-linux
zfs-zed
sanoid

# Samba e Rede
samba
winbind
smbclient
cifs-utils
nfs4-acl-tools
attr
nfs-kernel-server
rsync
net-tools
bridge-utils
vlan

# Hardware e Ferramentas
smartmontools
ipmitool
lm-sensors
hdparm
htop
curl
wget
openssh-server
```

**Nota sobre Configuração:** Para que o Samba funcione como no TrueNAS, você precisará configurar o `smb.conf` para suportar **vfs objects** específicos (como `vfs_zfsacl` ou `vfs_fruit` para compatibilidade com Mac) e garantir que o dataset ZFS tenha a propriedade `acltype=nfsv4` e `xattr=sa` ativadas, conforme as práticas de otimização do TrueNAS.
