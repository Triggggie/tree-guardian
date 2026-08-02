# Tree Guardian — Current Project Status

Updated: 2026-08-02

Implementation parent for this checkpoint: `ffdb880a9d3558c8b0167f9754d9005c42089c4b` (`Add current project status handoff`)

Checkpoint commit: `Refactor enemy and wave runtime to data-driven architecture`

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
- Tree death stops the active combat cycle and opens a defeat panel. The player can retry immediately, or the tree revives automatically after a 10-second countdown. The stage restarts at Wave 1.
- Normal death preserves in-memory long-term run progression: Age, Forest Essence, Branch XP and levels, purchased branch upgrades and talents, tree upgrades, and the selected Tree Soul and rank.

The prototype has no save/load system, so this preserved state lasts only for the running game process.

## 3. Branches

### Strength

Strength is a close-range offensive branch using preferred-lane targeting with fallback behavior. Its base attack deals 10 damage with a 1.5-second cooldown; the runtime minimum cooldown remains 0.45 seconds.

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

Talent metadata comes from `TalentDefinition` Resources, but these three combat effects are still implemented directly in `strength_branch.gd`; `effect_ids` are not yet dispatched by a generic effect system.

### Blossom

Blossom is a support/ranged branch with its own scene. It heals the tree for 3 HP every 2.0 seconds and fires petals for 3 base damage every 2.0 seconds. Its targeting profile permits any lane.

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
- `WaveDefinition`
- `StageDefinition`
- `StatusEffectDefinition`
- `TargetingProfile`

The current authored content consists of two BranchDefinition Resources, six UpgradeDefinition Resources, one Strength TalentTreeDefinition with three TalentDefinition Resources, four TreeSoulDefinition Resources, one EnemyDefinition, one repeating StageDefinition, and one WaveDefinition template. Definitions own stable IDs, presentation text, ordered relationships, and balance values. Runtime nodes own mutable health, combat state, progression, and wave-cycle state.

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
- 40 — enemy runtime smoke test partially completed; it covers the current runtime foundation but is not yet a full combat-integration test scene.

Current runtime ownership:

- `EnemyTracker` owns the authoritative scene-local set of live enemies.
- `LaneRegistry` owns cached queue columns per formation side and lane.
- `EnemyHealthComponent`, `EnemyAttackComponent`, and `EnemyMovementComponent` own their isolated mechanics.
- `EnemySpawnRequest` is the typed, validated spawn-batch input.
- `SpawnDirector` owns instantiation, shared lane counters, queue order, cadence, and crowd formation.
- `WaveDirector` owns global wave/stage state, Resource-driven scaling and timing, enemy waiting, and asynchronous cycle cancellation.
- `WaveManager` coordinates tree death, retry, enemy cleanup, Age side effects, and public UI signal relay.
- `EnemyDefinition`, `WaveDefinition`, `StageDefinition`, and `ContentRegistry` provide the registered data and lookups.

Current authored enemy/wave data:

- Enemy ID: `bark_beetle`.
- Stage ID: `guardian_grove`.
- Wave template ID: `standard_bark_beetle`.
- Guardian Grove has 100 wave slots and repeats indefinitely as consecutively numbered Stages.
- Enemy counts, HP, damage multiplier, spawn interval, completion-message duration, and time after each wave are Resource-driven.

## 5. ContentRegistry and GameContent

`resources/content_registry.tres` currently registers exactly two branches in UI/gameplay order—Strength then Blossom—four Tree Souls—Crimson, Azure, Golden, and Verdant—one Bark Beetle enemy, and one Guardian Grove Stage. The top-level status-effect list remains empty.

`ContentRegistry` rebuilds stable lookup indexes for top-level branch, Tree Soul, enemy, stage, and status-effect IDs. Nested content uses owner-scoped indexes:

- `branch_id + upgrade_id`
- `branch_id + talent_id`
- `stage_id + wave_id`

Talent tree IDs remain global. The first valid item wins when a duplicate is encountered during indexing. Dictionary indexes provide lookups, while ordered list APIs return the original Resource arrays so UI and gameplay order remains data-defined.

`GameContent` exposes explicit typed access to branches, upgrades, talent trees, talents, Tree Souls, enemies, stages, and waves. The standard Bark Beetle Wave is indexed within Guardian Grove. Missing registry or unknown IDs safely return empty arrays or `null` as appropriate.

## 6. Content Validation

`ContentValidator` validates the original Resource arrays rather than relying only on indexes that retain the first duplicate. Current checks cover:

