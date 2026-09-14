# Neighborhood Life — full scope and evidence ledger (v1.68)

Target: Project Zomboid **42.20.4**, confirmed in the isolated game window.
Host/invite multiplayer is a release requirement, not an optional add-on.
The original broad goal remains active. This ledger is not a reduced definition of done.

| Requirement | Current implementation | Completion evidence still required |
|---|---|---|
| Sims-inspired HUD | Six live adverse-stat bars, fold control, career journal link, and v1.43 per-instance local-character labels | Resolution and accessibility polish |
| Character markers | Production client plumbob asset and world-to-screen panel for active characters; v1.25 uses a compact 16x22 source texture, v1.36 reduces the runtime panel to 4x7, v1.39 tightens it to a pin-sized 3x5 panel with a 20px lift, and v1.42 reduces the source to 8x11 with a 2x3 panel and 10px lift so the gem stays tiny and close above the model; native remote-player discovery attaches markers when Build 42 exposes a body, and v1.21 adds an authoritative-presence-driven local native remote-player replica when the engine temporarily omits a peer | Stable native two-way remote-character bodies and movement; fallback replica behavior is covered by contract tests and remains to be exercised in a naturally missing-peer gameplay run |
| Careers | Tailor, carpenter, medic; four ranks; daily supply requests; actual skill gates; account/world persistence; v1.8 real host delivery consumed six authoritative `Base.RippedSheets` and returned XP/credits; v1.14 real client pickup transferred eight server-spawned `Base.RippedSheets` through vanilla inventory actions before a fresh medic delivery returned XP/credits; v1.40 adds named server-authoritative daily work shifts with duplicate-day guards and actual host evidence; v1.68 journals player inventory removal plus the profile award and repairs the half-transaction after a dedicated-server crash | Rank/restart tests, richer work beyond the daily shift, rewards and balance |
| Customization | v1.54 adds a server-authoritative appearance profile with four Build 42 hair presets (Natural, Bob cut, Braided and Short), a live Looks panel, revisioned snapshots and native `HumanVisual` application on each client | Expanded creator controls, richer preferences, original additional hair/assets |
| Clothing options | Three saved outfit-layer slots; server-authoritative worn-garment capture and revisioned private snapshots in v1.28; v1.29 actual vanilla clothing acquisition, wear and reconnect snapshot persistence; v1.30 actual production saved-outfit replacement after vanilla unequip; v1.55 production replacement now queues vanilla unequip for unrelated worn layers before saved garments; v1.56 actual host proof removes a post-snapshot `Base.Hat_Cowboy` from before=1 to after=0; light-themed wardrobe panel reachable from HUD | New garment variants, original assets, unlock/reward integration |
| Persistent neighborhood NPCs | Production `NpcAuthority` creates all three authored vertical-slice neighbors (Marisol, Kenji and Amara) as native `IsoPlayer` bodies, repairs legacy stacked saved rows to distinct free squares, gives each identity/outfit data and a persisted nearby route, restores the exact fractional position across a dedicated-server restart, sends immediate and periodic `npc_presence` from a dedicated server, and production clients render named revision-checked native replicas with plumbobs and disconnect/menu cleanup; v1.10 proves the same client reconnects after the dedicated server restarts, v1.11 proves distinct native positions on both clients, v1.13 drives client replicas through Build 42's native `preupdate`/`update`/path behavior frame with a bounded interpolation fallback, v1.27 adds a best-effort `GameServer` reannouncement adapter plus mock contract coverage, v1.31 makes the dedicated-server fallback collision-aware and reroutes a blocked waypoint instead of stepping through it, v1.32 retires native deaths into persistent dead rows and schedules saved-tile recovery for missing streamed bodies, v1.47 adds loaded-cell zombie detection plus server-authoritative retreat/pause behavior, v1.48 drops stale client NPC handles before recreating a streamed-out native replica, and v1.49 proves that recovery in a live host+guest Build 42 session, v1.51 promotes a late-arriving server-native body over an existing compatibility replica, v1.53 reconciles an engine-native body from the loaded cell even when no new mod presence packet arrives, and v1.57 adds a native online-id hint to loaded-cell promotion, v1.59 suppresses duplicate native hints, and v1.60 reserves stable authored online-id slots for the three vertical-slice identities and applies available hints to compatibility replicas; v1.61 tries method/field assignment with getter verification and records the actual dedicated-server bridge result | Build 42 native server-body reannouncement remains unproven because the real dedicated server exposes `GameServer=nil` to Lua; the v1.50 natural-walk probe reached only an 8-tile displacement and retained the NPC body, so natural engine-driven cell streaming remains open |
| NPC interaction | Server proximity/floor/visibility gates and personality-based dialogue implemented for all three native bodies; v1.7 hands-free host introduced Marisol through the production command and guest received an independent proximity-gated snapshot; v1.23 completes a real host `chat` -> `joke` sequence against Marisol during a connected host+guest run with cooldown and line-of-sight gates; v1.24 broadcasts successful social events to every connected client without sharing private relationship values; v1.26 drives a guest `introduce` against Kenji while the host remains connected and receives the guest event; v1.33 adds persistent per-NPC inventory, server-validated `give`/`request` exchange, revisioned snapshots and Relationships-panel actions, with actual host gameplay evidence; v1.34 adds normalized multi-item inventory entries, persisted display metadata and dynamic Relationships-panel selection from the player's main inventory; v1.35 proves a real dedicated-server process restart preserves the NPC inventory snapshot before a second host exchange; v1.37 adds recoverable cross-owner inventory transaction journaling and partial-state repair; v1.38 proves journal repair after a forced real server crash and reconnect | Broader world actions and item/container metadata |
| Relationships and romance | Per-player friendship/trust/attraction, bounded memories, pacing, dates and exclusive partnerships implemented; Sims-inspired panel; v1.7 actual host relation mutation and guest isolation evidence; v1.24 adds a bounded replicated social-event feed and Relationships-panel shared-event line; v1.26 proves the guest independently mutates Kenji to friendship 3/trust 2 while the host receives only the event | In-world UI/interaction checks, richer date activities and direct two-client romance synchronization |
| Household life | v1.16 extends the v1.15 server-authoritative Neighborhood Home with persistent shared storage, exact item-type deposits from unequipped main inventory, member withdrawals, capacity and malformed-item guards, shared-storage UI actions, and real host-to-guest inventory transfer evidence; v1.44 adds owner-only transfer to an existing member with revisioned role snapshots; v1.45 makes the native storage furnishing interactable from the world-object menu with server-validated store/retrieve actions and actual host-to-guest evidence; v1.64 proves household membership, furnishing and stored `Base.RippedSheets` survive a real dedicated-server restart; v1.65 adds bounded per-instance item metadata capture, snapshot delivery, and restoration hooks plus dynamic furnishing-menu item types; v1.66 proves real host storage and guest retrieval of a damaged `Base.KitchenKnife` (condition 4) and partially filled Build 42 `Base.WaterBottle` (usedDelta 0.25) through the production furnishing callback; v1.67 adds a recoverable household storage journal that repairs a player/world half-transaction after a forced dedicated-server crash | Offline/co-op routines beyond the tested activity, broader global-data crash atomicity |
| Aspirations and home activities | Delivery milestones already persist and render in the career journal; v1.15 adds three authoritative home routines (tidy, meal, social) with daily replay guards and rewards | Household-linked aspiration goals, hobbies and broader home progression |
| Zombies optional | Careers have no kill requirements; v1.47 adds a real server-side danger scan for living zombies and bounded NPC retreat/pause behavior | Test the same full loop with zombies disabled and enabled |
| Host multiplayer | Server command adapter, private snapshots, authoritative player/NPC presence broadcasts, immediate refresh state, production client heartbeat, stale-packet rejection, dedicated-server NPC restart persistence, distinct three named NPC replicas, host and guest social mutations with private relationship state, replicated social events, server-authoritative career delivery, server-authoritative wardrobe capture plus vanilla clothing acquisition/wear and same-client reconnect snapshot persistence in v1.29, actual production saved-outfit replacement in v1.30, v1.56 actual automatic unrelated-layer removal with the connected host and guest present, vanilla client-acquisition inventory transfer, v1.33 actual host `give`/`request` exchange, v1.34 dynamic inventory metadata snapshots, server-authoritative household invite/accept/activity loop, shared-storage host deposit plus guest withdrawal, v1.66 real arbitrary-item/container metadata storage and retrieval, v1.67 actual forced-server-stop household journal repair after fresh host+guest reconnect; v1.68 actual forced-server-stop career-delivery journal repair after fresh host+guest reconnect, disconnect-clean local native NPC replicas, authoritative remote marker fallback and v1.21 local native remote-player fallback, v1.27 native reannouncement adapter probing, v1.31 collision-aware native NPC fallback movement, v1.47 server-authoritative zombie danger handling in a real two-client session, v1.52 loaded-cell remote-player native discovery plus late native promotion with a hands-free host+guest capture, and v1.54 per-account appearance-select commands with separate host+guest native hair application | Simultaneous gameplay beyond the tested delivery, mod distribution, broader global-data crash atomicity, successful native body reannouncement, stable two-way remote movement under a naturally missing native peer, and replicated-character UI |
| Verification on this machine | Lua 5.1 tests; installed-game Kahlua harness; isolated real PZ profile; v1.14 vanilla world-item pickup plus fresh production delivery; v1.31 hands-free host+guest movement, NPC replicas and runtime API probe; v1.33 hands-free host `give`/`request` exchange against Marisol; v1.34 hands-free snapshot metadata and dynamic item-selection regression; v1.35 hands-free dedicated-server restart and post-restart NPC inventory exchange; v1.38 forced-crash journal repair with reconnect; v1.47 real server zombie seed, production danger response, and connected host+guest NPC replication; v1.48 stale streamed-replica contract and engine-VM coverage; v1.49 clean-profile hands-free startup plus live host+guest stale-body recovery; v1.50 natural-walk streaming attempt plus separate forced recovery probe; v1.51 late-native-body promotion contract and engine-VM coverage; v1.52 loaded-cell remote-player native discovery contract, engine-VM coverage, and actual hands-free host+guest capture; v1.53 packetless loaded-cell NPC-native promotion contract and engine-VM coverage; v1.54 appearance preset contract, panel contract, engine-VM coverage and actual hands-free host+guest native hair capture; v1.56 actual hands-free automatic wardrobe-layer removal capture; v1.57 native NPC online-id promotion contract and engine-VM coverage; v1.58 versioned QA evidence-root and actual host+guest probe; v1.59 duplicate native online-id suppression; v1.60 stable authored online-id assignment contract, Lua/Kahlua coverage and actual v81 host+guest probe with `onlineHints=0`; v1.61 runtime setter probe in an actual v82 host+guest run; v1.66 actual host+guest arbitrary-item/container metadata capture and restoration; v1.67 actual forced server-stop household journal repair after fresh host+guest reconnect | Broader world/inventory/NPC/host integration tests and regression suite |

