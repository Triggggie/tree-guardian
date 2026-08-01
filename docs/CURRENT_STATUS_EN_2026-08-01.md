# Tree Guardian — Current Project Status

_Last updated: 1 August 2026_  
_Repository state: `main` branch, commit `fcb3536` — `Add Tree Soul tab button`_

> This document is the current implementation source of truth. It describes what is actually present in the repository and separates functional systems, partial prototypes, and planned systems. If it conflicts with older status documents, this file and the current code take precedence.

## 1. Project overview

**Tree Guardian** is a 2D idle / tower-defense game built in Godot.

The player develops a central Tree of Life standing in the middle of the battlefield. Enemies approach from both sides, and deployed combat branches defend the tree automatically.

The current build is a technical prototype. It uses procedural drawing, basic tweens, and prototype UI. The planned final visual direction is pixel art.

## 2. Current technical setup

- Engine: Godot 4.7; development uses Godot 4.7.1 stable
- Language: GDScript
- Renderer: Forward+
- Base viewport: 1920 × 1080
- Main scene: `res://scenes/main_world.tscn`
- Main tree scene: `res://scenes/tree/tree.tscn`
- Repository: `Triggggie/tree-guardian`
- Active autoloads:
  - `RunModifiers`
  - `TreeSouls`
  - `GameContent`

## 3. Current main scene structure

```text
MainWorld
├── Background
├── World
│   ├── Ground
│   ├── LeftSpawnPoint
│   └── RightSpawnPoint
├── Entities
│   └── Tree
├── Effects
├── UI
│   ├── EssenceLabel
│   ├── BranchInfoLabel
│   ├── AgeLabel
│   ├── WaveLabel
│   ├── HealthLabel
│   ├── HealthBar
│   ├── WaveMessageLabel
│   ├── GameOverPanel
│   ├── BranchUpgradePanel
│   ├── TreeUpgradePanel
│   ├── UpgradeTabs
│   │   ├── BranchTabButton
│   │   ├── TreeTabButton
│   │   └── SoulTabButton
│   ├── TalentScreen
│   ├── TalentsButton
│   ├── TreeSoulSelectionScreen
│   └── TreeSoulStatusPanel
├── Camera2D
├── Developer
└── WaveManager
```

## 4. Development-plan status

The accepted roadmap starts with prototype stabilization, continues through a data and service foundation, then migrates current systems before expanding content.

### Phase 0 — Stabilize the current game

**Status: complete.**

Completed fixes include:

- revalidating targets immediately before real hits,
- validating Sweeping Strike secondary targets,
- validating Blossom projectile targets,
- stopping and resuming every combat branch together,
- supporting multiple instances of the same branch type in Talent Screen,
- safe minimum XP and tree-maturity values,
- distributing enemies across open lanes,
- a dedicated enemy collision layer,
- removing the legacy talent mode from the upgrade panel.

### Phase 1 — Data and service foundation

**Status: technical foundation complete.**

General definitions now exist:

- `UpgradeDefinition`
- `TalentDefinition`
- `TalentTreeDefinition`
- `BranchDefinition`
- `TreeSoulDefinition`
- `TreeSoulBonusDefinition`
- `EnemyDefinition`
- `WaveDefinition`
- `StageDefinition`
- `StatusEffectDefinition`
- `TargetingProfile`

The repository also contains:

- `ContentRegistry`
- `ContentValidator`
- `ContentService` / `GameContent` autoload
- `RunModifierService` / `RunModifiers` autoload
- stable `StringName` modifier IDs
- `AttackContext`
- `AttackResolver`
- `BranchStatCalculator`
- `CombatTargeting`

Important limitation: definition classes do not mean the entire prototype is already data-driven. The current `ContentRegistry` contains the four Tree Soul resources. Branch, enemy, stage, and status-effect collections are prepared but not yet populated with real content. Current branches, Bark Beetle, and WaveManager still rely largely on scene and script exports.

### Phase 2 — Prototype migration and Tree Soul V1

**Status: in progress; the main gameplay core works, while UI and persistence remain incomplete.**

Completed:

- shared `CombatBranch` interface,
- generic upgrade and talent interfaces,
- Strength Branch migration to shared targeting, attack context, resolver, and run modifiers,
- Blossom Branch migration to separated damage, healing, and attack-speed calculations,
- four Tree Soul resources,
- Tree Soul service, rank progression, and modifier application,
- Tree Soul selection screen,
- Crimson, Azure, Golden, and Verdant gameplay effects,
- Tree Soul status panel,
- SOUL tab button in the scene,
- protection against Age farming from repeated waves.

