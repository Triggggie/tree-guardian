# Tree Guardian — Current Project Status

Updated: 2026-08-21

Implementation parent for this checkpoint: `d6c6302` (`Update status after gameplay UX pass`)

Checkpoint commit: `Update status after persistence foundation`

Baseline branch: `main`

## 1. Project Snapshot

Tree Guardian is a playable 2D idle/tower-defense prototype built for Godot 4.7.1 with GDScript 2 and Forward Plus rendering. The project configuration declares Godot feature level 4.7, a 1920 × 1080 base viewport, and `res://scenes/main_world.tscn` as the main scene.

The current prototype has one central tree and four standard branch instances: Strength and Blossom on both the left and right sides. Stable identities are `standard_slot_1`, `standard_slot_2`, `standard_slot_3`, `standard_slot_4`, and `apex_slot`. Thorn Crown (`thorn_crown`) is the first production Legendary Branch supporting Tier I-III acquisition through one Apex-only bilateral area-damage Branch definition registered in `GameContent`. Global content, run, Branch Seed cycle progression, runtime loadout, and shared Branch progression services are provided by the `GameContent`, `TreeSouls`, `RunModifiers`, `BranchSeeds`, `BranchLoadout`, and `BranchProgress` autoloads.

This document describes the repository after the Basic Equipment Loot V1 checkpoint built on the implementation parent above.

## 2. Current Playable Prototype

The main loop is functional:

- Bark Beetles are instantiated from registered Enemy, Stage, and Wave Resources. They spawn in lane-aware waves, move toward the tree, attack it, and grant Branch XP plus Forest Essence drops when defeated.
- Strength branches perform melee attacks; Blossom branches heal the tree and fire ranged petals.
- Branch XP increases Branch Level. XP, level, total Talent Points earned, and Essence-upgrade levels are shared by all runtime instances with the same stable `branch_id`. Purchased talents are independent for each `slot_id + branch_id` loadout.
- Forest Essence buys branch and tree upgrades. A shared Branch upgrade purchase is charged once and immediately updates every active instance of that archetype; mutable progress never resides in shared definition Resources.
- Age increases only after completing a new highest global wave. Replaying already completed waves after a death does not farm Age.
- Tree death stops the active combat cycle and opens a defeat panel. The player can retry immediately, or the tree revives automatically after a 10-second countdown. Retry now opens Preparation before restarting the current Substage at its Wave 1.
- Normal death preserves in-memory long-term run progression: Age, Forest Essence, Branch XP and levels, purchased branch upgrades and talents, tree upgrades, and the selected Tree Soul and rank.

Stable Inventory, Equipment, Branch Progress, per-slot talent builds, and Branch Loadout state now persist through the versioned `SaveGame` service. Active run state remains process-local. Legendary Branch Seed unlocks and pity remain an independent persistence domain owned by `BranchSeeds`.

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

`BranchProgressionRules` centrally defines Branch XP and Talent Point progression. XP required to advance from the current level is `ceil(2.0 + 1.5 * pow(level, 1.35))`; the cost is recalculated after every level in a multi-level grant and overflow XP is preserved. The 12 Talent Point milestones are Levels 2, 5, 10, 20, 35, 55, 80, 110, 150, 200, 275, and 375. Earned budget is derived from shared Branch Level, while purchases remain independent per `slot_id + branch_id`.

Save structure remains compatible: saved Branch Level and current XP are preserved, and the new next-level requirement plus earned Talent Point budget are derived from the restored level. Existing purchased talent IDs remain intact even if an old build has spent more points than its newly derived current-level budget; no level, XP, or purchased talent is removed.

Valid examples include `Slot 1 Strength -> Sweeping Strike` beside `Slot 3 Strength -> Rebuff`, and independent stored builds for `Slot 1 Strength` and `Slot 1 Blossom`. Runtime `TalentEffectSet` objects remain separate per physical instance.

Branch progress and slot-specific talent loadouts are stored on disk through `SaveGame`. Talent-effect set objects remain separate per physical Strength or Blossom instance, and only purchased effect IDs are synchronized. Forest Essence is spent once by the authoritative upgrade transaction, even though all matching runtime instances receive the new level.

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

The Tree scene contains the empty central marker `AttachmentPoints/Apex` at its authored position `(0, -95)`. Its dedicated BranchMount uses the top offset `(0, -170)`, while the existing attachment-position storage and Tree growth scaling include the marker. The effective Apex mount remains above both upper Standard mounts for sapling and mature growth. The Branch panel labels an empty Slot 5 as `APEX`, keeps it disabled, and excludes invalid Branch/slot combinations.

Strength and Blossom remain standard Tier 0 Branches. Legendary Tier is player progression stored by stable `branch_id`, not immutable `BranchDefinition` identity. One Legendary Branch can be acquired at Tier I, II, or Tier III; higher acquisition never downgrades within a Prestige cycle. `BranchDefinition.get_legendary_tier_display_name_for_tier()` is the canonical formatter. Final Tier combat scaling and duplicate/fusion rules remain intentionally undefined.

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

### Guardian Tree Growth Visuals V1

The production Guardian Tree base visual is driven only by canonical `Tree.age`. `TreeGrowthVisual` owns one nearest-filtered `Visual/BaseTreeSprite`, listens to `Tree.age_changed`, and swaps among four authored 256x256 transparent PNGs without polling or changing the Tree gameplay node. The approved mapping is Stage 1 at Age 1-39, Stage 2 at Age 40-79, Stage 3 at Age 80-199, and Stage 4 at Age 200+. Age 200 displays the Mature Guardian Tree immediately while the existing Tree Soul system independently unlocks selection at the same milestone.

Presentation scales are Stage 1 `(2.0, 2.0)`, Stage 2 `(1.85, 1.85)`, Stage 3 `(1.6, 1.6)`, and Stage 4 `(1.575, 1.575)`. Their corresponding presentation-only offsets are `(1, -124)`, `(2.775, -127.65)`, `(-0.8, -150.4)`, and `(0, -159.075)`. These values center each opaque sprite bound and align its lowest root pixel to the Tree origin. The authored dormant gray Soul Core remains baked into each base sprite; the empty `Visual/SoulCoreVisual` node reserves a future overlay without hard-coding a selected Soul color in this checkpoint.

Visual swaps do not relocate or recreate `AttachmentPoints`, `BranchMount` nodes, runtime Branches, collision, Tree HP, or progression. Ordinary death/revive does not change Age and therefore retains the same visual stage. There is still no player-facing Prestige flow; a future canonical reset that changes Age to 1 will resolve to Stage 1 without a second Age counter.

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

### Tree Loadout UX & Apex Placement Fix

