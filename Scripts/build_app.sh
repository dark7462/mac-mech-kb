#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if (( $# != 0 )); then
    print -u2 -- "Usage: zsh Scripts/build_app.sh"
    exit 2
fi
# Recorded WAV assets are checked in. Never regenerate audio during an app build.
python3 Scripts/verify_sounds.py
mkdir -p .build/cache dist
export CLANG_MODULE_CACHE_PATH="$PWD/.build/cache"
build_options=(--disable-sandbox --manifest-cache none -debug-info-format none -c release
    --triple arm64-apple-macosx13.0 --scratch-path .build/release-arm64)
swift build "${build_options[@]}"
binary_directory=$(swift build "${build_options[@]}" --show-bin-path)
app_path="$PWD/dist/mac-mech-kb.app"
staging_directory=$(mktemp -d "$PWD/dist/.app-build.XXXXXX")
trap 'rm -rf "$staging_directory"' EXIT
staged_app="$staging_directory/mac-mech-kb.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
cp "$binary_directory/mac-mech-kb" "$staged_app/Contents/MacOS/mac-mech-kb"
[[ "$(lipo -archs "$staged_app/Contents/MacOS/mac-mech-kb")" == arm64 ]]
cp -R "$binary_directory/MacMechKB_MacMechKB.bundle" "$staged_app/Contents/Resources/"
cp Sources/MacMechKB/Resources/Info.plist "$staged_app/Contents/Info.plist"
cp AudioLicenses.md LICENSE "$staged_app/Contents/Resources/"
cp Assets/AppIcon.icns "$staged_app/Contents/Resources/"
plutil -lint "$staged_app/Contents/Info.plist"
python3 Scripts/verify_sounds.py --bundle "$staged_app"
# Seal the entire bundle after copying resources. Ad-hoc signing is not notarization.
codesign --force --sign - "$staged_app"
codesign --verify --deep --strict --all-architectures --verbose=2 "$staged_app"
# Replace the generated bundle only after it passes verification. Avoid merging stale files.
if [[ -e "$app_path" ]]; then mv "$app_path" "$staging_directory/previous.app"; fi
if ! mv "$staged_app" "$app_path"; then
    if [[ -e "$staging_directory/previous.app" ]]; then mv "$staging_directory/previous.app" "$app_path"; fi
    exit 1
fi
print -r -- "$app_path"
