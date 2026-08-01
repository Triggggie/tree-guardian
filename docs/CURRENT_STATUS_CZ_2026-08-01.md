# Tree Guardian — Aktuální stav projektu

_Poslední aktualizace: 1. srpna 2026_  
_Stav repozitáře: větev `main`, commit `fcb3536` — `Add Tree Soul tab button`_

> Tento dokument je aktuální zdroj pravdy pro stav implementace. Popisuje to, co je skutečně přítomné v repozitáři, a odděluje funkční systémy, částečné prototypy a plánované systémy. Při rozporu s historickými dokumenty má přednost tento soubor a aktuální kód.

## 1. Přehled projektu

**Tree Guardian** je 2D idle / tower-defense hra vytvářená v Godotu.

Hráč rozvíjí centrální Strom života, který stojí uprostřed bojiště. Nepřátelé přicházejí zleva i zprava a nasazené bojové větve strom automaticky brání.

Současná verze je technický prototyp. Používá procedurální kreslení, základní tweens a prototypové UI. Finální vizuální směr je pixel art.

## 2. Současné technické nastavení

- Engine: Godot 4.7; vývoj probíhá v Godotu 4.7.1 stable
- Jazyk: GDScript
- Renderer: Forward+
- Základní viewport: 1920 × 1080
- Hlavní scéna: `res://scenes/main_world.tscn`
- Hlavní scéna stromu: `res://scenes/tree/tree.tscn`
- Repozitář: `Triggggie/tree-guardian`
- Aktivní autoloady:
  - `RunModifiers`
  - `TreeSouls`
  - `GameContent`

## 3. Aktuální struktura hlavní scény

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

## 4. Stav vývojového plánu

Původní plán byl rozdělen na stabilizaci prototypu, vytvoření datového a servisního základu, migraci současných systémů a následné rozšiřování obsahu.

### Fáze 0 — Stabilizace současné hry

**Stav: dokončeno.**

Dokončené opravy zahrnují zejména:

- opakovanou validaci cíle před skutečným zásahem,
- validaci sekundárních zásahů Sweeping Strike,
- validaci cílů Blossom projektilů,
- společné zastavení a obnovení všech bojových větví,
- podporu více instancí stejného typu větve v Talent Screen,
- bezpečné minimální hodnoty XP a věku dospělosti stromu,
- rozdělování nepřátel mezi otevřené lanes,
- samostatnou kolizní vrstvu nepřátel,
- odstranění starého talentového režimu z panelu upgradů.

### Fáze 1 — Datový a servisní základ

**Stav: technický základ dokončen.**

V repozitáři existují obecné definice:

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

Dále jsou implementovány:

- `ContentRegistry`
- `ContentValidator`
- `ContentService` / autoload `GameContent`
- `RunModifierService` / autoload `RunModifiers`
- stabilní `StringName` modifier ID
- `AttackContext`
- `AttackResolver`
- `BranchStatCalculator`
- `CombatTargeting`

Důležité omezení: existence definic neznamená, že je celý prototyp již datově řízený. Současný `ContentRegistry` obsahuje čtyři Tree Soul resources. Pole pro branches, enemies, stages a status effects jsou připravená, ale zatím nejsou naplněná skutečným obsahem. Současné větve, Bark Beetle a WaveManager stále z velké části používají scénové a skriptové exporty.

### Fáze 2 — Migrace prototypu a Tree Soul V1

**Stav: probíhá; hlavní gameplay jádro je funkční, UI a persistence nejsou dokončené.**

Dokončeno:

- společné rozhraní `CombatBranch`,
- generické rozhraní upgradů a talentů,
- migrace Strength Branch na sdílené targeting, attack context, resolver a run modifiers,
- migrace Blossom Branch na oddělený damage, healing a attack-speed výpočet,
- čtyři Tree Soul resources,
- Tree Soul service, rank progression a aplikace modifierů,
- výběrová obrazovka Tree Soul,
- aplikace Crimson, Azure, Golden a Verdant bonusů,
- status panel Tree Soul,
- tlačítko záložky SOUL ve scéně,
- ochrana Age před farmením opakovaných vln.

Zbývá:

