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
The career journal also offers one server-authoritative work shift per career
and world day; shifts award modest career XP and community credits without
replacing delivery contracts.
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
2. Complete the persistent server-controlled NPC gate: native body
   reannouncement, natural streamed-cell gameplay and danger handling. v1.32
   now retires native deaths persistently and schedules offscreen recovery
   without player-position fallback; v1.31 refuses blocked tiles and reroutes
   safely.
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

## v1.20 tiny plumbob placement

The production marker is now an 8x11 panel with a 56-pixel world-to-screen
lift. This keeps the faceted gem small and places its tip close above the
character model instead of leaving a large floating marker over the street.
The isolated Build 42.20.4 engine logged `size=8x11` for the real player and
continued to anchor all three production NPC markers. The change affects only
the production marker presentation; it does not claim native remote-player
body replication.

## v1.21 authoritative remote-player body fallback

The existing server-authoritative `presence` roster now has a production body
fallback. `NLRemotePlayerClient` uses Build 42's native remote body whenever it
is present; when the engine temporarily omits that peer, it creates exactly one
local native `IsoPlayer` tagged with `NeighborhoodRemotePlayerId`, follows the
revisioned server position through the native path frame and bounded
interpolation, and removes the replica when the peer leaves the roster. The
marker-only presence plumbob remains visible throughout the engine gap.

The Lua/Kahlua contract suite covers fallback creation, movement, native-body
promotion, stale packets and cleanup. A fresh hands-free host/guest run kept
the real `nl-host`/`nl-guest` native bodies visible on both clients across
repeated scans, so it verifies the no-duplicate native path; it did not
naturally trigger the missing-peer fallback and that branch remains explicitly
unclaimed as gameplay evidence.

## v1.22 extra-small plumbob placement

The production marker is now a 5x8 panel with a 42-pixel world-to-screen lift.
The faceted gem remains directly above the character model while occupying
substantially less screen space. Lua and installed-game Kahlua verification
passed for the new dimensions and anchor calculation. A fresh hands-free
isolated launcher run reached the game state but did not emit the marker
assertion before the disposable process was stopped, so no new screenshot is
claimed here.

## v1.23 multi-step NPC conversation evidence

The isolated QA client now waits through the production social cooldown and
repositions only its disposable viewpoint beside the moving target when needed.
It does not alter the production server authority.

`evidence/v42/` records a real Build 42.20.4 dedicated server with `nl-host`
and `nl-guest`. The host completed the production `chat` then `joke` sequence
with Marisol: friendship advanced from 18 to 24 and then 28, while trust
advanced from 5 to 11. The server logged both authoritative commands and
responses, after which the same host continued through career pickup/delivery
and the household invite, shared-storage and tidy loop.

The guest stayed connected and received authoritative presence, NPC and
household snapshots but remained refresh-only for social interaction. This is
actual two-client session evidence for a multi-step host conversation; direct
cross-account conversation synchronization and richer world actions remain
open gates.

## v1.24 replicated social event feed

Successful production social interactions now broadcast a small event packet to
all connected clients. The packet identifies the actor, NPC, action and dialogue
without exposing the actor's private friendship, trust or attraction values.
`NLSocialClient` retains a bounded twenty-event feed, clears it on disconnect or
menu entry, and the Relationships panel displays the latest shared event.

`evidence/v43/` records the actual host+guest result: the host completed `chat`
and `joke`, the dedicated server logged both commands, and the guest received
both `SOCIAL EVENT` packets. The existing career delivery and household loop
also completed in the same run. This is cross-client event replication, not a
claim that private relationship values are shared.

## v1.25 compact plumbob asset and placement

The production marker now uses a 16x22 source texture, a 6x10 runtime panel
and a 30-pixel world-to-screen lift. This keeps the faceted gem very small and
close above the character model, including on Build 42 paths that draw a source
texture at native size. `evidence/v44/` records the baseline and modified
Lua/Kahlua checks, live QA marker-size logging and rollback verification; the
QA logger remains outside the production package.

## v1.26 direct two-client social action

The isolated host and guest now exercise independent production social actions.
`evidence/v45/` records the guest moving beside Kenji, sending `introduce`,
receiving `friendship=3` and `trust=2`, and the host receiving the guest's
replicated social event without receiving the guest's private relationship
values. This is actual Build 42 host-plus-guest evidence, not a mock or VM
claim. Richer world actions and romance synchronization remain open.

