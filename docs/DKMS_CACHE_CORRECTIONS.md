# Correções de Gaps Críticos na Implementação de Cache DKMS

## Resumo Executivo

Este documento detalha as correções implementadas para resolver **7 gaps críticos** identificados na solução de cache persistente DKMS (especificamente para zfs-dkms) durante builds de ISO Debian Trixie via live-build.

---

## Gaps Corrigidos

### 1. Problema de ccache com Paths Absolutos ✅

**Problema Identificado:**
O ccache usa hash de pré-processamento, mas módulos DKMS incluem paths absolutos do chroot que mudam a cada build (ex: `/tmp/tmp.XXXXXX/chroot/...`). Isso invalida o cache mesmo quando o código-fonte é idêntico.

**Solução Implementada:**

- **Arquivo:** [`/etc/dkms/ccache.conf`](live_config/config/includes.chroot/etc/dkms/ccache.conf)
- Configurações críticas adicionadas:
  ```
  base_dir = /var/lib/dkms
  no_hash_dir = true
  sloppiness = include_file_mtime, time_macros, pch_defines
  ```

**Hook de Configuração:**

- **Arquivo:** [`0500-setup-dkms-cache.chroot`](live_config/config/hooks/normal/0500-setup-dkms-cache.chroot)
- Exporta variáveis de ambiente:
  ```bash
  export CCACHE_BASEDIR="/var/lib/dkms"
  export CCACHE_NOHASHDIR="1"
  export CCACHE_SLOPPINESS="include_file_mtime,time_macros,pch_defines"
  ```

**Como Funciona:**

1. `CCACHE_BASEDIR` normaliza paths absolutos para relativos antes do hash
2. `CCACHE_NOHASHDIR` desabilita hash do diretório de compilação
3. `CCACHE_SLOPPINESS` permite variações em timestamps e macros de tempo

---

### 2. Limpa do Chroot pelo live-build ✅

**Problema Identificado:**
`lb clean --purge` remove `/var/lib/dkms` mesmo com bind mounts. O `entrypoint.sh` original executava `lb clean && lb build` sem proteção ao cache.

**Solução Implementada:**

- **Arquivo:** [`entrypoint.sh`](entrypoint.sh) (reescrito)
- **Estratégia de Preservação:**
  1. **Fase Pre-Clean:** Copia cache para diretório temporário fora do chroot
  2. **Execução do Clean:** Roda `lb clean` normalmente
  3. **Fase Pós-Clean:** Restaura cache do diretório temporário

**Funções Principais:**

- `preserve_cache_before_clean()` - Salva cache em `/tmp/dkms-cache-preserve`
- `restore_cache_after_clean()` - Restaura cache após limpeza
- `selective_clean()` - Alternativa: limpeza seletiva sem remover cache

**Modos de Operação:**

```bash
# Padrão: Preserva cache automaticamente
./entrypoint.sh

# Limpeza seletiva (preserva cache)
./entrypoint.sh --selective-clean

# Sem limpeza (build incremental)
./entrypoint.sh --no-clean
```

---

### 3. Hooks Incompletos ✅

**Problema Identificado:**
Apenas hooks `.chroot` foram considerados. Faltavam hooks `bootstrap` para preparação e hooks para garantir preservação dos módulos compilados.

**Solução Implementada:**

#### Hook Bootstrap (Preparação)

- **Arquivo:** [`0001-dkms-cache-bootstrap.bootstrap`](live_config/config/hooks/bootstrap/0001-dkms-cache-bootstrap.bootstrap)
- **Prioridade:** 0001 (execução precoce)
- **Responsabilidades:**
  1. Cria estrutura de diretórios de cache no host
  2. Configura bind mounts para persistência
  3. Verifica e prepara ccache
  4. Valida correspondência de kernel headers
  5. Gera relatório de bootstrap

#### Hook Chroot (Configuração)

- **Arquivo:** [`0500-setup-dkms-cache.chroot`](live_config/config/hooks/normal/0500-setup-dkms-cache.chroot)
- **Prioridade:** 0500 (antes de builds)
- **Responsabilidades:**
  1. Configura variáveis de ambiente ccache
  2. Cria wrappers de compilador
  3. Configura framework.conf do DKMS
  4. Instala hooks de build DKMS

