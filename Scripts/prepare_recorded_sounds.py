#!/usr/bin/env python3
"""Prepare the checked-in CC0 recordings. Requires only Python + macOS afconvert.

Normal app builds use the resulting checked-in WAVs and do not run this script.
To reproduce: python3 Scripts/prepare_recorded_sounds.py
"""
import array
import hashlib
import io
import json
import math
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "AudioSources"
OUTPUT = ROOT / "Sources/MechanicalKeyboard/Resources/Sounds"
CACHE = ROOT / ".build/audio"
RATE = 48000


def read_wave(path, sample_rate=RATE):
    with wave.open(str(path), "rb") as wav:
        if (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) != (sample_rate, 1, 2):
            raise ValueError(f"Unexpected audio format: {path}")
        values = array.array("h", wav.readframes(wav.getnframes()))
    if sys.byteorder != "little":
        values.byteswap()
    return values


def encode_wave(samples):
    if not samples or any(not math.isfinite(x) or abs(x) > 1 for x in samples):
        raise ValueError("Cannot encode empty, non-finite or clipped audio")
    pcm = array.array("h", (round(x * 32767) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    encoded = io.BytesIO()
    with wave.open(encoded, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    return encoded.getvalue()


def bass_shelf(samples):
    """A +5 dB low shelf at 300 Hz, with a monotonic slope (S=1).

    RBJ biquad equations: https://www.w3.org/TR/audio-eq-cookbook/
    Applied offline so the live playback path needs no additional effect unit.
    """
    amplitude = 10 ** (5 / 40)
    omega = 2 * math.pi * 300 / RATE
    cosine = math.cos(omega)
    beta = math.sqrt(2 * amplitude) * math.sin(omega)
    plus, minus = amplitude + 1, amplitude - 1
    a0 = plus + minus * cosine + beta
    a1 = -2 * (minus + plus * cosine) / a0
    a2 = (plus + minus * cosine - beta) / a0
    b0 = amplitude * (plus - minus * cosine + beta) / a0
    b1 = 2 * amplitude * (minus - plus * cosine) / a0
    b2 = amplitude * (plus - minus * cosine - beta) / a0
    x1 = x2 = y1 = y2 = 0.0
    result = []
    for value in samples:
        output = b0 * value + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, value, y1, output
        result.append(output)
    return result


def prepare(raw, *, special=False):
    if len(raw) < 2:
        raise ValueError("Audio excerpt is empty or too short")
    # Remove desk rumble before balancing levels; preserve the recorded attack.
    alpha = 1 / (1 + 2 * math.pi * 55 / RATE)
    previous_input = previous_output = 0.0
    result = []
    for value in raw:
        value /= 32768
        filtered = alpha * (previous_output + value - previous_input)
        previous_input, previous_output = value, filtered
        result.append(filtered)
    result = bass_shelf(result)
    attack, release = 12, 384
    # Keep the strike's body, then ease out room noise and later release clicks.
    # Special-key excerpts retain a little more body than ordinary typing keys.
    hold = RATE * (0.012 if special else 0.010)
    decay = RATE * (0.016 if special else 0.012)
    for i in range(len(result)):
        result[i] *= min(1, i / attack, (len(result) - 1 - i) / release)
        result[i] *= math.exp(-max(0, i - hold) / decay)
    peak = max(abs(x) for x in result)
    energy = sum(x * x for x in result)
    if peak == 0 or energy == 0:
        raise ValueError("Audio excerpt is silent")
    # Match hit energy over a common 100 ms window, while retaining peak headroom.
    gain = min(0.26 / peak, 0.020 * math.sqrt(RATE * 0.1 / energy))
    return [x * gain for x in result]


def audition(prepared):
    """Individual keys followed by uneven typing, close pairs, and chords."""
    timeline = [0.0] * (RATE * 7)
    events = [(0.2 + i * 0.27, name) for i, name in enumerate(prepared)]
    position = 2.9
    intervals = (0.095, 0.067, 0.11, 0.038, 0.082, 0.058)
    for i in range(36):
        name = "space" if i % 8 == 7 else f"normal-{i % 6 + 1:02d}"
        events.append((position, name))
        position += intervals[i % len(intervals)]
    events.extend([(6.0, "normal-01"), (6.0, "normal-03"), (6.0, "normal-05"),
                   (6.2, "enter"), (6.35, "backspace")])
    for position, name in events:
        frame = round(position * RATE)
        for offset, value in enumerate(prepared[name]):
            timeline[frame + offset] += value * 0.75
    return encode_wave(timeline)


def main():
    manifest = json.loads((SOURCE / "manifest.json").read_text())
    CACHE.mkdir(parents=True, exist_ok=True)
    report = {"processing": {
        "high_pass_hz": 55, "bass_shelf_hz": 300, "bass_shelf_db": 5,
        "peak_ceiling": 0.26,
        "normal_hold_ms": 10, "normal_decay_ms": 12,
        "special_hold_ms": 12, "special_decay_ms": 16,
        "fade_in_ms": 0.25, "fade_out_ms": 8,
        "rms_target_over_100_ms": 0.020
    }, "sources": {}, "samples": []}
    pending_files = {}
    for preset, source in manifest["presets"].items():
        pitch = source.get("pitch_semitones", 0)
        if not math.isfinite(pitch) or not -3 <= pitch <= 3:
            raise ValueError(f"Invalid pitch offset: {preset}")
        # Resample with macOS's high-quality converter, then write at 48 kHz.
        # This raises pitch and slightly shortens the Blue hits entirely offline.
        decode_rate = round(RATE / 2 ** (pitch / 12))
        source_path = SOURCE / source["file"]
        decoded = CACHE / (preset.lower() + ".wav")
        subprocess.run([
            "afconvert", "-f", "WAVE", "-d", f"LEI16@{decode_rate}", "-c", "1", "-r", "127",
            str(source_path), str(decoded)
        ], check=True)
        data = read_wave(decoded, decode_rate)
        report["sources"][source["file"]] = hashlib.sha256(source_path.read_bytes()).hexdigest()
        prepared = {}
        for name, (start, end) in source["cuts"].items():
            if not (math.isfinite(start) and math.isfinite(end)
                    and 0 <= start < end <= len(data) / decode_rate
                    and 0.03 <= end - start <= 0.20):
                raise ValueError(f"Invalid excerpt interval: {preset}/{name}")
            samples = prepare(data[round(start * decode_rate):round(end * decode_rate)],
                              special=not name.startswith("normal-"))
            path = OUTPUT / preset / (name + ".wav")
            pending_files[path] = encode_wave(samples)
            prepared[name] = samples
            report["samples"].append({
                "file": str(path.relative_to(ROOT)),
                "source": source["file"], "start": start, "end": end,
                "pitch_semitones": pitch, "source_sample_rate": decode_rate,
                "peak_dbfs": round(20 * math.log10(max(abs(x) for x in samples)), 2),
                "peak_at_ms": round(max(range(len(samples)), key=lambda i: abs(samples[i])) / RATE * 1000, 2),
                "energy_after_30_ms_percent": round(100 * sum(x * x for x in samples[1440:]) / sum(x * x for x in samples), 2),
                "sha256": hashlib.sha256(pending_files[path]).hexdigest()
            })
        pending_files[ROOT / "dist/AudioPreviews" / (preset + ".wav")] = audition(prepared)
    # Validate/prepare all excerpts before replacing any existing pack.
    for path, contents in pending_files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)
    (SOURCE / "processing-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Prepared {len(report['samples'])} recorded samples and three audition clips.")


if __name__ == "__main__":
    main()
