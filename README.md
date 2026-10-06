<p align="center">
  <img src="docs/banner.svg" alt="mac-mech-kb — Give your keyboard a little character" width="100%" />
</p>

<p align="center">
  <a href="https://github.com/dark7462/mac-mech-kb/releases/latest"><img alt="Download for Mac" src="https://img.shields.io/badge/Download_for_Mac-F0B579?style=for-the-badge&amp;logo=apple&amp;logoColor=171D29" /></a>
  <img alt="macOS 13 or later" src="https://img.shields.io/badge/macOS-13%2B-273242?style=for-the-badge" />
  <img alt="Apple Silicon M1 and newer" src="https://img.shields.io/badge/Apple_Silicon-M1%2B-273242?style=for-the-badge" />
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/License-MIT-273242?style=for-the-badge" /></a>
</p>

<p align="center">
  <strong>Mechanical keyboard sounds for your Mac. A tiny menu-bar app with a lot of character.</strong><br />
  Blue clicks. Brown taps. Red ticks. Optional extra thock.
</p>

<p align="center">
  <a href="#get-it-on-your-mac">Install</a> ·
  <a href="#allow-input-monitoring">Permissions</a> ·
  <a href="#pick-your-feel">Sounds</a> ·
  <a href="#small-app-personal-sound">Features</a> ·
  <a href="#build-it-yourself">Build</a> ·
  <a href="https://github.com/dark7462/mac-mech-kb/issues">Feedback</a>
</p>

---

## Get it on your Mac

