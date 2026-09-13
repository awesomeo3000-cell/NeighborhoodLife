# Neighborhood Life: careers, wardrobe and relationship prototype (v0.3)

Target: installed B42.20.4 CharacterStat API; Steam build ID 24909800.
Full scope, outstanding work and evidence requirements are tracked in SCOPE.md.
This is a work-in-progress life simulation, not a completed neighborhood overhaul.

## Install and try
Copy the NeighborhoodLife directory into your Windows user Zomboid/mods directory.
Enable Neighborhood Life - Needs HUD in Mods. For Host play, include
NeighborhoodLifeHUD in the hosted server's Mods list and give your friend the
same mod folder to install. This local prototype has no Workshop ID yet.
Restart the game after installing. Keep vanilla moodles enabled.
Click the panel header to collapse/expand. All percentages show adverse stat
intensity; lower is better. Colors are visual bands, not vanilla moodle thresholds.
The panel is anchored above the bottom-left hotbar area and follows viewport size.
Click its bottom Career journal link for Tailor, Carpenter and Medic career tracks.
Each has four ranks, actual PZ skill requirements and three daily supply requests.
Deliver consumes the displayed quantity from unequipped main-inventory items.
Career XP and community credits are separate from vanilla skill XP. Credits are
recorded but not spendable yet. Career progress persists per account per world.
Right-click the world for Neighborhood wardrobe: three save/wear layer presets.
Wear uses vanilla timed actions and requires the garments in main inventory.
It does not remove unrelated worn layers or create missing clothes.
The HUD footer opens Careers on the left and Relationships on the right.
Relationships use separate friendship, trust and attraction bars, with introductions,
chat, jokes, flirting, dates, partnerships and breakups. They only operate on a neighbor
registered with a real server-side body. The production NPC spawn adapter is unfinished,
so existing worlds currently show an empty-neighborhood message rather than fake neighbors.

## Required game checks (not yet performed)
- Host and guest join: each sees one panel with their own six current stats.
- Eat, drink, rest and read: observe appropriate values changing.
- Resize window, change UI font size, collapse and expand; inspect overlap.
- Die/respawn, disconnect/rejoin, return to menu and host again: no duplicates.
- Repeat with zombies disabled. Confirm vanilla UI and gameplay remain intact.
- Test other HUD mods before combining them; controller navigation is not implemented.

## Roadmap
1. In-game host/guest HUD verification and layout polish.
2. One persistent server-controlled NPC feasibility spike: rendering, movement,
   danger reactions, save/restart, replication to two clients. Do not promise a
   neighborhood until this passes; engine integration may need another approach.
3. Individual friendship/trust, server-validated requests and exactly-once rewards.
4. Tailoring career, clothing variants and wardrobe; new meshes are separate art work.
5. Adult NPC mutual-interest romance, routines and shared households.
6. Richer customization, aspirations and optional zombie-free life-sim balance.

NPC world spawning, portraits and households remain unfinished. Relationship/romance
logic is implemented and unit-tested, but its full world/multiplayer integration is pending.
The isolated QA probe now proves single-player native NPC path-following movement
(three waypoint legs, evidence/v13); replication, persistence and production spawning
are still open. No new clothing meshes/textures are included yet.

## Developer verification
tools/launch-qa.ps1 starts a separate no-Steam game process with its own profile
at E:/pzmod/test-profile. It does not change the user's running save. The QA-only
mod validates actual engine APIs and shows a labeled UI fixture at the main menu.
In its disposable single-player save it exercises real inventory delivery/replay
checks, then verifies persisted career credits on the next save reload.
Never distribute qa/NeighborhoodQA as part of the normal mod.
tests/EngineLua.java also runs production Lua tests inside the game's Kahlua VM;
those tests still mock world/network objects and do not prove real multiplayer.
tools/pipeline.py is the consolidated test/package entry point:
"python tools/pipeline.py test" runs Lua 5.1 plus installed-game Kahlua suites,
and "python tools/pipeline.py package --version vN" writes a production-only
package and diff under evidence/vN. tools/launch-multiplayer-qa.ps1 starts a
dedicated no-Steam server and two isolated clients without OS input. The v0.7
run reached server startup, connected both clients, entered each client into a
world, and completed a real production `NeighborhoodLife` refresh/snapshot
round trip for `nl-host` and `nl-guest`. The launcher uses
`DoLuaChecksum=false` only in the isolated QA server because the two QA
identity fixtures intentionally differ; the release package contains neither
those fixtures nor the launcher. This proves the host/guest command loop, not
synchronized movement, inventory, reconnect, or full remote-character gameplay.

## v0.7 host/guest evidence

- `evidence/v14/` records a real B42.20.4 dedicated server and two isolated
  no-Steam clients. The server logged `Connected new client` twice and each
  client logged `Connected`, `CLIENT START`, `REFRESH SENT`, and `SNAPSHOT`.
- Production `NLAuthority` processed both real refresh commands and emitted a
  revision-1 snapshot to each client. The server callback normalizes Build 42's
  omitted empty argument table for no-argument commands.
- This is actual engine multiplayer evidence, distinct from Lua mock tests and
  installed-game Kahlua VM tests. It does not yet prove synchronized movement,
  inventory delivery, reconnect/restart behavior, or remote NPC replication.
