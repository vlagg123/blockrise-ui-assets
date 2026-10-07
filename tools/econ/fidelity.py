"""FIDELITY_V2: what the first simulator left out, read from the game in Studio (2026-10-07):
- Rebirth Stars (sqrt(run earned / 2.5M) per Rebirth) and the Star Shop perks (Tycoon +10% cash, Strong Genes +20% Strength,
  Property Lawyer +25% rent, Lucky Finds, Head Start 2,500 x 3^lv, Loyal Crew keeps workers) - RebirthService / Company
- Blueprints (premium contracts x1.5..x5 pay for x1.2..x2.2 work), found on 6% + 1.2% x order of contracts
- one-time cash (Empire Road steps + achievements) - in the recipe rescaled to ~8% of each of the first 5 Rebirths
- small extras: client tips (8% of a reward), rush orders, playtime gifts, daily missions, streak (~3%)
Usage: import fidelity; fidelity.apply(E)"""


def apply(E, onetime=0.08, extras=1.03, bp=0.46, stars=True, stars_new=True):
    E["stars"] = stars
    E["stars_new"] = stars_new
    E["bp_gain"] = bp
    E["onetime_frac"] = onetime
    E["pay_extra"] = extras
    return E
