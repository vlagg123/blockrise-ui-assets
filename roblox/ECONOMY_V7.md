# BlockRise Empire: Economia V7 (14 octombrie 2026)

Refăcută de la zero, la cererea owner-ului, înainte de update-ul cu crate-urile noi și clădirile noi. Toate cifrele vin
din simulatorul nou `tools/econ/v7/sim7.py` + `proposal.py`, scris după codul **live** exportat din Studio azi
(`tools/econ/v7/live_2026-10-14.json`). Rulează `python3 cmp.py` în `tools/econ/v7` după orice schimbare.

## 1. Ce am găsit (auditul)

- **Bucla de azi = farm.** Un jucător activ construiește ~41 de clădiri în Town, ~40 în Suburbs și ~39 în Downtown
  până la Rebirth 3. Majoritatea sunt aceeași clădire de top (Corner Shop, Luxury Villa, Grand Hotel), doar pentru XP.
  Training Yard-ul e folosit ~4 minute din ~55.
- **Training Yard-ul nu merita:** Tire Flip dă ×1 Strength pe rep. Asta e aproape cât o lovitură de construcție, care
  mai dă și bani și XP. Nu exista niciun motiv să antrenezi.
- **Road-ul din Suburbs și Downtown plătea foarte mult** (300K → 9M, apoi 100M → 700M) față de ce plătesc clădirile
  acolo. Era calibrat pe vechiul Rebirth pe bani (V5).
- **Funnel-ul live** (ultimele 7 zile, 22 de jucători noi):
  - cea mai mare pierdere e la „Trained 10 reps” (31%);
  - apoi la „Tutorial complete”, adică vechiul pas „Visit your property” (29%).

  Pasul de proprietate l-am scos azi (tutorialul se termină acum la Training Yard).
- **Retenția:** D1 52% pe ultimele 7 zile, 104 min timp mediu de joc. Cine rămâne joacă mult, deci bucla lungă
  contează.
- **Ce n-am putut citi:** salvările jucătorilor (Data Stores). Accesul automat la ele a fost blocat. Dacă vrei analiza
  pe fiecare jucător (cine a revenit, unde a ajuns), îmi dai OK explicit și o fac.

## 2. Bucla nouă (V7)

**Construiești → antrenezi → următoarea clădire.**

- Fiecare zonă are acum **10 clădiri în ordine**: cele 5 de azi + 5 noi.
- **Fiecare clădire nouă se deschide doar după ce ai construit-o pe cea dinainte**, plus pragul ei de Strength și de
  crew.
- **Ultima clădire a zonei deschide Rebirth-ul:** Town Hall, Suburb Mall, City Stadium.
- **XP-ul celor 10 clădiri, fiecare construită o dată, dă exact nivelul Rebirth-ului** (12 / 35 / 55, neschimbate). Nu
  mai trebuie să faci de 20–30 de ori aceeași clădire. Nici nu poți sări peste ele: Rebirth-ul cere ultima clădire, iar
  ea le cere pe toate dinainte.
- **Strength-ul vine ca azi din construit, dar pragurile noi cer antrenament.** Stațiile din Training Yard dau acum de
  ~3 ori mai mult decât o lovitură de construcție:

  | Stație | Prag (neschimbat) | Strength pe rep: azi | Strength pe rep: V7 |
  |---|---|---|---|
  | Tire Flip | 0 | ×1 | **×2** |
  | Beam Lift | 4.000 | ×1,5 | **×4** |
  | Block Press | 150.000 | ×2,5 | **×8** |
  | Engine Hoist | 5.000.000 | ×4 | **×16** |

- **Timpul total rămâne același.** Simulatorul arată minute de joc de la primul join:

  | | R1 | R2 | R3 | R4 | R5 |
  |---|---|---|---|---|---|
  | Azi, jucător activ | 21,6 | 38,3 | 52,6 | 73,2 | 103,6 |
  | **V7, jucător activ** | **22,5** | **37,5** | **52,2** | **69,2** | **92,1** |
  | Azi, jucător casual | 32,1 | 53,6 | 72,9 | 100,9 | 140,8 |
  | **V7, jucător casual** | **30,3** | **48,4** | **66,1** | **86,2** | **113,6** |

- **Ce se schimbă în minutele astea:** construcții până la R3 (Town / Suburbs / Downtown):
  - azi: 41 / 40 / 39, aproape toate farm;
  - V7: 11 / 10 / 7, aproape toate clădiri noi.

  Antrenamentul crește de la ~4 la ~11 minute: e „train for your next building”, exact cum ai cerut.

## 3. Clădirile noi

Plata e cea de bază; Rebirth-ul o înmulțește ca azi (+150% per Rebirth). Munca e tunată pe simulator: prima construcție,
la prag, cu crew-ul cerut, ține ~60–100 s în Town, ~30–50 s în Suburbs și ~45–65 s în Downtown.

