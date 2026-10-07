# BlockRise Empire — Economia v5 (rețeta, 7 octombrie 2026)

Pornește de la economia v4 (`recipe.md`, implementată). Schimbările sunt cele cerute de tine între 14:06 și 15:54:
- Rebirth pe **cash în mână**, mai greu;
- **cutii gratis doar din misiuni**: cutiile pe Gems se dau doar la misiuni cu muncă cât pentru Gems-urile lor;
- **Road-ul și bucla** regândite;
- **ciocanele și cutiile noi** puse în calcul;
- piața de ciocane, banii și Gems-urile verificate **fiecare separat**.

Implementarea o face chatul de pe PC, după `ECONOMY_V5_PC.md` (lista exactă de lucru și verificările).

Tot ce e mai jos e măsurat în simulator (`tools/econ/`: `v5.py`, `v5_checks.py`, `v5_value.py`, `v5_market.py`,
`v5_gems.py`), cu 3–5 rulări pentru fiecare tip de jucător:

| Tip de jucător | Profil |
|---|---|
| activ | 2 h pe zi |
| casual | 45 min pe zi |
| plătitor | 2x Cash, VIP, 2x Strength |
| whale | toate pass-urile |

---

## 1. Pe scurt

| | v4 (azi) | v5 |
|---|---|---|
| Ce cere Rebirth-ul | bani câștigați în tură | **cash în mână ȘI câștigat de tine în tură** (banii primiți la trade nu contează) |
| Rebirth 1 / 2 / 3 / 4 / 5 | 25K / 250M / 20B / 150B / 800B | **150K / 600M / 25B / 150B / 1T**, apoi 4T, 10T, ×3 |
| Primul Rebirth (activ / casual) | 17 / 22 min | **30 / 37 min** |
| Rebirth 5 (activ / casual) | 8 h 49 / 11 h 06 | **12 h 40 / 15 h 16** |
| Cutii gratis | Supply la fiecare 6 contracte, Builder's la ~3% din contracte, cutii pe bara de Rebirth | **doar din misiuni**: cutia zilei, Builder's Order (zilnic), Golden Order (săptămânal), 5 pași din Road (o singură dată) |
| Kraken King (Divine, Pirate Cove) | 1 din 1.000 pentru 600 Gems | **1 din 25.000** (ca orice Divine din Golden) |
| Ciocane noi în joc pe zi | — | Uncommon–Epic **−55%**, Legendary −13% (−38% cu trade-up-urile), Mythic la fel, Secret / Divine +17% până se deschid cutiile noi, apoi −13% |

---

## 2. Rebirth-ul: cash în mână

### 2.1 Regula
- Poți da Rebirth când **cash-ul tău ≥ costul** ȘI **banii câștigați de tine în tura asta ≥ costul** ȘI ultima clădire a
  zonei e construită (ca azi).
  - **Câștigați de tine:**
    - contracte;
    - chirii (și offline);
    - Road și achievements;
    - misiuni;
    - pachetele de bani pe Robux;
    - Cash Bag / Cash Safe pe Gems.
  - **Nu intră:**
    - banii primiți la trade;
    - banii din vânzarea materialelor (altfel un jucător mare îi dă unuia mic 2 Diamonds = 160K și acela face Rebirth 1
      pe loc).
  - Pentru un jucător cinstit cele două sume sunt aproape egale, deci regula care se simte e „cash în mână”.
- **Banii se cheltuiesc la Rebirth.** Tura nouă pornește ca azi: banii de start, plus 1% din Rebirth-ul plătit, plus
  perk-ul Head Start.
- **Stars:** 3 + 2 × numărul Rebirth-ului, +1 pentru fiecare dublare a costului pe care o ai în momentul Rebirth-ului.

