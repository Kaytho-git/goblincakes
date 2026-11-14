"""Barnläge's name sounds with Chatterbox Multilingual imitating Cori – run with the Python that has chatterbox
(namnljud.py finds it). The model is loaded once for every name.

    python namnljud_chatterbox.py <ref.wav> <out.wav> <text> [<out.wav> <text> …]

As the test 5 Nov: cfg_weight 0.3 (the reference is English – less British accent), fp32, Perth's watermark off.
A little more lively than Kakan (exaggeration 0.65) – it is for a three-year-old.
14 Nov (the user: "Cori reads, then starts mumbling about something else"): with a short text Chatterbox sometimes
doesn't find the end and goes on talking (Toy Story became 9 s). So: a cap on the length from the text (speech
tokens are 25 per second – 0.8 s + 0.1 s per letter is ~twice a calm reading), three tries per name and the
shortest kept (the one that ended by itself), the silence after cut off and a short fade so a cap never clicks.
"""
import re
import sys

import perth
import torch
import torchaudio

perth.PerthImplicitWatermarker = perth.DummyWatermarker
from chatterbox.mtl_tts import ChatterboxMultilingualTTS  # noqa: E402


TOKENS_PER_SECOND = 25
TRIES = 3


def longest(text):
    """The most a name may take, in seconds."""
    return 0.8 + 0.1 * len(text)


def tidy(wav, sr):
    """The silence after the voice cut off (and a little before), then 40 ms fade out."""
    level = wav.abs().max().item() or 1.0
    loud = (wav.abs() > level * 0.04).nonzero()
    if loud.numel():
        first, last = loud[:, -1].min().item(), loud[:, -1].max().item()
        wav = wav[:, max(0, first - int(0.03 * sr)):min(wav.shape[-1], last + int(0.12 * sr))]
    fade = min(wav.shape[-1], int(0.04 * sr))
    if fade:
        wav[:, -fade:] *= torch.linspace(1.0, 0.0, fade)
    return wav


def main():
    ref, pairs = sys.argv[1], sys.argv[2:]
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = ChatterboxMultilingualTTS.from_pretrained(device=device)
    cap = [1000]
    inference = model.t3.inference

    def capped(*args, **kwargs):          # generate() always asks for 1000 tokens (40 s)
        kwargs["max_new_tokens"] = cap[0]
        return inference(*args, **kwargs)
    model.t3.inference = capped
    for out, text in zip(pairs[0::2], pairs[1::2]):
        lang = "sv" if re.search(r"[åäöÅÄÖ]", text) else "en"
        if text.startswith(("sv:", "en:")):
            lang, text = text[:2], text[3:]
        cap[0] = int(longest(text) * TOKENS_PER_SECOND)
        best, best_enough = None, False
        for _ in range(TRIES):
            wav = tidy(model.generate(text + "!", language_id=lang, audio_prompt_path=ref,
                                      cfg_weight=0.3, exaggeration=0.65).cpu(), model.sr)
            # the shortest – but not one that stopped before the name was said
            enough = wav.shape[-1] >= (0.25 + 0.04 * len(text)) * model.sr
            if best is None or (enough and (not best_enough or wav.shape[-1] < best.shape[-1])):
                best, best_enough = wav, enough
        torchaudio.save(out, best, model.sr)
        print(out, flush=True)


if __name__ == "__main__":
    main()