#### Hook Pós-Build (Preservação)

- **Arquivo:** [`9999-preserve-dkms-modules.chroot`](live_config/config/hooks/normal/9999-preserve-dkms-modules.chroot)
- **Prioridade:** 9999 (após todos os builds)
- **Responsabilidades:**
  1. Detecta módulos DKMS compilados
  2. Preserva no cache persistente
  3. Gera checksums e metadados
  4. Valida integridade

---

### 4. Validação de Integridade Ausente ✅

**Problema Identificado:**
Sem verificação se arquivos `.ko` não estão truncados/corrompidos. Sem checagem de `vermagic` do módulo vs kernel.

**Solução Implementada:**

- **Arquivo:** [`dkms-cache-validator.sh`](live_config/config/includes.chroot/usr/local/share/dkms-cache/dkms-cache-validator.sh)

**Validações Implementadas:**

1. **Integridade do Arquivo (.ko)**
   - Verifica magic number ELF (`0x7f454c46`)
   - Valida que arquivo não está vazio ou truncado
   - Executa `modinfo` para garantir legibilidade

2. **Vermagic (Compatibilidade de Kernel)**

   ```bash
   validate_vermagic() {
       local ko_file="$1"
       local expected_kernel="$2"
       local module_vermagic=$(modinfo -F vermagic "$ko_file")
       # Compara versão do kernel no vermagic
   }
   ```

3. **Checksums**
   - Gera SHA256 para cada módulo
   - Valida contra checksum armazenado
   - Arquivos `.sha256` acompanhando cada `.ko`

4. **Dependências**
   - Verifica se dependências declaradas estão disponíveis
   - Warning (não erro) para dependências ausentes

**Comandos Disponíveis:**

```bash
# Validar arquivo único
dkms-cache-validator.sh validate-file /path/to/module.ko

# Validar cache de um módulo
dkms-cache-validator.sh validate-cache zfs-dkms 2.2.7

# Validar todo o cache
dkms-cache-validator.sh validate-all

# Gerar checksums
dkms-cache-validator.sh generate /path/to/modules/
```

---

### 5. Kernel Headers Mismatch ✅

**Problema Identificado:**
Headers instalados podem não corresponder ao kernel da ISO. Builds de DKMS falham silenciosamente ou geram módulos incompatíveis.

**Solução Implementada:**

#### No Hook Bootstrap

- **Arquivo:** [`0001-dkms-cache-bootstrap.bootstrap`](live_config/config/hooks/bootstrap/0001-dkms-cache-bootstrap.bootstrap)
- **Função:** `verify_kernel_headers()`
- Ações:
  1. Detecta versão do kernel via `apt-cache show linux-headers-amd64`
  2. Extrai versão dos headers disponíveis
  3. Salva em `${CACHE_BASE_DIR}/.kernel-version`

#### No Hook Chroot

- **Arquivo:** [`0500-setup-dkms-cache.chroot`](live_config/config/hooks/normal/0500-setup-dkms-cache.chroot)
- **Função:** `ensure_kernel_headers_match()`
- Ações:
  1. Detecta versão atual do kernel
  2. Verifica existência de headers em `/lib/modules/${kernel}/build`
  3. Alerta sobre mismatches

#### Fallback Implementado

```bash
if [[ ! -d "/lib/modules/${kernel_version}/build" ]]; then
    log_warn "Headers não encontrados para kernel: $kernel_version"
    # Tenta encontrar headers disponíveis
    find /usr/src -name "linux-headers-*" -type d
fi
```

---

### 6. Concorrência em Builds Paralelos ✅

**Problema Identificado:**
Risco de corrupção de cache sem file locking quando múltiplos builds acessam o cache simultaneamente.

**Solução Implementada:**

- **Arquivo:** [`dkms-cache-manager.sh`](live_config/config/includes.chroot/usr/local/share/dkms-cache/dkms-cache-manager.sh)

**Mecanismos de Locking:**

1. **Lock Global**

   ```bash
   acquire_lock "global"
   # Operações críticas
   release_lock "$lock_fd"
   ```