- top-level definition types, validity, empty IDs, and duplicate IDs;
- Branch scenes, targeting profiles, scoped upgrades, and upgrade validity;
- optional talent trees, globally stable talent tree IDs, scoped talents, prerequisites, conflicts, overlap between prerequisite/conflict IDs, and prerequisite cycles;
- Stage and Wave structure, procedural progression fields, scoped Wave IDs, enemy/count array consistency, timing and multiplier values;
- Wave-to-Enemy references and Enemy-to-immune-Status-Effect references;
- deterministic de-duplication of identical validation messages while preserving order.

Null entries, empty IDs, missing references, mismatched Wave arrays, duplicates, and prerequisite cycles are handled without relying on unsafe indexes. The supplied manual run reported no ContentValidator errors for the current registered data.

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

### Enemy/Wave Regression Checkpoint

The user completed a visual Godot 4.7.1 regression pass and confirmed correct two-sided movement, lane ordering, non-overlapping queue columns, front-enemy-only attacks, promotion after a front enemy dies, HealthBar and death feedback, Wave Complete messaging, Game Over, and Retry. No visually apparent regression was found.

Automated regression evidence for this checkpoint:

- Godot 4.7.1 headless editor/import completed successfully.
- The enemy runtime smoke test passed five consecutive runs. Each run covered `EnemyDefinition`, `StageDefinition`, `WaveDefinition`, `EnemySpawnRequest`, all three enemy components, `EnemyTracker`, `LaneRegistry`, and a two-request `SpawnDirector` fixture with 20 enemies and 20 unique side/lane/queue-order keys.
- MainWorld progression confirmed Wave 1–4 values: 2/30 HP, 2/33 HP, 2/36 HP, and 3/39 HP per side respectively; Bark Beetle damage remains 5 through EnemyDefinition × WaveDefinition multiplier.
- Death/retry confirmed cancellation during an active wave, restart at Wave 1 of the numbered Stage, no Age gain from replayed completed waves, and one Age gain when the next new highest wave was first completed.
- Shutdown race tests during initial spawning, active combat, and a wave boundary all exited cleanly without a late spawn, late attack, false completion, or SceneTree stack trace.

## 9. Known Gaps and Limitations

- There is no save/load system; all progression is process-local.
- Blossom has no talent tree or talents.
- Only one real enemy type currently exists.
- The two-request automated fixture reuses Bark Beetle as two logical request blocks; a real multi-enemy Wave has not yet been visually tested.
- Plan item 40 is only partially complete because the smoke test validates the enemy runtime foundation rather than a full combat-integration scene.
- No StatusEffect definitions are registered yet.
- Talent `effect_ids` are data only. Strength talent execution remains hardcoded in `strength_branch.gd`.
- The Tree Soul orb described in project guidance as visible from Age 1 is not a persistent world-space element; only the hidden-by-default SOUL panel and selection cards draw orb glyphs.
- A service-level prestige reset hook exists, but there is no integrated player-facing prestige flow.
- Gameplay scripts contain extensive prototype debug logging.
- Visuals are primarily code-drawn prototype shapes; the repository has no production art or audio content beyond the project icon.
- Validator coverage is extensive but has not been exercised with committed automated negative test fixtures.
- Project guidance describes a Soul orb visible from Age 1, but the current implementation has no persistent world-space orb; orb glyphs exist only in the SOUL panel and selection cards.

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

The next recommended implementation-plan item is:

- 25 — add a second real enemy type and a real multi-enemy `WaveDefinition`.

This will exercise the typed multi-request batch with distinct runtime scenes and provide the missing visual validation of mixed enemy waves. Save/load, prestige integration, complete Strength/Blossom talent trees, Status Effects, and the persistent Tree Soul orb remain later known gaps.

## 12. Handoff Checklist

- Read the root `AGENTS.md`.
- Read `docs/CURRENT_STATUS.md`.
- Run `git status --short` and verify the working tree is clean before starting a new task.
- Run `git log -1 --oneline` and review the current HEAD.
- Expected baseline branch: `main`.
- Implementation parent for this checkpoint: `ffdb880a9d3558c8b0167f9754d9005c42089c4b`.
- Verify that the current HEAD contains this implementation baseline or is a descendant of it.
- Baseline working tree before this document: clean.
- After this document is committed and pushed, the working tree should be clean before new development begins.
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
- Kill the tree and confirm immediate/automatic retry, Wave 1 stage restart, and preservation of in-memory progression.
- Confirm replayed waves do not grant additional Age and a newly completed highest wave does.
- At the Age 199/200/300 boundaries, verify Soul Rank 0/1/2, deferred selection, status-panel reopening, modifier isolation, and non-blocking rank-up notification behavior.
- Before committing this document or later work, ensure the diff contains only explicitly intended files and no generated UID changes.
