#!/usr/bin/env python3
"""Generate a quiet, 60-second local WAV for explicit user media verification."""
import math
from pathlib import Path
import struct
import sys
import wave

destination = Path(sys.argv[1]) if len(sys.argv) == 2 else Path.home() / 'Music/shittim-test.wav'
destination.parent.mkdir(parents=True, exist_ok=True)
# Exclusive creation: never overwrite a user's music.
with destination.open('xb') as output:
    with wave.open(output, 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(22050)
        second = b''.join(struct.pack('<h', int(500 * math.sin(2 * math.pi * 220 * index / 22050))) for index in range(22050))
        for _ in range(60):
            wav.writeframesraw(second)
print(str(destination))