2. **Lock por Módulo**

   ```bash
   # Cada módulo tem seu próprio lock
   acquire_lock "zfs-dkms"
   # Operações no cache de zfs-dkms
   release_lock "$lock_fd"
   ```

3. **Timeout Configurável**

   ```bash
   readonly LOCK_TIMEOUT="${DKMS_LOCK_TIMEOUT:-300}"  # 5 minutos
   flock -w "$timeout" -x "$lock_fd"
   ```

4. **Wrapper Conveniente**
   ```bash
   with_lock "module-name" operation_command
   ```

**Proteções Implementadas:**

- Timeout evita deadlocks
- Locks automáticos em operações de cache
- Cleanup de locks stale

---

### 7. Variáveis Críticas Ausentes ✅

**Problema Identificado:**
`CCACHE_SLOPPINESS=include_file_mtime,time_macros` não estava configurada, resultando em cache misses desnecessários.

**Solução Implementada:**

#### Configuração ccache Completa

- **Arquivo:** [`/etc/dkms/ccache.conf`](live_config/config/includes.chroot/etc/dkms/ccache.conf)

```ini
# Variáveis Críticas para DKMS
base_dir = /var/lib/dkms
no_hash_dir = true
sloppiness = include_file_mtime, time_macros, pch_defines

# Performance
max_size = 10.0G
compression = true
compression_level = 6
cache_dir_levels = 3

# Logging
log_file = /var/cache/dkms-build/ccache/ccache.log
stats = true

# Ignora opções que não afetam código gerado
ignore_options = -fdebug-prefix-map=* -ffile-prefix-map=* -fmacro-prefix-map=*
```

#### Framework DKMS

- **Arquivo:** `/etc/dkms/framework.conf` (modificado por hook)
- Adiciona:
  ```bash
  export CCACHE_SLOPPINESS="include_file_mtime,time_macros,pch_defines"
  MAKE[0]="make -j$(nproc) CC='ccache gcc' CXX='ccache g++'"
  ```

**Significado das Variáveis:**

- `include_file_mtime`: Ignora mudanças no mtime de headers (kernel headers mudam mtime sem mudar conteúdo)
- `time_macros`: Permite que `__TIME__` e `__DATE__` variem sem invalidar cache
- `pch_defines`: Suporte a headers pré-compilados do kernel

---

## Arquivos Criados/Modificados

### Scripts de Gerenciamento

| Arquivo                                                                                                            | Descrição                               |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------- |
| [`dkms-cache-manager.sh`](live_config/config/includes.chroot/usr/local/share/dkms-cache/dkms-cache-manager.sh)     | Gerenciamento de cache com file locking |
| [`dkms-cache-validator.sh`](live_config/config/includes.chroot/usr/local/share/dkms-cache/dkms-cache-validator.sh) | Validação de integridade de módulos     |
| [`dkms-integration.sh`](live_config/config/includes.chroot/usr/local/share/dkms-cache/dkms-integration.sh)         | Script de integração unificado          |

### Hooks

| Arquivo                                                                                                         | Tipo      | Prioridade | Descrição                           |
| --------------------------------------------------------------------------------------------------------------- | --------- | ---------- | ----------------------------------- |
| [`0001-dkms-cache-bootstrap.bootstrap`](live_config/config/hooks/bootstrap/0001-dkms-cache-bootstrap.bootstrap) | Bootstrap | 0001       | Preparação do cache antes do chroot |
| [`0500-setup-dkms-cache.chroot`](live_config/config/hooks/normal/0500-setup-dkms-cache.chroot)                  | Chroot    | 0500       | Configuração de ccache e DKMS       |
| [`9999-preserve-dkms-modules.chroot`](live_config/config/hooks/normal/9999-preserve-dkms-modules.chroot)        | Chroot    | 9999       | Preservação após build              |

### Configurações

| Arquivo                                                                            | Descrição                           |
| ---------------------------------------------------------------------------------- | ----------------------------------- |
| [`/etc/dkms/ccache.conf`](live_config/config/includes.chroot/etc/dkms/ccache.conf) | Configuração otimizada do ccache    |
| [`entrypoint.sh`](entrypoint.sh)                                                   | Entrypoint com preservação de cache |

### Documentação

