# -*- coding: utf-8 -*-
"""
=============================================================================
Dluz Film - Modo Hard: Orquestrador Autônomo de Produção de Vídeo por Link
Pipeline completo:
  1. Scraping do Artigo Web / Notícia
  2. Geração de Roteiro IA com bordão oficial: "Fala melhores, beleza?"
  3. Download de Gameplay 1080p60 (yt-dlp) & Micro-cortes Dinâmicos (NVENC)
  4. Síntese de Voz Clonada OmniVoice CUDA na RTX 2060 (dluz_voice.pt)
  5. Renderização de Overlays HyperFrames (Title Card, Lower-Thirds) com fundo verde
  6. Geração de Legendas Sincronizadas (.srt)
  7. Emissão do manifesto da timeline (timeline_manifest.json) para injeção no Dluz Film
=============================================================================
"""

import os
import sys
import re
import json
import time
import uuid
import shutil
import urllib.request
import urllib.parse
import subprocess
from pathlib import Path
from html.parser import HTMLParser

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Caminhos padrão do sistema DLuz
OMNIVOICE_ENV_PYTHON = r"C:\Users\dluzgg\.omnivoice_env\Scripts\python.exe"
DEFAULT_VOICE_PROMPT = r"C:\Users\dluzgg\Documents\antigravity\blissful-hertz\bilibili_tools\reference_voice\dluz_voice.pt"
DUBBER_SCRIPT = r"C:\Users\dluzgg\.gemini\config\skills\dublagem\scripts\dubber.py"
HYPERFRAMES_MJS = r"C:\Users\dluzgg\AppData\Roaming\npm\node_modules\hyperframes\bin\hyperframes.mjs"
NODE_EXE = r"C:\Program Files\nodejs\node.exe"
YT_DLP_EXE = r"C:\Python314\Scripts\yt-dlp.exe"
MASTER_VIDEOS_DIR = r"D:\antigravity\videos gerados"

def log_progress(percent: int, msg: str):
    """Envia o progresso estruturado para o Dluz Film."""
    print(f"PROGRESS:{percent}|{msg}", flush=True)

class HTMLTextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text_parts = []
        self.title_parts = []
        self.in_title = False
        self.skip_tags = {'script', 'style', 'nav', 'header', 'footer', 'aside', 'noscript', 'svg'}
        self.current_skip_depth = 0

    def handle_starttag(self, tag, attrs):
        if tag.lower() in self.skip_tags:
            self.current_skip_depth += 1
        elif tag.lower() == 'title':
            self.in_title = True

    def handle_endtag(self, tag):
        if tag.lower() in self.skip_tags and self.current_skip_depth > 0:
            self.current_skip_depth -= 1
        elif tag.lower() == 'title':
            self.in_title = False

    def handle_data(self, data):
        if self.current_skip_depth > 0:
            return
        text = data.strip()
        if not text:
            return
        if self.in_title:
            self.title_parts.append(text)
        else:
            self.text_parts.append(text)

