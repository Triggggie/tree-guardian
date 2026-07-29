TREE GUARDIAN

Game Design Bible

Základní návrh hry, herní pravidla a dlouhodobá vize

Verze 1.0
28. července 2026


# 1. Účel dokumentu

Tento dokument slouží jako společná paměť projektu Tree Guardian. Má zabránit tomu, aby se při postupném přidávání systémů měnila základní logika hry bez vědomého rozhodnutí nebo aby se zapomnělo, proč byl některý systém navržen určitým způsobem.

- Při návrhu nové funkce nejprve ověřit, zda odpovídá pravidlům v této Design Bible.

- Pokud se rozhodnutí změní, upravit nejdříve dokument a teprve potom implementaci.

- Rozlišovat mezi tím, co je rozhodnuté, co je pouze plánované a co je stále otevřené.

- Current Status popisuje, co už je implementované. Tato Design Bible popisuje, jak má hra dlouhodobě fungovat.


# 2. Vysoká úroveň vize

Tree Guardian je 2D idle / tower-defense / build-crafting hra, ve které hráč rozvíjí poslední Strom života. Strom stojí uprostřed bojiště, nepřátelé na něj útočí z obou stran a hráč během runu skládá vlastní build z větví, talentů, upgradů stromu a nalezeného equipmentu.


## 2.1 Herní fantasy

- Hráč není lidský bojovník. Hráčem je samotný živý strom.

- Všechny systémy musí tematicky odpovídat stromu, přírodě, růstu, kořenům, kůře, květům, míze, semenům, sporám a lesním duchům.

- Vývoj stromu má být vizuálně čitelný: strom stárne, sílí, větve rostou a equipment mění jeho vzhled nebo chování.

- Hra má být jednoduchá na pochopení, ale hluboká na skládání buildů.


## 2.2 Základní herní pilíře


# 3. Základní herní smyčka

Základní smyčka musí zůstat srozumitelná i po přidání dalších systémů:

1. Nepřátelé přicházejí z obou stran.

1. Větve automaticky bojují a chrání strom.

1. Nepřátelé poskytují XP, Forest Essence a později také itemy nebo jiné dropy.

1. Větve získávají levely a rostou.

1. Hráč utrácí Forest Essence za runové statistické upgrady.

1. Hráč volí talenty, které mění mechaniky větví.

1. Hráč porovnává a vybavuje tematický equipment stromu.

1. Obtížnost vln a Stage roste.

1. Po smrti se restartuje aktuální Stage, ale běžný runový postup zůstává.

1. Prestige později resetuje Age a část runu výměnou za dlouhodobý postup.


## 3.1 Krátkodobá rozhodnutí

- Do které větve investovat Essence.

- Zda posílit Damage, Attack Speed nebo Range konkrétní větve.

- Zda posílit Max HP, regeneraci nebo zisk Essence stromu.

- Který talent zvolit při dosažení milníku.


## 3.2 Střednědobá rozhodnutí

- Které čtyři archetypy větví použít v aktivním buildu.

- Jakou roli má každá větev plnit.

- Jak kombinovat status efekty, kontrolu davu, léčení a damage.

- Který equipment vybavit a zda obětovat čisté statistiky za unikátní efekt.


## 3.3 Dlouhodobá rozhodnutí

- Kdy provést prestige.

- Jak rozvíjet Garden a další metaprogress.

- Které větve, talenty, itemy nebo regiony odemykat jako první.


# 4. Strom života


## 4.1 Role stromu

Strom je současně hráčská postava, základna, objekt obrany a nositel větví i equipmentu. Nesmí působit jen jako statická věž s přilepenými zbraněmi.

- Strom má vlastní HP, Max HP, regeneraci a obranné vlastnosti.

- Strom získává Age za dokončené vlny.

- Strom nese aktivní větve ve slotech.

- Strom používá equipment odpovídající svým částem.

- Strom má být vizuálně starší, mohutnější a charakterističtější podle postupu.


## 4.2 Age

- Age představuje postup konkrétního runu.

- Age může odemykat vyšší limity globálních upgradů stromu.

