#!/bin/bash
set -e

# Sincroniza as customizações para a pasta de trabalho do live-build
rsync -av /project/config-overrides/config/ /project/build/config/

cd /project/build

# Executa o config se não existir
if [ ! -d ".build" ]; then
    lb config \
        --distribution trixie \
        --archive-areas "main contrib non-free non-free-firmware" \
        --linux-packages "linux-image-amd64 linux-headers-amd64" \
        --compression zstd \
        --cache-packages true \
        --apt-recommends false \
        --image-name "aurora-nas-trixie"
fi

lb build 2>&1 | tee /project/logs/build-$(date +%Y%m%d).log

# Move o resultado para a pasta de output
mv *.iso /project/output/ 2>/dev/null || true