def scrape_article(url_or_text: str) -> tuple[str, str]:
    """Extrai o título e o texto limpo da matéria a partir de uma URL ou texto direto."""
    if not (url_or_text.startswith("http://") or url_or_text.startswith("https://")):
        # O usuário digitou texto ou tema direto
        lines = [line.strip() for line in url_or_text.splitlines() if line.strip()]
        title = lines[0] if lines else "Novidade Gamer"
        body = "\n".join(lines[1:]) if len(lines) > 1 else url_or_text
        return title[:100], body

    log_progress(10, f"Baixando conteúdo da matéria: {url_or_text[:60]}...")
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }
    req = urllib.request.Request(url_or_text, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode('utf-8', errors='replace')
    except Exception as e:
        log_progress(12, f"Aviso: Erro ao acessar URL ({e}). Usando link como tema...")
        return "Novidade Gamer", f"Notícia sobre: {url_or_text}"

    parser = HTMLTextExtractor()
    parser.feed(html)

    title = " ".join(parser.title_parts).strip()
    if not title:
        title = "Notícia Especial DLuz Games"
    # Limpa sufixos de títulos (ex: " | TechTudo", " - DLuz Games")
    title = re.sub(r'\s*[-|–]\s*.*$', '', title).strip()

    body = "\n".join(parser.text_parts)
    # Limitar corpo a ~4000 caracteres mais relevantes
    if len(body) > 4000:
        body = body[:4000]

    return title, body

def generate_script_llm(title: str, article_text: str, provider: str, api_key: str, model: str) -> dict:
    """Gera o roteiro estruturado em 5 blocos com bordão oficial e termos em JSON."""
    log_progress(20, "Gerando roteiro narrativo com bordão oficial...")

    sys_prompt = (
        "Você é o roteirista oficial do canal gamer DLuz Games.\n"
        "Sua tarefa é criar um roteiro de vídeo curto (entre 45 e 70 segundos), enérgico, direto e empolgante "
        "com base nas informações da notícia fornecida.\n\n"
        "REGRAS ABSOLUTAMENTE OBRIGATÓRIAS:\n"
        "1. O primeiro bloco DEVE OBRIGATORIAMENTE começar com a frase exata: \"Fala melhores, beleza?\"\n"
        "   (NUNCA use 'Fala moleques', 'Fala galera' ou qualquer outra saudação).\n"
        "2. A linguagem deve ser descontraída, confiante e gamer, no estilo DLuz.\n"
        "3. Divida o roteiro em exatamente 5 blocos lógicos:\n"
        "   - Bloco 1 (intro): Saudação oficial 'Fala melhores, beleza?', gancho empolgante e anúncio do tema.\n"
        "   - Bloco 2 (noticia): O fato principal ou a grande novidade revelada.\n"
        "   - Bloco 3 (gameplay): Análise do visual, jogabilidade, gráficos ou desempenho.\n"
        "   - Bloco 4 (dica): Dica de ouro ou opinião sincera do canal.\n"
        "   - Bloco 5 (outro): Chamada para ação (deixar o like, se inscrever) e encerramento com reticências suaves (...).\n"
        "4. Para prevenir cortes no sintetizador de voz, SEMPRE finalize as falas de cada bloco de forma suave com reticências (...) ou ponto final.\n"
        "5. Responda ESTRITAMENTE em formato JSON com o seguinte formato exato, sem comentários extras:\n"
        "{\n"
        '  "title": "Título Curto do Vídeo",\n'
        '  "segments": [\n'
        '    {\n'
        '      "id": 1,\n'
        '      "type": "intro",\n'
        '      "text": "Fala melhores, beleza? Sejam muito bem-vindos ao DLuz Games! Hoje nós vamos falar sobre...",\n'
        '      "overlay_title": "DLUZ GAMES",\n'
        '      "overlay_subtitle": "DESTAQUE DO DIA",\n'
        '      "overlay_template": "title_card"\n'
        '    },\n'
        '    {\n'
        '      "id": 2,\n'
        '      "type": "noticia",\n'
        '      "text": "...",\n'
        '      "overlay_title": "NOVIDADE",\n'
        '      "overlay_subtitle": "ATUALIZAÇÃO",\n'
        '      "overlay_template": "lower_third"\n'
        '    },\n'
        '    {\n'
        '      "id": 3,\n'
        '      "type": "gameplay",\n'
        '      "text": "...",\n'
        '      "overlay_title": "GAMEPLAY",\n'
        '      "overlay_subtitle": "EM AÇÃO",\n'
        '      "overlay_template": "lower_third"\n'
        '    },\n'
        '    {\n'
        '      "id": 4,\n'
        '      "type": "dica",\n'
        '      "text": "...",\n'
        '      "overlay_title": "DICA DE OURO",\n'
        '      "overlay_subtitle": "FIQUE LIGADO",\n'
        '      "overlay_template": "lower_third"\n'
        '    },\n'
        '    {\n'
        '      "id": 5,\n'
        '      "type": "outro",\n'
        '      "text": "...",\n'
        '      "overlay_title": "INSCREVA-SE",\n'
        '      "overlay_subtitle": "DEIXE SEU LIKE",\n'
        '      "overlay_template": "social_card"\n'
        '    }\n'
        '  ]\n'
        "}"
    )

    user_content = f"Título da Notícia: {title}\n\nConteúdo da Matéria:\n{article_text}"

    # Se uma chave de API estiver disponível, faz a requisição
    if api_key and provider == "gemini":
        try:
            chosen_model = model if model else "gemini-2.5-flash"
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{chosen_model}:generateContent?key={api_key.strip()}"
            payload = {
                "contents": [{"role": "user", "parts": [{"text": user_content}]}],
                "systemInstruction": {"parts": [{"text": sys_prompt}]},
                "generationConfig": {"responseMimeType": "application/json"}
            }
            req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                return json.loads(raw_text)
        except Exception as e:
            log_progress(25, f"Aviso: Falha na API Gemini ({e}). Usando gerador inteligente de contingência...")
    elif api_key and provider in ("openrouter", "groq"):
        try:
            url = "https://openrouter.ai/api/v1/chat/completions" if provider == "openrouter" else "https://api.groq.com/openai/v1/chat/completions"
            chosen_model = model if model else ("anthropic/claude-3.5-sonnet" if provider == "openrouter" else "llama-3.3-70b-versatile")
            payload = {
                "model": chosen_model,
                "messages": [
                    {"role": "system", "content": sys_prompt},
                    {"role": "user", "content": user_content}
                ],
                "response_format": {"type": "json_object"}
            }
            req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'),
                                         headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key.strip()}"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                raw_text = data["choices"][0]["message"]["content"]
                return json.loads(raw_text)
        except Exception as e:
            log_progress(25, f"Aviso: Falha na API ({e}). Usando gerador inteligente de contingência...")

    # Fallback heurístico inteligente garantindo 100% de confiabilidade sem dependência de internet
    return {
        "title": title[:60],
        "segments": [
            {
                "id": 1,
                "type": "intro",
                "text": f"Fala melhores, beleza? Sejam muito bem-vindos ao DLuz Games! Hoje trazemos todos os detalhes sobre {title}...",
                "overlay_title": "DLUZ GAMES",
                "overlay_subtitle": "DESTAQUE DO DIA",
                "overlay_template": "title_card"
            },
            {
                "id": 2,
                "type": "noticia",
                "text": f"As principais novidades já estão dando o que falar na comunidade gamer e prometem mudar totalmente a dinâmica dos jogadores...",
                "overlay_title": "NOVIDADES",
                "overlay_subtitle": "CONFIRA OS DETALHES",
                "overlay_template": "lower_third"
            },
            {
                "id": 3,
                "type": "gameplay",
                "text": f"Dá uma olhada no ritmo de jogo e nos gráficos impressionantes que nós separamos aqui na tela para vocês acompanharem...",
                "overlay_title": "GAMEPLAY & AÇÃO",
                "overlay_subtitle": "ALTA PERFORMANCE",
                "overlay_template": "lower_third"
            },
            {
                "id": 4,
                "type": "dica",
                "text": f"A dica de ouro é dominar bem os novos comandos e manter a configuração sempre calibrada para ter máxima vantagem...",
                "overlay_title": "DICA DE OURO",
                "overlay_subtitle": "DICA DO DLUZ",
                "overlay_template": "lower_third"
            },
            {
                "id": 5,
                "type": "outro",
                "text": "Se você curtiu esse resumão, não esquece de deixar aquele like insano, se inscrever no canal e comentar a sua opinião! Valeu e até a próxima...",
                "overlay_title": "INSCREVA-SE",
                "overlay_subtitle": "DEIXE SEU LIKE!",
                "overlay_template": "social_card"
            }
        ]
    }

