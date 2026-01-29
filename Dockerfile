FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

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
    zstd \
    curl \
    wget \
    git \
    rsync \
    locales \
    && rm -rf /var/lib/apt/lists/*

RUN echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen pt_BR.UTF-8 && \
    update-locale LANG=pt_BR.UTF-8

ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Configurar diretório de trabalho
WORKDIR /project

# Script de entrada para executar o build
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]



