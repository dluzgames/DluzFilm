#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OmniFlash Clip Editor — Transformação de Clipes com Google Flow + Preservação de Áudio Original
Permite selecionar um clipe na timeline do Dluz Film, enviar o trecho visual para edição
no Google Flow (OmniFlash) via prompt, e remuxar 100% da voz/áudio original com FFmpeg,
garantindo zero alteração na voz do personagem.

Salva obrigatoriamente o resultado em: D:\antigravity\videos gerados
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

OUTPUT_DIR = Path(r"D:\antigravity\videos gerados")


def emit_progress(percent: int, text: str):
    """Envia progresso formatado para o Qt / QProcess."""
    print(f"PROGRESS:{percent}|{text}", flush=True)


def probe_media_info(video_path: str):
    """Obtém resolução, aspect ratio e presença de áudio com ffprobe."""
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "stream=codec_type,width,height",
        "-of", "json",
        video_path
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        width, height = 1920, 1080
        has_audio = False
        for s in data.get("streams", []):
            if s.get("codec_type") == "video":
                width = int(s.get("width", 1920))
                height = int(s.get("height", 1080))
            elif s.get("codec_type") == "audio":
                has_audio = True
        aspect = "9:16" if height > width else "16:9"
        return {"width": width, "height": height, "aspect": aspect, "has_audio": has_audio}
    except Exception as e:
        print(f"[Warning] Falha ao sondar mídia com ffprobe: {e}", file=sys.stderr)
        return {"width": 1920, "height": 1080, "aspect": "16:9", "has_audio": True}


def pick_flow_duration(duration_seconds: float) -> int:
    """O Google Flow / Veo aceita 4, 6, 8 (recomendado) ou 10 segundos."""
    if duration_seconds <= 5.0:
        return 4
    elif duration_seconds <= 7.0:
        return 6
    elif duration_seconds <= 9.0:
        return 8
    else:
        return 10


def run_command(cmd, desc=""):
    """Executa um comando e trata erros."""
    if desc:
        print(f"[Exec] {desc}: {' '.join(str(c) for c in cmd)}", flush=True)
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[Erro] Falha em {desc}:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}", file=sys.stderr)
        raise RuntimeError(f"Comando falhou ({res.returncode}): {res.stderr}")
    return res.stdout


