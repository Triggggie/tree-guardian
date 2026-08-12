# Tree Guardian — Current Project Status

Updated: 2026-08-12

Implementation parent for this checkpoint: `fd860d3` (`Add boss ability regression coverage`)

Checkpoint commit: `Update status after boss abilities`

Baseline branch: `main`

## 1. Project Snapshot

Tree Guardian is a playable 2D idle/tower-defense prototype built for Godot 4.7.1 with GDScript 2 and Forward Plus rendering. The project configuration declares Godot feature level 4.7, a 1920 × 1080 base viewport, and `res://scenes/main_world.tscn` as the main scene.

The current prototype has one central tree and four standard branch instances: Strength and Blossom on both the left and right sides. Stable identities are `standard_slot_1`, `standard_slot_2`, `standard_slot_3`, `standard_slot_4`, and `apex_slot`. Thorn Crown (`thorn_crown`) is the first production Legendary Branch: a Tier I, Apex-only bilateral area-damage Branch registered in `GameContent`. Global content, run, persistent Branch Seed, runtime loadout, and shared Branch progression services are provided by the `GameContent`, `TreeSouls`, `RunModifiers`, `BranchSeeds`, `BranchLoadout`, and `BranchProgress` autoloads.

This document describes the repository after the Boss Abilities V1 checkpoint built on the implementation parent above.

## 2. Current Playable Prototype

The main loop is functional:

- Bark Beetles are instantiated from registered Enemy, Stage, and Wave Resources. They spawn in lane-aware waves, move toward the tree, attack it, and grant Branch XP plus Forest Essence drops when defeated.
- Strength branches perform melee attacks; Blossom branches heal the tree and fire ranged petals.
- Branch XP increases Branch Level. XP, level, total Talent Points earned, and Essence-upgrade levels are shared by all runtime instances with the same stable `branch_id`. Purchased talents are independent for each `slot_id + branch_id` loadout.
- Forest Essence buys branch and tree upgrades. A shared Branch upgrade purchase is charged once and immediately updates every active instance of that archetype; mutable progress never resides in shared definition Resources.
- Age increases only after completing a new highest global wave. Replaying already completed waves after a death does not farm Age.
- Tree death stops the active combat cycle and opens a defeat panel. The player can retry immediately, or the tree revives automatically after a 10-second countdown. Retry now opens Preparation before restarting the current Substage at its Wave 1.
- Normal death preserves in-memory long-term run progression: Age, Forest Essence, Branch XP and levels, purchased branch upgrades and talents, tree upgrades, and the selected Tree Soul and rank.

The prototype has no general save/load system, so this preserved run state lasts only for the running game process. Unlocked legendary Branch Seed IDs are the isolated exception: `BranchSeeds` persists that meta-progression across sessions.

## 3. Branches

### Strength

Strength is a standard, close-range offensive branch using preferred-lane targeting with fallback behavior. Its base attack deals 10 damage with a 1.5-second cooldown; the runtime minimum cooldown remains 0.45 seconds.

Strength rendering is separated into the direct child node `StrengthBranchVisual`. The visual node owns the visual exports, growth formulas, and drawing, while `strength_branch.gd` continues to own combat orchestration, progression, and upgrades. The runtime synchronizes Branch Level, Tree growth factor, and facing direction to the visual node. Attack range uses the length provided by the visual node, and the attack tween still rotates the Strength root so the complete visual moves as before. No combat or balance values changed during this separation.

Its Resource-defined upgrades are ordered as follows:

| Upgrade | Effect per level | First cost | Maximum |
| --- | ---: | ---: | --- |
| Damage | +2.0 flat damage | 8 | Dynamic Branch Level limit |
| Attack Speed | -0.08 s attack cooldown | 10 | Dynamic Branch Level limit; runtime cooldown floor applies |
| Range | +15 attack range | 7 | 10 levels, also limited by Branch Level |

Strength has one Resource-defined talent tree with three Level 2, one-point talents:

- Crusher — Sweeping Strike: a second nearby target takes 60% damage.
- Warden — Rebuff: the struck enemy is pushed 35 units away from the tree.
- Duelist — Marked Prey: repeated hits on the same target gain up to five stacks, each adding 10% damage.

Purchased Strength talents now activate runtime behavior through `TalentDefinition.effect_ids`. `CombatBranch.get_active_talent_effect_ids()` reads the effect IDs of purchased talents in TalentTree Resource order, while `StrengthTalentEffectSet` dispatches the three Strength-specific runtime effects. Each Strength instance owns its own effect set and its own Marked Prey state; Resources continue to contain immutable content data only. The Strength root orchestrates the basic attack, and the effect set contributes talent behavior.

The current mapping is:

- `sweeping_strike` → `StrengthSweepingStrikeEffect`: second target, 60% damage, 120-unit search radius.
- `rebuff` → `StrengthRebuffEffect`: 35-unit knockback after a successfully resolved hit.
- `marked_prey` → `StrengthMarkedPreyEffect`: 10% damage per stack, up to five stacks.

### Blossom

Blossom is a standard support/ranged branch with its own scene. It heals the tree for 3 HP every 2.0 seconds and fires petals for 3 base damage every 2.0 seconds. Its targeting profile permits any lane.

Blossom rendering is separated into the direct child node `BlossomBranchVisual`. The visual node owns the exported dimensions, growth formula, flower count, and drawing, while `blossom_branch.gd` continues to own healing, projectile combat, targeting, upgrades, and combat orchestration. The runtime synchronizes Branch Level, Tree growth factor, and facing direction to the visual node and delegates growth progress, length, and thickness to it. Projectile spawning uses the length provided by the visual node, while ranged-attack feedback still tweens the Blossom root scale. No gameplay or balance values changed during this separation.

Each Blossom Branch uses its own runtime healing-effect ID in the form `blossom_healing_<instance_id>`. Reapplying healing from the same Blossom refreshes only its own effect, while multiple Blossom HoTs stack independently. Two base Blossom Branches therefore heal 6 HP together every 2.0 seconds.

Its Resource-defined upgrades are ordered as follows:

| Upgrade | Effect per level | First cost | Maximum |
| --- | ---: | ---: | --- |
| Healing per Tick | +1.0 healing | 9 | Dynamic Branch Level limit |
| Healing Speed | -0.10 s healing interval | 11 | 13 levels, also limited by Branch Level; 0.75 s runtime floor applies |
| Petal Damage | +1.0 flat damage | 8 | Dynamic Branch Level limit |

Blossom now has a Resource-defined TalentTree with three Level 2, one-point talents. Purchased talents activate runtime behavior only through `TalentDefinition.effect_ids`. Each Blossom instance owns its own `BlossomTalentEffectSet`, while the shared Resources retain immutable content data. The Blossom-specific dispatcher maps the active effect IDs as follows:

- `abundant_bloom` → `BlossomAbundantBloomEffect`: increases the final healing per tick by 50% after flat upgrades and healing-power calculation.
- `quickening_pollen` → `BlossomQuickeningPollenEffect`: reduces the calculated healing tick interval by 20% without bypassing the 0.75-second minimum.
- `twin_petals` → `BlossomTwinPetalsEffect`: launches a second projectile at another valid target for 60% of the current petal damage.

The two Strength instances share one Strength archetype progress record, and the two Blossom instances share one Blossom archetype progress record. Strength and Blossom remain isolated from one another. Each physical Node still owns its own visual, cooldown/timer position, target, projectile/tween state, and Branch-specific talent-effect dispatcher, so temporary combat state is never shared.

### Shared Branch Progression

`BranchProgressRecord` is the mutable in-memory record for one stable Branch archetype ID. It contains only shared Branch level, XP, total Talent Points earned, and upgrade levels. `BranchTalentLoadoutRecord` contains only `slot_id`, `branch_id`, and purchased talent IDs. Both provide validation and deep-copy APIs.

`BranchProgressService`, registered as the `BranchProgress` autoload after `BranchSeeds`, owns shared records by `branch_id` and talent loadouts by `slot_id + branch_id`. Each physical slot receives the complete Talent Point budget earned by its archetype; available points are derived as shared total earned minus the TalentDefinition costs purchased by that loadout. A loadout survives unregister/recreate and a temporary replacement by another archetype in the same slot.

