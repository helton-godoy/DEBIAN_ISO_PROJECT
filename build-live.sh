#!/usr/bin/env bash
# build-live.sh
# Constrói a ISO usando o conteúdo de live_config dentro de live_build

# Abortar em caso de erro
set -euo pipefail

# Garantir que estamos no diretório do projeto
cd "$(dirname "$0")" || exit 1

# Capturar diretório do projeto para evitar múltiplas chamadas a $(pwd)
PROJECT_DIR="$(pwd)"

# Variável para controle de limpeza forçada
FORCE_CLEAN=false

# Parse de argumentos
for arg in "$@"; do
	case $arg in
	--clean)
		FORCE_CLEAN=true
		shift
		;;
	--help | -h)
		echo "Uso: $0 [OPÇÕES]"
		echo ""
		echo "Opções:"
		echo "  --clean    Força rebuild limpo, removendo todo cache de bootstrap"
		echo "  --help     Mostra esta ajuda"
		exit 0
		;;
	esac
done

# Função para verificar e limpar cache desatualizado
check_and_clean_cache() {
	local cache_dir="${PROJECT_DIR}/live_build/cache"
	local bootstrap_cache="${cache_dir}/bootstrap"
	local packages_cache="${cache_dir}/packages"

	if [[ ${FORCE_CLEAN} == "true" ]]; then
		echo "=== Modo --clean ativado: Removendo todo cache de bootstrap ==="
		if [[ -d ${bootstrap_cache} ]]; then
			echo "Removendo cache de bootstrap: ${bootstrap_cache}"
			sudo rm -rf "${bootstrap_cache}"
		fi
		if [[ -d ${packages_cache} ]]; then
			echo "Removendo cache de pacotes: ${packages_cache}"
			sudo rm -rf "${packages_cache}"
		fi
		echo "Cache limpo com sucesso."
		return 0
	fi

	# Verifica se existe cache de bootstrap e se está potencialmente desatualizado
	if [[ -d ${bootstrap_cache} ]]; then
		local cache_age_days
		cache_age_days=$(find "${bootstrap_cache}" -maxdepth 0 -mtime +7 2>/dev/null | wc -l)

		if [[ ${cache_age_days} -gt 0 ]]; then
			echo "=== AVISO: Cache de bootstrap tem mais de 7 dias ==="
			echo "Para evitar conflitos de versão, o cache será limpo automaticamente."
			echo "Use --clean para forçar limpeza completa em builds futuros."
			echo ""
			sudo rm -rf "${bootstrap_cache}"
			echo "Cache de bootstrap removido."
		else
			echo "=== Cache de bootstrap encontrado (menos de 7 dias) ==="
			echo "Para forçar rebuild limpo, execute: $0 --clean"
		fi
	fi
}

# Configurar Logging
mkdir -p logs
BUILD_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/build_iso_${BUILD_TIMESTAMP}.log"
# Redirecionar stdout e stderr para o arquivo de log e para o terminal (tee)
# shellcheck disable=SC2312
exec > >(tee -i "${LOG_FILE}") 2>&1

START_TIME=$(date)
echo "=== Iniciando Build da ISO: ${START_TIME} ==="
echo "Log salvo em: ${LOG_FILE}"

# Verificar e limpar cache se necessário (antes de verificar dependências)
check_and_clean_cache

# Verificar dependências
if ! command -v docker &>/dev/null; then
	echo "ERRO: Docker não encontrado. Este script requer Docker para construir a ISO."
	exit 1
fi

# Verificar se live_config existe
if [[ ! -d "live_config" ]]; then
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

# Sincroniza live_config para live_build (--delete remove arquivos extras)
# Mas antes, corrige permissões de builds anteriores que podem ter deixado arquivos root
if [[ -d "live_build" ]]; then
	echo "Corrigindo permissões de live_build anterior..."
	# Tenta usar docker para corrigir permissões (mais rápido que sudo se docker já tiver permissão)
	# Se falhar (ex: imagem não existe), usa sudo chown
	docker run --rm -v "$(pwd)/live_build:/project" debian-live-builder chown -R $(id -u):$(id -g) /project 2>/dev/null ||
		sudo chown -R $(whoami) live_build
fi

# Exclui chroot/.build que são criados pelo build
# Exclui cache/ para gerenciar separadamente (preservando apt cache)
echo "Sincronizando live_config -> live_build..."
rsync -a --delete --exclude='chroot/' --exclude='.build/' --exclude='cache/' live_config/ live_build/

# Sincroniza apenas o cache DKMS (cria diretório se não existir)
mkdir -p live_build/cache
echo "Sincronizando cache DKMS..."
rsync -a --delete live_config/cache/dkms-modules/ live_build/cache/dkms-modules/

# 2. Construir a imagem Docker do ambiente de build
# Executa a partir da raiz, onde está o Dockerfile
echo "Criando ambiente de build (Docker)..."
docker build -t debian-live-builder .

# 3. Limpar containers anteriores do live-builder (evita conflitos)
echo "Verificando containers anteriores..."
# Para containers da imagem atual
RUNNING_CONTAINERS=$(docker ps -q --filter "ancestor=debian-live-builder" 2>/dev/null || true)

# Se não encontrou, tenta por nome (containers órfãos)
if [[ -z $RUNNING_CONTAINERS ]]; then
	RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null | head -3 || true)
	# Filtra apenas os que usam entrypoint.sh
	FILTERED=""
	for cid in $RUNNING_CONTAINERS; do
		if docker inspect --format '{{.Config.Cmd}}' "$cid" 2>/dev/null | grep -q entrypoint; then
			FILTERED="$FILTERED $cid"
		fi
	done
	RUNNING_CONTAINERS="$FILTERED"
fi

if [[ -n $RUNNING_CONTAINERS ]]; then
	echo "Parando containers anteriores: $RUNNING_CONTAINERS"
	docker stop $RUNNING_CONTAINERS 2>/dev/null || true
	sleep 1
	docker rm $RUNNING_CONTAINERS 2>/dev/null || true
fi
echo "Cleanup concluído"

# 5. Executar o build mapeando o diretório live_build
# Nota: --privileged é necessário para o live-build (chroot/mount)
# O cache agora reside dentro de live_build/cache, então é mapeado automaticamente via /project
echo "Iniciando build da ISO em live_build..."

time docker run --privileged --rm \
	-v "${PROJECT_DIR}/live_build:/project" \
	debian-live-builder

echo "================================================"
# Corrige permissões dos artefatos gerados (cache) para o usuário atual
# Isso evita erros no rsync de volta
echo "Ajustando permissões do cache..."
docker run --rm -v "${PROJECT_DIR}/live_build:/project" \
	--entrypoint chown \
	debian-live-builder \
	-R $(id -u):$(id -g) /project/cache

echo "Sincronizando cache gerado de volta para live_config..."
if [[ -d "live_build/cache/dkms-modules" ]]; then
	# Sincroniza cache de volta para persistência
	rsync -a live_build/cache/dkms-modules/ live_config/cache/dkms-modules/
	echo "Cache sincronizado: live_config/cache/dkms-modules/"
fi

echo "================================================"
echo "Pronto! ISO gerada em live_build/"
