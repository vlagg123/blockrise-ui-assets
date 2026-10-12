# BlockRise Empire: Economia V6 „Regiuni” (Oraș → Deșert → Lună)

Plan scris pe 12 octombrie 2026, la cererea owner-ului: economia și progresul regândite, cu crate-urile noi (cât costă,
când apar) și cele două lumi noi, Deșertul și Luna, pentru reach și retenție cât mai mari. Încă nimic nu e făcut în
Studio.

Cifrele derivate (premii, prețuri, șanse, puteri, zile) le calculează `tools/econ/v6_regions.py`; rulează-l după orice
schimbare a regulilor. Cifrele de azi vin din `tools/econ/game_dump_v4.md`, `tools/econ/recipe_v5.md`,
`roblox/ECON_V5_STUDIO.md`, `roblox/PC_2026-10-08_odds.md` (LOOP_V7, LEVEL_REBIRTH, ODDS_V7) și
`roblox/robux_list_2026-10-07.txt`.

**Pentru noul AI:** citește întâi `HANDOFF_2026-10-12_NEXT_AI.md`, apoi acest fișier. Regulile owner-ului (fără
publish, fără reset de progres, UI perfect pe PC și telefon) sunt valabile pentru tot ce scrie aici.

---

## 0. Pe scurt

**De ce se plictisesc jucătorii azi:**
- Conținutul se termină la Landmark Spire, la Rebirth 5. Asta înseamnă cam 12–13 ore de joc pentru un jucător activ:
  ~30 min până la Rebirth 1, ~1 h 30 până la Rebirth 2, ~3 h 30 până la Rebirth 3, ~6 h 30 până la Rebirth 4 și
  ~12 h 40 până la Rebirth 5.
- Un jucător care stă 5 ore pe zi ajunge acolo în ziua 3, exact cum a observat owner-ul.
- După Spire urmează doar Rebirth-uri la fiecare +20 de niveluri, cu aceleași clădiri. Aici e bucla plată.

**Ce schimbă V6:**

| | Azi | V6 |
|---|---|---|
| Lumi | Orașul (Town, Suburbs, Downtown) | **Orașul + Deșertul + Luna**, câte 3 zone fiecare |
| Ce face un Rebirth | te mută din Town în Suburbs, apoi în Downtown, după care repetă Downtown (R3–R5 deblochează câte o clădire) | **fiecare Rebirth = zona următoare**. R3 = Deșert, R6 = Luna. Nu mai există Rebirth-uri pe aceeași hartă |
| Cât conținut are un jucător activ (2 h/zi) | ~13 h, adică ~ziua 7 | **~46 h, adică ~ziua 24**. Cu o regiune nouă la 3–4 săptămâni, nu ajunge la capăt |
| Crate-ul zonei | Supply Crate la 1,5 min de venit (prețul crește odată cu venitul) | **preț fix pe zonă**: scump când intri (2,5 construcții), ieftin spre final (~3–7% dintr-o construcție mare), deci îl deschizi în serie, ca ouăle din PS99 |
| Ciocanele | o singură familie (×1 … ×128) | **o familie nouă pe regiune, ×16**: un Common din Deșert = un Legendary din Oraș; un Common de pe Lună = un Legendary din Deșert |
| Visul | Divine (1 din 5.000 în Golden) | Divine + **COLOSSAL** (1 din 100.000 în orice crate al zonei, anunțat pe server, se poate da la trade) |
| Robux | Exclusive Crate (999), Legends (999), Pirate/Temple (199), Golden, Builder's, pass-uri | la fel, plus **Exclusive Crate pe regiune, cu timp limitat**, **Region Pack** (o dată pe regiune), **Open ×3 / ×8** |

---

## 1. Harta progresului: 9 zone = Rebirth 0–8

