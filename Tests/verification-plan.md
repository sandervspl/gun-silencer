# Verification plan

The addon can fail in these ways:

1. It mutes gun sounds while the player has a bow or no ranged weapon.
2. It leaves default gun sounds muted after the gun is unequipped or the addon is disabled.
3. It plays a replacement for another player's attack, for a trap, or for a spell that is not a gun shot.
4. It plays two replacements for one Classic Auto Shot or misses a ranged miss.
5. Any of the six shipped sounds differs from the WowInterface pack, is absent from the package, or cannot be played at the addon path.
6. It tries to register the combat log in Retail Midnight, where that event is restricted.
7. The release package omits any of the six sounds or includes test and development files.
8. A shot does not randomly select one of variants 01, 02, and 03, consecutive shots cannot repeat a variant, or a delayed reload uses a different variant from its shot when several shots are pending.
9. A delayed reload plays after switching away from a gun or disabling and re-enabling the addon.
10. A client without the timer API fails to play a reload sound at all.
11. A supported Hunter shot outside the original small spell list stays silent while gun sounds are muted.
12. Forever registers a restricted combat-log event, or misses repeated Auto Shots because it does not use its ranged swing event.
13. A missing or unloadable replacement sound leaves every later gun shot muted for the rest of the session.
14. Classic higher ranks of a supported shot use different spell IDs and stay silent even though the rank-one spell plays.
15. Temporarily disabling Sound Effects is mistaken for a missing sound file and permanently disables replacements after sound is re-enabled.
16. A loading screen temporarily hides the equipped gun; the addon unmutes default gun sounds after hearthstoning even though the gun is still equipped.
17. A bow with a gun appearance remains silent because detection only sees the equipped bow, or an applied appearance change is missed without an equipment change.
18. A gun with a bow appearance gets silenced, or a pending reload still plays after changing the appearance away from a gun.
19. Clients that return separate transmog values instead of a structure fail to detect the applied appearance.
20. A ranged swing or Auto Shot notification during Aimed Shot plays a phantom shot and schedules a reload even though no bullet fires.
21. Suppressing that notification also silences Aimed Shot itself, a real shot's pending reload, or Auto Shots after completion, cancellation, interruption, or failure.
22. Another unit's cast, an unrelated spell's success, or a late stop from an older cast incorrectly clears suppression; a higher rank of Aimed Shot is not recognized.
23. Starting Aimed Shot with a visible gun is silent because its normal loading cue is muted; another unit's cast or a cast while gun sounds are not muted incorrectly plays the replacement cue.

`e2e.lua` loads the real addon in simulated Classic, Retail, and Forever client sessions and checks the complete event flow, chat commands, sound selection, and appearance changes. Run it through `scripts/verify.sh`; the script writes `Tests/artifacts/e2e-result.txt` with the command result. An in-game pass with a hunter and a bow using a gun appearance is still needed to confirm exact audio timing in the client.
