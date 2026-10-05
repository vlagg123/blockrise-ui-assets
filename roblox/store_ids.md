# Config.Store ids (set in Studio, 2026-10-06)

Developer products (all checked with GetProductInfo: name, price and IsForSale = true)

| key | name | id | R$ |
|---|---|---|---|
| gems12000 | 12,000 Gems | 3716763699 | 3299 |
| gems4500 | 4,500 Gems | 3716763662 | 1399 |
| gems1700 | 1,700 Gems | 3716763636 | 599 |
| gems750 | 750 Gems | 3716763584 | 299 |
| gems300 | 300 Gems | 3716763532 | 129 |
| gems100 | 100 Gems | 3716763502 | 49 |
| cashboost | 2x Cash (30 min) | 3716763463 | 79 |
| cashbank | Cash Empire | 3716763439 | 699 |
| cashvault | Cash Vault | 3716763403 | 199 |
| cashstack | Cash Stack | 3716763367 | 49 |
| spins3 | 5 Lucky Spins | 3716763333 | 79 |
| spin1 | 1 Lucky Spin | 3716763310 | 19 |
| starter | Starter Pack | 3716763280 | 99 |
| cashpack | Contractor's Bonus | 3716559383 | 99 |
| rushcrew | Rush Crew (15 min) | 3716559252 | 49 |

Game passes (all checked with GetProductInfo: name, price and IsForSale = true)

| key | name | id | R$ |
|---|---|---|---|
| goldcar | Golden Supercar | 2004543731 | 599 |
| cash2x | 2x Cash | 2007039661 | 499 |
| stormhammer | Thunderclap Hammer | 2005029676 | 499 |
| autobuild | Auto Builder | 2006325688 | 399 |
| strength2x | Super Strength | 2005677672 | 349 |
| monster | Monster Truck | 2005731685 | 299 |
| gems2x | 2x Gems | 2007015623 | 299 |
| autotrain | Auto Train | 2005389593 | 249 |
| fasttools | Fast Hands | 2006841703 | 199 |
| teleporter | Teleporter | 2005785662 | 39 |
| skipanim | Skip Build Animation | 2008436250 | 39 |
| bigcrew | Big Crew | 2006613370 | 149 |
| vip | VIP Builder | 2005131359 | 199 |

Tested in Studio (Play, CE_Debug hooks): every pass grants its effect; every product grants once (a repeated receipt is not
granted twice); after a progress reset the ledger gives back Gems, spins, 2x Cash time, the Starter Pack flag and Rush Crew time.