### 2.2 Costurile
150K · 600M · 25B · 150B · 1T · 4T · 10T, apoi ×3 la fiecare Rebirth (30T, 90T…).
- Calculate în simulator, astfel încât un jucător activ gratis să ajungă la Rebirth 1 / 2 / 3 / 4 / 5 în ~30 min / 1 h 30
  / 3 h 30 / 6 h 30 / 12 h 40.
- Rebirth 1 e de 6 ori mai scump decât în v4. Aveai dreptate: 25K era prea puțin.

### 2.3 Bara de Rebirth
- **Arată min(cash, câștigat) / cost**, cu textul „Rebirth needs $150K in cash — you have $92K”.
- Premiile de pe bară se plătesc la cel mai mare procent atins în tură, o singură dată. Bara poate coborî când cumperi,
  dar premiul nu se mai plătește a doua oară.
- Premiile devin fără cutii:

  | Treaptă | v4 | v5 |
  |---|---|---|
  | 1% | Supply Crate | 3 minute din venitul tău |
  | 5% | 10 Gems | 10 Gems |
  | 10% | Supply Crate | 15 Gems |
  | 25% | 20 Gems | 20 Gems |
  | 50% | Builder's Crate | 40 Gems |
  | 75% | 30 Gems | 30 Gems |

### 2.4 Avertismentul de economisire (obligatoriu)
- **De ce e obligatoriu.** Fără el, un copil care cumpără orice (la întâmplare, sau mereu cel mai ieftin lucru) face
  Rebirth 1 abia după 89–132 de minute, nu 37. Nu strânge niciodată.
