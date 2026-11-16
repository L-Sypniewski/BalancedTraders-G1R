# EconomyProbe — measure the native sell-price curve

An [IngameTools](https://alkimiainteractive.github.io/G1R-Modkit/) panel
(developer tool) that records how much ore each sold unit of a tracked item
yields, so the game's native market-saturation price curve can be measured
and fitted. This is the instrument behind the question *"can we infer the
vanilla curve indirectly?"* — see the repo README.

## What it does

- Polls (every frame, only script-visible data): player ore
  (`CountItemsOfClass(UItMi_Orenugget)`) and units of the tracked item.
- When units drop and ore rises, records `units_sold -> ore_gained` as one
  observation; shows ratios vs the first unit (≈ saturation multiplier) and
  vs the item's base value (≈ total sell multiplier).
- **Test-rig buttons** (no grinding needed): Give 10 / 50 / 200 of the
  tracked item straight into the player inventory, item presets
  (shadowbeast teeth 25, lizard skin 13, wolf fur 5, arrows), and a custom
  class-name picker.
- **One-click session setup**: each trader button finds the merchant,
  gives them +1000 ore (keeps liquidity constant during the measurement)
  and teleports you to them, streaming-safe: Cavalorn & Wolf (Hunters,
  +0.2 on trophies), Cipher / Dexter / Viper / Fortuno (Generals, -0.1).
  Plus "+1000 ore to me".
- Copies everything as CSV.

## Protocol for a clean measurement

1. `Steam Launch Options`: `-ingametools -Mods=EconomyProbe`
   (install under `G1R/Mods/` first; both flags also settable via the
   Mod Management UI).
2. New game or a save where the trader still has plenty of ore (liquidity
   also lowers prices — keep it constant across the session).
3. The tool appears in the ImGui **top menu bar** → Economy → Sell Curve
   Probe. Pick a preset, "Give 50".
4. Sell **exactly one unit per trade acceptance**, repeatedly, to the same
   trader, same session.
5. Copy CSV. The n-th `ore_delta` is the marginal price of unit n.

## Fitting the curve

With `P_n` = ore delta of the n-th unit and `P_1` the first:

- geometric decay ⇒ `P_n/P_1 ≈ q^(n−1)` — plot `log(P_n/P_1)` vs `n−1`;
  a straight line confirms geometric, slope = `log q`.
- If the ratio flattens at some floor `f`, that floor is the
  `m_RegionalMultiplierMin` / `m_LiquidityMultiplierMin` clamp of the
  WorldDefinition (vanilla −1.0; see
  `G1R-Modkit/Script/LevelScripts/WorldDefinition.as`).
- Repeat per trader type and region to separate the category modifiers
  (e.g. General −0.1 vs Hunter +0.2 on `Item.Trophy`) from saturation.

If enough data is collected, a `curve-fit.md` with the recovered parameters
belongs in this repo — contributions welcome.

## Status

Compile-validated on game build `Build102_CL175960` (together with the
BalancedTraders package, `-ingametools`). Not yet exercised in-game.
