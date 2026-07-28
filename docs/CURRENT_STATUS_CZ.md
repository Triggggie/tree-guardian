# Tree Guardian — Aktuální stav projektu

_Poslední aktualizace: 28. července 2026_

## Přehled projektu

**Tree Guardian** je 2D idle / tower-defense hra vytvářená v Godotu 4.7.1.

Hráč ovládá poslední Strom života. Strom stojí uprostřed bojiště a automaticky se brání nepřátelům přicházejícím z obou stran.

Projekt nyní používá dočasnou procedurální grafiku. Finální vizuální styl je plánovaný jako pixel art.

## Základní herní koncept

- Hráč rozvíjí jeden centrální Strom života.
- Průběh aktuálního runu představuje **Věk** stromu.
- Za každou dokončenou vlnu strom získá jeden rok Věku.
- Věk zůstává zachovaný po běžné smrti.
- Věk se má resetovat pouze prostřednictvím budoucího systému prestiže.
- Bojové větve získávají vlastní XP za zabité nepřátele.
- Každá větev získává levely samostatně.
- Levely větve představují přirozený růst, milníky Talent Points a zvyšování limitu upgradů.
- Level větve přímo nezvyšuje Damage ani Attack Speed.
- Forest Essence je hlavní měna aktuálního runu.
- Forest Essence je oddělená od XP větví a Talent Points.
- Hlavní větve mají být ve finální hře jedinečné.
- Současné dvě zrcadlové Strength Branches slouží pouze k testování prototypu.

## Současné technické nastavení

- Engine: Godot 4.7.1 stable
- Jazyk: GDScript
- Renderer: Forward+
- Základní rozlišení: 1920 × 1080
- Repozitář: soukromý GitHub repozitář `tree-guardian`
- Hlavní scéna: `res://scenes/main_world.tscn`

## Současná struktura scény

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

## Systém stromu

Strom aktuálně podporuje:

- Ukládání Forest Essence
- Postup Věku
- Maximální a aktuální zdraví
- Přijímání poškození
- Smrt
- Automatický respawn
- Okamžitý manuální restart
- Klidovou „dýchací“ animaci
- Červený záblesk a zatřesení při zásahu
- Textové zobrazení zdraví
- Zelený ukazatel zdraví
- Upgrady maximálního zdraví
- Upgrady regenerace zdraví
- Upgrady zisku Forest Essence

Současné základní zdraví stromu:

```text
100 HP
```

## Upgrady stromu

Hráč může utrácet Forest Essence za globální upgrady stromu.

### Maximální HP

- Zvyšuje maximální zdraví.
- Současně zvýší aktuální zdraví o stejnou hodnotu.
- Současná hodnota jednoho upgradu: `+20 maximálního HP`.

### Regenerace HP

- Automaticky obnovuje zdraví v průběhu času.
- Zastaví se na maximálním zdraví.
- Neoživí mrtvý strom.
- Současná hodnota jednoho upgradu: `+0,5 HP za sekundu`.

### Zisk Forest Essence

- Zvyšuje množství Forest Essence padající z nepřátel.
- Bonus mění skutečný počet viditelných Essence orbů.
- Násobitel měny se při doletu orbu ke stromu znovu nepoužije.
- Současná hodnota jednoho upgradu: `+10 % Forest Essence`.

Upgrady stromu mají aktuálně limit levelu závislý na Věku:

```text
Základní maximální level upgradu: 3
+1 maximální level za každých 5 Věku
```

## Strength Branches

Ke stromu jsou nyní pro testování připojené dvě zrcadlové Strength Branches.

Každá větev má:

- Vlastní XP
- Vlastní level
- Vlastní Talent Points
- Automatický výběr cíle
- Automatické útoky
- Upgrady Damage
- Upgrady Attack Speed
- Upgrady Range
- Přirozený vizuální růst
- Zastavení boje po smrti stromu
- Obnovení boje po respawnu

Levely větve aktuálně ovlivňují:

- Vizuální růst
- Milníky Talent Points
- Maximální povolené levely Essence upgradů
- Přirozený dosah útoku prostřednictvím fyzické délky větve

Levely větve přímo nezvyšují Damage ani Attack Speed.

## Vizuální růst větve

Každá Strength Branch začíná jako malý pupen nebo výhonek a postupně roste směrem ke své dospělé velikosti.

```text
Level dospělé větve: 10
Délka pupenu: 38
Tloušťka pupenu: 10
Délka dospělé větve: 185
Tloušťka dospělé větve: 30
První boční výhonek: level 3
Maximální počet bočních výhonků: 5
```