- Standard and unlocked Apex Branches may now be changed while the tree is alive, including during active normal and boss Waves. Preparation remains the initial, Substage, and Retry transition state, but is no longer a loadout lock. Tree defeat still makes loadout editing unavailable.
- Runtime replacement stops the previous Branch, cancels its Branch-specific combat state, removes it, and instantiates the requested definition with the same stable slot identity. Replacements are combat-active immediately during a live Wave and remain stopped during Preparation until Continue. Shared archetype progress, Essence upgrades, and `slot_id + branch_id` talent builds remain owned by `BranchProgress` and survive replacement.
- Blossom replacement now explicitly removes its active petal projectiles and its source-specific Tree healing-over-time effect. Strength already guards delayed tween callbacks with `combat_enabled`, and Thorn Crown stops its cooldown, targets, talent state, and transient burst visuals. TREE safely discards stale freed runtime references during live refresh.
- Branch swaps do not pause SceneTree or reset WaveDirector, current Wave, enemies, enemy HP, tree HP, Forest Essence, Age, Tree Souls, loot, or pity.
- Thorn Crown remains a persistent Legendary Branch Seed unlock stored through `BranchSeedService` at `user://branch_seed_unlocks.cfg`. Persistent unlock is intentional and remains distinct from equipment: fresh Standard defaults are Strength, Blossom, Strength, Blossom; fresh Apex is initialized EMPTY; unlocking or reloading Thorn Crown never auto-equips it.
- The dedicated Apex BranchMount moved from zero offset to `(0, -170)`. Its effective Y is `-238.4` at sapling growth and `-265` at mature growth, compared with upper Standard mount Y values `-202.4` and `-215`. Apex is therefore above both LeftUpper and RightUpper throughout growth, remains centered, and Thorn Crown is parented to `AttachmentPoints/Apex/BranchMount` as the tree crown.
- The live loadout integration test uses a temporary Seed save, proves unlock persistence after reload without auto-equip, exercises Preparation and live Standard replacement, restores a saved per-slot Blossom talent build, cancels Blossom projectile/HoT ghost state, equips and attacks with Thorn Crown during the same Wave, and removes the Apex without resetting gameplay state.
- Godot 4.7.1 headless import passed. Live Branch Loadout Switch, TREE Branch Picker, TREE Apex Picker, Loadout Preparation, Apex Slot Rules, Apex Branch Loadout, and TREE Screen passed twice after their final changes. Standard Branch Loadout, Strength and Blossom Talent Effects, Thorn Crown runtime and visual, TALENTS Tab, Branch Seed Loot, Thorn Crown Guardian Grove Loot, Branch Seed Drop Notification, Enemy Runtime, Root Slam, and Colossal Quake passed their required regression runs. Expected warnings were limited to existing negative save-path and unknown-notification fixtures.
- Boss abilities and balance, Branch Seed chances, Tier I pity threshold and gains, loot pools, Branch progression semantics, Tree Souls, enemy data, and the Guardian Grove wave schedule are unchanged.

### Equipment Foundation V1

- `ItemDefinition` is immutable shared content with a stable `item_id`, display name, description, equipment slot, and optional null-safe icon metadata. Definitions are registered and indexed through the existing `ContentRegistry`, validated by `ContentValidator`, and exposed by `GameContent`; no parallel registry or new autoload was added.
- `ItemInstance` is independent mutable per-item data with a stable `instance_id`, `definition_id`, Item Level (minimum 1), equipment rarity, zero or more `ItemAffixRoll` values, and lock state. `definition_id` resolves shared content while `instance_id` identifies one concrete item. Rolled state never mutates the shared `ItemDefinition` Resource.
- `ItemAffixRoll` currently stores only a stable `stat_id` and numeric `value`. There is no affix database, pool, weighting, count rule, or generator yet.
- Equipment rarity has exactly four stable values: Common (`common`), Uncommon (`uncommon`), Epic (`epic`), and Legendary (`legendary`), with centralized display names and prototype gray, green, purple, and gold colors. Equipment rarity is independent from Legendary Branch Tier I-III; `rare` and `ancient` are not valid equipment rarities.
- Foundation equipment slots are Bark (`bark`) and Roots (`roots`) only. Heartwood, Canopy, Sap, and Soul Relic remain planned but are not production-supported slots in this checkpoint.
- The first production definitions are Living Bark (`living_bark`, Bark) and Deep Roots (`deep_roots`, Roots). They are registered in `GameContent`, but do not drop, cannot be equipped by the player, and apply no gameplay stats.
- Added deterministic smoke coverage for definitions, slot and rarity rules, registry lookup/rebuild, duplicate IDs, invalid entries, mutable instance independence, shared-definition safety, and equipment-rarity versus Branch-Tier separation.
- Not implemented: inventory, comparison, equip/unequip, item drop generation, auto-loot, equipment UI, equipment stat application, persistence, crafting, dismantle, reroll, unique Legendary effects, or Soul Relic gameplay.

### Inventory & Equipment V1

- `InventoryService` is an in-memory authority over concrete `ItemInstance` objects keyed by stable `instance_id`. It rejects duplicate instance IDs, invalid instance data, unknown definitions, and unsupported slots without mutation or signals. It exposes stable-ID lookup, removal, counts, full collection reads, and filtering through each `ItemDefinition.equipment_slot_id`. Production inventory starts empty.
- `EquipmentService` stores only Bark and Roots slot mappings to concrete inventory `instance_id` values. Both slots start EMPTY. Equip derives compatibility from the shared definition, replacement preserves both old and new items in Inventory, unequip removes only the slot reference, and removing an equipped inventory item safely clears that slot.
- Equip, replacement, and unequip preserve the same mutable `ItemInstance`; no operation copies an item, uses `definition_id` as concrete identity, changes lock state, or mutates shared `ItemDefinition` content. Locked items remain equipable. Inventory and equipment survive MainWorld recreation within one process but have no disk persistence.
- TREE now has distinct BARK and ROOTS selectors at the trunk and roots. Equipment mode replaces the Branch detail and Seed panels with an equipment detail/comparison panel and a scrollable, slot-filtered inventory panel. Returning to any Standard or Apex slot restores the original Branch UI and safely closes conflicting picker interaction.
- Equipment detail presents currently equipped versus selected item facts: display name, centralized rarity text/color, Item Level, and humanized affix values. It does not calculate power scores, recommendations, deltas, effective HP, DPS, or stat-application previews.
- Inventory candidates are independently keyed by `instance_id`, so multiple pieces from one `ItemDefinition` remain distinct. UI ordering is deterministic: rarity descending, Item Level descending, display name, then instance ID. Empty Bark and Roots states provide explicit messages and disabled actions.
- TREE refreshes from `item_added`, `item_removed`, and `equipment_slot_changed` signals without frame polling. Removed candidates clear stale selection. Equip/unequip works during Preparation and active Waves while the tree is alive; tree defeat keeps browsing available but disables mutations.
- Equipment operations never pause SceneTree, restart WaveDirector, remove enemies, or reset combat state. Equipment gameplay effects are provided separately by Equipment Stat Application V1.
- Not implemented: enemy item drops, Item Level or rarity generation, affix generation, auto-loot, persistence, crafting, dismantle, reroll, Legendary unique effects, Heartwood, Canopy, Sap, or Soul Relic.

### Equipment Stat Application V1

#### Supported Equipment Stats

