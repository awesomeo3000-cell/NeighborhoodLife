# Neighborhood Life: careers, wardrobe and relationship prototype (v1.12)

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

The same isolated host now receives a QA-seeded authoritative inventory fixture,
selects the Tailor career through the production command, and completes a real
server-side delivery for `+20 career XP, +10 community credits`; the seed remains
QA-only and does not alter the production economy.

## v1.9 authoritative remote marker fallback

Production clients now consume the server's authoritative `presence` roster when
Build 42 temporarily omits a remote player from `getOnlinePlayers()`. The client
draws a marker-only plumbob at the roster position, never constructs a substitute
player body, and immediately prefers a native body again when one reappears. Empty
or stale rosters remove the fallback marker on disconnect/menu reset.

The real two-client run in `evidence/v27/` logged `productionRemoteMarkers=1` while
the native guest body was visible, then `productionPresenceMarkers=1` on both host
and guest after native enumeration dropped the peer. Both clients continued to
receive the same authoritative two-player positions and the three native NPC
replicas. Native remote-body reannouncement and synchronized native movement remain
open; the fallback proves stable authoritative marker visibility, not body
replication completion.

## v1.10 same-client reconnect after dedicated-server restart

`evidence/v29/` records a hands-free run with the dedicated server stopped and
restarted against the same isolated world profile. The QA-only engine probe
requested the host disconnect without mouse or keyboard input; the host returned
to `MainScreenState`, completed a new connect cycle, logged `CONNECTED` and a new
`CLIENT START`, and then received production NPC state again. The guest continued
to receive the authoritative presence stream.

The restarted server restored Marisol, Kenji and Amara from their persisted
fractional positions before spawning their native bodies. Both clients then
logged three production NPC replicas and fresh `npc_presence` packets. This
proves same-client reconnect plus NPC persistence across a dedicated-server
restart; native Build 42 remote-body reannouncement and stable two-way native
remote movement remain open.

## v1.11 distinct native NPC spawn repair

`evidence/v30/` records a fresh isolated host plus guest run against the
persisted QA world after a legacy save had placed all three neighbors on one
tile. The production server logged `RELOCATE` for Kenji and Amara before native
spawn, then assigned separate native paths. Both clients received three NPC
presence entries with distinct coordinates and logged three production NPC
replicas; their object scans listed all three neighbors at separate positions.

The Lua contract test covers the repair branch as a mock, while the v30 logs
are actual Build 42 gameplay evidence. Native remote-body reannouncement and
stable two-way native remote movement remain open.

## v1.12 compact plumbob placement

The production marker now uses a `10x14` screen-space panel and a `72px` lift,
keeping the gem small and directly above the active character model. The
fallback renderer is bounded to that panel instead of drawing an oversized
shape outside its UI bounds. The isolated Build 42 smoke run logged
`size=10x14`; this is engine UI evidence, not multiplayer completion.

## v1.13 native client NPC movement

Production NPC replicas now use Build 42's native `PathFindBehavior2` frame
sequence (`preupdate`, `update`, behavior update, `postupdate`) for movement
toward server-authoritative positions, with bounded interpolation only when
the native behavior is unavailable or stalls. A fresh hands-free host/guest
run logged `productionNpcNativePaths=3` on both clients while the three NPC
positions advanced over repeated `npc_presence` packets. Native server-body
reannouncement remains an open Build 42 Lua API gate.

## v1.14 client-acquisition inventory sync

`evidence/v33/` records a real hands-free host plus guest run in which the
QA-only server spawned eight `Base.RippedSheets` world items, the host client
picked them up through vanilla `ISInventoryTransferUtil` actions, and the
production medic delivery consumed them and returned XP and credits. The guest
also received the three production NPC replicas and native movement paths.
QA helpers remain outside the production package.

## v1.15 household vertical slice

