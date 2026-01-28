# Reestruturação: live_config e live_build

O projeto agora utilizará `live_config` como a fonte de configurações do `live-build` e `live_build` como o diretório temporário de trabalho durante a geração da ISO.

## Mudanças Estruturais

- `live/` -> Removido.
- `live_config/` -> Contém a estrutura original de `live/` (`auto/`, `config/`).
- `live_build/` -> Diretório onde o comando `lb build` será executado.

## Impacto nos Scripts

- `build_live.sh`: Deve preparar o diretório `live_build` copiando `live_config` para dentro dele antes de iniciar o Docker.
- `Dockerfile`: Ajustar diretórios de trabalho se necessário.
- `install-system` e outros scripts: Garantir que os caminhos internos na ISO (chroot) permaneçam consistentes.
