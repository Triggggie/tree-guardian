# Tree Guardian — Codex Instructions

## Project overview

Tree Guardian is a 2D idle / tower-defense game built in Godot 4.7 with GDScript.

- Main scene: `res://scenes/main_world.tscn`
- Base viewport: 1920 × 1080
- Rendering: Forward Plus
- Main gameplay code: `res://scripts/`
- Content resources: `res://resources/`
- Global services are registered as Godot autoloads:
  - `RunModifiers`
  - `TreeSouls`
  - `GameContent`
  - `BranchSeeds`
  - `BranchProgress`

Read the relevant scene, scripts, resources, and service definitions before changing code. Never infer node paths, signals, methods, or resource fields without verifying them in the repository.

## Working style

- Make the smallest change that fully satisfies the task.
- Change only the files explicitly allowed by the task.
- If another file is genuinely required, stop and explain why before editing it.
- Do not perform unrelated refactors, renames, formatting passes, reorganizations, or cleanup.
- Preserve existing gameplay behavior unless the task explicitly changes it.
- Do not merge directly into `main`.
- Do not amend, rewrite, or squash existing commits.
- Prefer one focused commit per task.
- Before finishing, review the complete diff and report every changed file.
- Never claim that Godot was run if the executable was unavailable.

## Godot and GDScript conventions

- Target Godot 4.7 and GDScript 2.
- Use tabs for indentation.
- Preserve the existing formatting style.
- Use explicit types for important variables, parameters, and return values.
- Keep generic declarations such as `Array[TreeSoulDefinition]` on one line. Multiline generic type declarations have caused parser errors in this project.
- Use `StringName` IDs for stable gameplay/content identifiers.
- Preserve existing node names and node paths unless the task explicitly requires a scene change.
- Do not invent Godot UIDs or hand-create `.uid` values.
- Do not edit `project.godot` unless the task explicitly requires it.
- Do not pause the game for ordinary UI panels or Tree Soul selection.
- Treat `.tscn` and `.tres` files as structured Godot resources; keep edits minimal and preserve unrelated properties.

## Architecture

Use a Godot-friendly component and custom Resource architecture, not a full ECS.

Content belongs in data resources. General mechanics belong in reusable scripts and services.

Current and planned definition types include:

- `BranchDefinition`
- `UpgradeDefinition`
- `TalentDefinition`
- `TalentTreeDefinition`
- `TreeSoulDefinition`
- `TreeSoulBonusDefinition`
- `EnemyDefinition`
- `WaveDefinition`
- `StageDefinition`
- `StatusEffectDefinition`
- `TargetingProfile`

Use `ContentRegistry` and `GameContent` for content lookup. Do not hardcode content lists into gameplay or UI scripts when the registry already provides them.

Use reusable modifiers/effects for mechanics that may apply to more than one branch, enemy, talent, or Soul. Do not hardcode a reusable mechanic into one branch script merely because that branch is the first user.

Branch Seed unlocks are persistent meta-progression stored as stable legendary Branch IDs. Normal death and prestige runs do not clear them. Run modifiers and shared Resources must never mutate Branch Seed unlock state.

Standard Branches always use Legendary Tier 0 and do not display a Tier label. Legendary Branches use the player-facing labels `Tier I`, `Tier II`, or `Tier III`. Tier expresses the general rarity, complexity, and potential of an Apex Branch, but a higher Tier is not automatically best for every build. Legendary Tier is separate from the colored rarity of ordinary equipment. Future UI must use the Tier display text supplied by `BranchDefinition` consistently.

Branch Seed content is selected by the current `StageDefinition` loot pool, never by a per-enemy Branch list. `EnemyDefinition` supplies only the encounter rank (`normal`, `miniboss`, or `boss`), roll chance, and pity points. Pity is persistent and stored separately for Tiers I, II, and III. Normal enemies cannot grant Branch Seeds. The current shared Guardian Grove schedule places a Bark Warden miniboss at Wave 50 and an Ancient Bark Colossus boss at Wave 100 of every Substage. These bosses use the shared melee runtime and do not yet have unique abilities or phases.

Branch archetype progression is shared at runtime by stable `branch_id` through `BranchProgress`. Physical Branch Node instances must not own authoritative XP, level, Talent Points, talent purchases, or Essence-upgrade levels. Combat cooldown positions, targets, projectiles, tweens, and temporary talent-effect state remain per-instance. Branch progression is not yet saved to disk.

## Run modifier IDs

The canonical modifier IDs are:

```gdscript
const BRANCH_DAMAGE: StringName = &"branch_damage"
const ATTACK_SPEED: StringName = &"attack_speed"
const TREE_MAX_HEALTH: StringName = &"tree_max_health"
const TREE_REGEN_RATE: StringName = &"tree_regen_rate"
const ESSENCE_GAIN: StringName = &"essence_gain"
const HEALING_POWER: StringName = &"healing_power"
```

