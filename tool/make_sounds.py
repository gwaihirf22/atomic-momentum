#!/usr/bin/env python3
"""Makes the app's notification tones (original, synthesized here, so there
are no licensing questions): short bell-like sounds as 16-bit mono WAV.

Writes each tone to ios/Runner/<name>.wav (bundled with the app; iOS plays
it by file name) and android/app/src/main/res/raw/<name>.wav.

    python3 tool/make_sounds.py
"""
import math
import os
import struct
import wave

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def bell(freq, start, length, volume=1.0, decay=4.0):
    """A soft bell: a sine with a few inharmonic partials, fading out."""
    partials = [(1.0, 1.0), (2.76, 0.35), (5.4, 0.12), (8.93, 0.05)]
    def sample(t):
        if t < start or t > start + length:
            return 0.0
        x = t - start
        attack = min(1.0, x / 0.006)
        env = attack * math.exp(-decay * x)
        return volume * env * sum(a * math.sin(2 * math.pi * freq * r * x) for r, a in partials)
    return sample


TONES = {
    # Two rising notes, bright
    'chime': ([bell(1318.5, 0.0, 1.1), bell(1975.5, 0.12, 1.0, 0.8)], 1.2),
    # One clear note
    'ding': ([bell(1760.0, 0.0, 0.9, decay=5.0)], 0.95),
    # Two low, gentle notes
    'soft': ([bell(523.25, 0.0, 1.0, 0.9, decay=3.5), bell(783.99, 0.16, 0.9, 0.7, decay=3.5)], 1.1),
}


def render(voices, seconds):
    frames = [sum(v(i / RATE) for v in voices) for i in range(int(RATE * seconds))]
    peak = max(abs(f) for f in frames) or 1.0
    scale = 0.7 * 32767 / peak
    return b''.join(struct.pack('<h', int(f * scale)) for f in frames)


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


for name, (voices, seconds) in TONES.items():
    data = render(voices, seconds)
    write(os.path.join(ROOT, 'ios', 'Runner', f'{name}.wav'), data)
    write(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw', f'{name}.wav'), data)
    print(f'{name}.wav: {len(data) / 2 / RATE:.2f}s')