## v1.27 native NPC reannouncement adapter probe

Production `NLNpcAuthority` now makes a best-effort call through Build 42's
public `GameServer.getConnectionFromPlayer` and
`GameServer.sendPlayerConnected` methods after sending the existing
authoritative `npc_presence` packet. The compatibility packet remains the
authoritative route when the Java table is not exposed to Lua.

The Lua/Kahlua contract suite verifies that all three authored native bodies
are sent to a connected player using a deterministic `GameServer` fixture.
This is mock/engine-VM evidence, not gameplay evidence. In the fresh
hands-free run recorded under `evidence/v46/`, the dedicated Build 42.20.4
server spawned and moved all three neighbors, both clients received three
moving native replicas, and the guest completed its Kenji social probe. The
same server logged `GameServer=nil` during both refresh probes, so native
reannouncement remains an open engine-exposure gate.

## v1.28 server-authoritative wardrobe slice

Wardrobe saves now use the production `wardrobe_save` command. The server reads
the connected player's real worn-item list, validates slots 1-3, stores exact
garment identities in the private profile, increments its revision and returns
the preset through the normal snapshot packet. The production panel and world
context menu both use this route; wearing still uses vanilla
`ISWearClothing` actions.

`tests/wardrobe-authority.lua` covers the capture, validation, persistence and
snapshot contract in Lua 5.1 and the installed Kahlua VM. In the actual
Build 42.20.4 run under `evidence/v47/`, the host opened the real 590x450
wardrobe panel and received revision 72 after the authoritative save. The
disposable character had zero worn garments, so the run proves the empty-preset
and UI/server integration path, not visual garment replacement yet.

## v1.29 actual non-empty wardrobe and reconnect evidence

The isolated QA server fixture placed real `Base.Shirt_FormalWhite` and
`Base.Trousers_Denim` items on the host's square. The host acquired them using
the vanilla world-transfer action, equipped them using vanilla
`ISWearClothing`, and saved them through the production server-authoritative
`wardrobe_save` command. The fixture and all clothing seeding remain in the
QA-only mod.

`evidence/v48/` records the actual Build 42.20.4 host-plus-guest run: both
garments were acquired and worn, slot 1 returned `pieces=2` at revision 73,
and a stable hands-free same-client reconnect returned the same `pieces=2` at
revision 74. The run also retained the compact 6x10 plumbob and the guest's
three moving NPC replicas plus Kenji social event. Production saved-outfit
replacement after removing currently worn layers is recorded in v1.30 below;
the unit and Kahlua contracts continue to cover exact identity and fallback
behavior.

## v1.30 actual saved-outfit replacement

The QA-only isolated client now waits for the real saved slot, removes the
captured garments with vanilla `ISUnequipAction`, verifies both body locations
are empty, and invokes the production `NLWardrobe.wear(player, 1)` function.
QA does not implement the production wardrobe action.

`evidence/v49/` records the actual Build 42.20.4 result: the host acquired and
wore both garments, saved revision 75, completed vanilla unequip with both
garments at zero, and then logged replacement completion for both garments from
`production-NLWardrobe.wear`. New clothing variants, original assets and
unlock/reward integration remain breadth work.

## v1.38 forced-crash NPC inventory recovery

The isolated hands-free QA runner now arms a QA-only `player-applied` fault,
waits until the production inventory journal is saved, forcibly stops the real
dedicated `GameServer`, restarts it against the same save, and reconnects the
host without mouse or keyboard control. Build 42 logged the partial journal,
`SaveAll`, old PID `32700`, new PID `31648`, and
`NLQA INVENTORY JOURNAL RECOVERY: state=repaired`; the host then received the
repaired private snapshot. The fault config and orchestration remain outside
the production package.

`evidence/v58/` records the run as actual host-plus-guest engine gameplay
evidence. Lua/Kahlua tests remain mock and engine-VM evidence, and this
milestone proves the NPC inventory journal only; broader global-data crash
atomicity, world actions and item/container breadth remain open.

## v1.37 transactional NPC inventory recovery