- Age může ovlivňovat vzhled stromu, ale strom nemá růst do nekonečna.

- Po dosažení dospělé velikosti se má měnit spíše textura, kůra, koruna, detaily a stáří než samotná velikost.


## 4.3 Smrt a respawn

- Automatický respawn proběhne po desetisekundovém odpočtu.

- Hráč může použít Retry Now pro okamžitý návrat.

- Běžná smrt není prestige a nesmí působit jako úplný reset runu.


# 5. Zdroje postupu a měny


## 5.1 Forest Essence

- Essence je fyzicky reprezentovaná viditelnými orby.

- Essence Gain zvyšuje skutečný počet orbů, nikoliv skrytý bonus po sebrání.

- Další Essence upgrady se budou přidávat až podle potřeb balancu, ne preventivně.


## 5.2 Filosofie rozdělení progresu

- Level větve = růst, milníky, talenty a cap upgradů.

- Forest Essence = číselné statistiky během runu.

- Talent Points = nové funkce, změny chování a specializace.

- Equipment = náhodné dropy, kombinace statů a unikátní efekty.

- Garden a prestige = dlouhodobý metaprogress.


# 6. Systém větví


## 6.1 Základní pravidla

- Strength Branch je základní počáteční větev, kterou dostane každý hráč.

- Další sloty a archetypy se odemykají postupně.

- Každá větev má vlastní XP, level, Talent Points, Essence upgrady a talentový strom.

- Každý archetyp musí mít jasně odlišnou bojovou roli a vizuální identitu.

- Talenty mohou vytvořit více buildů uvnitř stejného archetypu.

- Větve začínají jako pupeny nebo výhonky a přirozeně rostou přibližně do levelu 10.

- Po dosažení dospělosti se přidávají hlavně vizuální detaily, nikoliv nekonečná délka a tloušťka.


## 6.2 Sloty větví


# 7. Plánované archetypy větví


## 1. Strength Branch

Role: Základní kontaktní fyzická větev.

Základní funkce: Přímé údery, spolehlivý single-target damage, základní obrana stromu.

Možné talentové směry: Knockback, stun, cleave, armor break, těžké údery nebo rychlejší lehké údery.


## 2. Blossom Branch

Role: Léčivá a podpůrná větev porostlá květy.

Základní funkce: Pravidelné léčení stromu a stabilizace runu.

Možné talentové směry: Burst heal při nízkém HP, léčivý pyl, cleanse, overheal shield, podpora ostatních větví.


## 3. Thornshot Branch

Role: Čistá ranged projektilová větev.

Základní funkce: Útok na velkou vzdálenost a prioritní cíle.

Možné talentové směry: Piercing, multishot, kritické zásahy, homing trny, střelba na zadní řady.


## 4. Poison Branch

Role: Damage-over-time větev.

Základní funkce: Aplikace jedu a dlouhodobé poškození.

Možné talentové směry: Stackování nebo refresh Poisonu, šíření po smrti, jedovatý mrak, zvýšený damage proti otráveným.


## 5. Frost Branch

Role: Kontrolní větev.

Základní funkce: Zpomalení pohybu a útoků nepřátel.

Možné talentové směry: Freeze, shatter, plošné zpomalení, bonus proti zmraženým cílům.


## 6. Flame Branch

Role: Ofenzivní plošná větev.

Základní funkce: Spalování skupin nepřátel.

Možné talentové směry: Šíření ohně, exploze při smrti, ohnivá oblast, vyšší damage proti davům.


## 7. Storm Branch

Role: Rychlá řetězová větev.

Základní funkce: Blesky přeskakující mezi nepřáteli.

Možné talentové směry: Chain lightning, elektrický stun, nabíjený výboj, bonus podle počtu zasažených cílů.


## 8. Root Branch

Role: Kontrola bojiště ze země.

Základní funkce: Kořeny, trny, root efekt a obrana prostoru u stromu.

Možné talentové směry: Zakořenění, řady trnů, sevření skupiny, bonus k obraně stromu.


## 9. Spirit Branch

Role: Summon a support archetyp.