Valid examples include `Slot 1 Strength -> Sweeping Strike` beside `Slot 3 Strength -> Rebuff`, and independent stored builds for `Slot 1 Strength` and `Slot 1 Blossom`. Runtime `TalentEffectSet` objects remain separate per physical instance.

This Branch progress is not yet stored on disk. Recreating a runtime Branch or MainWorld in the same process restores it, but exiting the application loses it. Talent-effect set objects remain separate per physical Strength or Blossom instance, and only purchased effect IDs are synchronized. Forest Essence is spent once by the authoritative upgrade transaction, even though all matching runtime instances receive the new level.

## 4. Content Resource Architecture

The project uses typed custom Resources for content data and Node scripts for mutable gameplay state. Current definition types include:

- `BranchDefinition`
- `UpgradeDefinition`
- `TalentDefinition`
- `TalentTreeDefinition`
- `TreeSoulDefinition` and `TreeSoulBonusDefinition`
- `EnemyDefinition`
- `BranchSeedLootEntryDefinition`
- `BranchSeedLootPoolDefinition`
- `WaveEnemyEntryDefinition`
- `WaveDefinition`
- `SubstageWaveScheduleEntryDefinition`
- `SubstageWaveScheduleDefinition`
- `SubstageDefinition`
- `StageDefinition`
- `StatusEffectDefinition`
- `TargetingProfile`

The current authored content includes two standard BranchDefinition Resources, four EnemyDefinition Resources, one repeating StageDefinition, one empty Guardian Grove Branch Seed loot pool, one shared SubstageWaveScheduleDefinition, and the existing normal, mixed, miniboss, and boss WaveDefinition templates. Definitions own stable IDs, presentation text, ordered relationships, and balance values. Runtime nodes own mutable health, combat state, progression, and wave-cycle state.

Resource references use repository paths. New Godot UIDs must be generated by Godot rather than invented or handwritten.

`BranchDefinition.category_id` now classifies Branch content with the stable IDs `standard` and `legendary`; any other value makes the definition invalid. Strength and Blossom are explicitly standard. `BranchSlotRules` centralizes the five-slot layout: Slots 1–4 accept only standard Branch definitions, while Slot 5 is the Apex Slot and accepts only legendary definitions. `CombatBranch` validates this assignment during startup, disables combat for an invalid assignment, and refuses to resume it until the assignment is valid.

The Tree scene now contains the empty central marker `AttachmentPoints/Apex` at its authored position `(0, -95)`. The existing attachment-position storage and Tree growth scaling automatically include it. The Branch panel labels an empty Slot 5 as `APEX`, keeps it disabled, excludes invalid Branch/slot combinations, and can display a future valid legendary Branch without adding an inventory or equip flow.

Strength and Blossom are standard Tier 0 Branches and therefore expose an empty Tier display string. Legendary Branch definitions must use Tier I, II, or III; `BranchDefinition.get_legendary_tier_display_name()` is the single player-facing source for the exact labels `Tier I`, `Tier II`, and `Tier III`. Tier represents increasing general rarity, complexity, and potential, while remaining build-dependent and separate from ordinary equipment rarity. The API is ready for future Branch cards, seed notifications, Apex lists, TREE details, and found-versus-equipped comparisons, but no Tier UI exists yet.

`BranchSeedLootEntryDefinition` links a weighted legendary Branch to its stable ID and player-facing Tier. `BranchSeedLootPoolDefinition` belongs to a Stage and defines encounter Tier limits plus pity thresholds. Guardian Grove currently allows Tier I from both minibosses and bosses with thresholds 12, 18, and 24 for Tiers I, II, and III. Its entries array is intentionally empty, so no production Branch Seed can currently drop. The former `BranchSeedDropDefinition` and `EnemyDefinition.branch_seed_drops` architecture was removed.

`BranchSeeds` persists stable legendary Branch IDs plus independent Tier I, II, and III pity counters in `user://branch_seed_unlocks.cfg`, using ConfigFile version 2. Version 1 unlock-only files migrate by preserving de-duplicated non-empty IDs and initializing pity to zero. The highest eligible locked Tier allowed by the encounter is tried first, with fallback to the next lower Tier only after the higher Tier is exhausted. Bark Warden failures add one pity point and Ancient Bark Colossus failures add three; failed rolls clamp at the Stage threshold, and the next eligible encounter after reaching it is guaranteed. Unlock and pity reset save atomically before signals are emitted, with rollback on save failure.

`WaveDirector` writes the exact active `StageDefinition` into each typed `EnemySpawnRequest`; `SpawnDirector` supplies it through `configure_stage_context()` before the enemy enters combat. The shared Bark Beetle death path processes eligible Stage loot once after XP and Forest Essence rewards and before death feedback. Normal deaths, repeated `die()`, retry cleanup, and `queue_free()` without death do not roll loot. Bark Runner, Bark Warden, and Ancient Bark Colossus inherit this Stage-aware runtime.

### Enemy and Wave Architecture Checkpoint

Completed implementation-plan items:

- 18 — scene-local `EnemyTracker` with signal-based enemy-count tracking.
- 19 — scene-local `LaneRegistry` with side/lane scoped queues.
- 20 — removal of the normal O(N²) Bark Beetle queue-column lookup; the group scan remains only as a compatibility fallback.
- 21 — Bark Beetle split into reusable Health, Attack, and Movement components.
- 22 — Bark Beetle `EnemyDefinition` plus runtime configuration from registered data.
- 23 — spawn and wave orchestration split into `SpawnDirector` and `WaveDirector`.
- 24 — Stage/Wave Resource-driven runtime, including typed multi-request spawn batches.
- 25A — Stage/Substage/Wave hierarchy with 10 Substages, 100 Waves per Substage, and player-facing `X-Y-Z` progress codes.
- 25B — ordered per-enemy Wave entries with independent count, health, and damage scaling data.
- 25D — deterministic Substage Wave schedule.
- 25E1 — second real enemy: Bark Runner.
- 25E2 — first production Bark Beetle + Bark Runner mixed Waves.
- 40 — enemy runtime smoke test partially completed; it covers the current runtime foundation but is not yet a full combat-integration test scene.

Current runtime ownership:

- `EnemyTracker` owns the authoritative scene-local set of live enemies.
- `LaneRegistry` owns cached queue columns per formation side and lane.
- `EnemyHealthComponent`, `EnemyAttackComponent`, and `EnemyMovementComponent` own their isolated mechanics.
- `EnemySpawnRequest` is the typed, validated spawn-batch input.
- `SpawnDirector` owns instantiation, shared lane counters, queue order, cadence, and crowd formation.
- `WaveDirector` owns global wave/stage/substage state, Resource-driven scaling and timing, enemy waiting, and asynchronous cycle cancellation. Its `current_wave` and `highest_completed_wave` values remain global.
- `WaveManager` coordinates tree death, retry, enemy cleanup, Age side effects, and public UI signal relay.
- `EnemyDefinition`, `WaveDefinition`, `StageDefinition`, and `ContentRegistry` provide the registered data and lookups.

Current authored enemy/wave data:

