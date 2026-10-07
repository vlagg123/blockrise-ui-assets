# BlockRise Empire — rețeta economiei (propunere, NIMIC implementat încă)

Lucrat în noaptea de 7 octombrie 2026. Toate cifrele „azi” sunt citite din Studio (Config, Company, Hammers, Main, Crew,
Machines, CompanyService, RebirthService). Cifrele „propus” vin dintr-un simulator al jocului (`tools/econ/sim.py`) care
folosește formulele reale ale jocului, plus 120+ scenarii (`tools/econ/sweep.py`).

---

## 1. Ce fac jocurile care au explodat (rețeta lor)

**Pet Simulator 99 (BIG Games)**
- 2,66 miliarde de vizite, vârf de 250.000 de jucători simultan (dec. 2024), ~52.000 acum, venit estimat ~534.000 $/lună
  (rowatcher).
- Rebirth-urile sunt la zonele 25 / 50 / 75 / 99 (lumea 1), apoi 125 / 150 / 175 / 199 / 219. Fiecare dă **+75% putere
  pentru pets**, plus o funcție nouă: teleport, auto-hatch, clanuri, echipe, ultimates, lumea 2 / 3.
  - Costă 10K → 25K → 50K → 100K diamante: fiecare rebirth cere zone tot mai departe.
- Ouăle sunt per zonă: costă în moneda zonei, iar ouăle de mai târziu dau pets mai buni.
  - Huge / Titanic au șanse infime. Un gamepass precum „Huge Hunter” (3.250 R$) dă **+6.250% șansă de Huge** (×63),
    ceea ce arată cât de mică e șansa de bază.
- Gamepass-uri (R$):

  | Gamepass | Preț | Efect |
  |---|---|---|
  | Lucky | 275 | +200% luck |
  | Ultra Lucky | 800 | +500% luck |
  | VIP | 400 | |
  | Magic Eggs | 1.200 | |
  | +15 Pets | 375 | |
  | Huge Hunter | 3.250 | |
  | Auto Farm | 175 | |
  | Auto Tap | 350 | |
  | +15 Eggs | 625 | |
  | +40 Egg Hatch | 1.499 | |
  | Super Drops | 2.400 | |
  | Super Shiny Hunter | 1.600 | |

  Total ~16.000 R$. Luck-urile se cumulează.
- Piața de trading e alimentată de raritate: valoarea unui pet = câte există („exists”). Cu cât sunt mai puține, cu atât
  e mai scump.

**Bee Swarm Simulator** (șanse publice pe wiki):

| Ou | Rare | Epic | Legendary | Gifted | Mythic |
|---|---|---|---|---|---|
| Basic | 1 în 10 | 1 în 40 | 1 în 200 | 1 în 250 | |
| Silver | | | | | 1 în 1.000 |
| Gold | | | | | 1 în 100 |
| Diamond (Robux, 300–800 R$) | | | | | 1 în 20 |

Ouă vândute pe Robux:
- Mythic Egg: 800 R$, Mythic garantat;
- Choose-a-Mythic: 1.000 R$.

**Ce se vede la jocurile virale din 2025** (Grow a Garden, Steal a Brainrot, Bubble Gum Simulator INFINITY) — din ce
știu, fără cifre exacte:
- bucla e foarte simplă, iar venitul pe secundă se vede tot timpul;
- rarități cu un nivel „Secret” la șanse de 1 în mii sau milioane;
- **evenimente pe server cu luck ×2 / ×3** (motiv să rămâi online);
- stocuri sau oferte care se reîmprospătează (motiv să revii);
- iteme limitate în timp (piață + FOMO).

**Ritmul rebirth-urilor** (ghid pentru simulatoare Roblox, creation.dev):
- primul rebirth în 30–60 min la majoritatea jocurilor;
- conținut care să țină 20–50 de rebirth-uri;
- primele rebirth-uri dau salturi mari de putere, cele de mai târziu creșteri mai mici plus cosmetice.

**Regulile Roblox pentru lăzi plătite** (Creator Docs):
- șansele trebuie arătate ca procente care adună exact 100%;
- în țările cu restricție sunt permise variantele „ordine predeterminată, arătată înainte de plată” (X-ray-ul nostru),
  „cale gratuită” sau „ascunde / blochează”.