| Regiune | Zona | Se deschide la | Intră la (ore de joc, activ) | Cât ține zona | Ziua: casual 45 min/zi | Ziua: activ 2 h/zi | Ziua: heavy 5 h/zi |
|---|---|---|---|---|---|---|---|
| Oraș | Town | start | 0 | 0,5 h | 1 | 1 | 1 |
| Oraș | Suburbs | Rebirth 1 | 0,5 | 1,5 h | 1 | 1 | 1 |
| Oraș | Downtown | Rebirth 2 | 2 | 4 h | 3 | 2 | 1 |
| Deșert | Dunes Outpost | Rebirth 3 | 6 | 4 h | 9 | 4 | 2 |
| Deșert | Oasis | Rebirth 4 | 10 | 5 h | 14 | 6 | 3 |
| Deșert | Oil Fields | Rebirth 5 | 15 | 6 h | 21 | 8 | 4 |
| Lună | Moon Base | Rebirth 6 | 21 | 7 h | 29 | 11 | 5 |
| Lună | Crater City | Rebirth 7 | 28 | 8 h | 38 | 15 | 6 |
| Lună | Spaceport | Rebirth 8 | 36 | 10 h (ultima zonă) | 49 | 19 | 8 |
| | Mega Rocket construit | | 46 | | 62 | 24 | 10 |

- Orele sunt pentru un jucător activ gratuit. Cine plătește (2x Cash, VIP, Super Strength) merge de ~2 ori mai repede, un
  whale de ~3–4 ori (raportul din v5).
- **Primul contact cu o lume nouă cade în ziua 2–4**, exact când azi jucătorii se plictiseau.
- Zonele devin tot mai lungi (0,5 h → 10 h), ca la PS99: la început totul vine repede, apoi fiecare zonă e un obiectiv
  de câteva zile.
- Jucătorii heavy (puțini) ajung la capăt în ~10 zile. Pentru ei rămân: Index-ul complet, vânătoarea de COLOSSAL,
  Zone Mastery, clasamentele și regiunea următoare (Mars / Atlantida / Space Station), adăugată **după** Lună, niciodată
  între regiunile existente.

---

## 2. Regulile de bază

1. **O singură monedă: Cash ($).** Rebirth-ul resetează oricum banii, așa că o monedă separată pe regiune (Oil, Moon
   Rock) n-ar aduce nimic în plus. Ar complica doar pass-urile (2x Cash, cash packs) și ar cere migrare.
2. **Rebirth = treci în zona următoare.** Ai nevoie de:
   - clădirea de top a zonei tale construită o dată (ca azi);
   - nivelul din tabelul de la secțiunea 3.

   Ce se resetează și ce rămâne nu se schimbă față de azi:
   - **Se resetează:** cash, gear, crew, utilaje, proprietăți, upgrade-uri.
   - **Rămân:** Strength, Level, ciocane, crate-uri, Gems, Stars, pass-uri, casa, mașinile.
3. **Downtown capătă toate cele 5 clădiri la Rebirth 2:** Office, Hotel, Skyscraper, HQ, Spire. Dispar `reqRebirth` 3/4/5;
   rămân doar porțile de Strength și de crew, recalibrate (secțiunea 9). Clădirea de top a Downtown devine
   **Landmark Spire**.
4. **După ultima zonă lansată nu mai există Rebirth.** Fereastra de Rebirth arată „🌙 THE MOON OPENS IN 5 DAYS” (sau
   numele regiunii următoare) cu numărătoare inversă.
5. **Bonusul de Rebirth rămâne:** +150% cash per Rebirth, adunat (R8 = ×13) și +75% Strength.
6. **Toate zonele deblocate rămân accesibile** prin portalurile din hub (fântâna) și prin PLACES. Poți reveni oricând
   în Oraș.
7. **Intrarea într-o zonă nouă e o sărbătoare:**
   - cinematic scurt cu numele zonei;
   - **3 crate-uri gratuite ale zonei** (Welcome Crates), deschise automat ca în tutorial;
   - 100 de Gems la prima intrare într-o regiune.

   Așa jucătorul devine imediat mai puternic.
8. **Fiecare regiune are fizica și atmosfera ei.** Deșertul: cer cald, miraje, furtuni de nisip (decor). Luna:
   **gravitație mică** (sărituri mari), cer negru cu Pământul. Gravitația se aplică doar pe client, în zona Lunii.

---

## 3. Clădirile, banii și XP-ul

- **Recompensele din Oraș rămân cele de azi.** Lumile noi continuă ritmul Orașului: ×2,8 pe clădire, XP ×1,6 pe clădire.
- **Prețul crate-ului de zonă** = 2,5 × recompensa primei clădiri a zonei × bonusul de Rebirth la intrare (Town: $150, ca
  azi în tutorial).