Remaining:

- connect `SoulTabButton` in `scripts/ui.gd`,
- switch Branch, Tree, and Soul panels so that only one is visible,
- finish and test visual-state reset in the Tree Soul status panel,
- add a non-blocking Tree Soul Rank Up notification,
- add a visible Soul orb to the tree,
- implement the real prestige flow,
- implement save/load and Tree Soul persistence,
- finish migrating branches, enemies, and waves to data definitions.

## 5. Tree and run progression

The tree currently supports:

- Forest Essence,
- Age,
- maximum and current HP,
- damage, death, and revival,
- automatic respawn and manual Retry,
- idle breathing animation,
- damage flash and shake,
- procedural growth based on Age,
- old-tree color and detail changes,
- maximum-HP upgrades,
- flat-regeneration upgrades,
- Essence Gain upgrades,
- healing-over-time effects,
- percentage regeneration from a Tree Soul modifier.

Base maximum:

```text
100 HP
```

### Tree upgrades

```text
Max HP: +20 per upgrade
HP Regeneration: +0.5 HP/s per upgrade
Essence Gain: +10% per upgrade
Cost growth: ×1.40
Base upgrade cap: 3
+1 maximum level every 5 Age
```

### Maximum-HP calculation

```text
(base maximum HP + purchased flat Max HP upgrades)
× Tree Max Health modifier
```

Verdant Soul is therefore applied after purchased flat HP upgrades.

### Regeneration calculation

```text
flat regeneration from Tree Upgrades
+ maximum HP × Tree Regen Rate
```

### Essence reward calculation

```text
base reward
× Tree Upgrade Essence multiplier
× Golden Soul modifier
```

Fractional bonus Essence is kept in a buffer so small bonuses periodically create a real additional orb.

## 6. Age, Wave, and death

- The tree starts at Age 1.
- Age increases only when a new highest global wave is completed for the first time.
- Replaying already completed waves after death grants no additional Age.
- A prototype Stage contains 100 waves.
- Death restarts the current Stage from Wave 1.
- `highest_completed_wave` remains preserved, preventing easy-wave Age farming.

Example:

```text
Complete waves 1–4 → Age progresses.
Die during wave 5.
Replay waves 1–4 → no additional Age.
Complete wave 5 for the first time → Age progresses again.
```

Ordinary death preserves current run progression, including Age, Essence, XP, levels, Talent Points, purchased talents, upgrades, and the selected Tree Soul. Ordinary death is not prestige.

## 7. Deployed branches

The current tree has five logical slots. Four are occupied:

```text
Slot 1 — left Strength Branch
Slot 2 — left Blossom Branch
Slot 3 — right Strength Branch
Slot 4 — right Blossom Branch
Slot 5 — empty
```

The game no longer contains only two mirrored Strength Branches. It now has two functional archetypes and two instances of each archetype.

## 8. Shared CombatBranch system

`CombatBranch` provides a shared base for:

- branch identity,
- side and slot,
- XP and level,
- Talent Points,
- purchased talents,
- Essence-upgrade limits,
- upgrade prices,
- stop/resume combat,
- generic statistic interface,
- generic upgrade interface,
- generic talent interface,
- talent prerequisites and conflicts.

Every branch instance has independent XP, level, Talent Points, talents, and upgrades.

Talent Points are earned at levels:

```text
2, 4, 7, 10, and 14
```

Maximum branch Essence-upgrade level:

```text
branch level × 3
```

## 9. Strength Branch

Strength Branch is the melee/offensive archetype.

### Base values

```text
Base Damage: 10
Base attack cooldown: 1.5 s
Minimum cooldown: 0.45 s
Attack angle: 18°
Base range padding: 100
Damage per upgrade: +2
Cooldown reduction per upgrade: 0.08 s
Range per upgrade: +15
Maximum Essence range bonus: +150
Upgrade cost growth: ×1.35
```

### Visual growth

```text
Mature level: 10
Bud length: 38
Mature length: 185
Bud thickness: 10
Mature thickness: 30
First side shoot: level 3
Maximum side shoots: 5
```

### Targeting

- uses explicit lanes,
- prefers its configured lane and allowed lane span,
- uses fallback behavior when no preferred target is found,
- does not use vertical Y tolerance as a replacement for lanes,
- revalidates the target immediately before the hit.

### Functional Strength talents

#### Sweeping Strike — Crusher

