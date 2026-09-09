#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
Dynamic Subtitles Generator (Whisper IA — Word-by-Word / MrBeast Style)
Dluz Film — Editor de Vídeo com IA
=============================================================================
Gera arquivos .srt sincronizados palavra por palavra (word-by-word) com
alta precisão através do faster-whisper e FFmpeg.
Permite agrupar 1 palavra por bloco (MrBeast), 2 a 3 palavras ou frases inteiras.
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


def emit_progress(percent: int, text: str):
    """Emite progresso para o Qt / QProcess no formato: PROGRESS:percent|text"""
    print(f"PROGRESS:{percent}|{text}", flush=True)


def format_srt_timestamp(seconds: float) -> str:
    """Converte segundos float em formato SRT: HH:MM:SS,mmm"""
    if seconds < 0:
        seconds = 0.0
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    if millis >= 1000:
        millis = 999
    return f"{hrs:02d}:{mins:02d}:{secs:02d},{millis:03d}"


def extract_clip_audio(video_path: str, in_point: float, duration: float, output_wav: Path) -> bool:
    """Extrai áudio mono 16kHz do intervalo exato do clipe via FFmpeg."""
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
        str(output_wav)
    ])
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return output_wav.exists() and output_wav.stat().st_size > 0
    except Exception as e:
        print(f"[Erro FFmpeg]: {e}", file=sys.stderr)
        return False


def clean_word_text(text: str, uppercase: bool = True) -> str:
    """Limpa e formata a palavra individual."""
    cleaned = text.strip()
    cleaned = re.sub(r'[\r\n\t]+', ' ', cleaned).strip()
    if uppercase:
        cleaned = cleaned.upper()
    return cleaned


def transcribe_to_cues(audio_wav: Path, lang: str = "pt", words_per_cue: int = 1,
                       uppercase: bool = True, model_size: str = "base"):
    """
    Transcreve o áudio com Whisper (word_timestamps=True) e agrupa em cues.
    Retorna lista de dicionários: [{'start': float, 'end': float, 'text': str}, ...]
    """
    emit_progress(25, "Carregando modelo Whisper IA...")

    try:
        from faster_whisper import WhisperModel
        use_faster = True
    except ImportError:
        use_faster = False

    cues = []
    whisper_lang = None if lang.lower() in ("auto", "") else lang.lower()
    if whisper_lang and "-" in whisper_lang:
        whisper_lang = whisper_lang.split("-")[0]

    if use_faster:
        emit_progress(35, "Inicializando transcrição neural...")
        model = WhisperModel(model_size, device="cpu", compute_type="int8")
        emit_progress(50, "Transcrevendo falas e detectando tempos por palavra...")
        segments, info = model.transcribe(
            str(audio_wav),
            language=whisper_lang,
            word_timestamps=True,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=300)
        )
        segments_list = list(segments)
    else:
        import whisper
        emit_progress(35, "Inicializando OpenAI Whisper...")
        model = whisper.load_model(model_size)
        emit_progress(50, "Transcrevendo falas e detectando tempos por palavra...")
        result = model.transcribe(
            str(audio_wav),
            language=whisper_lang,
            word_timestamps=True
        )
        segments_list = result.get("segments", [])

    emit_progress(75, "Sincronizando palavras e construindo legendas dinâmicas...")

    all_words = []

    for seg in segments_list:
        words = []
        if use_faster:
            words = getattr(seg, "words", []) or []
            seg_start = getattr(seg, "start", 0.0)
            seg_end = getattr(seg, "end", 0.0)
            seg_text = getattr(seg, "text", "")
        else:
            words = seg.get("words", [])
            seg_start = seg.get("start", 0.0)
            seg_end = seg.get("end", 0.0)
            seg_text = seg.get("text", "")

        if words:
            for w in words:
                if use_faster:
                    w_text = getattr(w, "word", "").strip()
                    w_start = getattr(w, "start", 0.0)
                    w_end = getattr(w, "end", 0.0)
                else:
                    w_text = w.get("word", "").strip()
                    w_start = w.get("start", 0.0)
                    w_end = w.get("end", 0.0)

                if not w_text:
                    continue
                if w_end <= w_start:
                    w_end = w_start + 0.15
                elif (w_end - w_start) < 0.12:
                    w_end = w_start + 0.12

                all_words.append({
                    "start": max(0.0, float(w_start)),
                    "end": max(0.0, float(w_end)),
                    "text": clean_word_text(w_text, uppercase)
                })
        else:
            raw_tokens = seg_text.strip().split()
            if not raw_tokens:
                continue
            total_dur = max(0.2, seg_end - seg_start)
            dur_per_word = total_dur / len(raw_tokens)
            for idx, token in enumerate(raw_tokens):
                w_start = seg_start + (idx * dur_per_word)
                w_end = w_start + dur_per_word
                all_words.append({
                    "start": max(0.0, float(w_start)),
                    "end": max(0.0, float(w_end)),
                    "text": clean_word_text(token, uppercase)
                })

    if not all_words:
        print("[Aviso] Nenhuma palavra encontrada no áudio.", file=sys.stderr)
        return []

    for i in range(len(all_words) - 1):
        curr = all_words[i]
        nxt = all_words[i + 1]
        if curr["end"] > nxt["start"]:
            curr["end"] = max(curr["start"] + 0.08, nxt["start"])

    if words_per_cue <= 0:
        for seg in segments_list:
            if use_faster:
                s_start = getattr(seg, "start", 0.0)
                s_end = getattr(seg, "end", 0.0)
                s_text = getattr(seg, "text", "").strip()
            else:
                s_start = seg.get("start", 0.0)
                s_end = seg.get("end", 0.0)
                s_text = seg.get("text", "").strip()
            if s_text:
                cues.append({
                    "start": s_start,
                    "end": s_end,
                    "text": clean_word_text(s_text, uppercase)
                })
    elif words_per_cue == 1:
        cues = all_words
    else:
        i = 0
        while i < len(all_words):
            chunk = all_words[i:i + words_per_cue]
            chunk_start = chunk[0]["start"]
            chunk_end = chunk[-1]["end"]
            chunk_text = " ".join(item["text"] for item in chunk)
            cues.append({
                "start": chunk_start,
                "end": chunk_end,
                "text": chunk_text
            })
            i += words_per_cue

    return cues