- Enemy ID: `bark_beetle`.
- Enemy ID: `bark_runner`.
- Stage ID: `guardian_grove`.
- Wave template ID: `standard_bark_beetle`.
- Campaign is not implemented yet. The current `StageDefinition` requires exactly 10 Substages, each `SubstageDefinition` requires exactly 100 Waves, and one Stage therefore contains 1,000 Waves.
- `SubstageDefinition` no longer repeats `wave_patterns` with modulo. Each Substage uses one `SubstageWaveScheduleDefinition` containing ordered, one-based Wave ranges. A valid schedule must cover Waves 1–100 exactly, without gaps or overlaps, and lookup is fully deterministic.
- Guardian Grove has ten ordered Substage Resources. All ten currently share `guardian_grove_standard_schedule`.
- Player-facing progression uses `X-Y-Z` for Stage, Substage, and Wave within the Substage. Death restarts the current Substage, while `current_wave`, Age progression, and `highest_completed_wave` remain global.
- `WaveDefinition` owns ordered `enemy_entries`; their order defines deterministic spawn blocks. Each `WaveEnemyEntryDefinition` owns its stable `enemy_id`, base count per side, scaling start, count interval, count increase, maximum count, health multiplier, and damage multiplier.
- Enemy count, HP, and damage scaling use the Wave within the current Stage, from 1 through 1,000. When the prototype repeats Guardian Grove as the next numbered Stage, balance resets to Stage Wave 1 while Age and highest completion remain global.
- Spawn interval, completion-message duration, and time after each Wave remain Resource-driven.
- Bark Beetle has `maximum_health = 12`, `movement_speed = 120`, `attack_damage = 1.5`, `attack_interval = 1.5`, `attack_range = 130`, `essence_reward = 1`, and `experience_reward = 1`.
- Bark Runner is a faster, weaker basic melee enemy with `maximum_health = 7`, `movement_speed = 185`, `attack_damage = 0.75`, `attack_interval = 1.0`, `attack_range = 110`, `essence_reward = 1`, and `experience_reward = 1`.
- Bark Runner has its own scene and smaller, narrower orange-brown placeholder drawing. Its root script inherits the existing Bark Beetle runtime and overrides only `_draw()`, while the scene reuses the existing Health, Attack, and Movement components.
- Bark Runner is registered after Bark Beetle and is now used by production Guardian Grove Wave content.
- Bark Beetle and Bark Runner currently have empty `branch_seed_drops` arrays, so production gameplay does not yet award any Branch Seed.
- Guardian Grove replaced the same absolute HP addition for every enemy type with proportional scaling: maximum health gains 1.5% of base HP and damage gains 0.3% of base damage for each additional Stage Wave. Wave-entry multipliers are applied before the Stage multiplier, and maximum enemy health remains capped at 1,000,000.
- The scaling formulas are `base HP × Wave-entry HP multiplier × [1 + HP growth × (Stage Wave - 1)]` and `base damage × Wave-entry damage multiplier × [1 + damage growth × (Stage Wave - 1)]`.
- `WaveDirector.debug_start_global_wave` is a debug-build-only development tool for starting at any global Wave. A value of `0` preserves the normal start. A positive value is applied once without granting skipped rewards or changing Age, `highest_completed_wave`, or saved data; `main_world.tscn` has no stored override.

Guardian Grove uses this deterministic schedule in every Substage:

| Substage Waves | WaveDefinition ID |
| --- | --- |
| 1–10 | `standard_bark_beetle` |
| 11–19 | `bark_runner_intro` |
| 20 | `bark_beetle_runner_mixed` |
| 21–29 | `standard_bark_beetle` |
| 30 | `bark_beetle_runner_mixed` |
| 31–39 | `standard_bark_beetle` |
| 40 | `bark_runner_rush` |
| 41–49 | `standard_bark_beetle` |
| 50 | `bark_beetle_runner_mixed` |
| 51–59 | `standard_bark_beetle` |
| 60 | `bark_runner_rush` |
| 61–69 | `standard_bark_beetle` |
| 70 | `bark_beetle_runner_mixed` |
| 71–79 | `standard_bark_beetle` |
| 80 | `bark_runner_rush` |
| 81–89 | `standard_bark_beetle` |
| 90 | `bark_beetle_runner_mixed` |
| 91–99 | `standard_bark_beetle` |
| 100 | `guardian_grove_substage_finale` |

This is a 19-entry schedule that covers Waves 1–100 without gaps or overlaps. A special Wave occurs every 10 Waves, and Wave 100 is the Substage Finale. The mixed and finale Waves use ordered enemy entries: `bark_beetle`, then `bark_runner`. No random Wave or enemy selection was added.

## 5. ContentRegistry and GameContent

`resources/content_registry.tres` currently registers exactly two branches in UI/gameplay order—Strength then Blossom—four Tree Souls—Crimson, Azure, Golden, and Verdant—two enemies—Bark Beetle then Bark Runner—and one Guardian Grove Stage. The top-level status-effect list remains empty.

`ContentRegistry` rebuilds stable lookup indexes for top-level branch, Tree Soul, enemy, stage, and status-effect IDs. Nested content uses owner-scoped indexes:

- `branch_id + upgrade_id`
- `branch_id + talent_id`
- `stage_id + wave_id`

Talent tree IDs remain global. The first valid item wins when a duplicate is encountered during indexing. Dictionary indexes provide lookups, while ordered list APIs return the original Resource arrays so UI and gameplay order remains data-defined.

`GameContent` exposes explicit typed access to branches, upgrades, talent trees, talents, Tree Souls, enemies, stages, and waves. All five scheduled WaveDefinitions are indexed within Guardian Grove. Missing registry or unknown IDs safely return empty arrays or `null` as appropriate.

## 6. Content Validation

`ContentValidator` validates the original Resource arrays rather than relying only on indexes that retain the first duplicate. Current checks cover:

- top-level definition types, validity, empty IDs, and duplicate IDs;
- Branch scenes, targeting profiles, scoped upgrades, and upgrade validity;
- optional talent trees, globally stable talent tree IDs, scoped talents, prerequisites, conflicts, overlap between prerequisite/conflict IDs, and prerequisite cycles;
- Stage/Substage/Wave structure, exact hierarchy sizes, deterministic schedules, exact Wave 1–100 coverage without gaps or overlaps, scoped Substage and Wave IDs, ordered per-enemy entries, count-scaling fields, timing, and per-entry multiplier values;
- Wave-to-Enemy references and Enemy-to-immune-Status-Effect references;
- nested Branch Seed drop validity, per-enemy duplicate Branch IDs, and registered legendary Branch cross-references;
- deterministic de-duplication of identical validation messages while preserving order.

Null entries, empty IDs, missing references, invalid or mismatched count-scaling fields, duplicates, and prerequisite cycles are handled without relying on unsafe indexes. The current Godot 4.7.1 editor/import and runtime checks reported no ContentValidator errors.

## 7. Tree Souls

Tree Soul selection unlocks at Age 200. Rank 1 starts at Age 200, and each further rank requires 100 Age:

`rank = 1 + floor((age - 200) / 100)` for Age 200 or higher; otherwise Rank 0.

Selection opens automatically when it first becomes available. `CHOOSE LATER` hides it without selecting or activating a bonus and suppresses repeated automatic reopening during that run. The SOUL status panel can reopen the existing selection screen with `CHOOSE TREE SOUL`. Selection does not pause the SceneTree, and a selected Soul cannot be changed during the current run.

The four Souls and their modifier isolation are:

- Crimson: `branch_damage`; affects offensive Strength and Blossom branch damage, not healing.
- Azure: `attack_speed`; affects Strength attacks and Blossom petal firing, not Blossom healing ticks or unrelated timers.
- Golden: `essence_gain`; affects actual gameplay Essence rewards, not refunds, restoration, or debug grants.
- Verdant: `tree_max_health` plus percentage-of-maximum-HP `tree_regen_rate`; affects tree durability and regeneration.

No current Soul grants `healing_power`, so no Tree Soul directly increases Blossom healing amount. Rank growth has no hard maximum; growth after Rank 50 uses the configured 0.5 soft-cap multiplier.

The SOUL status panel draws a neutral gray orb glyph while no Soul is selected and recolors it after selection. That glyph is panel-local and the panel is hidden until the SOUL tab is opened; there is no separate always-visible world-space orb node at Age 1. Rank-up notifications are non-blocking, restart their approximately three-second display timer on another rank-up, and are not shown for initial Rank 1 selection.

Normal death does not clear the selected Soul or rank. `TreeSoulService` provides a prestige-clear method, but no player-facing prestige flow currently calls it.

## 8. Manual Test Status

### Shared Branch Progression Checkpoint

