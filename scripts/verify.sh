#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p Tests/artifacts
{
    printf 'Command: lua Tests/e2e.lua\n'
    sha256sum GunSilencer.lua GunSilencer.toc Sound/Item/Weapons/Gun/*.ogg
    lua Tests/e2e.lua
} | tee Tests/artifacts/e2e-result.txt