- **Ritmul în fiecare zonă:** clădirea k se deblochează la începutul zonei + lungimea zonei × (0 / 0,15 / 0,35 / 0,6 /
  0,85). Ultimele 15% ale zonei sunt pentru nivelul necesar Rebirth-ului.

| Zona (Rebirth) | Bonus cash | Level pentru Rebirth-ul care o deschide | Clădirile (premiu de bază → XP) | Crate-ul zonei |
|---|---|---|---|---|
| Town (R0) | ×1 | — | Repair Fence $60 → 25 · Garden Shed $190 → 55 · Brick Garage $520 → 120 · Small Family House $1,6K → 300 · **Corner Shop** $4,2K → 620 | **$150** |
| Suburbs (R1) | ×2,5 | 12 | Two-Story Villa $14K → 1,3K · Logistics Warehouse $32K → 2,1K · Apartment Block $85K → 3,6K · Luxury Villa $210K → 6K · **Distribution Center** $520K → 9K | **$88K** |
| Downtown (R2) | ×4 | 35 | Glass Office Tower $1,6M → 15K · Grand Hotel $4,5M → 24K · Skyscraper $14M → 38K · Corporate HQ $45M → 60K · **Landmark Spire** $150M → 100K | **$16M** |
| Dunes Outpost (R3) | ×5,5 | 55 | Desert Well $420M → 160K · Adobe House $1,2B → 260K · Gas Station $3,4B → 420K · Oil Derrick $9,5B → 670K · **Desert Motel** $27B → 1,1M | **$5,8B** |
| Oasis (R4) | ×7 | 75 | Oasis Bazaar $76B → 1,8M · Palm Resort $210B → 2,9M · Solar Farm $590B → 4,6M · Desert Mall $1,7T → 7,4M · **Great Pyramid** $4,8T → 12M | **$1,3T** |
| Oil Fields (R5) | ×8,5 | 100 | Oil Pipeline $13T → 19M · Oil Refinery $36T → 30M · Tanker Port $100T → 48M · Golden Tower $280T → 77M · **Oil Palace** $780T → 120M | **$280T** |
| Moon Base (R6) | ×10 | 125 | Landing Pad $2,2Qa → 190M · Moon Habitat $6,2Qa → 300M · Solar Array $17Qa → 480M · Rover Garage $48Qa → 770M · **Moon Dome** $130Qa → 1,2B | **$55Qa** |
| Crater City (R7) | ×11,5 | 145 | Crater Mine $360Qa → 1,9B · Oxygen Plant $1Qi → 3B · Lunar Lab $2,8Qi → 4,8B · Moon Hotel $7,8Qi → 7,7B · **Colony Tower** $22Qi → 12B | **$10Qi** |
| Spaceport (R8) | ×13 | 165 | Launch Tower $62Qi → 19B · Rocket Hangar $170Qi → 30B · Mission Control $480Qi → 48B · Space Elevator $1,3Sx → 77B · **Mega Rocket** $3,6Sx → 120B | **$2Sx** |

- Clădirea de top (**îngroșată**) a fiecărei zone deschide Rebirth-ul. Mega Rocket are un cinematic de lansare cu
  teaser pentru regiunea următoare.
- **Numerele mari:** sufixele Qa (10^15), Qi (10^18) și Sx (10^21). `Config.Short` trebuie să le aibă. Verifică și
  câmpurile salvate (Money, Earned, RunEarned): numerele Luau sunt double, deci încap, dar orice `math.floor` /
  `tostring` / formatare trebuie testată la 10^22.
- **XP-ul și nivelul:** nivelurile pentru Rebirth (12, 35, 55, 75, 100, 125, 145, 165) continuă regula de azi (+20 după
  125). Pe simulator, poarta trebuie să fie clădirea de top. Nivelul nu are voie să țină jucătorul pe loc mai mult de
  ~15% din zonă. Dacă îl ține, scade nivelul cerut, nu crește XP-ul.

---

## 4. Puterea: Strength × ciocan × crew

- **Strength** (antrenament + construit, rămâne pentru totdeauna) dă ×(1 + (S/40)^0,55), ca azi (LOOP_V7).
  - Fiecare regiune nouă aduce **1 stație de antrenament** și **2 trepte de gear**, ca Strength-ul să țină pasul:
    - Deșert: „Oil Barrel Press”, ×6;
    - Luna: „Low-G Boulder Toss”, ×10.

    Pragurile se reglează în Studio (secțiunea 9).
