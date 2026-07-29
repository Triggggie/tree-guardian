# Tree Guardian — Current Project Status

_Last updated: July 29, 2026_

## Project Overview

**Tree Guardian** is a 2D idle / tower-defense game being developed in Godot 4.7.1.

The player controls the last Tree of Life. The tree stands in the center of the battlefield and automatically defends itself against enemies approaching from both sides.

The project currently uses temporary procedural graphics. The final visual direction is planned as pixel art.

## Core Game Concept

- The player develops one central Tree of Life.
- The progress of the current run is represented by the tree's **Age**.
- The tree gains one year of Age for every completed wave.
- Age remains preserved after an ordinary death.
- Age is intended to reset only through the future prestige system.
- Combat branches gain their own XP from defeated enemies.
- Each branch levels independently.
- Branch levels represent natural growth, Talent Point milestones, and increasing upgrade caps.
- Branch levels do not directly increase Damage or Attack Speed.
- Forest Essence is the main currency of the current run.
- Forest Essence is separate from branch XP and Talent Points.
- Main branches are intended to be unique in the final game.
- The current two mirrored Strength Branches are used only for prototype testing.

## Current Technical Setup

- Engine: Godot 4.7.1 stable
- Language: GDScript
- Renderer: Forward+
- Base resolution: 1920 × 1080
- Repository: private GitHub repository `tree-guardian`
- Main scene: `res://scenes/main_world.tscn`