def main():
    parser = argparse.ArgumentParser(description="OmniFlash Clip Editor")
    parser.add_argument("--clip", required=True, help="Caminho do arquivo do clipe de vídeo")
    parser.add_argument("--in-point", type=float, default=0.0, help="Ponto de entrada (segundos)")
    parser.add_argument("--duration", type=float, default=8.0, help="Duração do clipe na timeline (segundos)")
    parser.add_argument("--prompt", required=True, help="Prompt de transformação visual para o OmniFlash / Flow")
    parser.add_argument("--aspect", choices=["16:9", "9:16"], default=None, help="Aspect ratio (detectado automaticamente se omitido)")
    parser.add_argument("--preserve-audio", action="store_true", default=True, help="Preserva a voz e áudio original do personagem")
    parser.add_argument("--no-preserve-audio", dest="preserve_audio", action="store_false", help="Não preserva áudio")
    parser.add_argument("--output-name", default=None, help="Nome do arquivo final de saída")

    args = parser.parse_args()

    clip_path = Path(args.clip).resolve()
    if not clip_path.exists():
        print(f"ERROR: Arquivo de vídeo não encontrado: {clip_path}", file=sys.stderr)
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    out_filename = args.output_name or f"omniflash_edit_{timestamp}.mp4"
    final_output_path = OUTPUT_DIR / out_filename

    emit_progress(5, "Analisando formato e áudio do clipe original...")
    media_info = probe_media_info(str(clip_path))
    aspect = args.aspect or media_info["aspect"]
    has_audio = media_info["has_audio"]

    flow_duration = pick_flow_duration(args.duration)
    emit_progress(10, f"Ajustando duração para {flow_duration}s (limite otimizado Google Flow)...")

    temp_dir = Path(tempfile.mkdtemp(prefix="omniflash_clip_"))
    try:
        # 1. Extração do áudio da voz original
        audio_extracted_path = temp_dir / "original_voice.wav"
        if has_audio and args.preserve_audio:
            emit_progress(15, "Extraindo voz e áudio original em alta fidelidade...")
            run_command([
                "ffmpeg", "-y",
                "-ss", str(args.in_point),
                "-t", str(flow_duration),
                "-i", str(clip_path),
                "-vn",
                "-c:a", "pcm_s16le",
                "-ar", "48000",
                "-ac", "2",
                str(audio_extracted_path)
            ], "Extrair áudio original")
        else:
            emit_progress(15, "Clipe sem áudio ou preservação desativada.")

        # 2. Extração dos frames de referência para o Flow
        emit_progress(25, "Extraindo frames de referência do clipe...")
        start_frame_path = temp_dir / "start_frame.png"
        end_frame_path = temp_dir / "end_frame.png"

        # Frame inicial
        run_command([
            "ffmpeg", "-y",
            "-ss", str(args.in_point),
            "-i", str(clip_path),
            "-vframes", "1",
            "-q:v", "2",
            str(start_frame_path)
        ], "Extrair frame inicial")

        # Frame final (se o clipe tiver tempo suficiente)
        end_time = args.in_point + max(0.5, flow_duration - 0.2)
        run_command([
            "ffmpeg", "-y",
            "-ss", str(end_time),
            "-i", str(clip_path),
            "-vframes", "1",
            "-q:v", "2",
            str(end_frame_path)
        ], "Extrair frame final")

        # 3. Disparo da transformação visual no Google Flow
        emit_progress(35, "Conectando ao Google Flow (OmniFlash Veo)...")
        flow_raw_video = temp_dir / "flow_raw_generated.mp4"

        # Tenta i2v com frame inicial + final; se o modelo não aceitar end-frame, usa initial-frame
        flow_cmd = [
            "uvx", "--from", "gflow-cli", "gflow", "video", "i2v",
            "--initial-frame", str(start_frame_path),
            "--end-frame", str(end_frame_path),
            "--model", "omni-flash",
            "--duration", str(flow_duration),
            "--aspect", aspect,
            "-o", str(flow_raw_video),
            args.prompt
        ]

        emit_progress(45, f"Renderizando transformação visual no Google Flow com OmniFlash ({flow_duration}s)...")
        print(f"[Flow] Executando comando:\n{' '.join(flow_cmd)}", flush=True)

        try:
            flow_proc = subprocess.run(flow_cmd, capture_output=True, text=True, check=True)
            print(f"[Flow Output]\n{flow_proc.stdout}", flush=True)
        except subprocess.CalledProcessError as e:
            print(f"[Warning] Falha com end-frame, tentando somente initial-frame: {e.stderr}", file=sys.stderr)
            emit_progress(50, "Ajustando parâmetros de geração Flow...")
            flow_cmd_fallback = [
                "uvx", "--from", "gflow-cli", "gflow", "video", "i2v",
                "--initial-frame", str(start_frame_path),
                "--model", "omni-flash",
                "--duration", str(flow_duration),
                "--aspect", aspect,
                "-o", str(flow_raw_video),
                args.prompt
            ]
            subprocess.run(flow_cmd_fallback, capture_output=True, text=True, check=True)

        if not flow_raw_video.exists() or flow_raw_video.stat().st_size == 0:
            raise RuntimeError("O Google Flow não gerou o vídeo ou o download falhou.")

        emit_progress(80, "Vídeo do Google Flow recebido! Sincronizando com áudio original...")

        # 4. Remux com preservação absoluta da voz do personagem
        if has_audio and args.preserve_audio and audio_extracted_path.exists():
            emit_progress(88, "Remuxando voz original com imagem transformada (FFmpeg)...")
            remux_cmd = [
                "ffmpeg", "-y",
                "-i", str(flow_raw_video),
                "-i", str(audio_extracted_path),
                "-c:v", "copy",
                "-c:a", "aac",
                "-b:a", "192k",
                "-map", "0:v:0",
                "-map", "1:a:0",
                "-shortest",
                str(final_output_path)
            ]
            run_command(remux_cmd, "Remux final de áudio e vídeo")
        else:
            emit_progress(88, "Copiando vídeo transformado final...")
            shutil.copy2(str(flow_raw_video), str(final_output_path))

        emit_progress(100, "Clipe editado com sucesso pelo OmniFlash!")
        print(f"OUTPUT_VIDEO:{final_output_path.resolve()}", flush=True)

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
