# EconomyProbe — measure the native sell-price curve

An [IngameTools](https://alkimiainteractive.github.io/G1R-Modkit/) panel
(developer tool) that records how much ore each sold unit of a tracked item
yields, so the game's native market-saturation price curve can be measured
and fitted. This is the instrument behind the question *"can we infer the
vanilla curve indirectly?"* — see the repo README.

## What it does

- Polls (every frame, only script-visible data): player ore
  (`CountItemsOfClass(UItMi_Orenugget)`) and units of the tracked item
  (default: shadowbeast teeth).
- When units drop and ore rises, records `units_sold -> ore_gained` as one
  observation.
- Shows the running sequence with each step's ratio vs the first unit
  (≈ the saturation multiplier), and copies everything as CSV.

## Protocol for a clean measurement

1. `Steam Launch Options`:
   `-ingametools -Mods=EconomyProbe` (install under `G1R/Mods/` first).
2. New game or a save where the trader still has plenty of ore (liquidity
   also lowers prices — keep it constant across the session).
3. Open Ingame Tools → Economy → Sell Curve Probe.
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