## Current Scene Structure

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
│   └── TreeUpgradePanel
├── Camera2D
├── Developer
└── WaveManager
```

## Tree System

The tree currently supports:

- Storing Forest Essence
- Age progression
- Maximum and current health
- Taking damage
- Death
- Automatic respawn
- Immediate manual retry
- Idle “breathing” animation
- Red flash and shake feedback when hit
- Text health display
- Green health bar
- Maximum health upgrades
- Health regeneration upgrades
- Forest Essence gain upgrades

Current base tree health:

```text
100 HP
```

## Tree Upgrades

The player can spend Forest Essence on global tree upgrades.

### Maximum HP

- Increases maximum health.
- Also increases current health by the same amount.
- Current value per upgrade: `+20 maximum HP`.

### HP Regeneration

- Automatically restores health over time.
- Stops at maximum health.
- Does not revive a dead tree.
- Current value per upgrade: `+0.5 HP per second`.

### Forest Essence Gain

- Increases the amount of Forest Essence dropped by enemies.
- The bonus changes the actual number of visible Essence orbs.
- The currency multiplier is not applied again when an orb reaches the tree.
- Current value per upgrade: `+10% Forest Essence`.

Tree upgrades currently have an Age-dependent level cap:

```text
Base maximum upgrade level: 3
+1 maximum level for every 5 Age
```

## Strength Branches

Two mirrored Strength Branches are currently attached to the tree for testing.

Each branch has:

- Its own XP
- Its own level
- Its own Talent Points
- Automatic target selection
- Automatic attacks
- Damage upgrades
- Attack Speed upgrades
- Range upgrades
- Natural visual growth
- Combat shutdown after tree death
- Combat resumption after respawn

Branch levels currently affect:

- Visual growth
- Talent Point milestones
- Maximum allowed Essence upgrade levels
- Natural attack range through the branch's physical length

Branch levels do not directly increase Damage or Attack Speed.

## Branch Visual Growth

Each Strength Branch begins as a small bud or shoot and gradually grows toward its mature size.

```text
Mature branch level: 10
Bud length: 38
Bud thickness: 10
Mature length: 185
Mature thickness: 30
First side shoot: level 3
Maximum side shoots: 5
```

After reaching mature size, later levels should primarily add visual detail rather than infinitely increasing branch length or thickness.

## Branch Combat Statistics

```text
Base Damage: 10
Base cooldown: 1.5 s
Minimum cooldown: 0.45 s
Base attack angle: 18°
XP required per level: 2
```

The UI displays Attack Speed instead of cooldown. Cooldown remains the internal value used by the attack timer.

## Branch Essence Upgrades

Each branch can spend Forest Essence on Damage, Attack Speed, and Range.

```text
Damage per upgrade: +2
Cooldown reduction per upgrade: 0.08 s
Range per upgrade: +15
Upgrade cost growth: ×1.35
Maximum upgrade level = Branch Level × 3
```

Range also has its own separate maximum bonus.

## Branch Range System

```text
Attack Range
=
Current branch length
+ Base range padding
+ Essence Range bonus
```

Current values:

```text
Base range padding: 100
Range per Essence upgrade: +15
Maximum Essence Range bonus: +150
Maximum number of Range upgrades: 10
```

Approximate examples:

```text
Young branch: 38 + 100 = Range 138
Mature branch: 185 + 100 = Range 285
Mature branch with maximum bonus: 185 + 100 + 150 = Range 435
```

## Talent Points

Strength Branches gain Talent Points at levels 2, 4, 7, 10, and 14.

Talent Points are stored separately for each branch. The first three Strength talents are functional as a technical prototype. The final talent tree and its visual node-web are not implemented yet.

### Functional Strength Talents

#### Sweeping Strike — Crusher

- A basic attack also hits a second nearby enemy.
- Current test value for the secondary hit: `60% Damage`.
- The secondary target must be on the correct side of the tree, within the branch's range, and near the primary target.
- Secondary kills correctly award XP to the Strength Branch.

#### Rebuff — Warden

- Every hit pushes the enemy away from the tree.
- Current test distance: `35 px`.
- The enemy stops attacking, must walk back to its attack checkpoint, and then starts a full attack cooldown again.
- Bark Beetle has a reusable `apply_knockback()` method and configurable `knockback_resistance`.
- Rebuff is also applied to the secondary target hit by Sweeping Strike.

#### Marked Prey — Duelist

- The Strength Branch tracks its primary attacked target.
- The first hit against a new target deals base Damage.
- Every additional hit against the same target adds one stack.
- Current test value: `+10% Damage per stack`, up to `5 stacks`.
- Stacks reset when the target changes, combat stops, or the tree respawns.
- The secondary Sweeping Strike hit does not build Marked Prey stacks.

All values are prototypes and are separated from the gameplay logic so they can be balanced extensively later.

## Bark Beetle Enemy

Bark Beetle currently supports:

- Movement toward the tree
- Health scaling by wave
- Automatic attacks
- Movement speed variation
- Multiple depth lanes
- Separate attack queues for each lane
- Queue advancement after the leading enemy dies
- Health bar display after taking damage
- Red flash and shake feedback when hit
- Shrinking and fading on death
- Forest Essence drops
- Multiple Essence orbs from one death
- XP reward for the branch
- Combat shutdown after tree death
- Pseudo-3D rendering based on Y position
- Reusable knockback through `apply_knockback()`
- Configurable knockback resistance for future heavy enemies and bosses

```text
Movement speed: 120
Base health: 30
Attack damage: 5
Attack cooldown: 1.5 s
XP reward: 1
Base Forest Essence reward: 1
```

## Enemy Crowds and Battlefield Depth

Enemies spawn from both sides, use several shallow depth lanes, receive slightly varied movement speeds, and have separate attack queues for each lane. Only the first living enemy in each lane attacks. Branch attacks do not stop enemy movement.

The battlefield uses procedural 2.5D ground with a horizon, perspective lines, and enough depth for all lanes.

## Region, Stage, and Wave Structure

Planned progression:

```text
Region → Stage → Wave
```

Current test value: `100 waves per Stage`.

The system supports endless waves, scaling enemy count and health, delays between spawns and waves, increasing Age after a completed wave, a wave completion message, and restarting the Stage after tree death.

```text
Base enemies per side: 2
One additional enemy every 3 waves
Maximum enemies per side: 30
Base enemy health: 30
Health increase per wave: +3
```

The current wave scaling is still prototype logic and should later become data-driven.

## Forest Essence

When an enemy dies, its actual Essence reward is calculated. The result determines the number of visible orbs. Each orb appears with a small random offset, waits briefly, flies toward the tree, and adds one Forest Essence.

Essence Gain uses a fractional remainder accumulator. At `+10%`, enemies usually drop one orb and periodically drop one additional orb. The normal gameplay value is:

```text
Essence Gain Per Upgrade: 0.10
```

## Death and Respawn

When the tree's health reaches zero:

- Combat for the tree, branches, and enemies stops.
- Wave spawning and wave messages stop.
- The Game Over panel is displayed.
- A ten-second respawn countdown starts.
- The player can use `RETRY NOW`.
- The current Stage restarts from Wave 1.

An ordinary death preserves Age, Forest Essence, branch XP and levels, Talent Points, branch upgrades, and tree upgrades. An ordinary death is not prestige.

## Current UI

The implemented UI includes Forest Essence, branch information, tree Age, wave information, enemy count, tree HP, health bar, wave completion message, Game Over panel, respawn countdown, Retry, branch upgrade panel, tree upgrade panel, and a temporary prototype for purchasing the first three Strength talents.

The panels display current and next values, prices, disabled states when Essence is insufficient, and `MAX` when the current limit is reached.

The UI still uses fixed positions and remains a prototype. Before mobile support or release, it should be rebuilt using responsive containers and anchors.

### Decided Next UI Direction

The main combat screen should remain as clean as possible.

- The main screen will keep a compact list of equipped branches.
- Each equipped branch will display only its primary metric, such as `Damage` or `HPS`.
- Essence upgrades for the tree and branches will remain accessible from the main screen or a quick-access panel.
- Detailed statistics such as Damage, Attack Speed, Range, DPS, HPS, and upgrade levels will move to a separate `STATS` page.
- Talents will receive a separate large `TALENTS` page.
- On the TALENTS page, the player selects an equipped branch and sees that branch's own talent node-web.
- The screen will include details for the selected talent, its cost, required level, dependencies, and purchase state.
- The current three talent buttons are only a technical prototype and will not be the final layout.
- Talent designs and numerical values are not final yet.

## Visual State

The current graphics are temporary: a procedural tree and branches, simple enemies, procedural ground, green Essence circles, basic tweens, and simple UI panels.

Planned direction:

- Pixel-art style
- Visible tree growth based on Age
- Natural branch development
- More distinctive enemies
- Improved terrain, shadows, and depth
- Better attack, hit, and collection effects
- Strong visual identity for every branch type

## Intentionally Deferred Systems

- Garden system
- Permanent metaprogression
- Prestige implementation
- Save system
- Offline progress
- Branch selection screen
- Additional branch archetypes
- Final talent tree UI and complete talent node-webs for all branches
- Elite enemies and bosses
- Status effects
- Sound and music
- Final pixel-art assets
- Mobile controls and responsive UI
- Steam integration and achievements
- Localization
- Data-driven wave configuration

## Recommended Next Development Phase

1. Create a separate `TALENTS` page.
2. Add equipped-branch selection and the first real Strength talent node-web.
3. Move detailed statistics to a separate `STATS` page.
4. Simplify the main combat screen into a compact branch list with primary metrics.
5. Perform longer tests of Sweeping Strike, Rebuff, and Marked Prey combinations.
6. Review and clean up the current scripts after completing the UI milestone.
7. Add one new enemy archetype.
8. Continue with another distinct branch archetype.

## Immediate Next Task

Create a separate large `TALENTS` page where the player can select an equipped branch and view its talent node-web. The first version will use the three already functional Strength talents and prepare the structure for future expansion.

## Current Milestone Status

### Completed

- Central tree, health, death, automatic respawn, and manual Retry
- Stage restart after death
- Two separate combat branches
- XP, levels, and Talent Point milestones
- Natural visual branch growth
- Automatic targeting and attacks
- Enemy movement, attacks, scaling, and depth lanes
- Dynamic lane queues and pseudo-3D ground
- Forest Essence, multiple orbs, and Essence Gain
- Tree Age, hit feedback, and health indicators
- Interaction with branch and tree upgrades
- General talent purchase system, level requirements, and Talent Points
- Functional Strength talents: Sweeping Strike, Rebuff, and Marked Prey
- Enemy knockback interface with configurable resistance
- Damage, Attack Speed, and Range upgrades
- Range based on branch length with a maximum Essence bonus
- Maximum HP, HP regeneration, and Essence Gain upgrades
- Limits, costs, branch selection, and unified Attack Speed display

### In Progress

- Design of the separate TALENTS screen
- Design of the Strength Branch talent node-web
- Design of the separate STATS page
- Simplification of the main combat screen
- Combat improvements
- Balancing
- Script cleanup
- Documentation

### Not Started

- Prestige
- Garden
- Additional branches and enemies
- Final talent node-webs and complete talent trees
- Bosses
- Save system and offline progress
- Sound and final graphics
- Mobile UI and metaprogression
- Steam integration and localization

## Development Principles

- Add only one small feature at a time.
- Test after every significant change.
- Create a commit after each stable milestone.
- Do not build future systems before the current gameplay loop is clear.
- Keep gameplay code independent of final graphical assets.
- For larger changes, replace complete scripts when that reduces the risk of merge or indentation errors.
- Optimize only when there is an actual performance problem.
- Preserve the possibility of a future mobile version.
- Keep XP, Talent Points, and Forest Essence separate.
- Use branch levels for growth and unlocks, not for automatic statistic scaling.
- Every upgrade must have a meaningful limit.
