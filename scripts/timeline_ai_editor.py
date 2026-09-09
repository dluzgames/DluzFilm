#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
Timeline AI Editor — Transcrição, Análise Contextual e Injeção de HyperFrames
Dluz Film — Editor de Vídeo com IA
=============================================================================
Fluxos Suportados:
  1. contextual_hyperframes:
     - Adquire transcrição completa do vídeo via Whisper IA.
     - Analisa o contexto rigorosamente (temas, pessoas, tópicos, momentos-chave).
     - Renderiza overlays HyperFrames (Title Card, Lower-Thirds, Social Cards)
       sincronizados exatamente aos segundos em que os assuntos são falados.
  2. full_edit:
     - Tudo do modo contextual_hyperframes.
     - Geração de legendas dinâmicas palavra por palavra estilo MrBeast (.srt).
     - Detecção e preparação de corte de silêncios / pausas mortas.
     - Emissão do manifesto estruturado timeline_edit_manifest.json para a timeline.
=============================================================================
"""

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

OUTPUT_DIR = Path(r"D:\antigravity\videos gerados")
HYPERFRAMES_MJS = r"C:\Users\dluzgg\AppData\Roaming\npm\node_modules\hyperframes\bin\hyperframes.mjs"
NODE_EXE = r"C:\Program Files\nodejs\node.exe"


def emit_progress(percent: int, text: str):
    """Emite progresso estruturado para o Qt: PROGRESS:percent|text"""
    print(f"PROGRESS:{percent}|{text}", flush=True)


def extract_audio(video_path: str, in_point: float, duration: float, out_wav: Path) -> bool:
    """Extrai áudio mono 16kHz do intervalo exato do clipe usando FFmpeg."""
    cmd = ["ffmpeg", "-y"]
    if in_point > 0.001:
        cmd.extend(["-ss", f"{in_point:.3f}"])
    if duration > 0.001:
        cmd.extend(["-t", f"{duration:.3f}"])
    cmd.extend([
        "-i", str(video_path),
        "-vn",
        "-ar", "16000",
        "-ac", "1",
        "-c:a", "pcm_s16le",
        str(out_wav)
    ])
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return out_wav.exists() and out_wav.stat().st_size > 0
    except Exception as e:
        print(f"[Erro FFmpeg]: {e}", file=sys.stderr)
        return False


def transcribe_video(audio_wav: Path, lang: str = "pt", model_size: str = "base") -> list[dict]:
    """
    Transcreve o áudio com Whisper IA retornando segmentos temporizados e palavras.
    Cada segmento contém: {'start': float, 'end': float, 'text': str, 'words': list}
    """
    emit_progress(20, "Carregando modelo neural Whisper para transcrição...")

    try:
        from faster_whisper import WhisperModel
        use_faster = True
    except ImportError:
        use_faster = False

    whisper_lang = None if lang.lower() in ("auto", "") else lang.lower()
    if whisper_lang and "-" in whisper_lang:
        whisper_lang = whisper_lang.split("-")[0]

    segments_out = []

    if use_faster:
        emit_progress(30, "Transcrevendo falas e marcando tempos com faster-whisper...")
        model = WhisperModel(model_size, device="cpu", compute_type="int8")
        segments, info = model.transcribe(
            str(audio_wav),
            language=whisper_lang,
            word_timestamps=True,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=300)
        )
        for seg in segments:
            seg_words = []
            if getattr(seg, "words", None):
                for w in seg.words:
                    seg_words.append({
                        "start": round(float(w.start), 2),
                        "end": round(float(w.end), 2),
                        "word": w.word.strip()
                    })
            segments_out.append({
                "start": round(float(seg.start), 2),
                "end": round(float(seg.end), 2),
                "text": seg.text.strip(),
                "words": seg_words
            })
    else:
        import whisper
        emit_progress(30, "Transcrevendo falas com OpenAI Whisper...")
        model = whisper.load_model(model_size)
        result = model.transcribe(str(audio_wav), language=whisper_lang, word_timestamps=True)
        for seg in result.get("segments", []):
            seg_words = []
            for w in seg.get("words", []):
                seg_words.append({
                    "start": round(float(w.get("start", 0)), 2),
                    "end": round(float(w.get("end", 0)), 2),
                    "word": w.get("word", "").strip()
                })
            segments_out.append({
                "start": round(float(seg.get("start", 0)), 2),
                "end": round(float(seg.get("end", 0)), 2),
                "text": seg.get("text", "").strip(),
                "words": seg_words
            })

    return segments_out


def analyze_transcript_for_hyperframes(segments: list[dict], total_duration: float, title_hint: str = "") -> list[dict]:
    """
    Analisa rigorosamente a transcrição e decide a inserção contextual de HyperFrames:
    - 1 Title Card nos primeiros segundos com o tema central.
    - 2 a 4 Lower Thirds nos momentos em que novos tópicos, nomes ou dados são introduzidos.
    - 1 Social Card no final se houver chamada para ação (ou nos últimos 15s).
    """
    emit_progress(55, "Analisando contexto semântico e pontos-chave da fala...")

    if not segments:
        # Fallback se o vídeo não tiver falas audíveis
        t = title_hint if title_hint else "DLUZ FILM"
        return [
            {
                "type": "title_card",
                "title": t.upper(),
                "subtitle": "Edição Oficial",
                "at_seconds": 0.5,
                "duration": 4.0
            }
        ]

    overlays = []
    full_text = " ".join(s["text"] for s in segments)

    # 1. Title Card de Abertura (Tema Principal)
    first_seg = segments[0]
    main_title = ""
    main_sub = "Edição Oficial"

    # Tenta extrair o tema da primeira ou segunda frase
    intro_candidates = []
    for s in segments[:3]:
        # Remove saudações comuns
        cleaned = re.sub(r'^(?:fala\s+melhores[,\s!]+beleza\??|fala\s+galera|e\s+aí[,\s]|olá[,\s]|bem[- ]vindos[,\s]|hoje\s+vamos\s+falar\s+sobre\s+|hoje\s+eu\s+vou\s+mostrar\s+)', '', s["text"], flags=re.IGNORECASE).strip()
        if len(cleaned) > 10:
            intro_candidates.append(cleaned)

    if intro_candidates:
        cand = intro_candidates[0].split('.')[0].split(',')[0].strip()
        words = cand.split()
        if len(words) > 6:
            main_title = " ".join(words[:5]).upper()
            main_sub = " ".join(words[5:])
        else:
            main_title = cand.upper()
    elif title_hint:
        main_title = title_hint.upper()
    else:
        main_title = "DESTAQUES DO VÍDEO"

    if len(main_title) > 35:
        main_title = main_title[:35].strip() + "..."

    overlays.append({
        "type": "title_card",
        "title": main_title,
        "subtitle": main_sub[:40],
        "at_seconds": max(0.5, first_seg["start"]),
        "duration": 4.0
    })

    # 2. Lower Thirds Contextuais ancorados em momentos de fala
    # Procuramos por nomes próprios, entidades ou palavras de destaque nos segmentos seguintes
    used_times = [overlays[0]["at_seconds"]]

    # Padrão para capturar nomes próprios compostos (ex: Carlo Ancelotti, Vinicius Júnior, Endrick)
    proper_noun_regex = re.compile(r'\b([A-ZÁÉÍÓÚÂÊÔÃÕ][a-záéíóúâêôãõ]+(?:\s+[A-ZÁÉÍÓÚÂÊÔÃÕ][a-záéíóúâêôãõ]+)+)\b')
    # Padrão para tópicos importantes (números, estatísticas, convocados, novidades)
    topic_keywords = ["amistosos", "convocação", "jogadores", "estreantes", "destaque", "partida", "gameplay", "atualização", "desempenho", "configuração", "gráfico", "tutorial", "novidade"]

    for seg in segments[1:]:
        t_start = seg["start"]
        # Garante distância mínima de 6 segundos entre overlays para não sobrepor
        if any(abs(t_start - ut) < 6.5 for ut in used_times):
            continue

        seg_text = seg["text"].strip()

        # Checa nomes próprios
        proper_matches = proper_noun_regex.findall(seg_text)
        found_name = None
        for name in proper_matches:
            # Ignora nomes genéricos no início de frase
            if name.lower() not in ("seleção brasileira", "fala melhores", "muito bem", "além disso", "boa noite", "bom dia"):
                found_name = name
                break

        if found_name:
            overlays.append({
                "type": "lower_third",
                "title": found_name,
                "subtitle": "Destaque na Fala",
                "at_seconds": t_start,
                "duration": 4.0
            })
            used_times.append(t_start)
            continue

        # Checa tópicos relevantes
        for kw in topic_keywords:
            if kw in seg_text.lower():
                # Cria um card de tópico
                words = seg_text.split()
                frag = " ".join(words[:4])
                overlays.append({
                    "type": "lower_third",
                    "title": kw.upper(),
                    "subtitle": frag[:35],
                    "at_seconds": t_start,
                    "duration": 4.0
                })
                used_times.append(t_start)
                break

        if len(overlays) >= 4:
            break

    # 3. Social Card / Call to action no encerramento (se duração > 20s)
    if total_duration > 20.0 and len(segments) > 2:
        last_seg = segments[-1]
        t_last = max(total_duration - 6.0, last_seg["start"])
        if not any(abs(t_last - ut) < 5.0 for ut in used_times):
            overlays.append({
                "type": "social_card",
                "title": "DLuz Games",
                "subtitle": "@dluzgames • Inscreva-se!",
                "at_seconds": t_last,
                "duration": 4.0
            })

    emit_progress(65, f"Contexto mapeado: {len(overlays)} HyperFrames contextuais decididos!")
    return overlays


def render_hyperframes_overlay(item: dict, out_mp4: Path) -> bool:
    """Renderiza uma animação HyperFrames com fundo verde #00ff00."""
    tmpl = item.get("type", "lower_third")
    title = item.get("title", "DLuz Games")
    sub = item.get("subtitle", "Oficial")

    if tmpl == "title_card":
        html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ margin:0; padding:0; background:#00ff00; overflow:hidden; width:1920px; height:1080px; display:flex; justify-content:center; align-items:center; font-family:'Segoe UI',system-ui,sans-serif; }}
    .box {{ text-align:center; opacity:0; transform:scale(0.85); }}
    .badge {{ display:inline-block; padding:8px 24px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; font-size:22px; font-weight:800; border-radius:30px; letter-spacing:3px; text-transform:uppercase; margin-bottom:18px; box-shadow:0 6px 20px rgba(0,0,0,0.6); }}
    .title {{ font-size:74px; font-weight:900; color:#ffffff; text-transform:uppercase; letter-spacing:4px; text-shadow:0 8px 30px rgba(0,0,0,0.9); line-height:1.1; }}
    .subtitle {{ font-size:32px; font-weight:700; color:#fbbf24; margin-top:14px; letter-spacing:3px; text-shadow:0 4px 16px rgba(0,0,0,0.8); }}
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
</head>
<body>
  <div data-composition-id="title_card" data-width="1920" data-height="1080" data-duration="4" class="clip">
    <div class="box" id="box">
      <div class="badge">DESTAQUE</div>
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

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        (tmp_path / "index.html").write_text(html, encoding="utf-8")
        node_bin = NODE_EXE if os.path.exists(NODE_EXE) else shutil.which("node")

        if os.path.exists(HYPERFRAMES_MJS) and node_bin:
            cmd = [node_bin, HYPERFRAMES_MJS, "render", str(tmp_path), "-o", str(out_mp4)]
            subprocess.run(cmd, capture_output=True)
        else:
            subprocess.run(["cmd.exe", "/c", "hyperframes", "render", str(tmp_path), "-o", str(out_mp4)], capture_output=True)

    return out_mp4.exists() and out_mp4.stat().st_size > 0


def generate_word_by_word_srt(segments: list[dict], out_srt: Path):
    """Gera arquivo SRT palavra por palavra (estilo MrBeast) a partir dos segmentos transcritos."""
    cues = []
    for seg in segments:
        words = seg.get("words", [])
        if words:
            for w in words:
                w_text = w.get("word", "").strip().upper()
                w_start = float(w.get("start", 0.0))
                w_end = float(w.get("end", 0.0))
                if not w_text:
                    continue
                if w_end <= w_start:
                    w_end = w_start + 0.15
                elif (w_end - w_start) < 0.12:
                    w_end = w_start + 0.12
                cues.append({"start": w_start, "end": w_end, "text": w_text})
        else:
            tokens = seg.get("text", "").strip().split()
            if not tokens:
                continue
            dur = max(0.2, seg["end"] - seg["start"])
            dur_token = dur / len(tokens)
            for idx, token in enumerate(tokens):
                cues.append({
                    "start": seg["start"] + (idx * dur_token),
                    "end": seg["start"] + ((idx + 1) * dur_token),
                    "text": token.upper()
                })

    # Ajusta sobreposições
    for i in range(len(cues) - 1):
        if cues[i]["end"] > cues[i + 1]["start"]:
            cues[i]["end"] = max(cues[i]["start"] + 0.08, cues[i + 1]["start"])

    # Escreve SRT
    with open(out_srt, "w", encoding="utf-8") as f:
        for idx, cue in enumerate(cues, start=1):
            s_hrs = int(cue["start"] // 3600)
            s_min = int((cue["start"] % 3600) // 60)
            s_sec = int(cue["start"] % 60)
            s_ms = int(round((cue["start"] - int(cue["start"])) * 1000))

            e_hrs = int(cue["end"] // 3600)
            e_min = int((cue["end"] % 3600) // 60)
            e_sec = int(cue["end"] % 60)
            e_ms = int(round((cue["end"] - int(cue["end"])) * 1000))

            f.write(f"{idx}\n{s_hrs:02d}:{s_min:02d}:{s_sec:02d},{s_ms:03d} --> {e_hrs:02d}:{e_min:02d}:{e_sec:02d},{e_ms:03d}\n{cue['text']}\n\n")


def main():
    parser = argparse.ArgumentParser(description="Timeline AI Editor (Whisper + Contextual HyperFrames)")
    parser.add_argument("--video", required=True, help="Caminho do arquivo de vídeo da timeline")
    parser.add_argument("--in-point", type=float, default=0.0, help="Offset inicial em segundos")
    parser.add_argument("--duration", type=float, default=-1.0, help="Duração do trecho em segundos")
    parser.add_argument("--timeline-start", type=float, default=0.0, help="Posição temporal do clipe na timeline")
    parser.add_argument("--mode", default="contextual_hyperframes", choices=["contextual_hyperframes", "full_edit"])
    parser.add_argument("--lang", default="pt", help="Idioma da transcrição")
    parser.add_argument("--out-dir", default=str(OUTPUT_DIR), help="Diretório de saída")

    args = parser.parse_args()

    video_path = Path(args.video)
    if not video_path.exists():
        print(f"[Erro] Arquivo de vídeo não encontrado: {video_path}", file=sys.stderr)
        sys.exit(1)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    stem = video_path.stem

    emit_progress(5, "Iniciando processamento do vídeo da timeline...")

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_wav = Path(temp_dir) / "clip_speech.wav"
        if not extract_audio(str(video_path), args.in_point, args.duration, temp_wav):
            print("[Erro] Falha ao extrair áudio do clipe com FFmpeg.", file=sys.stderr)
            sys.exit(2)

        emit_progress(15, "Áudio isolado com sucesso. Executando transcrição Whisper IA...")

        # 1. Transcrição Obrigatória com Whisper IA
        segments = transcribe_video(temp_wav, lang=args.lang)
        emit_progress(50, f"Transcrição concluída: {len(segments)} falas identificadas.")

        # Obtém duração efetiva do vídeo
        dur = args.duration
        if dur <= 0.05:
            probe = ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                     "-of", "default=noprint_wrappers=1:nokey=1", str(video_path)]
            try:
                dur = float(subprocess.check_output(probe, text=True).strip())
            except Exception:
                dur = 30.0

        # 2. Análise Contextual dos Tópicos Falados
        overlay_plans = analyze_transcript_for_hyperframes(segments, total_duration=dur, title_hint=stem)

        # 3. Renderização de Cada HyperFrames Contextual
        emit_progress(70, "Renderizando animações HyperFrames com fundo verde...")
        rendered_overlays = []
        for idx, plan in enumerate(overlay_plans, start=1):
            out_mp4 = out_dir / f"hf_{plan['type']}_{stem}_{timestamp}_{idx:02d}.mp4"
            emit_progress(70 + int((idx / len(overlay_plans)) * 18), f"Renderizando {plan['type']}: {plan['title']}...")
            if render_hyperframes_overlay(plan, out_mp4):
                rendered_overlays.append({
                    "type": plan["type"],
                    "title": plan["title"],
                    "subtitle": plan["subtitle"],
                    "path": str(out_mp4).replace("\\", "/"),
                    "timeline_start": round(args.timeline_start + plan["at_seconds"], 2),
                    "duration": plan["duration"],
                    "effect": "key.chroma"
                })

        # 4. Modo Edição Completa (Legendas MrBeast + Silêncios)
        srt_path_str = ""
        remove_silence = False
        if args.mode == "full_edit":
            emit_progress(90, "Gerando legendas dinâmicas palavra por palavra estilo MrBeast...")
            out_srt = out_dir / f"legendas_mrbeast_{stem}_{timestamp}.srt"
            generate_word_by_word_srt(segments, out_srt)
            if out_srt.exists() and out_srt.stat().st_size > 0:
                srt_path_str = str(out_srt).replace("\\", "/")
            remove_silence = True

        # 5. Emissão do Manifesto Estruturado
        manifest = {
            "mode": args.mode,
            "video_path": str(video_path).replace("\\", "/"),
            "timeline_start": args.timeline_start,
            "transcript_count": len(segments),
            "remove_silence": remove_silence,
            "silence_params": {
                "threshold": -30.0,
                "min_duration": 0.3,
                "padding": 0.08
            },
            "subtitles_srt": srt_path_str,
            "subtitles_preset": "karaoke-pop",
            "overlays": rendered_overlays,
            "summary": f"{len(rendered_overlays)} HyperFrames contextuais sincronizados na timeline."
        }

        manifest_file = out_dir / f"timeline_manifest_{stem}_{timestamp}.json"
        manifest_file.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

        emit_progress(100, "Edição e contextualização concluídas com sucesso!")
        print(f"OUTPUT_MANIFEST:{manifest_file.resolve()}", flush=True)
        sys.exit(0)


if __name__ == "__main__":
    main()
