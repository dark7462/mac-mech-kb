#!/usr/bin/env python3
"""Validate recorded sources, metadata, and optionally a finished app bundle."""
import argparse
import array
import hashlib
import json
import math
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = {"Blue", "Brown", "Red"}
NAMES = {f"normal-{i:02d}" for i in range(1, 7)} | {"space", "enter", "backspace"}
SOUNDS = Path("Sources/MechanicalKeyboard/Resources/Sounds")


def require(condition, message):
    # Unlike assert, these release checks remain active with python -O.
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(root=ROOT, bundle=None):
    report = json.loads((root / "AudioSources/processing-report.json").read_text())
    manifest = json.loads((root / "AudioSources/manifest.json").read_text())
    require(set(manifest["presets"]) == PRESETS, "Expected Blue, Brown and Red presets")
    for preset, source in manifest["presets"].items():
        require(set(source["cuts"]) == NAMES, f"Incomplete preset: {preset}")
    expected = {str(SOUNDS / preset / (name + ".wav")) for preset in PRESETS for name in NAMES}
    samples = report["samples"]
    require(len(samples) == 27 and {s["file"] for s in samples} == expected, "Incomplete or duplicate sample report")
    actual = {str(path.relative_to(root)) for path in (root / SOUNDS).rglob("*.wav")}
    require(actual == expected, "Missing or unexpected WAV files")
    source_files = {source["file"] for source in manifest["presets"].values()}
    require(set(report["sources"]) == source_files, "Source hashes do not match manifest")
    hashes = set()
    for item in samples:
        path = root / item["file"]
        preset, filename = Path(item["file"]).parts[-2:]
        source = manifest["presets"][preset]
        pitch = source.get("pitch_semitones", 0)
        require(math.isfinite(pitch) and -3 <= pitch <= 3, f"Invalid pitch: {preset}")
        decode_rate = round(48000 / 2 ** (pitch / 12))
        require(item["pitch_semitones"] == pitch and item["source_sample_rate"] == decode_rate, f"Wrong pitch processing: {path}")
        require(item["source"] == source["file"], f"Wrong source: {path}")
        require([item["start"], item["end"]] == source["cuts"][Path(filename).stem], f"Wrong excerpt times: {path}")
        digest = sha256(path)
        require(digest == item["sha256"], f"Changed audio: {path}")
        require(digest not in hashes, f"Duplicate audio: {path}")
        hashes.add(digest)
        with wave.open(str(path), "rb") as wav:
            require((wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (48000, 1, 2), f"Wrong format: {path}")
            frame_count = wav.getnframes()
            require(0.03 <= frame_count / 48000 <= 0.20, f"Wrong duration: {path}")
            require(frame_count == round(item["end"] * decode_rate) - round(item["start"] * decode_rate), f"Excerpt length mismatch: {path}")
            values = array.array("h", wav.readframes(frame_count))
            if sys.byteorder != "little":
                values.byteswap()
        require(len(values) == frame_count, f"Truncated PCM data: {path}")
        require(values[0] == values[-1] == 0, f"Unfaded edge: {path}")
        require(100 < max(abs(v) for v in values) <= 8520, f"Invalid peak: {path}")
        peak_frame = max(range(len(values)), key=lambda i: abs(values[i]))
        require(peak_frame < 720, f"Delayed main strike: {path}")
        energy = sum(v * v for v in values)
        require(sum(v * v for v in values[1440:]) / energy < 0.02, f"Excessive tail energy: {path}")
    for filename, digest in report["sources"].items():
        require(sha256(root / "AudioSources" / filename) == digest, f"Changed source recording: {filename}")
    if bundle:
        bundled = list((bundle / "Contents/Resources").rglob("*.wav"))
        require(len(bundled) == 27, "App must contain exactly 27 WAVs")
        bundled_hashes = {(p.parent.name, p.name): sha256(p) for p in bundled}
        for item in samples:
            preset, filename = Path(item["file"]).parts[-2:]
            require(bundled_hashes.get((preset, filename)) == item["sha256"], f"Stale bundled sample: {preset}/{filename}")
    return len(samples)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, help="Also check an assembled .app")
    args = parser.parse_args()
    try:
        count = verify(bundle=args.bundle)
    except (ValueError, OSError, KeyError, TypeError, wave.Error) as error:
        parser.exit(1, f"Audio verification failed: {error}\n")
    print(f"Verified {count} unique WAVs: format, provenance, fades, attack, tails, peak headroom" + (", and app bundle." if args.bundle else "."))


if __name__ == "__main__":
    main()
