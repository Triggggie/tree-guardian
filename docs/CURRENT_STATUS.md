# Tree Guardian — Current Status

_Last updated: 27 July 2026_

## Project overview

**Tree Guardian** is a 2D idle / tower-defense game built in Godot 4.7.1.

The player is the last Tree of Life. The tree stands in the center of the battlefield and defends itself against enemies approaching from both sides.

The current project uses temporary geometric graphics. Final visuals are planned as pixel art.

## Core design

- The player controls and develops one central Tree of Life.
- The tree's overall progression is represented by **Age**.
- One completed wave adds one year of Age.
- Combat branches gain their own XP from kills.
- Each branch levels independently.
- Forest Essence is the main currency.
- Forest Essence is separate from branch XP.
- Main branches are planned to be unique in the final game.
- Current mirrored strength branches exist only for prototype testing.

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
│   └── GameOverPanel
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
- Game-over signal
- Idle breathing animation
- Red flash and shake when damaged
- Health label
- Green health bar

Current base tree health:

```text
100 HP
```

## Strength branches

Two mirrored strength branches are currently attached to the tree for testing.

Each branch has:

- Independent XP
- Independent level
- Automatic target selection
- Automatic attacks
- Damage scaling
- Attack-speed scaling
- Visual growth
- Level 3 evolution
- Wider attack arc at Level 3
- Thorns at Level 3
- Combat shutdown after game over

Current prototype values:

```text
Range: 260
Base damage: 10
Damage per level: +2
Base cooldown: 1.5 s
Cooldown reduction per level: 0.15 s
Minimum cooldown: 0.45 s
Base attack angle: 18°
Level 3 attack angle: 30°
XP required per level: 2
Base branch length: 150
Length per level: +20
Base thickness: 24
Thickness per level: +3
```

## Bark beetle enemy

The bark beetle currently supports:

- Movement toward the tree
- Wave-based health scaling
- Automatic attacks
- Independent movement-speed variation
- Multiple depth lanes
- Per-lane attack queues
- Queue advancement after the front enemy dies
- Health bar shown after receiving damage
- Red hit flash
- Hit shake
- Death shrink and fade
- Forest Essence drop
- Branch XP reward
- Combat shutdown after game over
- Pseudo-3D rendering by Y position

Current base values:

```text
Movement speed: 120
Base health: 30
Attack damage: 5
Attack cooldown: 1.5 s
XP reward: 1
```

## Enemy crowd and battlefield depth

Enemies now move in a crowd formation rather than one flat line.

Current behavior:

- Enemies spawn from both sides.
- They are distributed across several shallow depth lanes.
- Each enemy receives a slightly different movement speed.
- Enemies in lower lanes are rendered in front of enemies in upper lanes.
- Enemies can visually overlap.
- Each lane has its own attack queue.
- Only the first living enemy in each lane attacks.
- When that enemy dies, the next enemy in the same lane advances.

The ground is currently drawn procedurally and includes:

- A distant lighter section
- A closer darker section
- A visible horizon
- Perspective lines
- Enough depth for all enemy lanes to appear grounded

This is a 2.5D presentation, not real 3D.

## Wave system

The wave system currently supports:

- Automatic endless wave loop
- Enemy spawning from both sides
- Enemy-count scaling
- Enemy-health scaling
- Maximum enemy count
- Maximum enemy health
- Spawn delay
- Short delay between waves
- Age increase after completing a wave
- Wave-complete message
- Full shutdown after tree death

Current default scaling:

```text
Base enemies per side: 2
One additional enemy every 3 waves
Maximum enemies per side: 30
Base enemy health: 30
Health increase per wave: +3
```

Current wave transition:

```text
Last enemy dies
→ WAVE X COMPLETE appears briefly
→ short pause
→ next wave begins
```

There is intentionally no 3–2–1 countdown between ordinary waves because it would slow the game unnecessarily.

## Forest Essence

When an enemy dies:

1. It drops one Forest Essence.
2. The drop waits briefly.
3. It flies toward the tree.
4. The tree receives the currency.

Forest Essence is planned to fund upgrades and future progression systems.

## Game over

When the tree reaches zero health:

- The tree dies.
- Branch combat stops.
- Enemy combat stops.
- Wave spawning stops.
- Wave messages disappear.
- The Game Over panel appears.
- The restart button reloads the current scene.

## Current UI

Implemented UI elements:

- Forest Essence
- Branch information
- Tree Age
- Current wave
- Tree HP text
- Tree health bar
- Wave-complete message
- Game Over panel
- Restart button

The current UI uses fixed positions and is still a prototype.

Before mobile support or final release, it should be rebuilt using responsive containers and anchors.

## Visual status

Current visuals are placeholders:

- Tree: procedural shapes
- Branches: procedural shapes
- Enemies: circles and lines
- Ground: procedural rectangles and lines
- Effects: simple tweens and color flashes

The gameplay systems should remain independent of the final artwork.

Planned final direction:

- Pixel-art visual style
- Tree growth visible with Age
- Branch visual evolution by level
- More expressive enemy animation
- Better terrain
- Shadows
- Improved depth
- Attack and impact effects

## Health-bar decision

Regular enemy health bars currently stay hidden until the enemy is damaged.

This is intentional because permanently showing every health bar would create visual clutter when large crowds are present.

Possible later improvements:

- Hide health bars again after 1–2 seconds
- Keep them visible at low health
- Always display bars for elite enemies and bosses
- Add an accessibility setting

## Systems intentionally postponed

The following features are not part of the current implementation stage:

- Garden system
- Permanent meta progression
- Save system
- Offline progress
- Upgrade menu
- Branch selection screen
- Additional branch archetypes
- Elite enemies
- Bosses
- Enemy status effects
- Sound and music
- Final pixel-art assets
- Mobile controls
- Responsive UI
- Steam integration
- Achievements
- Localization

## Planned garden system

The garden may later provide modular upgrades such as:

- Attack-speed bonus
- Tree defense
- Health regeneration
- Forest Essence gain
- Branch damage
- Special combat modifiers

This system has not been implemented yet.

## Recommended next development stage

The next stage should focus on improving the existing combat loop rather than adding many new systems.

Recommended order:

1. Review and clean the current scripts.
2. Confirm all current systems work after several waves.
3. Add a basic branch-upgrade interaction.
4. Add one genuinely different second branch type.
5. Add one new enemy archetype.
6. Add simple sound effects.
7. Start replacing placeholder graphics.

## Immediate next task

The most useful next gameplay addition is a basic upgrade interaction for branches.

A small prototype could allow the player to:

- click a branch,
- view its current statistics,
- spend Forest Essence,
- improve one stat,
- immediately see the result.

This would connect the existing combat, currency and branch systems into a more complete gameplay loop.

## Current milestone status

### Completed

- Central tree
- Tree health and death
- Two independent combat branches
- Branch XP and levels
- Automatic targeting and attacks
- Enemy movement and attacks
- Wave loop
- Enemy scaling
- Forest Essence drops
- Tree Age
- Hit feedback
- Death feedback
- Enemy health bars
- Tree health bar
- Game Over panel
- Restart
- Crowd lanes
- Different enemy movement speeds
- Dynamic per-lane queues
- Pseudo-3D ground
- Wave-complete message

### In progress

- Combat polish
- Balancing
- Documentation

### Not started

- Player-controlled upgrades
- Garden
- Additional branches
- Additional enemies
- Bosses
- Saving
- Audio
- Final art
- Mobile UI
- Meta progression

## Development principles

- Add one small feature at a time.
- Test after every meaningful change.
- Commit after stable milestones.
- Avoid building future systems before the current loop is clear.
- Keep gameplay code independent from final artwork.
- Replace whole scripts when major edits reduce the risk of indentation or merge mistakes.
- Only optimize when there is a real performance issue.
- Preserve the option for a future mobile release.
