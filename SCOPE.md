# Neighborhood Life — full scope and evidence ledger

Target: Project Zomboid **42.20.4**, confirmed in the isolated game window.
Host/invite multiplayer is a release requirement, not an optional add-on.
The original broad goal remains active. This ledger is not a reduced definition of done.

| Requirement | Current implementation | Completion evidence still required |
|---|---|---|
| Sims-inspired HUD | Six live adverse-stat bars, fold control, career journal link | Actual host+guest independent values; resolution and accessibility polish |
| Character markers | Production client plumbob asset and world-to-screen panel for active characters; adapter ready for authoritative NPC bodies | Two-client remote-character marker and NPC marker after replicated bodies exist |
| Careers | Tailor, carpenter, medic; four ranks; daily supply requests; actual skill gates; account/world persistence | Actual multiplayer inventory sync, rank/restart tests, richer work beyond deliveries, rewards and balance |
| Customization | Existing vanilla appearance retained | Expanded creator, preference/profile UI, appearance presets, original additional hair/assets |
| Clothing options | Three saved outfit-layer slots; vanilla wear actions; light-themed wardrobe panel reachable from HUD | In-game panel rendering and preset save/load/reconnect test; new garment variants, original assets, unlock/reward integration |
| Persistent neighborhood NPCs | QA-only humanoid body renders and path-follows a three-waypoint route in isolated single-player when the probe emulates the engine frame; no production spawner | Obstacle handling, two-client replication, persistence, damage/death and offscreen behavior; production server-side ticking |
| NPC interaction | Server proximity/floor/visibility gates and personality-based dialogue implemented; bodies supplied by adapter | Actual world-body integration and two-client conversations |
| Relationships and romance | Per-player friendship/trust/attraction, bounded memories, pacing, dates and exclusive partnerships implemented; Sims-inspired panel | In-world UI/interaction checks, richer date activities and two-client synchronization |
| Household life | Not implemented | Homes, responsibilities, inventory rules, membership and co-op routines |
| Aspirations and home activities | Not implemented | Goals, progress/rewards, hobbies and functional furnishings |
| Zombies optional | Careers have no kill requirements | Test same full loop with zombies disabled and enabled |
| Host multiplayer | Server command adapter and private snapshots implemented; v0.7 real host plus guest refresh loop recorded | Reconnect, simultaneous gameplay/inventory delivery, restart, mod distribution, remote movement and replicated-character UI |
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
