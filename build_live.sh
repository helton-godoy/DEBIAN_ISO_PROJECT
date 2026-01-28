#!/bin/bash
# build_live.sh
# Constrói a ISO usando o conteúdo de live_config dentro de live_build

# Garantir que estamos no diretório do projeto
cd "$(dirname "$0")"

# 1. Preparar o ambiente de build
echo "Limpando e preparando diretório live_build..."
# Remove conteúdo mas mantém o diretório se ele já existir (evita problemas de permissão de montagem se houver algo preso)
# No entanto, o live-build pode deixar montagens pendentes. O lb clean é preferível se rodado dentro.
# Fora do container, fazemos uma limpeza bruta.
# sudo rm -rf live_build/.build
# sudo rm -rf live_build/auto
# sudo rm -rf live_build/chroot
# sudo rm -rf live_build/local
# sudo rm -rf live_build/config
# sudo rm -rf live_build/.lock
# sudo rm -rf live_build/binary.*
# sudo rm -rf live_build/live.*
# sudo rm -rf live_build/chroot.*
# mkdir -p live_build

# Remove tudo menos (cache|config|auto)
# 1. Entre na pasta
cd live_build || exit

# 2. Ative o extglob apenas para este shell
shopt -s extglob

# 3. Use o sudo para chamar o RM, mas deixe o Bash expandir os arquivos
sudo rm -rf !(cache|config|auto)





# Sincroniza live_config para live_build
echo "Sincronizando live_config -> live_build..."
rsync -a live_config/ live_build/

# 2. Construir a imagem Docker do ambiente de build
echo "Criando ambiente de build (Docker)..."
docker build -t debian-live-builder .

# 3. Executar o build mapeando o diretório live_build
# Nota: --privileged é necessário para o live-build (chroot/mount)
echo "Iniciando build da ISO em live_build..."
docker run --privileged --rm \
    -v "$(pwd)/live_build:/project" \
    debian-live-builder
