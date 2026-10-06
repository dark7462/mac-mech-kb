# Audio sources and licenses

The app bundles **27 excerpts from real mechanical-keyboard recordings**.
All three recordings were published under **CC0 1.0** on their individual
Freesound pages, verified and downloaded on **2026-10-06**.

| Preset | Recording and creator | Hardware described by creator |
| --- | --- | --- |
| Blue | [Typing on a keyboard — SamsterBirdies](https://freesound.org/people/SamsterBirdies/sounds/489424/) | Cherry MX Blue |
| Brown | [Mechanical keyboard typing sounds — Reina0613](https://freesound.org/people/Reina0613/sounds/709460/) | ikki68 Aurora with hand-lubed WS Brown tactile switches |
| Red | [Typing on a keyboard — SamsterBirdies](https://freesound.org/people/SamsterBirdies/sounds/489422/) | Gateron Red |

License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
The sources permit copying, modification, distribution and commercial use.
Credits are retained voluntarily.

## Downloaded material

The public high-quality MP3 previews linked by Freesound were downloaded.
These are compressed versions of the creators' recordings, not the lossless
original uploads. No audio was extracted from YouTube.

The downloaded MP3s are retained in `AudioSources/`. Downloaded source-page
snapshots are local verification artifacts and are excluded from Git.
`AudioSources/manifest.json` records the creator, page, download URL, license,
and exact excerpt times for every output. `processing-report.json` records
SHA-256 hashes for each source and finished WAV.

## Processing and key assignments

`Scripts/prepare_recorded_sounds.py` converts the recordings to 48 kHz mono,
extracts short hits aligned to the main strike, and applies a 55 Hz high-pass
filter, a +5 dB bass shelf at 300 Hz, and short edge fades. Blue is raised one
semitone with macOS sample-rate conversion before writing at 48 kHz. A smooth
decay after the first 10 ms (12 ms for special keys) reduces lingering room
sound and secondary impacts. Levels are
balanced with a peak ceiling of 0.26 (approximately −11.7 dBFS), leaving room
for overlapping keystrokes, then written as 16-bit PCM WAV files. No synthesized
layers are added. The processing report includes pitch, attack and tail measurements.

Each preset has six distinct normal-key excerpts and three additional excerpts
assigned to Space, Enter and Backspace. The continuous source recordings do
not identify individual keys, so these assignments do **not** claim to be
verified recordings of those specific physical keys.

The app build uses the prepared WAV files directly; it never regenerates audio.

When a preset loads, the app derives unique per-key tones from these excerpts
using high-quality sample-rate conversion, with three small repeat variations.
No additional recordings are introduced. The optional **Lube** effect adds a
350 Hz bass shelf, reduces upper clicks above 1.6 kHz, and rolls off the highest
frequencies. Preset-specific makeup gain (Blue +9.5 dB, Brown +3.25 dB, Red +4 dB)
compensates for the filtering's level reduction; the output limiter still protects
overlapping strokes. It is a stylized sound treatment, not a claim that each
source was recorded both before and after physical lubrication.

Lube references: [Glorious switch-lubing guide](https://www.gloriousgaming.com/en-fr/pages/guide-howto-lube-switches)
and [Switch and Click's Gateron Red comparison](https://www.youtube.com/watch?v=StflQIsQCoE).
No audio was copied from YouTube. Bass filter equations follow the
[W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/).
