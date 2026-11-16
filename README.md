# BalancedTraders-G1R — native ModKit port + economy research tools

> **Credit where it's due:** this repo is a native AngelScript port of
> **BalancedTraders for Gothic 1 Remake** by **Altos25**
> ([Nexus Mods #473](https://www.nexusmods.com/gothic1remake/mods/473),
> uploaded by Altos2255). The mod design, the measured vanilla-vs-mod price
> tables, the trophy curve formula and every gameplay decision are
> Altos25's work. This port contains **none of the original code** — it is a
> clean-room reimplementation for the official G1R ModKit, published with
> attribution. If you are the original author and want anything changed or
> removed, please open an issue.

## What's in here

| Path | What it is |
|---|---|
| `BalancedTraders/` | The mod package (Steam Workshop-ready): fixes zero-value hunting trophies & arrows via script-level value floors, preserving all dynamic regional/trader pricing |
| `EconomyProbe/` | Developer IngameTools panel that records per-unit sell prices — the instrument for measuring the game's native market-saturation curve |
| `tools/as_diag_client.py` | Minimal client for the AngelScript in-game debug protocol (port 27099) |
| `docs/g1r-modding-notes.md` | Reusable G1R ModKit engineering notes (validated against game build 102) |

## Why the linear trophy curve is not (yet) portable

The original UE4SS mod clamps every marginal trophy unit to
`max(native_price, desired, 1)` with
`desired(k) = round(P1 − (P1 − 1)·(k−1)/21)` by rewriting the native trade
payload at click time. In the ModKit's AngelScript layer the entire
pricing pipeline (saturation maps on `UTraderManager`, per-unit price math,
trade payload widgets) is native C++ with no script-exposed hook — so this
port ships the item-level features (trophy/arrow 1-ore floors) and provides
`EconomyProbe` to *measure* the native curve instead. See
`BalancedTraders/README.md` for the full analysis.

## Status

- Compile-validated against game build `Build102_CL175960` with a
  calibrated `-as-exit-on-error` harness (negative control + bisection,
  evidence in `BalancedTraders/VALIDATION.md`).
- Known game-build-102 bugs affecting mods are documented in
  `docs/g1r-modding-notes.md` (most notably: a crash when a
  `UGothicModExt_UserSettings` settings page coexists with a second enabled
  mod — the reason this port ships without an in-game settings UI).

## License

MIT for the code in this repository (see `LICENSE`). The original
BalancedTraders mod remains the property of its author; this repository
redistributes none of it.
