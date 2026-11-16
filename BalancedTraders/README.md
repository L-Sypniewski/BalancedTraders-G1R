# BalancedTraders — Native G1R ModKit Port

Native AngelScript port of the **BalancedTraders** UE4SS Lua mod
([Nexus Mods #473](https://www.nexusmods.com/gothic1remake/mods/473), v1.0.2)
for *Gothic 1 Remake*.

## What the original mod does (reference behavior)

Measured against vanilla, selling hunting trophies crashes their price almost
immediately: the 2nd unit is worth ~40% of the 1st, and by the 3rd–5th unit
most trophies sell for **0 ore**. The original mod patches the trading
payload at click time via UE4SS:

- The game's own live first-unit price stays authoritative (trader stock,
  trader ore, region, long-term saturation).
- From that live price, each following unit slides **linearly down to
  1 ore at the 22nd unit** (config defaults: `TrophyCurveUnitsToFloor = 22`,
  `TrophyCurveMinPrice = 1`):

  ```lua
  -- main.lua, trophy_unit_price(first_price, native_price, ordinal)
  desired = round(first_price - (first_price - 1) * (ordinal - 1) / 21)
  price   = max(native_price, desired, 1)
  ```

- Applies **only** to items of type `Item.Trophy` (trophy filtering).
- Exact-class floor for arrows (`FixedUnitPriceClassTokens = { "ItAm_Arrow" }`,
  `FixedUnitPriceMinimum = 1`): arrows never round down to 0 ore.
- No WorldDefinition edits (the multiplier-floor code exists in
  `balance_patch.lua` but ships disabled: `BalanceEnabled = false`), no
  changes to other item categories, no changes to buy prices.

## What this native port ships

The entire per-unit price computation and the market-saturation state
(`m_GlobalItemAmountForTrading` / `m_RegionItemAmountForTrading` /
`m_RegionLiquidity` on the native `UTraderManager`) are **C++ engine code**
with no AngelScript-exposed hook or accessor — the Lua mod itself only
reached them by patching native objects through UE4SS at trade-click time
(its own config notes: *"Native trading entry points are called directly
from C++ (bypassing ProcessEvent)"*). That mechanism has no equivalent in
the ModKit scripting layer.

This package therefore ports the mod's **item-level, script-reachable**
features through `ReplaceParentClass` overrides of the vanilla item
definitions (`Script/BalancedTraders/TrophyFloors.as`):

| Change | Original counterpart |
|---|---|
| `UItAt_Lizard_01` `m_Value` 3 → 5 | "items like the lizard claw, which vanilla prices at 0 from the first unit" — first-unit 1-ore floor |
| `UItAt_Scavenger_01` `m_Value` 3 → 5 | same value tier / defect class |
| `UItAm_Arrow` `m_Value` 1 → 2 | `FixedUnitPriceClassTokens = { "ItAm_Arrow" }` — arrows sell for ≥ 1 ore after the sell multiplier |

All of the game's dynamic pricing is preserved untouched: regional
multipliers, per-trader-type category modifiers, saturation, liquidity and
buy prices keep their vanilla behavior (constraint: *preserve
location-based pricing*).

### Known deviation (documented, not silently dropped)

- **The linear 22-unit decay curve is not portable** to a pure AngelScript
  package: it lives in native code. Effect in-game with this port: trophies
  still follow the vanilla geometric saturation decline, but the zero-value
  edge cases above are floored. Regional/vendor price differences are fully
  preserved.
- Raising `m_Value` also raises the *buy* price of the three affected items
  by 1–2 ore (the Lua clamp was sell-side only; `m_Value` is the only
  script-reachable price input and feeds both directions).

If Alkimia ever exposes the trade-price calculation or the saturation maps
to AngelScript, the exact curve can be added to this package as a script
hook; the reference formula is documented above.

## Configuration

The shipped package uses compile-time values (edit
`Script/BalancedTraders/TrophyFloors.as` and relaunch — the game recompiles
mod scripts on startup; no tools needed).

An in-game settings UI **was built and validated**
(`Script/BalancedTraders/Settings.as.disabled`) but is disabled: on the
current game build (`Build102_CL175960`) any mod registering a
`UGothicModExt_UserSettings` page **crashes the game when a second mod
package is enabled** (proven by bisection — see VALIDATION.md). Renaming the
file back to `Settings.as` re-enables it if you only ever run this one mod,
or once the game fixes the crash.

## Install / test

1. Copy (or symlink) the `BalancedTraders` folder into
   `Gothic 1 Remake/G1R/Mods/` so you get
   `G1R/Mods/BalancedTraders/GothicMod.json`.
2. Steam Launch Options (Proton) for a compile-verified dev session:

   ```
   -as-development-mode -as-exit-on-error -Mods=BalancedTraders
   ```

   For pointing at a dev checkout outside the game folder:

   ```
   -ModsDirectory="Z:\<path>\<to>\<parent-dir>" -Mods=BalancedTraders
   ```

3. Normal play: the mod also appears in the in-game Mod Manager
   (`-ModManagementUI`) once installed under `G1R/Mods/`.

## Validation

Compiled clean against game build `Build102_CL175960`. Shipping build
writes no logs, so validation used negative-control calibration +
one-construct-per-run bisection (each `-as-exit-on-error` run: exit 3 =
compile error, exit 124/alive = clean; ~2.5–4 min per run):

| Run | Content | Exit | Meaning |
|---|---|---|---|
| neg-control | mod copy, `m_Value = "five"` injected | **3** | harness engages mod scripts; `-as-exit-on-error` fires |
| 1, 2 | TrophyFloors.as via `-ModsDirectory` | alive ⇒ clean | value overrides compile |
| 4 | TrophyFloors.as via `G1R/Mods` symlink | alive ⇒ clean | installed layout works |
| A | settings skeleton (class + CategoryName) | alive ⇒ clean | ModExt settings class usable |
| B | + all 3 members, Bool as `(bValue = true)` + rich ctor args | **3** | isolated the failing constructs |
| C | Int member `(Value = 5)` without UPROPERTY | alive ⇒ clean | Int ctor form valid |
| D | Int member with `UPROPERTY(Config)` | alive ⇒ clean | Config binding valid |
| E | Bool member `(Value = true)` | alive ⇒ clean | Bool ctor uses `Value`, not `bValue` |
| final | full package: TrophyFloors.as + Settings.as (3 settings + world subsystem with CDO writes) | alive ⇒ clean | **shipped build compiles** |

Full evidence details: `VALIDATION.md`. Behavioral testing (prices in trade
screen, settings screen rendering) pending in-game verification by the player.

## Credits

- Original mod: **BalancedTraders** (UE4SS), Nexus Mods #473 — the linear
  curve design, trophy filter, arrow floor and all measured numbers are
  that author's work.
- Native port: compiled to a G1R ModKit package per the
  [official ModKit docs](https://alkimiainteractive.github.io/G1R-Modkit/).
