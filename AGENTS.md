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

`ItemDefinition` is immutable shared content identified by stable `item_id` and registered through the central `ContentRegistry` / `GameContent` path. `ItemInstance` owns mutable per-item state: `instance_id`, `definition_id`, Item Level, equipment rarity, affix rolls, and lock state. Never mutate a shared `ItemDefinition` Resource to represent a rolled item. Inventory, equipment activation, loot generation, and persistence remain separate runtime layers from definition content; do not create a parallel item registry.

Equipment rarity uses exactly Common, Uncommon, Epic, and Legendary and is separate from Legendary Branch Tier I-III. Production equipment slots are Bark, Roots, Heartwood, Canopy, and Sap through stable `StringName` slot IDs. Soul Relic remains reserved for future Tree Soul-specific design. Equipment slot lists, runtime state, stat aggregation, loot filtering, and TREE filters derive from `EquipmentSlotRules`; never repurpose enum indexes as persistent identity or duplicate Bark/Roots-only lists.

`Inventory` owns concrete `ItemInstance` objects by stable `instance_id`. `Equipment` references inventory items only by `instance_id`, never by `definition_id`; equipped items remain in the inventory collection and are not copied, removed, or destroyed by equip, replacement, or unequip. Slot compatibility always comes from `ItemDefinition.equipment_slot_id` and `EquipmentSlotRules`, and runtime equipment operations never mutate shared `ItemDefinition` Resources.

Inventory and equipment are in-memory only until the general save system is implemented. Production inventory starts empty and must not silently receive starter items. TREE equipment selection is allowed whenever the tree is alive, including Preparation and active Waves, and must not pause or reset gameplay. Equipment state and gameplay stat application remain separate runtime layers.

Use reusable modifiers/effects for mechanics that may apply to more than one branch, enemy, talent, or Soul. Do not hardcode a reusable mechanic into one branch script merely because that branch is the first user.

Branch Seed unlocks are persistent meta-progression stored as stable legendary Branch IDs. Normal death and prestige runs do not clear them. Run modifiers and shared Resources must never mutate Branch Seed unlock state.

Standard Branches always use Legendary Tier 0 and do not display a Tier label. Legendary Branches use the player-facing labels `Tier I`, `Tier II`, or `Tier III`. Tier expresses the general rarity, complexity, and potential of an Apex Branch, but a higher Tier is not automatically best for every build. Legendary Tier is separate from the colored rarity of ordinary equipment. Future UI must use the Tier display text supplied by `BranchDefinition` consistently.

Branch Seed content is selected by the current `StageDefinition` loot pool, never by a per-enemy Branch list. `EnemyDefinition` supplies only the encounter rank (`normal`, `miniboss`, or `boss`), roll chance, and pity points. Pity is persistent and stored separately for Tiers I, II, and III. Normal enemies cannot grant Branch Seeds. The current shared Guardian Grove schedule places a Bark Warden miniboss at Wave 50 and an Ancient Bark Colossus boss at Wave 100 of every Substage. Bark Warden uses Root Slam. Ancient Bark Colossus uses Colossal Quake and enters Phase 2 once at or below 50% maximum health.

Boss abilities are per-enemy-instance runtime state. Boss Resources may contain immutable configuration, but cooldown, phase, active telegraph, Tween/Timer, and pending damage must never be stored as mutable state in shared Resources. Every delayed boss ability effect must be safely cancelled when the enemy dies or leaves the tree, including Retry and wave cleanup. Boss abilities must use the existing tree damage pipeline and must not mutate loot, Branch Seeds, progression, or wave state.

Branch archetype progression is shared at runtime by stable `branch_id` through `BranchProgress`: XP, level, total Talent Points earned, and Essence-upgrade levels. Talent selection is stored by stable `slot_id + branch_id`; each physical Branch slot has its own talent build, and multiple copies of the same archetype may use different talents. Each slot gets the full Talent Point budget unlocked by the shared archetype level, while available Talent Points are derived from that budget minus the selected slot loadout's spent points rather than stored as shared mutable currency. Unequip/re-equip must not erase a slot-plus-archetype talent loadout. A standard archetype may be equipped in all four standard slots; Apex Branches remain restricted to Slot 5. Talent respec is not implemented. Combat cooldown positions, targets, projectiles, tweens, and temporary talent-effect state remain per-instance. Branch progression and talent loadouts are not yet saved to disk.