Základní funkce: Vyvolávání lesních duchů a podpora ostatních větví.

Možné talentové směry: Útoční, léčiví nebo buffovací duchové; zvýšení Attack Speed; debuffy; Essence utility.


## 10. Spore Branch

Role: Plošná infekční větev.

Základní funkce: Spory, houby a dlouhodobá kontrola prostoru.

Možné talentové směry: Infekce, oslabení obrany, houby na zemi, přeskakování spor, plošný DoT.


# 8. Levelování, růst a Range větví


## 8.1 Level větve

- Současné Talent Point milníky prototypu: level 2, 4, 7, 10 a 14.

- Základní cap Essence upgradů prototypu: level větve krát tři.

- Konečná XP křivka bude později upravena podle délky runu.


## 8.2 Přirozený Range

- Současný prototyp: délka větve + 100 základní rezerva + Essence bonus.

- Range upgrade: +15 za level, maximální bonus +150.

- Každý archetyp nemusí používat stejný Range model. Projektilová větev bude mít vlastní logiku.


# 9. Talenty


## 9.1 Základní filosofie

- Talenty mohou přidávat stun, knockback, chaining, cleave, šíření statusů, nové projektily nebo reakce na situaci.

- Číselné staty patří především do Essence upgradů a equipmentu.

- Každá finální větev má vlastní talentový strom.

- Talenty mají umožnit alespoň dvě až tři smysluplné specializace jednoho archetypu.


## 9.2 Příklad Strength talentů


# 10. Upgrady za Forest Essence


## 10.1 Větve

- Damage.

- Attack Speed, interně realizovaný snížením cooldownu.

- Range nebo jiný archetypově odpovídající parametr.


## 10.2 Strom

- Maximum HP.

- HP Regeneration.

- Forest Essence Gain.


# 11. Equipment stromu


## 11.1 Základní princip

Equipment je hlavní systém náhodných dropů. Nepoužívá lidské meče, helmy ani klasické brnění. Každý item představuje část stromu, přírodní mutaci, magický organický prvek nebo pradávný artefakt srostlý se stromem.


## 11.2 Navrhované equipment sloty


## 11.3 Pátý slot větve


## 11.4 Rarity


## 11.5 Pravidla itemizace

- Vyšší rarity nesmějí znamenat pouze vyšší čísla.

- Unikátní efekty musí být jasně čitelné a tematické.

- Item má vytvářet rozhodnutí: vyšší čisté staty versus silná synergie nebo unikátní mechanika.

- Počet affixů, rozsahy hodnot a drop rate se budou řešit až po základním prototypu inventáře.

- Equipment nesmí nahradit identitu větví; má je doplňovat nebo propojovat.


## 11.6 Příklady unikátních itemů


# 12. Drop systém


## 12.1 Možné dropy

- Forest Essence — základní častý drop.

- Equipment — náhodné itemy s raritou.

- Fragmenty nebo materiály — budoucí úpravy, reroll nebo crafting.

- Seeds nebo unlock fragmenty — odemykání nových větví.

- Vzácné boss odměny — unikátní itemy, talenty nebo Garden zdroje.


## 12.2 První implementace equipmentu


# 13. Nepřátelé


## 13.1 Základní princip

- Nepřátelé přicházejí z obou stran a používají několik mělkých 2.5D drah.

- Každá dráha má vlastní útočnou frontu; útočí pouze první živý nepřítel.

- Nepřátelé pokračují v pohybu, i když jsou napadáni z dálky.

- Různé archetypy mají vytvářet důvod používat různé větve a talenty.


## 13.2 Plánované archetypy nepřátel


## 13.3 Status efekty

- Poison — damage over time.

- Slow — snížení rychlosti pohybu.

- Freeze — dočasné zastavení.

- Stun — krátké přerušení útoku a pohybu.

- Burn — damage over time s možností šíření nebo exploze.

- Root — ukotvení na místě.

- Armor Break — snížení obrany.

- Weakness — snížení damage nepřítele.


# 14. Region, Stage a Wave


## 14.1 Struktura postupu

