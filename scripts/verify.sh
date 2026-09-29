#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p Tests/artifacts
result=Tests/artifacts/e2e-result.txt
{
    printf 'Command: lua Tests/e2e.lua\n'
    sha256sum GunSilencer.lua GunSilencer.toc Sound/Item/Weapons/Gun/*.ogg
} > "$result"
if lua Tests/e2e.lua >> "$result" 2>&1; then
    cat "$result"
else
    cat "$result"
    exit 1
fi
