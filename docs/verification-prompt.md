# Verification prompt — BalancedTraders-G1R

Hand this prompt to an AI agent that has shell access to the development
machine (Linux + Steam/Proton with Gothic 1 Remake installed). It was
authored 2026-11; verify facts against the repo before trusting them.

---

## ROLE

You are verifying the `BalancedTraders` native ModKit port (and its
companion tool `EconomyProbe`) for *Gothic 1 Remake*, and adding automated
tests where possible. Work autonomously with shell access; the game
requires a display for full behavioral tests (a human can be asked to do
the in-game steps via a question tool if one is available).

## REPO & MACHINE FACTS

- Repository: https://github.com/L-Sypniewski/BalancedTraders-G1R
  (local checkout: `/home/gombka/Documents/Developer/BalancedTraders-G1R`)
- Game: build `Build102_CL175960` at
  `~/.local/share/Steam/steamapps/common/Gothic 1 Remake/`
- Both mods are symlinked into `G1R/Mods/` (BalancedTraders, EconomyProbe)
- Engine facts you MUST internalize before testing (do not re-derive):
  read `docs/g1r-modding-notes.md` in the repo and the workspace
  `AGENTS.md` at `/home/gombka/Documents/Developer/AGENTS.md`. Key points:
  - The shipping build writes **no logs**. Validation = exit-code harness:
    launch with `-as-exit-on-error`; **exit 3 = compile error/crash,
    still alive at `timeout` (exit 124) = clean**. Boots take 2–4 min.
  - **`Mods.ini`** (`compatdata/1297900/pfx/.../AppData/Local/G1R/Saved/
    Mods.ini`) persists enabled mods and auto-loads them every launch —
    check it before every isolating run.
  - Known build-102 bug: a `UGothicModExt_UserSettings` settings page
    crashes the game when a second mod is enabled (that is why
    `Settings.as.disabled` is disabled — do not enable it except in a
    single-mod run if you deliberately test that bug).
  - Launch command template (Proton) is in AGENTS.md; kill leftovers with
    `kill -9` on the Shipping.exe PIDs (avoid `pkill -f` self-matches).

## TASK 1 — Re-verify compile state (automated)

1. Re-run the negative control once (inject `m_Value = "five";` into a copy
   of TrophyFloors.as in a scratch `-ModsDirectory`, expect exit 3) to
   confirm the harness still engages mod scripts on the current game build.
2. Clean runs to confirm (expect alive-at-timeout 124):
   - `-as-exit-on-error -Mods=BalancedTraders` (G1R/Mods layout)
   - `-as-exit-on-error -Mods=BalancedTraders,EconomyProbe` (with and
     without `-ingametools`)
   - with `-as-ignore-precompiled-data` added once (full vanilla recompile)
3. Record results in a new `VERIFICATION.md` (append-style; do not rewrite
   history in VALIDATION.md).

## TASK 2 — Add an automated self-test mod (code)

There is no test framework for G1R AngelScript. Build a self-test as an
IngameTools panel in a new mod package `BalancedTradersSelfTest/` (same
repo, `GothicMod.json`, `#if WITH_IMGUI`-guarded script), that asserts at
the press of a button and prints PASS/FAIL lines via ImGui:

- `UItAt_Lizard_01.DefaultObject.m_Value == 5` (and Scavenger_01 == 5,
  `UItAm_Arrow.DefaultObject.m_Value == 2`) — the ported floors,
  WITH the BalancedTraders mod enabled (ReplaceParentClass must have
  applied).
- Same three values WITHOUT the mod (launch `-Mods=BalancedTradersSelfTest`
  only; clean Mods.ini first) must be 3 / 3 / 1 — vanilla baseline,
  proving the overrides actually come from the mod and nothing else.
- `UItAt_Shadow_03.DefaultObject.GetItemType()` matches `Item.Trophy`
  (type tags intact; also check one NonTrade-tagged item is untouched).
- `UItAt_Lizard_01` still `IsChildOf(UItemDefinition::StaticClass())` after
  replacement (class hierarchy sane).
- Multi-mod coexistence: self-test + BalancedTraders + EconomyProbe all
  enabled, no crash (this is also the regression test for the settings
  bug: it must stay crashed-free as long as no settings page exists).
- Bonus (if cheap): verify `UDefaultWorldDefinition.DefaultObject.
  m_RegionalMultiplierMin == -1.0` (floors module still disabled).

Constraints: only documented, build-102-proven AngelScript idioms (copy
from the existing scripts and vanilla `Script/IngameTools/`); no Script
Patches, no paks, no Python; every new pattern you are unsure about gets
its own compile-run probe before assembly (one construct per run).
Compile-validate the self-test with the harness before finishing.

## TASK 3 — Behavioral verification (needs the game running)

If you can launch the game to the main menu you can verify compile +
self-test panel outcomes yourself via the panel's status text (readable
only by a human — if no human is available, prepare the session and hand
the in-game steps to the user via a question tool):

1. `-ingametools -Mods=BalancedTraders,EconomyProbe,BalancedTradersSelfTest`
2. New game → run SelfTest panel → expect all PASS.
3. Economy session (the actual product test): top menu → Economy →
   Sell Curve Probe → click "Cavalorn" (teleport + trader ore) → preset
   shadowbeast teeth → Give 50 → sell ONE unit per trade acceptance ~25
   times → Copy CSV. Repeat at Cipher (General, contrast). Paste CSVs.
4. Floor check of the port itself: at a Herbalist (−0.2 on trophies),
   sell one lizard claw / scavenger teeth / arrow — each must show
   ≥ 1 ore (vanilla shows 0 at some traders). With the mod DISABLED,
   confirm the 0-ore case exists (baseline contrast for the README table).

## TASK 4 — Analyze and document

- From the CSVs write `curve-fit.md` (repo root): fit P_n/P_1 (log-linear
  → geometric factor; flattening floor → multiplier clamps), separate the
  category modifier (+0.2 Hunter vs −0.1 General) from saturation, and
  state whether `WorldDefinitionFloors.as.disabled` (−0.25 floors) would
  approximate BalancedTraders' linear-to-1-ore-at-22 curve or not.
- Update `VERIFICATION.md` with everything you measured. Do not weaken or
  delete existing evidence in VALIDATION.md.

## ACCEPTANCE CRITERIA

- Compile harness re-calibrated and all clean runs reproducible.
- `BalancedTradersSelfTest` compiles, all assertions PASS with the mod,
  and vanilla baselines (3/3/1) confirmed without it.
- In-game floor check passes (≥1 ore at harsh trader) with mod, and the
  vanilla 0-ore baseline is documented.
- `curve-fit.md` exists with fitted parameters or an explicit statement of
  what data is still missing.
- All changes pushed to a branch or PR against main (do not force-push).

## GUARDRAILS

- Never modify game files or the vanilla script tree; mods only.
- Keep attribution (Altos25, Nexus #473) intact everywhere.
- Do not enable `Settings.as.disabled` in multi-mod runs.
- If a probe contradicts documented facts (e.g., exit codes change after a
  game update), re-calibrate the harness first, then re-verify.
