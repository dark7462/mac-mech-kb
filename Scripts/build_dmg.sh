#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if (( $# != 0 )); then
    print -u2 -- "Usage: zsh Scripts/build_dmg.sh"
    exit 2
fi

# Keep packaging dependencies isolated from the user's system Python.
packaging_python="$PWD/.build/dmg-tools/bin/python"
if [[ ! -x "$packaging_python" ]]; then
    python3 -m venv .build/dmg-tools
fi
if ! "$packaging_python" -c 'import dmgbuild, ds_store, mac_alias; from importlib.metadata import version; assert version("dmgbuild") == "1.6.5"' 2>/dev/null; then
    "$packaging_python" -m pip install --disable-pip-version-check -r Scripts/dmg-requirements.txt
fi

zsh Scripts/build_app.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/mac-mech-kb.app/Contents/Info.plist)
filename="mac-mech-kb-${version}-arm64.dmg"
staging_directory=$(mktemp -d "$PWD/dist/.dmg-build.XXXXXX")
mount_directory="$staging_directory/mounted"
mounted=false
cleanup() {
    if [[ "$mounted" == true ]]; then
        hdiutil detach "$mount_directory" || return 1
    fi
    rm -rf "$staging_directory"
}
trap cleanup EXIT
mkdir -p "$mount_directory"
"$PWD/.build/dmg-tools/bin/dmgbuild" -s Scripts/dmg_settings.py \
    -D "app=$PWD/dist/mac-mech-kb.app" -D "assets=$PWD/Assets" \
    "mac-mech-kb" "$staging_directory/$filename"

hdiutil verify "$staging_directory/$filename"
hdiutil attach "$staging_directory/$filename" -readonly -nobrowse -mountpoint "$mount_directory"
mounted=true
installed_app="$mount_directory/mac-mech-kb.app"
codesign --verify --deep --strict --all-architectures --verbose=2 "$installed_app"
[[ "$(lipo -archs "$installed_app/Contents/MacOS/mac-mech-kb")" == arm64 ]]
plutil -lint "$installed_app/Contents/Info.plist"
python3 Scripts/verify_sounds.py --bundle "$installed_app"
[[ "$(readlink "$mount_directory/Applications")" == /Applications ]]
[[ -s "$installed_app/Contents/Resources/AppIcon.icns" ]]
"$packaging_python" - "$mount_directory" <<'VERIFY_LAYOUT_EOF'
import sys
from pathlib import Path
from ds_store import DSStore
volume = Path(sys.argv[1])
visible = {p.name for p in volume.iterdir() if not p.name.startswith('.')}
assert visible == {'mac-mech-kb.app', 'Applications'}, visible
with DSStore.open(str(volume / '.DS_Store'), 'r') as layout:
    assert layout['mac-mech-kb.app']['Iloc'] == (170, 190)
    assert layout['Applications']['Iloc'] == (470, 190)
    assert layout['.']['icvp']['iconSize'] == 112
print('Verified two-icon drag-to-Applications layout; no Read Me file.')
VERIFY_LAYOUT_EOF
hdiutil detach "$mount_directory"
mounted=false

# Publish locally only after the actual mounted payload passes verification.
mv -f "$staging_directory/$filename" "dist/$filename"
(cd dist && shasum -a 256 "$filename" > SHA256SUMS.txt)
print -r -- "$PWD/dist/$filename"
