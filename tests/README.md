# 📖 Guia Completo: Testando a ISO e o Sistema Instalado

> **Este guia foi escrito para qualquer pessoa, mesmo sem experiência em Linux.**

---

## 📋 Resumo

O diretório `tests/` contém scripts para testar a ISO do projeto Aurora NAS.
O script principal é o **`vm-test.sh`** que faz TUDO automaticamente.

---

## 🚀 Início Rápido (1 Comando!)

### Testar a ISO Live (sistema que roda do CD)

```bash
./tests/vm-test.sh live
```

### Testar o Sistema Instalado (após instalar)

```bash
./tests/vm-test.sh installed
```

### Teste Automatizado (para agentes LLM)

```bash
./tests/vm-test.sh test-install
```

---

## 📚 Índice

1. [O que é cada script?](#-scripts-disponíveis)
2. [Como testar a ISO live](#-modo-1-testar-a-iso-live)
3. [Como testar o sistema instalado](#-modo-2-testar-o-sistema-instalado)
4. [Fluxo completo de teste](#-fluxo-completo-de-teste)
5. [Comandos auxiliares](#-comandos-auxiliares)
6. [Troubleshooting](#-problemas-comuns)
7. [Scripts especializados](#-scripts-especializados)

---

## 📁 Scripts Disponíveis

| Script                 | Propósito                                      |
| ---------------------- | ---------------------------------------------- |
| **`vm-test.sh`**       | ⭐ Script principal - faz tudo automaticamente |
| `generate-seed-iso.sh` | Gera ISO de configuração cloud-init            |
| `vm-diagnose.sh`       | Diagnóstico avançado via qemu-guest-agent      |
| `vm-capture-logs.sh`   | Captura logs da VM para análise                |

---

## 🧪 Modo 1: Testar a ISO Live

Use este modo para testar a imagem ISO recém-criada pelo live-build.

### Passo 1: Abrir o Terminal

- **Linux**: Pressione `Ctrl + Alt + T`
- **VS Code**: Pressione `` Ctrl + ` ``

### Passo 2: Navegar até o projeto

```bash
cd /home/helton/git/DEBIAN_ISO_PROJECT
```

### Passo 3: Executar o teste

```bash
./tests/vm-test.sh live
```

### O que acontece:

```
┌─────────────────────────────────────────────────────────┐
│  [1/4] Verifica dependências (virsh, qemu, etc.)        │
│  [2/4] Localiza a ISO em live_build/                    │
│  [3/4] Remove VM anterior (se existir)                  │
│  [4/4] Cria VM nova e inicia boot pela ISO              │
│        ↓                                                │
│        Aguarda 45 segundos                              │
│        ↓                                                │
│        Conecta você ao console Linux                    │
└─────────────────────────────────────────────────────────┘
```

### Você verá:

```
admin@debian-zfs-live:~$
```

**Parabéns! Você está dentro do sistema Linux live!** 🎉

---

## ✅ Modo 2: Testar o Sistema Instalado

Use este modo **APÓS** ter instalado o sistema usando o instalador.

### Pré-requisitos:

1. Você já executou `./tests/vm-test.sh live`
2. Você instalou o sistema usando o instalador
3. A instalação foi concluída com sucesso

### Executar:

```bash
./tests/vm-test.sh installed
```

### O que acontece:

```
┌─────────────────────────────────────────────────────────┐
│  [1/3] Verifica se a VM existe                          │
│  [2/3] Ejeta a ISO e configura boot pelo disco          │
│  [3/3] Inicia a VM                                      │
│        ↓                                                │
│        Aguarda 30 segundos                              │
│        ↓                                                │
│        Conecta você ao sistema instalado                │
└─────────────────────────────────────────────────────────┘
```

---

## 🤖 Modo 3: Teste Automatizado (para agentes LLM)

Este modo foi projetado para agentes de IA (LLMs) ou scripts automatizados testarem o instalador sem interação humana.

### O que faz:

1. Inicia a VM em modo live (sem conectar ao console)
2. Aguarda o QEMU Guest Agent ficar disponível
3. Injeta versão atualizada do `install-system` (se existir localmente)
4. Executa `install-system --auto` automaticamente
5. Monitora os logs em tempo real
6. Salva o log completo em `install-system-latest.log`

### Como usar:

```bash
./tests/vm-test.sh test-install
```

### Requisitos adicionais:

- `jq` (JSON processor) - para comunicação com QEMU Guest Agent

```bash
sudo apt install jq
```

### Sinônimos aceitos:

```bash
./tests/vm-test.sh test-install
./tests/vm-test.sh test
./tests/vm-test.sh auto
./tests/vm-test.sh --test
```

### Saída esperada:

```
🤖 TESTE AUTOMATIZADO DO INSTALADOR
Executa install-system --auto via QEMU Guest Agent

[1/4] Verificando dependências...
[2/4] Verificando ISO...
[3/4] Preparando ambiente...
[4/4] Criando VM e iniciando boot pela ISO...
    ✓ VM criada e iniciada
[5/7] Aguardando QEMU Guest Agent...
    ✓ Agente detectado!
[6/7] Disparando instalação automática...
[7/7] Monitorando instalação...
    (Pressione Ctrl+C para cancelar)
--- LOG START ---
...logs da instalação...
--- LOG END ---
    ✓ Instalação concluída com sucesso!
    ℹ Log completo salvo em install-system-latest.log
```

---

## 🔄 Fluxo Completo de Teste

                    ┌──────────────────────┐
                    │  Construir a ISO     │
                    │  build-live.sh       │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Testar ISO Live     │
                    │  vm-test.sh live     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Executar Instalador │
                    │  sudo aurora-install │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Sair do Console     │
                    │  Ctrl + ]            │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Testar Instalado    │
                    │  vm-test.sh installed│
                    └──────────────────────┘

````

### Comandos na Ordem

```bash
# 1. Construir a ISO (se ainda não fez)
./build-live.sh

# 2. Testar a ISO live
./tests/vm-test.sh live

# 3. Dentro da VM, executar o instalador
sudo aurora-installer

# 4. Sair do console (Ctrl + ])

# 5. Testar o sistema instalado
./tests/vm-test.sh installed
````

---

## 🔧 Comandos Auxiliares

### Ver status da VM

```bash
./tests/vm-test.sh --status
```

**Saída exemplo:**

```
Status da VM de Teste
─────────────────────────────────────
Nome:   debian-zfs-test
Estado: executando
Disco:  2,1G
ISO:    Não anexada (boot pelo disco)
```

### Parar a VM

```bash
./tests/vm-test.sh --stop
```

### Remover a VM completamente

```bash
./tests/vm-test.sh --remove
```

### Reconectar a uma VM que já está rodando

```bash
./tests/vm-test.sh --connect
```

### Ver ajuda completa

```bash
./tests/vm-test.sh --help
```

---

## 🔑 Credenciais de Acesso

| Campo       | Valor   |
| ----------- | ------- |
| **Usuário** | `admin` |
| **Senha**   | `admin` |

> 💡 Normalmente o login é automático (autologin)

---

## ⬅️ Como Sair do Console

Para sair do Linux e voltar ao seu terminal:

| Atalho     | Descrição                             |
| ---------- | ------------------------------------- |
| `Ctrl + ]` | Ctrl + colchete direito (recomendado) |
| `Ctrl + 5` | Alternativa                           |

---

## ❓ Problemas Comuns

### "ISO não encontrada"

```
Caminho esperado: live_build/live-image-amd64.hybrid.iso
```

**Solução:** Construa a ISO primeiro:

```bash
./build-live.sh
```

### "Dependências ausentes"

**Solução:** Instale os pacotes:

```bash
sudo apt install libvirt-clients virtinst qemu-system-x86 bsdutils
```

### "Tela em branco no console"

Isso é **normal**! Pressione `Enter` e o prompt aparecerá.

### "VM não encontrada" (modo installed)

Você precisa primeiro executar o modo `live` e instalar o sistema.

---

## 🔬 Scripts Especializados

Estes scripts são para casos específicos e não são necessários para o teste básico.

### `generate-seed-iso.sh`

Gera uma ISO de configuração cloud-init para injetar configurações na VM.

```bash
# Uso básico
./tests/generate-seed-iso.sh

# Com hostname customizado
./tests/generate-seed-iso.sh --hostname meuservidor

# Ver todas as opções
./tests/generate-seed-iso.sh --help
```

**Quando usar:** Quando precisar configurar automaticamente usuários, SSH keys ou rede na VM.

---

### `vm-diagnose.sh`

Executa comandos de diagnóstico na VM via qemu-guest-agent (sem precisar de rede ou SSH).

```bash
# Ping (verifica se agente está respondendo)
./tests/vm-diagnose.sh ping

# Informações de rede
./tests/vm-diagnose.sh network

# Informações do sistema
./tests/vm-diagnose.sh all

# Ver todas as opções
./tests/vm-diagnose.sh --help
```

**Quando usar:** Para diagnóstico avançado quando SSH não está funcionando.

---

### `vm-capture-logs.sh`

Captura logs da VM para análise de problemas.

```bash
# Captura completa
./tests/vm-capture-logs.sh

# Modo rápido
./tests/vm-capture-logs.sh --quick

# Ver todas as opções
./tests/vm-capture-logs.sh --help
```

**Quando usar:** Para investigar erros de boot ou problemas do sistema.

---

## 📊 Checklist de Validação

Use esta lista para validar a ISO:

### Teste Live (ISO)

- [ ] VM iniciou sem erros
- [ ] Sistema bootou até o prompt
- [ ] Autologin funcionou
- [ ] Comandos básicos funcionam (`ls`, `uname -a`)
- [ ] Rede está funcionando (`ip addr`)
- [ ] Sudo funciona (`sudo whoami`)
- [ ] Instalador está disponível (`which aurora-installer`)

### Teste Installed (Pós-instalação)

- [ ] Sistema bootou do disco
- [ ] Login funciona (se não tiver autologin)
- [ ] Sistema de arquivos ZFS está montado
- [ ] Serviços estão rodando
- [ ] Rede está configurada

---

## 📝 Referência Rápida

```bash
# Testar ISO (interativo para humanos)
./tests/vm-test.sh live

# Testar após instalação (interativo para humanos)
./tests/vm-test.sh installed

# Testar instalador (automatizado para LLMs)
./tests/vm-test.sh test-install

# Ver status
./tests/vm-test.sh --status

# Reconectar
./tests/vm-test.sh --connect

# Parar VM
./tests/vm-test.sh --stop

# Remover VM
./tests/vm-test.sh --remove

# Ajuda
./tests/vm-test.sh --help
```

---

_Atualizado em: 2026-02-01_
_Script principal: `tests/vm-test.sh`_
