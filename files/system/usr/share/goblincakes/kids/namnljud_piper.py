"""Barnläge's name sounds with Piper's Cori (en_GB-cori-high) – run with Kakan's voice environment (goblincakes-voice).

    python namnljud_piper.py <model.onnx> <out.wav> <text> [<out.wav> <text> …]
"""
import sys
import wave

from piper import PiperVoice, SynthesisConfig


def main():
    voice = PiperVoice.load(sys.argv[1])
    cfg = SynthesisConfig(length_scale=1.05)
    pairs = sys.argv[2:]
    for out, text in zip(pairs[0::2], pairs[1::2]):
        with wave.open(out, "wb") as w:
            w.setframerate(voice.config.sample_rate)
            w.setsampwidth(2)
            w.setnchannels(1)
            for chunk in voice.synthesize(text + "!", cfg):
                w.writeframes(chunk.audio_int16_bytes)
        print(out, flush=True)


if __name__ == "__main__":
    main()
