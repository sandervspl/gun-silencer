# GunSilencer

GunSilencer mutes WoW's gun firing and reload sound files for you and nearby players whenever the addon is on, regardless of your equipped weapon. When your character's ranged weapon looks like a gun, including a bow transmogged to a gun, it plays one of three silenced shots and a matching reload sound for your recognized gun attacks. It needs no WeakAuras or Details! installation.

## Install

Install the complete addon folder for the game version you play. Close the game, then put a folder named exactly `GunSilencer` in that version's `Interface/AddOns` directory. Use the `GunSilencer` folder from a release ZIP, or create it from source by copying `GunSilencer.toc`, `GunSilencer.lua`, and the entire `Sound` and `Media` folders into it. The in-game sound and icon paths use the exact `GunSilencer` folder name.

| Game version | Folder under `World of Warcraft` |
| --- | --- |
| Retail / Midnight | `_retail_` |
| Classic progression (including Mists of Pandaria Classic) | `_classic_` |
| Classic Era, Hardcore, and Season of Discovery | `_classic_era_` |
| Burning Crusade Anniversary | `_anniversary_` |
| Forever beta | `_classic_beta_` |

For example, Forever needs this complete addon layout:

```text
World of Warcraft\_classic_beta_\Interface\AddOns\GunSilencer\
  GunSilencer.toc
  GunSilencer.lua
  Media\icon.tga
  Sound\Item\Weapons\Gun\
    GunFire01.ogg
    GunFire02.ogg
    GunFire03.ogg
    GunLoad01.ogg
    GunLoad02.ogg
    GunLoad03.ogg
```

Use the same layout under each version's folder in the table. When updating an older GunSilencer install, copy the current Lua file and sound tree together; older Lua files point to the former `Media` path. Copying only `Sound\Item\Weapons\Gun` into the game-version root is the older loose-file override method; it does not work in Forever beta and is not the installation method for this addon. The Ogg must remain inside `Interface\AddOns\GunSilencer` so the addon can play it.

Restart the game fully, enable GunSilencer in the character-select AddOns list, and equip a gun or a bow with a gun appearance. If the addon is marked out of date, enable "Load out of date AddOns" and check the folder and file paths above. Type `/gunsilencer` in chat to see whether the addon is on; use `/gunsilencer on` if needed. Keep Sound Effects enabled in the game's audio settings.

On Windows, `scripts/copy-to-wow.ps1` finds installed WoW clients and copies the complete addon, including the nested sound file, to each detected version. Pass a WoW root with `-WowRoot` if it is not found automatically. Use `-WhatIf` to preview the destinations.

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

The shorter `/gsilencer` alias also works. The addon is on by default, and the setting is saved per account. It applies your saved setting automatically at login and after loading screens, even before equipment data becomes available. An explicitly saved `off` stays off.

Classic uses ranged combat log events for Auto Shot and cast events for Hunter shots. Retail uses your character's spellcast events. Forever uses its ranged swing event for each Auto Shot and spellcast events for other shots; its combat log is restricted. The supported shots include Arcane, Aimed, Multi, Steady, Cobra, Barbed, Kill, Concussive, Tranquilizing, Explosive, and other listed shot abilities. Classic ranks share a localized name and are recognized together. Aimed Shot plays a loading cue when its cast starts. Shots within 0.2 seconds of the last played gunshot share that sound and its reload, so an ability followed immediately by Auto Shot does not produce overlapping gunshots. Each played shot randomly selects one of the three GunFire variants; the matching GunLoad sound plays about 0.45 seconds later. Reload timing is approximate because the addon has no separate reload event. Sounds attached to other spells may still play in Retail. Nearby players' original gun sounds stay muted even when you equip a bow or unequip your weapon; replacement sounds play for your own gun attacks only. `/gunsilencer off` restores the original gun sounds for everyone you hear.

If a replacement file cannot play while Sound Effects are enabled, the addon restores the original gun sounds for the rest of the session and prints a message. Check that the entire `Sound` folder is installed inside `GunSilencer`, then reload the UI after fixing it.

## Verify and release

Forever is detected by its 1.60 interface version as well as the Retail project ID, so a changed project ID cannot send it through Classic's restricted combat-log registration. The simulated sessions cover Forever with both Retail and non-Retail project IDs, and reject protected combat-log registration at login.

Run `sh scripts/verify.sh` where Lua is installed (WSL works on Windows). It loads the shipped Lua file in Classic, Retail, and Forever client simulations and writes `Tests/artifacts/e2e-result.txt`. The [verification plan](Tests/verification-plan.md) records the failure cases it exercises. For an in-game check, equip a bow with a gun appearance, fire and miss several Auto Shots, use a few class shots such as Cobra Shot and Kill Shot, switch its appearance to a bow and back, then run `/gunsilencer off` and `on`. Have another player fire a gun while you use a bow and while you have no weapon: their gunfire should stay muted while the addon is on and return when you turn it off. Log out and back in with the addon on, then repeat with it off; each setting should apply without a slash command. In Forever, also start Aimed Shot just before the Auto Shot swing timer expires: the blocked Auto Shot should stay silent, Aimed Shot should sound when it fires, and Auto Shot sounds should resume after completing or cancelling the cast.

Mechanic's current `addon.validate` parser flags the comma-separated interface list as outdated. The BigWigs packager recognizes all six interface versions, so the CI verification uses the event-flow exercise and the release job uses the packager.

Pushes and pull requests run the verification workflow. Tags run the BigWigs packager, which reads all supported interface versions from the TOC and creates one multi-client archive. The CurseForge project ID is configured in the TOC; publishing also requires the `CF_API_KEY` repository secret. Add a Wago project ID to the TOC and its repository secret if publishing there.
