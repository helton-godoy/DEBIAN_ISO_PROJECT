#!/usr/bin/env bash
# ==============================================================================
# download-zfsbootmenu.sh - Gerenciador de Binários ZFSBootMenu (Robusto)
#
# Baixa os binários do ZFSBootMenu (EFI e Recovery) diretamente do GitHub.
# ==============================================================================

set -euo pipefail

# Cores
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[38;5;39m'
readonly NC='\033[0m'

# Configuração via GitHub API
readonly REPO="zbm-dev/zfsbootmenu"
readonly GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"

# Diretórios (Relativos à raiz do projeto)
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BINARY_DIR="${PROJECT_ROOT}/live_config/config/includes.binary/EFI/ZBM"
readonly CHROOT_DIR="${PROJECT_ROOT}/live_config/config/includes.chroot/usr/local/bin"

log_info() { printf "${CYAN}[ZBM]${NC} %s\n" "$*"; }
log_ok() { printf "${GREEN}[ZBM]${NC} ✔ %s\n" "$*"; }
log_warn() { printf "${YELLOW}[ZBM]${NC} ⚠ %s\n" "$*"; }
log_err() {
	printf "${RED}[ZBM]${NC} ✖ %s\n" "$*"
	exit 1
}

# Parâmetros
FORCE=false
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
	FORCE=true
fi

# 1. Detectar Versão e URLs via GitHub API
log_info "Buscando metadados da versão mais recente no GitHub..."
RELEASE_DATA=$(curl -s "${GITHUB_API}")

VERSION=$(echo "${RELEASE_DATA}" | grep -oP '"tag_name": "\K[^"]+')
if [[ -z "${VERSION}" ]]; then
	log_err "Falha ao detectar a versão no GitHub API."
fi
log_ok "Versão detectada: ${VERSION}"

# 2. Verificar Idempotência
VERSION_FILE="${BINARY_DIR}/VERSION"
if [[ -f "${VERSION_FILE}" ]] && [[ "${FORCE}" == "false" ]]; then
	INSTALLED_VERSION=$(head -n 1 "${VERSION_FILE}" | cut -d' ' -f2)
	if [[ "${INSTALLED_VERSION}" == "${VERSION}" ]]; then
		if [[ -f "${BINARY_DIR}/VMLINUZ.EFI" ]] && [[ $(stat -c%s "${BINARY_DIR}/VMLINUZ.EFI") -gt 1000000 ]]; then
			log_ok "ZFSBootMenu ${VERSION} já está instalado e íntegro."
			exit 0
		fi
	fi
fi

# 3. Preparar Diretórios
mkdir -p "${BINARY_DIR}" "${CHROOT_DIR}"

# 4. Encontrar e Baixar Assets
download_asset() {
	local pattern="$1"
	local dest="$2"
	local label="$3"

	log_info "Buscando URL para ${label}..."
	local url=$(echo "${RELEASE_DATA}" | grep -oP '"browser_download_url": "\K[^"]+' | grep -E "${pattern}" | head -n 1)

	if [[ -z "${url}" ]]; then
		log_err "Asset para ${label} não encontrado no GitHub."
	fi

	log_info "Baixando de: ${url}"
	if curl -L -f -s -o "${dest}" "${url}"; then
		local size=$(stat -c%s "${dest}")
		log_ok "${label} baixado: ${size} bytes"
	else
		log_err "Falha no download via curl."
	fi
}

# Download Release (Escolhemos o asset .EFI correspondente a x86_64)
# O padrão busca "zfsbootmenu-release-x86_64-.*.EFI" preferindo o que tiver kernel no nome se houver
download_asset "zfsbootmenu-release-x86_64-.*\.EFI" "${BINARY_DIR}/VMLINUZ.EFI" "Release EFI"
download_asset "zfsbootmenu-recovery-x86_64-.*\.EFI" "${BINARY_DIR}/VMLINUZ-RECOVERY.EFI" "Recovery EFI"

# 5. Sincronizar com diretório do instalador
log_info "Sincronizando para chroot..."
cp "${BINARY_DIR}/VMLINUZ.EFI" "${CHROOT_DIR}/zfsbootmenu.efi"

# 6. Criar arquivo de versão
echo "ZFSBootMenu ${VERSION}" >"${VERSION_FILE}"
echo "Data: $(date -Iseconds)" >>"${VERSION_FILE}"
echo "URL: ${GITHUB_API}" >>"${VERSION_FILE}"

log_ok "Concluído: ZFSBootMenu ${VERSION} baixado e organizado."