**Ce iau de aici pentru BlockRise:**
1. Primul rebirth repede (în prima sesiune), apoi fiecare rebirth ×1,7–1,9 mai lung decât precedentul.
2. Lăzi per zonă, cu prețul legat de cât câștigi acolo. Doar unele lăzi pot da itemele de top.
3. Iteme de top la șanse de tip „1 în zeci de mii”: puține există, deci piața are valoare.
4. Luck care se cumulează din mai multe surse: item (casca), gamepass, poțiune, eveniment pe server.
5. Gamepass-uri de tip multiplicator / automatizare, la 175–800 R$, plus câteva „vânătoare” scumpe (1.500–3.000 R$).

---

## 2. Auditul jocului nostru (azi)

### Timpul până la fiecare Rebirth (simulat, cu formulele reale ale jocului)

| Jucător | Rebirth 1 | Rebirth 2 | Rebirth 3 | Rebirth 4 |
|---|---|---|---|---|
| activ, gratis | 44 min | 2 h 48 | 5 h 15 | 9 h |
| casual, gratis | 78 min | 4 h 04 | 7 h 23 | 12 h 28 |
| plătitor (2x Cash, VIP, 2x Str) | 26 min | 1 h 43 | 2 h 51 | 4 h 25 |

Rebirth 1 cere 150K câștigați în tură plus clădirea Corner Shop (strength 2.500, crew 3, ciocan Uncommon).
Rebirth 2 cere 40M.

### Problemele găsite

1. **Primul rebirth vine prea târziu.** 45–80 min, iar al doilea rebirth la 3–4 ore: copilul pleacă înainte să simtă
   bucla.
2. **E un clicker obositor.** Jucătorul face singur 82–92% din muncă în primele zone și dă click în continuu, 110–150
   click-uri pe minut. Crew-ul și utilajele contează prea puțin.
3. **Costurile de rebirth sar neregulat:** 150K → 40M (×267) → 10B (×250) → 100B (×10) → 1T (×10) → ×10. Rebirth-ul 2
   e un zid.
4. **Lăzile Supply se exploatează.** Prețul e 15% din recompensa de bază a celui mai bun contract, nu din cât câștigi
   tu. Cu multiplicatorii de rebirth și pass-uri, lada ajunge să coste câteva secunde de venit.
   - Trade-up-ul 10→1 merge până la Divine.
   - În simulare, un jucător gratis care cumpără Supply în masă scoate **9 Divine în 20 de ore**.
5. **Șansele sunt prea generoase.** Golden Crate: Divine 1 în 1.000, Secret 1 în 111, Mythic 1 în 17.
   - Un jucător activ gratis are primul Legendary în ~1,8 h și primul Mythic în ~9 h.
   - La 1.000 de jucători pe zi, după 30 de zile există ~34.000 Legendary, ~1.700 Mythic, ~210 Secret și ~23 Divine.
     Piața nu are ce valoare să aibă.
6. **Banii offline sunt nelimitați.** Proprietățile plătesc 100% offline, fără limită de ore (200% cu Night Shift), iar
   chiria intră la banii pentru Rebirth.
   - Online, proprietățile nu merită: se recuperează în 30–170 min.
   - Offline sunt ruptura economiei: nu joci, dar faci rebirth.
7. **Muncitorii au preț fix** (200 / 800 / 6.000) și nu mai înseamnă nimic după prima zonă.
8. **Porți de conținut bazate pe noroc.** Contractele cer o raritate de ciocan (Rare / Epic), iar cu șansele noi asta
   ar bloca jucătorii gratis. Level-ul și Rep-ul sunt porți dublate care fac zid după rebirth.
9. **Training Yard-ul dă ×3…×50 față de o lovitură la construcție.** Strength-ul se face mai repede stând la
   antrenament decât construind, deci copiii ajung să antreneze în loc să joace bucla principală.
10. **Puterea ciocanelor e plată.** Divine e doar ×8 față de Common (×1,35 pe raritate): un item de 1 în 25.000 abia se
    simte.

---

## 3. Ținta și rezultatul, pe scurt

**Cum trebuie să se simtă:**
- primul Rebirth în prima sesiune (~15–20 min);
- fiecare Rebirth cam de 2 ori mai lung decât precedentul;
- crew-ul și utilajele preiau treptat munca: jucătorul nu trebuie să dea click non-stop;
- itemele de top sunt rare de-adevăratelea.

**Minute de joc până la fiecare Rebirth** (media pe 5 rulări cu noroc diferit la lăzi):