def write_srt_file(cues, output_path: Path):
    """Grava as cues no arquivo SRT padrão UTF-8."""
    with open(output_path, "w", encoding="utf-8") as f:
        for idx, cue in enumerate(cues, start=1):
            start_str = format_srt_timestamp(cue["start"])
            end_str = format_srt_timestamp(cue["end"])
            text = cue["text"].strip()
            f.write(f"{idx}\n{start_str} --> {end_str}\n{text}\n\n")


def main():
    parser = argparse.ArgumentParser(description="Dynamic Subtitles Generator (MrBeast Style)")
    parser.add_argument("--video", required=True, help="Caminho do arquivo de vídeo ou áudio")
    parser.add_argument("--in-point", type=float, default=0.0, help="Offset inicial em segundos")
    parser.add_argument("--duration", type=float, default=-1.0, help="Duração do trecho em segundos")
    parser.add_argument("--lang", default="pt", help="Idioma do áudio (pt, en, es, auto)")
    parser.add_argument("--words-per-cue", type=int, default=1, help="Palavras por bloco (1 = MrBeast)")
    parser.add_argument("--model-size", default="base", help="Tamanho do modelo Whisper (base, small, tiny)")
    parser.add_argument("--no-uppercase", action="store_true", help="Desativa conversão para MAIÚSCULAS")
    parser.add_argument("--out-dir", default=str(OUTPUT_DIR), help="Diretório de saída")
    parser.add_argument("--out-srt", default=None, help="Caminho exato do arquivo .srt de saída")

    args = parser.parse_args()

    video_path = Path(args.video)
    if not video_path.exists():
        print(f"[Erro] Arquivo não encontrado: {video_path}", file=sys.stderr)
        sys.exit(1)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    stem = video_path.stem
    if args.out_srt:
        output_srt = Path(args.out_srt)
    else:
        output_srt = out_dir / f"legendas_{stem}_{timestamp}.srt"

    output_srt.parent.mkdir(parents=True, exist_ok=True)

    emit_progress(5, "Iniciando extração do áudio...")

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_wav = Path(temp_dir) / "extracted_speech.wav"
        if not extract_clip_audio(str(video_path), args.in_point, args.duration, temp_wav):
            print("[Erro] Falha ao extrair áudio do clipe com FFmpeg.", file=sys.stderr)
            sys.exit(2)

        emit_progress(15, "Áudio extraído com sucesso. Processando IA...")

        uppercase = not args.no_uppercase
        cues = transcribe_to_cues(
            temp_wav,
            lang=args.lang,
            words_per_cue=args.words_per_cue,
            uppercase=uppercase,
            model_size=args.model_size
        )

        if not cues:
            print("[Aviso] Nenhuma fala identificada para gerar legendas.", file=sys.stderr)
            write_srt_file([], output_srt)
        else:
            emit_progress(90, f"Gerando arquivo .srt com {len(cues)} palavras/cues...")
            write_srt_file(cues, output_srt)

    emit_progress(100, "Legendas dinâmicas geradas com sucesso!")
    print(f"OUTPUT_SRT:{output_srt.resolve()}", flush=True)
    sys.exit(0)


if __name__ == "__main__":
    main()