Temporary aliases may exist for compatibility. New code should use the canonical names.

Modifier semantics:

- `BRANCH_DAMAGE` affects branch damage, secondary branch attacks, branch DoT, and offensive branch abilities. It does not affect healing.
- `ATTACK_SPEED` affects attacks, projectile firing, and possibly offensive active cooldowns. It does not affect passive healing ticks, HoT refresh, DoT tick rate, buff duration, debuff duration, waves, or enemies.
- `TREE_MAX_HEALTH` affects the tree’s maximum HP.
- `TREE_REGEN_RATE` is percentage-of-maximum-HP regeneration per second.
- `ESSENCE_GAIN` affects actual gameplay Essence rewards, not refunds, loading, restoration, or debug grants.
- `HEALING_POWER` is reserved for healing mechanics and future talents. No base Tree Soul currently grants it.

## Tree Soul rules

Tree Souls are a run-long specialization selected during a prestige run.

- The Soul orb exists visually from Age 1 but is gray and inactive.
- Soul selection unlocks at Age 200.
- The selection screen does not pause gameplay.
- While selection is pending, no Soul bonus is active.
- The player may choose later; Rank is calculated from the current Age at the moment of selection.
- A selected Soul cannot be changed during the current prestige run.
- Normal death preserves Age, selected Soul, Soul Rank, Essence, XP, talents, and purchased upgrades.
- Prestige resets Age to 1, clears the selected Soul, resets Soul Rank to 0, locks selection until Age 200, and returns the orb to gray.

Rank progression:

- Rank 1 begins at Age 200.
- A new Rank is gained every 100 Age.
- Formula: `1 + floor((age - 200) / 100)`.
- There is no hard maximum Rank.
- After Rank 50, per-rank growth may be multiplied by a configurable soft-cap multiplier, currently 0.5.

Soul identities:

- Crimson: branch damage only.
- Azure: attack speed only.
- Golden: Essence gain.
- Verdant: maximum HP plus percentage-of-maximum-HP tree regeneration.

Maximum HP formula:

`(base maximum HP + purchased flat maximum HP upgrades) * Verdant multiplier`

Tree regeneration formula:

`flat regeneration from Tree Upgrades + maximum HP * Verdant regeneration rate`

Essence formula:

`base reward * Tree Upgrade multiplier * Golden modifier`

Do not apply Soul modifiers to refunds, save restoration, debug setup, or unrelated systems.

## Age and wave progression

Age increases only when the player completes a new highest global wave for the first time.

Example:

- Complete waves 1–4.
- Die during wave 5.
- Replay waves 1–4: no additional Age.
- Complete wave 5 for the first time: Age increases.

Do not reintroduce Age farming from repeated waves.

## Combat targeting

- Enemies use explicit lane information.
- Do not use vertical Y-distance tolerance as a substitute for lane targeting.
- Validate a target immediately before applying an attack, projectile, secondary hit, or healing effect.
- Reusable targeting belongs in shared targeting utilities/profiles.
- Preserve current preferred-lane and fallback behavior unless the task explicitly changes it.
- Do not silently convert preferred targeting into strict targeting.

## UI behavior

- The main right-side upgrade area has BRANCHES, TREE, and SOUL tabs.
- Only one of `BranchUpgradePanel`, `TreeUpgradePanel`, and `TreeSoulStatusPanel` may be visible at a time.
- The active tab button is disabled; the other tab buttons remain enabled.
- BRANCHES remains the default tab on game start.
- The TALENTS button and Talent Screen must keep working.
- UI panels must not pause combat unless a future task explicitly requires it.
- Dynamic UI should read content from definitions/registry rather than duplicate Soul data in the UI script.

## Validation and testing

Before editing:

1. Inspect all relevant files.
2. State the exact files expected to change.
3. Confirm the existing node paths, signal names, method names, and resource fields.

After editing:

1. Review the full diff for accidental changes.
2. Run `git diff --check`.
3. Run a Godot parse/import check when a Godot executable is available:

```sh
if command -v godot4 >/dev/null 2>&1; then
  godot4 --headless --path . --editor --quit
elif command -v godot >/dev/null 2>&1; then
  godot --headless --path . --editor --quit
else
  echo "Godot executable unavailable; runtime validation must be performed locally."
fi
```

4. Report whether Godot was actually available and whether the command passed.
5. Run `git status --short`.
6. Report:
   - changed files,
   - what changed in each file,
   - checks executed,
   - checks that could not be executed,
   - any remaining manual Godot test steps.

## Completion standard

A task is complete only when:

- the requested behavior is implemented,
- unrelated behavior is preserved,
- the diff contains no unrelated changes,
- available checks pass,
- unavailable checks are disclosed,
- manual test steps are clearly listed.

When requirements are ambiguous, stop and ask rather than making a broad design decision.