| Zona | Clădirea | Plată | XP | Crew | Strength | Munca totală |
|---|---|---|---|---|---|---|
| Town | Corner Bakery | $5.500 | 1.000 | 3 | 8.500 | 79,5K |
| Town | Car Wash | $7.300 | 1.700 | 4 | 16.000 | 130K |
| Town | Town Clinic | $9.600 | 2.900 | 4 | 40.000 | 288K |
| Town | Fire Station | $13.000 | 4.800 | 5 | 90.000 | 663K |
| Town | **Town Hall** (Rebirth 1) | $17.000 | 7.891 | 6 | 160.000 | 1,26M |
| Suburbs | Shopping Plaza | $750K | 15.000 | 6 | 5M | 34,6M |
| Suburbs | Sports Arena | $1,1M | 24.000 | 7 | 10M | 64M |
| Suburbs | Hospital | $1,6M | 39.000 | 7 | 24M | 128M |
| Suburbs | Water Park | $2,3M | 64.000 | 8 | 40M | 205M |
| Suburbs | **Suburb Mall** (Rebirth 2) | $3,3M | 103.394 | 8 | 62M | 386M |
| Downtown | Bank Tower | $6,1M | 37.000 | 8 | 100M | 653M |
| Downtown | Concert Hall | $8,2M | 59.000 | 9 | 130M | 941M |
| Downtown | City Museum | $11M | 91.000 | 9 | 180M | 1,32B |
| Downtown | Twin Towers | $15M | 140.000 | 10 | 230M | 1,74B |
| Downtown | **City Stadium** (Rebirth 3) | $20M | 226.520 | 10 | 290M | 2,27B |

- **Verificarea XP-ului:** clădirile din Town, fiecare o dată, dau 19.411 XP, adică exact nivelul 12. Suburbs dă 267.394
  XP (12 → 35), Downtown 592.520 XP (35 → 55).
- **Skyscraper / HQ / Spire** (R3 / R4 / R5) rămân până la update-ul cu Deșertul. Pragurile lor de Strength cresc la
  1B / 2,5B / 8B. Altfel XP-ul de la City Stadium ar fi scurtat R4 și R5.

## 4. Crate-urile

| Unde | Crate | Preț | Se deblochează |
|---|---|---|---|
| Shop, pe bani ($) | Town Supply Crate | **$150** fix | de la început |
| | Suburbs Supply Crate | **$88.000** fix | **Rebirth 1** |
| | Downtown Supply Crate | **$16.000.000** fix | **Rebirth 2** |
| Shop, doar pe Gems | Builder's Crate | 200 💎 | — |
| | Pirate Cove / Jungle Temple | 600 💎 | — |
| | Golden Crate | 750 💎 | — |
| | Legends Crate | 3.000 💎 | — |
| Store, doar pe Robux | Exclusive Crate | 999 R$ (3 = 2.699) | — |
| | **Divine Crate (nou)** | **1.499 R$ (3 = 3.999)** | — |

- **Crate-urile de zonă:**
  - costă fix: ~2,5 construcții ale primei clădiri când intri în zonă și ~1–5% dintr-o construcție la final, deci le
    deschizi în serie;
  - un crate de zonă deblocat rămâne de cumpărat și după ce treci mai departe;
  - cele blocate arată „🔒 Unlocks at Rebirth N”.
- **Crate-urile pe Gems:** nu se mai vând direct pe Robux în Store. Robux-ii cumpără Gems.
- **Divine Crate:**
  - **Ce dă:** Mythic sau mai bun, din ciocanele normale: Mythic 82%, Secret 15%, Divine 3%.
  - **Pity:** Divine garantat la fiecare 30 de crate-uri.
  - **Rolul lui:** crate-ul de „putere”. Exclusive Crate rămâne cel de colecție (exclusivele).
- **În Shop, la Crates:** un banner „EXCLUSIVE & DIVINE CRATES”, cu buton spre Store.

## 5. Empire Road V7

- **Tutorialul:** cei 7 pași rămân (pasul 7 e acum Training Yard).
- **Apoi câte un capitol pe zonă, de-a lungul lanțului:**
  - fiecare clădire nouă e un pas;
  - între ei sunt câțiva pași de-o parte, ca azi.
- **Banii:**
  - **Town:** ~1 construcție pe pas, ~44K pe tot capitolul.
  - **Suburbs și Downtown:** pașii de azi își păstrează banii (ajută la recumpărarea gear-ului și a crew-ului după
    Rebirth). Clădirile noi dau ~2 construcții.
- **Pasul „Golden Order”** e săptămânal, deci l-am mutat după City Stadium, ca să nu blocheze capitolul o săptămână.
- **După Rebirth 3:** pașii de azi.
- Lista completă e în `tools/econ/v7/v7_road.json`.

## 6. Migrarea (fără reset, regula owner-ului)

- **Clădirile construite rămân construite.**
- **Ordinea nouă** (o clădire cere clădirea dinainte) se aplică doar celor 15 clădiri noi. Clădirile vechi rămân cum
  sunt.
- **Cine era deja gata de Rebirth pe vechea regulă** (nivelul + clădirea de top veche) își păstrează Rebirth-ul o dată.
  Nu-i luăm ce avea deschis.
- **Empire Road:** pozițiile se mapează pe lista nouă după (stat, target). Pașii deja făcuți trec fără să plătească a
  doua oară.