## Current test environments

- Unit fixtures: E:/pzmod/tests. They are labeled mocks, not claimed multiplayer runs.
- Installed game VM: tests/EngineLua.java loads the unmodified game jar and executes
  actual production Lua with explicit world/network mocks. This catches Kahlua differences.
- Real engine: E:/pzmod/test-profile, launched by tools/launch-qa.ps1, with a separate
  no-Steam game process and its own saves, mods, options and console log.
- QA-only mod: qa/NeighborhoodQA. Never deploy it to the normal user mod folder.
- User gameplay process and saves are not used as disposable fixtures.

## Design contracts

- Player identity comes from the server callback, never from client-supplied usernames.
- Supply requests consume only unequipped main-inventory items. No partial delivery.
- Career claims are per career/day/slot; switching careers preserves prior claims.
- Duplicate packets do not reward twice during a running server. NPC inventory
  journal repair after a forced crash is proven in v1.38; broader global-data
  crash-atomic commits remain open and must be investigated before release.
- Careers persist per account per world, including after a survivor dies.
- A career work shift is one claim per career/world day; vanilla perk level remains
  authoritative for promotion gates.
- Community credits are currently a ledger, not yet spendable currency.
- Saved outfits are replacement presets: matching layers are retained, unrelated
  worn layers are removed with vanilla timed actions, and saved inventory garments
  are then equipped. v1.56 closes the automatic unrelated-layer gameplay gate.
- Vanilla stats remain authoritative. Need percentages show adverse intensity, lower is better.
- Needs bar fill shows remaining wellbeing (1 minus adverse intensity), while the number
  retains vanilla adverse intensity. Panel header explicitly says lower percentages are better.
- Relationships never create pretend world characters. Empty world registries show an
  explicit not-yet-registered state; social actions require an actual authoritative body.
- All authored romance candidates are adults. Interest grows after trust/friendship;
  NPC partnership is shared world state, not an independent partnership for each player.
- NPCs must be real in-world characters. A journal list or static prop is not equivalent.
- Existing IsoSurvivor constructors alone do not prove network replication. Investigate
  actual Lua exposure, character update behavior, and replication before choosing the adapter.

## Next engineering gates

1. Broaden global-data crash atomicity and household routines; v1.63 proves a guest main-inventory retrieve from the production furnishing, v1.64 proves household storage membership/furnishing/item persistence across a dedicated-server restart, v1.66 proves arbitrary item/container metadata capture and restoration in a real host+guest run, and v1.67 proves repair of an interrupted household storage transaction after a forced server stop.
2. Resolve native NPC server-body reannouncement and test persistent movement under a naturally missing native peer; the current v1.62 run still reports `GameServer=nil`, `Java=nil`, and `onlineHints=0`.
3. Expand the vertical slice into conversations, relationships, romance, neighborhood careers, households, aspirations and furnishings without reducing the host/invite multiplayer requirement.
4. Integrate conversations, relationships, romance and neighborhood careers.
5. Expand appearance/clothing assets, households, aspirations, furnishings and UI polish.

## v1.62 actual career and NPC-inventory restart gate

The isolated hands-free Build 42.20.4 capture in `evidence/v84/actual-v89/`
proves a real host-plus-guest session, two online players after a dedicated
server restart, three persistent moving authored NPCs with production native
paths, career work persistence (`career=medic shifts=1 xp=35 credits=15
workedToday=true`), and NPC inventory persistence plus a post-restart request
for `Base.RippedSheets`. This is actual gameplay evidence, separate from the
mock/unit Lua suites and the installed-game Kahlua engine-VM suites.

The restart-tool parameters and QA reconnect/retry behavior are test tooling
only. The QA helper remains outside the production mod. The full scope remains
host/invite multiplayer, persistent moving NPCs, careers, customization,
clothing, relationships, households, and optional zombies.

The gate does not close native server-body reannouncement: the real dedicated
server still exposes `GameServer=nil`, `Java=nil`, and `onlineHints=0` to the
mod Lua bridge. Shared household storage beyond the existing sheet exchange,
broader global-data crash atomicity, and breadth across the remaining life
systems remain open.

## v1.63 actual co-op household furnishing transfer

The isolated hands-free Build 42.20.4 capture in `evidence/v93/actual/`
records a real host-plus-guest household path: the host created a home and
invited the guest; the guest accepted and moved to the shared home; the host
stored one `Base.RippedSheets` through the production world-object furnishing;
the guest retrieved it through the same production callback and verified
`Base.RippedSheets count=1` in its real main inventory. The server log records
both authoritative furnishing operations. Ownership transfer and the tidy
household activity also completed in this run.

This is actual gameplay evidence, distinct from mock/unit Lua tests and the
installed-game Kahlua engine-VM suites. It closes only the first co-op storage
transfer assertion. The full scope remains host/invite multiplayer,
persistent moving NPCs, careers, customization, clothing, relationships,
  households, and optional zombies; richer item metadata and broader home life
  remain open.

## v1.64 actual household storage restart persistence

- The QA-only hands-free runner preserved the existing household instead of
  reseeding it, stopped the real Build 42.20.4 dedicated server, restarted it
  against the same cachedir, and forced the connected host through a production
  household refresh.
- The host logged `HOUSEHOLD RESTART SNAPSHOT: members=2 owner=nl-guest
  storage=Base.RippedSheets/3 furnishing=storage`; the same reconnect also
  logged the persisted career snapshot. The tool returned
  `PASS: host observed persisted household membership, furnishing, and storage
  after dedicated-server restart`.
- This closes household storage process-restart persistence for the tested
  fixture. It does not close richer item/container metadata, global-data
  crash-atomic commits, offline/co-op home routines, or native NPC server-body
  reannouncement. QA helpers remain outside the production mod package.

## v1.67 household storage crash atomicity

- The production household authority now journals the pre-mutation player
  inventory count, household storage maps, item metadata, and revision before a
  store/retrieve operation. The journal remains in world ModData until both
  owners reach a consistent state; a later household command repairs or clears
  the interrupted transaction.
