"""Barnläge's name sounds with Chatterbox Multilingual imitating Cori – run with the Python that has chatterbox
(namnljud.py finds it). The model is loaded once for every name.

    python namnljud_chatterbox.py <ref.wav> <out.wav> <text> [<out.wav> <text> …]

As the test 5 Nov: cfg_weight 0.3 (the reference is English – less British accent), fp32, Perth's watermark off.
A little more lively than Kakan (exaggeration 0.65) – it is for a three-year-old.
"""
import re
import sys

import perth
import torch
import torchaudio

perth.PerthImplicitWatermarker = perth.DummyWatermarker
from chatterbox.mtl_tts import ChatterboxMultilingualTTS  # noqa: E402


def main():
    ref, pairs = sys.argv[1], sys.argv[2:]
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = ChatterboxMultilingualTTS.from_pretrained(device=device)
    for out, text in zip(pairs[0::2], pairs[1::2]):
        lang = "sv" if re.search(r"[åäöÅÄÖ]", text) else "en"
        wav = model.generate(text + "!", language_id=lang, audio_prompt_path=ref,
                             cfg_weight=0.3, exaggeration=0.65)
        torchaudio.save(out, wav.cpu(), model.sr)
        print(out, flush=True)


if __name__ == "__main__":
    main()