- a basic attack may hit a second nearby valid enemy,
- the prototype secondary hit deals 60% Damage,
- the secondary target is revalidated,
- a secondary kill awards XP correctly.

#### Rebuff — Warden

- a valid hit knocks the enemy away from the tree,
- current test distance is 35 px,
- uses the general enemy knockback interface,
- also applies to a Sweeping Strike secondary hit.

#### Marked Prey — Duelist

- repeated hits against the same primary target gain stacks,
- +10% Damage per stack,
- maximum 5 stacks,
- stacks reset on target change, stop combat, or respawn,
- secondary Sweeping Strike hits do not create stacks.

## 10. Blossom Branch

Blossom Branch is a hybrid support/ranged archetype deployed in both upper tree slots.

### Healing Over Time

```text
Base healing per tick: 3 HP
Base tick interval: 2.0 s
Minimum tick interval: 0.75 s
Effect duration: 6 s
Effect refresh interval: 6 s
```

- repeatedly applies a refreshable HoT effect to the tree,
- the same effect ID does not stack; it refreshes,
- healing strength uses `HEALING_POWER`,
- Azure attack speed does not accelerate healing ticks.

### Ranged petal attack

```text
Base petal damage: 3
Base attack interval: 2.0 s
Range: 650
```

- prefers enemies on its own side,
- may use the opposite side when no own-side target exists,
- validates targets before firing and again before impact,
- petal damage uses `BRANCH_DAMAGE`,
- petal firing cadence uses `ATTACK_SPEED`.

### Blossom Essence upgrades

```text
Healing per Tick: +1 HP per upgrade
Healing Speed: -0.1 s tick interval per upgrade
Petal Damage: +1 per upgrade
```

Blossom does not yet have its own functional talent tree.

## 11. Talent Screen

The separate `TALENTS` screen is implemented.

It supports:

- opening and closing a full-size screen,
- dynamically finding all nodes in the `combat_branch` group,
- sorting branches by slot,
- a separate button for every deployed instance,
- talent-node display,
- talent details,
- required level,
- Talent Point cost,
- prerequisites,
- conflicts,
- talent purchase,
- inspecting already purchased talents.

Talent Screen supports multiple instances of the same archetype. Strength Branch currently has functional talent content. Blossom can appear as a deployed branch in the selector, but its talent list is currently empty.

## 12. Combat architecture

### AttackContext

Carries data for a concrete attack, including:

- source,
- target,
- damage,
- attack ID,
- tags,
- optional metadata.

### AttackResolver

Performs shared damage resolution and separates attack creation from damage application.

### BranchStatCalculator

Centralizes the application of:

- `BRANCH_DAMAGE`,
- `ATTACK_SPEED`,
- `HEALING_POWER`.

### CombatTargeting and TargetingProfile

Provide reusable targeting behavior for:

- target group,
- priority,
- preferred/strict/any lane mode,
- preferred lane span,
- range,
- tree side,
- targetability validation.

## 13. Run modifiers

Canonical modifier IDs:

```gdscript
BRANCH_DAMAGE
ATTACK_SPEED
TREE_MAX_HEALTH
TREE_REGEN_RATE
ESSENCE_GAIN
HEALING_POWER
```

Semantics:

- `BRANCH_DAMAGE` affects branch damage, secondary attacks, branch DoT, and offensive branch abilities. It does not affect healing.
- `ATTACK_SPEED` affects attacks and projectile firing. It does not affect passive healing tick interval, DoT tick rate, effect duration, waves, or enemies.
- `TREE_MAX_HEALTH` affects the tree's maximum HP.
- `TREE_REGEN_RATE` is a percentage of maximum HP regenerated per second.
- `ESSENCE_GAIN` affects real gameplay rewards, not refunds, loading, restoration, or debug grants.
- `HEALING_POWER` is reserved for healing strength and future talents.

## 14. Content architecture

`ContentRegistry` contains prepared collections for:

- branches,
- tree souls,
- enemies,
- stages,
- status effects.

The registry builds stable-ID indexes, and `ContentValidator` checks definitions when `GameContent` initializes.

Only the four Tree Souls are currently registered as real content. The remaining definition classes are foundations for later migration and must not be treated as a completed data-driven content pipeline.

## 15. Tree Soul system

### Core rules

- selection unlocks at Age 20,
- the selection screen does not pause combat,
- no Soul bonus is active while selection remains pending,
- the player may choose later; Rank is calculated from current Age,
- the selected Soul cannot be changed during the same prestige run,
- ordinary death does not clear the Soul,
- future prestige is intended to clear the Soul and return the orb to an inactive state.