- `tools/run-household-crash-qa.ps1` uses only disposable profiles and the
  hands-free launcher. It observed a real `NLQA HOUSEHOLD JOURNAL PARTIAL`
  marker, waited for `SaveAll`, forcibly stopped the dedicated Build 42 server,
  restarted it against the same cachedir, launched fresh host and guest
  clients, and returned `PASS: partial household storage transaction repaired
  after forced server crash`.
- This is actual engine gameplay evidence, separate from Lua unit fixtures and
  Kahlua engine-VM tests. It closes only the tested household storage
  transaction; broader global-data atomicity, offline/co-op routines, native
  NPC server-body reannouncement, and the full life-sim scope remain open.

## v1.65 household item metadata foundation

- `NLHouseholds` now stores bounded per-instance records under
  `storageEntries` while retaining the count-based `storage` contract for
  legacy saves and existing UI. Summaries expose `storageDetails` without
  exposing arbitrary client data.
- The server-authoritative furnishing path captures and restores item name,
  category, container type, condition, maximum condition and used delta using
  guarded Build 42 method calls. Failed storage operations still restore the
  removed inventory items.
- The world-object menu enumerates unequipped main-inventory item types and
  authoritative stored types; its no-inventory fallback preserves the legacy
  sheet action. The household panel displays the first saved metadata records.
- `tests/households.lua` covers multi-instance metadata persistence and
  retrieval; the full Lua 5.1/Kahlua pipeline passes. These are mock/unit and
  engine-VM checks, not actual multiplayer proof. A real arbitrary-item and
  container transfer capture remains open.

## v1.66 actual household item/container metadata capture

- The QA-only launcher now has `-VerifyHouseholdMetadata`; it seeds genuine
  Build 42 `Base.KitchenKnife` and `Base.WaterBottle` instances in the host's
  networked inventory, then drives the production world-object furnishing path.
- In `evidence/v96/actual/launch-d/`, the real dedicated server and both
  isolated clients logged storage and retrieval of the knife with `condition=4`
  and the bottle with `usedDelta=0.25`. The guest's real inventory readback
  matched both values. Build 42 fluid containers use the `getFluidContainer()`
  amount/capacity API; the production authority now restores that state before
  sending the client item replica.
- This is actual engine multiplayer evidence, distinct from mock/unit and
  installed-game Kahlua engine-VM checks. It closes the tested arbitrary
  item/container metadata gate, not global-data crash atomicity, broader home
  routines, or native NPC server-body reannouncement. QA helpers remain outside
  the production mod package.

## v1.26 direct two-client social action

The QA-only hands-free client stimulus now gives each account its own social
viewpoint. In `evidence/v45/`, the guest moved beside Kenji, refreshed its own
relationship snapshot, sent the real production `introduce` command, and
received `friendship=3` and `trust=2` for Kenji. The host received the
replicated `actor=nl-guest` event while its private Marisol values remained
separate. The server log records the authoritative guest command and result.
This is actual two-client action and event evidence; richer world actions and
romance synchronization remain open.

## v1.27 native NPC reannouncement adapter probe

- Production `NLNpcAuthority` now includes a best-effort adapter for Build 42's
  public `GameServer.getConnectionFromPlayer` and
  `GameServer.sendPlayerConnected` methods. It is invoked after the existing
  authoritative `npc_presence` packet and retains that packet as the
  compatibility path when the Java table is unavailable.
- `tests/npc-authority.lua` uses a deterministic `GameServer` fixture to verify
  that all three authored native bodies are sent to a connected player. This
  is mock/unit evidence; the consolidated pipeline and installed-game Kahlua
  suites remain separate from gameplay evidence.
- `evidence/v46/` records a fresh hands-free Build 42.20.4 server with both
  isolated clients connected. The server spawned and moved all three native
  neighbors, both clients received three moving native replicas, and the guest
  completed its Kenji social probe. The same server logged
  `GameServer=nil` during both refresh probes, so the adapter did not execute
  through the native engine API. Successful native reannouncement remains an
  open engine-exposure gate.

## v1.28 server-authoritative wardrobe slice

- Production wardrobe saves now go through `NeighborhoodLife` as a
  `wardrobe_save` command. The server reads the connected player's actual
  worn-item list, validates slots 1-3, persists exact garment full types and
  item identities in the private profile, increments the profile revision and
  returns the preset in the normal snapshot packet.
- The client wardrobe panel and world-object context menu request that
  authoritative save. The client applies returned presets to its local outfit
  data, while the existing vanilla `ISWearClothing` action remains the wear
  path. `tests/wardrobe-authority.lua` covers capture, invalid slots,
  persistence and snapshot delivery in Lua 5.1 and the installed Kahlua VM.
- `evidence/v47/` records an actual host-plus-guest Build 42.20.4 run. The
  host opened the real 590x450 wardrobe panel, sent `wardrobe_save` after the
  command-throttle interval, and received revision 72 with slot 1 persisted.
  The disposable character had zero worn garments in this run, so this proves
  the server-authoritative empty-preset path and UI integration, not a visual
  garment replacement yet.

## v1.29 actual non-empty wardrobe and reconnect evidence

- The QA-only isolated server fixture placed real `Base.Shirt_FormalWhite` and
  `Base.Trousers_Denim` items on the host's current square. The host acquired
  both through the vanilla world-transfer action, equipped both through the
  vanilla `ISWearClothing` action, and then invoked the production
  server-authoritative `wardrobe_save` command. The fixture and items remain
  outside the production package.
- `evidence/v48/` records the actual Build 42.20.4 host-plus-guest run. The
  host logged `WARDROBE PICKUP COMPLETE` for both garments,
  `WARDROBE WORN COMPLETE` for both garments, and a saved slot 1 snapshot with
  `pieces=2` at revision 73. After a stable hands-free same-client disconnect
  and reconnect, the host received revision 74 with `pieces=2` again. This is
  actual gameplay persistence evidence, not a mock or engine-VM claim.
- The same run retained the 6x10 plumbob above the player and the guest logged
  three moving native NPC replicas plus its Kenji social event. The production
  saved-outfit replacement probe is recorded separately in v1.30 below.

## v1.30 actual saved-outfit replacement

- The QA-only isolated client now waits for the real saved slot, queues vanilla
  `ISUnequipAction` for the captured garments, verifies both body locations are
  empty, and calls the production `NLWardrobe.wear(player, 1)` function. QA
  does not implement or replace the production wardrobe action.
- `evidence/v49/` records the actual Build 42.20.4 result: the host acquired
  and wore both garments, saved revision 75, completed vanilla unequip with
  both counts at zero, and then logged
  `WARDROBE REPLACEMENT COMPLETE` for both garments from
  `production-NLWardrobe.wear`. No unequip-action errors remained in the
  captured run.
- This closes the actual saved-outfit replacement probe. New clothing
  variants, original assets and unlock/reward integration remain breadth work.

## v1.38 forced-crash NPC inventory recovery

- The isolated hands-free runner arms a temporary QA-only fault after the
  production `give` command removes the player's item and journals the pending
  NPC-side mutation. It waits for the real dedicated server's `SaveAll`, stops
  that process, restarts it with the same cachedir, and asks the host client to
  reconnect.
- The restarted production authority logged
  `NLQA INVENTORY JOURNAL RECOVERY: state=repaired`, restoring the player's
  pre-transaction count and NPC row. The host received `Inventory recovery
  repaired` in its private snapshot.
- `evidence/v58/` contains the baseline/modified/rollback tests and real
  server/host/guest logs. This is actual Build 42 process and gameplay
  evidence, not a mock or engine-VM claim. The QA fault config and runner are
  not packaged into the production mod. Broader global-data crash atomicity,
  world actions and item/container breadth remain open.

## v1.37 transactional NPC inventory recovery

- Production `NLSocialAuthority` writes `world.inventoryJournal` before an NPC
  `give` or `request` mutation. The journal records player and NPC pre-state,
  item metadata, revision and transaction phase, then clears only after both
  persisted owners apply.
- The next authoritative command for the same account repairs a partial
  player-side or world-side mutation, finalizes a fully applied transaction, or
  discards an untouched journal. The focused authority suite covers both
  partial directions and the complete 31-assertion path passes in Lua 5.1 and
  the installed Kahlua VM.
- The v1.38 forced-crash probe exercises this recovery path across a real
  dedicated-server process restart.

## v1.40 career work shifts

- Each career now exposes a named daily work shift in the production journal.
  The server records one claim per career and world day, awards 15 career XP
  and 5 community credits, and keeps the vanilla perk level as the promotion
  gate. A duplicate claim is rejected until the next world day.