| Arquivo                                                            | Descrição      |
| ------------------------------------------------------------------ | -------------- |
| [`docs/DKMS_CACHE_CORRECTIONS.md`](docs/DKMS_CACHE_CORRECTIONS.md) | Este documento |

---

## Fluxo de Execução

```
┌─────────────────────────────────────────────────────────────────────┐
│                        BUILD DE ISO                                 │
└─────────────────────────────────────────────────────────────────────┘

FASE 1: BOOTSTRAP (fora do chroot)
┌─────────────────────────────────────────┐
│ 0001-dkms-cache-bootstrap.bootstrap     │
│   ├── Cria estrutura de diretórios      │
│   ├── Configura bind mounts             │
│   ├── Verifica ccache                   │
│   └── Valida kernel headers             │
└─────────────────────────────────────────┘
                    │
                    ▼
FASE 2: CHROOT SETUP
┌─────────────────────────────────────────┐
│ 0500-setup-dkms-cache.chroot            │
│   ├── Exporta CCACHE_* variáveis        │
│   ├── Cria wrappers de compilador       │
│   ├── Configura framework.conf          │
│   └── Instala hooks DKMS                │
└─────────────────────────────────────────┘
                    │
                    ▼
FASE 3: BUILD DE PACOTES (incluindo DKMS)
┌─────────────────────────────────────────┐
│ Durante build de zfs-dkms:              │
│   ├── ccache intercepta compilações     │
│   ├── DKMS usa cache se disponível      │
│   └── Módulos compilados em /var/lib/dkms
└─────────────────────────────────────────┘
                    │
                    ▼
FASE 4: PRESERVAÇÃO
┌─────────────────────────────────────────┐
│ 9999-preserve-dkms-modules.chroot       │
│   ├── Detecta módulos compilados        │
│   ├── Valida integridade                │
│   ├── Gera checksums                    │
│   └── Copia para cache persistente      │
└─────────────────────────────────────────┘
```

---

## Uso

### Build Normal (com cache)

```bash
./build_live.sh
```

### Build com Preservação Explícita

```bash
PRESERVE_DKMS_CACHE=1 ./build_live.sh
```

### Build sem Cache

```bash
DKMS_CACHE_ENABLED=0 ./build_live.sh
```

### Verificar Status do Cache

```bash
# No chroot ou no host se cache montado
dkms-cache-manager.sh stats
dkms-cache-validator.sh validate-all
```

### Limpar Cache Antigo

```bash
# Remove entradas com mais de 30 dias
dkms-cache-manager.sh cleanup 30

# Limpa todo o cache ccache
CCACHE_DIR=/var/cache/dkms-build/ccache ccache -C
```

---

## Troubleshooting

### Cache Não Está Sendo Usado

1. Verifique variáveis de ambiente:

   ```bash
   echo $CCACHE_DIR
   echo $CCACHE_BASEDIR
   ```

2. Verifique se ccache está funcionando:

   ```bash
   ccache -s
   ```

3. Verifique logs:
   ```bash
   tail /var/cache/dkms-build/ccache/ccache.log
   ```

### Módulos Inválidos Detectados

1. Valide manualmente:

   ```bash
   dkms-cache-validator.sh validate-all
   ```

2. Limpe cache inválido:
   ```bash
   dkms-cache-manager.sh invalidate zfs-dkms 2.2.7
   ```

### Lock Timeouts

1. Aumente timeout:

   ```bash
   export DKMS_LOCK_TIMEOUT=600
   ```

2. Verifique locks existentes:
   ```bash
   ls -la /var/cache/dkms-build/.locks/
   ```

---

## Métricas de Sucesso

- **Cache Hits:** `ccache -s` deve mostrar hits crescentes
- **Tempo de Build:** Redução de 60-80% em builds subsequentes
- **Integridade:** Zero módulos corrompidos (validado por `dkms-cache-validator.sh`)
- **Concorrência:** Nenhum erro de corrupção de cache em builds paralelos

---

## Compatibilidade

- **Debian:** Trixie (testing) e posteriores
- **DKMS:** 3.0.12+ (verificado automaticamente)
- **ccache:** 3.7+ (recomendado 4.0+)
- **Kernel:** Linux 6.x

---

_Documento gerado em: $(date -Iseconds)_
_Versão: 1.0.0_