### Rank progression

```text
Rank 1: Age 20
Next Rank: every 100 Age
Rank = 1 + floor((Age - 20) / 100)
Soft cap: Rank 50
Post-soft-cap growth: 50% of normal per-rank growth
Hard cap: none
```

Examples:

```text
Age 20 → Rank 1
Age 120 → Rank 2
Age 220 → Rank 3
```

### Crimson Soul

```text
Rank 1: +8% Branch Damage
Growth: +0.75% per Rank
```

Affects Strength damage and Blossom petal damage. Does not affect Blossom healing.

### Azure Soul

```text
Rank 1: +6% Attack Speed
Growth: +0.40% per Rank
```

Affects Strength attack cadence and Blossom petal firing. Does not accelerate healing ticks.

### Golden Soul

```text
Rank 1: +3% Essence Gain
Growth: +0.25% per Rank
```

Applies to real gameplay Essence rewards.

### Verdant Soul

```text
Rank 1:
+15% Maximum HP
+0.03% Max HP per second

Growth per Rank:
+1.5% Maximum HP
+0.003% Max HP per second
```

Maximum HP and percentage regeneration are connected directly to the tree and update on Soul selection, Rank change, and Soul clear.

### Implemented Tree Soul UI

- `TreeSoulSelectionScreen`,
- four-column selection for all four Souls,
- colored cards and descriptions read from Resources,
- `TreeSoulStatusPanel`,
- Soul name, color, Rank, bonuses, next Rank, and progress bar,
- `SoulTabButton` in the scene.

### Currently incomplete Tree Soul UI

1. `SoulTabButton` is not connected in `scripts/ui.gd`.
2. The status panel is therefore not normally accessible through tab switching.
3. The inactive status refresh makes the orb gray but does not remove the Soul-name color override after a previous selection; this should be fixed for real clear/prestige behavior.
4. No rank-up notification exists.
5. No graphical orb is attached to the tree.
6. No completed prestige or save/load flow exists.

## 16. Bark Beetle enemy

Bark Beetle supports:

- movement toward the tree,
- HP scaling by global wave,
- attacks against the tree,
- explicit lane index and lane Y,
- attack queues per lane,
- targetability checks,
- damage feedback,
- health bar,
- death animation,
- Essence reward,
- branch XP reward,
- knockback and knockback resistance,
- stop/resume combat,
- dedicated collision layer.

Current prototype values:

```text
Base HP: 30
HP per wave: +3
Attack Damage: 5
Attack cooldown: 1.5 s
XP reward: 1
Base Essence reward: 1
```

## 17. WaveManager and lanes

WaveManager still directly preloads the Bark Beetle scene and uses exported prototype values.

```text
Waves per Stage: 100
Base enemies per side: 2
+1 enemy per side every 3 waves
Maximum enemies per side: 30
Lane count: 5
Spawn interval: 0.25 s
```

Enemies are distributed through shuffled lane orders so available lanes are used more evenly. Battlefield depth uses lane scale and Y jitter for a pseudo-3D effect.

`WaveDefinition`, `StageDefinition`, and `EnemyDefinition` exist, but runtime WaveManager and Bark Beetle are not yet fully rebuilt around those resources.

## 18. Current UI

Functional:

- Forest Essence label,
- branch information,
- Age,
- Wave,
- Tree HP label and health bar,
- wave-complete message,
- Game Over panel,
- respawn/retry,
- generic Branch Upgrade Panel,
- Tree Upgrade Panel,
- BRANCHES and TREE tabs,
- separate Talent Screen,
- Tree Soul selection overlay.

Prepared but incomplete:

- SOUL tab button exists,
- Tree Soul status panel exists,
- their connection in `ui.gd` is missing.

The UI still uses many fixed offsets and is not final responsive UI.

## 19. Visual state

Current visuals remain temporary:

- procedurally drawn tree,
- procedurally drawn Strength and Blossom branches,
- simple Bark Beetle,
- procedural ground and perspective lines,
- basic circular Essence orbs,
- basic tweens,
- prototype panels.

Planned direction:

- pixel art,
- clear visual identity for every branch,
- visible Tree Soul orb,
- appearance evolution through Age, branch levels, and Soul Rank,
- stronger enemies,
- improved attacks, impacts, projectiles, and collection effects,
- cleaner and responsive UI.

## 20. Save, prestige, and offline progress

Not implemented:

- save/load,
- save-version migrations,
- persistence after closing the game,
- offline progress,
- real prestige trigger,
- run reset,
- Garden/metaprogress.

