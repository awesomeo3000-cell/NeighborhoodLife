# Neighborhood Life: careers, wardrobe and relationship prototype (v1.7)

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
registered with a real server-side body. In a new or loaded single-player world,
Neighborhood Life now creates the persistent Marisol native body, gives her a small
two-point route, and anchors a compact plumbob just above her model. The dedicated
server now broadcasts authoritative NPC state, and each client creates a local native
replica that interpolates only toward that state. A refresh or presence request now
pushes NPC state immediately, and clients reject stale revisions during reconnects.
Multiplayer NPC distribution is engine-proven at the mod-state/replica layer; native
server-body reannouncement is still an open Build 42 API gate. The server now saves
the latest NPC position through `OnSave`, and a restart restores the fractional tile
position instead of snapping to the tile center.

## Required game checks (not yet performed)
- Host and guest join: each sees one panel with their own six current stats.
- Eat, drink, rest and read: observe appropriate values changing.
- Resize window, change UI font size, collapse and expand; inspect overlap.
- Die/respawn, disconnect/rejoin, return to menu and host again: no duplicates.
- Repeat with zombies disabled. Confirm vanilla UI and gameplay remain intact.
- Test other HUD mods before combining them; controller navigation is not implemented.

## Roadmap
1. In-game host/guest HUD verification and layout polish.
2. Complete the persistent server-controlled NPC gate: obstacle/danger reactions,
   damage/death, offscreen behavior, native body reannouncement and reconnect state.
3. Individual friendship/trust, server-validated requests and exactly-once rewards.
4. Tailoring career, clothing variants and wardrobe; new meshes are separate art work.
5. Adult NPC mutual-interest romance, routines and shared households.
6. Richer customization, aspirations and optional zombie-free life-sim balance.

NPC breadth, portraits and households remain unfinished. Relationship/romance
logic is implemented and unit-tested, but its full world/multiplayer integration is pending.
The v1.1 production adapter proves single-player native spawning, path-following,
plumbob anchoring and ModData save/reload restoration in `evidence/v18/`. The v1.2
run in `evidence/v19/` proves a dedicated server moving the authoritative native body
and both real clients receiving the same `npc_presence` stream while rendering local
native replicas. That run does not prove Build 42 native body reannouncement,
reconnect/restart persistence, inventory, danger, damage/death, or household life.
No new clothing meshes/textures are included yet.

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

## v0.8 native remote marker evidence

The production plumbob now discovers native Build 42 remote bodies through the
client `getOnlinePlayers()` list and anchors markers to those bodies. In the
real run in `evidence/v15/`, the host observed `nl-guest` and logged
`productionRemoteMarkers=1`. The guest still observed only itself, and the
host's remote entry later disappeared. Remote marker replication is therefore
started and engine-proven in one direction, but not yet a stable two-way
multiplayer result.

## v0.9 authoritative presence channel

The server now broadcasts a private authoritative roster containing usernames,
positions, floors, and online IDs to every connected client. Real QA logs show
both `nl-host` and `nl-guest` received the same two-player roster. This supplies
a reliable mod-level state channel while native remote-body replication remains
unstable; it does not fabricate bodies or claim synchronized movement yet.
The QA repair probe also found Build 42's native `GameServer` class is not
exposed as a Lua table on this dedicated server, so native re-announcement
remains an engine/API investigation gate.

## v1.0 movement-state heartbeat evidence

Production clients now send a periodic presence heartbeat. The server derives
positions from authoritative player objects and rebroadcasts them to every
 client. In `evidence/v17/`, hands-free QA moved `nl-host` from
`6817.50,5259.50` to `6819.50,5259.50`; the guest received the changed
position repeatedly. Native remote-body rendering remains a separate open gate.

## v1.1 production NPC vertical slice

`evidence/v18/` records the production native `IsoPlayer` neighbor: spawn near the
player, real Build 42 pathfinding over repeated two-point legs, a plumbob anchored to
the body, `GameWindow.save(false)`, and a second launch restoring the saved position.
The QA mod only observes and drives the isolated test profile; it is not in the release
package. This is single-player gameplay evidence, not proof of two-client NPC
replication or completed household life.

## v1.2 two-client NPC state and replica evidence

`evidence/v19/` records `tools/launch-multiplayer-qa.ps1` starting one isolated
dedicated server plus `nl-host` and `nl-guest`. The server spawned the production
native Marisol body, logged authoritative movement from `6815.50,5259.50` through
`6816.22,5259.50` to `6817.02,5259.50`, and broadcast `npc_presence`. Both clients
received the same revisioned NPC positions and logged a native `Marisol Vega
[Neighborhood Life]` object in their local object list. This is actual engine
multiplayer evidence for the server-state/client-replica layer, distinct from the
Lua mock and installed-game Kahlua suites. Build 42 did not expose `GameServer` as a
Lua table in this run, so native server-body reannouncement remains open.

## v1.3 reconnect-state evidence

The current production build sends `npc_presence` during the same server refresh
that returns a player's snapshot, instead of waiting for the periodic route tick.
In the hands-free run recorded under `evidence/v20/`, the host received its NPC
packet immediately after `SNAPSHOT`, and the guest received the same revisioned state
on join. Both clients logged `productionNpcReplicas=1`. Client-side revision checks
ignore delayed packets from before a reconnect, while an empty authoritative roster
still removes the local replica and its plumbob.

## v1.4 dedicated-server restart evidence

`evidence/v21/` records the isolated server save/restart probe. The first run used
the QA-only one-minute save interval and moved Marisol to `6816.70,5259.50`; the
next dedicated-server process logged `RESTORE ... revision=5` and spawned her at
the same fractional position, then delivered that state to the newly joined host
and guest. The production adapter now also registers `OnSave` so the final position
is persisted before a normal world save. This proves NPC ModData persistence across
a dedicated-server restart, not native body reannouncement or a reconnect inside
the same client process.

The client replica layer now clears native NPC bodies, plumbobs and revision state
on both `OnDisconnect` and `OnMainMenuEnter`, preventing stale replicas from
surviving a normal engine disconnect transition.

The production neighborhood adapter now materializes all three authored vertical-
slice neighbors—Marisol Vega, Kenji Arakawa and Amara Okonkwo—with identity,
outfit and gender data carried in the authoritative presence stream. Each body
gets its own nearby persisted home/route, native movement cadence and client
replica/plumbob rather than sharing Marisol-only construction logic.

The isolated multiplayer probe now drives a real production social refresh from
the host, introduces the nearest native neighbor through `NeighborhoodSocial`,
and verifies the guest receives its own proximity-gated relationship snapshot.