| Jucător | | Rebirth 1 | Rebirth 2 | Rebirth 3 | Rebirth 4 | Rebirth 5 |
|---|---|---|---|---|---|---|
| activ, gratis | azi | 44 min | 2 h 48 | 5 h 15 | 9 h | — |
| | **propus** | **19 min** | **55 min** | **1 h 51** | **4 h 00** | **8 h 28** |
| casual, gratis | azi | 78 min | 4 h 04 | 7 h 23 | 12 h 28 | — |
| | **propus** | **23 min** | **67 min** | **2 h 12** | **5 h 09** | **10 h 50** |
| plătitor (2x Cash, VIP, 2x Str) | azi | 26 min | 1 h 43 | 2 h 51 | 4 h 25 | — |
| | **propus** | **9 min** | **29 min** | **58 min** | **2 h 07** | **4 h 12** |
| whale (toate pass-urile) | **propus** | **6 min** | **18 min** | **38 min** | **1 h 19** | **2 h 32** |

- „Nici 10 minute până la al 5-lea rebirth”: nici whale-ul nu ajunge la Rebirth 5 în mai puțin de ~2 ore și un sfert.
- Norocul la lăzi schimbă puțin ritmul: Rebirth 1 între 17 și 20 min, Rebirth 5 între 8 h 13 și 8 h 52 (jucător activ).

**Cum se simte fiecare tură** (jucător activ):

| Tura | Durată | Contracte | O construcție | Crew-ul face | Din chirii | Cumpărături / min |
|---|---|---|---|---|---|---|
| 1 (Town) | 17 min | 13 | 36 s | 24% din muncă | 0% | 0,8 |
| 2 (Suburbs) | 36 min | 42 | 24 s | 52% | 5% | 5,6 |
| 3 (Downtown) | 80 min | 48 | 66 s | 68% | 30% | 3,5 |
| 4 | 2 h 11 | 130 | 33 s | 74% | 15% | 2,4 |
| 5 | 4 h 28 | 166 | 70 s | 77% | 26% | 1,2 |

- O construcție ține între 25 s și 2 min.
- La început jucătorul lovește singur, apoi crew-ul face 3/4 din muncă.
- Cumpără ceva cam la fiecare 10–75 de secunde.

---

## 4. Rețeta, cifră cu cifră

### 4.1 Rebirth

| Rebirth | Cost azi (câștigat în tură) | Cost propus | Bani după (azi → propus) | Strength după (azi → propus) |
|---|---|---|---|---|
| 1 | 150K | **25K** + Corner Shop construit | ×1,5 → **×2,5** | ×1,5 → **×1,75** |
| 2 | 40M | **200M** + Distribution Center | ×2 → **×4** | ×2 → **×2,5** |
| 3 | 10B | **5B** + Hotel | ×2,5 → **×5,5** | ×2,5 → **×3,25** |
| 4 | 100B | **75B** + Skyscraper | ×3 → **×7** | ×3 → **×4** |
| 5 | 1T | **400B** + HQ | ×3,5 → **×8,5** | ×3,5 → **×4,75** |
| 6 | 10T | **2,5T** + Spire | **×10** | **×5,5** |
| 7 | 100T | **25T** | **×11,5** | **×6,25** |

- Formula: bani ×(1 + 1,5·R), strength ×(1 + 0,75·R).
- Fiecare Rebirth cere și ultima clădire a zonei: Rebirth-ul e o etapă de joc, nu doar o sumă.
- Sumele cresc neregulat pentru că fiecare zonă nouă plătește de zeci de ori mai mult. Ce contează e timpul (tabelul
  din secțiunea 3), iar timpul crește regulat.

### 4.2 Drumul: contractele

Recompensele rămân **exact ca azi**. Se schimbă munca (cât durează), porțile și zona.