- `maximum_health` is flat Maximum HP.
- `health_regeneration` is flat HP per second.
- `branch_damage` is percentage global Branch Damage.
- `attack_speed` is percentage offensive Branch Attack Speed.

Percentage values use fractional storage: `0.10` means +10%. Duplicate rolls and Bark plus Roots values are summed inside the Equipment source before its percentage multiplier composes multiplicatively with other RunModifier sources. Item Level, rarity, and lock state do not rescale an already rolled affix value. Unknown non-empty affixes remain valid item data, are ignored by gameplay, and retain the generic factual UI fallback.

#### Runtime Architecture

`EquipmentService` remains the in-memory authority for slot-to-`instance_id` ownership. The new `EquipmentStatService`, registered once as the `EquipmentStats` autoload after `Equipment`, listens to `equipment_slot_changed`, performs an initial rebuild, aggregates supported affixes from all equipped Bark and Roots instances, and exposes `rebuild_from_equipment()`, `get_total_affix_value()`, and `get_all_total_affix_values()`. Its `equipment_stats_changed` signal is emitted only after a completed rebuild.

Equipment projection uses the dedicated RunModifiers source `equipment`. A rebuild clears only that source, never calls `RunModifiers.clear_all()`, and therefore preserves Tree Soul, external, and future sources. Flat health regeneration uses the new `TREE_FLAT_REGEN` ID rather than overloading percentage `TREE_REGEN_RATE`. Rebuilds are idempotent, and the autoload state plus initial modifier projection remains correct across MainWorld recreation.

#### Tree Integration

The Tree remains the authority for final Maximum HP and regeneration. Equipment Maximum HP enters the existing `TREE_MAX_HEALTH` additive path; a dedicated equipment refresh preserves the current-health ratio at full, damaged, and non-round health values. Repeated equip/unequip cannot heal the Tree, and a dead Tree remains at zero HP and dead while its maximum changes.

Final regeneration combines the existing flat Tree Essence upgrade, Equipment `TREE_FLAT_REGEN`, and the existing percentage-of-maximum-health `TREE_REGEN_RATE`, with the existing non-negative clamp intact. Verdant and other Tree-health modifier sources continue composing through RunModifiers without duplicated Soul logic.

#### Branch Integration

Equipment Branch Damage flows through `BranchStatCalculator` and therefore affects Strength damage, Blossom petal damage, and Thorn Crown damage while preserving Essence upgrades, talents, and other modifier sources. Equipment Attack Speed uses the existing offensive cooldown calculation for Strength, Blossom ranged attacks, and Thorn Crown. Strength and Thorn Crown refresh their Timer `wait_time` when equipment stats change; Blossom reads its current ranged interval when scheduling the next attack countdown. Existing minimum cooldowns remain enforced, and Blossom healing amount and healing tick interval are unchanged.

#### UI and Runtime Safety

TREE uses `EquipmentStatRules` for centralized display names and formatting: `+20`, `+0.5/s`, `+10%`, and `+15%`. Its current-versus-selected comparison remains factual; no power score or recommendation was added. Equip, replacement, unequip, and removal of an equipped item rebuild immediately during Preparation or a live Wave without pausing SceneTree, resetting WaveDirector, removing enemies, or bypassing the existing tree-defeat UI lock.

Production Inventory still starts empty and no starter item, item drop, item generator, rarity roll, affix generator, affix pool, percentage-HP affix, Defense, damage reduction, Range, Healing Power equipment, Essence Gain equipment, Tree Soul Power equipment, unique Legendary effect, or equipment persistence was added.

Deterministic Equipment Stat Rules and Equipment Stat Application smoke tests cover fresh state, aggregation, duplicate affixes, unknown affixes, exact rolled-value semantics, stacking, external-source survival, replacement, unequip, equipped-item removal, idempotence, MainWorld recreation, health-ratio preservation, dead-tree safety, actual regeneration, all three damage paths, all three offensive timing paths, timer refresh, and unchanged Blossom healing timing. TREE Equipment coverage verifies the four known formats, generic unknown formatting, factual comparison, Preparation/live-Wave behavior, defeat gating, and no SceneTree or Wave reset.

### Basic Equipment Loot V1

#### Enemy Equipment Rewards

- Bark Beetle and Bark Runner each have a 1% equipment drop chance, minimum Common, no guarantee, and no Item Level bonus.
- Bark Warden has one guaranteed equipment reward per stage/global-Wave/enemy encounter, minimum Uncommon, with +2 Item Levels.
- Ancient Bark Colossus has one guaranteed equipment reward per encounter, minimum Epic, with +4 Item Levels.
- The left and right runtime instances share one encounter guarantee. The guarantee key is `stage_id + global_wave + enemy_id`, survives ordinary Retry in the current process, and is claimed only after successful Inventory insertion.
- Equipment rewards are independent from Branch Seed rolls and pity. A boss may grant both rewards from the same death without either system modifying the other.

#### Item Level and Rarity

Prototype Item Level is `1 + floor((global_wave - 1) / 10)`, minimum 1, plus the enemy source bonus. Wave 1 and Wave 10 normal drops are Item Level 1, Wave 11 is Item Level 2, Wave 50 Bark Warden is Item Level 7, and Wave 100 Ancient Bark Colossus is Item Level 14. Tree Age is not used.

Random rarity weights are Common 78, Uncommon 20, Epic 2, and Legendary 0. Enemy minimum rarity filters lower entries before the remaining weights are used. `ItemRarityRules` still contains Legendary for future content, but Basic Equipment Loot V1 never randomly generates it. Rarity affects rolled values only during generation: Common ×1.00, Uncommon ×1.25, and Epic ×1.50, followed by a seeded ±10% variance.

#### Affixes and Generation

Common items receive one affix; Uncommon and Epic receive two distinct affixes. Deep Roots uses Maximum Health and Health Regeneration. Living Bark temporarily uses Branch Damage and Attack Speed as a prototype pool until a future Defense/damage-reduction system exists; this is not the final thematic Bark design.

Centralized formulas use Item Level `L`: Maximum Health `(8 + 2L)` rounded to whole HP; Health Regeneration `(0.15 + 0.04L)` rounded to 0.05 HP/s; Branch Damage `(0.03 + 0.004L)` and Attack Speed `(0.03 + 0.003L)` rounded to 0.005 fractional steps. Each base value is multiplied by rarity and variance before rounding.

`EquipmentItemGenerator` selects a valid production Bark/Roots `ItemDefinition` from `GameContent`, then creates a new mutable `ItemInstance` with rarity, Item Level, affixes, and `is_locked = false`. It never mutates definitions or creates a parallel registry. `EquipmentLootService` owns a monotonic identity counter such as `equipment_loot_000001`, checks Inventory for collisions, reconciles the counter after save restore, inserts the result automatically, and emits `equipment_item_dropped` only after successful insertion. Items are never auto-equipped.

#### Reward Context and Presentation

`WaveDirector` writes the current global Wave into `EnemySpawnRequest`; `SpawnDirector` passes it with the exact `StageDefinition` into each enemy's reward context. Enemy death preserves XP and physical Forest Essence rewards, then processes Branch Seed and equipment rewards as independent siblings.