NPC `give` and `request` now write a world-level transaction journal before
touching either the player's vanilla inventory or the persistent NPC row. The
journal records both pre-state counts, the NPC revision and display metadata;
the server clears it only after both sides apply. On the next command for the
same account, a complete transaction is finalized, an untouched transaction is
discarded, and a partial transaction is repaired to its recorded pre-state.
The Lua/Kahlua suites cover both player-side and world-side partial mutations.
This recovery journal is the production mechanism exercised by the v1.38
forced-crash probe above.

## v1.40 career work shifts

Each career now exposes a named daily work shift in the journal. The server
tracks the claim per career and world day, awards 15 career XP and 5 community
credits, and keeps vanilla perk level as the promotion gate. Duplicate clicks
are rejected for that day, and a new world day unlocks the shift again.

The actual Build 42 host-plus-guest run in `evidence/v60/` completed the medic
delivery, then sent the production `work` command and received
`Staff the neighborhood clinic: +15 career XP, +5 community credits`. The
guest remained connected and the household sequence continued afterward. QA
stimulus remains outside the production package.

## v1.41 career work persistence

The isolated hands-free runner now performs the daily production work shift,
restarts the real dedicated server, reconnects the host, and checks the
revisioned career snapshot. `evidence/v61/` records the medic shift before the
restart and `workedToday=true`, `shifts=1`, `xp=615`, and `credits=450` after
reconnect. The same run retained the NPC inventory snapshot and completed the
post-restart exchange. This is actual Build 42 gameplay evidence; the Lua and
Kahlua suites remain separate mock and engine-VM evidence.

## v1.42 tiny plumbob placement

The production marker is now an 8x11 source texture rendered through a 2x3
runtime panel with a 10-pixel lift. The reduced source asset prevents Build 42
from restoring the old large native-size gem, while the shorter lift keeps the
marker close above the character model. This is a presentation change; it does
not change NPC, multiplayer, or persistence behavior.

## v1.45 functional household storage furnishing

The native household storage object now has a world-object context menu with
`Store 1 Ripped Sheet` and `Take 1 Ripped Sheet` actions. The production client
routes those actions through the server, which validates the household member,
the furnishing tile, action, item type and quantity before changing shared
storage. The actual host-plus-guest run in `evidence/v65/` stores on the host,
retrieves on the guest, then continues through the existing ownership-transfer
request. The isolated save already had the daily household task claimed, so
the later task probe correctly returned the server's replay guard. The menu
and engine-VM checks remain distinct from that gameplay evidence.

## v1.44 household ownership transfer

The Neighborhood Home panel now exposes a server-authoritative `Transfer owner`
action. Only the current owner can transfer to an existing member; both roles,
the owner field, revision, and private snapshots update together. The actual
hands-free host-plus-guest run in `evidence/v64/` transferred ownership from
`nl-host` to `nl-guest`, then continued the shared household task. QA remains
outside the production package.

## v1.43 multiplayer HUD identity

The needs panel now labels each live instance with its local character name,
for example `NEEDS / nl-host / LOWER % IS BETTER`, so split-screen and
multi-client observations cannot be confused. The actual hands-free host and
guest run in `evidence/v63/` created six-row panels on both clients and read
each client's six vanilla stats independently. The QA logger remains outside
the production package; this proves runtime HUD routing, not final visual
accessibility polish.

## v1.39 pin-sized plumbob placement

The production marker is now a 3x5 runtime panel with a 20-pixel lift, down
from 4x7 and 30 pixels. This keeps the gem above the head while making it a
small visual cue instead of a second character-sized object. The plumbob
contract locks the new dimensions; NPC, multiplayer and persistence behavior
remain unchanged.

## v1.36 extra-small plumbob placement

The production marker is now a 4x7 runtime panel, down from 6x10, while keeping
the 30-pixel lift so its tip remains above the player model. The existing
16x22 source texture is still scaled through the panel, and the plumbob
contract suite now locks the extra-small dimensions. This is a presentation
change; NPC, multiplayer, and persistence claims remain unchanged.

## v1.35 dedicated-server restart persistence probe