- Godot 4.7.1 headless editor/import passed without parser, Resource, ContentValidator, invalid-UID, orphan, or stack-trace errors.
- The shared Branch progress smoke test passed two consecutive runs against the real MainWorld, both Strength instances, both Blossom instances, their real Branch/TalentTree/Upgrade Resources, the `BranchProgressService`, and the Tree Forest Essence API.
- The regression suite confirmed shared XP, level, Talent Points, talents, and upgrade levels within each archetype; isolation between Strength and Blossom; one-time Forest Essence charging; higher follow-up costs; and restoration after MainWorld recreation in the same process.
- Strength and Blossom talent-effect smoke tests, Blossom healing-stack and both Branch visual smoke tests, the TALENTS UI test, Apex slot rules, Branch Seed loot, and enemy runtime tests passed. The shared-progress and TALENTS tests each passed twice.
- The production BRANCHES/TREE/SOUL/TALENTS layout was unchanged. Physical Branch visuals and talent-effect runtime objects remain per-instance.

The following evidence was supplied with this handoff from a manual Godot 4.7.1 run. It was not re-executed while creating this document:

- The project started without parser errors, missing Resources, or ContentValidator errors.
- Strength attacked; Blossom attacked and healed.
- Strength Damage cost 8 and changed damage from 10 to 12.
- Strength Attack Speed cost 10 and changed cooldown from 1.50 s to 1.42 s.
- Strength Range cost 7 and added 15 range.
- Blossom Healing per Tick cost 9 and changed one Blossom instance from 3 to 4.
- Blossom Petal Damage cost 8 and changed one Blossom instance from 3 to 4.
- With primary Strength damage at 12, Sweeping Strike dealt 7.2 secondary damage.
- Marked Prey repeated-hit damage progressed 10 → 11 → 12 → 13.
- All three Strength talents were purchasable.
- Death, revival, and stage restart at Wave 1 worked.

Manual-test limitations:

- Rebuff's visible knockback was not independently confirmed from the text log.
- The Range level-10 cap was not reached.
- The Healing Speed level-13 cap was not reached.
- Negative ContentValidator cases were not exercised in the editor.
- The game process was manually stopped at the end of the test.

### Approved Early-game Balance Playtest

The approved manual survivability playtest used two Strength Branches, two Blossom Branches, no upgrades, and a normal start from global Wave 1 (`debug_start_global_wave = 0`). The tree died on Wave 47. The intended no-upgrade early-game wall is approximately Waves 40–50, so this checkpoint meets its target.

### Enemy/Wave Regression Checkpoint

The user completed a visual Godot 4.7.1 regression pass and confirmed correct two-sided movement, lane ordering, non-overlapping queue columns, front-enemy-only attacks, promotion after a front enemy dies, HealthBar and death feedback, Wave Complete messaging, Game Over, and Retry. No visually apparent regression was found.

Automated regression evidence for this checkpoint:

- Godot 4.7.1 headless editor/import completed successfully.
- The final enemy runtime smoke test passed two consecutive runs without parser, Resource, ContentValidator, orphan, or stack-trace errors. Both runs covered `EnemyDefinition`, `StageDefinition`, `SubstageDefinition`, `WaveDefinition`, `WaveEnemyEntryDefinition`, `EnemySpawnRequest`, all three enemy components, `EnemyTracker`, `LaneRegistry`, and a two-request `SpawnDirector` fixture with 20 enemies and 20 unique side/lane/queue-order keys.
- Stage/Substage boundary mapping confirmed 10 Substages, 100 Waves per Substage, and 1,000 Waves per Stage. `X-Y-Z` mapping was checked across boundaries from `1-1-1` through `2-1-47`, including `1-10-100` and `2-1-1`.
- Wave enemy entry tests confirmed standard scaling at Stage Waves 1, 2, 3, 4, 6, 7, 100, and 1,000; delayed scaling beginning at Stage Wave 101; and negative fixtures for every entry validation rule.
- An in-memory multi-entry Wave test confirmed ordered IDs, independent counts and multipliers, total count, duplicate-ID rejection, and null-entry rejection without adding a second real enemy.
- Stage Wave scaling confirmed count/HP values of 2/30, 2/33, 2/36, 3/39, and 30/327 at Stage Waves 1, 2, 3, 4, and 100. Global Wave 1001 mapped to Stage 2 and reset balance to Stage Wave 1 at 2/30 while global progression state remained global.
- MainWorld progression confirmed `1-1-1` through `1-1-4`: 2/30 HP, 2/33 HP, 2/36 HP, and 3/39 HP per side respectively; Bark Beetle damage remained 5. Timing data remained 0.25 seconds between spawns, 0.7 seconds for the completion message, and 0.5 seconds after a Wave.
- A shutdown during active Wave `1-1-4` exited with code 0 without a late spawn, late attack, orphan warning, or SceneTree stack trace.
- The automated checkpoint did not visually verify the rendered `X-Y-Z` HUD; that remains a manual check.
- The Bark Runner smoke checkpoint verified its registered definition and exact stats, scene instantiation, shared Health/Attack/Movement components, EnemyTracker and LaneRegistry cleanup, and safe scene removal.
- At the Bark Runner checkpoint, a mixed `SpawnDirector` fixture spawned Bark Beetle followed by Bark Runner in one ordered batch: two instances of each type, four unique queue keys, and zero tracked enemies after cleanup. Production Wave Resources were introduced by the later 25D/25E2 checkpoint.
- The deterministic-schedule checkpoint passed two implementation smoke runs and one final regression run in Godot 4.7.1. All three exited with code 0 and printed `ENEMY RUNTIME SMOKE TEST PASS` without parser, Resource, ContentValidator, orphan, or stack-trace errors.
- Current schedule tests verify exactly 19 ordered entries, complete coverage of Waves 1–100, and `null` lookup results outside the valid range at Waves 0 and 101.
- All ten Guardian Grove Substages were verified to share the same schedule Resource and to resolve Standard, Runner Intro, Mixed, Runner Rush, and Finale Waves at their expected indexes.
- Current early-balance tests verify the authored Standard, Runner Intro, Mixed, Runner Rush, and Finale counts and a total of 508 spawned enemies across both sides through Wave 50.
- Negative schedule fixtures covered missing identity data, empty and null entries, invalid and reversed ranges, gaps, overlaps, entry ordering, incomplete endpoints, missing WaveDefinitions, and conflicting Wave Resources with the same Wave ID.
- MainWorld was not run for this checkpoint. Production Bark Runner and mixed-Wave presentation remains a later manual and visual verification task.

### Early-game Balance and Blossom Stacking Checkpoint

- Bark Beetle and Bark Runner base HP/damage, proportional Stage-Wave HP/damage growth, all 19 schedule entries, Wave timings, count continuity, debug-start mapping, mixed spawning, and cleanup passed two final enemy runtime smoke runs.
- Wave 31 diagnostic coverage confirmed 12 total Bark Beetles and reduced theoretical combined DPS from 18.40 to 13.08, approximately 28.9% lower.
- Blossom healing uses a per-instance runtime ID. Two final Blossom smoke runs confirmed stable per-source refresh, two simultaneous effects, unchanged petal values, and combined healing from 90 to 96 HP in one tick.
- The later approved MainWorld playtest reached Wave 47 with two Strength Branches, two Blossom Branches, no upgrades, and a normal Wave 1 start.

### Strength Visual Separation Checkpoint

- The Strength visual smoke test passed two final runs. It verifies the real Strength scene, visual growth at key Branch Levels, Tree growth scaling, facing direction, root API delegation, attack range, root-transform inheritance, and cleanup.
- The TALENTS smoke test passed two final runs against the real MainWorld and equipped Branch instances. It verifies the visible and functional TALENTS button, both Strength instances, the three Strength talents, Blossom selection, return to Strength, and exclusion of `StrengthBranchVisual` from branch detection.
- The Blossom healing stack smoke test passed two final runs with combined healing from 90 to 93 to 96 HP. The enemy runtime smoke test also passed its final regression run.
- The Godot 4.7.1 headless editor/import completed successfully without parser, Resource, invalid-UID, orphan, or stack-trace errors.
- The user manually verified the left and right Strength visuals, growth, shoots, attack animation, attack range, TALENTS visibility and opening, and Strength to Blossom to Strength switching in MainWorld.
- The reported TALENTS incident was not a production UI regression. The button remained present, visible, enabled, and functional; the apparent disappearance came from the embedded game display and clipped viewport in the Godot editor. Production UI was not changed, and the regression smoke test now covers this flow.