| Contract | Zonă (Rebirth) | Recompensă | Muncă azi → propus | Strength azi → propus | Crew azi → propus | Prima construire |
|---|---|---|---|---|---|---|
| Fence | Town (0) | 60 | 209 → 140 | 0 → 0 | 0 | 25 s |
| Shed | Town (0) | 190 | 376 → 278 | 0 → 200 | 0 | 31 s |
| Garage | Town (0) | 520 | 864 → 451 | 60 → 750 | 1 | 30 s |
| House | Town (0) | 1,6K | 2,6K → 4,1K | 400 → 2K | 2 | 59 s |
| Corner Shop | Town (0) | 4,2K | 5,54K → 5,54K | 2,5K → 4K | 3 | 72 s |
| Villa | Suburbs (1) | 14K | 21,5K → 7,5K | 15K → 15K | 4 | 34 s |
| Warehouse | Suburbs (1) | 32K | 31,6K → 10,7K | 60K → 20K | 5 | 31 s |
| Apartments | Suburbs (1) | 85K | 36,9K → 16,4K | 200K → 50K | 6 | 25 s |
| Luxury Villa | Suburbs (1) | 210K | 43,7K → 32,3K | 600K → 600K | 7 → 6 | 28 s |
| Distribution Center | Suburbs (1) | 520K | 75,1K → 61,2K | 1,5M → 2,5M | 8 → 6 | 39 s |
| Office | Downtown (2) | 1,6M | 108K → 134K | 4,9M → 4,9M | 8 | 57 s |
| Hotel | Downtown (2) | 4,5M | 114K → 445K | 6,8M → 25M | 9 → 8 | 1 min 43 |
| Skyscraper | Downtown (2 → **3**) | 14M | 134K → 1,09M | 8,9M → 150M | 10 → 8 | 80 s |
| HQ | Downtown (3 → **4**) | 45M | 147K → 3,96M | 12M → 400M | 10 → 8 | 1 min 46 |
| Spire | Downtown (4 → **5**) | 150M | 192K → 5,19M | 35M → 1,5B | 12 → 8 | 55 s |

- **Se scot porțile de raritate a ciocanului** (azi House cere Uncommon, Villa Rare, Distribution Center Epic).
  Cu șansele noi, un jucător gratis ar rămâne blocat.
- **Se scot porțile de Level și Rep** (rămân ca recompense și titluri). Rămân doar zona (Rebirth), Strength și crew-ul.
- Downtown se deschide o clădire nouă la fiecare Rebirth (2, 3, 4, 5): fiecare Rebirth aduce ceva nou de construit.
- Verificat în simulare: fiecare contract chiar e construit în tura lui. La prima calibrare, Warehouse și Luxury Villa
  ieșeau mai slabe decât clădirea dinainte și nimeni nu le construia; le-am reparat, iar acum fiecare clădire nouă
  plătește mai bine pe minut.

### 4.3 Upgrade-uri (departamentele Company)

| | Azi | Propus |
|---|---|---|
| Bonus pe nivel | +10% (Strength +12%) | **+15%** la toate |
| Cost nivel 1 | Power 2,5K · Strength 2K · Cash 2K · Crew 3K · Rent 4K | la fel |
| Creștere cost | ×1,55 pe nivel | la fel |
| Nivel maxim | 10 / 20 / 30 (Rebirth 0 / 1 / 2+) | la fel |

### 4.4 Crew (muncitori)

| Muncitor | Preț | Viteză azi → propus |
|---|---|---|
| Laborer | 200 | 0,35 → **1,4** |
| Builder | 800 | 0,85 → **3,4** |
| Foreman | 6.000 | 0,6 → **2,4** (+20% la tot crew-ul, max 2) |

- **Fiecare angajat în plus costă ×1,3** (azi prețul e fix). Așa crew-ul rămâne o cumpărătură reală în fiecare zonă.
- Crew-ul ×4 e motivul principal pentru care jocul nu mai e un clicker obositor: de la tura 2 crew-ul face jumătate
  din muncă, de la tura 3 două treimi.

### 4.5 Utilaje

| Utilaj | Preț | Viteză azi → propus |
|---|---|---|
| Excavator | 2.500 | 3 → **4,5** |
| Mixer | 6.500 | 4 → **6** |
| Crane | 120.000 | 3 → **4,5** |

Upgrade-urile Mk rămân cum sunt (×2,2 pe Mk).

### 4.6 Proprietăți și bani offline

**Regula:**
- o unitate dintr-o clădire dă chirie cât 3% din ce câștigi construind clădirea respectivă;
- prima unitate se recuperează în **30 min** (online);
- fiecare unitate în plus costă **×1,45** (azi ×1,15), maxim 10 pe tip;
- la 10 unități, chiria e ×1,5;
- chiria primește și multiplicatorul de bani al Rebirth-ului;
- **offline: 50% din chirie, maxim 8 ore** (azi: 100%, fără limită);
- pass-ul nou **Night Shift: 100% și 12 ore**.

| Clădire | Prima unitate | Chirie / min online | Offline / min |
|---|---|---|---|
| Shed | 187 | 6 | 3 |
| Garage | 432 | 14 | 7 |
| House | 1,15K | 38 | 19 |
| Corner Shop | 2,67K | 89 | 45 |
| Villa | 10,1K | 336 | 168 |
| Warehouse | 20,3K | 678 | 339 |
| Apartments | 48,3K | 1,61K | 805 |
| Luxury Villa | 108K | 3,6K | 1,8K |
| Distribution Center | 244K | 8,14K | 4,07K |
| Office | 909K | 30,3K | 15,2K |
| Hotel | 2,31M | 77,1K | 38,6K |
| Skyscraper | 6,3M | 210K | 105K |
| HQ | 18M | 600K | 300K |
| Spire | 54M | 1,8M | 900K |

