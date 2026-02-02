# AURORA NAS - Orchestration Makefile
# Versão: 1.0 (2026-02-02)

.PHONY: help setup-vms build-docker-builder iso test-iso clean

# Cores para o output (Harmonia Slate-Aurora)
PEAK := \033[38;5;153m
SLATE := \033[38;5;67m
RESET := \033[0m

help:
	@echo "$(PEAK)AURORA NAS - Comandos de Automação$(RESET)"
	@echo "$(SLATE)  make setup-vms$(RESET)       - Prepara KVM, Virsh e dependências de teste"
	@echo "$(SLATE)  make build-builder$(RESET)   - Cria imagem Docker baseada em Trixie para o build"
	@echo "$(SLATE)  make iso$(RESET)             - Gera a ISO AURORA dentro do container Docker"
	@echo "$(SLATE)  make test-iso$(RESET)        - Inicia VM de teste dando boot pela ISO gerada"
	@echo "$(SLATE)  make test-disk$(RESET)       - Inicia VM para validar estado pós-instalação"

# 1. Preparação do ambiente de virtualização
setup-vms:
	@echo "$(PEAK)Executando setup do ambiente de virtualização...$(RESET)"
	bash scripts/vm/vm-setup.sh

# 2. Criação do Builder Docker (Debian 13 Puro)
build-builder:
	@echo "$(PEAK)Construindo imagem Docker Aurora-Builder (Trixie)...$(RESET)"
	docker build -t aurora-builder scripts/docker/

# 3. Geração da ISO
# Monta o diretório local no container para persistir os logs e o output
iso:
	@echo "$(PEAK)Iniciando build da ISO AURORA...$(RESET)"
	docker run --privileged -v $(PWD)/config-overrides:/project/config \
		-v $(PWD)/output:/project/output \
		-v $(PWD)/logs:/project/logs \
		aurora-builder

# 4. Testes de Validação em VM
test-iso:
	@echo "$(PEAK)Iniciando VM de teste (Boot via ISO)...$(RESET)"
	bash scripts/vm/vm-start-test-boot-iso.sh

test-disk:
	@echo "$(PEAK)Iniciando VM de teste (Boot via Disco ZFS)...$(RESET)"
	bash scripts/vm/vm-start-test-boot-disk.sh

clean:
	@echo "$(SLATE)Limpando artefatos de build...$(RESET)"
	rm -rf build/* logs/* output/*.iso
