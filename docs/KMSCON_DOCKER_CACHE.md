# KMSCON Docker Cache - Guia de Uso

Sistema de cache multi-camada para builds do KMSCON em ambientes Docker containerizados.

## Índice

- [Visão Geral](#visão-geral)
- [Arquitetura de Cache](#arquitetura-de-cache)
- [Instalação Rápida](#instalação-rápida)
- [Uso com Docker](#uso-com-docker)
- [Uso com Docker Compose](#uso-com-docker-compose)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)
- [Referência da API](#referência-da-api)

---

## Visão Geral

O sistema de cache multi-camada do KMSCON foi projetado para:

- **Reduzir tempos de build** em 60-90% após o primeiro build
- **Persistir cache** entre builds via volumes Docker
- **Suportar builds paralelos** com file locking (`flock`)
- **Validar integridade** via hashes SHA256
- **Funcionar em CI/CD** com graceful degradation

### Recursos Principais

| Recurso            | Descrição                                |
| ------------------ | ---------------------------------------- |
| 4 Camadas de Cache | Source, Build, Package, Deps             |
| Manifest JSON      | Metadados e hashes de todos os inputs    |
| File Locking       | `flock` para builds paralelos seguros    |
| Detecção Docker    | Auto-detecção de ambiente containerizado |
| TTL de Cache       | Limpeza automática de entradas expiradas |
| Fallback           | Build completo se cache corrompido       |

---

## Arquitetura de Cache

### Camadas de Cache

```
/var/cache/kmscon/
├── manifest.json           # Manifest com hashes e metadados
├── lock/                   # Diretório de locks
│   └── build.lock
├── sources/                # Layer 1: Source cache
│   ├── kmscon/
│   │   ├── kmscon-9.0.0.tar.xz
│   │   └── HEAD
│   └── libtsm/
│       └── libtsm-4.0.2.tar.xz
├── build/                  # Layer 2: Build cache
│   ├── kmscon-builddir/
│   └── libtsm-builddir/
├── packages/               # Layer 3: Package cache
│   ├── kmscon_9.0.0_amd64.deb
│   └── kmscon_9.0.0_amd64.deb.manifest
└── deps/                   # Layer 4: Deps cache (apt)
    └── apt-cache/
```

### Formato do Manifest

```json
{
  "version": "1.0",
  "created_at": "2026-01-31T15:00:00Z",
  "entries": {
    "kmscon": {
      "source_hash": "abc123...",
      "patches_hash": "def456...",
      "config_hash": "ghi789...",
      "deps_hash": "jkl012...",
      "combined_hash": "xyz789...",
      "cached_deb": "packages/kmscon_9.0.0_amd64.deb",
      "package_hash": "sha256_of_deb_file",
      "build_time": 120,
      "valid": true,
      "created_at": "2026-01-31T15:00:00Z"
    }
  }
}
```

### Invalidação de Cache

O cache é invalidado automaticamente quando:

1. **Source hash muda**: Nova versão do tarball ou commit diferente
2. **Patches hash muda**: Arquivos de patch modificados
3. **Config hash muda**: Flags de compilação alteradas
4. **Deps hash muda**: Versões de ferramentas de build diferentes
5. **TTL expirado**: Cache mais antigo que `KMSCON_CACHE_TTL_DAYS`
6. **Hash do pacote inválido**: Arquivo .deb corrompido

---

## Instalação Rápida

### 1. Setup de Cache Local

```bash
# Executar script de setup
./scripts/docker-cache-setup.sh setup

# Ou com diretório específico
./scripts/docker-cache-setup.sh setup -d /mnt/fast-ssd/kmscon-cache
```

### 2. Verificar Status

```bash
./scripts/docker-cache-setup.sh status
```

Saída esperada:

```
================================================
KMSCON Docker Cache Setup v1.0.0
================================================
Cache Dir: /home/user/.cache/kmscon-build
Volume: kmscon-cache
UID/GID: 1000/1000
================================================
[INFO] Diretório de cache no host: /home/user/.cache/kmscon-build
[INFO] Volume Docker: kmscon-cache
[INFO] Setup concluído com sucesso!
================================================
```

---

## Uso com Docker

### Build Direto com Cache

```bash
# Build usando volume nomeado
docker run --rm \
  -v kmscon-cache:/var/cache/kmscon \
  -v $(pwd)/scripts:/usr/local/share/kmscon:ro \
  -e KMSCON_CACHE_ENABLED=1 \
  debian:trixie-slim \
  bash /usr/local/share/kmscon/build-kmscon.sh
```

### Build com Bind Mount

```bash
# Usar diretório local como cache
docker run --rm \
  -v ~/.cache/kmscon-build:/var/cache/kmscon \
  -v $(pwd)/scripts:/usr/local/share/kmscon:ro \
  -v $(pwd)/output:/var/cache/kmscon-build \
  -e KMSCON_CACHE_ENABLED=1 \
  -e HOST_UID=$(id -u) \
  -e HOST_GID=$(id -g) \
  debian:trixie-slim \
  bash /usr/local/share/kmscon/build-kmscon.sh
```

### Forçar Rebuild (Ignorar Cache)

```bash
docker run --rm \
  -v kmscon-cache:/var/cache/kmscon \
  -e KMSCON_CACHE_FORCE_REFRESH=1 \
  debian:trixie-slim \
  bash /usr/local/share/kmscon/build-kmscon.sh
```

### Apenas Verificar Cache

```bash
docker run --rm \
  -v kmscon-cache:/var/cache/kmscon \
  -e KMSCON_CACHE_ENABLED=1 \
  debian:trixie-slim \
  bash /usr/local/share/kmscon/build-kmscon.sh --cache-only
```

---

## Uso com Docker Compose

### Build Simples

```bash
# Configurar ambiente
export HOST_CACHE_DIR=$HOME/.cache/kmscon-build
export OUTPUT_DIR=$PWD/output
mkdir -p $HOST_CACHE_DIR $OUTPUT_DIR

# Executar build
docker-compose -f docker-compose.cache.yml up --build kmscon-builder
```

### Build com Variáveis

```bash
# Build com configurações específicas
KMSCON_VERSION=9.0.0 \
KMSCON_CACHE_ENABLED=1 \
KMSCON_PARALLEL_JOBS=8 \
LOG_LEVEL=DEBUG \
docker-compose -f docker-compose.cache.yml up --build kmscon-builder
```

### Inspecionar Cache

```bash
# Ver conteúdo do cache
docker-compose -f docker-compose.cache.yml --profile inspect run --rm cache-inspector
```

### Limpar Cache

```bash
# Limpeza suave (remove pacotes antigos >30 dias)
docker-compose -f docker-compose.cache.yml --profile cleanup run --rm cache-cleanup

# Limpeza completa via script
./scripts/docker-cache-setup.sh cleanup hard
```

---

## Variáveis de Ambiente

### Controle de Cache

| Variável                     | Padrão              | Descrição                                 |
| ---------------------------- | ------------------- | ----------------------------------------- |
| `KMSCON_CACHE_DIR`           | `/var/cache/kmscon` | Diretório raiz do cache                   |
| `KMSCON_CACHE_ENABLED`       | `1`                 | Habilitar cache (1=sim, 0=não)            |
| `KMSCON_CACHE_FORCE_REFRESH` | `0`                 | Forçar rebuild ignorando cache            |
| `KMSCON_CACHE_TTL_DAYS`      | `30`                | Dias até expiração do cache               |
| `KMSCON_LOCK_TIMEOUT`        | `300`               | Timeout para aquisição de lock (segundos) |

### Configuração Docker

| Variável               | Padrão | Descrição                         |
| ---------------------- | ------ | --------------------------------- |
| `KMSCON_DOCKER_MODE`   | `auto` | Modo Docker: auto, yes, no        |
| `KMSCON_PARALLEL_JOBS` | `auto` | Jobs de compilação (auto = nproc) |
| `KMSCON_APT_CACHE`     | `1`    | Usar cache de apt (1=sim, 0=não)  |
| `HOST_UID`             | `1000` | UID do host (permissões)          |
| `HOST_GID`             | `1000` | GID do host (permissões)          |

### Configuração de Build

| Variável         | Padrão  | Descrição                                |
| ---------------- | ------- | ---------------------------------------- |
| `KMSCON_VERSION` | `9.0.0` | Versão do kmscon                         |
| `LIBTSM_VERSION` | `4.0.2` | Versão do libtsm                         |
| `LOG_LEVEL`      | `INFO`  | Nível de log: DEBUG, INFO, WARN, ERROR   |
| `KEEP_BUILD`     | `0`     | Manter diretório de build (1=sim, 0=não) |

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Build KMSCON

on: [push, pull_request]

env:
  KMSCON_CACHE_ENABLED: 1
  KMSCON_VERSION: 9.0.0

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Cache
        uses: actions/cache@v4
        with:
          path: ~/.cache/kmscon-build
          key: kmscon-${{ runner.os }}-${{ hashFiles('scripts/patches/*.patch') }}
          restore-keys: |
            kmscon-${{ runner.os }}-

      - name: Setup Docker Cache
        run: |
          ./scripts/docker-cache-setup.sh setup

      - name: Build KMSCON
        run: |
          docker-compose -f docker-compose.cache.yml up --build kmscon-builder

      - name: Upload Package
        uses: actions/upload-artifact@v4
        with:
          name: kmscon-package
          path: output/*.deb
```

### GitLab CI

```yaml
variables:
  KMSCON_CACHE_ENABLED: "1"
  DOCKER_DRIVER: overlay2

stages:
  - build

.kmscon_cache: &kmscon_cache
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - .cache/kmscon-build/
  policy: pull-push

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  cache:
    <<: *kmscon_cache
  script:
    - ./scripts/docker-cache-setup.sh setup -d .cache/kmscon-build
    - docker-compose -f docker-compose.cache.yml up --build kmscon-builder
  artifacts:
    paths:
      - output/*.deb
    expire_in: 1 week
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any

    environment {
        KMSCON_CACHE_ENABLED = '1'
        HOST_CACHE_DIR = "${env.WORKSPACE}/.cache"
    }

    stages {
        stage('Setup') {
            steps {
                sh './scripts/docker-cache-setup.sh setup'
            }
        }

        stage('Build') {
            steps {
                sh 'docker-compose -f docker-compose.cache.yml up --build kmscon-builder'
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'output/*.deb', fingerprint: true
            }
        }
    }

    post {
        always {
            sh 'docker-compose -f docker-compose.cache.yml down'
        }
    }
}
```

### Travis CI

```yaml
language: minimal

services:
  - docker

env:
  - KMSCON_CACHE_ENABLED=1

cache:
  directories:
    - $HOME/.cache/kmscon-build

before_script:
  - ./scripts/docker-cache-setup.sh setup

script:
  - docker-compose -f docker-compose.cache.yml up --build kmscon-builder
```

---

## Troubleshooting

### Cache Não Encontrado

**Sintoma**: Build sempre executa do zero, ignorando cache

**Solução**:

```bash
# Verificar se manifesto existe
ls -la ~/.cache/kmscon-build/manifest.json

# Verificar permissões
./scripts/docker-cache-setup.sh setup -u $(id -u) -g $(id -g)

# Verificar se volume está montado
docker volume inspect kmscon-cache
```

### Lock Timeout

**Sintoma**: "Timeout ao adquirir lock de cache"

**Causa**: Outro build em andamento ou lock stale

**Solução**:

```bash
# Verificar processos em execução
docker ps --filter "name=kmscon"

# Remover lock manualmente (se tiver certeza que nenhum build roda)
rm -f ~/.cache/kmscon-build/lock/build.lock

# Aumentar timeout
export KMSCON_LOCK_TIMEOUT=600
```

### Cache Corrompido

**Sintoma**: "Hash do pacote em cache não corresponde"

**Solução**:

```bash
# Limpar cache específico
./scripts/docker-cache-setup.sh cleanup hard

# Ou remover manualmente
rm -rf ~/.cache/kmscon-build/packages/*.deb

# Forçar rebuild
export KMSCON_CACHE_FORCE_REFRESH=1
```

### Permissões Negadas

**Sintoma**: "Sem permissão de escrita em /var/cache/kmscon"

**Solução**:

```bash
# Verificar UID/GID no container
docker run --rm -v kmscon-cache:/var/cache/kmscon debian:trixie-slim id

# Ajustar permissões
./scripts/docker-cache-setup.sh setup -u $(id -u) -g $(id -g)

# Ou usar bind mount com permissões corretas
docker run --rm \
  -v ~/.cache/kmscon-build:/var/cache/kmscon \
  -e HOST_UID=$(id -u) \
  -e HOST_GID=$(id -g) \
  ...
```

### Falta de Espaço

**Sintoma**: "Espaço em disco insuficiente"

**Solução**:

```bash
# Verificar uso de disco
du -sh ~/.cache/kmscon-build/*

# Limpar cache antigo
./scripts/docker-cache-setup.sh cleanup soft

# Ou limpar tudo
./scripts/docker-cache-setup.sh cleanup all
```

### Build Paralelo Conflitando

**Sintoma**: Builds simultâneos causam corrupção

**Solução**:

- O sistema usa `flock` automaticamente
- Aumente `KMSCON_LOCK_TIMEOUT` para builds longos
- Use diretórios de cache separados para builds paralelos independentes

---

## Referência da API

### Comandos do Script de Setup

```bash
./scripts/docker-cache-setup.sh [COMANDO] [OPÇÕES]
```

| Comando          | Descrição                           |
| ---------------- | ----------------------------------- |
| `setup`          | Configuração completa (padrão)      |
| `setup-volume`   | Apenas volume Docker                |
| `setup-host`     | Apenas diretório no host            |
| `validate`       | Pré-validação do ambiente           |
| `cleanup [modo]` | Limpar cache (soft/hard/volume/all) |
| `status`         | Mostrar status do cache             |

### Opções do Build Script

```bash
./scripts/build-kmscon.sh [OPÇÕES]
```

| Opção              | Descrição                   |
| ------------------ | --------------------------- |
| `-h, --help`       | Mostrar ajuda               |
| `-v, --version`    | Mostrar versão              |
| `-k, --keep`       | Manter diretório de build   |
| `-c, --clean`      | Limpar cache antes de build |
| `-j, --jobs N`     | Número de jobs paralelos    |
| `-l, --log-level`  | Nível de log                |
| `-o, --output DIR` | Diretório de saída          |
| `--cache-only`     | Apenas verificar cache      |
| `--force-refresh`  | Forçar rebuild              |

### Docker Compose Profiles

| Profile   | Uso               |
| --------- | ----------------- |
| (default) | Build normal      |
| `inspect` | Inspecionar cache |
| `cleanup` | Limpar cache      |

---

## Dicas de Performance

### SSD para Cache

```bash
# Usar SSD rápido para cache
./scripts/docker-cache-setup.sh setup -d /mnt/fast-ssd/kmscon-cache
```

### Cache Compartilhado entre Projetos

```bash
# Usar mesmo cache para múltiplos projetos
export HOST_CACHE_DIR=/shared/kmscon-cache
```

### Network Cache (Avançado)

```bash
# NFS share para cache distribuído
sudo mount -t nfs server:/export/kmscon-cache /mnt/kmscon-cache
./scripts/docker-cache-setup.sh setup -d /mnt/kmscon-cache
```

---

## Changelog

### v2.0.0 (2026-01-31)

- Sistema de cache multi-camada implementado
- Suporte a Docker e CI/CD
- File locking com `flock`
- Manifest JSON com hashes SHA256
- TTL automático de cache

---

## Licença

Este sistema de cache é parte do projeto AURORA NAS e segue a mesma licença MIT.

## Suporte

Para relatórios de bugs ou sugestões, consulte o repositório do projeto.
