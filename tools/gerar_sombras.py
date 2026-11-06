"""Gera no Gemini as sombras dos animais marinhos (vistas de cima) e salva prontas para o jogo.

Uso (no terminal, dentro da pasta godot):
    GEMINI_API_KEY=sua_chave python3 tools/gerar_sombras.py
    GEMINI_API_KEY=sua_chave python3 tools/gerar_sombras.py baleia        # só uma
    GEMINI_API_KEY=sua_chave python3 tools/gerar_sombras.py --modelo gemini-2.5-flash-image

O Gemini desenha a silhueta escura em fundo branco; o script transforma isso numa
máscara (branco com transparência), corta as sobras e deita o bicho com a cabeça para a
direita. O jogo pinta a máscara com a cor do fundo do mar. Os originais ficam em assets/raw.
"""
import argparse
import io
import os
import subprocess
import sys
from pathlib import Path

from google import genai
from PIL import Image, ImageFilter, ImageOps

RAIZ = Path(__file__).resolve().parent.parent
RAW = RAIZ / "assets" / "raw"
SPRITES = RAIZ / "assets" / "sprites"
GODOT = Path.home() / "Documentos/games/Godot_v4.3-stable_linux.x86_64"

BASE = (
    "Top-down view from directly above, as seen through clear ocean water. "
    "A single solid flat dark navy silhouette, no details, no eyes, no texture, no shading, "
    "on a pure white background. Head pointing to the RIGHT, body horizontal, centered, "
    "with empty white margin around it. No text, no water, no shadow, no border."
)
BICHOS = {
    "tubarao": "Silhouette of a shark seen from above: streamlined body, two pectoral fins spread to the sides, crescent tail fin. " + BASE,
    "baleia": "Silhouette of a humpback whale seen from above: big wide body, two long pectoral flippers, wide tail flukes. " + BASE,
    "peixe": "Silhouette of one small reef fish seen from above: slim oval body and forked tail. " + BASE,
}


def gerar(cliente, modelo: str, nome: str) -> Image.Image:
    print(f"gerando {nome}...", flush=True)
    resp = cliente.models.generate_content(model=modelo, contents=BICHOS[nome])
    for parte in resp.candidates[0].content.parts:
        if getattr(parte, "inline_data", None) and parte.inline_data.data:
            return Image.open(io.BytesIO(parte.inline_data.data)).convert("RGB")
    raise RuntimeError(f"o Gemini não devolveu imagem para {nome}")


def para_mascara(img: Image.Image) -> Image.Image:
    """Escuro vira opaco, branco vira transparente; resultado branco com alfa."""
    cinza = ImageOps.grayscale(img)
    alfa = ImageOps.invert(cinza).point(lambda v: 0 if v < 40 else min(255, int((v - 40) * 1.6)))
    alfa = alfa.filter(ImageFilter.GaussianBlur(1.2))
    caixa = alfa.getbbox()
    if not caixa:
        raise RuntimeError("a imagem veio vazia")
    alfa = alfa.crop(caixa)
    if alfa.height > alfa.width:  # veio em pé: deita com a cabeça para a direita
        alfa = alfa.rotate(-90, expand=True)
    out = Image.new("RGBA", alfa.size, (255, 255, 255, 0))
    out.putalpha(alfa)
    out.thumbnail((512, 512))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bichos", nargs="*", help="quais gerar: " + ", ".join(BICHOS) + " (padrão: todos)")
    ap.add_argument("--modelo", default="gemini-2.5-flash-image", help="modelo de imagem do Gemini")
    ap.add_argument("--virar", nargs="*", default=[], help="espelhar estes (se a cabeça ficou para a esquerda)")
    args = ap.parse_args()
    for nome in args.bichos + args.virar:
        if nome not in BICHOS:
            sys.exit(f"bicho desconhecido: {nome} (use {', '.join(BICHOS)})")

    if args.virar and not args.bichos:
        # só espelha os que já existem, sem gerar de novo
        for nome in args.virar:
            p = SPRITES / f"sombra_{nome}.png"
            ImageOps.mirror(Image.open(p)).save(p)
            print(f"espelhado: {p.name}")
        return

    if not (os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")):
        sys.exit("Defina GEMINI_API_KEY antes (ex.: GEMINI_API_KEY=sua_chave python3 tools/gerar_sombras.py)")

    cliente = genai.Client()
    RAW.mkdir(parents=True, exist_ok=True)
    for nome in args.bichos or list(BICHOS):
        img = gerar(cliente, args.modelo, nome)
        img.save(RAW / f"sombra_{nome}.png")
        para_mascara(img).save(SPRITES / f"sombra_{nome}.png")
        print(f"ok: assets/sprites/sombra_{nome}.png")

    # a Godot precisa importar os PNGs novos para o jogo enxergar
    if GODOT.exists():
        print("importando na Godot...")
        subprocess.run([str(GODOT), "--headless", "--path", str(RAIZ), "--import"], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("Pronto. Abra o jogo: as sombras do Gemini substituem as desenhadas em código.")
    print("Se algum bicho ficou com a cabeça para a esquerda: python3 tools/gerar_sombras.py --virar baleia")


if __name__ == "__main__":
    main()