- Exemplul tău („1 milion pe o casă care să-ți facă 10K pe minut offline”) e aproape exact Office-ul: 909K, 15K pe minut
  offline. După Rebirth 2 (×4) dă 60K pe minut offline.
- **O noapte offline (8 h) valorează cam 15–60 de minute de joc**, în funcție de tură. E un motiv bun să revii a doua
  zi, dar nu mai poți face Rebirth fără să joci.
- Online, chiriile ajung la 15–30% din venit: o a doua sursă de bani, nu sursa principală.

### 4.7 Training Yard

| Stație (de la Strength) | Azi | Propus |
|---|---|---|
| 0 | ×3 | **×1** |
| 3K / 4K | ×8 | **×1,5** |
| 60K / 150K | ×20 | **×2,5** |
| 1M / 5M | ×50 | **×4** |

- Azi antrenamentul dă de 3–50 de ori mai mult Strength decât construcția, așa că jucătorul stă la sală în loc să
  construiască.
- Propus: antrenamentul e cam cât construcția (puțin mai bun mai târziu). E o opțiune pe lângă, nu o scurtătură care
  sare peste drum. Jucătorul activ tot antrenează ~15% din timp.
- **Auto Train** (pass-ul) primește în plus ×2 la antrenament, ca să nu pară că pierde valoare pentru cine l-a cumpărat.

### 4.8 Ciocane

- **Puterea crește ×2 pe raritate** (azi ×1,35):

  | Raritate | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Divine |
  |---|---|---|---|---|---|---|---|---|
  | Putere | ×1 | ×2 | ×4 | ×8 | ×16 | ×32 | ×64 | ×128 |

  Azi un Divine e doar ×8 față de Common. Un item de 1 în 25.000 trebuie să se simtă.
- Nivelurile rămân la +8% pe nivel (×1,72 la nivelul 10). Cooldown-urile pe raritate și gear-ul rămân la fel.

---

## 5. Lăzi, raritate și „1 în X”

### 5.1 Lăzile și șansele

Șansele apar în joc **ca „1 în X”**. Procentele exacte (care adună exact 100%, cum cere Roblox) sunt în butonul (i) de
pe fiecare ladă, înainte de cumpărare.

| Ladă | Preț | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Divine |
|---|---|---|---|---|---|---|---|---|---|
| Town Supply | 1,5 min din venitul tău | 75% · 1 în 1,3 | 20% · 1 în 5 | 4% · 1 în 25 | 1% · 1 în 100 | | | | |
| Suburbs Supply | la fel | 52% | 33% · 1 în 3 | 12% · 1 în 8 | 2,6% · 1 în 38 | 0,4% · **1 în 250** | | | |
| Downtown Supply | la fel | | 55% | 33% · 1 în 3 | 10,8% · 1 în 9 | 1,15% · 1 în 87 | 0,05% · **1 în 2.000** | | |
| Builder's | 200 💎 / 49 R$ | | 52% | 36% · 1 în 3 | 10% · 1 în 10 | 1,85% · 1 în 54 | 0,15% · 1 în 667 | | |
| Golden | 750 💎 / 149 R$ | | | 55,996% | 33% · 1 în 3 | 9,4% · 1 în 11 | 1,3% · 1 în 77 | 0,3% · **1 în 333** | 0,004% · **1 în 25.000** |

- **Lăzile urcă pe zone.** Supply-ul e altă ladă în fiecare zonă (Town / Suburbs / Downtown): mai scumpă, cu șanse mai
  bune. Prețul e de 1,5 minute din venitul tău, deci nu se mai poate exploata.
  - Azi prețul e 15% din recompensa de bază a celui mai bun contract și ajunge să coste câteva secunde de venit.
- **Doar unele lăzi dau topul:**

  | Raritate | Din ce lăzi |
  |---|---|
  | Legendary | din Suburbs în sus |
  | Mythic | Downtown Supply, Builder's, Golden |
  | Secret și Divine | **doar Golden** |
- Supply-ul gratuit la fiecare 6 contracte și Builder's-ul care pică 3% din contracte rămân.

### 5.2 Exclusive Crate: „1 în ???”