- `evidence/v60/` records actual Build 42 host-plus-guest gameplay: the host
  completed the medic delivery, sent the production `work` command, received
  `Staff the neighborhood clinic: +15 career XP, +5 community credits`, and
  continued into the household sequence. Lua/Kahlua tests remain separate
  mock and engine-VM evidence.

## v1.41 career work persistence

- The hands-free runner now performs a real daily work shift, restarts the
  dedicated server, reconnects the host, and checks the persisted career
  snapshot before continuing the household sequence.
- `evidence/v61/` records `CAREER WORK RESULT` before restart and
  `CAREER WORK RESTART SNAPSHOT` afterward with `workedToday=true`,
  `shifts=1`, `xp=615`, and `credits=450`; the NPC inventory snapshot also
  survives and the post-restart exchange completes.
- This is actual Build 42 host-plus-guest gameplay evidence. Unit/Lua and
  installed-game Kahlua tests remain classified separately and do not claim
  multiplayer completion. Career rank progression and richer work remain open.

## v1.42 tiny plumbob placement

- The production marker now uses an 8x11 source texture, a 2x3 runtime panel,
  and a 10-pixel lift. The source reduction protects the smaller appearance
  when Build 42 draws the texture at native dimensions; the shorter lift keeps
  the tip close above the player model.
- The focused plumbob contract suite locks the tiny dimensions. This is a
  presentation change and does not add multiplayer or NPC completion claims.

## v1.44 household ownership transfer

- The household authority now accepts `transfer` only from the current owner
  and only for an existing member. It changes the owner and member roles in a
  single revisioned mutation, then notifies every online household member.
- The household panel exposes `Transfer owner` and selects another current
  member. Unit, engine-VM, and client-routing tests cover owner checks and the
  role transition.
- `evidence/v64/` records actual hands-free host-plus-guest gameplay:
  `HOUSEHOLD TRANSFER RESULT: owner=nl-guest members=2`, followed by the
  shared household task. Functional storage furnishing interaction was added
  in v1.45; offline/co-op routines remain open.

## v1.45 functional household storage furnishing

- The production household storage object now exposes a world-object context
  menu with store/take actions. The client sends a `furnishing` request, while
  the server validates the household membership, native furnishing proximity,
  action, item type and quantity before mutating shared storage.
- `household-furnishing-menu.lua` covers menu identity and routing, and the
  authority suite covers the server command. These are mock/unit and installed
  game-VM checks, not gameplay claims.
- `evidence/v65/` records an actual isolated Build 42 host-plus-guest run in
  which the host stored a real `Base.RippedSheets` item through the furnishing
  command, the guest retrieved it from the same native furnishing, and the
  household continued with ownership transfer. The later task probe returned
  the server's existing daily replay guard because this isolated save already
  had that task claimed. QA helpers remain outside the production package.

## v1.43 multiplayer HUD identity

- The production needs panel now labels each instance with the local character
  name, such as `NEEDS / nl-host / LOWER % IS BETTER`, while retaining six
  live vanilla-stat rows and the existing fold/actions behavior.
- `evidence/v63/` records actual hands-free Build 42 host and guest panels:
  both clients created six-row HUD instances and read their own six stat
  values independently. QA logging remains outside the production package.
- This closes the runtime HUD-routing evidence gate. Resolution and broader
  accessibility polish remain open; it does not claim NPC or multiplayer
  completion beyond the observed HUD loop.

## v1.39 pin-sized plumbob placement

- The production runtime panel is now 3x5 pixels with a 20-pixel lift instead
  of 4x7 and 30 pixels. The gem remains above the player model while taking
  less visual space.
- The focused plumbob contract suite locks the pin-sized dimensions. This is a
  presentation change and does not add multiplayer or NPC completion claims.

## v1.36 extra-small plumbob placement

- The production runtime panel is now 4x7 pixels instead of 6x10, while the
  30-pixel lift keeps the marker above the model.
- The focused plumbob contract suite locks the extra-small dimensions. This is
  a presentation change and does not add multiplayer or NPC completion claims.

## v1.35 dedicated-server restart persistence probe

- The isolated hands-free runner now stops and restarts the real Build 42
  dedicated server after the production inventory give/request exchange, then
  reconnects the host client without desktop input.
- The post-restart host snapshot contained `Base.RippedSheets/1/Rag`; the next
  give produced `Base.RippedSheets/2/Rag`, and the request completed. The
  evidence is actual host-plus-guest engine gameplay, not a mock test or the
  installed-game VM suite.
- This establishes process-restart persistence for the NPC inventory slice. It
  does not establish forced-crash atomicity, native `GameServer` body
  reannouncement, or the broader missing-peer/danger/death gameplay gates.

## v1.34 generalized NPC inventory selection and metadata

- `NLNeighbors` now normalizes legacy NPC inventory rows: invalid item keys and
  non-positive counts are discarded, valid counts are integerized, and each
  stored item retains a persisted display label in `inventoryMeta`.
- Social snapshots include a deterministic `inventoryItems` list. The
  Relationships panel selects the first unequipped main-inventory item for
  `give` and the first stored NPC item for `request`; the server remains the
  authority for the full item type, amount and resulting count.
- Contract and installed-game Kahlua suites cover a second item type, metadata,
  malformed-save normalization and dynamic UI callbacks. `evidence/v54/`
  records actual Build 42 host-plus-guest snapshot metadata
  (`Base.RippedSheets/2/Rag`) alongside the successful production exchange and
  three moving NPC replicas. Crash-atomic inventory/global-data commits and
  richer container metadata remain unproven.

## v1.32 native NPC lifecycle retirement and offscreen recovery

- Production `NLNpcAuthority` now removes a dead native body from the
  authoritative registry, cancels its path, unregisters its social body and
  persists the row as dead. The next presence packet omits the dead neighbor,
  allowing clients to remove its replica and plumbob instead of keeping a dead
  body visible.
- A body missing from the server cell object list is now retired as an offscreen
  transient. Its last fractional position remains in the persistent neighbor
  row; scheduled recovery calls `spawnBody` with no player fallback, so an
  unloaded home tile cannot relocate the NPC to a connected player's position.
- `tests/npc-authority.lua` covers body removal, saved-position retention,
  saved-tile recovery and native death retirement. These are mock contract
  assertions, and the consolidated Kahlua suite repeats them in the installed
  game VM; neither is actual offscreen streaming or damage gameplay evidence.
- `evidence/v52/` records the baseline/modified/rollback artifacts and a fresh
  hands-free host+guest regression run. That run proves the existing three-NPC
  presence, movement, plumbob and guest-social loop; it does not claim that the
  QA session naturally caused damage, death or cell streaming.

## v1.31 collision-aware NPC fallback and runtime API gate

- Production `NLNpcAuthority` now checks the destination tile before its
  dedicated-server stalled-path fallback moves a native NPC. A blocked tile
  causes the body to choose a bounded free neighboring step; when no safe step
  exists, the authority cancels the path, advances the persisted route and
  emits a `BLOCKED` diagnostic instead of moving through the obstruction.
- `tests/npc-authority.lua` covers both the free-tile fallback and refusal to
  cross a blocked tile. These are mock contract assertions, not gameplay
  evidence.
- `evidence/v51/` records an actual Build 42.20.4 host-plus-guest run after
  the production change. The server logged native route movement, both clients
  received three moving NPCs and the guest logged the real social event. The
  same run probed the public Java class route; the native server still exposed
  `GameServer=nil`, the reflective class wrapper exposed neither
  `getClassLoader` nor `forName`, and `reflectiveNpcSent=0`. The mod therefore
  keeps the authoritative `npc_presence`/local-native-replica route rather
  than claiming native server-body reannouncement.
- This closes the collision-aware fallback probe. Damage/death, offscreen
  scheduling and the engine-native reannouncement gate remain open.

## v1.25 compact plumbob asset and placement

The production plumbob source texture is now 16x22 pixels, the runtime panel is
6x10 pixels, and the world-to-screen lift is 30 pixels. The smaller source
asset makes the reduction visible even if Build 42 draws the texture at native
dimensions, while the panel anchor keeps the gem directly above the model.
Lua and installed-game Kahlua tests passed, and the QA-only live marker logger
records the panel and source-texture dimensions during a hands-free run.
This is visual presentation evidence only; it does not claim native remote
player body replication or completion of the remaining multiplayer gates.

## v1.14 client-acquisition inventory evidence

- `evidence/v33/` records a fresh hands-free host plus guest run against the
  isolated Build 42.20.4 profile. The QA-only server placed eight
  `Base.RippedSheets` world items on the host's current square and sent only a
  seed acknowledgement; it did not add items to the inventory.
