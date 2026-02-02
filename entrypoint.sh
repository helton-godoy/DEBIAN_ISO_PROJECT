#!/usr/bin/env bash
# =============================================================================
# Entrypoint Simplificado - Cache DKMS via live_config/cache
# =============================================================================
# Estratégia:
# 1. Copia cache do HOST (live_config/cache) para includes.chroot (INJEÇÃO)
# 2. Hooks usam /var/cache/dkms-modules dentro do chroot
# 3. Após build, copia do chroot de volta para HOST (EXTRAÇÃO)
# =============================================================================

set -euo pipefail

# Caminhos
# O cache host vem mapeado em /project/cache (via sync live_config -> live_build)
HOST_CACHE_DIR="/project/cache/dkms-modules"

# Local de injeção para o live-build copiar para dentro do chroot
# O conteúdo deste diretório vai parar em /var/cache/dkms-modules no chroot
INJECT_DIR="/project/config/includes.chroot/var/cache/dkms-modules"

# Local onde o hook salva o novo cache (dentro do chroot)
CHROOT_CACHE_DIR="/project/chroot/var/cache/dkms-modules"

# Funções de Log
log_info() { echo "[entrypoint.sh] [INFO] $1"; }
log_warn() { echo "[entrypoint.sh] [WARN] $1" >&2; }
log_error() { echo "[entrypoint.sh] [ERROR] $1" >&2; }

prepare_cache() {
	log_info "Preparando cache para injeção..."

	# Limpa injeção anterior para garantir consistência
	rm -rf "$INJECT_DIR"

	# Se existe cache no host, copia para includes.chroot
	if [[ -d $HOST_CACHE_DIR ]] && [[ "$(ls -A "$HOST_CACHE_DIR")" ]]; then
		mkdir -p "$INJECT_DIR"
		cp -a "$HOST_CACHE_DIR/." "$INJECT_DIR/"
		log_info "Cache copiado para injeção ($INJECT_DIR)"
		find "$INJECT_DIR" -maxdepth 3 -not -path '*/.*' || true
		ls -la "$INJECT_DIR/.manifest.json" || log_warn "Manifesto não encontrado na injeção!"
	else
		log_info "Nenhum cache prévio encontrado em $HOST_CACHE_DIR"
	fi
}

extract_cache() {
	log_info "Extraindo cache pós-build..."

	# Se o build gerou novo cache no chroot
	if [[ -d $CHROOT_CACHE_DIR ]] && [[ -f "$CHROOT_CACHE_DIR/.manifest.json" ]]; then
		log_info "Novo cache encontrado no chroot. Atualizando host..."

		mkdir -p "$HOST_CACHE_DIR"

		# Usar rsync para atualizar host cache
		if command -v rsync &>/dev/null; then
			rsync -a --delete "$CHROOT_CACHE_DIR/" "$HOST_CACHE_DIR/"
		else
			# Fallback para cp
			rm -rf "$HOST_CACHE_DIR"/*
			cp -a "$CHROOT_CACHE_DIR/." "$HOST_CACHE_DIR/"
		fi

		log_info "Cache extraído com sucesso para $HOST_CACHE_DIR"
	else
		log_warn "Nenhum cache gerado no chroot ($CHROOT_CACHE_DIR) para extrair."
	fi
}

cleanup_injection() {
	# Limpar includes.chroot para não ficar sujeira no diretório de config para próximos runs
	# (Embora o container seja efêmero, é boa prática)
	if [[ -d $INJECT_DIR ]]; then
		log_info "Limpando diretório de injeção..."
		rm -rf "$INJECT_DIR"
	fi
}

main() {
	log_info "Iniciando processo de build..."

	# 1. Limpeza inicial do ambiente live-build
	log_info "Executando lb clean..."
	lb clean

	# 2. Preparar cache (injeta em includes.chroot)
	prepare_cache

	# 3. Build
	log_info "Executando lb build..."
	if lb build; then
		log_info "Build finalizado com sucesso."

		# 4. Extrair novo cache
		extract_cache

		RET=0
	else
		log_error "Build falhou."
		RET=1
	fi

	# 5. Limpeza final
	cleanup_injection

	exit $RET
}

main "$@"
