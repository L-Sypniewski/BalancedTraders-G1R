// BalancedTraders — native AngelScript port (of the UE4SS Lua mod, Nexus Mods #473, v1.0.2)
//
// Ported feature (item-level 1-ore floor):
//   The Lua mod clamps every marginal trophy/arrow unit to at least 1 ore
//   (`max(native_price, desired, TrophyCurveMinPrice)` in main.lua). The
//   per-click clamp itself runs inside the game's native trading pipeline
//   (UGothicTraderPayload row patching via UE4SS), which is not reachable
//   from AngelScript. The script-reachable source of truth for an item's
//   price is UItemDefinition::m_Value, which the native pricer multiplies
//   with trader-type / region / saturation / liquidity factors.
//
//   Raising m_Value of the items the mod explicitly called out as selling
//   for 0 ore from the first unit (README: "items like the lizard claw,
//   which vanilla prices at 0 from the first unit" and "Arrows that
//   vanilla rounds down to 0") guarantees a >= 1 ore result under the
//   worst-case vanilla sell multipliers, while leaving every dynamic
//   multiplier (region, trader type, saturation, liquidity) untouched.
//
// NOT ported (native-only, see README.md):
//   - The linear 22-unit saturation decay curve
//     (trophy_unit_price: price(k) = round(P1 - (P1-1)*(k-1)/21), floored at 1).
//     The saturation state (m_GlobalItemAmountForTrading /
//     m_RegionItemAmountForTrading on UTraderManager) and the per-unit price
//     computation are native C++ with no script-exposed hook or accessor.
//   - The WorldDefinition multiplier floors (LiquidityMinFloor/
//     RegionalMinFloor -0.25): already DISABLED in the shipped Lua config
//     (BalanceEnabled = false), so the reference mod does not apply them.

// Lizard claw: 3 -> 5. Vanilla could round its first-unit price to 0 ore at
// harsh traders (BalancedTraders README, "lizard claw" example).
UCLASS(meta = (ReplaceParentClass))
class UItAt_Lizard_01_BalancedTraders : UItAt_Lizard_01
{
	default m_Value = 5;
}

// Scavenger teeth: 3 -> 5. Same value tier and defect class as the lizard
// claw ("items LIKE the lizard claw").
UCLASS(meta = (ReplaceParentClass))
class UItAt_Scavenger_01_BalancedTraders : UItAt_Scavenger_01
{
	default m_Value = 5;
}

// Arrows: 1 -> 2. Mirrors the Lua config's exact-class floor
// (FixedUnitPriceClassTokens = { "ItAm_Arrow" }, FixedUnitPriceMinimum = 1):
// after the game's sell multiplier, arrows now round to at least 1 ore.
// Bolts (UItAm_Bolt) are intentionally untouched, matching the Lua token
// match, which only covers "ItAm_Arrow".
UCLASS(meta = (ReplaceParentClass))
class UItAm_Arrow_BalancedTraders : UItAm_Arrow
{
	default m_Value = 2;
}