- **Ciocanul:** puterea = factorul regiunii × 2^(raritate−1) × nivelul ciocanului.

  | Familia | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Divine |
  |---|---|---|---|---|---|---|---|---|
  | Oraș (cele de azi) | ×1 | ×2 | ×4 | ×8 | ×16 | ×32 | ×64 | ×128 |
  | Deșert (×16) | ×16 | ×32 | ×64 | ×128 | ×256 | ×512 | ×1K | ×2K |
  | Lună (×256) | ×256 | ×512 | ×1K | ×2K | ×4,1K | ×8,2K | ×16,4K | ×32,8K |

  - **Când intri în Deșert,** primul Common nou (din cele 3 Welcome Crates) e la fel de bun ca un Legendary din Oraș.
    Saltul se simte imediat.
  - **Ce ai scos cu noroc nu se pierde:** un Mythic sau Divine din Oraș te mai duce o bucată din Deșert (Divine ×128 = Epic
    de Deșert).
  - **Thunderclap** (×256, cel mai puternic azi) = Legendary de Deșert. Rămâne o piesă de colecție rară.
- **Ciocanele noi (1 pe raritate e minimul; al doilea vine la un update ulterior):**
  - **Deșert:** Sandstone Mallet (Common), Cactus Hammer (Uncommon), Oil Drill Hammer (Rare), Scorpion Hammer (Epic), Sun
    Disk Hammer (Legendary), Sandstorm Hammer (Mythic), Black Gold Hammer (Secret), Mirage Hammer (Divine).
  - **Lună:** Moon Rock Mallet, Rover Hammer, Crater Crusher, Astronaut Hammer, Comet Hammer, Eclipse Hammer, Starforge
    Hammer, Supernova Hammer (în aceeași ordine a rarităților).
- **Crew și utilaje:** aceleași reguli (LOOP_V7: lucrează cu puterea ta întreagă). Fiecare regiune adaugă un utilaj:
  - Deșert: Oil Rig Truck;
  - Luna: Moon Rover Crane.

---

## 5. Crate-urile: ce sunt, cât costă, când apar

### 5.1 Crate-ul zonei (pe cash): motorul principal, ca ouăle din PS99

- **Unde:** câte un crate pentru fiecare zonă, cu ciocane din familia regiunii. Stă **fizic în zonă**, pe un stand cu
  semn de preț și butoane OPEN 1 / ×3 / ×8 / AUTO, ca ouăle din PS99. Rămâne și în Shop. Standul din zonă se vede și își
  face singur reclamă.
- **Prețul e fix** (tabelul din secțiunea 3):
  - când intri în zonă e o decizie (≈ 2,5 construcții ale primei clădiri);
  - la final costă cât ~3–7% dintr-o construcție de top, deci îl deschizi în serie. Atunci pass-urile de deschidere
    rapidă (×3, ×8, Auto, Quick Open) valorează mult.
- **Șansele, după locul zonei în regiune** (suma = 100%; aceleași în Oraș, Deșert și Lună):

  | Zona din regiune | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Divine | Epic+ | Legendary+ |
  |---|---|---|---|---|---|---|---|---|---|---|
  | 1 (Town / Dunes / Moon Base) | 62 | 28 | 8,89 | 1 | 0,1 | 0,01 | — | — | 1 din 90 | 1 din 909 |
  | 2 (Suburbs / Oasis / Crater) | 30 | 38 | 22 | 8 | 1,8 | 0,19 | 0,01 | — | 1 din 10 | 1 din 50 |
  | 3 (Downtown / Oil Fields / Spaceport) | — | 30 | 40 | 24 | 5,4 | 0,555 | 0,04 | 0,005 | 1 din 3 | 1 din 17 |

- **Ce se schimbă la crate-urile din Oraș:** față de cele de azi, zona 1 și zona 2 primesc un vârf mic de Legendary /
  Mythic / Secret, adică visul că „orice se poate”. Cantitatea e neglijabilă pe piață.
- **Pity:** Epic sau mai bun garantat la fiecare 40 de crate-uri de zonă. Contează doar în prima zonă a regiunii, unde
  Epic e 1 din 90. Așa 40 de crate-uri nu se simt niciodată ca o țeapă.
