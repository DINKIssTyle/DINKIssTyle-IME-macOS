#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dkst-tests.XXXXXX")
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
SOURCES=(Sources/InputController.m Sources/InputController+ClientPolicy.m
         Sources/InputController+Hanja.m Sources/DKSTCompositionState.m
         Sources/DKSTHangul.m Sources/DKSTKeyMap.m Sources/DKSTConstants.m
         Sources/DKSTHanjaDictionary.m)
case "${DKST_TEST_MODE:-release}" in
    release) TEST_FLAGS=(-O2 -DNDEBUG) ;;
    debug) TEST_FLAGS=(-O0 -DDEBUG) ;;
    *) echo "DKST_TEST_MODE must be release or debug" >&2; exit 1 ;;
esac
for source in Sources_Tester/*Tests.m; do
    name=$(basename "$source" .m)
    clang "${TEST_FLAGS[@]}" -I Sources -framework Cocoa -framework InputMethodKit -framework Carbon \
        "$source" "${SOURCES[@]}" -o "$TEST_BUILD_DIR/$name"
    "$TEST_BUILD_DIR/$name"
    echo "PASS: $name"
done
python3 Sources_Tester/DictionaryUpdaterTests.py
