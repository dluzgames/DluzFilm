# Dluz Film v2.0 — Documento Mestre do Projeto (Project.md)

> **Documento Oficial de Arquitetura, Recursos, IA e Compilação**  
> **Versão:** 2.0.0 (Lançamento Oficial)  
> **Repositório Oficial:** [https://github.com/dluzgames/DluzFilm](https://github.com/dluzgames/DluzFilm)  
> **Repositório Base (Upstream):** [https://github.com/CutWire-Studios/Drift](https://github.com/CutWire-Studios/Drift)  
> **Última Atualização:** 17 de Setembro de 2026  

---

## 1. Visão Geral e Identidade do Produto

O **Dluz Film** é uma suíte profissional de edição de vídeo, timeline não-linear e automação com Inteligência Artificial desenvolvida pela **DLuz Games**, originada como uma evolução do projeto de código aberto *Drift* (da *CutWire Studios*).

Esta distribuição mantém a compatibilidade com o ecossistema original, mas acrescenta uma camada completa de **orquestração de agentes de IA**, geração autônoma de conteúdo, recursos avançados de linha do tempo, aceleração por hardware NVIDIA e identidade visual exclusiva baseada no sistema **Google Stitch**.

### Metadados e Branding
- **Nome Oficial:** Dluz Film
- **Versão:** `2.0.0` (Tag Git: `v2.0` e `v2.0.0`)
- **Identificador de Janela / Processo:** `Dluz Film.exe`
- **Identificador QML / Engine:** Módulo `Drift` (preservado para compatibilidade binária)
- **Extensão de Projeto:** `.drift` (garante abertura de projetos do ecossistema upstream)
- **Identificador macOS / Android:** `com.dluz.dluzfilm`
- **Idioma Padrão:** Português do Brasil (`pt_BR`) com mais de 2.000 mensagens localizadas.
- **Paleta de Cores Oficial:**
  - **Vermelho DLuz (Primary):** `#E50914` (Acentos de foco, reprodução, botões principais)
  - **Dourado / Âmbar (Accent):** `#F59E0B` (Alertas VIP, status do OmniRouter, destaques)
  - **Fundo Ônix Escuro:** `#0d0f12` e `#15181d` (Painéis, header e timeline)
  - **Verde Acento (Timeline):** Barra de título de clipes de vídeo em verde `#10b981` para rápido contraste visual.

---

## 2. Pilha de Tecnologias (Tech Stack)

| Camada | Tecnologia | Detalhes de Implementação |
| :--- | :--- | :--- |
| **Linguagem Principal** | C++20 | ISO C++20 com MSVC 2022 (x64) no Windows |
| **Interface Gráfica (UI)** | Qt 6.10.3 / Qt Quick (QML) | Renderização via Scene Graph sobre OpenGL 3.3 Core |
| **Processamento de Áudio** | JUCE DSP + SoundTouch | Processamento de efeitos, equalizadores dinâmicos e pitch/time stretch |
| **Decodificação & Encode** | FFmpeg 6.x / 7.x | Suporte completo a decodificação HW (D3D11VA, CUDA) e encode NVENC (`h264_nvenc`) |
| **Aceleração Gráfica** | OpenGL 3.3 Core Profile | Compartilhamento de texturas zero-copy entre thread do compositor e Qt Quick |
| **Inteligência Artificial (Local)** | Python 3.11 + Whisper / OmniVoice | Executado na GPU NVIDIA RTX 2060 (CUDA) |
| **Inteligência Artificial (Hub)** | OmniRouter (9Router) | API OpenAI-compatível em `https://9router.dluz.com.br/v1` com otimização RTK |
| **Automação Externa** | Model Context Protocol (MCP) | Servidor JSON-RPC via HTTP (porta dinâmica) e Stdio (`--mcp-stdio`) |
| **Build & Empacotamento** | CMake 3.21+ / MSBuild | Visual Studio 2022 Build Tools e vcpkg (`zstd`, `openssl`, `soundtouch`) |

---

## 3. Arquitetura de Inteligência Artificial & Multi-Agente (v2.0)

A versão 2.0 introduziu a arquitetura **Dluz Multi-Agent Engine**, acessível pelo atalho no cabeçalho ou pela tecla de atalho.

### 3.1 Hub Central OmniRouter (9Router)
- **Endpoint:** `https://9router.dluz.com.br/v1`
- O OmniRouter atua como gateway neural unificado da DLuz Games, permitindo que o editor acesse os modelos de maior inteligência do mercado (Claude 3.5 Sonnet, GPT-4o, Gemini 2.5 Flash/Pro, DeepSeek R1, Groq, Kimi) com balanceamento de carga automático e cache semântico de tokens.
- **Destaque VIP na UI:** Aba 4 do diálogo exibe um card azul/ouro exclusivo com ativação de 1 clique.

### 3.2 Estrutura Multi-Agente por Função
O usuário pode alternar entre dois modos operacionais:
1. **Modo Maestro (Default):** O modelo principal configurado no OmniRouter toma todas as decisões de edição, cortes, gráficos e áudio.
2. **Equipe Especializada (Multi-Agente Ativo):** O editor divide as tarefas em 3 agentes autônomos dedicados:
   - 🎬 **Agente de Cortes & Linha do Tempo:** Focado em remover silêncios, sincronizar cortes nas batidas da música e aplicar ritmo acelerado sem pausas mortas.
   - 🎨 **Agente de HyperFrames & Gráficos:** Especializado em criar Title Cards cinéticos, lower-thirds estilizados, overlays e elementos visuais com animações GSAP e transições de câmera.
   - 🎙️ **Agente de Áudio & Narração:** Focado em escrever scripts dinâmicos começando no segundo 0 com gancho imediato, bordão oficial (*"Fala melhores, beleza?"*), síntese de voz OmniVoice clonada (`dluz_voice.pt`) e trilha sonora adaptativa.

### 3.3 Integração com Ferramentas de Linha de Comando (CLIs)
A interface do assistente permite despachar comandos para os agentes instalados no sistema operacional:
- **🚀 Antigravity CLI (`agy`):** Geração de código e componentes HyperFrames em segundo plano.
- **💻 OpenAI Codex CLI (`codex`):** Manipulação de código e automações estruturadas.
- **⚡ OpenCode CLI (`opencode`):** Processamento em lote e manipulação de arquivos de projeto.

### 3.4 Persistência e Segurança de Chaves
- **No PC do Usuário:** Todas as chaves e provedores são gravados no Registro do Windows:
  `HKEY_CURRENT_USER\Software\Dluz Film\Dluz Film\ai`
- **No Repositório Git:** O código-fonte enviado para o GitHub é 100% livre de segredos hardcoded (usa chaves sanitizadas `"sk-..."`), prevenindo vazamento de credenciais.

---

## 4. Módulos & Ferramentas Exclusivas do Dluz Film

### 4.1 ⚡ Modo Hard (Produção Autônoma por Link)
- **Arquivo de Orquestração:** `scripts/dluz_auto_producer.py`
- **Fluxo Operacional:**
  1. O usuário cola o link de qualquer matéria, notícia ou postagem (ex: portal Dluz News).
  2. O script extrai o texto, remove anúncios e resume em roteiro dinâmico.
  3. Gera o áudio com a voz oficial da DLuz Games usando **OmniVoice CUDA** (`speed=1.15`, sem cortes).
  4. Baixa vídeos contextuais de gameplay em alta resolução via `yt-dlp`.
  5. Monta a linha do tempo, divide cenas a cada 2-3 segundos, aplica legendas dinâmicas e overlays **HyperFrames**.
  6. Injeta o projeto montado diretamente na timeline do editor aberta.

### 4.2 💬 Legendas Dinâmicas Estilo MrBeast
- **Diálogo:** `src/qml/components/DynamicSubtitlesDialog.qml`
- **Script:** `scripts/dynamic_subtitles_generator.py`
- Transcrição do áudio com timestamps palavra por palavra usando Whisper.
- Presets estilizados: Amarelo Ouro com borda preta grossa, Verde Neon, efeito Pop-in e rotação cinética.

### 4.3 ✂️ Removedor Inteligente de Silêncio
- **Diálogo:** `src/qml/components/SilenceRemoverDialog.qml`
- Analisa o envelope de decibéis da faixa de voz.
- Corta cirurgicamente todos os trechos com volume abaixo do limiar (ex: `-35 dB` por mais de `200ms`), colando os clipes com atração magnética para manter ritmo acelerado.

### 4.4 🌍 Dublagem Automática Multi-Idioma
- Suporte a localização entre **Português, Inglês, Espanhol e Mandarim (Chinês)**.
- Reconhecimento de fala, tradução contextual, time-stretch para sincronia labial e clonagem vocal com Edge-TTS e OmniVoice.

### 4.5 🟩 Auto Chroma Key
- Clipes de HyperFrames com fundo verde ou preto injetados na timeline recebem automaticamente o filtro de transparência Chroma Key configurado, sem exigir ajuste manual pelo usuário.

### 4.6 🧲 Atração Magnética & Fechamento de Gaps
- Métodos C++ `AppController::snapClipTime` e `AppController::closeAllGaps`.
- Elimina com 1 clique todos os espaços vazios deixados entre clipes na linha do tempo.

---

## 5. Servidor MCP Integrado (Model Context Protocol)

O Dluz Film possui um servidor MCP embutido que permite que o **Hermes Agent**, **Antigravity** ou qualquer cliente MCP controle a linha do tempo:

- **Modo Conectado (GUI Ativa):** Comunicação local via WebSocket/HTTP. Os comandos editam a timeline em tempo real na tela do usuário.
- **Modo Headless (`--mcp-stdio`):** Quando a GUI está fechada, o binário pode ser executado em segundo plano via Stdio JSON-RPC (`Dluz Film.exe --mcp-stdio`) para inspecionar mídias, ler catálogos e realizar edições programáticas.
- **Ferramentas MCP Disponíveis:**
  - `catalog`: Lista todos os efeitos, transições e mídias do projeto.
  - `toolbox`: Executa comandos de inserção, corte, remoção, split e movimentação de clipes.
  - `inspect`: Retorna o estado atual da timeline (faixas, clipes, durações e propriedades).
  - `apply`: Aplica efeitos, filtros de cor, keyframes e transformações.
  - `capture`: Captura frames do preview em alta resolução para inspeção por IA.

---

## 6. Soluções de Bugs Críticos Aplicadas na Versão 2.0

### 6.1 Correção do Carregamento do QML (Editor não abria)
- **Causa:** `AiAgentDialog.qml` usava propriedade inexistente `size: "sm"` e variante inválida `variant: "outline"` em `ThemedButton`.
- **Sintoma:** O motor Qt Quick abortava com `QQmlApplicationEngine failed to load component`, impedindo a janela de aparecer.
- **Correção:** Remoção de `size: "sm"` e substituição de `"outline"` por `"secondary"`. O QML agora carrega com zero erros.

### 6.2 Eliminação Total de Processos Zumbis ao Fechar
- **Causa:** O evento `onClosing` de `Main.qml` aceitava o fechamento visual da janela mas não invocava `Qt.quit()`. No C++, o sinal `engine.quit` não estava conectado a `QCoreApplication::quit`. Threads do JUCE DSP e listeners MCP mantinham o executável rodando invisível, acumulando instâncias de ~300 MB de RAM.
- **Correção:**
  1. `Main.qml`: Adicionado `Qt.quit()` em todas as saídas de fechamento.
  2. `src/main.cpp`: Conectado `engine.quit` e `lastWindowClosed` diretamente a `QCoreApplication::quit`.
  3. `src/main.cpp`: Inserida chamada direta à API Win32 `ExitProcess(exitCode)` ao final de `main()`, garantindo que todas as threads em segundo plano sejam finalizadas instantaneamente.

---

## 7. Estrutura de Diretórios do Repositório

```text
H:\Editor dluz\
├── .agents/                 Configurações de agentes locais
├── .github/                 Workflows de CI/CD para compilação e releases
├── android/                 Código e manifesto para versão Android
├── audio-effects/           Pacotes de efeitos de áudio nativos (JUCE)
├── cmake/                   Módulos e regras de compilação CMake
├── docs/                    Documentação do projeto original
├── effect-templates/        Modelos prontos de efeitos
├── effects/                 Shaders GLSL e filtros de vídeo
├── flatpak/                 Manifesto de distribuição Linux Flatpak
├── i18n/                    Catálogos de tradução do Qt (.ts e .qm)
│   └── drift_pt_BR.ts       Catálogo oficial em Português do Brasil
├── installer/windows/       Scripts de empacotamento Inno Setup
├── packaging/               Assets e ícones de empacotamento
├── resources/               Fontes (InterUI), ícones SVG e cursores
├── scripts/                 Scripts de automação, IA e build
│   ├── dluz_auto_producer.py           Pipeline do Modo Hard
│   ├── dynamic_subtitles_generator.py  Gerador de legendas MrBeast
│   ├── omniflash_clip_editor.py        Editor de clipes OmniFlash
│   └── timeline_ai_editor.py           Editor assistido de timeline
├── src/                     Código-fonte em C++ e QML
│   ├── core/                Estrutura de dados: Project, Track, Clip, Commands
│   ├── engine/              Motor de renderização, GlRuntime, FFmpeg, Exporter
│   ├── mcp/                 Servidor Model Context Protocol (HTTP e Stdio)
│   ├── models/              Controllers C++ expostos ao QML (AppController, AiAgentController)
│   ├── playback/            Engine de reprodução e sincronia de áudio/vídeo
│   ├── preview/             PreviewItem e renderização do canvas
│   ├── qml/                 Telas e componentes de interface gráfica
│   │   ├── components/      Diálogos (AiAgentDialog, DynamicSubtitles, etc.)
│   │   ├── Main.qml         Janela desktop principal
│   │   └── Theme.qml        Design tokens, cores DLuz e tipografia
│   ├── HeadlessApp.cpp      Execução em modo headless
│   └── main.cpp             Ponto de entrada do programa
├── tests/                   Suíte de testes automatizados
├── tools/                   Ferramentas utilitárias
├── transitions/             Pacotes de transições de vídeo
├── CHANGELOG.md             Histórico detalhado de versões
├── CMakeLists.txt           Configuração mestre de compilação
├── project.md               Este documento mestre
└── README.md                Apresentação pública do projeto
```

---

## 8. Pipeline de Compilação no Windows (Guia Rápido)

### 8.1 Ambientes e Caminhos
- **Pasta Raiz do Código (Repositório Git):** `H:\Editor dluz`
- **Junction para Compilação sem Espaços:** `D:\DluzEditorSource`
- **Diretório de Build (MSBuild x64):** `D:\DluzEditorBuild2`
- **Executável Gerado:** `D:\DluzEditorBuild2\Release\Dluz Film.exe`
- **Atalho da Área de Trabalho:** `C:\Users\dluzgg\Desktop\Dluz Film.lnk`

### 8.2 Sincronizar Código e Compilar em Release

Para compilar qualquer alteração do código:

```powershell
# 1. Sincronizar arquivos para o diretório de build
Copy-Item "H:\Editor dluz\src\*" "D:\DluzEditorSource\src\" -Recurse -Force
Copy-Item "H:\Editor dluz\CMakeLists.txt" "D:\DluzEditorSource\CMakeLists.txt" -Force

# 2. Compilar no CMake / MSBuild em Release
cmake --build D:\DluzEditorBuild2 --config Release --target drift

# 3. Encerrar processos antigos se estiverem abertos
Stop-Process -Name "Dluz Film" -Force -ErrorAction SilentlyContinue

# 4. Atualizar o binário final
Copy-Item "D:\DluzEditorBuild2\Release\drift.exe" "D:\DluzEditorBuild2\Release\Dluz Film.exe" -Force
```

---

## 9. Guia de Atualizações Futuras do Upstream

Quando for conveniente avaliar novas atualizações vindas do repositório original `CutWire-Studios/Drift`:

1. **Nunca realizar merge direto sem isolamento:**
   Crie sempre uma branch separada para teste:
   ```powershell
   git checkout -b test-upstream-sync
   git fetch upstream
   git merge upstream/main
   ```
2. **Arquivos que exigem atenção cuidadosa durante resolução de conflitos:**
   - `CMakeLists.txt`: Preservar todos os diálogos de IA (`AiAgentDialog.qml`, `DynamicSubtitlesDialog.qml`, `HyperframesStudioDialog.qml`, etc.) e os scripts Python em `QML_FILES`.
   - `src/main.cpp`: Manter a inicialização do `AiAgentController`, branding "Dluz Film", conexão `engine.quit` e o encerramento seguro com `ExitProcess()`.
   - `src/models/AppController.cpp`: Preservar os métodos de atração magnética (`snapClipTime`), remoção com ripple (`closeAllGaps`) e exportador padrão NVENC.
   - `src/qml/EditorHeader.qml` e `AssetsPanel.qml`: Manter os botões da barra superior de IA, HyperFrames e as abas personalizadas.
3. **Validação:** Compilar em Release e testar a abertura limpa e o encerramento sem processos zumbis antes de enviar para a branch `main`.

---

*Dluz Film v2.0 — Criado e mantido com orgulho pela equipe DLuz Games.*
