#!/usr/bin/env bash
# =============================================================================
# generate-seed-iso.sh
# =============================================================================
# Gera ISO de configuração cloud-init (seed.iso) com user-data, meta-data
# e network-config. Inclui injeção de chave SSH pública do host.
# Requisitos: cloud-image-utils (contém cloud-localds) ou genisoimage
# Data: 2026-02-01
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURAÇÕES
# =============================================================================

readonly SCRIPT_NAME
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Valores padrão
OUTPUT_FILE="${OUTPUT:-seed.iso}"
SSH_KEY_FILE="${SSH_KEY:-${HOME}/.ssh/id_rsa.pub}"
INSTANCE_ID="${INSTANCE_ID:-$(date +%s)}"
HOSTNAME="${HOSTNAME:-debian-zfs-test}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-admin}"
TIMEZONE="${TIMEZONE:-America/Sao_Paulo}"

# Cores
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Variáveis
VERBOSE=0
DRY_RUN=0
# shellcheck disable=SC2034
NO_PASSWORD_AUTH=0
INSTALL_QEMU_GA=1
ENABLE_ROOT=0

# Diretório temporário
TEMP_DIR=""

# =============================================================================
# FUNÇÕES DE UTILIDADE
# =============================================================================

log_info() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
	echo -e "${CYAN}[STEP]${NC} $1"
}

log_debug() {
	if [[ ${VERBOSE} -eq 1 ]]; then
		echo -e "${BLUE}[DEBUG]${NC} $1"
	fi
}

log_success() {
	echo -e "${MAGENTA}[SUCCESS]${NC} $1"
}

cleanup() {
	if [[ -n ${TEMP_DIR} && -d ${TEMP_DIR} ]]; then
		log_debug "Limpando diretório temporário: ${TEMP_DIR}"
		rm -rf "${TEMP_DIR}"
	fi
}

trap cleanup EXIT

# =============================================================================
# VERIFICAÇÕES DE DEPENDÊNCIAS
# =============================================================================

check_dependencies() {
	local missing=()

	# Verifica por cloud-localds (cloud-image-utils) ou genisoimage
	if ! command -v cloud-localds &>/dev/null; then
		if ! command -v genisoimage &>/dev/null && ! command -v mkisofs &>/dev/null; then
			missing+=("cloud-image-utils OU genisoimage")
		fi
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Dependências ausentes:"
		for dep in "${missing[@]}"; do
			echo "  - ${dep}"
		done
		echo
		log_info "Instale com:"
		echo "  sudo apt install cloud-image-utils    # Recomendado"
		echo "  # ou"
		echo "  sudo apt install genisoimage"
		exit 1
	fi

	log_debug "Dependências verificadas"
}

# =============================================================================
# GERAÇÃO DE ARQUIVOS CLOUD-INIT
# =============================================================================

generate_meta_data() {
	local output_file="$1"

	log_debug "Gerando meta-data..."

	cat >"${output_file}" <<EOF
instance-id: ${INSTANCE_ID}
local-hostname: ${HOSTNAME}
EOF

	log_debug "meta-data criado: ${output_file}"
}

generate_network_config() {
	local output_file="$1"

	log_debug "Gerando network-config..."

	# Configuração de rede DHCP simples
	cat >"${output_file}" <<'EOF'
version: 2
ethernets:
  eth0:
    dhcp4: true
    dhcp6: false
    match:
      driver: virtio_net
    set-name: eth0
EOF

	log_debug "network-config criado: ${output_file}"
}