`evidence/v34/` records a real host plus guest loop for the first household
slice: the host creates a Neighborhood Home, invites `nl-guest`, the guest
accepts, and both clients receive the shared two-member state. The host then
completes the server-authoritative `tidy` routine at the persisted home tile;
the daily replay guard and five-credit reward are visible to both clients.
The Home panel exposes create, invite, accept, leave, refresh and three shared
activities. QA helpers remain outside the production package.

## v1.16 shared household storage

`evidence/v35/` records the next household step in a real hands-free
Build 42.20.4 host plus guest loop. The QA-only server seeded nine real
`Base.RippedSheets`; the host acquired them through vanilla transfer actions,
the production medic delivery consumed eight, and the host deposited the
remaining sheet into the server-authoritative household storage. The guest then
withdrew that stored item through the production household command and received
the synchronized storage snapshot. The host completed the shared tidy routine
afterward.

Deposits are limited to unequipped matching items in main inventory and require
the member to be at home. Withdrawals require household membership, restore
vanilla inventory items, enforce exact counts and a 500-item capacity, and are
validated independently of the Home panel. The first UI action pair is wired to
the career slice's `Base.RippedSheets` item. QA helpers remain outside the
production package; native server-body reannouncement, furnishings and richer
offline household routines remain open gates.

## v1.17 household furnishing vertical slice

The household now owns a persistent storage-furnishing record, including its
native tile identity, sprite and coordinates. The dedicated server reconciles
that record to a native `IsoObject` and includes it in every revisioned Home
snapshot. The production client creates the same native tile object locally when
the home square is loaded because Build 42.20.4 did not consistently replicate
Lua-created server objects in the isolated run.

`evidence/v36/` records the actual hands-free host/guest loop: the server reused
the persisted furnishing at `8282,11720,1`, the host created its native client
object from the authoritative snapshot, and the guest received the same
furnishing snapshot while completing invite, shared storage withdrawal and tidy.
The guest was not standing near the home tile, so its unloaded square produced no
local tile object; this remains a streaming/replication gate rather than a hidden
success claim. Mock and engine-VM tests remain separate from this gameplay
evidence, and QA helpers stay outside the production package.

## v1.18 streamed-in household furnishing retry

The production client now keeps a revisioned furnishing snapshot pending when
the home square is not loaded, then retries on engine ticks. The first successful
load creates one native local tile replica and removes the pending entry. Menu
and disconnect cleanup remove both the local object and deferred snapshot.

The server also uses Build 42's native `IsoObject.getNew` plus
`IsoGridSquare.transmitAddObjectToSquare` add path. The isolated 42.20.4 run
still did not expose that server-created object in either client's object-list
scan, so the snapshot replica is retained as the honest production fallback.

`evidence/v37/` records the real host/guest invite, shared-storage withdrawal
and tidy loop. A QA-only, hands-free viewpoint fixture loaded the shared home
tile for the guest; both clients then logged
`productionHouseholdFurnishingClient=1` and
`productionHouseholdFurnishingPending=0`. This proves the streamed-in client
retry path in the engine, while the viewpoint fixture is not presented as normal
guest walking. Native cross-client furnishing packets, normal streamed-in
walking, native server-body reannouncement, richer item metadata and offline
household routines remain open.

## v1.19 native furnishing packet diagnosis

The QA client now inspects the authoritative home square with the engine's
native `IsoGridSquare:getObjects()` list in addition to the broader
`getObjectListForLua()` probe. The v1.18 probe was incomplete: it excluded the
tile object even when the native object was present. A fresh hands-free run
showed one `NeighborhoodHouseholdStorage` object with household ModData on
both host and guest after the shared home tile loaded. The production snapshot
fallback still handles the guest's transient unloaded or partial packet state.

The server only transmits the native object on creation; retransmitting the
same object on every household action produced duplicate client tile objects,
so that branch remains intentionally absent. QA helpers remain outside the
production package. Normal streamed-in walking, native server-body
reannouncement, richer item metadata and offline household routines remain
open gates.
