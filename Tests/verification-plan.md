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

`e2e.lua` loads the real addon in simulated Classic and Retail client sessions and checks the complete event flow, chat commands, and sound selection. Run it through `scripts/verify.sh`; the script writes `Tests/artifacts/e2e-result.txt` with the command result. An in-game pass with a hunter and a gun is still needed to confirm exact audio timing in the client.