**[Download the latest DMG →](https://github.com/dark7462/mac-mech-kb/releases/latest)**

macOS **13 Ventura or later** · **Apple Silicon only (M1 and newer)** · No Swift or Xcode needed to install.

### Install the app

1. Open the [latest release](https://github.com/dark7462/mac-mech-kb/releases/latest) and expand **Assets** if needed.
2. Download the file ending in **`-arm64.dmg`**. The source-code ZIP is for developers.
3. Open the downloaded DMG. Follow **“Drag me to Applications”**: drag **mac-mech-kb** onto the **Applications** folder.
4. Wait for the copy to finish, then eject the **mac-mech-kb** disk image in Finder.
5. Open **Finder → Applications → mac-mech-kb**. Launch the installed copy from Applications.
6. Click the **keyboard icon in the menu bar** at the top of your screen. This is a menu-bar app, so it doesn't open a regular app window.

### If macOS blocks the first launch

> [!IMPORTANT]
> **This release is not Developer ID signed or notarized by Apple.** Only proceed if you trust the release you downloaded. Release assets include a SHA-256 checksum.

1. Try opening **mac-mech-kb** from Applications once.
2. Open **Apple menu → System Settings → Privacy & Security**.
3. Scroll to the security message about **mac-mech-kb** and click **Open Anyway**.
4. Authenticate if prompted, then confirm **Open**. Continue with Input Monitoring below.

See [Apple's first-launch instructions](https://support.apple.com/102445). You do not need to disable Gatekeeper.

### Allow Input Monitoring

**Input Monitoring is required for keystroke sounds while you use other apps.** mac-mech-kb uses physical key codes to choose sounds locally; it doesn't save a typing history or send your input anywhere.

1. Click the **keyboard icon in the menu bar** to open mac-mech-kb.
2. In the **Allow Input Monitoring** card, click **Request access**.
3. Click **Open Settings** in the app, or navigate to **Apple menu → System Settings → Privacy & Security → Input Monitoring**.
4. Find **mac-mech-kb** and turn its switch **on**. Use Touch ID or your Mac password if macOS asks you to authorize the change.
5. If macOS offers **Quit & Reopen**, choose it. Otherwise, choose **Quit** from the app's menu and reopen **mac-mech-kb** from Applications.
6. Open the keyboard menu again and turn **Keyboard sounds** on. Once the status says **Playing**, choose **Blue**, **Brown**, or **Red**, turn up the app volume, and type in a normal text field to try it.

[Apple's Input Monitoring guide](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac) explains where to manage or revoke this permission.

<details>
<summary><strong>App missing from the list, or still no sound?</strong></summary>

- **Not listed:** open the copy in Applications, click **Request access**, then revisit Input Monitoring. If the pane offers a **+** button, use it to add **Applications → mac-mech-kb.app**, then enable its switch.
- **Still says “Input Monitoring needed”:** check that the switch is on for the installed copy. Quit and reopen the app, then click **Refresh status** in its menu. If needed, turn its Input Monitoring switch off and back on, then reopen the app again.
- **Permission enabled but no sound:** check that **Keyboard sounds** is on, the app volume and your Mac's output volume are above zero, and the correct audio output is selected. Try typing in TextEdit outside a password field; Secure Input can block keyboard events. Try speakers or wired headphones if Bluetooth audio feels delayed.

</details>

<details>
<summary><strong>Already running an earlier build?</strong></summary>

Quit the old copy before installing, and remove it afterward if it has a different app name. Keep one copy running at a time. Public releases use the permanent bundle identifier `io.github.dark7462.mac-mech-kb`; builds from before v0.1.0 may need Input Monitoring access and preferences set again.

</details>

## Pick your feel

| Preset | Character | Recorded switch |
| :-- | :-- | :-- |
| 🔵 **Blue** | Bright, crisp, clicky. A little extra pitch. | Cherry MX Blue |
| 🟤 **Brown** | Warm, rounded, tactile. | Hand-lubed WS Brown |
| 🔴 **Red** | Soft, smooth, understated. | Gateron Red |

**Lube on. Thock up.** Flip the Lube switch for a rounder body and softer upper clicks. Automatic level compensation keeps it close to the normal volume. The setting is remembered when you quit.

Lube is a digital sound effect. Each key's tone is tuned from real recordings, with three subtle variations on repeat presses. The source recordings don't identify every physical key; [credits and processing details](AudioLicenses.md) explain how the sounds are made.

## Small app. Personal sound.

- **A voice for each key.** Every supported typing key gets a distinct tone. Chords keep the individual strokes.
- **Ready when you type.** Preloaded audio, independent overlapping playback, and no app-level queue of key sounds.
- **Lives in the menu bar.** Switch presets, toggle Lube, adjust volume, or pause in one place.
- **Remembers your setup.** Preset, volume, Lube, and optional launch at login.
- **Works offline.** No account, service, or audio downloads needed after installation.

### Your typing stays yours

The app uses the hardware key code and repeat flag to choose a sound. It doesn't read typed characters, save a typing history, log key events, or send data anywhere. Sound files are bundled with the app.

## A few things to know

- **Speakers or wired headphones feel most immediate.** Bluetooth earphones can add audio delay.
- **Held keys don't chatter.** Autorepeat, modifiers, F1–F20, and navigation keys are silent. Letters, numbers, punctuation, Tab, Escape, keypad, and international typing keys sound.
- **Secure Input can suppress sounds.** Some password fields and apps prevent global keyboard events from reaching the listener.
- **Audio overlaps freely up to 32 voices.** At capacity, the oldest voice is replaced so new strokes don't wait.
- **Early release.** Tested on the developer's Apple Silicon Mac. Feedback from other M1 and newer Macs is welcome.

## Build it yourself

You'll need an **Apple Silicon Mac (M1 or newer)**, macOS 13+, **Swift 5.9+ command-line tools**, and **Python 3**. Full Xcode is optional.

```sh
git clone https://github.com/dark7462/mac-mech-kb.git
cd mac-mech-kb
zsh Scripts/build_app.sh
open dist/mac-mech-kb.app
```

Build the Apple Silicon app and installer:

```sh
zsh Scripts/build_dmg.sh
```

Builds use the checked-in WAVs and app icon. They don't download or regenerate audio. The packaging script ad-hoc signs the app for integrity; Developer ID signing and notarization require an Apple Developer certificate and a separate release process.

The DMG shows the app, an Applications shortcut, and a “Drag me to Applications” guide. Its first build installs the pinned [dmgbuild](https://dmgbuild.readthedocs.io/) packaging tool into `.build/dmg-tools`; later builds reuse it. No system Python packages or Finder preferences are changed.

<details>
<summary><strong>Tests, audio previews, and asset preparation</strong></summary>

```sh
# Routing, preferences, per-key sounds, overlap, Lube levels, and asset checks
zsh Scripts/test_cli.sh

# Also render Lube on/off previews through the real audio engine
zsh Scripts/test_cli.sh --write-previews

# Rebuild the bundled audio from the original CC0 recordings
python3 Scripts/prepare_recorded_sounds.py
python3 Scripts/verify_sounds.py

# Redraw the native app icon
swift Scripts/prepare_icon.swift

# Redraw the Retina installer background
swift Scripts/prepare_dmg_art.swift
```

Tests render audio into memory. They don't play through your speakers, request keyboard access, or change login settings. Restricted runners need access to macOS audio components. Generated apps, installers, caches, and previews stay in ignored directories.

</details>

<details>
<summary><strong>Around the project</strong></summary>

```text
Sources/MacMechKB/
├── App/          Menu-bar UI and lifecycle
├── Audio/        Playback, per-key voicing, and Lube
├── Keyboard/     Event listener and key routing
├── Settings/     Preferences and permissions
└── Resources/    Bundle metadata and recorded sounds
Assets/           App icon and installer artwork
docs/             README artwork
Scripts/          Build, package, prepare, verify
Tests/            Swift and Python regression checks
AudioSources/     CC0 originals, provenance, and hashes
```

</details>

---

<p align="center">
  Built with SwiftUI + AVAudioEngine.<br />
  Code: <a href="LICENSE">MIT</a> · Recordings: <a href="AudioLicenses.md">CC0, with credits</a><br /><br />
  <a href="https://github.com/dark7462/mac-mech-kb/issues">Found a bug or have a sound suggestion?</a>
</p>