`BranchLoadout` is the runtime authority for equipped Branch IDs by stable `slot_id`: `standard_slot_1`, `standard_slot_2`, `standard_slot_3`, `standard_slot_4`, and `apex_slot`. Duplicate standard archetypes are allowed. An initialized slot may explicitly contain `&""` for EMPTY; this differs from an uninitialized slot and must survive MainWorld recreation. Apex defaults to initialized EMPTY, accepts only valid Legendary BranchDefinitions, and its runtime assignment also survives MainWorld recreation. Branch loadout assignments are not yet saved to disk. `TreeBranchLoadoutController` owns runtime Branch Node creation and destruction only, instantiating `BranchDefinition.branch_scene`; it does not own the authoritative loadout. BranchProgress and `slot_id + branch_id` talent loadouts survive equip/unequip. Apex talent loadouts use `apex_slot + branch_id`. `BranchLoadout` remains a low-level runtime service: its Apex equip and unequip APIs are not Preparation- or Branch Seed unlock-gated. Do not reintroduce static standard `CombatBranch` instances into `tree.tscn`.

Player-facing standard Branch changes are allowed whenever the tree is alive, including during active Waves. Preparation still occurs before the first Wave of a new run, after the final Wave of each Substage, and after death before restarting the current Substage, but it is not a Branch loadout lock. During Preparation, WaveDirector is stopped, no enemies are active, CombatBranches are stopped, and TREE opens automatically. A replacement Branch must inherit the current combat state: active during live combat and stopped during Preparation. All valid registered standard BranchDefinitions are currently available because no standard Branch unlock system exists. Duplicate standard archetypes remain allowed. Candidate preview must show the preserved `slot_id + branch_id` talent build before confirmation.

Player-facing Apex selection is allowed whenever the tree is alive. Candidate IDs come only from persistent `BranchSeeds` unlocked IDs and every candidate must resolve to a valid Legendary BranchDefinition eligible for the Apex slot. Unlocking a Legendary Branch must never automatically equip it; default Apex remains initialized EMPTY. Locked Legendary definitions must never be player-equippable. Unknown unlocked legacy IDs may be displayed in the Seed collection, but they are not equippable. Legendary Tier player-facing text always comes from `BranchDefinition`. Apex is one conceptual and physical runtime `CombatBranch` mounted at the dedicated topmost `AttachmentPoints/Apex/BranchMount`; do not model a two-sided Apex as two equipped Branch instances.

Replacing any runtime Branch must stop and remove the previous instance before the replacement becomes active. Delayed attacks, projectiles, healing effects, Timers, Tweens, and other combat state from a removed Branch must not survive replacement. Changing Branch loadout must never pause or reset SceneTree, WaveDirector, enemies, tree state, progression, loot, or pity.

Thorn Crown is the first production Legendary Branch. Its stable ID is `thorn_crown`; it is a Tier I Legendary restricted to the Apex Slot. One physical runtime Branch independently finds the nearest valid primary target on the left and right during each attack cycle. Each populated side creates one Thorn Burst that deals area damage through `AttackResolver`; either side may attack when the other has no valid target. V1 base balance is 12 damage, 2.40-second cooldown, 0.80-second minimum cooldown, 350 range, and 90 Burst Radius. Its Essence upgrades are Thorn Damage (+2 damage per level), Attack Speed (-0.08 seconds per level), and Burst Radius (+8 per level). Its talents are Barbed Core (primary target +40%), Twin Torment (both sides active gives +25% cycle damage), and Overgrowth (every third real attack cycle gives +30% damage and +50% radius).

Thorn Crown attacks require visible procedural presentation feedback tied to actual attack execution. The pulse, snap, flash, and cleanup are presentation-only and must never alter damage, range, targeting, cooldown, or attack timing. Replacement, `stop_combat()`, defeat, and node removal must cancel the presentation safely.

Guardian Grove has exactly one production Legendary Branch Seed entry: Thorn Crown (`thorn_crown`), Tier I, weight 1.0. Branch Seed encounter roll values remain enemy-owned: Bark Warden is a miniboss with a 5% roll chance and +1 Tier I pity on a failed eligible roll; Ancient Bark Colossus is a boss with a 15% roll chance and +3 Tier I pity. The Guardian Grove Tier I pity threshold remains 12. When Thorn Crown is already unlocked and no other locked Tier I entries exist, further Guardian Grove boss encounters do not roll a duplicate Seed or increase Tier I pity.

Branch Seed acquisition presentation is driven only by `BranchSeeds.branch_seed_dropped` after a successful persisted natural drop. The notification resolves the Branch display name and Legendary Tier from `GameContent` and `BranchDefinition`, and resolves the source enemy display name from `GameContent` when available. It does not mutate unlocks, pity, loadout, progress, or waves; does not pause combat; ignores mouse input; remains visible over TREE during Preparation; and auto-hides after a short presentation. Registration, pool membership, disk reload, and service-level unlock alone must not replay the natural-drop notification. Do not duplicate Legendary Tier mappings or Branch display names in notification UI.

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

## Equipment stat application

