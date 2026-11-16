# NOTICE

This project is a native AngelScript (Gothic 1 Remake ModKit) port of the
**BalancedTraders** mod for *Gothic 1 Remake*.

## Original work being credited

- **Mod:** BalancedTraders — Smooth Trophy Sell Prices
- **Author:** Altos25 (Nexus Mods; uploaded by Altos2255)
- **Source:** https://www.nexusmods.com/gothic1remake/mods/473 (v1.0.2)

## What was taken from the original

- The mod concept and gameplay goals (smooth trophy price decline, 1-ore
  floor, arrow floor, trophies-only scope).
- The published behavior description and the measured price tables from the
  original README (used as the behavioral specification).
- The linear-decay reference formula (documented, not executable here):
  `desired(k) = round(P1 − (P1 − 1)·(k−1)/21)`, floored at 1 ore.

## What was NOT taken

- No Lua source code, no configuration files, no assets and no text of the
  original mod are included or redistributed. The AngelScript in this
  repository was written from scratch against the official G1R ModKit.

If you are the original author and want this repository changed, renamed,
relicensed or taken down, please open an issue or contact the repository
owner.