generate_user_data() {
	local output_file="$1"

	log_step "Gerando user-data..."

	# Coleta chaves SSH
	local ssh_keys=""

	# Adiciona chave especificada
	if [[ -f ${SSH_KEY_FILE} ]]; then
		local key_content
		key_content=$(cat "${SSH_KEY_FILE}")
		ssh_keys="      - ${key_content}"
		log_info "Chave SSH adicionada: ${SSH_KEY_FILE}"
	else
		log_warn "Arquivo de chave SSH não encontrado: ${SSH_KEY_FILE}"
	fi

	# Procura por outras chaves comuns
	for key_file in "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/id_ecdsa.pub" "${HOME}/.ssh/id_rsa.pub"; do
		if [[ -f ${key_file} && ${key_file} != "${SSH_KEY_FILE}" ]]; then
			local key_content
			key_content=$(cat "${key_file}")
			if [[ -n ${ssh_keys} ]]; then
				ssh_keys="${ssh_keys}
      - ${key_content}"
			else
				ssh_keys="      - ${key_content}"
			fi
			log_info "Chave SSH adicional: ${key_file}"
		fi
	done

	# Gera user-data
	cat >"${output_file}" <<EOF
#cloud-config
# Gerado por ${SCRIPT_NAME} em $(date -Iseconds)

# Configuração do hostname
hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.local

# Configuração de usuário
users:
  - name: ${USERNAME}
    gecos: Administrator User
    groups: sudo, adm, libvirt, kvm
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "${PASSWORD}"
${ssh_keys:+    ssh_authorized_keys:
${ssh_keys}}

EOF

	# Adiciona usuário root se solicitado
	if [[ ${ENABLE_ROOT} -eq 1 ]]; then
		log_info "Habilitando acesso root via SSH..."
		cat >>"${output_file}" <<'EOF'
  - name: root
    lock_passwd: false
    plain_text_passwd: "root"

EOF
	fi

	# Continua com a configuração
	cat >>"${output_file}" <<EOF
# Configuração de senha (permitir login com senha)
chpasswd:
  list: |
    ${USERNAME}:${PASSWORD}
EOF

	if [[ ${ENABLE_ROOT} -eq 1 ]]; then
		echo "    root:root" >>"${output_file}"
	fi

	cat >>"${output_file}" <<'EOF'
  expire: false

# Configuração de SSH
ssh_pwauth: true
ssh_deletekeys: false
EOF

	if [[ ${ENABLE_ROOT} -eq 1 ]]; then
		cat >>"${output_file}" <<'EOF'
ssh_genkeytypes: [rsa, ecdsa, ed25519]
disable_root: false

EOF
	else
		cat >>"${output_file}" <<'EOF'
disable_root: true

EOF
	fi

	# Timezone
	cat >>"${output_file}" <<EOF
# Timezone
timezone: ${TIMEZONE}

EOF

	# Pacotes
	cat >>"${output_file}" <<'EOF'
# Pacotes a instalar
package_update: true
package_upgrade: false
packages:
  - qemu-guest-agent
  - curl
  - wget
  - vim
  - htop
  - net-tools
  - iputils-ping
  - less
  - bash-completion

EOF

	# Configuração do qemu-guest-agent
	if [[ ${INSTALL_QEMU_GA} -eq 1 ]]; then
		cat >>"${output_file}" <<'EOF'
# Habilitar e iniciar qemu-guest-agent
runcmd:
  - [systemctl, enable, qemu-guest-agent]
  - [systemctl, start, qemu-guest-agent]

EOF
	fi

	# Configuração final
	cat >>"${output_file}" <<'EOF'
# Mensagem final
final_message: "Sistema inicializado com sucesso! Acesse via SSH ou console."

power_state:
  mode: keep
  message: Cloud-init finalizado
EOF

	log_debug "user-data criado: ${output_file}"
}

# =============================================================================
# GERAÇÃO DA ISO
# =============================================================================