### Strength Talent Runtime Effects Checkpoint

- The Strength talent effects smoke test passed two final runs against the real Strength scene. It verifies Resource-driven effect dispatch, base attacks, all three individual effects, their combined behavior, independent per-Strength Marked Prey state, AttackContext data, stop/resume resets, and cleanup.
- The Strength visual smoke test, TALENTS smoke test, and Blossom healing stack smoke test each passed two final runs. The enemy runtime smoke test also passed its final regression run.
- The Godot 4.7.1 headless editor/import completed successfully without parser, Resource, ContentValidator, invalid-UID, orphan, or stack-trace errors.
- The user manually verified all three talents and their combination in MainWorld: Sweeping primary and secondary hits, Rebuff on both struck targets, Marked Prey growth and reset, and an independent second Strength instance without purchased talents.

### Blossom Visual Separation Checkpoint

- The Blossom visual smoke test passed two final runs against the real Blossom scene.
- The Blossom healing stack smoke test passed two final runs with combined healing from 90 to 93 to 96 HP.
- The Strength visual smoke test, Strength talent effects smoke test, and TALENTS smoke test each passed two final runs. The enemy runtime smoke test also passed its final regression run.
- The Godot 4.7.1 headless editor/import completed successfully without parser, Resource, ContentValidator, invalid-UID, orphan, or stack-trace errors.
- The user manually verified the left and right Blossom instances, mirroring, length and thickness growth, one through seven flowers, Tree growth scaling, projectile spawning at the correct branch end, root-scale attack feedback, `3 + 3` healing stacking, all three Blossom upgrades, and unchanged UI in MainWorld.

### Blossom Talent Runtime Effects Checkpoint

- The Blossom talent effects smoke test passed two final runs, and the updated TALENTS smoke test passed two final runs against the real MainWorld and all four equipped Branch instances.
- The Blossom healing stack smoke test passed with combined healing from 90 to 93 to 96 HP. The Blossom visual, Strength talent effects, Strength visual, and enemy runtime smoke tests also passed their final regression runs.
- The Godot 4.7.1 headless editor/import completed successfully without parser, Resource, ContentValidator, invalid-UID, orphan, or stack-trace errors.
- The user manually verified Abundant Bloom healing of 4.5, Twin Petals primary and secondary damage of 3.0 and 1.8, successful Quickening Pollen purchase, and continued gameplay without a runtime error.

### Branch Categories and Apex Slot Foundation Checkpoint

- The Apex slot rules smoke test passed two final runs against the real Branch Resources, Tree scene, MainWorld, and Branch panel.
- The TALENTS, Blossom talent effects, Blossom healing stack, Blossom visual, Strength talent effects, Strength visual, and enemy runtime smoke tests all passed their final regression runs.
- The Godot 4.7.1 headless editor/import completed successfully without parser, Resource, ContentValidator, invalid-UID, orphan, or stack-trace errors.
- Strength and Blossom remain standard Branches in unique Slots 1–4. Slot 5 is an empty, disabled Apex slot backed by a growth-scaled Tree attachment marker; no legendary Branch was added.

### Persistent Branch Seed Loot Foundation Checkpoint

- The Branch Seed loot smoke test passed two final runs against the real Strength, Blossom, Bark Beetle, and Bark Runner Resources, the real Bark Beetle scene, and isolated ConfigFile paths under `user://` that were removed after each run.
- The enemy runtime smoke test passed two final runs. The Apex slot rules, TALENTS, Blossom talent effects, Blossom healing stack, Blossom visual, Strength talent effects, and Strength visual smoke tests all passed their final regression runs.
- The Godot 4.7.1 headless editor/import completed successfully without parser, Resource, ContentValidator, invalid-UID, orphan, or stack-trace errors.
- Persistent Branch Seed unlock storage, nested drop data, validation, signals, and the real enemy-death hook now exist. No production seed drop, Thorn Crown, loot UI, physical loot object, or Apex equip flow was added.

### Legendary Tier and Guardian Grove Boss Loot Checkpoint

- Strength and Blossom remain standard Tier 0. Legendary content now has player-facing Tier I-III data, with Tier I as an early focused legendary, Tier II as a stronger or more build-supporting legendary, and Tier III as the rarest, most complex, potentially rule-changing legendary. A higher Tier is not automatically optimal for every build.
- Guardian Grove owns an empty Stage loot pool with Tier I miniboss/boss limits and Tier I-III pity thresholds of 12, 18, and 24. No Thorn Crown, production legendary Branch, or production loot entry was added, so no real seed can drop yet.
- Bark Beetle and Bark Runner are normal enemies with zero Branch Seed chance and pity. Bark Warden is a miniboss with movement 85, health 120, damage 4, interval 1.4, range 145, Essence/XP 8/8, 5% chance, and one pity point. Ancient Bark Colossus is a boss with movement 60, health 300, damage 7, interval 1.8, range 165, Essence/XP 20/20, 15% chance, and three pity points.
- Wave 50 of every one of the ten Guardian Grove Substages now contains one Bark Warden per side. Wave 100 contains one Ancient Bark Colossus per side. Neither count scales and no escort enemies were added; Waves 49, 51, and 99 and the remaining normal schedule balance are unchanged.
- Both boss prototypes reuse the existing component-based melee runtime and have their own scenes, definitions, and code-drawn placeholder visuals. Unique abilities, phases, boss health-bar UI, and production graphical assets are not part of this checkpoint.
- Branch Seed save version 2, version 1 migration, per-Tier pity, highest-eligible-Tier selection, weighted entry selection, atomic save rollback, signal ordering, Stage context propagation, and death-only integration are covered by isolated smoke tests.
- Godot 4.7.1 headless import passed. Legendary Boss Loot passed twice, Branch Seed Loot passed twice, Enemy Runtime passed twice, and the shared Branch progress, Apex slot, TALENTS tab, Strength effects, Blossom effects, Blossom healing stack, Strength visual, and Blossom visual regressions passed once each.

### Per-Slot Talent Loadout Checkpoint

- Stable slot IDs are `standard_slot_1`, `standard_slot_2`, `standard_slot_3`, `standard_slot_4`, and `apex_slot`; forward, reverse, and invalid mappings are covered.
- Shared archetype data is XP, level, total Talent Points earned, and Essence-upgrade levels. Purchased talents are stored independently by `slot_id + branch_id`, and every physical copy receives the full shared Talent Point budget.
- Available Talent Points are derived from total earned minus that loadout's purchased TalentDefinition costs. Loadouts and shared progress survive Branch unregister/recreate and MainWorld recreation; Strength and Blossom builds in the same slot remain separate.
- `Slot 1 Strength -> Sweeping Strike` and `Slot 3 Strength -> Rebuff` passed with distinct runtime effect sets. Independent same-talent purchases in Slots 1 and 3 also passed.
- Production `MainWorld/WaveDirector.debug_start_global_wave` is restored to `0` and covered by Enemy Runtime.
- Godot 4.7.1 headless import passed. Per-Slot Talent Loadout passed three times; Shared Branch Progress and TALENTS Tab passed twice; Strength Effects, Blossom Effects, Blossom Healing Stack, Strength Visual, Blossom Visual, Apex Slot Rules, Branch Seed Loot, Legendary Boss Loot, and Enemy Runtime passed. The loot tests emitted only their intentional negative-fixture save-path warnings; there were no parser, Resource, invalid-UID, orphan, or stack-trace failures.

### TREE Overview Checkpoint

