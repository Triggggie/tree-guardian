# Tree Guardian — Current Status

_Last updated: 28 July 2026_

## Project overview

**Tree Guardian** is a 2D idle / tower-defense game built in Godot 4.7.1.

The player controls the last Tree of Life. The tree stands in the center of the battlefield and automatically defends itself against enemies approaching from both sides.

The current project uses temporary procedural graphics. Final visuals are planned as pixel art.

## Core design

- The player develops one central Tree of Life.
- The tree's run progression is represented by **Age**.
- One completed wave adds one year of Age.
- Age is preserved after ordinary death.
- Age is planned to reset only through a future prestige system.
- Combat branches gain their own XP from kills.
- Each branch levels independently.
- Branch levels represent natural growth, talent milestones and upgrade-cap progression.
- Branch levels do not directly increase damage or attack speed.
- Forest Essence is the main run currency.
- Forest Essence is separate from branch XP and Talent Points.
- Main branches are planned to be unique in the final game.
- Current mirrored Strength Branches exist only for prototype testing.

## Current technical setup

- Engine: Godot 4.7.1 stable
- Language: GDScript
- Renderer: Forward+
- Base resolution: 1920 × 1080
- Repository: private GitHub repository `tree-guardian`
- Primary scene: `res://scenes/main_world.tscn`

## Current scene structure

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

## Tree system

The tree currently supports:

- Forest Essence storage
- Age progression
- Maximum and current health
- Receiving damage
- Death
- Automatic respawn
- Immediate manual retry
- Idle breathing animation
- Red flash and shake when damaged
- Health label
- Green health bar
- Maximum-health upgrades
- Health-regeneration upgrades
- Forest-Essence gain upgrades

Current base tree health:

```text
100 HP
```

## Tree upgrades

The player can spend Forest Essence on global tree upgrades.

### Maximum HP

- Increases maximum health.
- Also increases current health by the same amount.
- Current value per upgrade: `+20 maximum HP`.

### HP Regeneration

- Restores health automatically over time.
- Stops at maximum health.
- Does not revive a dead tree.
- Current value per upgrade: `+0.5 HP per second`.

### Forest Essence Gain

- Increases the amount of Forest Essence dropped by enemies.
- The bonus changes the actual number of visible Essence orbs.
- The currency multiplier is not applied again when an orb reaches the tree.
- Current value per upgrade: `+10% Forest Essence`.

Tree upgrades currently have an Age-based level cap:

```text
Base maximum upgrade level: 3
+1 maximum level every 5 Age
```

## Strength branches

Two mirrored Strength Branches are currently attached to the tree for testing.

Each branch has:

- Independent XP
- Independent level
- Independent Talent Points
- Automatic target selection
- Automatic attacks
- Damage upgrades
- Attack-speed upgrades
- Range upgrades
- Natural visual growth
- Combat shutdown after tree death
- Combat resumption after respawn

Branch levels currently affect:

- Visual growth
- Talent Point milestones
- Maximum allowed Essence-upgrade levels
- Natural attack range through physical branch length

Branch levels do not directly increase Damage or Attack Speed.

## Branch visual growth

Each Strength Branch begins as a small bud or shoot and gradually grows toward its mature size.

```text
Mature branch level: 10
Bud length: 38
Bud thickness: 10
Mature length: 185
Mature thickness: 30
First side shoot level: 3
Maximum side shoots: 5
```

After reaching mature size, later levels should mainly add visual detail rather than endlessly increasing length or thickness.

## Branch combat statistics

```text
Base damage: 10
Base cooldown: 1.5 s
Minimum cooldown: 0.45 s
Base attack angle: 18°
XP required per level: 2
```

The UI displays Attack Speed rather than cooldown. Cooldown remains the internal timer value.

## Branch Essence upgrades

Each branch can spend Forest Essence on Damage, Attack Speed and Range.

```text
Damage per upgrade: +2
Cooldown reduction per upgrade: 0.08 s
Range per upgrade: +15
Upgrade-cost growth: ×1.35
Maximum upgrade level = Branch Level × 3
```

Range also has its own separate maximum bonus.

## Branch range system

```text
Attack Range
=
Current Branch Length
+ Base Range Padding
+ Essence Range Bonus
```

Current values:

```text
Base Range Padding: 100
Range per Essence upgrade: +15
Maximum Essence Range Bonus: +150
Maximum Range upgrades: 10
```

Approximate examples:

```text
Young branch: 38 + 100 = 138 Range
Mature branch: 185 + 100 = 285 Range
Mature branch with maximum Range bonus: 185 + 100 + 150 = 435 Range
```

## Talent Points

Strength Branches gain Talent Points at levels 2, 4, 7, 10 and 14.

Talent Points are stored independently for each branch. The final talent-tree UI and functional talents have not yet been implemented.

## Bark beetle enemy

The Bark Beetle currently supports:

- Movement toward the tree
- Wave-based health scaling
- Automatic attacks
- Independent movement-speed variation
- Multiple depth lanes
- Per-lane attack queues
- Queue advancement after the front enemy dies
- Health bar shown after receiving damage
- Red hit flash and hit shake
- Death shrink and fade
- Forest Essence drops
- Multiple Essence orbs per death
- Branch XP reward
- Combat shutdown after tree death
- Pseudo-3D rendering by Y position