Po dosažení dospělé velikosti by měly pozdější levely přidávat především vizuální detaily, nikoliv nekonečně zvětšovat délku nebo tloušťku větve.

## Bojové statistiky větve

```text
Základní Damage: 10
Základní cooldown: 1,5 s
Minimální cooldown: 0,45 s
Základní úhel útoku: 18°
XP potřebné na level: 2
```

UI zobrazuje Attack Speed místo cooldownu. Cooldown zůstává interní hodnotou časovače útoků.

## Essence upgrady větví

Každá větev může utrácet Forest Essence za Damage, Attack Speed a Range.

```text
Damage za upgrade: +2
Snížení cooldownu za upgrade: 0,08 s
Range za upgrade: +15
Růst ceny upgradu: ×1,35
Maximální level upgradu = Level větve × 3
```

Range má navíc vlastní samostatný maximální bonus.

## Systém Range větve

```text
Attack Range
=
Aktuální délka větve
+ Základní rezerva dosahu
+ Essence bonus k Range
```

Současné hodnoty:

```text
Základní rezerva dosahu: 100
Range za Essence upgrade: +15
Maximální Essence bonus k Range: +150
Maximální počet Range upgradů: 10
```

Přibližné příklady:

```text
Mladá větev: 38 + 100 = Range 138
Dospělá větev: 185 + 100 = Range 285
Dospělá větev s maximálním bonusem: 185 + 100 + 150 = Range 435
```

## Talent Points

Strength Branches získávají Talent Points na levelech 2, 4, 7, 10 a 14.

Talent Points jsou uložené samostatně pro každou větev. Finální UI talentového stromu a funkční talenty zatím nejsou implementované.

## Nepřítel Bark Beetle

Bark Beetle aktuálně podporuje:

- Pohyb směrem ke stromu
- Škálování zdraví podle vlny
- Automatické útoky
- Variabilitu rychlosti pohybu
- Více hloubkových drah
- Samostatné fronty útoku pro každou dráhu
- Posun fronty po smrti prvního nepřítele
- Zobrazení ukazatele zdraví po poškození
- Červený záblesk a zatřesení při zásahu
- Zmenšení a zmizení při smrti
- Drop Forest Essence
- Více Essence orbů za jednu smrt
- XP odměnu pro větev
- Ukončení boje po smrti stromu
- Pseudo-3D vykreslování podle pozice Y

```text
Rychlost pohybu: 120
Základní zdraví: 30
Poškození útoku: 5
Cooldown útoku: 1,5 s
XP odměna: 1
Základní odměna Forest Essence: 1
```

## Dav nepřátel a hloubka bojiště

Nepřátelé se objevují z obou stran, používají několik mělkých hloubkových drah, dostávají mírně rozdílnou rychlost a mají samostatné fronty útoku pro každou dráhu. Útočí pouze první živý nepřítel v každé dráze. Útoky větví nezastavují pohyb nepřátel.

Bojiště používá procedurální 2.5D zem s horizontem, perspektivními čarami a dostatečnou hloubkou pro všechny dráhy.

## Struktura Region, Stage a Wave

Plánovaný postup:

```text
Region → Stage → Wave
```

Současná testovací hodnota: `100 vln na jednu Stage`.

Systém podporuje nekonečné vlny, škálování počtu a zdraví nepřátel, prodlevy mezi spawny a vlnami, zvyšování Věku po dokončení vlny, zprávu o dokončení vlny a restart Stage po smrti stromu.

```text
Základní počet nepřátel na stranu: 2
Jeden další nepřítel každé 3 vlny
Maximální počet nepřátel na stranu: 30
Základní zdraví nepřítele: 30
Zvýšení zdraví za vlnu: +3
```

Současné škálování vln je stále prototypová logika a později by mělo být řízené daty.

## Forest Essence

Po smrti nepřítele se vypočítá jeho skutečná Essence odměna. Výsledek určí počet viditelných orbů. Každý orb se objeví s malým náhodným posunem, krátce počká, letí ke stromu a přidá jednu Forest Essence.

Essence Gain používá zásobník desetinného zbytku. Při `+10 %` nepřátelé většinou pustí jeden orb a pravidelně pustí další orb navíc. Normální hodnota pro hru je:

```text
Essence Gain Per Upgrade: 0.10
```

## Smrt a respawn

Když zdraví stromu klesne na nulu:

- Boj stromu, větví a nepřátel se zastaví.
- Spawn vln a zprávy se zastaví.
- Zobrazí se Game Over panel.
- Spustí se desetisekundový odpočet do respawnu.
- Hráč může použít `RETRY NOW`.
- Aktuální Stage se restartuje od Wave 1.

