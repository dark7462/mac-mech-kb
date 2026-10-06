#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/cache"
swiftc -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
    Sources/MacMechKB/Keyboard/*.swift \
    Sources/MacMechKB/Audio/*.swift \
    Sources/MacMechKB/Settings/*.swift \
    Sources/MacMechKB/App/AppController.swift \
    Tests/RegressionTests.swift -o .build/regression-tests
.build/regression-tests "$@"
python3 Scripts/verify_sounds.py
python3 -m unittest discover -s Tests -p 'test_*.py'