- **Când apare.** După ce ultima clădire a zonei e construită, orice cumpărătură de cel puțin 5% din costul Rebirth-ului
  cere confirmare: „Saving for Rebirth: this sets it back by ≈ N min. Buy anyway?” (cu „don't ask again this run”).
- **AUTO BUY BEST** se oprește singur în modul ăsta, până îl repornește jucătorul.
- **Cu avertisment** (copilul ascultă 3 din 4 ori), cifrele măsurate sunt:

  | Copil care cumpără | Rebirth 1 | Rebirth 2 | Rebirth 3 |
  |---|---|---|---|
  | la întâmplare | 47 min (v4: 20) | 214 min (v4: 159) | 459 min (v4: 376) |
  | mereu cel mai ieftin | 46 min (v4: 21) | 160 min (v4: 65) | 297 min (v4: 156) |

### 2.5 Jucătorii de azi (migrare)
- Cine e în mijlocul unei ture păstrează procentul. Primește un **credit de Rebirth** = procentul din bara v4 × costul v5
  (maxim 95%). Creditul contează la ambele condiții, apare pe bară („saved before the update”) și se consumă la Rebirth.
  Nu se poate cheltui pe altceva.
- Clădirile construite vreodată rămân deschise (ca la v4).

---

## 3. Ritmul și bucla

### 3.1 Minute de joc continuu până la fiecare Rebirth (media pe 5 rulări)

| Jucător | | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|
| activ | v4 | 17 min | 49 min | 2 h 17 | 4 h 42 | 8 h 49 |
| | **v5** | **30 min** | **1 h 30** | **3 h 29** | **6 h 34** | **12 h 40** |
| casual | v4 | 22 min | 60 min | 2 h 52 | 5 h 52 | 11 h 06 |
| | **v5** | **37 min** | **1 h 51** | **4 h 19** | **7 h 34** | **15 h 16** |
| plătitor | v4 | 8 min | 25 min | 1 h 05 | 2 h 03 | 3 h 57 |
| | **v5** | **15 min** | **49 min** | **1 h 37** | **2 h 40** | **5 h 16** |
| whale | v4 | 6 min | 17 min | 40 min | 1 h 11 | 2 h 17 |
| | **v5** | **9 min** | **27 min** | **58 min** | **1 h 35** | **2 h 58** |

### 3.2 Pe zile: ziua în care vine fiecare Rebirth (o sesiune pe zi, noaptea offline)

| Jucător | v4 | v5 |
|---|---|---|
| casual, 20 min/zi | 1 · 3 · 6,5 · 12 · 18,5 | 2 · 5,5 · 8,5 · 13,5 · 24 |
| casual, 45 min/zi | 1 · 2 · 3 · 6,5 · 11 | 1 · 3 · 4,5 · 7,5 · 12,5 |
| activ, 45 min/zi | 1 · 2 · 3 · 6 · 9,5 | 1 · 2,5 · 5 · 7,5 · 11,5 |
| activ, 90 min/zi | 1 · 1 · 2 · 3,5 · 6 | 1 · 1,5 · 3 · 4 · 8 |

### 3.3 Cum se simte fiecare tură (jucător activ, v5)

| Tura | Durată | Contracte | O construcție | Partea ta din muncă | Din chirii | Cumpărături / min | Faza de strâns la final |
|---|---|---|---|---|---|---|---|
| 1 Town | 29 min | 30 | 29 s | 75% | 0% | 0,8 | 5 min (17%) |
| 2 Suburbs | 59 min | 81 | 19 s | 37% | 4% | 3,4 | 23 min (40%) |
| 3 Downtown | 1 h 51 | 121 | 30 s | 33% | 11% | 2,7 | 1 h 33 (83%) |
| 4 | 2 h 53 | 155 | 44 s | 24% | 11% | 1,9 | 2 h 13 (72%) |
| 5 | 5 h 48 | 202 | 83 s | 23% | 19% | 1,0 | 3 h 33 (64%) |

- **Suburbs are de 2 ori mai multă muncă pe clădire.** Tura 2 durează acum dublu față de v4. Cu munca din v4, jucătorul
  creștea peste Suburbs la jumătatea turei și o clădire ieșea în 9 secunde. Cu munca dublă, o clădire ține ~19 s.
- **Faza de strâns există și azi** (v4: 73% din tura 3). Spre finalul unei ture nu mai ai ce cumpăra care să se
  întoarcă la timp. În v5 faza asta are un scop vizibil:
  - bara de cash cu premiile ei;
  - misiunile zilnice și Builder's Order;
  - Golden Order;
  - Lucky Hour;
  - chiriile, care merg singure.

### 3.4 Bucla
Contracte (click + crew + utilaje) → **bani** → upgrade-uri, crew, utilaje, proprietăți (fiecare se întoarce în câteva
minute) → spre final **strângi cash** → **Rebirth**: bonus permanent de bani și Strength, Stars și o zonă nouă (sau o
clădire nouă în Downtown) → de la capăt, mai repede.

În paralel:
- contractele dau **Gems** → cutii pe Gems → **ciocane** (putere de construit) → trade cu alți jucători;
- **misiunile** dau cutii;
- Road-ul te duce prin toate cele de mai sus.

---

## 4. Cutiile gratis: doar din misiuni

### 4.1 Ce se scoate
- Supply Crate gratis la fiecare 6 contracte.
- Builder's Crate care pica din contracte (~3%, dublu cu Lucky Builder).
- Cutiile de pe bara de Rebirth (devin Gems / bani, vezi 2.3).
- Orice altă cutie gratis găsită de chatul de pe PC în export.
- Rămâne Supply-ul din tutorial (îl cumperi, cu banii tutorialului).

### 4.2 Misiunile cu cutii

| Misiune | Ce ceri | Premiu | Cât de des |
|---|---|---|---|
| Cutia zilei | toate cele 3 misiuni zilnice | 1 Supply Crate din zona ta | o dată pe zi |
| **Builder's Order** | construiești **100 / 75 / 55** contracte azi (Town / Suburbs / Downtown) | 1 Builder's Crate | o dată pe zi |
| **Golden Order** | construiești **480 / 365 / 260** contracte săptămâna asta **și** termini misiunile zilnice în 6 din 7 zile | 1 Golden Crate | o dată pe săptămână (luni, 00:00 UTC) |
| Road (o singură dată pe cont) | angajezi 2 muncitori · construiești Garage-ul · construiești Corner Shop · Rebirth 1 · Rebirth 2 | Builder's · Supply · Supply · Builder's · Golden | o dată |

**De ce cifrele astea** (`v5_value.py`): misiunea cere cam de 1,5–2 ori jocul de care ai avea nevoie ca să strângi Gems
pentru cutie. Nu e niciodată mai ieftin decât să o cumperi cu Gems:

| Zonă | Gems pe contract | 200 Gems = | Builder's Order | 750 Gems = | Golden Order |
|---|---|---|---|---|---|
| Town | 3,1 | 66 contracte (1 h) | 100 (1,5 h) | 246 (3,8 h) | 480 (~7 h) + 6 zile |
| Suburbs | 4,0 | 50 (0,6 h) | 75 (0,9 h) | 186 (2,3 h) | 365 (~4,5 h) + 6 zile |
| Downtown | 5,6 | 36 (0,9 h) | 55 (1,3 h) | 134 (3,2 h) | 260 (~6 h) + 6 zile |

**Pașii din Road** care dau cutii țin locul cutiilor gratis din prima tură. Fără ei, un jucător nou rămâne cu ciocane
Common până la Rebirth 1, iar Corner Shop-ul ține 4 minute de construit. Cu ei are un Rare pe la minutul 4, ca în v4.

**Țările unde Roblox nu permite cutii plătite** primesc aceleași misiuni. Cutiile cumpărate merg acolo ca azi (X-ray).

---

## 5. Piața ciocanelor

### 5.1 Ciocane intrate în joc pe zi, la 1.000 de jucători zilnici (primele 20 h ale fiecăruia, din cutii)

| | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Divine |
|---|---|---|---|---|---|---|---|
| v4 | 6.619 | 4.336 | 1.584 | 139 | ~9 | ~1,6 | ~0,02 |
| v5 | 2.793 | 2.068 | 760 | 121 | ~9 | ~1,9 | ~0,025 |
| v5 + cutiile noi deschise | 2.826 | 2.051 | 752 | 135 | ~6,5 | ~1,4 | ~0,02 |

(Mythic / Secret / Divine sunt prea rare pentru câteva rulări. Cifrele lor sunt calculate din numărul de Golden și
Builder's pe zi × șansele lor.)

- **Rarități mici −55%.** Erau aproape toate din cutiile gratis. Ciocanele obișnuite nu mai inundă inventarele.
- **Legendary −13% din cutii și −38% cu tot cu trade-up-uri** (10 → 1). Sunt mai puține de 10 ori la fel ca să urce.
- **Mythic rămâne la fel:**
  - în v4 ~1,8 Mythic pe zi veneau din Builder's-urile gratis;
  - în v5 vin din Golden Order.
- **Secret / Divine +17%** cât timp cutiile noi sunt „coming soon”. După ce se deschid, Gems-urile se împart și ies
  −13%.
- Chrono și Thunderclap rămân „1 in ???” (0,1% în cutia lor pe Robux, Secret garantat la 25 de cutii).

### 5.2 Cutiile și ciocanele noi
- **Kraken King** (Divine, Pirate Cove): **0,1% → 0,004%** (1 din 25.000). Restul de 0,096% trece la Treasure Chest
  (Legendary).
  - **De ce:** la 600 de Gems, 1 din 1.000 înseamnă un Divine de 31 de ori mai ieftin decât din Golden. La 10.000 de
    jucători ar fi ieșit ~16 Kraken King pe zi. Ar fi stricat piața de Divine și puterea: un Divine construiește ×128.
- **Norocul la cutiile noi**, ca la celelalte:
  - contează de la Legendary în sus;
  - pe Secret / Divine e plafonat la ×3, apoi × Secret Hunter.
- **Prețul cutiilor Pirate Cove / Jungle Temple pe Robux: 149 → 199 R$.**
  - Prin pachetul de 1.700 Gems, 600 de Gems costă ~211 R$.
  - La 149 R$, cumpărat direct ar fi fost cu 30% mai ieftin decât pe Gems.
  - Golden Crate are raportul 0,94; cu 199 R$ cutiile noi ajung tot la 0,94.
- **Colecții (setul complet).**
  - Cine are cele 3 ciocane mai ușoare ale unui set primește +5% noroc (ca o raritate completă din Index).
    - Pirate Cove: Anchor, Cannon, Treasure Chest.
    - Jungle Temple: Tiki, Stone Idol, Feathered Serpent.
    - Legends: Viking, Pharaoh, Aurora.
  - Cu tot setul primește un titlu: „Pirate King”, „Temple Guardian”, „Legend”.
  - Așa ciocanele din seturi au cerere la trade: lumea caută bucata care îi lipsește.

### 5.3 EXCLUSIVE_V2 (făcut între timp pe PC): problema și cele două variante
- **Ce s-a făcut pe PC:**
  - Exclusive e acum cea mai mare raritate, cu putere ×256 (peste Divine ×128).
  - Exclusive Crate dă 100% Exclusive, la 999 R$.
  - Exclusive of the Day se vinde direct, la 1.499 R$.
- **De ce strică piața.** Puterea crește cu raritatea, iar prețul trebuie să crească la fel. Prin Golden Crate (249 R$),
  în medie (`v5_exclusive.py`):

  | Raritate | Putere | Șansă | Cost mediu |
  |---|---|---|---|
  | Legendary | ×16 | 1 din 11 | ~2.600 R$ |
  | Mythic | ×32 | 1 din 77 | ~19.000 R$ |
  | Secret | ×64 | 1 din 333 | ~83.000 R$ |
  | Divine | ×128 | 1 din 25.000 | ~6,2 milioane R$ |
  | **Exclusive** | **×256** | **garantat** | **999 R$** |

  - Cel mai puternic ciocan din joc ar fi de ~6.000 de ori mai ieftin decât al doilea.
  - Divine-urile și Secret-urile nu mai valorează nimic la trade, pentru că oricine cumpără ceva mai bun cu 999 R$.
- **Ritmul**, cu un Exclusive cumpărat de la început:

  | Jucător | Rebirth 5 fără | Rebirth 5 cu Exclusive | Rebirth 3 fără | Rebirth 3 cu Exclusive |
  |---|---|---|---|---|
  | plătitor | 5 h 44 | **2 h 07** | | |
  | casual | | | 4 h 22 | 2 h 03 |

  Nu e o prăbușire (porțile de Strength și crew țin), dar e un pay-to-win mare.
- **Varianta A (recomandată):**
  - Exclusive rămâne cea mai rară raritate *de colecție*: insignă, secțiunea de sus din Index, efecte proprii, doar pe
    Robux.
  - Puterea e de Mythic (×32); Thunderclap, „1 în ???”, are puterea Secret (×64).
  - Divine rămâne cel mai puternic și se obține doar cu noroc.
  - Exclusive Crate 999 R$ și Exclusive of the Day 1.499 R$ rămân.
- **Varianta B:**
  - Exclusive rămâne ×256, dar nu se mai vinde garantat. Exclusive Crate revine la șanse: 75% Legendary / 22% Mythic /
    2,9% Secret / 0,1% Exclusive.
  - Exclusive of the Day se scoate.
- Alegi tu. Chatul de pe PC aplică varianta aleasă (`HANDOFF_PC.md`, 3.6).

---

## 6. Banii ($): de unde vin, unde se duc

| Sursă | Cât | Contează la Rebirth |
|---|---|---|
| Contractele | 80–100% din bani în primele ture, ~80% mai târziu | da |
| Chiriile (online și offline) | 0% în tura 1 → 11–19% din tura 3 | da |
| Road + achievements | ~8% din costul Rebirth-ului fiecărei ture | da |
| Pachetele de bani pe Robux / Cash Bag și Cash Safe pe Gems | minute din venitul tău | da |
| Vânzarea materialelor | mică | **nu** (îți dă cash, dar nu urcă bara) |
| Bani primiți la trade | | **nu** |

- **Unde se duc banii:**
  - upgrade-uri, crew, utilaje, proprietăți, gear;
  - Supply Crates;
  - căștile I–III;
  - **Rebirth-ul, cea mai mare cheltuială**: banii se plătesc.
- **Road + achievements:** sumele din v4 se înmulțesc ca să rămână ~8% din Rebirth-ul turei lor:

  | Unde | Factor |
  |---|---|
  | Town | ×6 |
  | Suburbs | ×2,4 |
  | Downtown (tura 3) | ×1,25 |
  | de acolo în sus | ×1 |

  Achievement-urile de 10K sau mai puțin (împărțite la 6 în v4) revin la valoarea dinainte.

---

## 7. Gems-urile: de unde vin, unde se duc

**Venit** (`v5_gems.py`), pe oră de joc:

| Jucător | Din contracte | Din lovituri | Din recompensele zilnice | Total |
|---|---|---|---|---|
| casual | ~205 | ~13 | ~105 | ~320 Gems/h |
| activ | ~215 | ~24 | ~40 | ~280 Gems/h |

| Ce cumperi cu Gems | Gems | Ore de joc (jucător gratis) |
|---|---|---|
| Builder's Crate | 200 | 0,7 |
| Golden Crate | 750 | ~2,5 |
| Pirate Cove / Jungle Temple | 600 | ~2 |
| Hammer of the Day Epic / Legendary / Mythic | 3K / 12K / 60K | 10 / 40 / 200 |
| Casca IV / V | 2,5K / 10K | 9 / 36 |

- Un Mythic din Hammer of the Day (60K) costă cam cât un Mythic din Golden-uri (~58K de Gems în medie). Corect.
- **Fără bucle.** Nu există drum de la bani la Gems și Gems-urile nu se dau la trade. Asta rămâne așa.
  - Lucky Spin: chatul de pe PC verifică că un spin nu dă în medie mai multe Gems decât costă.
- **Robux ↔ Gems** (pachetul de 1.700 Gems = 0,35 R$/Gem):

  | Cutie | Pe Gems | Direct pe Robux | Raport |
  |---|---|---|---|
  | Builder's Crate | ~70 R$ | 79 R$ | 1,12 |
  | Golden Crate | ~264 R$ | 249 R$ | 0,94 |
  | cutiile noi | ~211 R$ | 199 R$ (după schimbare) | 0,94 |

---

## 8. Empire Road v5

Road-ul urmează bucla. Fiecare capitol se termină cu „Strânge cash-ul → Rebirth”. Pașii cu sume plătesc în total ~8% din
Rebirth-ul capitolului; Gems 5–25 pe pas. Statisticile exacte le leagă chatul de pe PC de cele care există în joc.

**Tutorial** (cei 7 pași de azi, neschimbați): Supply Crate → gardul → mănușile → 10 repetări → Mini Excavator → un
Laborer → acasă.

**Capitolul 1 — Town (până la Rebirth 1, ~12K în total):**
1. Construiește Shed-ul.
2. **Angajează 2 muncitori → Builder's Crate.**
3. **Construiește Garage-ul → Supply Crate.**
4. Primul upgrade.
5. Construiește House-ul.
6. Prima proprietate (chirie).
7. Termină misiunile zilei.
8. **Construiește Corner Shop-ul → Supply Crate.**
9. Lifting Belt.
10. **Strânge $150K → Rebirth 1 → Builder's Crate.**

**Capitolul 2 — Suburbs (până la Rebirth 2, ~48M în total):**
1. Villa.
2. Concrete Mixer.
3. Crew de 4.
4. Un departament la nivelul 5.
5. Warehouse.
6. Primul Builder's Order.
7. Primul trade-up (10 → 1).
8. Apartments.
9. 3 feluri de proprietăți.
10. Luxury Villa.
11. O raritate completă în Index.
12. Distribution Center.
13. **Strânge $600M → Rebirth 2 → Golden Crate.**

**Capitolul 3 — Downtown (~2B):**
1. Office.
2. Casca I.
3. Crane.
4. Hotel.
5. Primul perk din Star Shop.
6. Primul Golden Order.
7. **Strânge $25B → Rebirth 3.**

**Apoi**, la fiecare Rebirth: noua clădire (Skyscraper, HQ, Spire), următoarea cască, „Strânge $X → Rebirth N”.

Cei care au trecut deja de un pas îl primesc bifat, fără premiu, inclusiv fără cutie: nimic nu se dă de două ori.

---

## 9. Pass-urile și produsele pe Robux (lista completă, cu schimbările v5)

Lista întreagă, cu nume, descriere, preț și id, e în `roblox/store_list_2026-10-07.md` (actualizată pe PC după
EXCLUSIVE_V2). **În v5 se schimbă doar:**

| Ce | Azi | v5 | De ce |
|---|---|---|---|
| Pirate Cove / Jungle Temple pe Robux | 149 R$ | **199 R$** (pe Gems tot 600) | pe Gems costă ~211 R$; acum raportul e ca la Golden (0,94) |
| Descrierea Pirate Cove | „Rare to Divine” | „Rare to Divine (Kraken King 1 in 25,000)” | noile șanse |
| Legends Crate pe Gems | 2.500 Gems | **12.000 Gems** (pe Robux tot 299 / 3 pentru 799) | vezi mai jos |
| Exclusive | ×256, 999 R$ garantat + Exclusive of the Day 1.499 R$ | varianta A sau B din 5.3 | 5.3 |

**De ce Legends Crate trece la 12.000 Gems.** Dă „Legendary sau mai bun”: Mythic 22%, Secret 3%.
- La 2.500 de Gems, un Mythic costă ~11.400 Gems. Din Golden costă ~58.000.
- Toată lumea ar trece pe Legends, iar Mythic-urile noi s-ar dubla pe piață.
- La 12.000 de Gems costă cât Hammer of the Day: Legendary. Cine dă atâția Gems pe o cutie „Legendary sau mai bun” nu
  pierde, iar Mythic-ul ajunge tot în jur de 55.000 de Gems.

**Rămâne la fel:**
- toate pass-urile;
- Starter Pack 99;
- pachetele de bani și de Gems;
- Golden 249 / 699 / 2.199, Builder's 79 / 349;
- 2x Luck 99, mașinile 299 / 599.

Hammer of the Day pe Robux (Epic / Legendary / Mythic) tot nu se creează.

---

## 10. Ce trebuie să confirmi
1. Rebirth pe cash în mână + câștigat de tine. Banii de la trade și din materiale nu urcă bara.
2. Costurile 150K / 600M / 25B / 150B / 1T / 4T / 10T, apoi ×3.
3. Avertismentul de economisire și AUTO BUY BEST care se oprește.
4. Cutii gratis doar din misiunile din 4.2 (cutia zilei, Builder's Order, Golden Order, 5 pași de Road).
5. Bara fără cutii (premiile din 2.3).
6. Suburbs cu muncă ×2.
7. Kraken King 1 din 25.000, cutiile noi la 199 R$, bonusul de colecție.
8. Legends Crate la 12.000 Gems.
9. **Exclusive: varianta A** (putere de Mythic; Thunderclap Secret) — aleasă, secțiunea 5.3.
10. Road-ul nou (secțiunea 8).
11. Migrarea (creditul de Rebirth).
