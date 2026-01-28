#!/bin/bash
# build_live.sh
# Constrói a ISO usando o container Docker definido

# 1. Construir a imagem Docker do ambiente de build
echo "Criando ambiente de build (Docker)..."
docker build -t debian-live-builder .

# 2. Executar o build mapeando o diretório atual
echo "Iniciando build da ISO..."
docker run --privileged --rm \
    -v "$(pwd):/project" \
    debian-live-builder
