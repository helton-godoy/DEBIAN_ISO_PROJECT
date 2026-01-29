#!/usr/bin/env bash
# build_live.sh
# Constrói a ISO usando o conteúdo de live_config dentro de live_build

# Abortar em caso de erro
set -e

# Garantir que estamos no diretório do projeto
cd "$(dirname "$0")"

# Verificar se live_config existe
if [ ! -d "live_config" ]; then
	echo "ERRO: Diretório 'live_config' não encontrado na raiz do projeto."
	exit 1
fi

# 1. Preparar o ambiente de build
echo "Limpando e preparando diretório live_build..."

mkdir -p live_build

# Limpeza segura: limpar conteúdo de live_build preservando cache/config/auto se existirem
(
	cd live_build || exit
	# Remove tudo exceto cache, config, auto e o próprio diretório atual (.)
	# Usa find para evitar problemas de parser com extglob e garantir que funcione
	find . -mindepth 1 -maxdepth 1 \
		! -name 'cache' \
		! -name 'config' \
		! -name 'auto' \
		-exec sudo rm -rf {} +
)

# Sincroniza live_config para live_build
echo "Sincronizando live_config -> live_build..."
rsync -a live_config/ live_build/

# 2. Construir a imagem Docker do ambiente de build
# Executa a partir da raiz, onde está o Dockerfile
echo "Criando ambiente de build (Docker)..."
docker build -t debian-live-builder .

# 3. Executar o build mapeando o diretório live_build
# Nota: --privileged é necessário para o live-build (chroot/mount)
echo "Iniciando build da ISO em live_build..."
docker run --privileged --rm \
	-v "$(pwd)/live_build:/project" \
	debian-live-builder