- **Norocul:** se aplică la fel ca azi (de la Legendary în sus; la Secret / Divine cel mult ×3, apoi × Secret Hunter).
  Lucky Rush (×2 noroc la 40 de minute) devine momentul în care lumea își deschide crate-urile strânse. HUD-ul spune asta:
  „SAVE YOUR CRATES FOR LUCKY RUSH!”.
- **Crate-urile gratuite:**
  - **Welcome Crates:** 3 la intrarea în fiecare zonă.
  - **Daily Crate:** devine **3 crate-uri ale zonei tale** (azi e 1), pentru că acum crate-ul e sursa principală de
    putere.
  - **Pașii Road-ului** (secțiunea 8).

### 5.2 Crate-urile pe Gems (diamante)
- **Builder's Crate** (200 Gems / 79 R$) și **Golden Crate** (750 Gems / 249 R$; Legendary+ garantat la 20) dau ciocane
  din **familia regiunii tale celei mai avansate**. Așa rămân utile în Deșert și pe Lună. Șansele rămân cele de azi
  (ODDS_V7).
- **Hammer of the Day** (Epic 3K / Legendary 12K / Mythic 60K Gems) vine tot din familia regiunii tale.
- Așa „lucrurile rare doar pe diamante” rămân valabile în toate regiunile.

### 5.3 Crate-urile pe Robux
- **Exclusive Crate pe regiune, cu timp limitat:**
  - **Ce dă:** Legendary sau mai bun din familia regiunii, plus exclusivele ei:
    - **Oraș** (cel de azi): Royal Crown, Ghost, Rainbow Prism, Thunderclap;
    - **Deșert:** Sultan's Hammer, Djinn Lamp Hammer, Golden Camel Hammer și, „1 in ???”, Sphinx Hammer;
    - **Lună:** Alien Hammer, Rocket Hammer, UFO Hammer și, „1 in ???”, Black Hole Core.
  - **Prețul:** 999 R$, sau 3 pentru 2.699.
  - **Șansele și pity-ul:** ca azi (Mythic 1 din 5, Secret 1 din 22, Divine 1 din 200, Exclusive 1 din 33; Secret+
    garantat la 25). Puterea exclusivelor e cea de Mythic a familiei lor (varianta A).
  - **Limitat:** fiecare se vinde până la lansarea regiunii următoare, apoi iese din Store pentru totdeauna. Cu 3 zile
    înainte apare „LAST CHANCE” în HUD și în Store. Lipsa îi dă valoare la trade și urgență la cumpărare (modelul PS99).
- **Crate-urile cu seturi** (Pirate Cove / Jungle Temple 199 R$ sau 600 Gems, Legends 999 R$): rămân, cu familia
  Orașului. La un update ulterior se adaugă un set pe regiune, de exemplu „Desert Caravan” sau „Moon Mission”, cu același
  preț și același bonus de colecție (+5% noroc).
- **Ce rămâne neschimbat:**
  - în țările unde PolicyService nu permite crate-uri plătite: X-Ray, ca azi;
  - butonul ODDS cu procentele exacte înainte de cumpărare, pentru **orice** crate nou.

### 5.4 COLOSSAL: visul care se anunță pe server

- **Ce este:** un ciocan COLOSSAL pe regiune, versiunea uriașă a Divine-ului ei: Colossal Galaxy (Oraș), Colossal
  Mirage (Deșert), Colossal Supernova (Lună). Se vede de ~1,6 ori mai mare în mână, are aura lui și eticheta
  „COLOSSAL”.
- **Puterea:** ×2 față de Divine-ul regiunii (cel mai puternic ciocan al regiunii).
- **Șansele:** 1 din 100.000 în orice crate de zonă, 1 din 25.000 în Golden, 1 din 2.500 în Exclusive. E o tragere
  separată, peste șansele normale. Norocul contează cel mult ×3.
- **Cât de rar:** la 1.000 de jucători pe zi care deschid ~200 de crate-uri de zonă și 1 Golden fiecare, ies **~2 pe zi
  în tot jocul**. E destul de rar ca să fie vis, dar destul de des ca mesajul să apară pe servere.
- **Momentul:** mesaj pe tot serverul („🔥 vlagg124 pulled a COLOSSAL MIRAGE! 1 in 100,000”), sunet, explozie de
  confetti și un loc pe tabla „COLOSSAL HALL OF FAME” de lângă fântână.