- Region určuje prostředí, sadu nepřátel, vizuál, hudbu a hlavní tematické mechaniky.

- Stage je hlavní opakovatelný úsek s vlastním průběhem obtížnosti.

- Wave je krátký bojový krok, po jehož dokončení roste Age.


## 14.2 Návrh Stage

- Stage má mít jasný začátek, růst tlaku, nové kombinace nepřátel a závěr.

- Současných 100 vln je testovací hodnota, nikoliv definitivní design.

- Později mají být vlny definované datově, ne sérií podmínek ve WaveManageru.

- Mini-boss nebo boss může uzavírat Stage nebo významný blok vln.


## 14.3 Regiony — pracovní příklady


# 15. Prestige a metaprogress


## 15.1 Prestige

- Prestige nemá být dostupné příliš brzy.

- Musí přinášet nové možnosti, nejen malé permanentní procento Damage.

- Může odemykat automatické nákupy Essence upgradů, nové sloty, větve, regiony nebo Garden funkce.


## 15.2 Garden

- Může poskytovat moduly, rostliny nebo permanentní bonusy.

- Může ovlivňovat obranu stromu, regeneraci, Essence Gain, větevní synergie nebo speciální mechaniky.

- Garden nesmí být jen druhé stejné menu statistik.

- Má vizuálně růst a vytvářet pocit budování vlastního zázemí.


# 16. UI a ovládání


## 16.1 Současný stav

- UI je prototypové a používá pevné pozice.

- Existuje panel upgradů větví a panel upgradů stromu.

- Statistika se hráči zobrazuje jako Attack Speed, i když interně používáme cooldown.


## 16.2 Budoucí pravidla UI

- Hlavní bojová obrazovka nesmí být zahlcena všemi systémy současně.

- Detail větve, talentový strom, equipment a inventář mohou používat samostatné obrazovky nebo vysouvací panely.

- Mobilní verze vyžaduje responzivní layout, anchors, containery a větší ovládací prvky.

- Statusy, Range a cílení musí být vizuálně čitelné bez nutnosti studovat čísla.

- Každá větev má mít výraznou barvu, siluetu a ikonografii.


# 17. Vizuální a zvukový směr


## 17.1 Grafika

- Větve vizuálně rostou od pupenu k dospělému tvaru.

- Equipment má být alespoň u vyšších rarit viditelný na stromu.

- Nepřátelé musí být čitelní i ve větším davu a v několika hloubkových drahách.

- Efekty útoků nesmí zakrýt bojiště při vysoké Attack Speed.


## 17.2 Audio

- Každý archetyp větve má vlastní zvukovou identitu.

- Úder dřeva, výstřel trnu, šíření jedu, květový heal, mráz a blesk musí být snadno rozlišitelné.

- Zvuky dropů a rarity itemu mají vytvářet silnou odměnu.

- Hudba regionu se může stupňovat podle Stage nebo boss fáze.


# 18. Ukládání, offline progress a platformy


## 18.1 Save systém

- Save musí později ukládat odemknuté větve, aktivní build, talenty, equipment, inventář, regiony, prestige a Garden.

- Je nutná verze save dat a migrační strategie mezi verzemi hry.


## 18.2 Offline progress

- Offline progress patří do pozdější idle fáze.

- Musí respektovat build a dosažený obsah, ale nesmí zcela nahradit aktivní hraní.

- Přesné odměny a časový cap budou řešeny až po balancu aktivního runu.


## 18.3 Platformy

- Primární vývoj probíhá pro PC.

- Architektura a UI mají zachovat možnost mobilní verze.

- Steam integrace, achievementy a cloud save jsou pozdější fáze.


# 19. Technická architektura


## 19.1 Základní princip


## 19.2 Plánované společné vrstvy


## 19.3 Pravidla implementace

- Přidávat jednu malou funkci najednou.

- Po každé významné změně provést cílený test.

- Po stabilním milníku commit a push.

- Větší přepis dělat pouze tehdy, když je jasný konkrétní přínos.

- Gameplay logika má zůstat oddělená od finálních grafických assetů.