- The host client discovered the synced world objects after the acknowledgement,
  queued vanilla `ISInventoryTransferUtil.newInventoryTransferAction` actions,
  and logged `CAREER PICKUP COMPLETE` with `localInventory=8` and
  `source=world-transfer-action`. The production medic contract then consumed
  those acquired items and returned `Delivery complete: +20 career XP, +10
  community credits.`
- The guest independently logged two-player presence, three production NPC
  replicas and `productionNpcNativePaths=3`. This is actual host-plus-guest
  engine evidence; the pipeline and Kahlua suites remain mock/engine-VM tests
  and do not substitute for the gameplay result.
- Native server-body reannouncement, obstacle/danger handling, damage/death,
  offscreen behavior, households and aspirations remain open gates.

## v1.15 household vertical slice

- `evidence/v34/` records the real hands-free host plus guest loop. The host
  created a Neighborhood Home at its current tile, invited `nl-guest`, and the
  guest accepted through the production household command adapter.
- Both clients received a two-member household snapshot. The host completed
  the authoritative `tidy` home activity at the saved home tile; the server
  applied the daily replay guard, awarded five credits, and sent the result to
  both clients. This is actual Build 42 multiplayer evidence, not a unit-test
  or engine-VM claim.
- The household implementation is intentionally server-authoritative: member
  identity comes from the server callback, invitations are checked against the
  online roster, activity location is checked against the saved home tile, and
  daily activity claims persist in world data.
- Inventory-sharing rules, furnishings, household-linked aspiration goals,
  native server-body reannouncement, obstacle/danger handling, damage/death
  and offscreen behavior remain open gates.

## v1.2 two-client NPC state and replica evidence

- `evidence/v19/` records the real hands-free run from `tools/launch-multiplayer-qa.ps1`
  with one dedicated server and two isolated clients.
- The production server spawned Marisol as a native body and logged authoritative
  movement from `6815.50,5259.50` through `6816.22,5259.50` to `6817.02,5259.50`.
- Both real clients received revisioned `npc_presence` packets containing the same
  server positions and logged a local native `Marisol Vega [Neighborhood Life]`
  object. This is actual gameplay evidence for mod-state distribution and client
  replicas, not a unit-test or Kahlua claim.
- Build 42 did not expose `GameServer` as a Lua table in the run. Native server-body
  reannouncement, reconnect/restart, inventory/action delivery, danger, damage/death,
  obstacles and offscreen behavior remain open gates.

## v1.4 dedicated-server restart evidence

- `evidence/v21/` records a real isolated server save followed by a new dedicated
  server process using the same world profile and newly joined host/guest clients.
- The seed run moved Marisol to `6816.70,5259.50` with the QA-only one-minute save
  interval. The next server logged `RESTORE id=marisol ... revision=5` and
  `SPAWN id=marisol x=6816.70 y=5259.50`, preserving the fractional position.
- The host and guest then received `npc_presence` for the restored position and
  created local native replicas. This is actual gameplay evidence for ModData
  persistence across a dedicated-server restart.
- Native Build 42 body reannouncement, inventory/action
  delivery, obstacle/danger handling, damage/death, offscreen behavior and
  households remain open gates.

## v1.5 disconnect cleanup evidence

- Production `NLNpcClient` now registers cleanup for both `OnDisconnect` and
  `OnMainMenuEnter`; cleanup removes local native bodies and plumbobs and resets
  the accepted packet revision before a later connection.
- `tests/npc-client.lua` invokes the registered disconnect callback and verifies
  the reset. This is a Lua native-shaped contract test, not multiplayer evidence.
- The hands-free forced-server-stop probe is recorded in `evidence/v22/`. Build
  42 did not emit a client `OnDisconnect` transition during that early probe;
  the later `evidence/v29/` server-restart run supersedes it with a verified
  same-client reconnect.

## v1.6 three-neighbor vertical-slice evidence

- Production `NLNpcAuthority` now iterates the three authored identities in
  `NLNeighbors`: Marisol Vega, Kenji Arakawa and Amara Okonkwo. First-world
  homes are reserved on distinct nearby free squares; later starts use each
  row's persisted fractional position.
- `npc_presence` now carries each neighbor's name, gender and outfit metadata.
  The production client uses that metadata to construct correctly named native
  replicas and plumbobs instead of hard-coding Marisol.
- The hands-free B42.20.4 run in `evidence/v23/` recorded all three server
  bodies moving, both clients receiving `count=3`, and both clients listing all
  three native replicas in `ObjectListForLua`. This is actual multiplayer
  evidence for the three-neighbor slice, not a unit-test claim.
- Native Build 42 body reannouncement, inventory/action
  delivery, obstacle/danger handling, damage/death, offscreen behavior and
  households remain open gates.

## v1.7 actual social interaction evidence

- The QA-only hands-free client stimulus now waits for the native replica to be
  present, walks the host to a free square beside the slice, refreshes the real
  production relationship snapshot, then sends one delayed `introduce` command.
  The delay avoids the server's duplicate-command throttle rather than bypassing
  it.
- In the isolated B42.20.4 run, the host snapshot reported `canInteract=true`
  for Marisol and the server returned `I'm Marisol Vega. It's good to meet
  another survivor.` The host then received `met=true` and `friendship=6`.
- The guest, which remained at a distant position, received its own snapshot with
  all three `canInteract=false` and Marisol `met=false`, proving the relation
  mutation stayed keyed to the host account. These are real two-client engine
  logs, not Lua-only or Kahlua evidence.
- Multi-step conversations, richer world actions, inventory exchange and native
  reannouncement remain open.

## v1.8 multiplayer career delivery evidence

- The QA-only server observer seeded six `Base.RippedSheets` into the real host
  inventory, then returned a `career_seeded` acknowledgement. The production
  client selected `tailor` and submitted `tailor:1:1` through the normal
  `NeighborhoodLife` command path.
- The actual dedicated server logged the production `select` and `deliver`
  commands, removed the required authoritative items, advanced the host profile
  and returned `Delivery complete: +20 career XP, +10 community credits`.
- This proves the production multiplayer delivery path against a real server
  inventory and real account profile. It does not yet prove a client-acquired
  item's inventory replication path, career rank persistence after restart or
  multiplayer wardrobe exchange; those remain open.

## v1.9 authoritative remote marker fallback evidence

- `evidence/v27/` records a real isolated Build 42.20.4 dedicated server plus
  `nl-host` and `nl-guest` clients. Both clients received the same authoritative
  two-player `presence` roster while the host walk changed its server position.
- The host first logged `productionRemoteMarkers=1` while Build 42 exposed the
  native guest body. After native enumeration dropped that peer, the host logged
  `productionPresenceMarkers=1`; the guest logged the same fallback marker count.
  The fallback is driven only by server `presence` coordinates and does not make
  a character body or claim native remote replication.
- The same run retained three native NPC replicas and the existing production
  social/career probes. Native remote-body reannouncement and synchronized native
  movement remain open gates.

## v1.3 reconnect-state evidence

- `evidence/v20/` records the current production build in the hands-free dedicated
  server plus two-client launcher.
- The server returned the host snapshot and immediate `npc_presence` in the same
  refresh cycle. The guest received the same revisioned NPC state on its refresh.
- Both clients logged `productionNpcReplicas=1` and native Marisol object positions.
- The client now ignores older NPC revisions, and an authoritative empty roster
  removes the replica and plumbob. This improves reconnect state handling but does
  not yet prove a server process restart or native Build 42 body reannouncement.

## v1.1 production NPC vertical-slice evidence

- `NeighborhoodLife/42/media/lua/server/NL/NpcAuthority.lua` is now a
  production native-body adapter. It restores the `marisol` identity and
  position from `ModData`, creates an actual `IsoPlayer` with `setNpc(true)`,
  registers that body with the social authority, and persists route positions.
- The first isolated world anchors Marisol near the player, then alternates two
  free nearby waypoints. Single-player uses the local client event queue for
  native cadence; dedicated servers use the server tick. No synthetic body or
  client-supplied coordinates are used.
- The real engine run in `evidence/v18/` logged production spawn, plumbob
  anchoring, repeated native path completion, `GameWindow.save(false)`, and a
  second launch restoring `x=10777.50,y=10256.50,revision=21`. This is actual
  single-player production NPC evidence, not a mock or Kahlua-only test.
- The same run does not prove two-client NPC replication. Native remote-body
  visibility and dedicated-server distribution remain open.

## v0.3 investigation results

