# mac-mech-kb

A native macOS 13+ menu-bar app that plays recorded mechanical-keyboard sounds when
you press physical keys. Blue, Brown, and Red each give every supported typing
key a distinct, consistent tone with three subtle variations on repeated presses.
Each preset's tones are derived from six typing excerpts and separate excerpts
assigned to Space, Enter, and Backspace; they are not recordings of every individual key.
Autorepeat, modifiers, F1–F20 and navigation keys are silent. Letters in
shortcuts still sound; Tab, Escape, keypad and international typing keys sound.

## Build and run

Requires macOS 13+, Swift 5.9+ command-line tools, and Python 3. Full Xcode is
not required.

```sh
git clone https://github.com/dark7462/mac-mech-kb.git
cd mac-mech-kb
zsh Scripts/build_app.sh
open dist/MechanicalKeyboard.app
```

The build script verifies the bundled audio, compiles a release
executable, and assembles a local app bundle. It uses the checked-in WAV files
without downloading or regenerating sounds. The bundle uses an example
identifier; change it before signing or distributing. This build is unsigned.
Run `zsh Scripts/test_cli.sh` for the full regression suite. It uses the Swift
command-line tools and Python; full Xcode is not required. The suite checks
routing, non-repeating variations, settings, permission/audio recovery, sleep,
login state and every sound pack. It also renders 32 overlapping voices to
memory to check clipping and muting, verifies that 40 strikes spaced 20 ms apart
overlap independently, checks eight different keys played together against their
individual waveforms, checks the Lube effect, and tests rejection of damaged assets.
It does not request keyboard access, change login settings or play sound.
Restricted runners must allow access to macOS audio components for the offline
engine test.

## Sound controls

**Lube · On/Off** adds a rounder thock by emphasizing the body and softening
upper clicks. It applies to every preset, switches without restarting playback,
and is remembered after quitting. Automatic level compensation keeps its average
typing loudness close to Lube Off at the same volume setting. It is a digital
effect; the Brown source recording already uses physically lubricated switches.

All presets have a bass boost, and Blue's source recordings are raised one
semitone before the individual keys are tuned. Each physical key selects its own
preloaded buffers with small pitch/level variations, even during chords. There
are no group/chord recordings and no app-level queue of keystrokes. The key
callback submits a player immediately; Core Audio renders up to 32 independent
voices. At capacity, the oldest voice is replaced rather than queuing a late hit.
Disk reads, tuning and buffer allocation happen when loading a preset.

## First launch

On first launch, open the menu-bar keyboard icon and select **Request access**.
Grant Input Monitoring in System Settings → Privacy & Security → Input
Monitoring, then restart the app if macOS asks. If a downloaded unsigned build
is blocked by Gatekeeper, use the usual Open Anyway flow for a build you trust;
do not disable Gatekeeper globally.

The menu rechecks access on opening and the app also polls permission while
running. Retry remains available after listener or audio failures. Launch at
login shows when system approval is still pending. macOS Secure Input, such as
in some password fields, can suppress global keyboard events.

## Privacy

The app reads a key-down event's hardware key code and repeat flag in memory
to choose its preloaded sound. It never reads typed characters, stores key
history, logs key events, transmits data, or includes analytics/network SDKs.
All sounds are bundled and work offline.

## Before distributing a release

The core listener, sound engine, presets, preferences, and menu UI are included.
The first release should be validated on real Macs before distribution:

1. Test Input Monitoring grant, denial, revocation, restart, and listener retry
   on macOS 13 and newer. Confirm whether a sandboxed build can create the
   listen-only event tap before considering the Mac App Store.
2. Listen for lag, voice stealing, clipping, and preset balance during fast
   typing and after output changes or sleep/wake. Tune or replace sounds based
   on listening tests.
3. Test launch-at-login registration from a signed app in a stable location.
4. Set a real bundle identifier, sign and notarize a Developer ID build, then
   test a fresh install on another Mac. An App Store release depends on sandbox
   feasibility and review.

## Recorded sounds

Blue uses a Cherry MX Blue recording, Brown uses WS Brown tactile switches,
and Red uses Gateron Red. All three source recordings are CC0. See
[AudioLicenses.md](AudioLicenses.md) for creator credits, sources and processing
details, including how excerpts are assigned to the special keys.

To reproduce the WAV files on macOS:

```sh
python3 Scripts/prepare_recorded_sounds.py
python3 Scripts/verify_sounds.py
```

The source MP3 files are included in `AudioSources/`. The preparation script
also produces seven-second audition clips in `dist/AudioPreviews/`, including
individual source strikes, uneven fast typing, and a chord. Samples have tight
attacks and controlled tails to keep overlapping strokes distinct.

Run `zsh Scripts/test_cli.sh --write-previews` to also render the actual per-key
engine into `dist/AudioPreviews/Blue-LubeOff.wav`, `Blue-LubeOn.wav`, and equivalent
Brown/Red files. These include repeat presses, fast typing, and 2/4/8-key chords.
Quit and reopen the app after rebuilding to load updated sounds and controls.

## Project layout

- `Sources/MechanicalKeyboard/` — menu-bar UI, keyboard listener, audio engine,
  preferences, and bundled WAV files.
- `Scripts/` — build, audio preparation, and verification tools.
- `Tests/` — command-line Swift regression checks and Python audio tests.
- `AudioSources/` — original CC0 recordings, provenance, and processing hashes.
- `dist/` — locally generated app and previews; excluded from Git.

## License

Code is available under the [MIT License](LICENSE). The bundled recordings are
CC0; see [AudioLicenses.md](AudioLicenses.md) for credits and processing details.