Some services are prepared for future persistence:

- `TreeSoulService.selected_soul`,
- `current_rank`,
- `last_announced_rank`,
- `clear_for_prestige()`.

These values are not yet written to disk.

## 21. Known current limitations

- SOUL tab is not connected.
- Tree Soul rank-up notification does not exist.
- Tree Soul orb on the tree does not exist.
- Prestige and save/load do not exist.
- Blossom has no talent tree.
- Strength has only three prototype talents, not a complete spider.
- Data definitions exist, but most current gameplay content is not migrated to them.
- The registry currently contains only Tree Souls.
- WaveManager remains hardcoded to Bark Beetle.
- UI is prototype-quality and fixed-position.
- There are no automated gameplay tests or Godot CI validation.
- Balance values are temporary.
- Art and audio are not final.

## 22. Immediate next task

The nearest safe step:

1. add and commit the root `AGENTS.md` for Codex,
2. connect the SOUL tab in `scripts/ui.gd`,
3. ensure BRANCHES, TREE, and SOUL display exactly one panel,
4. keep BRANCHES as the default tab,
5. preserve the TALENTS button behavior,
6. test locally in Godot,
7. review the diff before merge.

Then:

1. strictly review and minimally fix `tree_soul_status_panel.gd`,
2. add a non-blocking Tree Soul Rank Up notification,
3. test all four Soul effects,
4. add the visual orb to the tree,
5. prepare the real prestige/save flow.

## 23. Recommended order of larger next steps

1. Finish Tree Soul V1 UI and tests.
2. Add rank-up feedback and the orb vertical slice.
3. Complete the Strength talent tree.
4. Design and implement the Blossom talent tree.
5. Migrate branch content to `BranchDefinition`.
6. Migrate Bark Beetle to `EnemyDefinition`.
7. Migrate WaveManager to `StageDefinition` and `WaveDefinition`.
8. Add save/load and versioned migrations.
9. Add prestige.
10. Add more enemy and branch archetypes.
11. Begin the final graphical vertical slice.

## 24. Intentionally postponed systems

- Garden
- permanent metaprogression
- full prestige
- save/load and offline progress
- equipment
- additional regions and stage content
- elites and bosses
- complete status-effect gameplay
- sound and music
- final pixel art
- mobile controls
- responsive mobile UI
- Steam integration
- achievements
- localization

## 25. Development principles

- One clearly bounded task at a time.
- Read relevant scenes, scripts, and Resources before editing.
- Do not change unrelated files.
- Do not perform broad refactors without a dedicated task.
- Test after every meaningful change.
- Review the exact diff before commit or merge.
- Preserve stable `StringName` IDs.
- Content data belongs in Resources.
- General mechanics belong in shared services/components.
- XP, Talent Points, and Forest Essence remain separate.
- Branch level controls growth, talent milestones, and upgrade cap; it does not automatically increase base Damage.
- Do not use Y tolerance as a replacement for lane targeting.
- Revalidate targets before real hits.
- Tree Soul selection must not pause the game.
- Azure must not accelerate healing ticks.
- Crimson must not increase healing.
- Golden must not apply to load, restoration, refunds, or debug grants.
- A smaller clean step is better than a large unreviewable diff.

## 26. Milestone summary

### Complete

- stabilization of the base combat prototype,
- central tree, damage, death, and respawn,
- Age, Stage, and Wave prototype,
- protection against Age farming,
- explicit lanes and crowd formation,
- Strength and Blossom archetypes,
- four deployed branch instances,
- generic XP, level, Talent Point, and upgrade interfaces,
- functional separate Talent Screen,
- three functional Strength talents,
- healing over time and Blossom petal combat,
- shared targeting, context, and resolver,
- RunModifierService,
- ContentRegistry and validator,
- definition foundation,
- four Tree Souls,
- Tree Soul rank progression,
- Tree Soul selection screen,
- Tree Soul modifiers connected to gameplay,
- Tree Soul status panel,
- SOUL button in the scene.

### In progress

- Tree Soul V1 UI completion,
- SOUL-tab connection,
- status-panel review,
- rank-up notification,
- Codex workflow and `AGENTS.md`,
- migration of current gameplay to data-driven definitions,
- documentation and testing.

### Not started or only interface-prepared

- real save/load,
- prestige flow,
- offline progress,
- visible orb on the tree,
- complete Strength and Blossom talent trees,
- data-driven enemy/stage/wave runtime,
- additional branch and enemy content,
- bosses,
- equipment,
- final art, audio, and localization.