The isolated hands-free QA runner now performs a real dedicated-server process
restart after the production NPC inventory give/request exchange, forces the
host client through an engine reconnect, and checks the post-restart social
snapshot before completing a second exchange. The Build 42 run preserved
`Base.RippedSheets/1/Rag` across the restart, then reported
`Base.RippedSheets/2/Rag` after the next give and completed the request. This is
actual host-plus-guest engine gameplay evidence, not a mock or engine-VM claim.
The restart probe does not establish forced-crash atomicity; that remains open.

## v1.34 generalized NPC inventory selection and metadata

The NPC inventory slice now normalizes legacy and malformed saved counts,
retains a stable display label for each stored full item type, and sends a
sorted `inventoryItems` list in every social snapshot. The Relationships panel
chooses the first unequipped main-inventory item for `Give item` and the first
stored NPC item for `Request item`, instead of hard-coding `Base.RippedSheets`.
The server still validates the full type and amount and keeps the persisted
count authoritative.

Contract and installed-game Kahlua suites cover multi-item metadata,
normalization and the dynamic UI callbacks. `evidence/v54/` records the fresh
hands-free host-plus-guest run: the production snapshot returned
`Base.RippedSheets/2/Rag` after the real give, while the host requested the
item back and the guest retained three moving NPC replicas. This is actual
snapshot/engine evidence, not a mock or VM claim. Crash-atomic persistence and
broader container metadata remain open.

## v1.33 authoritative NPC inventory exchange

Production NPC rows now carry a persistent `inventory` map. The server validates
item type, amount, same-floor proximity, line of sight and unequipped main
inventory before accepting `give`; `request` restores stored items through the
player's vanilla inventory and rolls back failed additions. Each successful
exchange increments the NPC row revision and returns the inventory in the
private social snapshot. The Relationships panel exposes the current vertical
slice as `Give 1 sheet` and `Request 1 sheet` actions.

The Lua contract suite and installed-game Kahlua VM both pass the exchange
path. `evidence/v53/` records a real Build 42.20.4 host-plus-guest run: the
host acquired ten real `Base.RippedSheets` through vanilla world-transfer
actions, gave one to Marisol through the production command, received the
authoritative `Gave 1 Base.RippedSheets to marisol.` snapshot, then requested
and received the same item back. The server logged both commands while the
guest remained connected and continued receiving the NPC presence stream.
QA stimulus and seeded items remain outside the production package. General
item selection, richer metadata, crash-atomic persistence and broader world
actions remain open.

## v1.32 native NPC lifecycle retirement and offscreen recovery

Production `NLNpcAuthority` now treats the native `IsoPlayer` as a transient
engine body instead of the persistent identity. A native death cancels its path,
removes its social/body registration, persists the neighbor as dead and causes
the next authoritative presence roster to omit it. A body that disappears from
the server cell object list is retained as an alive persistent row with its last
fractional position; the scheduled recovery path calls the native spawn adapter
without a connected-player fallback, preventing an offscreen neighbor from
teleporting into the player's area.

The NPC contract suite covers death retirement, offscreen removal, saved-position
retention and saved-tile recovery in Lua 5.1 and the installed Kahlua VM. Those
are mock/engine-VM checks, not damage or natural cell-streaming gameplay
evidence. `evidence/v52/` records the baseline, modified package, diff,
verification and executable rollback artifacts. The accompanying hands-free
host-plus-guest run remains actual regression evidence for three moving NPCs,
plumbobs and the guest social event; it does not claim a naturally caused NPC
death or streamed-cell transition.

## v1.31 collision-aware NPC fallback and runtime API gate

Production `NLNpcAuthority` now checks destination tiles before its bounded
dedicated-server stalled-path fallback moves an NPC. It chooses a free
neighboring step around a short obstruction and skips a waypoint when no safe
step exists instead of moving through a solid or occupied tile. The Lua
contract test covers both cases.

`evidence/v51/` records an actual Build 42.20.4 host-plus-guest run after the
change: the server moved the three native NPC bodies, both clients received
their moving replicas, and the guest completed the real social event. The same
run confirmed that the dedicated server still exposes `GameServer=nil` and
that the Java class wrapper does not expose the reflection methods needed for
native reannouncement; the existing authoritative presence/local-replica
route remains active. Damage/death, offscreen scheduling and native
reannouncement remain open.

## v1.46 smaller, closer character marker

