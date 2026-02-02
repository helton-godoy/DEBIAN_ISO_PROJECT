# AURORA NAS: Criar ISO

O projeto tem como objetivo criar uma imagem personalizada do Debian Trixie 13 (atual STABLE em 2026), para reproduzir o comportamento do Samba do  "FreeNAS 9.10" (ou "TrueNAS Scale" que é também baseado no Debian) utilizando um Debian mais puro.
Para gerenciar o boot será utilizado o ZFSBootMenu para melhor compatibilidade com suporte avançados do ZFS.
A imagem terá como público alvo, sysadmin que precisam de um servidor com características Debian "vanilla" para melhor integração com outros sistemas e possibilidade de ajustes mais simples, assim como seriam feitos num Debian tradicional.
A imagem oferece suporte ao modo BIOS e UEFI, sendo que em computadores instalador no modo BIOS terão o Syslinux para o boot inicial, mas que trasnfirirá imediatamente para o ZFSBootMenu a gestão do boot, ele servirá apenas de módulo de compatibilidade BIOS Legacy e ponte para o ZFSBootMenu, pois assim isso garantirá a máquinas mais antigas o mesmo suporte a recuperação avançada que as máquinas UEFI teriam com o gerenciamento do ZFSBootMenu puro em máquinas UEFI.

```shell
aurora-nas/
├── .github/workflows/build.yml # Configuração do CI/CD
├── .git/hooks/
├── docs/ # Documentos arquitetura e manuais do projeto (MAN)
├── archived/ # Documentos de obsoletos, já cumpriu sua função (DONE)
├── plan/ # Planos com conceitos que justificam o motivo de execução de tarefas (STORIES)
├── tasks/ # Listas de tarefas a serem executadas baseadas em algum plano (TODO)
├── config-overrides/
│   └── config/           
│       ├── include.binary/
│       ├── include.chroot/
│       └── package.lists/
├── build/ # Manter artefatos gerados pelo live-build organizados (BUILD)
├── logs/ # Logs de build (LOGS)
├── output/ # ISOs geradas (ISO)
├── scripts/ # scripts de automação
│   ├── download-zfsbootmenu.sh
│   ├── docker/
│   │   ├── Dockerfile # Imagem do Builder (Base Trixie)
│   │   └── entrypoint.sh # entrypoint Docker
│   └── vm/
│       ├── vm-setup.sh # script de instalação do KVM, Virsh e demais dependências para preparar o ambiente de teste.
│       ├── disks/ # reservado para criação di discos virtuais de teste qcow2.
│       ├── cloud-config.yaml
│       ├── vm-start-test-boot-iso.sh # script para criar uma VM com KVM usando Virsh, iniciando o boot pela imagem ISO
│       ├── vm-start-test-boot-disk.sh # script que inicia a VM utilizando o disco virtual para verificar o estado da máquina após a instalação e fazer testes
│       └── vm-connent-agent-llm.sh # permitir o acesso de agentes LLM dentro da máquinas virtuais para interagirem e executar troubleshooting, tanto no ambiente iniciada pela ISO, quanto iniciada pela disco virtual.
├── tests/ # teste escritos para validação de alguma funcionalidade
└── Makefile # centraliza todos os comandos necessários
```

## Diretórios Principais de Configuração (`config/`)

- **`config/package-lists/`**: Contém arquivos `.list.chroot` com os nomes dos pacotes (um por linha) que você deseja instalar no sistema.
- **`config/includes.chroot/`**: É o espelho da raiz (`/`) do sistema live. Arquivos colocados aqui serão copiados exatamente para o mesmo local dentro da imagem instalada (ex: colocar algo em `config/includes.chroot/etc/skel/` afetará o usuário padrão).
- **`config/includes.binary/`**: Contém arquivos que ficarão na raiz da mídia (USB/ISO), fora do sistema de arquivos compactado, acessíveis logo ao montar o dispositivo.
- **`config/hooks/`**: Scripts (com extensão `.hook.chroot`) que são executados durante o processo de construção para realizar configurações complexas que não podem ser feitas apenas copiando arquivos.
- **`config/archives/`**: Usado para adicionar repositórios extras (arquivos `.list`) e suas respectivas chaves GPG (`.key`), permitindo instalar pacotes que não estão nos espelhos oficiais do Debian.
- **`config/binary`, `config/chroot`, `config/common`**: Arquivos gerados pelo `lb config` que guardam as variáveis de ambiente e opções de build (como arquitetura, mirrors e tipo de imagem). 

Diretórios de Operação (fora de `config/`)

- **`auto/`**: Onde ficam scripts de automação (`config`, `build`, `clean`) que servem como "wrappers" para garantir que os mesmos parâmetros sejam usados em todas as reconstruções.
- **`chroot/`**: Diretório temporário criado durante o `lb build` onde o sistema é montado e configurado antes de ser compactado.
- **`cache/`**: Armazena pacotes `.deb` baixados para acelerar reconstruções futuras. 

Você gostaria de um exemplo de script para **automatizar a configuração inicial** no diretório `auto/`?