- Actual save/reload preserved career credits (npc-first-probe.log).
- An IsoPlayer configured with setNpc(true) was constructed without replacing local player 0.
- First probe recorded only 0.034 tiles of movement while the scene was paused. This is
  NOT evidence of working navigation. A new probe explicitly checks the model and alpha,
  attaches the render model and tests an adjacent unobstructed square.
- Native QA auto-load now selects only the separate test profile's latest save; production
  mod never auto-loads a save or spawns the experimental NPC.
- Social domain tests and authority tests execute in both Lua 5.1 and the installed Kahlua VM.
- An interrupted auto-load is logged separately and not counted as a passed test.

## v0.4 milestone evidence

- Git history now starts at commit 0efe222 and tools/pipeline.py consolidates
  Lua 5.1, syntax, installed Kahlua VM, production packaging and diff generation.
- NLNeighbors persists named neighbor identity, home, route position, waypoint,
  alive/dead state and revision in world ModData without creating pretend bodies.
  SocialAuthority now consumes that registry while engine bodies remain transient.
- tests/neighbors.lua passes in Lua 5.1 and the installed Kahlua VM. This is
  domain/engine-VM evidence, not native NPC movement or multiplayer evidence.
- tools/launch-multiplayer-qa.ps1 started a real B42.20.4 dedicated no-Steam
  server and two real client JVMs in isolated profiles. Both clients loaded the
  production and QA mods and the hands-free agent invoked OnSteamGameJoin,
  but the server recorded no player connections and neither client produced
  NLQA MP CLIENT START or NLQA MP SNAPSHOT. Host+guest gameplay remains open.
- Native NPC movement remains open: the latest real engine probe reports
  PATH RESULT: Working followed by PATH RESULT: Failed and distance=0.

## v0.5 presentation evidence

- `NL/Plumbob.lua` registers a screen-space marker without creating or substituting
  a character. It uses the engine's isometric projection and player viewport offsets,
  scales with zoom, hides dead bodies, and exposes `register`/`unregister` for future
  authoritative NPC adapters.
- `NL_Plumbob.png` is included in the production package. The installed B42.20.4
  single-player QA run logged `NLQA PASS: real engine plumbob panel registered and
  anchored at 1248,672`.
- This is actual single-player UI evidence. It does not prove remote-player
  replication, host/invite multiplayer, or native NPC movement.

## v0.6 NPC movement spike

- A QA-only IsoPlayer with `setNpc(true)` on an isolated single-player save
  completed three consecutive native pathfinding legs of roughly 2.0 tiles each
  with exact arrival (`targetError=0.000`) and 6.0 tiles total displacement.
- Engine finding: B42.20.4 does not tick an IsoPlayer that is not in the local
  player list. Without `preupdate`/`postupdate` the character's
  `isAnimationUpdatingThisFrame` stays false, deferred movement stays zero and
  `PathFindBehavior2:update()` fails after the walking-on-the-spot timeout with
  no displacement (the v0.3/v0.8 stationary result).
- The QA probe now emulates the engine frame per tick in the engine's order:
  `preupdate`, `update`, `PathFindBehavior2:update` (as vanilla
  `WalkToTimedAction` does), `postupdate`. Evidence: `evidence/v13/`.
- Boundaries: this proves native path-following movement for a QA body in
  single player only. It does not prove production NPC spawning, server-side
  ticking, two-client replication, persistence or danger reactions.

## v0.7 host/guest multiplayer evidence

- `tools/launch-multiplayer-qa.ps1` launched one isolated B42.20.4 dedicated
  no-Steam server and two isolated clients without mouse or keyboard control.
- The real server logged two `Connected new client` events. Host `nl-host` and
  guest `nl-guest` each reached `Connected`, `OnGameStart`, sent one real
  `NeighborhoodLife.refresh` command, and received their own revision-1
  production snapshot. Evidence is in `evidence/v14/`.
- The QA server uses `DoLuaChecksum=false` only because the isolated host and
  guest QA identity fixtures intentionally differ. The production package
  excludes QA helpers, identity fixtures, isolated profiles and the launcher.
- This is real engine multiplayer command/snapshot evidence, not a mock or
  engine-VM claim. The remaining multiplayer gates are synchronized movement,
  inventory/actions, reconnect/restart, remote-character markers, and NPC
  replication/persistence. The native NPC movement result remains QA-only
  single-player frame-emulated evidence from v0.6.

## v0.8 native remote-player marker evidence

- The production plumbob now enumerates Build 42's client `getOnlinePlayers()`
  list and attaches a marker to each non-local native player body. It never
  creates a substitute body or uses client-supplied coordinates.
- In the real two-client run recorded under `evidence/v15/`, the host saw the
  native guest body in `ObjectListForLua` and `OnlinePlayers` at
  `10754.00,10214.00,0`, with `productionRemoteMarkers=1`.
- The guest initially saw only itself (`OnlinePlayersCount=1` and
  `productionRemoteMarkers=0`), and the host's remote entry later disappeared.
  This is evidence of a one-way/unstable native remote-body replication gap,
  not completion. The next gate is server-side repair or a reliable native
  join/update path, followed by stable remote movement and persistence.

## v0.9 authoritative presence channel

- Production `NLAuthority.broadcastPresence()` now reads server-side
  `getOnlinePlayers()`, packages each authoritative username, position, floor
  and online ID, and sends the roster privately to every connected player.
- A real two-client run logged both `nl-host` and `nl-guest` on both clients,
  twice, while the native body scan still showed the guest-only-on-host
  asymmetry. This proves a real mod-level replication channel, not native body
  replication.
- The presence channel is groundwork for movement and NPC state replication;
  it does not create bodies, replace native movement, or complete reconnect,
  inventory synchronization, NPC persistence, or two-way remote markers.
- A QA attempt to call Build 42's native `GameServer.sendPlayerConnected`
  repair path recorded that `GameServer` is not exposed as a Lua table on this
  dedicated server. Native re-announcement therefore remains an engine/API
  investigation gate rather than claimed functionality.

## v1.0 movement-state heartbeat evidence

- Production clients now send a server command heartbeat every 300 render
  frames. The server derives positions from its authoritative `getOnlinePlayers()`
  objects and rebroadcasts revisioned presence to every client.
- The hands-free real-engine run queued a native walk for `nl-host` from
  `6817.50,5259.50` to `6819.50,5259.50`. Subsequent guest logs received both
  players with the changed host position repeatedly. Evidence is in
  `evidence/v17/`.
- This proves mod-level position replication for a real movement change. It
  does not yet prove stable native remote-body visibility, inventory/action
  replication, reconnect/restart, or production NPC movement/persistence.

## v1.11 distinct native NPC spawn repair

- `evidence/v30/` records a fresh isolated Build 42.20.4 host plus guest run
  against the persisted QA world after the server had previously saved all
  three legacy rows on one tile.
- The production server logged `RELOCATE` for Kenji and Amara, moving them from
  the stacked `8282,11718,0` square to `8281,11718,0` and `8282,11717,0` before
  native spawn. The server then logged separate native paths for all three.
- Both clients received `count=3` `npc_presence` entries with distinct
  coordinates and logged `productionNpcReplicas=3`; their object scans listed
  Marisol, Kenji and Amara at separate positions. This is actual gameplay
  evidence, while `tests/npc-authority.lua` remains a mock contract for the
  collision-repair branch.

## v1.10 same-client reconnect after dedicated-server restart

- `evidence/v29/` records a hands-free isolated run in which the dedicated
  server was stopped at PID 13140 after both clients were in-game, then
  restarted as PID 28040 with the same `mp-server` profile and world save.
- The QA-only agent requested the host engine disconnect without mouse or
  keyboard input. The host logged `MainScreenState`, a new connect cycle,
  `CONNECTED`, and a new `CLIENT START`; the guest continued receiving the
  authoritative presence stream.
- The restarted server logged `RESTORE` for Marisol, Kenji and Amara from the
  saved fractional position before spawning their native bodies. After the
  host rejoined, both clients again logged `productionNpcReplicas=3` and
  revisioned `npc_presence`. This proves same-client reconnect plus NPC
  persistence across the server restart. Native body reannouncement remains
  open.

## v1.13 native client NPC movement evidence

- Production `NLNpcClient` now starts a Build 42 `PathFindBehavior2` target for
  each authoritative NPC replica and drives the native `preupdate`, `update`,
  behavior and `postupdate` frame sequence. It only falls back to bounded
  interpolation when that native behavior is unavailable or stalls.
