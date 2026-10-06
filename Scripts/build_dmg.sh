#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if (( $# != 0 )); then
    print -u2 -- "Usage: zsh Scripts/build_dmg.sh"
    exit 2
fi

zsh Scripts/build_app.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/MechanicalKeyboard.app/Contents/Info.plist)
filename="MechanicalKeyboard-${version}-arm64.dmg"
staging_directory=$(mktemp -d "$PWD/dist/.dmg-build.XXXXXX")
mount_directory="$staging_directory/mounted"
cleanup() {
    if mount | grep -Fq " on $mount_directory ("; then
        hdiutil detach "$mount_directory" || return 1
    fi
    rm -rf "$staging_directory"
}
trap cleanup EXIT
mkdir -p "$staging_directory/payload" "$mount_directory"
ditto dist/MechanicalKeyboard.app "$staging_directory/payload/MechanicalKeyboard.app"
ln -s /Applications "$staging_directory/payload/Applications"
cp Assets/AppIcon.icns "$staging_directory/payload/.VolumeIcon.icns"
SetFile -a C "$staging_directory/payload"
cat > "$staging_directory/payload/Read Me.txt" <<'INSTALL_NOTES_EOF'
MECHANICAL KEYBOARD
Mechanical sounds. A satisfying thock. Right in your Mac's menu bar.

INSTALL
1. Quit any older copy of Mechanical Keyboard.
2. Drag MechanicalKeyboard.app into Applications, then eject this disk image.
3. Open the app from Applications and look for its keyboard menu-bar icon.
4. Choose Request access and enable the app in System Settings > Privacy &
   Security > Input Monitoring. Quit and reopen it if macOS asks.
5. Pick Blue, Brown, or Red, set the volume, and try Lube for a rounder sound.

FIRST LAUNCH
This release is ad-hoc signed. It is not Developer ID signed or notarized.
If macOS blocks it, try opening it, then use System Settings > Privacy &
Security > Open Anyway for this app if you trust the download.
Apple's instructions: https://support.apple.com/102445
You do not need to disable Gatekeeper.

macOS 13 or later. Apple Silicon Macs only (M1 and newer).
Speakers and wired headphones have less audio delay than Bluetooth earphones.
The app works offline and does not record or transmit your typing.

Help, source, audio credits, and updates:
https://github.com/dark7462/mac-mech-kb
INSTALL_NOTES_EOF

hdiutil create -volname "Mechanical Keyboard" -srcfolder "$staging_directory/payload" \
    -format UDZO -fs HFS+ "$staging_directory/$filename"
hdiutil verify "$staging_directory/$filename"
hdiutil attach "$staging_directory/$filename" -readonly -nobrowse -mountpoint "$mount_directory"
installed_app="$mount_directory/MechanicalKeyboard.app"
codesign --verify --deep --strict --all-architectures --verbose=2 "$installed_app"
[[ "$(lipo -archs "$installed_app/Contents/MacOS/MechanicalKeyboard")" == arm64 ]]
plutil -lint "$installed_app/Contents/Info.plist"
python3 Scripts/verify_sounds.py --bundle "$installed_app"
[[ "$(readlink "$mount_directory/Applications")" == /Applications ]]
[[ -s "$installed_app/Contents/Resources/AppIcon.icns" ]]
hdiutil detach "$mount_directory"

# Publish locally only after the actual mounted payload passes verification.
mv -f "$staging_directory/$filename" "dist/$filename"
(cd dist && shasum -a 256 "$filename" > SHA256SUMS.txt)
print -r -- "$PWD/dist/$filename"
