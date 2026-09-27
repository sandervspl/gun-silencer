# GunSilencer

GunSilencer mutes WoW's gun firing and reload sound files while your character has a gun equipped, then plays a silenced shot for recognized gun attacks. It needs no WeakAuras or Details! installation.

## Install

Copy this folder to `World of Warcraft/<game version>/Interface/AddOns/GunSilencer`, then restart the game. On Windows, `scripts/copy-to-wow.ps1` finds installed WoW clients and copies the addon; pass a WoW root with `-WowRoot` if it is not found automatically. Use `-WhatIf` to preview the destinations.

Examples:

```powershell
.\scripts\copy-to-wow.ps1 -WhatIf
.\scripts\copy-to-wow.ps1 -WowRoot 'C:\Program Files (x86)\World of Warcraft'
```

## Commands

```text
/gunsilencer on
/gunsilencer off
```

The shorter `/gsilencer` alias also works. The setting is saved per account.

Classic uses ranged combat log events for Auto Shot and selected shot spells. Retail Midnight blocks addon access to the combat log, so Retail uses your character's spellcast events for Auto Shot and selected shot spells. Sounds attached to other spells may still play in Retail. Muting game sound files is global while you have a gun equipped, so nearby players' original gun sounds are muted too.

## Verify and release

Run `sh scripts/verify.sh` where Lua is installed (WSL works on Windows). It loads the shipped Lua file in Classic and Retail client simulations and writes `Tests/artifacts/e2e-result.txt`. The [verification plan](Tests/verification-plan.md) records the failure cases it exercises. For an in-game check, equip a gun, fire and miss several Auto Shots, swap to a bow, then run `/gunsilencer off` and `on`.

Mechanic's current `addon.validate` parser flags the comma-separated interface list as outdated. The BigWigs packager recognizes all six interface versions, so the CI verification uses the event-flow exercise and the release job uses the packager.

Pushes and pull requests run the verification workflow. Tags run the BigWigs packager, which reads all supported interface versions from the TOC and creates one multi-client archive. The CurseForge project ID is configured in the TOC; publishing also requires the `CF_API_KEY` repository secret. Add a Wago project ID to the TOC and its repository secret if publishing there.