`UI/EquipmentDropNotification` listens to `EquipmentLoot`, presents EQUIPMENT FOUND, item name, centralized rarity color, Item Level, centralized affix formatting, known enemy source, and “Available in TREE”. It is horizontally centered directly below Tree HP with separate space before the Branch Seed notification, ignores mouse input, and never pauses combat. A bounded FIFO queue retains at most five pending presentations, drops the oldest pending entry on overflow, and never removes the corresponding Inventory item. There is no physical equipment pickup.

Inventory continues to start empty. A natural or forced drop triggers the existing `Inventory.item_added` signal, so an already-open TREE equipment panel refreshes without a direct loot-to-UI dependency. Automated coverage verifies formulas, rarity minima, distinct affixes, deterministic RNG, 100 collision-free IDs, W50/W100 guarantees, left/right and Retry suppression, failed insertion rollback, no auto-equip, generated EquipmentStats effects, actual enemy death integration, live TREE refresh, notification content/queue, and simultaneous non-overlapping Seed/equipment presentation.

Not implemented: Legendary unique equipment, Defense, damage reduction, materials, Garden loot, pet loot, Soul Relic, physical item pickup, loot filter, auto-dismantle, inventory capacity, crafting, reroll, or explicit Stage equipment loot pools.

### Gameplay Feel & Inventory Expansion V1

Checkpoint date: 2026-08-13.

#### Equipment Notification

- Equipment reward presentation is now horizontally centered in the screen with a short scale/fade/drift treatment and rarity border. The existing bounded sequential queue and approximately three-second timing are preserved.
- It remains non-blocking, ignores mouse input, and never pauses gameplay. The Branch Seed notification remains independent and can be visible simultaneously without pixel overlap.

#### Inventory Overview

- TREE now exposes a one-click `INVENTORY` entry point and a global all-items view in its main central area. A dynamic `ScrollContainer` plus three-column grid displays every concrete `ItemInstance` independently by `instance_id`.
- Cards show display name, rarity, Item Level, equipment slot, affix summary, LOCKED when applicable, and EQUIPPED from `Equipment.is_item_equipped(instance_id)`. Sorting is centralized rarity rank descending, Item Level descending, display name, then instance ID.
- Required filters are ALL, BARK, ROOTS, HEARTWOOD, CANOPY, and SAP. Empty states are safe and explicit.
- Selecting a card shows its full factual detail and the currently equipped item in the same slot. Existing `EquipmentService` performs equip, replacement, and unequip; no score or Better/Worse judgment was added.
- `Inventory.item_added`, `item_removed`, and `Equipment.equipment_slot_changed` refresh the open view without polling. A valid selected instance survives live drops.
- The layout leaves room for later management actions, but scrap, dismantle, materials, crafting, and inventory capacity are intentionally not implemented.

#### Equipment Slots and Content

- Production slots are Bark, Roots, Heartwood, Canopy, and Sap. All five default to EMPTY and derive from `EquipmentSlotRules`; `EquipmentStatService` aggregates every equipped slot. Soul Relic remains future-only and is not supported.
- New registered definitions are Elder Heartwood (`elder_heartwood`), Verdant Canopy (`verdant_canopy`), and Luminous Sap (`luminous_sap`). `GameContent.get_items()` now returns Living Bark, Deep Roots, Elder Heartwood, Verdant Canopy, and Luminous Sap.
- Prototype affix pools are Bark: Branch Damage / Attack Speed; Roots: Maximum Health / Health Regeneration; Heartwood: Maximum Health / Branch Damage; Canopy: Branch Damage / Attack Speed; Sap: Health Regeneration / Attack Speed.
- Bark's pool remains temporary until a real Defense identity exists. No Defense, Healing Power, Range, Essence Gain, or Tree Soul Power equipment stat was added.
- Successful equipment drops choose uniformly from the five valid registered definitions. Normal 1% drop chance, Warden/Colossus guarantees, affix counts, formulas, and Legendary generation weight 0 remain unchanged.

#### Thorn Crown Readability

- Every real Thorn Crown attack activation now starts one 0.28-second procedural bilateral snap/pulse with arm extension, small scale pulse, and brighter wood/thorn/leaf flash. Overgrowth may use the simple 1.2 intensity variant.
- No-target cooldown ticks do not animate. Presentation cleanup kills and resets the Tween during `stop_combat()`, replacement, defeat, or node removal.
- Damage, cooldown, range, Burst Radius, targeting, and attack timing are unchanged.

#### Wave Pacing

- Waves 1–10 require strict clear. Waves 11–25 may launch the next adjacent normal Wave at at most 20% survivors; Waves 26–49 at 30%; Wave 51+ at 35%.
- Overlap begins only after the current Wave finishes spawning. At most two adjacent normal cohorts may be active. A third cannot launch until the oldest cohort completes.
- Miniboss/boss Waves cannot overlap in or out. Substage/Preparation boundaries are hard barriers, so W50, W100, rewards, completion, and Preparation retain their encounter ordering.
- `EnemyTracker` indexes live enemies by origin global Wave without per-frame node scanning. `WaveDirector.current_wave` means the newest launched Wave, while completion is queued and finalized in global-Wave order.
- Age advances only from ordered first-time completion. Every enemy retains its origin Wave for health/damage spawn scaling and reward context, including equipment Item Level and boss guarantee keys. Retry clears cohort runtime and tracked enemies without changing guarantee anti-farm state.

#### Unchanged and Not Implemented

- Enemy HP, speed, damage, XP, Forest Essence, boss ability values, Branch balance, Branch Seed loot/pity, Tree Souls, Guardian Grove schedule data, and equipment drop rates are unchanged.
- Not implemented: save/persistence, scrap, materials, crafting, reroll, inventory cap, auto-dismantle, Defense, Soul Relic, Legendary equipment effects, or additional Stage loot pools.

#### Recommended Next Work

1. Manual pacing and Inventory UX playtest.
2. Save & Persistence Foundation V1.
3. Inventory Scrap & Materials V1.
4. Bark Defense identity.
5. Legendary Equipment V1 only after the common loot and Inventory loop is stable.

### Save & Persistence Foundation V1

Checkpoint date: 2026-08-14.

#### SaveGame

- `SaveGame` is the final gameplay-service autoload and central persistence orchestrator. Runtime ownership and validation remain in `Inventory`, `Equipment`, `BranchProgress`, `BranchLoadout`, and the independent `BranchSeeds` service.
- The single local player slot is `user://player_progress.cfg` with `SAVE_VERSION = 1`. Startup automatically restores valid data before MainWorld creates runtime Branches.
- Restore order is Inventory, Equipment, Branch Progress/talent builds, then Branch Loadout, followed by an idempotent EquipmentStats rebuild and equipment-loot instance-counter reconciliation.
- Inventory add/remove, Equipment equip/unequip, and Branch Loadout changes request autosave. Branch Progress changes share one 0.75-second one-shot coalescing timer.
- Public `save_now()`, `request_save()`, `load_now()`/`reload_from_disk()`, initialization, and debug test-path override APIs exist. Current-version reload replaces persistence-owned runtime state instead of appending duplicates.
- Missing files are a valid fresh state. Corrupt/malformed or unsupported-version files fail without partial restore. Future versions disable writes so an older build cannot overwrite them. There is no modal error UI.