- This checkpoint introduced the fullscreen `TREE` overview from a dedicated button beside TALENTS. The former small right-side player-facing TREE tab is named `TRUNK`; its existing upgrade behavior is unchanged.
- TREE presents five slots around a central built-in silhouette: Slot 2 upper-left, Slot 1 lower-left, Slot 4 upper-right, Slot 3 lower-right, and the empty Apex Slot top-center. The current build is Strength in Slots 1 and 3, Blossom in Slots 2 and 4, and no Apex Branch.
- The selected standard-slot detail separates shared archetype Level, XP, and total Talent Points earned from the physical slot's available Talent Points and purchased talent names. It also shows shared Essence upgrade levels and effective statistics supplied directly by the runtime Branch.
- The right collection preview reads unlocked Legendary Branch Seed IDs from `BranchSeeds`, resolves definitions through `GameContent`, uses `BranchDefinition` Tier display text, and safely identifies unknown legacy IDs.
- TREE and TALENTS are mutually exclusive fullscreen screens. Neither pauses combat, and closing either leaves the small upgrade panels unchanged.
- At this historical checkpoint TREE had no mutation actions. Standard replacement during Preparation was added by the later Preparation checkpoint below; Apex equip, Thorn Crown, equipment/inventory, and talent purchase/respec/copy-build remain unimplemented.
- Godot 4.7.1 headless import passed. TREE Screen and TALENTS Tab passed twice. Per-Slot Talent Loadout, Shared Branch Progress, Strength Effects, Blossom Effects, Blossom Healing Stack, Apex Slot Rules, Branch Seed Loot, Legendary Boss Loot, Enemy Runtime, Strength Visual, and Blossom Visual passed once. Loot tests emitted only their intentional negative-fixture save-path warnings; there were no parser, Resource, invalid-UID, orphan, or stack-trace failures.

### Standard Branch Runtime Loadout Foundation

- `BranchLoadout` is a new runtime-only autoload that stores initialized standard `slot_id -> branch_id` assignments. An initialized value of `&""` represents explicit EMPTY and is preserved across MainWorld recreation; no disk save was added.
- The production defaults remain Strength, Blossom, Strength, Blossom in Slots 1-4. Duplicate standard archetypes are valid, including four simultaneous Strength instances.
- Four `BranchMount` nodes preserve the original left/right offsets. Static Strength and Blossom gameplay instances were removed from `tree.tscn`; `TreeBranchLoadoutController` now instantiates runtime roots through `GameContent` and `BranchDefinition.branch_scene`.
- Low-level runtime equip and unequip APIs exist. Shared BranchProgress and per-`slot_id + branch_id` talent builds survive real Strength-to-Blossom-to-Strength swaps, unequip, and MainWorld recreation.
- TREE, TALENTS, and the BRANCHES upgrade panel refresh from completed runtime slot changes without polling or retaining freed Branch nodes. This foundation initially exposed no player-facing mutation controls.
- The later Preparation checkpoint below adds gated standard Branch selection. Unrestricted mid-combat swap, Apex equip, disk persistence, and Thorn Crown remain unimplemented.
- Godot 4.7.1 headless import passed. Standard Branch Loadout, TREE Screen, and TALENTS Tab passed twice. Per-Slot Talent Loadout, Shared Branch Progress, Strength Effects, Blossom Effects, Blossom Healing Stack, Apex Slot Rules, Strength Visual, Blossom Visual, Branch Seed Loot, Legendary Boss Loot, and Enemy Runtime passed once. Loot tests emitted only their intentional negative-fixture save-path warnings; there were no parser, Resource, invalid-UID, orphan, or stack-trace failures.

### Standard Branch Picker + Preparation Phase V1

- `WaveManager` owns Preparation. A new run opens Initial Preparation before Wave 1; completing the StageDefinition-defined final Wave of a Substage opens Substage Complete Preparation; death/retry prepares Wave 1 of the current Substage and opens Retry Preparation instead of starting immediately.
- During Preparation, the WaveDirector cycle is stopped, active enemies are removed, all CombatBranches are stopped, the Tree is alive, and TREE opens automatically without pausing gameplay. START RUN, CONTINUE, or RETRY SUBSTAGE resumes every current Branch, closes TREE, and starts exactly the next prepared Wave.
- WaveDirector detects a Substage boundary through `get_safe_waves_per_substage()` after wave completion, the completion message, and `time_after_wave`; Wave 100 is not hardcoded. The completed global Wave remains current until Continue starts the next Wave.
- TREE dynamically builds its standard candidate list from `GameContent.get_branches()` in ContentRegistry Resource order. Only valid, placeable standard BranchDefinitions appear; every registered standard Branch is currently available because no standard unlock system exists, and duplicate archetypes remain valid.
- The current candidate is marked EQUIPPED and cannot issue a no-op. Candidate preview reads a copy of shared archetype progress and the preserved `slot_id + branch_id` talent loadout in TalentTree Resource order; preview does not instantiate a Branch or mutate loadout, progress, talents, or Essence.
- Confirm rechecks the WaveManager Preparation gate, standard slot, candidate validity, and current assignment before calling only the low-level `BranchLoadout.equip_standard_branch()`. The existing controller performs the runtime swap, and WaveManager immediately stops a newly created Branch while Preparation remains active.
- Outside Preparation, TREE remains available as a read-only overview with a clear LOADOUT LOCKED state. CLOSE cannot escape active Preparation, TALENTS cannot open during Preparation, and direct UI confirm outside Preparation fails without changing the runtime or loadout.
- Player-facing unequip, a standard Branch unlock system, disk loadout save, Apex equip, Thorn Crown, and equipment/inventory remain unimplemented.
- Godot 4.7.1 headless import passed. Loadout Preparation, TREE Branch Picker, TREE Screen, and TALENTS Tab passed twice. Standard Branch Loadout, Per-Slot Talent Loadout, Shared Branch Progress, Strength Effects, Blossom Effects, Blossom Healing Stack, Apex Slot Rules, Strength Visual, Blossom Visual, Branch Seed Loot, Legendary Boss Loot, and Enemy Runtime passed once. Loot tests emitted only their intentional negative-fixture save-path warnings; there were no parser, Resource, invalid-UID, orphan, or stack-trace failures.

### Apex Branch Seed Selection + Equip Foundation

- `BranchLoadout` now owns the runtime `apex_slot -> legendary branch_id / EMPTY` assignment. Apex defaults to initialized EMPTY, supports low-level equip and unequip, and preserves both equipped and explicit EMPTY state across MainWorld recreation without adding disk persistence.
- `AttachmentPoints/Apex/BranchMount` hosts zero or one physical Legendary `CombatBranch`. `TreeBranchLoadoutController` instantiates the registered Branch scene with Slot 5 / `apex_slot`, safely removes it during swaps, and preserves shared archetype progress plus the `apex_slot + branch_id` talent build.
- Player-facing Apex selection is available only during Preparation. The TREE picker starts from unlocked Branch Seed IDs, preserves unlock order, resolves only valid Legendary definitions eligible for Apex, and rechecks Preparation, unlock ownership, definition validity, Tier, slot eligibility, and no-op state on confirmation.
- Unknown unlocked legacy Seed IDs remain visible through the safe collection fallback but are never equippable. Standard definitions stay out of the Apex picker, Legendary definitions stay out of the standard picker, and Legendary Tier text comes from `BranchDefinition`.
- Apex candidate preview shows definition text, shared archetype progress, and saved Apex talents in Resource order without creating progress, instantiating a Branch, or mutating loadout or unlock state. Live `branch_seed_unlocked` refresh updates the collection and open picker without polling.
- TREE, TALENTS, and BRANCHES refresh after Apex runtime changes. TALENTS identifies Slot 5 as APEX, and newly created Apex Branches remain combat-stopped during Preparation before the shared resume flow starts combat.
- Synthetic Legendary A/B fixtures exist only under `tests/fixtures/branches` and are injected into the registry during isolated tests. At this historical checkpoint no production Legendary Branch existed; Thorn Crown was added by the later checkpoint below.
- Godot 4.7.1 headless import passed. Apex Branch Loadout, TREE Apex Picker, Loadout Preparation, TREE Branch Picker, TREE Screen, and TALENTS Tab passed twice. Standard Branch Loadout, Per-Slot Talent Loadout, Shared Branch Progress, Apex Slot Rules, Strength Effects, Blossom Effects, Blossom Healing Stack, Strength Visual, Blossom Visual, Branch Seed Loot, Legendary Boss Loot, and Enemy Runtime passed once. Loot tests emitted only their intentional negative-fixture save-path warnings.

### Thorn Crown Tier I V1