generate_seed_iso() {
	local output="$1"
	local user_data="$2"
	local meta_data="$3"
	local network_config="$4"

	log_step "Gerando ISO de configuração..."

	# Usa caminho absoluto para o output
	local abs_output
	if [[ ${output} == /* ]]; then
		abs_output="${output}"
	else
		abs_output="$(pwd)/${output}"
	fi

	log_info "Arquivo de saída: ${abs_output}"

	if [[ ${DRY_RUN} -eq 1 ]]; then
		log_info "[DRY-RUN] ISO seria criada em: ${abs_output}"
		log_info "Arquivos que seriam incluídos:"
		log_info "  - user-data: ${user_data}"
		log_info "  - meta-data: ${meta_data}"
		log_info "  - network-config: ${network_config}"
		return 0
	fi

	# Cria diretório se necessário
	local output_dir
	output_dir=$(dirname "${abs_output}")
	if [[ ! -d ${output_dir} ]]; then
		log_info "Criando diretório: ${output_dir}"
		mkdir -p "${output_dir}"
	fi

	# Remove arquivo anterior se existir
	if [[ -f ${abs_output} ]]; then
		log_warn "Removendo ISO anterior: ${abs_output}"
		rm -f "${abs_output}"
	fi

	# Gera a ISO
	if command -v cloud-localds &>/dev/null; then
		# Método preferido: cloud-localds
		log_debug "Usando cloud-localds para gerar ISO..."

		# Copia network-config para o temp dir se existir
		local network_opt=""
		if [[ -f ${network_config} ]]; then
			network_opt="--network-config=${network_config}"
		fi

		cloud-localds "${abs_output}" "${user_data}" "${meta_data}" "${network_opt}"
	else
		# Fallback: genisoimage/mkisofs
		log_debug "Usando genisoimage/mkisofs para gerar ISO..."

		local iso_tool="genisoimage"
		if ! command -v genisoimage &>/dev/null; then
			iso_tool="mkisofs"
		fi

		# Copia arquivos para temp_dir com nomes corretos
		cp "${user_data}" "${TEMP_DIR}/user-data"
		cp "${meta_data}" "${TEMP_DIR}/meta-data"
		[[ -f ${network_config} ]] && cp "${network_config}" "${TEMP_DIR}/network-config"

		${iso_tool} -output "${abs_output}" -volid cidata -joliet -rock \
			"${TEMP_DIR}/user-data" "${TEMP_DIR}/meta-data" 2>/dev/null || {
			log_error "Falha ao criar ISO com ${iso_tool}"
			exit 1
		}
	fi

	if [[ -f ${abs_output} ]]; then
		local iso_size
		iso_size=$(du -h "${abs_output}" | cut -f1)
		log_success "ISO criada com sucesso: ${abs_output} (${iso_size})"
	else
		log_error "Falha ao criar ISO"
		exit 1
	fi
}

# =============================================================================
# FLUXO PRINCIPAL
# =============================================================================

main() {
	echo "================================================================"
	echo "  Cloud-Init Seed ISO Generator"
	echo "================================================================"
	echo

	# Parse argumentos
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		--verbose | -v)
			VERBOSE=1
			shift
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--output | -o)
			OUTPUT_FILE="$2"
			shift 2
			;;
		--ssh-key | -k)
			SSH_KEY_FILE="$2"
			shift 2
			;;
		--hostname)
			HOSTNAME="$2"
			shift 2
			;;
		--username | -u)
			USERNAME="$2"
			shift 2
			;;
		--password | -p)
			PASSWORD="$2"
			shift 2
			;;
		--timezone | -t)
			TIMEZONE="$2"
			shift 2
			;;
		--instance-id)
			INSTANCE_ID="$2"
			shift 2
			;;
		--no-password-auth)
			NO_PASSWORD_AUTH=1
			shift
			;;
		--enable-root)
			ENABLE_ROOT=1
			shift
			;;
		--no-qemu-ga)
			INSTALL_QEMU_GA=0
			shift
			;;
		*)
			log_error "Opção desconhecida: $1"
			echo "Use --help para ver opções disponíveis"
			exit 1
			;;
		esac
	done

	# Verifica dependências
	check_dependencies

	# Cria diretório temporário
	TEMP_DIR=$(mktemp -d -t seed-iso-XXXXXX)
	log_debug "Diretório temporário: ${TEMP_DIR}"

	# Gera arquivos
	local user_data_file="${TEMP_DIR}/user-data"
	local meta_data_file="${TEMP_DIR}/meta-data"
	local network_config_file="${TEMP_DIR}/network-config"

	generate_user_data "${user_data_file}"
	generate_meta_data "${meta_data_file}"
	generate_network_config "${network_config_file}"

	# Mostra configuração
	echo
	log_info "Configuração:"
	echo "  Hostname: ${HOSTNAME}"
	echo "  Usuário: ${USERNAME}"
	echo "  Timezone: ${TIMEZONE}"
	echo "  Instance ID: ${INSTANCE_ID}"
	echo

	# Gera ISO
	generate_seed_iso "${OUTPUT_FILE}" "${user_data_file}" "${meta_data_file}" "${network_config_file}"

	echo
	log_success "Processo concluído!"
	echo
	log_info "Para usar esta ISO com a VM:"
	echo "  ./tests/vm-start-with-cloudinit.sh --seed ${OUTPUT_FILE}"
	echo
}

show_help() {
	cat <<EOF
Uso: ${SCRIPT_NAME} [OPÇÕES]

Gera uma ISO de configuração cloud-init (seed.iso) para inicialização
automática de VMs com configurações personalizadas.

Opções:
  -h, --help                 Mostra esta ajuda
  -v, --verbose              Modo verbose (mais informações)
      --dry-run              Simula execução sem criar arquivos
  -o, --output ARQUIVO       Arquivo de saída (padrão: seed.iso)
  -k, --ssh-key ARQUIVO      Chave SSH pública a injetar (padrão: ~/.ssh/id_rsa.pub)
      --hostname NOME        Hostname da VM (padrão: debian-vm)
  -u, --username USUARIO     Nome do usuário (padrão: admin)
  -p, --password SENHA       Senha do usuário (padrão: admin)
  -t, --timezone TZ          Timezone (padrão: America/Sao_Paulo)
      --instance-id ID       ID da instância (padrão: timestamp)
      --no-password-auth     Desabilita autenticação por senha
      --enable-root          Habilita login como root via SSH
      --no-qemu-ga           Não instala/configura qemu-guest-agent

Exemplos:
  ${SCRIPT_NAME}                          # Usa valores padrão
  ${SCRIPT_NAME} -o config.iso            # Nome de saída customizado
  ${SCRIPT_NAME} -k ~/.ssh/mykey.pub      # Chave SSH específica
  ${SCRIPT_NAME} --hostname server1       # Hostname personalizado
  ${SCRIPT_NAME} -u dev -p secret123      # Credenciais customizadas

Notas:
  - A ISO gerada deve ser montada como CD-ROM na VM
  - Cloud-init procura por dispositivos com label 'cidata'
  - A ISO deve ser gerada novamente para cada instância única

EOF
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

main "$@"