The production plumbob remains an 8x11 source texture rendered through a 2x3
screen-space panel, and its lift is now 8 pixels so the tip sits closer above
the character model. The isolated profile was resynchronized from the production
mod; the hands-free host and guest run logged `player:0=2x3 texture=8x11` on
both clients. This is presentation evidence, not a claim about native NPC
reannouncement or broader multiplayer completion.

## v1.47 server-authoritative zombie danger handling

Production NPC authority now scans the loaded Build 42 server cell for living
zombies within four tiles. When a threat is present, it cancels the NPC's
current route, pauses or takes a bounded retreat onto a walkable square, and
persists the resulting position before normal route work resumes.

The isolated hands-free run seeded one real zombie beside Marisol through the
vanilla `addZombiesInOutfit` API. The dedicated server logged
`NLQA DANGER PROBE: ok=true count=1` and production `NPC PRODUCTION DANGER`
events for all three neighbors; the host and guest remained connected with
three native NPC replicas. This is actual engine gameplay evidence for the
danger probe, not a claim that the full optional-zombies loop is complete.
The same session also has a no-threat phase before the first probe: the server
logged zero production danger events while both clients already had three
native NPC replicas and native paths. That establishes the no-nearby-zombie
behavior in the same two-client run; a separate sandbox population-setting
toggle remains untested.

## v1.48 streamed NPC replica handle recovery

The production client now verifies that each cached NPC body still exists in
Build 42's client object list before applying a newer authoritative presence
packet. If streaming removed the native body, the client drops the stale handle
and recreates a local native replica from the server row, preserving its
plumbob, target and revision state. The contract and installed-game Kahlua
suites cover this path.

The QA multiplayer launcher now accepts `-ProfileRoot`, allowing a disposable
isolated profile without overwriting the persistent test profile. The v1.48
fresh-profile probe exposed a separate startup issue before NPC gameplay: the
clean clients did not complete the hands-free connection path, while the
archived profile relocated NPCs and produced no replicas. This run is retained
as a genuine failed gameplay probe; streamed-cell gameplay evidence remains
open.

## v1.49 clean-profile startup and live stale-body recovery

The isolated QA agent now acknowledges the first-run Build 42 terms state
without OS input, while the multiplayer launcher seeds the mod-list sentinel
that a clean profile otherwise uses to reset `default.txt`. The launcher also
leaves connection ownership with the QA Lua callback instead of sending a
competing `+connect` bootstrap. QA helpers remain outside the production mod.

`evidence/v70/` records the resulting clean-profile Build 42.20.4 host+guest
run. Both clients connected to the real dedicated server, loaded the current
production mod, rendered three native moving NPC replicas with compact
plumbobs, and completed the production stale-body probe: Kenji was removed from
the host's local object list and the next authoritative presence application
created a fresh native replica. The logs also retain the real danger probe,
independent social actions and HUD/plumbob checks. This closes the live QA
recovery probe without claiming native server-body reannouncement or natural
engine-driven cell streaming.

## v1.50 natural-walk streaming attempt

The QA-only client stimulus now queues repeated short vanilla walk actions in
one real host session before the explicit stale-body compatibility probe. The
host moved eight tiles while Build 42 retained Kenji in the client object list,
so the natural stream check correctly recorded `bodyPresent=true`; no natural
stream-out claim is made. The same run still reached the explicit production
stale-handle recovery probe afterward. Logs and the separate mock/engine-VM
classification are in `evidence/v71/`.
## v1.51 late native-body promotion

The production NPC client now marks its locally-created compatibility replicas
and excludes those marked bodies when searching the cell for a server-native
body. If Build 42 supplies the native body after the fallback already exists,
the next authoritative presence packet removes the fallback, promotes the
native body, repositions it from the authoritative entry, and reuses the
plumbob registration. The focused contract test and installed-game Kahlua
execution cover the promotion path; a real naturally missing native peer is
still not available in the current dedicated-server Lua exposure.

## v1.52 loaded-cell remote-player discovery

The production remote-player client now searches both Build 42's online-player
list and the loaded cell object list. A connected peer that has entered the
cell before `getOnlinePlayers()` refreshes is promoted over the local fallback,
with the old replica path cancelled and its plumbob/state presentation cleaned
up. The focused Lua 5.1 and installed-game Kahlua tests cover this branch.
This remains engine-VM evidence; a real naturally missing peer still needs a
full gameplay capture.