- `evidence/v32/` records a fresh hands-free B42.20.4 host plus
  guest run. Both clients logged three production NPC replicas with
  `productionNpcNativePaths=3`, while authoritative positions advanced over
  multiple presence packets. This is actual client-engine movement evidence,
  not a Lua-only or Kahlua claim.
- Build 42 still does not expose the server's native `GameServer` class to Lua;
  native server-body reannouncement to the engine player list remains open.

## v1.16 shared household storage evidence

- Production household storage persists exact item-type counts in the authoritative
  household record. Deposits require an online member at the home tile and consume
  only unequipped matching items from that member's main inventory. Withdrawals are
  member-authorized, restore vanilla inventory items, and cannot exceed the stored
  count or the 500-item household capacity.
- The Home panel exposes the first vertical-slice storage actions for
  `Base.RippedSheets`; the server also validates arbitrary well-formed item types,
  amount bounds, membership and malformed requests independently of the UI.
- The v1.16 hands-free Build 42.20.4 run in `evidence/v35/` seeded nine real world
  sheets through the QA-only server. The host acquired all nine through vanilla
  transfer actions, delivered eight through the production medic contract, deposited
  the remaining sheet into shared storage, and the guest withdrew it. The same run
  then completed the shared tidy activity and retained three native NPC replicas with
  native movement paths on both clients.
- QA helpers remain outside the production package. Native server-body reannouncement,
  furnishings, richer item metadata and offline household routines remain open.

## v1.17 household furnishing vertical slice

- Production households now carry a persistent furnishing record for the shared
  storage tile. The dedicated server reconciles that record to a native
  `IsoObject` with household identity ModData and removes it when the last member
  leaves. The Home snapshot includes the furnishing kind, sprite and tile.
- Build 42.20.4 did not consistently replicate a Lua-created dedicated-server
  `IsoObject` to clients in this run, so the production client creates the same
  native tile object from the revisioned household snapshot when the home square
  is streamed locally. This is a bounded engine workaround, not a claim of native
  network-object replication.
- The v1.17 hands-free run in `evidence/v36/` logged the persisted native server
  furnishing at `8282,11720,1`; the host created a native client furnishing from
  the authoritative snapshot, and the guest received the same `storage` snapshot
  during the real invite, storage deposit/withdrawal and tidy loop. The guest's
  camera remained away from the home tile, so its unloaded square correctly did
  not produce a local object. Server storage, guest withdrawal and three native
  NPC replicas with native movement paths were also observed.
- Mock tests cover server creation/reuse/removal and client identity/cleanup;
  the Kahlua engine-VM suite passes; the v36 logs are the actual host/guest
  gameplay evidence. Native cross-client furnishing replication, streamed-in
  client retry when a distant home becomes loaded, native server-body
  reannouncement, richer item metadata and offline household routines remain
  open gates.

## v1.18 streamed-in household furnishing retry

- Production clients now retain the latest furnishing snapshot when its square
  is not loaded and retry it on every engine tick. Once Build 42 streams the home
  square, the client creates exactly one native furnishing replica and clears the
  pending entry; menu/disconnect cleanup clears both loaded and pending state.
- The server now uses Build 42's `IsoObject.getNew` and
  `IsoGridSquare.transmitAddObjectToSquare` path when available. This is the
  correct native add path, but the isolated Build 42.20.4 clients still did not
  expose the server object in their object list, so the snapshot replica remains
  the production fallback rather than a false native-network claim.
- `evidence/v37/` records the hands-free host/guest run after the real invite,
  storage deposit/withdrawal and tidy sequence. The QA-only viewpoint fixture
  loaded the shared home tile for the guest without mouse or keyboard input;
  both clients logged `productionHouseholdFurnishingClient=1` and
  `productionHouseholdFurnishingPending=0`, while both received
  `furnishing=storage` and retained three native NPC replicas with native paths.
  The viewpoint relocation is explicitly QA fixture evidence, not a claim that
  normal guest walking has been completed.
- Mock, engine-VM and actual gameplay evidence remain separate. Native
  cross-client `IsoObject` replication, normal streamed-in walking without the
  QA viewpoint fixture, native server-body reannouncement, richer item metadata
  and offline household routines remain open gates.

## v1.19 native furnishing packet diagnosis

- The QA client now records both the broad `getObjectListForLua()` scan and the
  authoritative home square's native `IsoGridSquare:getObjects()` list. The
  former omitted tile objects in the v1.18 run, so
  `productionHouseholdFurnishings=0` was an instrumentation blind spot rather
  than proof that the packet was absent.
- A fresh hands-free run records one `NeighborhoodHouseholdStorage` object with
  `NeighborhoodHouseholdFurnishing=storage` on both host and guest after the
  shared home tile loads. The client fallback still covers the guest's
  transient partial or unloaded packet state and clears its pending entry after
  local creation.
- Re-sending an existing native object on every household action was tested and
  produced duplicate client tile objects, so the server transmits only on
  creation. Normal streamed-in walking without the QA viewpoint fixture, native
  server-body reannouncement, richer item metadata and offline household
  routines remain open gates.

## v1.20 tiny plumbob placement

- The production client marker is now an 8x11 panel with a 56-pixel lift. The
  faceted gem remains above the character model while occupying much less
  screen space and sitting closer to the model.
- The isolated Build 42.20.4 engine logged `size=8x11` for the real player and
  retained anchored plumbobs for Marisol, Kenji and Amara. This is actual
  single-player engine evidence for presentation, not proof of native remote
  player-body replication.

## v1.21 authoritative remote-player body fallback

- Production clients now consume the existing authoritative `presence` roster
  through `NLRemotePlayerClient`. If Build 42 exposes a native peer,
  presentation continues to use that engine body. If the peer disappears from
  `getOnlinePlayers()`, the client creates one local native `IsoPlayer` replica,
  tags it as `NeighborhoodRemotePlayerId`, drives it toward revisioned server
  coordinates with the native path frame and bounded interpolation fallback,
  and removes it when the roster disappears.
- The replica never accepts client-supplied identity or coordinates and never
  enters the production package as a server authority. The marker-only
  presence plumbob remains available while the local body fills the engine
  enumeration gap.
- `tests/remote-player-client.lua` covers fallback creation, authoritative
  movement, promotion to a real native body, stale revision rejection and
  cleanup. The latest hands-free two-client run also retained the native
  `nl-host`/`nl-guest` bodies in both clients across repeated scans; it did not
  naturally enter the missing-peer fallback branch, so that branch is not
  claimed as actual multiplayer evidence yet.

## v1.22 extra-small plumbob placement

- The production marker is now a 5x8 panel with a 42-pixel world-to-screen
  lift. This presentation-only reduction keeps the faceted gem directly above
  the character model without dominating the surrounding scene.
- The Lua/Kahlua suite verifies the new dimensions and anchor calculation. A
  fresh hands-free isolated launcher run reached the game state but did not
  emit the marker assertion before the disposable process was stopped, so this
  change is not overstated as a fresh actual-game screenshot.

## v1.23 multi-step NPC conversation evidence

- The QA-only hands-free client stimulus now waits through the production
  social cooldown and repositions only the isolated QA viewpoint when the
  moving target changes squares. It never changes production authority or
  sends client coordinates as social state.
- `evidence/v42/` records a real Build 42.20.4 dedicated server, `nl-host`,
  and `nl-guest`. The host received `chat` from Marisol, advanced friendship
  from 18 to 24 and trust from 5 to 11, then received `joke` and advanced
  friendship to 28. The production server logged both authoritative commands
  and responses; the host then continued into the existing career pickup,
  delivery, household invite, shared storage and tidy sequence.
- The guest remained connected and received the independent authoritative
  presence, NPC and household snapshots, while its social probe stayed
  refresh-only. This proves a multi-step conversation inside a real two-client
  session, not two-player social state mutation; direct cross-account
  conversation synchronization remains open.

## v1.24 replicated social event feed

- Production `NLSocialAuthority` now broadcasts only successful interaction
  events to every online client. Each event carries the authoritative actor,
  NPC, action and dialogue text, but never exposes another player's private
  friendship, trust or attraction values.
- `NLSocialClient` keeps a bounded twenty-event feed, clears it on disconnect
  and menu entry, and the Relationships panel shows the latest shared event.
  `tests/social-events.lua` covers receipt, bounded history and cleanup; the
  engine-VM suite passes the same client implementation.
- `evidence/v43/` records the real host+guest run: the host completed `chat`
  and `joke`, the server logged both authoritative commands, and the guest
  received `SOCIAL EVENT` packets for both actions. The host then completed
  the existing career and household loop. This proves cross-client social
  event replication, not shared private relationship mutation.

