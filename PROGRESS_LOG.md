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





---

## Master Feature Completion Roadmap

| Feature Area | Current State | Target for Feature Complete & Polished |
|---|---|---|
| **Native NPCs** | Authored bodies spawn as native IsoPlayers with routines, detours, and motion sync. | Native body persistence verified across dedicated server restart. Natural cell streaming resilience. |
| **Careers & Economy** | Tailor, Carpenter, Medic ranks 1-4, daily requests, daily shifts. | Community credit shop catalog to purchase rare goods, recipes, and furniture; career rank perk unlocks. |
| **Social & Romance** | Dialogue, dates, pacing, friendship/trust/attraction, world-object menu. | Gift giving with preferences; partnership proposal/acceptance; apology & breakup flow; diverse date activities. |
| **Household Life** | Home claiming, invites, member storage transfer with full item metadata. | Household chores/routines (cooking together, relaxing); multi-stage household aspirations with titles. |
| **Needs HUD & Plumbob** | 6 adverse stat bars, plumbob diamond above head, fold toggle. | UI resolution scaling (1080p-4K), accessibility tooltips, smooth plumbob tracking. |
| **Multiplayer Stability** | Atomic journals for inventory & world mutations; 2-client test matrix. | 100% clean test passes on Kahlua VM + clean packaging with zero QA leakage. |

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
