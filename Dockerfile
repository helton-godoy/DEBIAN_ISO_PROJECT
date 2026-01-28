FROM debian:trixie-slim

# Instalar dependências do live-build
RUN apt-get update && \
    apt-get install -y \
    live-build \
    live-config \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    grub-efi-amd64-bin \
    grub-pc-bin \
    mtools \
    dosfstools \
    && rm -rf /var/lib/apt/lists/*

# Configurar diretório de trabalho
WORKDIR /project

# Script de entrada para executar o build
CMD lb clean && lb build