- Neoptimalizovat bez skutečného výkonového problému.

- Nové větve nesmí kopírovat celý Strength skript; společná logika se postupně přesune do základu.


# 20. Obsahové pořadí vývoje


# 21. Co zatím záměrně neimplementovat

- Všech deset větví současně.

- Kompletní talentové stromy všech archetypů.

- Plný equipment systém se šesti sloty a šesti raritami.

- Crafting, reroll a komplexní affix systém.

- Garden před ověřením základního buildu.

- Prestige před stabilní délkou runu.

- Offline progress před aktivním balancem.

- Finální mobilní UI před ustálením obrazovek.

- Velký save systém před stabilizací dat.

- Desítky nepřátel bez jasné funkce pro build.


# 22. Pevná pravidla návrhu

- Hráčem je Strom života, nikoliv lidská postava.

- Standardní aktivní build používá maximálně čtyři větve.

- Pátá větev je zvláštní a vzácné odemknutí.

- Strength Branch je základní počáteční větev.

- Ve finální nabídce má být přibližně deset jasně odlišných archetypů.

- Level větve znamená růst, Talent Points a upgrade cap; ne automatický růst Damage a Attack Speed.

- Forest Essence slouží hlavně k číselným runovým upgradům.

- Talenty mění funkci a mechaniky.

- Equipment je tematicky tvořen částmi stromu a přírodními či magickými prvky.

- Vyšší rarity musí přinášet unikátní mechaniky, ne jen vyšší hodnoty.

- Běžná smrt restartuje Stage, ale není prestige.

- Age se resetuje až při prestige.

- Garden je oddělený metaprogress, nikoliv kopie Essence menu.

- Hra má být jednoduchá na pochopení, ale hluboká na skládání buildů.

- Každá nová funkce se implementuje v malém testovatelném kroku.


# 23. Otevřené otázky

- Který archetyp bude druhou implementovanou větví: Poison, Thornshot nebo Blossom?

- Je Strength Branch povinná pouze na začátku, nebo musí zůstat v každém buildu?

- Jak přesně se odemykají sloty 2 až 4?

- Je pátý slot výhradně Crown equipment, nebo může existovat více cest?

- Co přesně prestige resetuje a co zachová?

- Je equipment trvalý mezi prestige, nebo existuje runový a permanentní equipment?

- Kolik vln má mít jedna finální Stage?

- Kdy vstupuje boss do struktury Region–Stage–Wave?

- Jaké typy damage a resistencí hra skutečně potřebuje?

- Budou talenty volně přepínatelné, resetovatelné za cenu, nebo fixní během runu?

- Jak bude fungovat inventář, limit kapacity a automatické třídění?

- Jak velký význam má offline progress oproti aktivnímu hraní?

- Jak přesně má Garden vypadat vizuálně a herně?

- Které systémy patří do první Early Access verze a které až do 1.0?


# 24. Definice minimálního vertical slice

Vertical slice je malý, ale reprezentativní úsek finální hry. Nemusí mít velké množství obsahu, ale musí ukázat všechny hlavní vrstvy v základní kvalitě.

- Jedna kompletní Stage s jasným začátkem, průběhem a závěrem.

- Alespoň tři odlišné větve včetně Strength Branch.

- Alespoň tři až pět archetypů nepřátel.

- Jeden mini-boss nebo boss.

- Funkční Talent Points a malý talentový strom alespoň jedné větve.

- Základní equipment drop, inventář a equipování.

- První finální nebo téměř finální grafický styl.

- Základní zvuky a hudba regionu.

- Save/load základního postupu.

- Dostatečný balance, aby bylo možné posoudit zábavnost buildu.


# 25. Správa změn dokumentu

- Při zásadním rozhodnutí přidat datum a stručnou změnu do changelogu.

- Pokud implementace neodpovídá dokumentu, musí být jasné, zda jde o dočasný prototyp, nebo vědomou změnu designu.

- Current Status aktualizovat po stabilních milnících.

- Design Bible aktualizovat po změně dlouhodobých pravidel nebo vize.


## 25.1 Changelog