- Equipped `ItemInstance` affixes are projected into gameplay through the shared runtime modifier layer. Never mutate `ItemDefinition`, Branch base values, or Tree base values to apply equipment.
- Equipment modifier rebuilds own only the dedicated `equipment` RunModifiers source and must never clear unrelated sources.
- Equipment percentage affixes use fractional values: `0.10` means +10%. Percentage bonuses aggregate additively within the Equipment source before that source composes multiplicatively with other RunModifier sources.
- Equipment `maximum_health` is flat HP. Equipment `health_regeneration` is flat HP per second and remains separate from percentage-of-maximum-health regeneration.
- Equipment `branch_damage` is percentage Branch Damage. Equipment `attack_speed` is percentage offensive Branch Attack Speed and must not affect Blossom healing timing.
- Live equipment Maximum HP changes preserve the current-health percentage, never create an equip/unequip healing exploit, and never revive a dead tree.
- Equipment stat rebuilds must remain idempotent across repeated rebuilds and MainWorld recreation.
- Item Level, rarity, and lock state do not independently scale or suppress an already rolled `ItemAffixRoll.value`.
- Equipment Stat Application V1 supports only Maximum Health, Health Regeneration, Branch Damage, and Attack Speed. Unknown affixes remain valid item data but are ignored by gameplay projection.

## Equipment loot

- Equipment loot is automatically collected into `Inventory`; it has no physical pickup and requires no player interaction. A drop never auto-equips an item.
- Enemy equipment reward eligibility is data-driven through `EnemyDefinition` reward fields. Branch Seed loot and equipment loot are independent reward systems.
- Item Level is mutable runtime `ItemInstance` data derived from encounter progression and source difficulty. Never write Item Level, rarity, or affix rolls into `ItemDefinition`.
- Equipment rarity and affixes are rolled when the concrete `ItemInstance` is generated. Generated ownership identity is always the unique `instance_id`, never `definition_id`.
- Random equipment generation must use an owned, testable RNG and deterministic seeded tests. Prototype generation values belong in centralized equipment loot rules.
- Boss equipment guarantees are encounter-level. Left and right runtime instances of the same boss archetype share one `stage_id + global_wave + enemy_id` guarantee.
- A boss guarantee is claimed only after successful Inventory insertion. Claimed guarantees survive ordinary Retry within the current process to prevent reward farming.
- Basic Equipment Loot V1 generates only Common, Uncommon, and Epic. Legendary remains valid foundation data but is reserved for future unique-effect items.
- Production normal-enemy equipment chance must never be temporarily raised for manual testing and committed.
- Equipment drop notifications are centered reward feedback with a bounded queue. They ignore mouse input and must never pause gameplay or conflict with the independent Branch Seed notification.

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

Normal Wave overlap is disabled for onboarding Waves 1–10. After onboarding, only adjacent normal Waves may overlap, only after the current Wave finishes spawning and reaches its configured survivor threshold, and never with more than two active cohorts. Boss/miniboss Waves and Preparation boundaries are hard no-overlap boundaries. Every enemy retains its origin global Wave for tracking, scaling, completion, Item Level, and reward context even when `current_wave` represents a newer launched Wave. Wave completion remains ordered, and Age advances only from ordered completion rather than Wave launch.

## Combat targeting

- Enemies use explicit lane information.
- Do not use vertical Y-distance tolerance as a substitute for lane targeting.
- Validate a target immediately before applying an attack, projectile, secondary hit, or healing effect.
- Reusable targeting belongs in shared targeting utilities/profiles.
- Preserve current preferred-lane and fallback behavior unless the task explicitly changes it.
- Do not silently convert preferred targeting into strict targeting.

## UI behavior

- The main right-side upgrade area has BRANCHES, TRUNK, and SOUL tabs. TRUNK is the small right-side tree-stat upgrade tab.
- TREE is the fullscreen Branch/loadout overview. It may replace standard and unlocked Apex Branches whenever the tree is alive; tree defeat disables editing. It must not mutate progress, buy talents or upgrades, bypass Branch Seed unlocks, or duplicate gameplay stat calculations.
- TREE slot selection uses stable `slot_id`. Its physical layout is Slot 2 upper-left, Slot 1 lower-left, Slot 4 upper-right, Slot 3 lower-right, and Apex top-center.
- TREE reads shared archetype progress from `BranchProgress`, the per-slot talent build from `slot_id + branch_id`, effective stats from the actual runtime Branch, and unlocked Legendary Branch Seeds from `BranchSeeds`.
- TREE exposes a global Inventory overview in addition to per-slot equipment selection. Inventory cards always identify concrete items by `instance_id`, so multiple instances of one `ItemDefinition` remain independent.
- Player-facing Legendary Tier text in TREE comes from `BranchDefinition`.
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