#### Persisted Inventory and Equipment

- Every saved `ItemInstance` stores textual `instance_id`, `definition_id`, Item Level, equipment rarity, lock state, and each affix's textual stat ID plus full float value.
- Restore creates new runtime `ItemInstance` and `ItemAffixRoll` objects, resolves immutable definitions through `GameContent`, skips invalid/unknown entries with warnings, and retains the first valid duplicate instance ID.
- Multiple instances of one definition retain independent identity, levels, rarity, affixes, and lock state.
- Equipment stores the five mappings for Bark, Roots, Heartwood, Canopy, and Sap through `EquipmentSlotRules`. Missing, unknown, or wrong-slot references restore EMPTY and are never remapped.
- Inventory continues to own every equipped item. Equipment references only concrete Inventory `instance_id` values. Restored EquipmentStats and Maximum Health modifiers are available before a new Tree initializes.
- `EquipmentLoot` reconciles its monotonic `equipment_loot_######` counter against restored Inventory. Boss guarantee claims intentionally remain process-local because there is no persistent run identity.

#### Branch Progress, Talent Builds, and Branch Loadout

- Shared Branch Progress persists by `branch_id`: XP, level, total earned Talent Points, and definition-validated upgrade levels. Available Talent Points remain derived rather than saved.
- Talent builds persist independently by `slot_id + branch_id`; unknown talent IDs are ignored without erasing other valid selections.
- Branch Loadout persists all four Standard slots plus Apex. Valid partial Standard loadouts restore before current default initialization fills missing slots. A fresh save still produces Strength/Blossom/Strength/Blossom and Apex EMPTY.
- Restored Apex definitions must be valid Legendary Apex content and already unlocked in `BranchSeeds`; player save data cannot bypass the Seed gate.
- Branch Seed unlock IDs and tier pity remain exclusively in the unchanged `user://branch_seed_unlocks.cfg` version-2 save. Loading player progress never emits Branch Seed or Equipment Drop acquisition notifications.

#### Inventory Grid and Tree Equipment Tiles

- Global TREE Inventory is a scrollable five-column compact tile grid containing only unequipped concrete items. ALL/Bark/Roots/Heartwood/Canopy/Sap filters derive from `EquipmentSlotRules` after equipped items are excluded.
- Tiles show an icon area, short name, centralized rarity color, Item Level, slot identity, and LOCKED marker. Affixes remain in the selected detail/comparison panel rather than filling each tile.
- `ItemDefinition.icon` is used automatically when present. Null icons receive a slot-aware BARK/ROOT/HEART/CANOPY/SAP fallback; icon art and texture references are not persisted.
- The five Tree equipment positions are compact item-slot tiles. Empty slots identify their type and EMPTY state; occupied slots show the same icon/fallback, rarity, and Item Level presentation without an EQUIPPED badge.
- Clicking an occupied Tree tile selects its concrete item and exposes UNEQUIP. Clicking an empty tile opens that slot context. Equip hides the tile from Inventory and shows it on the Tree; replacement returns the prior item to sorted Inventory; unequip returns the current item. These are presentation changes only—Inventory ownership never changes.
- `item_added`, `item_removed`, and `equipment_slot_changed` refresh open UI without polling. Restored available and equipped items are visible correctly on first TREE open.

#### Equipment Drop Presentation

- Equipment Drop Notification remains horizontally centered, queued, rarity-colored, animated, input-ignoring, and non-pausing.
- Its top edge is Y 90, 22 px below the Tree HP bar's Y 68 bottom edge. Its bottom edge is Y 310, leaving 20 px before the independent Branch Seed notification begins at Y 330.

#### Not Persisted or Implemented

- Not persisted: active Wave/cohorts/enemies, enemy HP, Tree HP, Age, highest completed Wave, Forest Essence, Tree upgrades, Tree Soul selection/rank, Preparation, Stage/Substage, equipment guarantee claims, and offline progress.
- Not implemented: Run Resume, save slots, Load Game/Delete Save UI, cloud/Steam Cloud, scrap, dismantle, materials, crafting, reroll, auto-dismantle, inventory cap, Defense, Soul Relic, Legendary equipment effects, or offline progress.

#### Recommended Next Work

After a manual save/load and Inventory visual playtest, choose either Run Save & Resume V1 or Material Loot & Scrap V1.

### Strength Full Talent Tree V1

Checkpoint date: 2026-08-17.

- Strength is the first production five-layer talent graph: 27 one-point talents across required levels 2, 4, 7, 10, and 14. Each slot retains its independent `slot_id + branch_id` build while XP, level, earned-point budget, and Essence upgrades remain shared by archetype.
- The mutually exclusive fork pairs are Cleaver/Earthbreaker, Disruptor/Protector, and Executioner/Relentless. Roots do not conflict, so five earned points can complete one root-to-capstone specialization or form any valid prerequisite-respecting split build. The current graph does not yet consume the full 12-point Level 375 budget; later content expansion will add valid uses without weakening prerequisites or conflicts.
- All runtime counters, target snapshots, combo state, interrupt counts, and pending sequences belong to the physical Strength instance. Talent damage uses the current Strength damage pipeline and `AttackResolver`; delayed Aftershock/Combo/Flurry work revalidates targets and is invalidated by combat stop or replacement.
- Persistence remains `SAVE_VERSION = 1`: the stored schema is still a list of stable `purchased_talent_ids` under `slot_id + branch_id`. Old root-only saves load unchanged, new IDs default unpurchased, unknown IDs are skipped without losing other valid state, and repeated load remains idempotent.

The six complete paths are:

- Crusher / Cleaver: Sweeping Strike → Cleaver → Serrated Arc → Reaping Sweep → Whirling Bough.
- Crusher / Earthbreaker: Sweeping Strike → Earthbreaker → Fault Line → Aftershock → Worldroot Slam.
- Warden / Disruptor: Rebuff → Disruptor → Staggering Blow → Disruptive Arc → Uproot.
- Warden / Protector: Rebuff → Protector → Hold the Line → Sentinel Reflex → Last Bastion.
- Duelist / Executioner: Marked Prey → Executioner → Cull the Weak → Finishing Rhythm → Final Cut.
- Duelist / Relentless: Marked Prey → Relentless → Pursuit → Unbroken Combo → Relentless Flurry.

Crusher preserves the original 60% Sweeping Strike. Cleaver permits two secondary targets, Serrated Arc adds one fresh 45% continuation, Reaping Sweep adds at most one 60% fresh hit after a sweep kill, and every fourth resolved primary becomes Whirling Bough's six-target Grand Sweep. Earthbreaker triggers every third resolved primary at 40%; Fault Line changes its selection to outward line geometry, Aftershock repeats half the shockwave damage after 0.25 seconds, and every third Earthbreaker trigger becomes the larger 70% Worldroot Slam with normal-enemy knockback.