| Ciocan | Raritate | Șansă propusă | Azi |
|---|---|---|---|
| Royal Crown | Legendary | 75% | 65% |
| Ghost | Mythic | 22% | 27% |
| Rainbow Prism | Secret | 2,9% · 1 în 34 | 7% |
| Thunderclap | Exclusive | 0,1% · afișat **„1 în ???”** cu animație rainbow | 1% |

- Prețuri: **399 R$, 3 pentru 999 R$, 10 pentru 2.999 R$**.
- Procentul exact al Thunderclap-ului (0,1%) e în (i), înainte de plată.
  - **Atenție:** Roblox cere ca șansele să se vadă înainte de cumpărare. „???” e doar stilul afișării; butonul (i) cu
    procentul trebuie să stea chiar pe ladă, lângă butonul de cumpărare.
- Lada se deschide abia când Crown, Ghost și Prism au modele (azi sunt „soon”).

### 5.3 Reguli

- **Trade-up 10 → 1 doar până la Mythic** (10 Legendary → 1 Mythic e ultimul). Azi merge până la Divine: 10 Secret →
  1 Divine. Secret și Divine vin doar din lăzi și din trade între jucători.
- **Luck-ul se aplică doar la Legendary și mai rar.** Nu schimbă cât de des pică Common-urile.
- Fără pity, cu excepția primei lăzi deschise vreodată (rămâne ca azi).

### 5.4 Ce înseamnă pentru piață

**Ore de joc până la primul item:**

| Jucător | Legendary (azi → propus) | Mythic | Secret | Divine |
|---|---|---|---|---|
| activ, gratis | 1,8 → **5,3 h** | 9 → **28 h** | 72 → **~1.000 h** | 590 h → practic niciodată |
| plătitor | 1,1 → **2,2 h** | 4,6 → **13 h** | 27 → **156 h** | 184 h → foarte rar |
| whale | 0,4 → **0,6 h** | 1,4 → **3,2 h** | 6,5 → **17,5 h** | 36 h → **~1.300 h** |

**Câte există după 30 de zile, la 1.000 de jucători pe zi:**

| | Legendary | Mythic | Secret | Divine |
|---|---|---|---|---|
| Azi | 34.000 | 1.660 | 211 | 23 |
| Propus | **9.300** | **710** | **90** | **~1** |

- Un Divine pe lună la o mie de jucători pe zi: exact ca un Huge / Titanic în PS99. Cine îl are e celebru pe server, iar
  la trade valorează enorm.
- Un jucător activ gratis are în 14 ore de joc ~5 Legendary și un Mythic. Simte progresul, dar topul rămâne un vis.

---

## 6. Casca de constructor (Builder's Helmet)

Item nou, purtat pe cap (un singur slot). Se face în Company → Helmet, cu bani, materiale (care pică deja din contracte)
și, la ultimele niveluri, Gems.

| Nivel | Luck | Când | Cost |
|---|---|---|---|
| I | **+10%** | după Rebirth 1 | 50M + 25 Steel |
| II | **+25%** | după Rebirth 2 | 1B + 25 Copper |
| III | **+50%** | după Rebirth 3 | 20B + 25 Marble |
| IV | **+100%** | după Rebirth 4 | 100B + 20 Gold + 2.500 💎 |
| V | **+200%** | după Rebirth 5 | 600B + 10 Diamond + 10.000 💎 |

- Prețul în bani e cam un sfert din Rebirth-ul următor. Banii se pierd oricum la Rebirth, așa că o cască e locul
  perfect pentru banii de la finalul turei: fiecare nivel e obiectivul unei ture.
  - Numărul de materiale e de reglat după rata reală de drop, ca un nivel să ceară 1–2 ore de joc în zona lui.
- **Permanentă:** rămâne după Rebirth și nu se poate da la trade.
- Are model 3D pe cap, care se schimbă pe niveluri: galbenă → portocalie → argintie → aurie → diamant cu lumină. Toată
  lumea vede ce nivel ai.

**Cum se adună luck-ul:** se adună procentele, ca la PS99, nu se înmulțesc.

| Sursă | Luck |
|---|---|
| Casca V | +200% |
| Lucky Builder | +100% |
| Ultra Lucky | +200% |
| Poțiune 2x Luck (30 min) | +100% |
| Lucky Hour pe server | +100% |
| **Maxim, cu tot** | **×8** la Legendary și mai rar (Divine din Golden: 1 în ~5.500) |

- **Secret Hunter** (pass, 2.499 R$) înmulțește separat cu ×3 doar Secret și Divine.