- Production content now includes `thorn_crown`, a Legendary Tier I Branch restricted to the Apex Slot. It is registered after Strength and Blossom in `GameContent` and uses the existing unlocked-Seed-gated Apex picker.
- Thorn Crown is one physical runtime Branch with one attack cycle that independently chooses the nearest valid left and right primary targets. Each populated side creates one Thorn Burst centered on its primary target; each Burst deals same-side area damage through `AttackContext` and `AttackResolver`, with a one-hit-per-enemy-per-cycle guard.
- V1 base balance is 12 damage, 2.40-second cooldown, 0.80-second minimum cooldown, 350 horizontal range, and 90 Burst Radius. Branch damage and attack-speed RunModifiers use the shared `BranchStatCalculator` paths.
- Shared `thorn_crown` progression owns Level, XP, and three Essence upgrades: Thorn Damage (+2), Attack Speed (-0.08 seconds), and Burst Radius (+8). The Apex talent loadout remains `apex_slot + thorn_crown`.
- Its TalentTree contains Barbed Core at Level 2 (primary +40%), Twin Torment at Level 4 (both sides active gives +25% cycle damage), and Overgrowth at Level 7 (every third real cycle gives +30% damage and +50% radius). Multipliers stack multiplicatively.
- The code-drawn Thorn Crown visual has a symmetric central crown, bilateral arms and thorns, modest level growth, and transient code-drawn Thorn Burst feedback that self-cleans.
- TREE displays the production description, Legendary Tier, progress, saved Apex build, upgrades, and effective stats. TALENTS discovers `APEX — THORN CROWN` and its three talents; BRANCHES discovers its three upgrades without special UI code.
- At this historical checkpoint Thorn Crown was registered but could not yet drop naturally. The later Guardian Grove Tier I Loot checkpoint below adds natural acquisition without default-unlocking it.
- Godot 4.7.1 headless import passed. Thorn Crown runtime/content, Thorn Crown visual, TREE Apex Picker, Apex Branch Loadout, and Apex Slot Rules passed twice. Preparation, TREE Branch Picker, TREE Screen, TALENTS Tab, Standard Branch Loadout, Per-Slot Talent Loadout, Shared Branch Progress, Strength Effects, Blossom Effects, Blossom Healing Stack, Strength Visual, Blossom Visual, Branch Seed Loot, Legendary Boss Loot, and Enemy Runtime passed once. Loot tests emitted only their intentional negative-fixture save-path warnings.

### Thorn Crown Guardian Grove Tier I Loot

- Thorn Crown is the first production Branch Seed entry in the Guardian Grove Tier I pool. The entry references the registered `thorn_crown` BranchDefinition and has weight 1.0.
- Bark Warden retains its 5% eligible roll chance and +1 Tier I pity on failure. Ancient Bark Colossus retains its 15% chance and +3 Tier I pity. The Tier I threshold remains 12.
- With all chance rolls failing, three complete Warden + Colossus pairs move Tier I pity through `0 -> 1 -> 4 -> 5 -> 8 -> 9 -> 12`. The next eligible encounter sees the threshold already reached and is guaranteed; the Colossus that raises pity from 9 to 12 does not retroactively drop the Seed.
- A successful production drop unlocks Thorn Crown through `BranchSeeds`, resets Tier I pity to 0, persists the unlock to the existing disk save, and makes it available to the existing TREE Apex picker during Preparation. Reload preserves the unlock; the Branch loadout itself remains runtime-only.
- Once Thorn Crown is unlocked it leaves the locked pool. Warden and Colossus cannot drop it again, and with no other locked Tier I entry they perform no Seed roll, emit no duplicate drop, and add no pity.
- Registration and pool membership alone do not unlock Thorn Crown. Bark Beetle and Bark Runner remain normal enemies with zero Branch Seed chance and pity contribution.
- Branch Seed drop notification, a loot popup, a physical loot object, boss abilities, production Tier II and Tier III Branches, and equipment/inventory are still not implemented.
- Godot 4.7.1 headless import passed. Thorn Crown Guardian Grove Loot, Branch Seed Loot, and Legendary Boss Loot passed twice. Thorn Crown runtime/content, Thorn Crown visual, Apex Branch Loadout, Apex Slot Rules, TREE Apex Picker, TREE Screen, TALENTS Tab, Loadout Preparation, Standard Branch Loadout, Per-Slot Talent Loadout, Shared Branch Progress, Strength Effects, Blossom Effects, Blossom Healing Stack, Strength Visual, Blossom Visual, and Enemy Runtime passed once. Loot tests emitted only their intentional negative-fixture save-path warnings.

### Branch Seed Acquisition Notification V1

- `BranchSeeds.branch_seed_dropped` is the sole production trigger. The service emits it only after a successful natural drop has persisted its unlock and pity reset; registry membership, loot-pool membership, disk reload, and direct service-level unlock do not replay the presentation.
- The top-center panel presents `LEGENDARY BRANCH SEED UNLOCKED`, the BranchDefinition display name and Legendary Tier text, the resolved source EnemyDefinition display name when available, and `Available in TREE during Preparation`.
- The notification is non-blocking, ignores mouse input, has a 4-second default hold, and uses a short 0.22-second fade/slide in plus 0.30-second fade out. A newer valid acquisition replaces the current content and restarts one presentation tween.
- Its `z_index = 100` keeps it visible above TREE during Initial, Substage, or Retry Preparation without opening TREE, equipping a Branch, changing Preparation, or pausing combat. Missing enemy metadata hides only the source line; an invalid Branch event is ignored safely.
- No physical loot object, loot inventory, sound, Branch Seed icon art, boss abilities, production Tier II or Tier III Branch, or equipment/inventory was added.
- Godot 4.7.1 headless import passed. Branch Seed Drop Notification passed repeatedly, including a real isolated production Warden-to-Thorn-Crown drop, Initial Preparation overlay, auto-hide, reload silence, and metadata guards. Thorn Crown Guardian Grove Loot, Branch Seed Loot, and Legendary Boss Loot passed twice. TREE Apex Picker, TREE Screen, TALENTS Tab, Loadout Preparation, Thorn Crown runtime/content, Thorn Crown visual, Apex Branch Loadout, Apex Slot Rules, Standard Branch Loadout, Per-Slot Talent Loadout, Shared Branch Progress, Strength Effects, Blossom Effects, Blossom Healing Stack, Strength Visual, Blossom Visual, and Enemy Runtime passed once. Existing loot tests emitted only their intentional negative-fixture save-path warnings.

### Boss Abilities V1

- Bark Warden keeps its normal melee behavior and adds Root Slam: a telegraphed 8-damage burst with a 3.0-second initial delay, 7.0-second cooldown, and 0.90-second telegraph. Each Warden owns an independent cooldown and active telegraph, and death or cleanup cancels the cast without delayed damage.
- Ancient Bark Colossus keeps its normal melee behavior and adds Colossal Quake. Phase 1 uses a 3.5-second initial delay, 8.0-second cooldown, 1.20-second telegraph, and one 12-damage pulse. At the first transition to 50% maximum health or below, that instance enters Phase 2 once; Phase 2 uses a 6.0-second cooldown and 1.0-second telegraph followed by two 10-damage pulses separated by 0.35 seconds. Death between pulses cancels the pending second pulse.
- `BossAbilityDefinition` stores immutable, optional boss configuration referenced by `EnemyDefinition`. The scene-local `BossAbilityRuntime` child owns every mutable cooldown, phase, cast, Timer, Tween, telegraph, and pending-pulse value for one enemy instance. Telegraphs and phase feedback are code-drawn children of that enemy and require no external assets.
- Ability execution uses the existing tree `take_damage()` pipeline. Only the casting boss's normal melee component is disabled during the cast and restored afterward; the SceneTree, WaveDirector, CombatBranches, other enemies, and the second boss instance are never paused or coordinated.
- Death, `stop_combat()`, `queue_free()`, `_exit_tree()`, Retry, and wave cleanup converge on cancellation that stops Timers, kills Tweens, removes telegraphs, and prevents pending damage. Shared Resources contain no mutable runtime state, and two boss instances remain independent.
- Boss loot, Branch Seed chances, pity, Thorn Crown gameplay, TREE/Apex behavior, Branch Seed notification, progression, rewards, and the Wave 50/100 schedules are unchanged.
- Still not implemented: a boss health bar or intro, production boss art/audio, screen shake, additional boss abilities, equipment/inventory, and the second Legendary Branch.
- Godot 4.7.1 headless import passed. Root Slam and Colossal Quake smoke tests each passed twice, including death cancellation, the one-time Phase 2 transition, double-pulse cancellation, Retry-equivalent cleanup, and two-instance isolation. Enemy Runtime; Legendary Boss Loot; Thorn Crown Guardian Grove Loot; Branch Seed Loot; Branch Seed Drop Notification; Loadout Preparation; Strength and Blossom Talent Effects; Thorn Crown runtime and visual; TREE Screen; and TALENTS Tab regressions passed once. Loot tests emitted only their intentional negative-fixture save-path warnings.

