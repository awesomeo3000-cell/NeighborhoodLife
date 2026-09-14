# Neighborhood Life — full scope and evidence ledger

Target: Project Zomboid **42.20.4**, confirmed in the isolated game window.
Host/invite multiplayer is a release requirement, not an optional add-on.
The original broad goal remains active. This ledger is not a reduced definition of done.

| Requirement | Current implementation | Completion evidence still required |
|---|---|---|
| Sims-inspired HUD | Six live adverse-stat bars, fold control, career journal link | Actual host+guest independent values; resolution and accessibility polish |
| Character markers | Production client plumbob asset and world-to-screen panel for active characters; native remote-player discovery now attaches markers when Build 42 exposes a body | Stable two-way remote-character markers and NPC marker after replicated bodies exist |
| Careers | Tailor, carpenter, medic; four ranks; daily supply requests; actual skill gates; account/world persistence; v1.8 real host delivery consumed six authoritative `Base.RippedSheets` and returned XP/credits | Client-acquisition inventory sync, rank/restart tests, richer work beyond deliveries, rewards and balance |
| Customization | Existing vanilla appearance retained | Expanded creator, preference/profile UI, appearance presets, original additional hair/assets |
| Clothing options | Three saved outfit-layer slots; vanilla wear actions; light-themed wardrobe panel reachable from HUD | In-game panel rendering and preset save/load/reconnect test; new garment variants, original assets, unlock/reward integration |
| Persistent neighborhood NPCs | Production `NpcAuthority` creates all three authored vertical-slice neighbors (Marisol, Kenji and Amara) as native `IsoPlayer` bodies, gives each identity/outfit data and a persisted nearby route, restores the exact fractional position across a dedicated-server restart, sends immediate and periodic `npc_presence` from a dedicated server, and production clients render named revision-checked native replicas with plumbobs and disconnect/menu cleanup; QA remains the observer and launcher helper | Native Build 42 body reannouncement to the engine's native player list, verified same-client reconnect, obstacle/danger handling, damage/death and offscreen behavior |
| NPC interaction | Server proximity/floor/visibility gates and personality-based dialogue implemented for all three native bodies; v1.7 hands-free host introduced Marisol through the production command and guest received an independent proximity-gated snapshot | Multi-step two-client conversations, richer world actions and inventory exchange |
| Relationships and romance | Per-player friendship/trust/attraction, bounded memories, pacing, dates and exclusive partnerships implemented; Sims-inspired panel; v1.7 actual host relation mutation and guest isolation evidence | In-world UI/interaction checks, richer date activities and two-client synchronization |
| Household life | Not implemented | Homes, responsibilities, inventory rules, membership and co-op routines |
| Aspirations and home activities | Not implemented | Goals, progress/rewards, hobbies and functional furnishings |
| Zombies optional | Careers have no kill requirements | Test same full loop with zombies disabled and enabled |
| Host multiplayer | Server command adapter, private snapshots, authoritative player/NPC presence broadcasts, immediate refresh state, production client heartbeat, stale-packet rejection, dedicated-server NPC restart persistence, three named NPC replicas, host social mutation, guest isolation, server-authoritative career delivery and disconnect-clean local native NPC replicas; v0.7/v0.9/v1.0/v1.2/v1.3/v1.4/v1.5/v1.6/v1.7/v1.8 real host plus guest evidence | Verified same-client reconnect after a server restart, client-acquisition inventory sync, simultaneous gameplay beyond the tested delivery, mod distribution, native body reannouncement, stable two-way native remote movement and replicated-character UI |
| Verification on this machine | Lua 5.1 tests; installed-game Kahlua harness; isolated real PZ profile | Broader world/inventory/NPC/host integration tests and regression suite |

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
- Duplicate packets do not reward twice during a running server. Crash-atomic inventory
  and global-data commits are NOT yet proven and must be investigated before release.
- Careers persist per account per world, including after a survivor dies.
- Community credits are currently a ledger, not yet spendable currency.
- Saved outfits currently add/equip layers; they do not remove unrelated worn layers.
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

1. Real-world career/wardrobe tests; preserve and reload the isolated save.
2. Actual two-client Host adapter tests and inventory synchronization.
3. NPC body/movement/network experiment in the isolated world, then persistent neighbors.
4. Integrate conversations, relationships, romance and neighborhood careers.
5. Expand appearance/clothing assets, households, aspirations, furnishings and UI polish.

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
- Native Build 42 body reannouncement, same-client reconnect, inventory/action
  delivery, obstacle/danger handling, damage/death, offscreen behavior and
  households remain open gates.

## v1.5 disconnect cleanup evidence

- Production `NLNpcClient` now registers cleanup for both `OnDisconnect` and
  `OnMainMenuEnter`; cleanup removes local native bodies and plumbobs and resets
  the accepted packet revision before a later connection.
- `tests/npc-client.lua` invokes the registered disconnect callback and verifies
  the reset. This is a Lua native-shaped contract test, not multiplayer evidence.
- The hands-free forced-server-stop probe is recorded in `evidence/v22/`. Build
  42 did not emit a client `OnDisconnect` transition during that probe, so a
  real same-client reconnect is still unverified rather than claimed complete.

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
- Native Build 42 body reannouncement, same-client reconnect, inventory/action
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
- Multi-step conversations, richer world actions, inventory exchange, native
  reannouncement and same-client reconnect remain open.

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