Warden preserves the original 35px Rebuff. Disruptor cancels active attack cycles on normal enemies through a reusable `can_be_interrupted()` / `interrupt_attack()` seam; minibosses and bosses are immune by default. Staggering Blow doubles every third same-primary Rebuff, Disruptive Arc propagates successful interrupts to at most two normal enemies, and every fifth primary activates the non-damaging Uproot displacement. Protector prioritizes same-side enemies within the 250px tree danger radius. Hold the Line doubles danger Rebuff, Sentinel Reflex grants one half-cooldown follow-up after pushing a target out of danger, and Last Bastion dynamically expands the radius to 350px and uses 2.5× Rebuff at 35% Tree HP or lower.

Duelist preserves Marked Prey's five 10% stacks on primary attacks only. Executioner adds 50% damage at maximum stacks below 35% HP, Cull the Weak carries two stacks after a qualifying kill, every third maximum-stack hit becomes a Finishing Rhythm finisher, and Final Cut uses lethal resolved damage for normal enemies below 15% HP while bosses receive damage rather than an instant kill. Relentless carries half the previous stacks, Pursuit safely retains at most three weak recent-target snapshots for four seconds, and Unbroken Combo/Relentless Flurry schedule one/two non-recursive 35% follow-ups.

Procedural feedback distinguishes Earthbreaker, Worldroot Slam, Whirling Bough, Uproot, Finishers, and Final Cut without changing timing or hit logic.

### Talent Screen Graph

- Talent Screen now renders a definition-driven branching graph inside horizontal and vertical scrolling space. `TalentDefinition.tree_column/tree_row` is presentation-only shared content; trees without explicit coordinates use a generic required-level fallback, preserving the current Blossom and Thorn Crown prototype trees.
- Strength displays five rows and six fork columns. Prerequisite lines are generated from `prerequisite_ids`, not concrete talent names, and the general tree validator rejects prerequisite cycles.
- Nodes remain selectable for factual detail while visually distinguishing purchased, available, level/prerequisite locked, conflict locked, and no-point states. Conflicted alternatives stay visible and name the selected opposing specialization.

### TREE Navigation Polish

- The fullscreen header now keeps `TREE | INVENTORY` visible in both views, with the active tab disabled. Inventory can return immediately to the main Tree view without closing fullscreen or changing Branch loadout, Equipment, Inventory filters/data, Wave state, or pause state.
- Esc from Inventory returns to TREE. Esc from the main TREE view closes the fullscreen according to the existing Preparation restriction. The standalone TALENTS screen is unchanged as a separate fullscreen.

### Not Implemented Yet

- Talent Respec remains near-term work.
- Blossom full tree, Thorn Crown full tree, Thornshot, Status Effects Foundation, new enemies, Materials, Scrap, and Run Resume are not part of this checkpoint.

### Recommended Next Work

1. Blossom Full Talent Tree V1.
2. Thornshot Branch plus its full talent tree.
3. Enemy Variety V1: Armored Beetle, Spitter, and Swarm.
4. Status Effects Foundation plus Poison Branch.

### UI Cleanup, Talent Respec & Debug Progress Reset V1

Checkpoint date: 2026-08-17.

- Inventory grid cards, per-slot equipment candidates, equipped Tree tiles, and item detail/comparison text now use the ASCII-safe `ILvl N - Slot` format. Compact tile height, font sizing, content margins, and candidate spacing were adjusted while preserving definition icons, slot-aware text fallback, rarity colors, sorting, filtering, and concrete `instance_id` identity.
- The left TREE Branch detail is now a scrollable `VBoxContainer` flow. Shared progress, the current slot talent build, Essence upgrades, and effective stats size vertically instead of occupying overlapping fixed rectangles; loadout status and the Branch action remain fixed below the scroll area.
- `BranchProgress` owns individual talent refund validation and mutation. A purchased talent is refundable for free only when no purchased direct or transitive descendant depends on it; blocked selection reports `Locked by purchased descendants`. Successful refund restores its derived Talent Point budget immediately and refreshes runtime effects and UI.
- Talent Screen also exposes a confirmed `RESET TALENTS - SLOT N BUILD` action. It clears only the selected `slot_id + branch_id` loadout, preserves shared XP/Level/earned-point budget/Essence upgrades, and does not affect another physical slot using the same archetype.
- Refund and reset reuse the existing persisted `purchased_talent_ids` representation and autosave signal path. Reload preserves refunded/reset builds and other slot builds, so `SaveGame.SAVE_VERSION` remains `1`.
- Debug builds expose `RESET PROGRESS (DEBUG)` on TREE behind a confirmation dialog. The central `SaveGame` reset removes `player_progress.cfg` and the independent `branch_seed_unlocks.cfg`, clears Inventory, Equipment, EquipmentStats projection, Branch Progress/talent builds, Branch Loadout/Apex, Branch Seed unlocks/pity, process-local Equipment loot state, and Tree Soul runtime state, then reloads the current scene for the normal fresh Strength/Blossom/Strength/Blossom plus EMPTY Apex initialization.
- The long `BranchInfoLabel` debug/stat column was removed from normal gameplay HUD. Tree HP, Essence, Age/Wave information, upgrade tabs/panels, TALENTS, and TREE remain intact.

Not implemented in this checkpoint: scrap/materials, Run Resume, Blossom full talent tree, or new enemies.

Recommended next checkpoint: **Blossom Full Talent Tree V1**.

### Standard Branch Positional Compatibility + Poison Vine V1

Checkpoint date: 2026-08-21.

#### Standard Branch positional compatibility

- `BranchDefinition.standard_position_id` is immutable content data with the stable values `any_standard`, `lower_standard`, and `upper_standard`. `BranchSlotRules` remains the canonical authority for slot classification and placement.
- The canonical physical mapping is lower Standard Slots 1 and 3 (`standard_slot_1`, `standard_slot_3`), upper Standard Slots 2 and 4 (`standard_slot_2`, `standard_slot_4`), and the distinct Apex Slot 5 (`apex_slot`).
- Strength is authored `lower_standard` and is valid only in Slots 1 and 3. Blossom preserves its previous behavior through `any_standard`. Poison Vine is also `any_standard`. Standard content remains invalid in Apex, and Legendary content remains Apex-only through the existing category rule.
- `BranchLoadout`, `TreeBranchLoadoutController`, `CombatBranch`, SaveGame restore, TREE candidate filtering/confirmation, and ContentValidator converge on `BranchSlotRules`. The UI therefore never offers Strength for an upper slot, and low-level runtime assignment also rejects it.
- SaveGame remains version 1 because the stored schema did not change. A saved upper-slot Strength assignment is skipped and never instantiated; normal default initialization fills an uninitialized upper slot with Blossom when MainWorld is created. Valid lower Strength assignments restore. Shared Strength XP, Level, earned Talent Points, Essence upgrades, and historical `slot_id + branch_id` talent records are preserved. Positional rejection applies to physical equipment, while category-compatible historical talent records remain loadable.

#### Status Effects Foundation

