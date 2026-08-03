# Tree Guardian — Current Project Status

Updated: 2026-08-03

Implementation parent for this checkpoint: `db33f5f4a7effa19adbf5af5e0bd1e5955ee0ca5` (`Add Bark Runner enemy`)

Checkpoint commit: `Add deterministic Guardian Grove mixed waves`

Baseline branch: `main`

## 1. Project Snapshot

Tree Guardian is a playable 2D idle/tower-defense prototype built for Godot 4.7.1 with GDScript 2 and Forward Plus rendering. The project configuration declares Godot feature level 4.7, a 1920 × 1080 base viewport, and `res://scenes/main_world.tscn` as the main scene.

The current prototype has one central tree and four branch instances: Strength and Blossom on both the left and right sides. Global content and run services are provided by the `GameContent`, `TreeSouls`, and `RunModifiers` autoloads.

This document describes the repository after the enemy/wave architecture checkpoint built on the implementation parent above.

## 2. Current Playable Prototype

The main loop is functional:

- Bark Beetles are instantiated from registered Enemy, Stage, and Wave Resources. They spawn in lane-aware waves, move toward the tree, attack it, and grant Branch XP plus Forest Essence drops when defeated.
- Strength branches perform melee attacks; Blossom branches heal the tree and fire ranged petals.
- Branch XP increases Branch Level. Talent Points are awarded at configured Branch Levels and are spent independently by each branch instance.
- Forest Essence buys branch and tree upgrades. Current upgrade levels remain mutable state on the individual runtime node, not in shared Resources.
- Age increases only after completing a new highest global wave. Replaying already completed waves after a death does not farm Age.
- Tree death stops the active combat cycle and opens a defeat panel. The player can retry immediately, or the tree revives automatically after a 10-second countdown. The current Substage restarts at its Wave 1.
- Normal death preserves in-memory long-term run progression: Age, Forest Essence, Branch XP and levels, purchased branch upgrades and talents, tree upgrades, and the selected Tree Soul and rank.

The prototype has no save/load system, so this preserved state lasts only for the running game process.

## 3. Branches

### Strength

Strength is a close-range offensive branch using preferred-lane targeting with fallback behavior. Its base attack deals 10 damage with a 1.5-second cooldown; the runtime minimum cooldown remains 0.45 seconds.

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

Blossom is a support/ranged branch with its own scene. It heals the tree for 3 HP every 2.0 seconds and fires petals for 3 base damage every 2.0 seconds. Its targeting profile permits any lane.

Blossom rendering is separated into the direct child node `BlossomBranchVisual`. The visual node owns the exported dimensions, growth formula, flower count, and drawing, while `blossom_branch.gd` continues to own healing, projectile combat, targeting, upgrades, and combat orchestration. The runtime synchronizes Branch Level, Tree growth factor, and facing direction to the visual node and delegates growth progress, length, and thickness to it. Projectile spawning uses the length provided by the visual node, while ranged-attack feedback still tweens the Blossom root scale. No gameplay or balance values changed during this separation.

Each Blossom Branch uses its own runtime healing-effect ID in the form `blossom_healing_<instance_id>`. Reapplying healing from the same Blossom refreshes only its own effect, while multiple Blossom HoTs stack independently. Two base Blossom Branches therefore heal 6 HP together every 2.0 seconds.

Its Resource-defined upgrades are ordered as follows:

| Upgrade | Effect per level | First cost | Maximum |
| --- | ---: | ---: | --- |
| Healing per Tick | +1.0 healing | 9 | Dynamic Branch Level limit |
| Healing Speed | -0.10 s healing interval | 11 | 13 levels, also limited by Branch Level; 0.75 s runtime floor applies |
| Petal Damage | +1.0 flat damage | 8 | Dynamic Branch Level limit |

Blossom currently has no TalentTree. Each left/right Strength or Blossom node keeps its own Branch XP, level, Talent Points, purchases, and upgrade levels; buying an upgrade on one instance does not mutate the other instance or its shared definition Resource.

## 4. Content Resource Architecture

The project uses typed custom Resources for content data and Node scripts for mutable gameplay state. Current definition types include:

- `BranchDefinition`
- `UpgradeDefinition`
- `TalentDefinition`
- `TalentTreeDefinition`
- `TreeSoulDefinition` and `TreeSoulBonusDefinition`
- `EnemyDefinition`
- `WaveEnemyEntryDefinition`
- `WaveDefinition`
- `SubstageWaveScheduleEntryDefinition`
- `SubstageWaveScheduleDefinition`
- `SubstageDefinition`
- `StageDefinition`
- `StatusEffectDefinition`
- `TargetingProfile`

The current authored content consists of two BranchDefinition Resources, six UpgradeDefinition Resources, one Strength TalentTreeDefinition with three TalentDefinition Resources, four TreeSoulDefinition Resources, two EnemyDefinition Resources, one repeating StageDefinition, one shared SubstageWaveScheduleDefinition, and five WaveDefinition templates. Definitions own stable IDs, presentation text, ordered relationships, and balance values. Runtime nodes own mutable health, combat state, progression, and wave-cycle state.

Resource references use repository paths. New Godot UIDs must be generated by Godot rather than invented or handwritten.

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

## 9. Known Gaps and Limitations

- There is no save/load system; all progression is process-local.
- Blossom still has no TalentTree or runtime talent effects.
- There is no `CampaignDefinition`.
- Stage 2 is currently only the repeated Guardian Grove Resource, not a second authored Stage Resource.
- All ten Guardian Grove Substages currently share one schedule; later Substages are not yet differentiated.
- Automated tests did not physically play all 1,000 Waves in a Stage.
- The `X-Y-Z` HUD mapping is covered by data/runtime tests, but its rendered presentation still needs manual visual confirmation.
- Bark Runner's placeholder appearance still needs manual visual confirmation.
- `bark_runner.gd` currently inherits the shared runtime behavior from the Bark Beetle root script and overrides only drawing; separating a generic enemy root base is outside this checkpoint.
- Plan item 40 is only partially complete because the smoke test validates the enemy runtime foundation rather than a full combat-integration scene.
- No StatusEffect definitions are registered yet.
- Strength runtime talent effects are separated and dispatched through `TalentDefinition.effect_ids`; the dispatcher remains Strength-specific rather than a global universal effect system.
- Strength and Blossom both have separated visual layers.
- A shared Branch visual base does not yet exist and is not needed for the current two implementations.
- The Tree Soul orb described in project guidance as visible from Age 1 is not a persistent world-space element; only the hidden-by-default SOUL panel and selection cards draw orb glyphs.
- A service-level prestige reset hook exists, but there is no integrated player-facing prestige flow.
- Gameplay scripts contain extensive prototype debug logging.
- Visuals are primarily code-drawn prototype shapes; the repository has no production art or audio content beyond the project icon.
- Schedule validation has automated negative fixtures, but broader ContentValidator failure presentation has not been manually exercised in the editor.
- Project guidance describes a Soul orb visible from Age 1, but the current implementation has no persistent world-space orb; orb glyphs exist only in the SOUL panel and selection cards.

### Balance Note

Enemy HP and damage now scale proportionally from each enemy's base values. The approved no-upgrade playtest reached Wave 47, within the intended early-game wall of approximately Waves 40–50. The next balance evidence should come from a normal run with natural upgrade purchases and from reviewing the Forest Essence economy under the higher enemy counts.

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

1. Design a third Branch archetype, including its role, base attack, three upgrades, and first talent paths.
2. Implement the third Branch from the start with separate runtime and visual nodes.
3. Then add a Blossom TalentTree and runtime talent effects.

Save/load, prestige integration, complete Strength/Blossom talent trees, Status Effects, and the persistent Tree Soul orb remain later known gaps.

## 12. Handoff Checklist

- Read the root `AGENTS.md`.
- Read `docs/CURRENT_STATUS.md`.
- Run `git status --short` and verify the working tree is clean before starting a new task.
- Run `git log -1 --oneline` and review the current HEAD.
- Expected baseline branch: `main`.
- Implementation parent for this checkpoint: `db33f5f4a7effa19adbf5af5e0bd1e5955ee0ca5`.
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
- Kill the tree and confirm immediate/automatic retry, restart at Wave 1 of the current Substage, and preservation of in-memory progression.
- Confirm replayed waves do not grant additional Age and a newly completed highest wave does.
- At the Age 199/200/300 boundaries, verify Soul Rank 0/1/2, deferred selection, status-panel reopening, modifier isolation, and non-blocking rank-up notification behavior.
- Before committing this document or later work, ensure the diff contains only explicitly intended files and no generated UID changes.