---

## 7. Gems și Robux

### 7.1 Gems

- Din contracte: **1 + (numărul clădirii / 4), +1 dacă e construită rapid** (azi: numărul / 2). Puțin mai puține la
  clădirile mari.
- Un jucător activ gratis face **~270–320 💎 pe oră**, cu tot cu recompensele zilnice:
  - Builder's Crate (200 💎) ≈ 40 min de joc;
  - Golden Crate (750 💎) ≈ 2,5 h de joc.
- **Hammers of the Day:**

  | Ciocan | Azi | Propus |
  |---|---|---|
  | Epic | 2.500 💎 | **3.000 💎** |
  | Legendary | 12.000 💎 | **12.000 💎** |
  | Mythic | 40.000 💎 | **60.000 💎** |

  Mythic-ul costă cât îl costă în medie din Golden Crate (77 × 750 💎), dar e garantat.

### 7.2 Robux

**Game passes:**

| Pass | Azi | Propus | De ce |
|---|---|---|---|
| 2x Cash | 499 | 499 | |
| Auto Builder | 399 | 399 | lovește în locul tău, cam ca un jucător calm (în simulare: Rebirth 1 în 15 min stând AFK) |
| Super Strength | 349 | 349 | |
| 2x Gems | 299 | 299 | |
| Auto Train | 249 | 249 | + ×2 la antrenament (vezi 4.7) |
| Fast Hands | 199 | 199 | |
| Big Crew | 149 | **299** | crew-ul face acum 50–75% din muncă: valorează mult mai mult |
| VIP Builder | 199 | **399** | cât VIP-ul din PS99 (400) |
| Golden Supercar / Monster Truck / Teleporter / Skip Build Animation | 599 / 299 / 39 / 39 | la fel | |
| Thunderclap Hammer | 499 | **scos de la vânzare** | ciocanul e acum în Exclusive Crate, 1 în ???; cine are pass-ul îl păstrează |
| Lucky Builder | — (gata în cod, fără id) | **299** | +100% luck |
| Ultra Lucky | — | **899** | +200% luck |
| Secret Hunter | — | **2.499** | Secret și Divine ×3 (ca Huge Hunter din PS99) |
| Night Shift | — | **199** | offline 100% și 12 ore |
| Quick Open | — (gata în cod) | **99** | deschidere instantă |
| Auto Opener | — (gata în cod) | **199** | deschide singur toate lăzile |

**Produse (se cumpără de mai multe ori):**

| Produs | Azi | Propus |
|---|---|---|
| Starter Pack (o singură dată) | 99 | 99 = **600 💎 + 1 Golden Crate + 30 min 2x Cash** |
| Builder's Crate | 39 | **49 · 5 pentru 199** |
| Golden Crate | 149 · 3 pentru 399 (fără id) | **149 · 3 pentru 399 · 10 pentru 1.199** |
| Exclusive Crate | 399 · 3 pentru 999 (fără id) | **399 · 3 pentru 999 · 10 pentru 2.999** |
| 2x Luck (30 min) | — | **99** |
| Pachete de Gems, de bani (în minute de venit), 2x Cash 30 min, Rush Crew, Lucky Spins | | **rămân cum sunt** |

---

## 8. Ce conținut să adăugăm (în ordinea asta)

1. **Casca de constructor** (secțiunea 6): motiv de joc după fiecare Rebirth și primul item de luck.
2. **Exclusive Crate deschisă**: modele pentru Crown, Ghost, Prism; Thunderclap la 1 în ???.
3. **Ciocanele „soon” terminate**: Clockwork (Epic), Phoenix (Legendary), Void (Mythic), Black Hole și Demon King
   (Secret), Celestial (Divine). Fiecare raritate are nevoie de 3–4 ciocane, ca Index-ul să aibă ce colecta.
4. **Lucky Hour**: ×2 luck pe server, 15 minute la fiecare 3 ore, cu numărătoare pe ecran. E un motiv să rămâi online.
5. **Recompense de Index**: toate ciocanele unei rarități colectate → +5% luck permanent + Gems.
6. **Halloween Crate** (de pe ~15 octombrie până pe 2 noiembrie): 3 ciocane limitate, pentru Gems și Robux. Nu mai apar
   niciodată, deci au valoare la trade.
7. **Zona 4** (o hartă nouă) de la Rebirth 6. După Spire drumul se termină; un jucător activ ajunge acolo în ~15 h.

---

## 9. Cum am lucrat