- **Se poate da la trade**, cu taxa de azi. Nu se vinde niciodată direct.

---

## 6. Diamantele (Gems)

**Azi** un jucător gratuit strânge ~280–320 de Gems pe oră:
- din contracte: 1 + ordinul clădirii / 4, +1 dacă e rapidă;
- din lovituri;
- din misiunile zilnice, streak, playtime, Road și achievements.

**Ce se adaugă:**
- **Mai multe Gems pe contract în lumile noi**, fără nicio schimbare de cod: ordinul clădirilor ajunge la 45, deci un
  contract dă 5–12 Gems.
- **Speed Build și Parkour** (lumile din hub-ul cu portaluri):
  - **Speed Build:** 10 / 25 / 50 Gems (bronz / argint / aur), cu cooldown de 15 min.
  - **Parkour:** cufărul de la final dă 15 / 40 / 100 Gems (Easy / Medium / Hard), cu cooldown de 20 min.
  - **Cufărul mare zilnic** (Parkour Hard): 250 de Gems + 1 Golden Crate.
- **Index pe regiune:** fiecare raritate completă a unei familii noi dă 100 × indexul rarității în Gems și +5% noroc,
  ca azi.
- **Bonus de regiune:** 100 de Gems la prima intrare în fiecare regiune.

**Unde se cheltuie** (în plus față de azi):
- **Builder's / Golden** din familia regiunii tale (secțiunea 5.2).
- **2x Luck pe 15 minute:** 80 de Gems în Gem Shop. Poțiunea de noroc e ce cumpără lumea pentru o sesiune de deschis
  crate-uri.
- **Aure cosmetice pentru ciocan** (doar aspect, fără putere): 2.000–20.000 de Gems. Pentru cei care au strâns mult.

**Ce nu se schimbă:**
- Gems-urile nu se dau la trade.
- Nu există drum de la Cash la Gems.
- Pachetele de Gems pe Robux rămân aceleași.

---

## 7. Robux: ce e nou

| Ce | Preț | Când apare | De ce |
|---|---|---|---|
| **Region Pack** (Desert Pack, Moon Pack): 10 crate-uri ale primei zone a regiunii + 750 Gems + 30 min 2x Cash | 299 R$, o singură dată pe regiune | ofertă (OffersUI) la prima intrare în regiune, apoi în Store | momentul de entuziasm la intrarea într-o lume nouă |
| **Open ×3** (pass) | 299 R$ | Store, plus ofertă după 50 de crate-uri deschise | deschiderea în serie e bucla principală |
| **Open ×8** (pass, cere Open ×3) | 999 R$ | Store, plus ofertă după 300 de crate-uri deschise | la fel, pentru jucătorii mari |
| **Exclusive Crate pe regiune** (limitat) | 999 / 3 pentru 2.699 | la lansarea regiunii, scos la lansarea următoarei | secțiunea 5.3 |
| **Colossal Hunter** (pass, ×2 la COLOSSAL; opțional, faza 3) | 1.499 R$ | după ce primele COLOSSAL au apărut pe servere | ca „Huge Hunter” din PS99 |

**Rămân la fel:**
- toate pass-urile de azi (VIP, 2x Cash, Lucky Builder, Ultra Lucky, Secret Hunter, Quick Open, Auto Opener, Skip
  Animation, Auto Builder etc.);
- Starter Pack;
- pachetele de cash: cresc singure cu venitul, pentru că sunt minute de venit;
- pachetele de Gems, crate-urile pe Robux și 2x Offline Cash.

**Skip Animation** s-a vândut la jucători random (2026-10-12). Rămâne oferit în același moment (cinematicul de
construcție).

---

## 8. Motive să revii (D1, D7) și să mai joci o tură

- **Empire Road pe fiecare zonă:** câte un capitol de 6–8 pași pentru fiecare zonă nouă: fiecare clădire, primul crate
  al zonei, „deschide 25 de crate-uri ale zonei”, prima raritate din Index-ul regiunii, Zone Mastery 1 și „Level X →
  Rebirth”.
  - **Premii pe Road:** ~8% din banii zonei pe tot capitolul, ca azi, și 5–25 Gems pe pas.
  - **Crate-uri pe Road:** 2 pe capitol (un crate al zonei la a 2-a clădire și un Golden la Rebirth).
