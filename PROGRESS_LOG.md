# Neighborhood Life — Progress & Handoff Log

This document tracks the ongoing status, completed engineering gates, architecture decisions, and remaining roadmap for **Neighborhood Life** (Project Zomboid Build 42.20.4).
Any developer or AI agent picking up this project can review this file to immediately understand the exact state of the codebase.

---

## Mod Architecture & Invariants

1. **Target Engine**: Project Zomboid **Build 42.20.4** (`CharacterStat` API, Steam build ID 24909800).
2. **Multiplayer Authority**: Dedicated server and host/invite multiplayer is a hard requirement.
   - All character identities, inventory transfers, relationship snapshots, career promotions, and world mutations are strictly server-authoritative.
   - Client Lua only sends commands via `sendClientCommand` and receives authoritative updates via `sendServerCommand`.
3. **Packaging Boundary**:
   - The production mod lives entirely within [`NeighborhoodLife/`](file:///e:/pzmod/NeighborhoodLife).
   - Test suites ([`tests/`](file:///e:/pzmod/tests)), QA mod ([`qa/NeighborhoodQA`](file:///e:/pzmod/qa/NeighborhoodQA)), launchers ([`tools/`](file:///e:/pzmod/tools)), and disposable profiles ([`test-profile*`](file:///e:/pzmod)) are strictly excluded from production distributions.
   - Verification is governed by `tools/pipeline.py test` (Lua 5.1 syntax + Game Kahlua VM).

---

## Log of Progress & Milestones

### Pre-v2.00 Milestones (Completed & Documented in SCOPE.md)
- **v1.95**: Global ModData mutation journaling before profile, household, and social writes.
- **v1.96**: Dedicated server crash recovery verified for shared world ModData mutations.
- **v1.97**: Richer social action slice (`ask_work`, `talk_home`, `compliment`, personality responses, replicated events).
- **v1.98**: Server-clock driven home/work routines for authored NPCs (Marisol, Kenji, Amara) navigating between homes and career locations.
- **v1.99**: Typed native NPC bridge (`NLNativeNpcBridge`, `NLNativeNpcPositionSync`, `NLNativeOnlineIdSetter`). Verified 3-body native roster and authoritative movement in `evidence/v140/actual/native-bridge-motion-3/`.

- **v141 (v2.00 Milestone)**: **Native NPC Restart Persistence Gate CLOSED**.
  - Verified hands-free host-plus-guest Build 42.20.4 run in `evidence/v141/actual/native-persistence/`.
  - Authoritative Marisol position before restart: `8472.84, 11556.24`.
  - Dedicated server stopped, restarted with typed bridge active.
  - Authoritative Marisol position after restart: `8472.84, 11556.24` (`delta = 0.00`).
  - Both host and guest reconnected and observed the full engine native player roster (`source=engine-online-players`).
  - Resolved drive-letter case-sensitivity check in `HandsFreeQA.java` / `NativeBridgeQA.java` and array string argument formatting in `tools/run-native-bridge-persistence-qa.ps1`.

- **Phase 2 (Completed)**: **Economy & Community Rewards Store**.
  - Added 14 spendable community rewards catalog in `Definitions.lua` (`supplies`, `medical`, `tailoring`, `carpentry`, `books`).
  - Implemented authoritative `NLDomain.purchase` and `NLAuthority.purchaseReward` with credit validation, inventory addition, and transaction journaling.
  - Added dedicated tab "Community Rewards" to player Journal UI with pagination, credit balance check, and one-click purchasing.
  - Added unit test suite in `tests/gameplay.lua`.
  - 100% test pass on Lua 5.1 and B42.20.4 Kahlua VM.

- **Phase 3 (Completed)**: **Social & Romance Breadth**.
  - Added favorite gift catalogs to `Social.lua` for Marisol (tailoring goods/textiles), Kenji (tools/timber/glue), and Amara (medical supplies/books).
  - Implemented `NLSocial.isFavorite` and `NLSocial.giveGift` with custom appreciative dialogue lines, bonus relationship gains (+6 friendship, +4 trust, +3 attraction), and memory journaling.
  - Wired gift giving reaction into `SocialAuthority.command('NeighborhoodSocial', 'give')` so giving items authoritatively triggers character responses and relationship progression.
  - Expanded `Relationships.lua` with the full action suite (14 actions including `ask_work`, `talk_home`, `compliment`, `apologize`), context-aware button states, and `(Fav!)` gift indicators.
  - Added unit test suites in `tests/social.lua` and `tests/social-authority.lua`.
  - 100% test pass on Lua 5.1 and B42.20.4 Kahlua VM.

- **Phase 4 (Completed)**: **Household Life & Shared Progression**.
  - Expanded shared household routine tasks in `Households.lua` to include `relax` ("Relax together at home") and `repair` ("Maintain home fixtures").
  - Extended multi-stage home aspirations in `Aspirations.lua` from 3 to 5 progression milestones: "First Nest", "Shared Routine", "Household Heart", "Sanctuary Keepers", and "Utopian Homestead" (with up to +50 credit rewards).
  - Updated `HouseholdPanel.lua` UI with 2-row clean action grid, home aspiration milestone tracker, and dynamic activity tally.
  - Added test coverage in `tests/households.lua`.
  - 100% test pass on Lua 5.1 and B42.20.4 Kahlua VM.

- **Phase 5 (Completed)**: **HUD & Accessibility Polish**.
  - Added dynamic resolution scaling to `NeighborhoodNeeds.lua` supporting viewports from 720p/1080p up to 1440p and 4K (`uiScale = width / 1920` clamped).
  - Added accessibility status hints `(Low)`, `(Med)`, `(High)` next to percentages to clarify adverse intensity.
  - Added test coverage in `tests/hud.lua` verifying 2560px screen width scaling.
  - 100% test pass on Lua 5.1 and B42.20.4 Kahlua VM.

- **Phase 6 (Completed)**: **In-Game Singleplayer Engine Verification & NPC Spawning Fix**.
  - **Root Cause & Fix for In-Game NPC Spawning**:
    - Removed non-existent `addToWorld()` call on `IsoPlayer` (Build 42.20.4 bytecode verified); replaced with `cell:addMovingObject(body)` and `body:setMovingSquareNow()`.
    - Fixed ground floor detection so outdoor grass/dirt tiles at level 0 are accepted as valid spawn locations.
    - Switched `IsoCell.getObjectList()` (Java `Set`) to `getObjectListForLua()` (Java `List`) in body lookup.
    - Prevented premature `row.spawned = true` state mutation before body is successfully created.
    - Added simulation frame execution (`preupdate()`, `update()`, `behavior:update()`, `postupdate()`) and singleplayer tick delegation to `NLNpcAuthority.update()` so NPCs walk, animate, follow career schedules, and flee zombies.
  - **HUD & Interaction Polish**:
    - Ensured `NeighborhoodNeeds` HUD initializes on loaded games via `Events.OnGameStart` and tick watchdog; added periodic auto-retry for feature data sync until `DATA READY` is reached.
    - Updated `NpcInteractionMenu` to display friendly neighbor names (e.g. "Neighborhood: Marisol Vega") instead of raw IDs.
    - Added clear distance and proximity feedback in `Relationships` window instructing player when within 4 tiles to interact or right-click.
  - **Live Game Verification**:
    - Created `tools/run-singleplayer-qa.ps1` launching the real Build 42.20.4 engine (`javaw.exe`).
    - Verified 3 production NPC bodies spawned and persisted in-world (Marisol, Kenji, Amara).
- **Phase 7 (Completed)**: **In-Game 3D Mesh Visibility, Alpha Indexing & Plumbob Scale Fix**.
  - **Root Cause & Diagnosis for In-Game Invisibility**:
    - The debug log confirmed NPCs spawned into the world (`[NeighborhoodLife] NPC/SP ready: 3/3 NPCs registered in world`), but were visually invisible on screen due to two engine-level rendering guards.
    - **Alpha Indexing Bug**: `body:setAlphaAndTarget(1, 1)` set `alpha` for `playerIndex = 1` (splitscreen player 2). For local player 0, `alpha[0]` remained 0.0 (`isAlphaZero(0) == true`), causing `IsoGameCharacter.render` to immediately abort rendering the character. Fixed to set alpha = 1.0 across all player indices 0..3 and base alpha.
    - **ModelManager Timing Bug**: During `OnCreatePlayer`, `ModelManager.instance:isCreated()` is false (`GameLoadingState`). Attempts to attach 3D model slots silently fail, leaving `legsSprite.modelSlot` null. Added `ensureBodyRender()` running on `OnGameStart` and every tick, which detects uninitialized models and triggers `ModelManager.Add(body)` and `body:resetModel()`.
    - **Idle Animation Ticking**: Fixed idle bodies so `preupdate()`, `update()`, and `postupdate()` run continuously even without active pathfinding targets, keeping character animation and skeletal stances active.
    - **Plumbob Scale & Placement**: Increased `NLPlumbob` dimensions from 2x3 pixels with 8px lift to 12x16 pixels with 64px lift so the glowing diamond hovers visibly above neighbor heads on high-resolution displays (1080p/1440p).
  - **Live Game Verification**:
    - Ran live Build 42.20.4 client engine test (`tools/run-singleplayer-qa.ps1`).
    - Both `legsSprite:hasActiveModel()` and `body:getAlpha(0) > 0.5` asserted and passed.

- **Phase 8 (Completed)**: **In-Game 3D Mesh Visibility, ModelManager Slot Binding & Engine Stability**.
  - **Root Cause & Diagnosis for In-Game Invisibility & Entity Stability**:
    - Build 42's `ModelManager` creates 3D model slots (`legsSprite.modelSlot`), animation skeletons, outfits, and bone hierarchies only when `ModelManager.instance:Add(character)` is called after `ModelManager.instance:isCreated()` returns true.
    - Because NPCs spawn before the loading state finishes `ModelManager.create()`, calling `resetModel()` alone was a silent no-op (the engine's `ModelManager.Reset()` explicitly returns early if `modelSlot` is null).
    - `IsoSurvivor` is incompatible with Build 42 because its `bodyDamage` field is permanently null, crashing the engine in `IsoCell.ProcessObjects` (`getBodyDamage().getNumPartsBleeding()`). In contrast, `IsoPlayer` has native `BodyDamage`, `Moodles`, `XP`, `Nutrition`, and `Fitness`.
    - Added automatic `ModelManager.instance:Add(body)` binding once `ModelManager.instance:isCreated()` is true, attached the moving squares to the grid via `setMovingSquareNow()`, marked `spottedByPlayer = true`, and added direct rendering through `Events.OnRender3D`.
  - **Live In-Engine Verification**:
    - Ran live Build 42.20.4 client engine test (`tools/run-singleplayer-qa.ps1`).
    - Verified all 3 production NPCs (Marisol, Kenji, Amara) spawned, persisted, and ticked with active 3D meshes in `2026-09-17_11-44_DebugLog.txt`.
    - Verified right-click interaction menus with 11 context actions, active Needs HUD panel, and plumbob tracking.
    - 100% test pass across 26 test suites on Lua 5.1 and Project Zomboid Kahlua VM.
    - Synchronized and verified production mod in `C:\Users\clare\Zomboid\mods\NeighborhoodLife`.

- **Phase 9 (Completed)**: **FBO World-Character Rendering for Locally Created IsoPlayer Bodies**.
  - **Root Cause & Fix for Remaining Invisibility**: Phase 8's `Events.OnRender3D` hook never ran because Build 42.20.4 does not expose that event (`Events.OnRender3D == nil`); the handler was dead code. Writing the model slot and alpha state alone is not enough.
  - Build 42 renders the world through FBO render chunks. `FBORenderCell.renderMovingObject(obj)` explicitly returns for any object whose exact class is `IsoPlayer`, and `FBORenderCell.renderPlayers()` only walks `IsoPlayer.players` / `GameClient.IDToPlayerMap`. Authored neighbors and presentation replicas are in neither roster, so their ModelManager model was active but never received an engine draw call.
  - Added `NL/NpcRender.lua`: it registers locally created `IsoPlayer` bodies and queues the same `body:render(x, y, z, squareLight, true, false, nil)` and `body:renderShadow(x, y, z)` calls the engine uses for its own players from `Events.OnPostRender` (a real world-render event).
  - Wired the single-player bridge (`NpcSinglePlayer.lua`), the NPC client replica path (`NpcClient.lua`) and the remote-player replica path (`RemotePlayerClient.lua`) into the registry, including native-body promotion and cleanup.
  - **Live In-Engine Verification**:
    - `tools/run-singleplayer-qa.ps1` passes and now also captures a world-view screenshot (`test-profile/Screenshots/NLQANPCVIEW`) with the UI hidden and the player teleported beside Marisol; the screenshot shows the NPC model rendered.
- **Phase 10 (Completed)**: **Fix Plumbob and Thought Bubble Overhead Placement in Build 42**.
  - **Root Cause Discovered**:
    1. In Project Zomboid's isometric camera engine, `Core.getZoom(playerIndex)` returns values where `zoom < 1.0` is zoomed IN (e.g. `0.25`, `0.5`, `0.75`), which draws characters larger on screen, and `zoom > 1.0` is zoomed OUT (e.g. `1.5`, `2.0`, `2.5`).
    2. Character screen height from feet (`isoToScreenY`) scales as `worldHeight / zoom`. To maintain correct overhead placement above the character's head across all zoom levels, world-to-screen lift must scale inversely as `1 / zoom`.
    3. `NLPlumbob.lua` and `NLThoughtBubble.lua` incorrectly multiplied by `zoom` rather than dividing by `zoom`. Furthermore, `baseLift` was set to only `64` for plumbobs and `82` for thought bubbles, which is far below human character height (~135-140 world px). When zoomed in (e.g. zoom 0.5), the lift shrank to ~32px, placing plumbobs directly at the ankles/feet.
  - **Fixes Applied**:
    1. `NeighborhoodLife/42/media/lua/client/NL/Plumbob.lua`: Increased `baseLift` to `150` and updated `positionOverCharacter()` to use `liftScale = 1 / zoom` with inverted size scaling (`sizeScale = math.max(0.75, math.min(1.5, 1 / zoom))`), placing the plumbob comfortably atop the character's head.
    2. `NeighborhoodLife/42/media/lua/client/NL/ThoughtBubble.lua`: Increased `LIFT` to `160` and updated `positionAll()` to use `liftScale = 1 / zoom` with inverted size scaling (`sizeScale = math.max(0.75, math.min(1.4, 1 / zoom))`), placing reaction bubbles atop the character's head.
    3. `tests/plumbob.lua` and `tests/thought-bubble.lua`: Updated unit tests to assert proper overhead lift and verified inverse zoom scaling at `zoom = 0.5`.
  - **Verification Completed**:
    - `python tools/pipeline.py test`: PASS (Lua 5.1 and Project Zomboid Kahlua VM).
    - `tools/run-singleplayer-qa.ps1`: PASS in live engine runtime.
    - Synchronized production mod to `C:\Users\clare\Zomboid\mods\NeighborhoodLife`.

---



## Master Feature Completion Roadmap

| Feature Area | Status | Verified Delivery |
|---|---|---|
| **Native NPCs** | **COMPLETE** | Native body persistence verified across dedicated server restart with delta=0.00 (`evidence/v141/actual/native-persistence/`). 3-body roster sync and motion verified. |
| **Careers & Economy** | **COMPLETE** | Tailor, Carpenter, Medic ranks 1-4, daily requests, daily shifts, and 14 spendable community reward purchases with dedicated Journal UI tab. |
| **Social & Romance** | **COMPLETE** | 14-action social suite (`introduce`, `chat`, `joke`, `ask_work`, `talk_home`, `compliment`, `flirt`, `date`, `date_activity`, `partner`, `breakup`, `apologize`, `give`, `request`), favorite gifts with character dialogues & bonuses, `(Fav!)` UI hint. |
| **Household Life** | **COMPLETE** | Home claiming, invites, transfer, shared storage with item metadata, 5 routine activities (`tidy`, `meal`, `social`, `relax`, `repair`), and 5-stage home aspirations ("First Nest" to "Utopian Homestead"). |
| **Needs HUD & Plumbob** | **COMPLETE** | 6 adverse stat bars with `(Low)`, `(Med)`, `(High)` accessibility status hints, dynamic resolution scaling (720p to 4K), plumbob tracking, and fold toggle. |
| **Multiplayer Stability** | **COMPLETE** | Dedicated server authority for all mutations, atomic inventory & world ModData journaling, 100% test pass on Lua 5.1 and B42.20.4 Kahlua VM, zero QA package leakage. |

---

## Handoff Instructions for Subsequent Agents

1. **Running Tests**:
   - Run standard pipeline test: `python tools/pipeline.py test`. Must pass both Lua 5.1 and Kahlua VM suites.
2. **Compiling QA Agents**:
   - Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-hands-free-qa.ps1`.
3. **Running QA Multiplayer Tests**:
   - Use PowerShell with `-ExecutionPolicy Bypass`. Ensure scripts call `powershell`, not `pwsh`.
4. **Mod Source Location**:
   - Never edit files in `evidence/` or disposable `test-profile/` directories.
   - All production mod edits go into `NeighborhoodLife/42/media/lua/...`.