def obtain_gameplay(gameplay_input: str, topic: str, project_dir: Path) -> Path:
    """Obtém ou baixa a gameplay original usando yt-dlp."""
    output_raw = project_dir / "gameplay_raw.mp4"

    # Caso 1: Arquivo local já existente
    if gameplay_input and os.path.isfile(gameplay_input):
        log_progress(32, f"Usando arquivo de gameplay local: {os.path.basename(gameplay_input)}")
        shutil.copy2(gameplay_input, output_raw)
        return output_raw

    yt_dlp = YT_DLP_EXE if os.path.exists(YT_DLP_EXE) else shutil.which("yt-dlp")

    # Caso 2: URL do YouTube fornecida
    if gameplay_input and ("youtube.com" in gameplay_input or "youtu.be" in gameplay_input):
        log_progress(35, f"Baixando gameplay do YouTube com yt-dlp...")
        cmd = [
            yt_dlp or "yt-dlp",
            "-f", "bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "--merge-output-format", "mp4",
            "--no-playlist",
            "-o", str(output_raw),
            gameplay_input
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0 and output_raw.exists():
            return output_raw
        log_progress(38, "Aviso: Download por link falhou. Tentando busca por tema...")

    # Caso 3: Busca automática no YouTube ou fallback
    search_query = f"{topic} gameplay 60fps no commentary"
    log_progress(40, f"Buscando gameplay no YouTube: '{search_query[:40]}'...")
    if yt_dlp:
        cmd = [
            yt_dlp,
            f"ytsearch1:{search_query}",
            "-f", "bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "--merge-output-format", "mp4",
            "--no-playlist",
            "-o", str(output_raw)
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0 and output_raw.exists():
            return output_raw

    # Caso 4: Se falhar ou offline, gerar clipe de fundo dinâmico gamer com FFmpeg
    log_progress(42, "Criando base visual gamer com FFmpeg...")
    cmd = [
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", "testsrc=size=1920x1080:rate=60",
        "-t", "90",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        str(output_raw)
    ]
    subprocess.run(cmd, capture_output=True)
    return output_raw

def slice_gameplay_cuts(gameplay_file: Path, cuts_dir: Path, target_total_duration: float) -> list[dict]:
    """Corta a gameplay em micro-cenas dinâmicas de 3.5s a 5.5s para manter alto dinamismo."""
    log_progress(45, "Fatiando gameplay em cortes dinâmicos com NVENC...")
    cuts_dir.mkdir(parents=True, exist_ok=True)

    # Identificar duração do vídeo com ffprobe
    probe_cmd = [
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(gameplay_file)
    ]
    total_sec = 60.0
    try:
        out = subprocess.check_output(probe_cmd, text=True).strip()
        total_sec = float(out)
    except Exception:
        pass

    cursor = 15.0 if total_sec > 45.0 else 0.0
    clips = []
    clip_dur = 4.5
    accumulated = 0.0
    idx = 1

    has_nvenc = True

    while accumulated < target_total_duration + 5.0 and cursor < total_sec:
        out_clip = cuts_dir / f"cut_{idx:02d}.mp4"
        cur_dur = min(clip_dur, target_total_duration - accumulated + 2.0)
        if cur_dur <= 0.5:
            break

        encoder_args = ["-c:v", "h264_nvenc", "-preset", "p4", "-b:v", "7000k"] if has_nvenc else ["-c:v", "libx264", "-preset", "veryfast", "-b:v", "7000k"]
        cmd = [
            "ffmpeg", "-y",
            "-ss", f"{cursor:.2f}",
            "-i", str(gameplay_file),
            "-t", f"{cur_dur:.2f}",
            "-vf", "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,fps=60",
            *encoder_args,
            "-an",
            str(out_clip)
        ]
        res = subprocess.run(cmd, capture_output=True)
        if res.returncode != 0 and has_nvenc:
            has_nvenc = False
            cmd = [
                "ffmpeg", "-y",
                "-ss", f"{cursor:.2f}",
                "-i", str(gameplay_file),
                "-t", f"{cur_dur:.2f}",
                "-vf", "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,fps=60",
                "-c:v", "libx264", "-preset", "veryfast", "-b:v", "7000k",
                "-an",
                str(out_clip)
            ]
            res = subprocess.run(cmd, capture_output=True)

        if out_clip.exists():
            clips.append({
                "path": str(out_clip).replace("\\", "/"),
                "timeline_start": round(accumulated, 2),
                "duration": round(cur_dur, 2)
            })
            accumulated += cur_dur
            cursor += cur_dur + 3.0
            idx += 1
        else:
            break

    return clips

def synthesize_narration(segments: list[dict], audio_dir: Path, engine: str, voice_prompt: str, lang: str) -> list[dict]:
    """Sintetiza cada bloco narrativo com OmniVoice CUDA ou Edge-TTS."""
    log_progress(55, "Sintetizando locução com voz clonada do DLuz...")
    audio_dir.mkdir(parents=True, exist_ok=True)
    results = []
    current_time = 0.0

    for idx, seg in enumerate(segments):
        text = seg["text"].strip()
        out_wav = audio_dir / f"voice_seg_{idx+1:02d}.wav"
        log_progress(55 + int((idx / len(segments)) * 15), f"Sintetizando bloco {idx+1}/{len(segments)}...")

        cmd = [
            "python", DUBBER_SCRIPT,
            "--tts", text,
            "--engine", engine,
            "--output", str(out_wav),
            "--voice", voice_prompt,
            "--lang", lang,
            "--speed", "0.95"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)

        dur = 5.0
        if out_wav.exists():
            probe = ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                     "-of", "default=noprint_wrappers=1:nokey=1", str(out_wav)]
            try:
                dur = float(subprocess.check_output(probe, text=True).strip())
            except Exception:
                dur = max(3.0, len(text.split()) * 0.35)
        else:
            subprocess.run([
                "ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=24000:cl=mono",
                "-t", "5.0", str(out_wav)
            ], capture_output=True)

        results.append({
            "id": seg["id"],
            "path": str(out_wav).replace("\\", "/"),
            "text": text,
            "timeline_start": round(current_time, 2),
            "duration": round(dur, 2)
        })
        current_time += dur + 0.3

    return results

def render_hyperframes_overlays(segments: list[dict], narration_data: list[dict], overlays_dir: Path) -> list[dict]:
    """Gera e renderiza overlays animados com fundo verde via HyperFrames CLI."""
    log_progress(72, "Renderizando vinhetas e lower-thirds HyperFrames...")
    overlays_dir.mkdir(parents=True, exist_ok=True)
    results = []

    node_bin = NODE_EXE if os.path.exists(NODE_EXE) else shutil.which("node")

    for seg, narr in zip(segments, narration_data):
        tmpl = seg.get("overlay_template", "lower_third")
        title = seg.get("overlay_title", "DLuz Games")
        sub = seg.get("overlay_subtitle", "Notícia")
        out_mp4 = overlays_dir / f"overlay_{seg['id']:02d}.mp4"

        if tmpl == "title_card":
            html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; display:flex; justify-content:center; align-items:center; font-family:'Segoe UI',system-ui,sans-serif; }}
    .box {{ text-align:center; opacity:0; transform:scale(0.85); }}
    .badge {{ display:inline-block; padding:8px 24px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; font-size:22px; font-weight:800; border-radius:30px; letter-spacing:3px; text-transform:uppercase; margin-bottom:18px; box-shadow:0 6px 20px rgba(0,0,0,0.6); }}
    .title {{ font-size:76px; font-weight:900; color:#ffffff; text-transform:uppercase; letter-spacing:4px; text-shadow:0 8px 30px rgba(0,0,0,0.9); line-height:1.1; }}
    .subtitle {{ font-size:32px; font-weight:700; color:#fbbf24; margin-top:14px; letter-spacing:3px; text-shadow:0 4px 16px rgba(0,0,0,0.8); }}
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="title_card" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="box" id="box">
      <div class="badge">OFICIAL</div>
      <div class="title">{title}</div>
      <div class="subtitle">{sub}</div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    tl.to("#box", {{ opacity:1, scale:1, duration:0.7, ease:"back.out(1.7)" }})
      .to("#box", {{ opacity:0, scale:1.05, duration:0.5, ease:"power2.in" }}, 3.4);
    window.__timelines = window.__timelines || {{}};
    window.__timelines["title_card"] = tl;
  </script>
</body>
</html>"""
        elif tmpl == "social_card":
            html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; font-family:'Segoe UI',system-ui,sans-serif; }}
    .card {{ position:absolute; bottom:100px; right:100px; background:rgba(18,18,22,0.95); border:2px solid #38bdf8; border-radius:24px; padding:20px 36px; display:flex; align-items:center; box-shadow:0 12px 40px rgba(0,0,0,0.8); opacity:0; transform:translateY(50px); }}
    .avatar {{ width:60px; height:60px; border-radius:50%; background:linear-gradient(135deg, #f59e0b, #ef4444); display:flex; justify-content:center; align-items:center; font-size:28px; font-weight:bold; color:white; margin-right:20px; box-shadow:0 4px 14px rgba(245,158,11,0.5); }}
    .name {{ font-size:28px; font-weight:800; color:#ffffff; }}
    .handle {{ font-size:20px; color:#38bdf8; font-weight:600; margin-top:2px; }}
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="social_card" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="card" id="card">
      <div class="avatar">▶</div>
      <div>
        <div class="name">{title}</div>
        <div class="handle">{sub}</div>
      </div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    tl.to("#card", {{ opacity:1, y:0, duration:0.7, ease:"elastic.out(1, 0.75)" }})
      .to("#card", {{ opacity:0, y:30, duration:0.5, ease:"power2.in" }}, 3.4);
    window.__timelines = window.__timelines || {{}};
    window.__timelines["social_card"] = tl;
  </script>
</body>
</html>"""
        else: # lower_third
            html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; font-family:'Segoe UI',system-ui,sans-serif; }}
    .wrapper {{ position:absolute; bottom:120px; left:100px; display:flex; align-items:center; }}
    .accent-bar {{ width:8px; height:76px; background:linear-gradient(to bottom, #f59e0b, #ef4444); border-radius:4px; transform:scaleY(0); box-shadow:0 0 16px rgba(245,158,11,0.6); }}
    .content {{ margin-left:20px; opacity:0; transform:translateX(-30px); background:rgba(18,18,22,0.92); padding:12px 28px; border-radius:14px; border-left:1px solid rgba(255,255,255,0.1); box-shadow:0 10px 30px rgba(0,0,0,0.7); }}
    .title {{ font-size:36px; font-weight:800; color:#ffffff; text-shadow:0 4px 12px rgba(0,0,0,0.9); }}
    .subtitle {{ font-size:22px; font-weight:600; color:#f59e0b; margin-top:4px; letter-spacing:1px; text-shadow:0 2px 8px rgba(0,0,0,0.8); }}
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="lower_third" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="wrapper">
      <div class="accent-bar" id="bar"></div>
      <div class="content" id="content">
        <div class="title">{title}</div>
        <div class="subtitle">{sub}</div>
      </div>
    </div>
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
    tl.to("#bar", {{ scaleY:1, duration:0.5, ease:"power3.out" }})
      .to("#content", {{ opacity:1, x:0, duration:0.6, ease:"power3.out" }}, "-=0.3")
      .to(["#content", "#bar"], {{ opacity:0, x:-20, duration:0.5, ease:"power3.in" }}, 3.4);
    window.__timelines = window.__timelines || {{}};
    window.__timelines["lower_third"] = tl;
  </script>
</body>
</html>"""

        tmp_dir = overlays_dir / f"tmp_{seg['id']}"
        tmp_dir.mkdir(parents=True, exist_ok=True)
        (tmp_dir / "index.html").write_text(html, encoding="utf-8")

        if os.path.exists(HYPERFRAMES_MJS) and node_bin:
            cmd = [node_bin, HYPERFRAMES_MJS, "render", str(tmp_dir), "-o", str(out_mp4)]
            subprocess.run(cmd, capture_output=True)
        else:
            subprocess.run(["cmd.exe", "/c", "hyperframes", "render", str(tmp_dir), "-o", str(out_mp4)], capture_output=True)

        shutil.rmtree(tmp_dir, ignore_errors=True)

        if out_mp4.exists():
            results.append({
                "path": str(out_mp4).replace("\\", "/"),
                "timeline_start": narr["timeline_start"] + 0.3,
                "duration": 4.0,
                "effect": "key.chroma"
            })

    return results

def generate_srt_subtitles(narration_data: list[dict], srt_file: Path) -> Path:
    """Gera arquivo de legendas .srt alinhado perfeitamente com os blocos sintetizados."""
    log_progress(85, "Gerando legendas sincronizadas (.srt)...")
    cues = []
    cue_index = 1

    def format_timestamp(seconds: float) -> str:
        ms = int((seconds - int(seconds)) * 1000)
        s = int(seconds) % 60
        m = (int(seconds) // 60) % 60
        h = int(seconds) // 3600
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

    for item in narration_data:
        text = item["text"]
        start = item["timeline_start"]
        dur = item["duration"]
        sentences = [s.strip() for s in re.split(r'([.?!,]+)', text) if s.strip()]
        chunks = []
        buf = ""
        for s in sentences:
            buf += s
            if len(buf) > 35 or s in ('.', '!', '?', ','):
                chunks.append(buf.strip())
                buf = ""
        if buf.strip():
            chunks.append(buf.strip())

        if not chunks:
            chunks = [text]

        chunk_dur = dur / len(chunks)
        c_start = start
        for c in chunks:
            c_end = c_start + chunk_dur
            cues.append(f"{cue_index}\n{format_timestamp(c_start)} --> {format_timestamp(c_end)}\n{c}\n")
            cue_index += 1
            c_start = c_end

    srt_file.write_text("\n".join(cues), encoding="utf-8")
    return srt_file

def find_bgm_track() -> str:
    """Localiza uma trilha sonora royalty-free do acervo do sistema."""
    candidate_paths = [
        r"D:\antigravity\anuncios_tiktok_mr30g\assets\sfx\bgm.mp3",
        r"C:\Users\dluzgg\.gemini\config\skills\media-use\audio\assets\sfx\chime.mp3"
    ]
    for p in candidate_paths:
        if os.path.exists(p):
            return p.replace("\\", "/")
    return ""

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Dluz Film - Modo Hard Orquestrador")
    parser.add_argument("--article", required=True, help="Link da matéria ou texto do tema")
    parser.add_argument("--gameplay", default="", help="Link do YouTube da gameplay ou arquivo local")
    parser.add_argument("--provider", default="gemini", help="Provedor LLM (gemini, openrouter, groq)")
    parser.add_argument("--api-key", default="", help="Chave API para o provedor")
    parser.add_argument("--model", default="", help="Modelo LLM")
    parser.add_argument("--voice-engine", default="omnivoice", choices=["omnivoice", "edge_tts"])
    parser.add_argument("--voice-prompt", default=DEFAULT_VOICE_PROMPT)
    parser.add_argument("--lang", default="pt")
    parser.add_argument("--format", default="16:9")
    parser.add_argument("--output-dir", default="")

    args = parser.parse_args()

    project_id = f"auto_{time.strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:6]}"
    if args.output_dir:
        proj_dir = Path(args.output_dir)
    else:
        proj_dir = Path(MASTER_VIDEOS_DIR) / "auto_projects" / project_id
    proj_dir.mkdir(parents=True, exist_ok=True)

    log_progress(5, f"Iniciando Modo Hard Dluz Film (Projeto: {project_id})...")

    # 1. Extração do conteúdo
    title, article_text = scrape_article(args.article)

    # 2. Roteiro estruturado com bordão oficial
    script_json = generate_script_llm(title, article_text, args.provider, args.api_key, args.model)
    (proj_dir / "script.json").write_text(json.dumps(script_json, indent=2, ensure_ascii=False), encoding="utf-8")

    # 3. Síntese de voz OmniVoice CUDA
    narration = synthesize_narration(
        script_json.get("segments", []),
        proj_dir / "audio",
        args.voice_engine,
        args.voice_prompt,
        args.lang
    )
    total_audio_duration = narration[-1]["timeline_start"] + narration[-1]["duration"] if narration else 60.0

    # 4. Download da Gameplay & Micro-cortes dinâmicos
    raw_gameplay = obtain_gameplay(args.gameplay, title, proj_dir)
    gameplay_cuts = slice_gameplay_cuts(raw_gameplay, proj_dir / "gameplay_cuts", total_audio_duration)

    # 5. Renderização dos Overlays HyperFrames
    overlays = render_hyperframes_overlays(script_json.get("segments", []), narration, proj_dir / "overlays")

    # 6. Geração de Legendas .srt
    srt_path = generate_srt_subtitles(narration, proj_dir / "subtitles.srt")

    # 7. Trilha Sonora BGM
    bgm_path = find_bgm_track()

    log_progress(95, "Montando manifesto da timeline para o Dluz Film...")

    manifest = {
        "project_name": script_json.get("title", title),
        "total_duration": round(total_audio_duration + 1.0, 2),
        "format": args.format,
        "tracks": [
            {
                "index": 0,
                "type": "video",
                "name": "V1 - Gameplay Dinâmica",
                "clips": gameplay_cuts
            },
            {
                "index": 1,
                "type": "video",
                "name": "V2 - HyperFrames Overlays",
                "clips": overlays
            },
            {
                "index": 2,
                "type": "audio",
                "name": "A1 - Locução DLuz (OmniVoice)",
                "clips": [
                    {
                        "path": item["path"],
                        "timeline_start": item["timeline_start"],
                        "duration": item["duration"],
                        "volume": 1.35
                    } for item in narration
                ]
            }
        ],
        "subtitles": str(srt_path).replace("\\", "/")
    }

    if bgm_path:
        manifest["tracks"].append({
            "index": 3,
            "type": "audio",
            "name": "A2 - Trilha Sonora BGM",
            "clips": [
                {
                    "path": bgm_path,
                    "timeline_start": 0.0,
                    "duration": round(total_audio_duration + 1.0, 2),
                    "volume": 0.05
                }
            ]
        })

    manifest_file = proj_dir / "timeline_manifest.json"
    manifest_file.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    log_progress(100, "Produção do vídeo concluída! Injetando faixas na timeline...")
    print(f"TIMELINE_MANIFEST:{str(manifest_file).replace('\\', '/')}", flush=True)

if __name__ == "__main__":
    main()