- zapojit `SoulTabButton` do `scripts/ui.gd`,
- přepínat mezi Branch, Tree a Soul panelem tak, aby byl viditelný vždy pouze jeden,
- dokončit a otestovat reset vizuálního stavu Tree Soul panelu,
- přidat neblokující oznámení při zvýšení Tree Soul Ranku,
- přidat viditelný Soul orb přímo na strom,
- implementovat skutečný prestige flow,
- implementovat save/load a ukládání Tree Soul stavu,
- dokončit migraci větví, nepřátel a vln na datové definice.

## 5. Strom a run progression

Strom aktuálně podporuje:

- Forest Essence,
- Age,
- maximální a aktuální HP,
- damage, smrt a revive,
- automatický respawn a manuální Retry,
- klidovou „dýchací“ animaci,
- damage flash a shake,
- procedurální růst podle Age,
- změny barev a detailů starého stromu,
- upgrady maximálního HP,
- upgrady ploché regenerace,
- upgrady Essence Gain,
- léčivé efekty v čase,
- procentní regeneraci z Tree Soul modifieru.

Základní maximum:

```text
100 HP
```

### Upgrady stromu

```text
Max HP: +20 za upgrade
HP Regeneration: +0,5 HP/s za upgrade
Essence Gain: +10 % za upgrade
Růst ceny: ×1,40
Základní limit upgradu: 3
+1 maximální level za každých 5 Age
```

### Výpočet maximálního HP

```text
(base maximum HP + ploché Max HP upgrady)
× Tree Max Health modifier
```

Verdant Soul se tedy aplikuje až po přičtení koupených plochých HP upgradů.

### Výpočet regenerace

```text
plochá regenerace z Tree Upgrades
+ max HP × Tree Regen Rate
```

### Výpočet Essence odměny

```text
base reward
× Tree Upgrade Essence multiplier
× Golden Soul modifier
```

Desetinné zbytky bonusové Essence se ukládají do bufferu, aby malé bonusy pravidelně vytvořily další skutečný orb.

## 6. Age, Wave a smrt

- Strom začíná na Age 1.
- Age se zvyšuje pouze při prvním dokončení nové nejvyšší globální vlny.
- Opakování již dokončených vln po smrti nepřidává další Age.
- Stage má v prototypu 100 vln.
- Po smrti se aktuální Stage restartuje od Wave 1.
- `highest_completed_wave` zůstává zachované, takže opakované snadné vlny nelze využít k farmení Age.

Příklad:

```text
Dokončení vln 1–4 → Age postupuje.
Smrt ve vlně 5.
Opakování vln 1–4 → žádný další Age.
První dokončení vlny 5 → Age se znovu zvýší.
```

Běžná smrt zachovává současnou run progression, včetně Age, Essence, XP, levelů, Talent Points, koupených talentů, upgradů a zvoleného Tree Soulu. Běžná smrt není prestige.

## 7. Nasazené větve

Současný strom má pět logických slotů. Čtyři jsou obsazené:

```text
Slot 1 — levá Strength Branch
Slot 2 — levá Blossom Branch
Slot 3 — pravá Strength Branch
Slot 4 — pravá Blossom Branch
Slot 5 — prázdný
```

Hra tedy již nepoužívá pouze dvě zrcadlové Strength Branches. Má dva funkční archetypy a dvě instance každého archetypu.

## 8. Společný CombatBranch systém

`CombatBranch` nyní poskytuje společný základ pro:

- identitu větve,
- stranu a slot,
- XP a level,
- Talent Points,
- zakoupené talenty,
- limity Essence upgradů,
- ceny upgradů,
- stop/resume combat,
- generické rozhraní statistik,
- generické rozhraní upgradů,
- generické rozhraní talentů,
- prerequisites a conflicts talentů.

Každá instance větve má vlastní XP, level, Talent Points, talenty a upgrady.

Talent Points se získávají na levelech:

```text
2, 4, 7, 10 a 14
```

Maximální level Essence upgradů větve:

```text
branch level × 3
```

## 9. Strength Branch

Strength Branch je melee/offensive archetyp.

### Základní hodnoty