- **Simulatorul** (`tools/econ/sim.py`) rejoacă jocul secundă cu secundă, cu formulele reale:
  - plata: recompensă × multiplicatori, +25% dacă e construit rapid;
  - puterea: ciocan × nivel × Strength;
  - crew-ul și utilajele pe verbele lor;
  - chiriile, lăzile, trade-up-ul, Gems.

  Jucătorul simulat face ce ar face un copil care vrea să avanseze: alege contractul care plătește cel mai bine, cumpără
  ce se recuperează cel mai repede, deschide lăzi, antrenează când o poartă îi stă în drum și dă Rebirth cât poate de
  repede.
- **4 jucători:**
  - activ: 5 click-uri pe secundă, 75% din timp;
  - casual: 4 click-uri, 45% din timp;
  - plătitor: 2x Cash, VIP, Super Strength și boost-uri;
  - whale: toate pass-urile și multe lăzi.
- **220 de scenarii:** 120 + 100 de combinații de parametri (viteza crew-ului și a utilajelor, multiplicatorii de Rebirth,
  chiriile, raritatea, upgrade-urile). Fiecare scenariu e calibrat și jucat de toți cei 4 jucători, apoi notat după cât
  de aproape e de rețeta jocurilor de top (ritm, cât face crew-ul, cât din venit vin chiriile, cât de des cumperi ceva).
  - Scenariul ales a ieșit **primul din 100** (scor 1,02, față de mediana 1,95).
- **Verificări la final:**
  - fiecare contract chiar e folosit (2 erau „morți” și au fost reparați);
  - 5 rulări cu noroc diferit la lăzi;
  - 4 obiceiuri de click: cine dă click doar 30% din timp merge de ~1,5 ori mai încet, ceea ce e normal;
  - un jucător AFK cu Auto Builder.
- Fișierele: `sim.py`, `proposal.py`, `sweep.py`, `final.py`, `road.py`, `report_final.py`, `avg.py`, `crates.py`,
  `sweep_A.json`, `sweep_B.json`, `final_econ.json` (toate cifrele exacte, inclusiv `workMult` pe contract).
- **Limită:** e un model. După lansare trebuie urmărite timpul real până la Rebirth 1 și 2 (mediana) și câte Legendary,
  Mythic, Secret și Divine apar pe zi. Ajustăm după primele 3–7 zile.

---

## 10. Cum s-ar implementa (DOAR după confirmarea ta)

1. **Config / Company:** contractele (muncă, porți, zone), costurile și multiplicatorii de Rebirth, crew, utilaje,
   upgrade-uri, Training Yard.
2. **Proprietăți:** prețuri, chirii, ×1,45, offline 50% / 8 h, Night Shift.
3. **Hammers:** ×2 pe raritate, șansele noi, prețul Supply în minute de venit, trade-up până la Mythic, „1 în X” în
   interfață, Exclusive „1 în ???” rainbow cu (i).
4. **Casca:** modul nou, interfață în Company, model 3D, luck adunat din toate sursele.
5. **Store:** pass-urile și produsele noi. Tu creezi id-urile în Creator Hub; eu le pun în Config.
6. **Jucătorii existenți:** nu ștergem progresul nimănui.
   - Ciocanele rămân, inclusiv Divine-urile de azi (vor valora și mai mult).
   - Proprietățile rămân la numărul de unități.
   - Toată lumea primește un cadou de update: 1 Golden Crate.
7. **Test în Studio** cu toți cei 4 jucători, X-ray-ul și țările cu restricție. Apoi îți spun să dai Publish.

---

## 11. Ce trebuie să confirmi

1. **Ritmul:** Rebirth 1 în ~19 min, Rebirth 2 la ~55 min, Rebirth 5 la ~8,5 h (jucător activ gratis). E bine?
2. **Offline:** 50%, maxim 8 ore (Night Shift: 100%, 12 ore)? Banii offline să conteze la Rebirth? (propunerea: da,
   fiind limitați)
3. **Șansele:** Divine 1 în 25.000 și Secret 1 în 333, doar în Golden Crate?
4. **Trade-up doar până la Mythic?**
5. **Training Yard redus** (×1 … ×4) și Auto Train cu ×2?
6. **Prețuri mărite:** VIP 199 → 399, Big Crew 149 → 299, Builder's Crate 39 → 49?
7. **Casca** cum e descrisă în secțiunea 6?
8. **Exclusive „1 în ???”** cu procentul în (i)?
9. **Jucătorii existenți:** fără ștergere, cu 1 Golden Crate cadou?