Běžná smrt zachovává Věk, Forest Essence, XP a levely větví, Talent Points, upgrady větví a upgrady stromu. Běžná smrt není prestige.

## Současné UI

Implementované UI zahrnuje Forest Essence, informace o větvích, Věk stromu, informace o vlně, počet nepřátel, HP stromu, ukazatel zdraví, zprávu o dokončení vlny, Game Over panel, odpočet do respawnu, Retry, panel upgradů větví a panel upgradů stromu.

Panely zobrazují aktuální a následující hodnoty, ceny, deaktivovaný stav při nedostatku Essence a `MAX` při dosažení současného limitu.

UI stále používá pevné pozice a je prototypové. Před mobilní podporou nebo vydáním se má přestavět pomocí responzivních containerů a anchors.

## Vizuální stav

Současná grafika je dočasná: procedurální strom a větve, jednoduché nepřátele, procedurální zem, zelené Essence kruhy, základní tweens a jednoduché UI panely.

Plánovaný směr:

- Pixel-art styl
- Viditelný růst stromu podle Věku
- Přirozený vývoj větví
- Výraznější nepřátelé
- Lepší terén, stíny a hloubka
- Lepší efekty útoků, zásahů a sbírání
- Silná vizuální identita každého typu větve

## Záměrně odložené systémy

- Garden systém
- Trvalý metaprogress
- Implementace prestige
- Save systém
- Offline progress
- Obrazovka výběru větví
- Další archetypy větví
- Kompletní UI talentového stromu a funkční talenty
- Elitní nepřátelé a bossové
- Stavové efekty
- Zvuky a hudba
- Finální pixel-art podklady
- Mobilní ovládání a responzivní UI
- Steam integrace a achievementy
- Lokalizace
- Datově řízená konfigurace vln

## Doporučená další fáze vývoje

1. Provést delší test stability.
2. Projít a vyčistit současné skripty.
3. Ověřit smrt, respawn a zachování upgradů během více Stage.
4. Přidat jeden skutečně odlišný druhý typ větve.
5. Přidat jeden nový archetyp nepřítele.
6. Začít první funkční prototyp talentového stromu.
7. Přidat jednoduché zvukové efekty.
8. Začít nahrazovat dočasnou grafiku.

## Okamžitý další úkol

Přidat jeden skutečně odlišný archetyp větve jako malý vertikální prototyp. Měl by přinést jasnou roli, například plošné poškození, poškození v čase, zpomalování, projektily, podporu, léčení nebo vyvolané jednotky.

## Současný stav milníku

### Dokončeno

- Centrální strom, zdraví, smrt, automatický respawn a manuální Retry
- Restart Stage po smrti
- Dvě samostatné bojové větve
- XP, levely a milníky Talent Points
- Přirozený vizuální růst větví
- Automatické cílení a útoky
- Pohyb, útoky, škálování a hloubkové dráhy nepřátel
- Dynamické fronty podle drah a pseudo-3D zem
- Forest Essence, více orbů a Essence Gain
- Věk stromu, zpětná vazba při zásahu a ukazatele zdraví
- Interakce s upgrady větví a stromu
- Upgrady Damage, Attack Speed a Range
- Range podle délky větve s maximálním Essence bonusem
- Upgrady maximálního HP, regenerace HP a Essence Gain
- Limity, ceny, výběr větve a sjednocené zobrazení Attack Speed

### Probíhá

- Vylepšování soubojů
- Balancování
- Vylepšování rozložení UI
- Čištění skriptů
- Dokumentace

### Nezahájeno

- Prestige
- Garden
- Další větve a nepřátelé
- Funkční talentové stromy
- Bossové
- Ukládání a offline progress
- Zvuk a finální grafika
- Mobilní UI a metaprogress
- Steam integrace a lokalizace

## Zásady vývoje

- Přidávat vždy jen jednu malou funkci.
- Testovat po každé významné změně.
- Po stabilním milníku vytvořit commit.
- Nestavět budoucí systémy dříve, než je jasná současná herní smyčka.
- Udržovat herní kód nezávislý na finální grafice.
- Při větších změnách nahrazovat celé skripty, pokud se tím sníží riziko chyb při slučování nebo v odsazení.
- Optimalizovat pouze při skutečném výkonovém problému.
- Zachovat možnost budoucí mobilní verze.
- Udržovat XP, Talent Points a Forest Essence oddělené.
- Používat levely větví pro růst a odemykání, nikoliv pro automatické škálování statistik.
- Každý upgrade musí mít smysluplný limit.