```text
Base Damage: 10
Base attack cooldown: 1,5 s
Minimum cooldown: 0,45 s
Attack angle: 18°
Base range padding: 100
Damage per upgrade: +2
Cooldown reduction per upgrade: 0,08 s
Range per upgrade: +15
Maximum Essence range bonus: +150
Upgrade cost growth: ×1,35
```

### Vizuální růst

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

- používá explicitní lanes,
- preferuje nastavenou lane a povolený lane span,
- při nenalezení vhodného cíle používá fallback,
- nepoužívá vertikální Y-toleranci jako náhradu lane systému,
- cíl se znovu validuje těsně před zásahem.

### Funkční Strength talenty

#### Sweeping Strike — Crusher

- základní útok může zasáhnout druhého blízkého platného nepřítele,
- sekundární zásah má prototypově 60 % Damage,
- sekundární cíl se znovu validuje,
- sekundární zabití správně připisuje XP.

#### Rebuff — Warden

- platný zásah odhodí nepřítele od stromu,
- testovací vzdálenost je 35 px,
- používá obecné nepřátelské knockback rozhraní,
- funguje také na sekundární zásah Sweeping Strike.

#### Marked Prey — Duelist

- opakované zásahy stejného hlavního cíle získávají stacky,
- +10 % Damage za stack,
- maximum 5 stacků,
- stacky se resetují při změně cíle, stop combat nebo respawnu,
- sekundární Sweeping Strike stacky nevytváří.

## 10. Blossom Branch

Blossom Branch je hybridní support/ranged archetyp. Je nasazená na obou horních slotech stromu.

### Healing Over Time

```text
Base healing per tick: 3 HP
Base tick interval: 2,0 s
Minimum tick interval: 0,75 s
Effect duration: 6 s
Effect refresh interval: 6 s
```

- aplikuje na strom opakovaně obnovovaný HoT efekt,
- stejný effect ID se nestackuje; pouze se obnoví,
- healing strength používá `HEALING_POWER`,
- Azure attack speed nezrychluje healing ticks.

### Ranged petal attack

```text
Base petal damage: 3
Base attack interval: 2,0 s
Range: 650
```

- preferuje nepřátele na vlastní straně,
- při absenci vlastního cíle může použít opačnou stranu,
- projektil před vystřelením i při dopadu znovu validuje cíl,
- petal damage používá `BRANCH_DAMAGE`,
- cadence petal útoku používá `ATTACK_SPEED`.

### Blossom Essence upgrady

```text
Healing per Tick: +1 HP za upgrade
Healing Speed: -0,1 s tick interval za upgrade
Petal Damage: +1 za upgrade
```

Blossom zatím nemá vlastní funkční talentový strom.

## 11. Talent Screen

Samostatná obrazovka `TALENTS` je implementovaná.

Podporuje:

- otevření a zavření samostatné velké obrazovky,
- dynamické nalezení všech uzlů ve skupině `combat_branch`,
- řazení větví podle slotu,
- samostatné tlačítko pro každou nasazenou instanci,
- zobrazení talentových uzlů,
- detail talentu,
- požadovaný level,
- cenu v Talent Points,
- prerequisites,
- conflicts,
- nákup talentu,
- zachování možnosti prohlížet již koupený talent.

Současný Talent Screen umí pracovat s více instancemi stejného archetypu. Funkční obsah má zatím Strength Branch. Blossom se v selectoru může zobrazit jako nasazená větev, ale její seznam talentů je zatím prázdný.

## 12. Combat architektura

### AttackContext

Nese data o konkrétním útoku, například:

- source,
- target,
- damage,
- attack ID,
- tags,
- doplňková metadata.

### AttackResolver

Provádí společné vyhodnocení damage a odděluje vytvoření útoku od jeho aplikace.

### BranchStatCalculator

Centralizuje aplikaci:

- `BRANCH_DAMAGE`,
- `ATTACK_SPEED`,
- `HEALING_POWER`.

### CombatTargeting a TargetingProfile

Připravují opakovaně použitelné targeting chování:

- target group,
- priority,
- preferred/strict/any lane režim,
- preferred lane span,
- range,
- stranu stromu,
- validaci targetability.

