# G1R ModKit engineering notes

Reusable, evidence-backed notes for building native Gothic 1 Remake mods.
Established 2026-11 against game build `Build102_CL175960` (Proton
Experimental, Steam). Companion to the machine-local AGENTS.md of the
development workspace.

## Mod package anatomy (pure script mods — no .pak, no Python)

```
<ModName>/
  GothicMod.json     # name, title, author, description, modVersion, loadOrder
  Script/<ModName>/*.as
  ScriptPatches/*.patch   # only when editing vanilla .as files
  Config/                 # .ini
```

## Proven hooking patterns (compile-validated on build 102)

1. **ReplaceParentClass** on script-defined vanilla classes (item defs,
   `UG1RPlayer`, `UDefaultWorldDefinition`, …) — the workhorse.
2. **World subsystem** — `class UMySubsystem : UGothicModExt_WorldSubsystem`
   with `UFUNCTION(BlueprintOverride) void HandleReadyForPlay()` — safe with
   multiple mods; can mutate item-CDO `m_Value` at world start.
3. **IngameTools panel** — `class UMyTool : UIngameTool` overriding
   `DrawImGuiWindow()` / `DrawImGuiAlways()`, set `Category/MenuPath/Title`,
   requires launching with `-ingametools`, and **wrap the file in
   `#if WITH_IMGUI … #endif`** (all vanilla ImGui code is guarded; ImGui
   bindings are conditional).

## Known game-build-102 bugs that bite mods (each proven by bisection)

- **`UGothicModExt_UserSettings` multi-mod crash:** a mod registering a
  settings page crashes the game when any *second* package is enabled — even
  if the other package is an empty dummy. Until fixed, don't ship settings
  pages. (FModUserSettings* ctor args beyond `Value`/`bValue` are also not
  bound on this build: use `FModUserSettingsBool(Value = true)`.)
- **`Mods.ini` persistence:** the game stores enabled mods in
  `<compatdata>/…/AppData/Local/G1R/Saved/Mods.ini` and **auto-enables them
  on every later launch**, regardless of `-Mods=`. This silently turns
  "isolated" test runs into multi-mod runs — check/clean this file before
  drawing conclusions from exit codes.

## Native wall (don't re-derive)

The trading/economy pipeline (saturation maps on `UTraderManager`, per-unit
pricing, trade payload, trading widgets) is native C++ with no script hook
or accessor. UE4SS mods patch it at click time; AngelScript cannot. The
script-reachable economy levers: item `m_Value` (compile-time or CDO),
`UDefaultRegionsDefinition` / `UDefaultTradersTypeDefinition` modifier maps,
`UDefaultWorldDefinition` multiplier bounds (`Script/LevelScripts/
WorldDefinition.as`), trader stock (`UTraderConfig`), item spec tags
(`Item_Property_TraderRegen`, `Item_Property_NonTrade`).

## Validation on a headless-ish Linux box (no game logs exist)

Each `-as-exit-on-error` run is one bit: **exit 3 = script compile error /
crash**, **alive at `timeout` (124) = clean**. Calibrate with a negative
control (injected type error → 3), then bisect constructs one per run
(~2.5–4 min each). Confirm `Mods.ini` state before every run. Mine the API
surface with `strings -a <game>/G1R/Script/Binds.Cache | grep …`; the
shipped vanilla `Script/` tree is the ground truth for dialect idioms
(`#if WITH_IMGUI`, f-string specs like `:.1f`, `ClassName.Get().Name`,
trailing named ctor args).

## Publishing

`-ModManagementUI` → select mod → **Prepare Steam Workshop Item** → details
→ **Upload to SteamWorkshop**. Bump `modVersion` for updates.