- `EnemyStatusEffectComponent` is an enemy-owned runtime container. Each affected enemy owns its own mutable stacks, remaining duration, deterministic tick accumulation, periodic value, and weak application-source reference. Shared `StatusEffectDefinition` Resources remain immutable, and no global per-enemy status singleton exists.
- The reusable foundation implements refresh, duration-add, intensity-stack, and replace modes plus generic periodic damage through `AttackContext` and `AttackResolver`. Periodic damage carries `status_effect` and `periodic_damage` tags plus `status_effect_id` metadata; it is distinct from direct/basic projectile hits and does not recursively apply Poison.
- Enemy death, `stop_combat()`, forced cleanup, retry/wave teardown, and scene exit clear status state. Ticks revalidate the enemy immediately, and cleared or freed enemies cannot receive stale callbacks. A compact three-pip green indicator provides restrained stack feedback above the enemy HealthBar.
- Production currently registers only `poison`. Burn, Bleed, Slow, Vulnerability, and other future effects remain intentionally unimplemented until their associated content is designed.

#### Poison Vine

- Poison Vine is a production Standard Branch with stable `branch_id = poison_vine`. No Common Branch unlock system exists yet, so it follows the current Standard availability rule and appears immediately for every compatible slot. It does not use Legendary Branch Seeds, unlock itself, or auto-equip. Its stable identity is ready for future Common Branch acquisition integration.
- Base combat is 4 direct damage, a 1.80-second attack interval, a 0.60-second runtime floor, and 650 range. Blossom's authored ranged reach is also 650, so Poison Vine now engages approaching enemies at the same nominal practical distance instead of the previously proposed short 190-unit value. Both measure from the runtime Branch mount origin; Poison Vine retains outward-facing and preferred-lane filtering. Direct hits use `AttackResolver`, then apply one Poison stack only after damage resolves.
- Poison uses stable `status_effect_id = poison`, 4.0-second duration, 1.0-second ticks, 2 damage per stack per tick, and a maximum of three stacks. Every successful application below cap adds one stack and refreshes the full duration. At three stacks, another application remains at three and refreshes the full duration. One, two, and three stacks therefore deal 2, 4, and 6 damage per tick. A full uninterrupted four-second duration produces ticks at 1, 2, 3, and 4 seconds, then expires.
- Targeting first considers valid outward enemies below the Poison cap, prefers the current preferred lane, and among eligible enemies favors higher current health so the DoT is more likely to realize its value. It then uses the normal lane fallback. If every valid enemy is fully poisoned, it falls back to the established targeting profile behavior. The scan occurs only when the 1.8-second attack cycle requests a target, not per frame.
- Shared `poison_vine` archetype progress owns XP, Level, earned Talent Points, and Essence upgrades. Every physical instance owns its own cooldown, projectile collection, presentation tween, and current targeting work. Existing `slot_id + branch_id` talent-loadout persistence creates independent Poison Vine build records even though no Poison Vine talents are authored yet.
- Resource-authored upgrades are Venom Potency (+0.5 Poison damage per stack per tick, first cost 9, dynamic Branch Level cap), Toxic Persistence (+0.25 seconds, first cost 8, maximum 16 levels), and Application Speed (-0.08 seconds, first cost 10, maximum 15 levels and the 0.60-second runtime floor). Run Branch Damage affects direct damage and the Poison value applied by the Branch; Attack Speed affects the offensive application interval but not Poison tick rate or duration.
- The current visual is procedural placeholder art: a green living vine with alternating toxic thorns, a bright venom bulb at the true projectile endpoint, a brief attack pulse, and a distinct green toxic projectile. It mirrors from the actual `facing_side`, scales with Tree growth, and uses the unchanged canonical BranchMounts in all four Standard positions. Final production art is not complete.
- Poison Vine intentionally has no TalentTree Resource in this checkpoint. The existing progress service still creates independent slot loadout records. Recommended future work is **Poison Vine Full Talent Tree V1**.

#### Testing

- Added `poison_vine_status_smoke_test`, covering content registration/validation, malformed Poison data, all four Standard slots, Apex rejection, scene instantiation, left/right endpoint mirroring, Blossom-equivalent 650 range, approaching-enemy acquisition beyond melee distance from representative upper/lower and left/right mount offsets, direct damage, stack 1/2/3, cap, tick timing and scaling, below-cap and max-cap refresh, duration expiry, direct/tick source distinction, cleanup/no stale ticks, targeting preference/fallback, four physical instances, shared XP/upgrades, independent cooldown/projectile state, and independent per-slot talent-loadout records.
- Poison/status passed twice. Apex Slot Rules, Standard Branch Loadout, TREE Branch Picker, TREE Screen, TREE Apex Picker, live Branch replacement, SaveGame full round trip, SaveGame Branch Progress, Strength talent effects, Blossom talent effects, Blossom visual, shared Branch progress, per-slot talent loadouts, and Thorn Crown regressions passed in Godot 4.7.1.
- Godot 4.7.1 headless editor/import passed without parser, Resource, UID, or ContentValidator errors.
- Enemy Runtime passed after restoring the documented production `debug_start_global_wave = 0` value in `main_world.tscn`. The Strength Visual fixture now clears runtime BranchProgress at test start/end, matching the isolation used by other Branch tests, and passes without inheriting disk-loaded Strength Level or upgrades.
- Manual rendered MainWorld checks remain required for Strength lower-left/lower-right appearance, absence of Strength in both upper candidate lists, Poison Vine in all four Standard mounts, left/right mirroring, projectile origin, practical attack distance beside Blossom, Tree overlap, Tree growth presentation, and Poison stack-feedback readability. These were not claimed as visually verified.

#### Recommended next work

1. **Poison Vine Full Talent Tree V1**.
2. Add Burn, Bleed, Slow, or other Status Effects only when their associated content is designed.
3. Replace Poison Vine procedural placeholder visuals with final production art.
4. Implement a Common Branch Seed/unlock system and migrate Poison Vine availability through that system without using Legendary Tier/pity semantics.

### Blossom All-Standard-Mount Visual Compatibility

Checkpoint date: 2026-08-21.

- Blossom remains an `any_standard` gameplay archetype with unchanged healing, petal damage, talents, attack timing, targeting, and 650 range.
- `BlossomBranchVisual` now resolves its existing production sprite through Tree stage plus left/right mount side for every valid Standard slot. Slots 1 and 2 share the authored left-facing stage layout; Slots 3 and 4 share the right-facing layout. The canonical upper/lower `BranchMount` positions continue to own physical attachment, so no duplicate Blossom scenes or gameplay implementations were added.
- Lower-left, upper-left, lower-right, and upper-right Blossom instances all use `res://resources/branches/blossom/visuals/blossom_branch.png`; no valid Standard slot falls back to the old procedural branch drawing. Tree stages continue updating sprite position, scale, mirroring, rotation, and draw order without recreating the runtime Branch.
- Regression coverage verifies all four slots across Ages 1, 40, 80, and 200, left/right mirroring, upper/lower replacement, Poison Vine visual isolation, lower-only Strength rejection, and SaveGame restoration of production Blossom art in both lower slots.
- Manual rendered MainWorld verification remains required for final attachment, overlap, and composition quality in all four positions. Automated tests verify node/resource identity and transforms but do not establish final visual quality.

