# Plano de Correção do Build da ISO

## Diagnóstico

A execução do `./build_live.sh` falha devido a problemas estruturais na navegação de diretórios e contexto de execução Docker.

### Problemas Identificados

1. **Contexto e Caminhos no Script (`build_live.sh`)**:
   - O script executa `cd live_build` e permanece lá.
   - O comando `rsync` subsequente falha porque tenta acessar `live_config` (que está no pai) como se estivesse dentro de `live_build`.
   - O comando `docker build` falha porque o contexto `.` agora é `live_build`, onde não existe o `Dockerfile` (que está na raiz).
   - A montagem do volume `-v "$(pwd)/live_build:/project"` falha logicamente porque `$(pwd)` já é `.../live_build`, tentando montar um subdiretório inexistente.

2. **Configuração de Locale no Dockerfile**:
   - As variáveis de ambiente `ENV LC_ALL=pt_BR.UTF-8` são definidas antes da geração do locale (`locale-gen`), o que causa avisos durante a instalação de pacotes.

## Solução Proposta

### 1. Refatoração do `build_live.sh`

O script será reescrito para operar principalmente a partir da raiz do projeto, garantindo consistência.

- **Segurança**: Adicionar `set -e` para abortar imediatamente em caso de erro.
- **Validação**: Verificar a existência de `live_config` antes de iniciar.
- **Limpeza**: Realizar a limpeza de `live_build` de forma segura (usando subshell ou caminhos explícitos), preservando diretórios de cache se existirem.
- **Build**: Executar `docker build` a partir da raiz.
- **Execução**: Executar `docker run` montando o diretório correto.

### 2. Ajuste do `Dockerfile`

- Mover a definição de `ENV LANG` e `ENV LC_ALL` para o final do arquivo, após a execução de `locale-gen`.
- Isso garante que o sistema só tente usar o locale português depois que ele estiver instalado e compilado.

### 3. Verificação do `entrypoint.sh`

- O arquivo atual contém `lb clean && lb build`. Isso é adequado.

## Passos de Execução

1. [ ] **Modificar `build_live.sh`**: Aplicar as correções de lógica de diretório e tratamento de erros.
2. [ ] **Modificar `Dockerfile`**: Reordenar instruções de locale.
3. [ ] **Validar**: Solicitar ao usuário que execute `./build_live.sh` novamente.

## Perguntas

- Existe algum motivo específico para a limpeza agressiva ("rm -rf tudo menos cache") em vez de confiar no `lb clean` dentro do container? (Assumirei que a limpeza externa é desejada para garantir um estado limpo, mas farei de forma segura).