## 13. Run modifiers

Kanonické modifier ID:

```gdscript
BRANCH_DAMAGE
ATTACK_SPEED
TREE_MAX_HEALTH
TREE_REGEN_RATE
ESSENCE_GAIN
HEALING_POWER
```

Význam:

- `BRANCH_DAMAGE` ovlivňuje branch damage, secondary attacks, branch DoT a offensive branch abilities. Neovlivňuje healing.
- `ATTACK_SPEED` ovlivňuje útoky a střelbu projektilů. Neovlivňuje passive healing tick interval, DoT tick rate, duration efektů, vlny ani nepřátele.
- `TREE_MAX_HEALTH` ovlivňuje maximum HP stromu.
- `TREE_REGEN_RATE` je procento maximálního HP regenerované za sekundu.
- `ESSENCE_GAIN` ovlivňuje skutečné gameplay odměny. Neovlivňuje refundy, load, restore ani debug granty.
- `HEALING_POWER` je samostatný prostor pro healing sílu a budoucí talenty.

## 14. Content architecture

`ContentRegistry` obsahuje připravené kolekce pro:

- branches,
- tree souls,
- enemies,
- stages,
- status effects.

Registry vytváří indexy podle stabilních ID a `ContentValidator` kontroluje definice při inicializaci `GameContent`.

Aktuálně jsou skutečně zaregistrované pouze čtyři Tree Souls. Ostatní definition classes jsou základ pro další migraci a nesmí být považované za dokončený datový content pipeline.

## 15. Tree Soul systém

### Základní pravidla

- výběr se odemkne na Age 20,
- výběrová obrazovka nezastavuje boj,
- dokud hráč Soul nevybere, není aktivní žádný Soul bonus,
- výběr lze provést později; Rank se vypočítá z aktuálního Age,
- Soul nelze během stejného prestige runu změnit,
- běžná smrt Soul nemaže,
- budoucí prestige má Soul vymazat a vrátit orb do neaktivního stavu.

### Rank progression

```text
Rank 1: Age 20
Další Rank: každých 100 Age
Rank = 1 + floor((Age - 20) / 100)
Soft cap: Rank 50
Růst po soft capu: 50 % běžného přírůstku
Hard cap: žádný
```

Příklady:

```text
Age 20 → Rank 1
Age 120 → Rank 2
Age 220 → Rank 3
```

### Crimson Soul

```text
Rank 1: +8 % Branch Damage
Přírůstek: +0,75 % za Rank
```

Ovlivňuje Strength damage a Blossom petal damage. Neovlivňuje Blossom healing.

### Azure Soul

```text
Rank 1: +6 % Attack Speed
Přírůstek: +0,40 % za Rank
```

Ovlivňuje Strength attack cadence a Blossom petal firing. Nezrychluje healing ticks.

### Golden Soul

```text
Rank 1: +3 % Essence Gain
Přírůstek: +0,25 % za Rank
```

Aplikuje se na skutečné gameplay Essence rewards.

### Verdant Soul

```text
Rank 1:
+15 % Maximum HP
+0,03 % Max HP za sekundu

Přírůstek za Rank:
+1,5 % Maximum HP
+0,003 % Max HP za sekundu
```

Max HP a procentní regenerace jsou zapojené přímo do stromu a reagují také na změnu Ranku nebo vymazání Soulu.

### Implementované Tree Soul UI

- `TreeSoulSelectionScreen`
- čtyřsloupcový výběr čtyř Soulů,
- barevné karty a popisy z Resources,
- `TreeSoulStatusPanel`,
- zobrazení jména, barvy, Ranku, bonusů, dalšího Ranku a progress baru,
- `SoulTabButton` ve scéně.

### Aktuální nedokončené části Tree Soul UI

1. `SoulTabButton` není zatím zapojený v `scripts/ui.gd`.
2. Status panel proto není normálně dostupný přepnutím záložky.
3. Inactive refresh status panelu nastavuje orb na šedou, ale po předchozím výběru neodstraňuje barevný override názvu Soulu; při skutečném clear/prestige se má tento stav opravit.
4. Neexistuje rank-up notification.
5. Neexistuje grafický orb přímo na stromu.
6. Neexistuje dokončený prestige a save/load flow.