### Ranged Cross-Lane Assistance

Checkpoint date: 2026-08-21.

- `TargetingProfile.SideMode` is immutable targeting content with three reusable policies. `OWN_SIDE_ONLY` searches only the Branch's mounted side. `OWN_SIDE_PREFERRED` completes normal selection on the mounted side before considering the opposite side. `ANY_SIDE` scores all otherwise valid targets together without side preference.
- `CombatTargeting` centrally resolves the side search order and target membership relative to the supplied side origin. Each acquisition takes one candidate snapshot from `EnemyTracker` when available, with the existing target group as an isolated-fixture fallback; side and lane passes reuse that snapshot. Side policy remains separate from lane preference, range validation, and target scoring, so future Branches can reuse the policy without branch-ID conditionals.
- Strength is authored `OWN_SIDE_ONLY`. Its runtime profile is an instance-local copy of the definition profile, and both acquisition and delayed hit revalidation remain side-locked. Strength damage, cooldown, range, talents, and balance are unchanged.
- Blossom and Poison Vine are authored `OWN_SIDE_PREFERRED`. Blossom preserves its existing nearest-to-Tree selection and true 650-unit Euclidean range. Poison Vine evaluates below-cap stacks, higher current health, and normal fallback independently within each searched side; any valid own-side target therefore wins before a more desirable opposite-side Poison target.
- Opposite-side targets remain subject to the same alive/targetable/group/range and projectile revalidation as own-side targets. No assist-mode state is retained: every normal acquisition starts with the mounted side again, and a committed projectile is not cancelled merely because a new local enemy appears.
- Thorn Crown is authored `ANY_SIDE` to describe its bilateral identity, while its established independent left/right attack-cycle implementation remains unchanged.
- The focused cross-lane smoke test covers all three modes, invalid-mode validation, left/right Strength isolation, Blossom assistance from all four Standard mounts, own-side reacquisition, exact out-of-range rejection, cross-Tree projectile origin/target, Poison stack/health priority on the assisted side, Poison own-side precedence, right-to-left assistance, and cleanup. SaveGame round-trip coverage verifies restored Branches retain their definition-owned policies.
- Manual rendered MainWorld verification remains required for cross-Tree projectile composition and the live own-side-clear/reacquisition scenarios. Automated tests verify targeting and projectile state but do not establish final visual quality.

## 9. Known Gaps and Limitations

- There is no active-run resume system; Save Foundation V1 persists stable player progression only.
- TREE supports live standard and unlocked Apex Branch replacement while the tree is alive; player-facing unequip and standard Branch unlock progression do not exist.
- There is no talent copy-build or save-preset flow.
- Tier data and the first miniboss/boss encounters are implemented. Five-slot inventory, equipment UI, activation, the first four equipment stats, and Common-to-Epic item loot generation exist.
- There is no `CampaignDefinition`.
- Stage 2 is currently only the repeated Guardian Grove Resource, not a second authored Stage Resource.
- All ten Guardian Grove Substages currently share one schedule; later Substages are not yet differentiated.
- Automated tests did not physically play all 1,000 Waves in a Stage.
- The `X-Y-Z` HUD mapping is covered by data/runtime tests, but its rendered presentation still needs manual visual confirmation.
- Bark Runner's placeholder appearance still needs manual visual confirmation.
- `bark_runner.gd` currently inherits the shared runtime behavior from the Bark Beetle root script and overrides only drawing; separating a generic enemy root base is outside this checkpoint.
- Plan item 40 is only partially complete because the smoke test validates the enemy runtime foundation rather than a full combat-integration scene.
- Poison is the first registered StatusEffect; Burn, Bleed, Slow, Vulnerability, and other effect content are not implemented.
- Strength, Blossom, and Thorn Crown have separated visual and talent-effect responsibilities. Their runtime dispatchers remain Branch-specific rather than a global universal effect system.
- A shared Branch visual base does not yet exist and is not needed for the current three implementations.
- Branch category data, Slot 5 rules, disk-backed Apex loadout, persistent Branch Seed unlock storage, the legendary drop-processing foundation, natural production Thorn Crown acquisition, and a non-blocking acquisition notification exist. There is still no physical loot object or separate player-facing Apex unequip action.
- There is no found-versus-equipped Apex Branch comparison.
- Bark Warden and Ancient Bark Colossus now have their first unique abilities, but there is no dedicated boss health-bar or encounter-intro UI and no additional boss ability set.
- Normal enemies can drop Bark/Roots equipment at the production 1% chance; no material, Garden, pet, or Soul Relic loot exists.
- The production Guardian Tree sprites contain the dormant gray Soul Core from Age 1. A separate colored world-space Soul overlay remains future work.
- A service-level prestige reset hook exists, but there is no integrated player-facing prestige flow.
- Gameplay scripts contain extensive prototype debug logging.
- Guardian Grove, the current enemy roster, and the Guardian Tree now use production pixel-art foundations; some Branch/UI visuals and audio remain prototype or future work.
- Schedule validation has automated negative fixtures, but broader ContentValidator failure presentation has not been manually exercised in the editor.

### Balance Note

Enemy HP and damage now scale proportionally from each enemy's base values. The approved no-upgrade playtest reached Wave 47, within the intended early-game wall of approximately Waves 40–50. The next balance evidence should come from a normal run with natural upgrade purchases and from reviewing the Forest Essence economy under the higher enemy counts.

### Approved Long-term Branch Plan

The approved roster target is 20 Branch archetypes: 13 standard Branches and seven legendary Branches. Slots 1–4 accept only standard Branches. Slot 5 is the Apex Slot: its attachment point and category rules accept exactly one legendary Branch placed at the top of the tree. Thorn Crown is the first implementation of the bilateral Apex gameplay model. Legendary Branch Seeds are planned as enemy loot or unlocks.

The first legendary concepts are:

- Thorn Crown: implemented as one naturally obtainable bilateral area-damage Apex Branch; production currently drops Tier I while ownership supports Tier I-III.
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

The next recommended work is:

1. Implement **Blossom Full Talent Tree V1**.
2. Perform a short manual UI playtest of inventory readability, long TREE builds, talent confirmations, and the debug fresh-start flow.
3. Revisit Run Save & Resume V1 or First Material Loot & Dismantle Foundation after the Blossom checkpoint.
4. Add the first real Bark defensive stat in a later focused checkpoint.

Active-run resume, prestige integration, later talent tiers, Status Effects, and the persistent Tree Soul orb remain later known gaps.

## 12. Handoff Checklist

- Read the root `AGENTS.md`.
- Read `docs/CURRENT_STATUS.md`.
- Run `git status --short` and verify the working tree is clean before starting a new task.
- Run `git log -1 --oneline` and review the current HEAD.
- Expected baseline branch: `main`.
- Implementation parent for this checkpoint: `169f667`.
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
