# Projeto AURORA: Debian 13 ZFS-Root ISO (Samba/AD Optimized)

## 1. Abordagem Arquitetural: "Live Installer"

Ao contrário do instalador padrão do Debian (`d-i`), que não suporta ZFS nativamente de forma trivial, a abordagem mais robusta e "limpa" é criar uma **Live ISO Personalizada**.

**O fluxo de instalação será:**

1. Boot da ISO (Carrega sistema Live na RAM com suporte a ZFS já compilado).
2. Execução automática (ou manual) de um script Bash `install-system`.
3. O script particiona, formata (ZFS), instala o sistema base e configura o bootloader. (usar squashfs)

## 2. Ferramenta de Construção: `live-build`

Usaremos a ferramenta oficial do Debian para gerar a ISO. Isso garante que a base seja 100% Debian puro, sem "gambiarras".

### Estrutura do Projeto de Build

```shell
📦 live
├── 📁 auto/
├── 📁 config/
│   ├── 📁 includes.chroot
│   │   └── 📁 usr/                           # Estrutura de sistema Unix-like
│   │       └── 📁 local/                     # Arquivos locais do sistema
│   │           └── 📁 bin/                   # Binários executáveis
│   │               └── 📄 install-system     # Script Bash de instalação
│   ├── 📁 package-lists/
│   │   ├── 📄 live.list.chroot        # Básico para a imagem live
│   │   └── 📄 nas.list.chroot         # Pacotes da remasteriazação (zfs-dkms, samba, winbind, acl, nfs4-acl-tools...)
│   └── 📁 hooks/
│       └── 📁 normal/                 # Scripts para rodar durante a CRIAÇÃO da ISO
```

## 3. Estratégia de ZFS Root & Samba AD

### Particionamento & Boot (ZFSBootMenu)

Para atender ao requisito de **"Selecionar snapshot no boot"**, o GRUB é limitado. A solução moderna e robusta é o **ZFSBootMenu**.

* **Estrutura de Boot:**
  * Partição ESP (`vfat`): Contém o bootloader ZFSBootMenu (kernel Linux mínimo).
  * Partição de Boot (`zfs` ou dentro do root): Contém kernels e initrd do Debian.
  * **Funcionalidade:** O ZFSBootMenu carrega, monta o pool ZFS, permite escolher snapshots/clones (Boot Environments) e então passa o controle para o Debian.

### Otimizações Pré-injetadas

O script de instalação já aplicará no `/target` (o novo sistema):

* `zfs set compression=lz4`
* `zfs set xattr=sa` (Vital para Samba)
* **ACLs:** Ver disucssão abaixo.

---

## 4. O Dilema das ACLs: POSIX vs NFSv4

Esta é a parte crítica da sua solicitação.

### A Abordagem FreeNAS (NFSv4 ACLs)

O FreeNAS usa ACLs NFSv4 nativas no ZFS (`acltype=nfsv4`).

* **Vantagem:** Compatibilidade perfeita com ACLs do Windows (sem mapeamento).
* **Desvantagem no Linux:** As ferramentas padrão (`ls`, `chmod`, `getfacl`) **não entendem** isso bem. Você precisa usar ferramentas específicas (`nfs4_getfacl`, `nfs4_setfacl`) que são "estranhas" para quem vem do Linux puro.

### A Abordagem Debian/Linux Padrão (POSIX ACLs + Xattr)

No Linux, o padrão de ouro para Samba é: `zfs set acltype=posixacl` e `zfs set xattr=sa`.

* **Como funciona:** O Samba armazena as ACLs complexas do Windows dentro dos atributos estendidos (xattr). O sistema Linux vê permissões POSIX padrão e ACLs POSIX (`getfacl`).
* **Vantagem:** Integração nativa com todas as ferramentas Linux (`mv`, `cp`, `tar` preservam tudo). É a forma mais estável e performática no Linux hoje.

### Minha Recomendação: Caminho Híbrido

Podemos configurar o ZFS com `acltype=posixacl` (para compatibilidade de sistema) **MAS** configurar o Samba (`vfs_acl_xattr` ou `vfs_zfsacl`) para gerenciar as permissões finas.

Se você quer **exatamente** o comportamento de usar comandos para ver ACLs ricas, podemos incluir o pacote `nfs4-acl-tools` e configurar o ZFS com `acltype=nfsv4` no Linux. É possível, mas requer cuidado extra. *Na proposta abaixo, focarei na abordagem POSIX/Xattr que é a mais robusta para AD no Linux.*

---

## 5. Esboço do Script de Instalação (`install-system`)

Este script será embutido na ISO.

1. **Detecção de Discos:** Lista discos e pede ao usuário para selecionar (ex: `/dev/sda` e `/dev/sdb` para mirror).

2. **Criação do Pool:**

    ```bash
    zpool create -o ashift=12 -O mountpoint=none -O compression=lz4 -O acltype=posixacl -O xattr=sa rpool mirror /dev/sda2 /dev/sdb2
    ```

3. **Datasets:**
    * `rpool/ROOT/debian` (Mountpoint `/`)
    * `rpool/arquivos`    (Dados)
4. **Debootstrap:** Instala o Debian Trixie básico em `/mnt`.

5. **Chroot Configuration:**
    * Instala kernel, zfs-dkms e grub.
    * Gera `smb.conf` otimizado.
    * Configura rede (NetworkManager ou systemd-networkd).

## 6. Próximos Passos

Se aprovado este design, gerar:

1. Os arquivos de configuração do `live-build` (`lb config`).
2. O script mestre `install-system` para incluir na ISO.