## 16. Nepřítel Bark Beetle

Bark Beetle podporuje:

- pohyb ke stromu,
- škálování HP podle globální vlny,
- útoky na strom,
- explicitní lane index a lane Y,
- frontu útoku v každé lane,
- targetability kontrolu,
- damage feedback,
- health bar,
- death animaci,
- Essence reward,
- branch XP reward,
- knockback a knockback resistance,
- stop/resume combat,
- samostatnou collision layer.

Současné prototypové hodnoty:

```text
Base HP: 30
HP per wave: +3
Attack Damage: 5
Attack cooldown: 1,5 s
XP reward: 1
Base Essence reward: 1
```

## 17. WaveManager a lanes

Současný WaveManager stále přímo načítá Bark Beetle scénu a používá exportované prototypové hodnoty.

```text
Waves per Stage: 100
Base enemies per side: 2
+1 enemy per side every 3 waves
Maximum enemies per side: 30
Lane count: 5
Spawn interval: 0,25 s
```

Nepřátelé jsou rozdělováni do lane pořadí tak, aby se otevřené lanes využívaly rovnoměrněji. Hloubka bojiště používá lane scale a Y jitter pro pseudo-3D dojem.

`WaveDefinition`, `StageDefinition` a `EnemyDefinition` existují, ale runtime WaveManager a Bark Beetle ještě nejsou plně přestavěné na tyto resources.

## 18. Současné UI

Funkční:

- Forest Essence label,
- branch info,
- Age,
- Wave,
- Tree HP label a health bar,
- wave-complete message,
- Game Over panel,
- respawn/retry,
- generický Branch Upgrade Panel,
- Tree Upgrade Panel,
- BRANCHES a TREE tabs,
- samostatný Talent Screen,
- Tree Soul selection overlay.

Připravené, ale nedokončené:

- SOUL tab button existuje,
- Tree Soul status panel existuje,
- jejich propojení v `ui.gd` chybí.

UI stále používá řadu pevných offsetů a není finálně responzivní.

## 19. Vizuální stav

Současná grafika je stále dočasná:

- procedurálně kreslený strom,
- procedurálně kreslené Strength a Blossom větve,
- jednoduchý Bark Beetle,
- procedurální zem a perspective lines,
- základní kruhové Essence orby,
- základní tweens,
- prototypové panely.

Plánovaný směr:

- pixel art,
- výrazná silueta každé větve,
- viditelný Tree Soul orb,
- vývoj vzhledu podle Age, levelů a Soul Ranku,
- výraznější nepřátelé,
- lepší útoky, zásahy, projektily a sbírání,
- čistší a responzivnější UI.

## 20. Save, prestige a offline progress

Zatím nejsou implementované:

- save/load,
- migrace verzí save dat,
- persistence po ukončení hry,
- offline progress,
- skutečný prestige trigger,
- reset runu,
- Garden/metaprogress.

Některé služby jsou na budoucí persistence připravené:

- `TreeSoulService` má `selected_soul`,
- `current_rank`,
- `last_announced_rank`,
- `clear_for_prestige()`.

Tyto hodnoty se však zatím neukládají na disk.

## 21. Známé aktuální limity

- SOUL tab není zapojený.
- Tree Soul rank-up notification neexistuje.
- Tree Soul orb na stromu neexistuje.
- Prestige a save/load neexistují.
- Blossom nemá vlastní talentový strom.
- Strength má pouze tři prototypové talenty, ne kompletní pavouk.
- Data definitions existují, ale většina současného gameplay obsahu na ně ještě není migrovaná.
- Registry obsahuje pouze Tree Souls.
- WaveManager je stále hardcoded na Bark Beetle scénu.
- UI je prototypové a používá pevné pozice.
- Neexistují automatické gameplay testy ani CI validace Godot projektu.
- Balancování je dočasné.
- Grafika a zvuk nejsou finální.

## 22. Okamžitý další úkol

Nejbližší bezpečný krok:

1. přidat a commitnout kořenový `AGENTS.md` pro Codex,
2. zapojit SOUL tab v `scripts/ui.gd`,
3. zajistit, že BRANCHES, TREE a SOUL zobrazují vždy pouze jeden panel,
4. zachovat BRANCHES jako výchozí tab,
5. zachovat funkční TALENTS button,
6. lokálně otestovat v Godotu,
7. zkontrolovat diff před merge.

Poté:

1. přísně zkontrolovat a minimálně opravit `tree_soul_status_panel.gd`,
2. přidat neblokující Tree Soul Rank Up notification,
3. otestovat všechny čtyři Soul effects,
4. přidat vizuální orb na strom,
5. připravit skutečný prestige/save flow.

## 23. Doporučené pořadí dalších velkých kroků

1. Dokončit Tree Soul V1 UI a testy.
2. Přidat rank-up feedback a orb vertical slice.
3. Dokončit Strength talent tree.
4. Navrhnout a implementovat Blossom talent tree.
5. Převést branch content do `BranchDefinition`.
6. Převést Bark Beetle do `EnemyDefinition`.
7. Převést WaveManager na `StageDefinition` a `WaveDefinition`.
8. Přidat save/load a versioned migrations.
9. Přidat prestige.
10. Přidat další enemy a branch archetypes.
11. Začít finální grafický vertical slice.

## 24. Záměrně odložené systémy

- Garden
- trvalý metaprogress
- plný prestige
- save/load a offline progress
- equipment
- další regions a stage content
- elites a bosses
- kompletní status-effect gameplay
- zvuky a hudba
- finální pixel art
- mobilní ovládání
- responzivní mobilní UI
- Steam integrace
- achievementy
- lokalizace

## 25. Zásady vývoje

- Jeden jasně ohraničený úkol najednou.
- Před změnou přečíst související scény, skripty a Resources.
- Neměnit nesouvisející soubory.
- Neprovádět široké refaktory bez samostatného zadání.
- Testovat po každé významné změně.
- Kontrolovat přesný diff před commitem nebo merge.
- Uchovávat stabilní `StringName` ID.
- Content data patří do Resources.
- Obecná mechanika patří do sdílených services/components.
- XP, Talent Points a Forest Essence zůstávají oddělené.
- Branch level řídí růst, talent milestones a upgrade cap; automaticky nezvyšuje základní Damage.
- Nepoužívat Y-toleranci jako náhradu lane targeting.
- Znovu validovat cíl před skutečným zásahem.
- Tree Soul selection nesmí pauzovat hru.
- Azure nesmí zrychlovat healing ticks.
- Crimson nesmí zvyšovat healing.
- Golden se nesmí aplikovat na load, restore, refund ani debug grant.
- Menší čistý krok je lepší než velký nezkontrolovatelný diff.

## 26. Shrnutí milníku

### Dokončeno

- stabilizace základního combat prototypu,
- centrální strom, damage, death a respawn,
- Age, Stage a Wave prototype,
- ochrana před Age farming,
- explicitní lanes a crowd formation,
- Strength a Blossom archetyp,
- čtyři nasazené branch instances,
- generické XP, level, Talent Point a upgrade rozhraní,
- funkční samostatný Talent Screen,
- tři funkční Strength talents,
- healing over time a Blossom petal combat,
- shared targeting, context a resolver,
- RunModifierService,
- ContentRegistry a validator,
- definitions foundation,
- čtyři Tree Souls,
- Tree Soul rank progression,
- Tree Soul selection screen,
- Tree Soul modifiers napojené na gameplay,
- Tree Soul status panel,
- SOUL button ve scéně.

### Probíhá

- dokončení Tree Soul V1 UI,
- zapojení SOUL tabu,
- kontrola status panelu,
- rank-up notification,
- Codex workflow a `AGENTS.md`,
- migrace současného gameplay na data-driven definitions,
- dokumentace a testování.

### Nezahájeno nebo pouze připraveno rozhraním

- skutečný save/load,
- prestige flow,
- offline progress,
- viditelný orb na stromu,
- kompletní Strength a Blossom talent trees,
- data-driven enemy/stage/wave runtime,
- další branch a enemy content,
- bosses,
- equipment,
- final art, audio a localization.