## v1.46 smaller, closer plumbob placement

- The production marker keeps the 8x11 source and 2x3 runtime panel but lowers
  the world-to-screen lift from 10px to 8px, placing the tiny gem closer above
  the model. The stale isolated profile copy was replaced with the current
  production mod so the live test uses the same asset.
- The hands-free Build 42 host and guest run logged `PLUMBOB SIZE:
  player:0=2x3 texture=8x11` on both clients and retained the three production
  NPC replicas. This confirms the runtime dimensions and host/guest loading, not
  native NPC reannouncement or full multiplayer completion.

## v1.47 server-authoritative zombie danger handling

- Production NPC authority scans the loaded Build 42 server cell for living
  zombies within four tiles. A nearby threat cancels the current native route,
  pauses when no safe tile is available, or applies a bounded retreat to a
  walkable square and persists the resulting position.
- `evidence/v68/` records a real isolated hands-free host-plus-guest run. The
  QA-only server bridge seeded one real zombie through the vanilla
  `addZombiesInOutfit` API, logged `NLQA DANGER PROBE: ok=true count=1`, and
  recorded production danger events for Marisol, Kenji and Amara while both
  clients remained connected with three native NPC replicas.
- The same run's pre-probe phase logged zero production danger events while
  both clients already had three native NPC replicas and native paths. This
  proves the no-nearby-zombie behavior in the same session; it is not evidence
  of a separate sandbox population-setting toggle.
- Unit and installed-game Kahlua tests cover collection adapters, threat
  filtering, bounded retreat and route pausing. These remain separate from the
  actual gameplay evidence. Full optional-zombies behavior with the feature
  disabled and enabled, including longer-lived world interactions, remains
  open.

## v1.54 appearance profile and two-client customization

- Production profiles now store a validated appearance preset id. The Looks
  panel offers Natural, Bob cut, Braided and Short, mapped to hair styles
  already shipped by Build 42. The server increments the profile revision and
  returns the choice in the private snapshot; each client applies the gendered
  style through native `HumanVisual` and refreshes the model.
- `tests/appearance.lua` covers server validation, persistence, snapshot
  delivery and native-shaped visual application. `tests/appearance-panel.lua`
  covers the panel callbacks and dead-state gate. Lua 5.1 and installed-game
  Kahlua runs pass; these are mock/engine-VM evidence, not multiplayer proof.
- `evidence/v75/` records an actual hands-free Build 42.20.4 host+guest run.
  The host selected `bob` and logged `hair=Bob`; the guest selected `braided`
  and logged `hair=Braids`, each through the production command and its own
  revisioned snapshot. A complete creator, richer preferences and original
  hair/assets remain open.

## v1.55 saved-outfit replacement queue

- `NeighborhoodLife/42/media/lua/client/NL/Wardrobe.lua` now compares the saved
  slot with the player's currently worn items before resolving inventory items.
  Matching exact ids or legacy full types are retained; every other worn item is
  queued through vanilla `ISUnequipAction`, followed by the saved garments through
  `ISWearClothing`.
- `tests/wardrobe.lua` covers replacement removal, exact identity, fallback,
  legacy slots and duplicate exclusion. Both Lua 5.1 and the installed Build
  42.20.4 Kahlua VM pass. These are mock/VM classifications, not actual gameplay
  evidence for automatic unrelated-layer removal.
- The prior `evidence/v49/` live replacement capture remains valid for final
  production wear after an explicit vanilla unequip, but does not close the new
  automatic-removal gameplay gate.

## v1.56 actual automatic wardrobe-layer removal

- The QA-only server seeds `Base.Hat_Cowboy` only after the authoritative outfit
  snapshot is saved. The connected host acquires and wears it, then calls the
  production `NLWardrobe.wear` function without QA-side unequipping of that hat.
- `evidence/v77/actual-gameplay-probes.txt` records the actual Build 42.20.4
  result: `extraBefore=1`, production replacement restores the saved shirt and
  trousers, and `WARDROBE AUTOMATIC LAYER REMOVAL` records `before=1 after=0`.
  The host and guest were both connected, and the server log records the extra
  world seed. This closes the live automatic-removal gate; the QA helper remains
  outside the production package.

## v1.57 native NPC online-id promotion hint

- Server `npc_presence` entries now include `onlineId` when Build 42 exposes a
  valid native `IsoPlayer` online id. The client checks that hint while scanning
  the loaded cell and uses it to promote a native body when persistent NPC
  ModData is not available yet.
- `tests/npc-client.lua` covers promotion from the online-id hint, while the
  full Lua 5.1 and installed-game Kahlua pipelines cover the production packet
  shape and loaded-cell lifecycle. This is contract/VM evidence, not proof that
  the dedicated server has begun reannouncing NPC bodies.

## v1.58 versioned multiplayer evidence tooling

- `tools/launch-multiplayer-qa.ps1` now accepts `EvidenceRoot`, keeping a
  disposable run's host, guest and server evidence separate from earlier
  versions.
- The QA-only `npc_presence` logger records valid `onlineId` hint counts and
  raw packet values. QA remains outside the production package.
- `evidence/v79/actual/` records a real host-plus-guest Build 42.20.4 run:
  both clients connected, the server sent three moving NPC rows with
  `onlineHints=3`, the host natural walk reached `playerDelta=12.34`, and the
  forced streamed-body probe recovered a fresh body. The raw hints were all
  `online=1`, so this actual run exposed a duplicate-identity defect rather
  than proving native server-body reannouncement.

## v1.59 duplicate native online-id handling

- The server suppresses an `onlineId` hint when more than one authoritative NPC
  body reports the same Build 42 value. The client independently rejects a
  duplicate hint during both packet promotion and loaded-cell reconciliation.
- `tests/replication.lua` covers packet suppression and `tests/npc-client.lua`
  covers refusal to promote an arbitrary body. The full Lua/Kahlua regression
  suite passes. Actual v79 evidence remains valid for connected host/guest NPC
  presence, movement, and forced streamed-body recovery, while native
  server-body reannouncement remains open because `GameServer=nil`.

## v1.60 stable authored native online-id slots

- The three authored neighbors now carry stable slots `30001`, `30002` and
  `30003` in persistent neighborhood rows. Server-created native bodies receive
  the slot through Build 42's public `IsoPlayer:setOnlineID(short)` method, and
  client compatibility replicas apply the same hint before they enter the
  loaded-cell scan.
- `tests/neighbors.lua`, `tests/npc-authority.lua` and `tests/npc-client.lua`
  cover the persisted row, server body and client replica contracts. This is
  identity groundwork for native reannouncement. The actual v81 probe reached
  both clients and rendered all three NPC rows, but reported `onlineHints=0`,
  so the dedicated server has not yet exposed an effective runtime setter or
  the `GameServer` bridge for sending native bodies.

## v1.61 runtime online-id setter probe

- The server adapter now tries both the public `IsoPlayer:setOnlineID(short)`
  method and the public `onlineId` field, then accepts the identity only after a
  getter round-trip. The v82 actual run logged `onlineId=1 assigned=false` for
  all three native bodies and `onlineHints=0`.
- This narrows the native replication blocker to the installed dedicated-server
  Kahlua bridge: `GameServer=nil`, `getClass=nil`, `Java=nil`, and neither setter
  route changed the native getter. The compatibility replica path remains an
  actual host+guest result; native server-body reannouncement is still open.

## v1.68 career delivery journal

- `NLAuthority.delivery` now records a before-image for the player's
  unequipped main-inventory count and the career profile before applying a
  delivery. It also stores a deterministic expected profile after-image, so a
  server restart can distinguish a completed award from a player-only removal.
- The next authoritative command repairs a persisted `player-applied` half
  state by restoring the missing inventory items and profile fields, then
  clears the journal. The recovery state travels in the private snapshot for
  the QA assertion without changing client-supplied identity handling.
- Mock/unit evidence: `lua tests/gameplay.lua NeighborhoodLife` passed 31
  assertions, including a forced player-applied delivery and refresh repair.
  Engine-VM evidence: the consolidated pipeline passed its installed-game
  Kahlua suite. Actual gameplay evidence: `evidence/v98/actual/delivery-crash-f/`
  records a real server stop after `NLQA DELIVERY JOURNAL PARTIAL`, restart,
  fresh host+guest reconnect, `state=repaired`, and a real host inventory count
  of nine sheets, including the eight restored delivery items.
- This milestone does not close native NPC server-body reannouncement,
  naturally missing-peer NPC movement, broader global-data crash atomicity, or
  the remaining neighborhood vertical-slice breadth.