- **Zone Mastery** (nou, ca Mastery din PS99): construcțiile repetate capătă un scop.

  | Construcții în zonă | Cash în zona respectivă (pentru totdeauna) | Gems |
  |---|---|---|
  | 25 | +10% | 50 |
  | 100 | +25% | 150 |
  | 250 | +50% | 400 |

  Apare în Job Board ca bară sub numele zonei.
- **Zilnic:**
  - Daily Crate (3 crate-uri ale zonei);
  - streak de login, cu **Golden Crate în ziua 7** (azi doar Gems);
  - spin gratuit la 4 h;
  - cadourile de playtime;
  - cufărul mare din Parkour.
- **Săptămânal:** Golden Order (ca azi).
- **Evenimente la 20 de minute:** Lucky Rush și Cash Rush (ca acum). La lansarea unei regiuni: **weekend cu 2x Luck**
  pe tot jocul.
- **Banii cât lipsești:** 50% / 8 h (Night Shift 100% / 12 h) și fereastra WELCOME BACK, ca acum.
- **Pe ecran, de la început:** în hub se văd portalurile spre Deșert și Lună, blocate, cu „REBIRTH 3” și „REBIRTH 6”.
  Jucătorul știe din prima zi că urmează lumi noi.

---

## 9. Cum se face în Studio (pentru noul AI)

**Ordinea de lucru:** P0 din handoff (teleport + funnel) → V6 partea 1 (Deșert) → hub-ul cu portaluri → V6 partea 2
(Lună). Fiecare parte e testată complet înainte să-i spui owner-ului că poate publica.

1. **Exportă valorile live** din Studio (Config, Company, Hammers, Economy, RebirthService, HammerService) într-un
   fișier `tools/econ/game_dump_v6.md`. Copiile din repo (`roblox/*.lua`) sunt vechi, din 7 octombrie, deci nu te baza
   pe ele.
2. **Actualizează simulatorul** (`tools/econ/sim.py` / `v5.py`) la regulile LOOP_V7 (puterea din Strength, crew-ul pe
   puterea ta, munca rescalată, Rebirth pe Level) și la regulile V6 de aici.
3. **Reglează doar două lucruri** (`workMult` și `reqStrength` pentru fiecare clădire; recompensele sunt fixate în
   secțiunea 3) ca să iasă **orele din secțiunea 1**, cu toleranță ±15%:
   - **Când se deblochează:** clădirea k a unei zone se deblochează la începutul zonei + lungimea zonei × (0 / 0,15 /
     0,35 / 0,6 / 0,85).
   - **Cât durează prima construcție:** la pragul ei de Strength, cu crew-ul cerut și cu ciocanul „1 din 10” al
     crate-ului zonei, prima construcție ține între 90 și 240 de secunde (90 / 120 / 150 / 180 / 240 s pentru clădirile
     1–5). Construcțiile următoare devin mai rapide pe măsură ce crești.
4. **Pragurile de acceptare:**
   - jucătorul activ intră în Deșert la 6 h ±1 h și pe Lună la 21 h ±3 h;
   - niciun moment fără un obiectiv vizibil mai lung de ~20 min: clădire nouă, crate, gear, Mastery sau nivel;
   - un copil care cumpără la întâmplare termină Downtown în cel mult de 1,6 ori timpul jucătorului activ;
   - fiecare crate de zonă costă la intrare 2–3 construcții, iar la finalul zonei cel mult ~7% dintr-o construcție de
     top (`v6_regions.py` arată 2,7–6,8%).
5. **Migrarea:** fără reset, regula owner-ului.
   - Câmp nou `Zone` (1–9) în profil; `Rebirths` rămâne cu valoarea lui, iar bonusul de cash / Strength nu scade.
   - `Zone = min(Rebirths + 1, 4)`: R0 → Town, R1 → Suburbs, R2 → Downtown, **R3 sau mai mult → Dunes Outpost**. Un
     jucător cu R5 de azi păstrează bonusul de R5 (×8,5 cash) ca bonus de veteran, dar continuă din prima zonă a
     Deșertului cu cele 3 Welcome Crates.
   - Clădirile construite rămân construite (Portfolio). Downtown are toate cele 5 deschise.
   - Înainte: citește (doar citire, Data Stores Manager) câți jucători au R ≥ 3 și arată-i owner-ului lista înainte de
     publicare.