```text
Movement speed: 120
Base health: 30
Attack damage: 5
Attack cooldown: 1.5 s
XP reward: 1
Base Forest Essence reward: 1
```

## Enemy crowd and battlefield depth

Enemies spawn from both sides, use several shallow depth lanes, receive slight speed variation and use independent per-lane attack queues. Only the first living enemy in each lane attacks. Branch attacks do not stop enemy movement.

The battlefield uses a procedural 2.5D ground with a horizon, perspective lines and enough depth for all enemy lanes.

## Wave, stage and region structure

Planned progression:

```text
Region → Stage → Wave
```

Current test value: `100 waves per stage`.

The system supports endless waves, enemy-count and health scaling, delays between spawns and waves, Age gain after wave completion, wave-complete messages and Stage restart after tree death.

```text
Base enemies per side: 2
One additional enemy every 3 waves
Maximum enemies per side: 30
Base enemy health: 30
Health increase per wave: +3
```

Current wave scaling is still prototype logic and should later become data-driven.

## Forest Essence

When an enemy dies, its actual Essence reward is calculated. The result determines the number of visible orbs. Each orb appears with a small random offset, waits briefly, flies to the tree and adds one Forest Essence.

Essence Gain uses a fractional reward buffer. At `+10%`, enemies usually drop one orb and periodically drop an additional orb. The normal gameplay value is:

```text
Essence Gain Per Upgrade: 0.10
```

## Death and respawn

When the tree reaches zero health:

- Tree, branch and enemy combat stop.
- Wave spawning and messages stop.
- The Game Over panel appears.
- A ten-second respawn countdown begins.
- The player may use `RETRY NOW`.
- The current Stage restarts at Wave 1.

Ordinary death preserves Age, Forest Essence, branch XP, branch levels, Talent Points, branch upgrades and tree upgrades. Ordinary death is not prestige.

## Current UI

Implemented UI includes Forest Essence, branch information, Tree Age, wave information, enemy count, Tree HP, health bar, wave-complete message, Game Over panel, respawn countdown, retry button, Branch Upgrade panel and Tree Upgrade panel.

Upgrade panels display current and next values, costs, disabled states when Essence is insufficient and `MAX` at the current cap.

The UI still uses fixed positions and is a prototype. Responsive containers and anchors are planned before mobile support or final release.

## Visual status

Current visuals are placeholders: procedural tree and branches, simple enemies, procedural ground, green Essence circles, basic tweens and basic UI panels.

Planned direction:

- Pixel-art style
- Visible tree growth by Age
- Natural branch evolution
- More expressive enemies
- Better terrain, shadows and depth
- Better attack, impact and pickup effects
- Strong visual identity for each branch type

## Systems intentionally postponed

- Garden system
- Permanent meta progression
- Prestige implementation
- Save system
- Offline progress
- Branch-selection screen
- Additional branch archetypes
- Full talent-tree UI and functional talents
- Elite enemies and bosses
- Enemy status effects
- Sound and music
- Final pixel-art assets
- Mobile controls and responsive UI
- Steam integration and achievements
- Localization
- Data-driven wave configuration

## Recommended next development stage

1. Perform a longer stability test.
2. Clean and review current scripts.
3. Confirm death, respawn and upgrade persistence across multiple stages.
4. Add one genuinely different second branch type.
5. Add one new enemy archetype.
6. Begin the first functional talent-tree prototype.
7. Add simple sound effects.
8. Start replacing placeholder graphics.

## Immediate next task

Add one genuinely different branch archetype as a small vertical prototype. It should introduce a clear combat role such as area damage, damage over time, slowing, projectiles, support, healing or summoned units.

## Current milestone status

### Completed

- Central tree, health, death, automatic respawn and manual retry
- Stage restart after death
- Two independent combat branches
- Branch XP, levels and Talent Point milestones
- Natural branch visual growth
- Automatic targeting and attacks
- Enemy movement, attacks, scaling and crowd lanes
- Dynamic per-lane queues and pseudo-3D ground
- Forest Essence drops, multiple orbs and Essence Gain
- Tree Age, hit feedback and health bars
- Branch and tree upgrade interactions
- Damage, Attack Speed and Range upgrades
- Range based on branch length with a maximum Essence bonus
- Maximum HP, HP Regeneration and Essence Gain upgrades
- Upgrade caps, costs, branch selection and unified Attack Speed display

### In progress

- Combat polish
- Balancing
- UI layout polish
- Script cleanup
- Documentation

### Not started

- Prestige
- Garden
- Additional branches and enemies
- Functional talent trees
- Bosses
- Saving and offline progress
- Audio and final art
- Mobile UI and meta progression
- Steam integration and localization

## Development principles

- Add one small feature at a time.
- Test after every meaningful change.
- Commit after stable milestones.
- Avoid building future systems before the current loop is clear.
- Keep gameplay code independent from final artwork.
- Replace whole scripts when major edits reduce merge or indentation risk.
- Optimize only when there is a real performance issue.
- Preserve the option for a future mobile release.
- Keep XP, Talent Points and Forest Essence separate.
- Use branch levels for growth and unlocks rather than automatic stat scaling.
- Ensure every upgrade has a meaningful limit.
