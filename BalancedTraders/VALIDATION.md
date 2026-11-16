# Validation — BalancedTraders native port

Environment: Ubuntu + Steam Proton (Proton Experimental), game build
`Build102_CL175960` (`G1R/Version/version.txt`), game install at
`~/.local/share/Steam/steamapps/common/Gothic 1 Remake/`.

Method note: the shipping build writes no log files (verified — no
`G1R.log` under the game dir, `AppData/Local/G1R/Saved/Logs`, or next to
the exe; `-log` ineffective), and the dev-mode language-server port (27099)
never opened on the shipping exe (two runs with `-as-development-mode`,
watched via `ss -tln` for 9+ min each; protocol client kept at
`../.tools/as_diag_client.py`). Validation therefore used exit-code
semantics of `-as-exit-on-error`: **exit 3 = script compile error (game
self-exits); still-running at a `timeout` (exit 124) = clean compile**,
calibrated with a negative control.

| # | Mod content | Invocation | Result | Conclusion |
|---|---|---|---|---|
| 1 | TrophyFloors.as (real) | `-as-exit-on-error -as-ignore-precompiled-data -Mods=BalancedTraders -ModsDirectory=Z:\…\Developer` | ran 6.5+ min into rendering, killed manually | clean compile |
| 2 | TrophyFloors.as (real) | same + `-log -no-intro-cinematic` | ran into rendering, killed manually | clean compile |
| 3 | **negative control**: copy with `m_Value = "five"` type error | `-as-exit-on-error -as-ignore-precompiled-data -Mods=BalancedTraders-NegTest -ModsDirectory=Z:\tmp\opencode\g1r-mods-negtest` | **self-exited, exit code 3** | harness compiles mod scripts and aborts on error — runs 1–2 meaningful |
| 4 | TrophyFloors.as (real), symlinked `G1R/Mods/BalancedTraders` | `-as-exit-on-error -as-ignore-precompiled-data -Mods=BalancedTraders` | alive at 180 s timeout (124) | installed layout discovered + clean |
| A | settings skeleton: `UCLASS(Config=GameUserSettings)` + `UGothicModExt_UserSettings` + `default CategoryName` | `-as-exit-on-error -Mods=BalancedTraders` | alive (124) | ModExt settings base usable on build 102 |
| B | + Bool `(bValue = true)` + Int `(Value = 5)` + rich ctor args | same | **exit 3** | failing constructs isolated |
| C | Int member `(Value = 5)`, no UPROPERTY | same | alive (124) | Int ctor form valid |
| D | Int member + `UPROPERTY(Config)` | same | alive (124) | Config binding valid |
| E | Bool member `(Value = true)` | same | alive (124) | Bool ctor arg is `Value` (script name), not `bValue` (C++ name) |
| F | full package: TrophyFloors.as + Settings.as (3 settings + subsystem with CDO writes) | `-as-exit-on-error -Mods=BalancedTraders` | alive (124) | full package compiles single-mod |

### Multi-mod series (P7-P16)

Ran during EconomyProbe validation. Key confounder found: the game persists
enabled mods in `.../AppData/Local/G1R/Saved/Mods.ini` and auto-enables them
on later launches, which retroactively explains every "mysterious" failure
where a supposedly-unloaded second package was present.

| Run | Content | Exit | Conclusion |
|---|---|---|---|
| P4 | EconomyProbe (trivial class) alone, /tmp dir | alive (124) | package itself fine |
| P7, P9-P12 | BalancedTraders(with Settings.as) + EconomyProbe (anything, even a trivial dummy class) | **3** | settings page + second enabled package = crash |
| P14 | both packages, Settings.as removed | alive (124) | crash isolated to Settings.as |
| P15 | both packages, subsystem only (no settings class) | alive (124) | subsystem innocent; the `UCLASS(Config=GameUserSettings)` / `UGothicModExt_UserSettings` page is the crasher |
| P16 | **shipped configuration**: TrophyFloors.as + full `#if WITH_IMGUI`-guarded EconomyProbe tool, both enabled, `-ingametools` | alive (124) | **final: multi-mod-safe, compiles clean** |

Shipped result: the settings page ships as `Settings.as.disabled` (game bug,
documented in docs/g1r-modding-notes.md); the optional WorldDefinition
floors module ships as `WorldDefinitionFloors.as.disabled`.

Not yet verified (needs human in-game session): trade-screen prices, and
the EconomyProbe panel behavior.