## 9. Known Gaps and Limitations

- There is no general save/load system. Branch Seed unlock IDs are the only persistent meta-progression currently stored across processes.
- Branch archetype progression is retained only in memory and is not included in the disk save.
- TREE supports standard and Apex Branch replacement only during Preparation; player-facing unequip and standard Branch unlock progression do not exist.
- There is no talent respec, copy-build, or save-preset flow.
- Tier data and the first miniboss/boss encounters are implemented, but Tier badges, equipment, and inventory are not.
- There is no `CampaignDefinition`.
- Stage 2 is currently only the repeated Guardian Grove Resource, not a second authored Stage Resource.
- All ten Guardian Grove Substages currently share one schedule; later Substages are not yet differentiated.
- Automated tests did not physically play all 1,000 Waves in a Stage.
- The `X-Y-Z` HUD mapping is covered by data/runtime tests, but its rendered presentation still needs manual visual confirmation.
- Bark Runner's placeholder appearance still needs manual visual confirmation.
- `bark_runner.gd` currently inherits the shared runtime behavior from the Bark Beetle root script and overrides only drawing; separating a generic enemy root base is outside this checkpoint.
- Plan item 40 is only partially complete because the smoke test validates the enemy runtime foundation rather than a full combat-integration scene.
- No StatusEffect definitions are registered yet.
- Strength, Blossom, and Thorn Crown have separated visual and talent-effect responsibilities. Their runtime dispatchers remain Branch-specific rather than a global universal effect system.
- A shared Branch visual base does not yet exist and is not needed for the current three implementations.
- Branch category data, Slot 5 rules, the Apex runtime/equip foundation, persistent Branch Seed unlock storage, the legendary drop-processing foundation, natural production Thorn Crown acquisition, and a non-blocking acquisition notification exist. There is still no physical loot object, player-facing Apex unequip, or disk Apex loadout save.
- There is no found-versus-equipped Apex Branch comparison.
- Bark Warden and Ancient Bark Colossus now have their first unique abilities, but there is no dedicated boss health-bar or encounter-intro UI and no additional boss ability set.
- Normal enemies do not drop equipment.
- The Tree Soul orb described in project guidance as visible from Age 1 is not a persistent world-space element; only the hidden-by-default SOUL panel and selection cards draw orb glyphs.
- A service-level prestige reset hook exists, but there is no integrated player-facing prestige flow.
- Gameplay scripts contain extensive prototype debug logging.
- Visuals are primarily code-drawn prototype shapes; the repository has no production art or audio content beyond the project icon.
- Schedule validation has automated negative fixtures, but broader ContentValidator failure presentation has not been manually exercised in the editor.
- Project guidance describes a Soul orb visible from Age 1, but the current implementation has no persistent world-space orb; orb glyphs exist only in the SOUL panel and selection cards.

### Balance Note

Enemy HP and damage now scale proportionally from each enemy's base values. The approved no-upgrade playtest reached Wave 47, within the intended early-game wall of approximately Waves 40–50. The next balance evidence should come from a normal run with natural upgrade purchases and from reviewing the Forest Essence economy under the higher enemy counts.

### Approved Long-term Branch Plan

The approved roster target is 20 Branch archetypes: 13 standard Branches and seven legendary Branches. Slots 1–4 accept only standard Branches. Slot 5 is the Apex Slot: its attachment point and category rules accept exactly one legendary Branch placed at the top of the tree. Thorn Crown is the first implementation of the bilateral Apex gameplay model. Legendary Branch Seeds are planned as enemy loot or unlocks.

The first legendary concepts are:

- Thorn Crown: implemented as a naturally obtainable bilateral Tier I area-damage Apex Branch.
- Spirit Branch: summons forest spirits on both sides. Spirits advance toward enemies; on contact both units stop and fight, and the enemy resumes moving toward the tree only after defeating the spirit.

## 10. Architecture Decisions to Preserve

- Use a Godot-friendly component plus custom-Resource architecture, not a full ECS.
- Keep content metadata and balance in Registry/Definition Resources; keep mutable gameplay state on runtime nodes.
- Resolve content through `ContentRegistry` and `GameContent` rather than hardcoded lists when registered definitions exist.
- Keep Upgrade and Talent IDs scoped by `branch_id`, and Wave IDs scoped by `stage_id`; do not collapse them into one global content-ID namespace.
- Preserve Resource array order for UI and gameplay. Dictionaries are for lookup, not ordering.
- Use stable `StringName` IDs for content and gameplay identifiers.
- Do not hand-write Godot UIDs or `.uid` files.
- Do not duplicate content metadata in UI when the same data is already available from Resources.
- Preserve preferred-lane targeting with fallback; do not silently turn it into strict-lane targeting.
- Preserve Tree Soul modifier isolation: damage does not affect healing, attack speed does not affect healing ticks or unrelated timers, Essence gain affects rewards only, and tree-health modifiers remain tree-specific.

## 11. Recommended Next Work

The next recommended steps are:

1. Optionally add Boss Encounter Presentation V1 (boss name and health presentation) if justified by playtest.
2. Begin `ItemDefinition` / `ItemInstance` and the minimal equipment foundation as the next main milestone.
3. Add the second production Legendary Branch concept after the current boss loop is visually verified.
4. Add production boss art/audio only after mechanics are stable.

General save/load, prestige integration, later talent tiers, Status Effects, and the persistent Tree Soul orb remain later known gaps.

## 12. Handoff Checklist

- Read the root `AGENTS.md`.
- Read `docs/CURRENT_STATUS.md`.
- Run `git status --short` and verify the working tree is clean before starting a new task.
- Run `git log -1 --oneline` and review the current HEAD.
- Expected baseline branch: `main`.
- Implementation parent for this checkpoint: `fd860d3`.
- Verify that the current HEAD contains this implementation baseline or is a descendant of it.
- The 25A and 25B implementation was accumulated in the working tree before this checkpoint document and committed as one focused package.
- After the checkpoint commit, the working tree should be clean before new development begins.
- Before changing code, read the relevant scenes, scripts, Resources, and service definitions and verify actual paths, signals, methods, and fields.
- Change only files explicitly allowed by the current task.
- Run `git diff --check` and review the complete diff after each focused task.
- Run the Godot headless parse/import check when an executable is available; disclose clearly when it is unavailable.
- State which runtime and manual tests were and were not performed.
- Launch `res://scenes/main_world.tscn` in Godot 4.7.1 and confirm there are no parser, missing-Resource, or ContentValidator errors.
- Verify both Strength and Blossom instances attack; verify Blossom heals.
- Verify each branch instance owns independent XP, Talent Points, talents, and upgrade levels.
- Recheck the first upgrade costs and one-level deltas listed in Sections 3 and 8.
- Recheck Sweeping Strike, Rebuff, and Marked Prey without changing their current balance.
- Kill the tree and confirm immediate/automatic revive into Retry Preparation, then restart at Wave 1 of the current Substage with in-memory progression preserved.
- Confirm replayed waves do not grant additional Age and a newly completed highest wave does.
- At the Age 199/200/300 boundaries, verify Soul Rank 0/1/2, deferred selection, status-panel reopening, modifier isolation, and non-blocking rank-up notification behavior.
- Before committing this document or later work, ensure the diff contains only explicitly intended files and no generated UID changes.
