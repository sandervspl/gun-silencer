# Verification plan

The addon can fail in these ways:

1. It mutes gun sounds while the player has a bow or no ranged weapon.
2. It leaves default gun sounds muted after the gun is unequipped or the addon is disabled.
3. It plays a replacement for another player's attack, for a trap, or for a spell that is not a gun shot.
4. It plays two replacements for one Classic Auto Shot or misses a ranged miss.
5. Any of the six shipped sounds differs from the WowInterface pack, is absent from the package, or cannot be played at the addon path.
6. It tries to register the combat log in Retail Midnight, where that event is restricted.
7. The release package omits any of the six sounds or includes test and development files.
8. Shot variants do not cycle through 01, 02, and 03, or the paired reload variant is wrong.
9. A delayed reload plays after switching away from a gun or disabling and re-enabling the addon.
10. A client without the timer API fails to play a reload sound at all.
11. A supported Hunter shot outside the original small spell list stays silent while gun sounds are muted.
12. Forever registers a restricted combat-log event, or misses repeated Auto Shots because it does not use its ranged swing event.
13. A missing or unloadable replacement sound leaves every later gun shot muted for the rest of the session.
14. Classic higher ranks of a supported shot use different spell IDs and stay silent even though the rank-one spell plays.
15. Temporarily disabling Sound Effects is mistaken for a missing sound file and permanently disables replacements after sound is re-enabled.

`e2e.lua` loads the real addon in simulated Classic, Retail, and Forever client sessions and checks the complete event flow, chat commands, and sound selection. Run it through `scripts/verify.sh`; the script writes `Tests/artifacts/e2e-result.txt` with the command result. An in-game pass with a hunter and a gun is still needed to confirm exact audio timing in the client.