6. **Testele** (pe lângă regulile din handoff):
   - profil nou cap-coadă până în Deșert, cu `CE_Debug` pentru timp;
   - profil vechi cu R5 (migrare);
   - crate-urile fiecărei zone: 10.000 de deschideri simulate, cu procentele comparate cu tabelul;
   - pity-ul la 40;
   - COLOSSAL forțat cu debug (anunțul, aura, trade-ul);
   - X-Ray în țările restricționate;
   - sufixele Qa, Qi, Sx peste tot în UI (HUD, Job Board, Shop, Rebirth, Trade);
   - gravitația pe Lună (intrare și ieșire);
   - performanța pe telefon cu hărțile noi (StreamingEnabled, ~60 FPS pe un telefon mediu);
   - toate ferestrele noi verificate după regula de UI (nimic lipit, totul centrat, text care încape) pe PC și în
     emulatorul de telefon.

---

## 10. Lansarea și reach-ul

| Când | Update | Ce intră |
|---|---|---|
| S0 | (în lucru) | P0: teleport, funnel curat |
| S1–S2 | **🏜️ DESERT UPDATE** | Downtown cu 5 clădiri, cele 3 zone din Deșert, familia Desert (8 ciocane), crate-uri de zonă cu preț fix și standuri, COLOSSAL (Oraș + Deșert), Exclusive Crate de Deșert, Desert Pack, Open ×3 / ×8, Zone Mastery, migrarea |
| S3 | **🌀 PORTALS UPDATE** | hub-ul de la fântână: Speed Build + Parkour, recompensele lor în Gems și crate-uri |
| S5–S6 | **🌙 MOON UPDATE** | cele 3 zone de pe Lună, familia Moon, gravitație mică, Moon Exclusive (cel de Deșert iese din Store), Moon Pack, Colossal Supernova |
| după | o regiune nouă la 3–4 săptămâni, cu un update mic între ele | Mars / Atlantida / Space Station, seturi noi de crate-uri, aure |

**Pentru reach, la fiecare update:**
- **Titlul jocului** primește tag-ul update-ului, de exemplu `BlockRise Empire [🏜️ DESERT]`.
- **Thumbnail nou și primul în listă:** lumea nouă și un ciocan uriaș.
- **Prima linie din descriere:** „🏜️ NEW: THE DESERT!”.
- **Numărătoare inversă în joc** cu 3 zile înainte („DESERT UPDATE IN 2D 4H”).
- **Lansarea** sâmbăta la 18:00, ora României (= 11:00 New York, 16:00 Londra). Toți intră în același moment, iar
  vârful de CCU ajută algoritmul.
- **Weekend cu 2x Luck** la lansare.
- **Cei 100€ de reclame:** dacă pragurile din handoff (secțiunea 6) sunt atinse, se cheltuie pe weekendul de lansare a
  Deșertului. Ai conținut nou, thumbnail nou și eveniment pornit exact când intră jucătorii din reclame.

**Ce urmărești după fiecare update** (Creator Hub, funnel-ul curat și evenimente noi `Entered <zone>`):
- D1 și D7;
- durata medie a sesiunii;
- câți jucători ajung în Downtown și în Deșert;
- crate-uri deschise per jucător;
- câți cumpără ceva;
- Robux pe jucător pe zi.

---

## 11. Ce trebuie să confirme owner-ul
1. O singură monedă (Cash) pentru toate regiunile.
2. Downtown cu toate cele 5 clădiri la Rebirth 2; Deșertul la Rebirth 3, Luna la Rebirth 6.
3. Ritmul din secțiunea 1 (Deșert ~ziua 4 pentru un jucător activ, capătul Lunii ~ziua 24).
4. Crate-urile de zonă cu preț fix, cu șansele și pity-ul din 5.1.
5. Ciocanele pe familii, ×16 pe regiune; numele ciocanelor noi.
6. COLOSSAL: 1 din 100.000, ×2 față de Divine, se poate da la trade.
7. Exclusive Crate pe regiune, cu timp limitat (cel din Oraș iese din Store la lansarea Deșertului).
8. Robux noi: Region Pack 299, Open ×3 299, Open ×8 999 (Colossal Hunter mai târziu).
9. Migrarea: jucătorii cu R ≥ 3 intră în Dunes Outpost și își păstrează bonusul.
10. Zone Mastery și Golden Crate în ziua 7 din streak.
