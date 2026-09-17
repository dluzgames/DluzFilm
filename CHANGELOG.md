# Dluz Film — Changelog de Lançamentos

**Versão Atual:** `2.0.0`

---

## 🚀 Versão 2.0.0 (Lançamento Oficial)

### ✨ Novas Funcionalidades
- **Integração Nativa com OmniRouter (9Router):** Suporte completo ao hub neural oficial da DLuz Games (`https://9router.dluz.com.br/v1`) com chave mestra pré-configurada, roteamento inteligente e economia de tokens RTK.
- **Arquitetura de Equipe Multi-Agente:**
  - **Modo Default (Maestro):** O modelo principal configurado cuida de todas as decisões e orquestração do vídeo.
  - **Equipe Especializada (1 IA para cada Função):** Atribuição dedicada de modelos e provedores específicos para:
    - 🎬 **Agente de Cortes & Timeline:** Detecção de silêncio, splits em beats e ritmo de edição.
    - 🎨 **Agente de HyperFrames & Gráficos:** Criação e renderização de Title Cards, Lower-Thirds e animações cinéticas.
    - 🎙️ **Agente de Áudio & Narração:** Roteiro com bordão oficial ("Fala melhores, beleza?"), síntese OmniVoice CUDA e trilha sonora adaptativa.
- **Nova Interface de 4 Abas (Google Stitch):**
  - Chat & Assistente IA
  - ⚡ Modo Hard (Produção Autônoma por Link)
  - 🤖 Equipe de IAs & Funções (Multi-Agente)
  - ⚙️ Modelos & Provedores (com destaque VIP para OmniRouter)
- **Aceleração por Hardware NVENC na Exportação:** Exportador FFmpeg configurado para priorizar GPU NVIDIA por padrão.
