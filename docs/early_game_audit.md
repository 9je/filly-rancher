# Early-game audit (2026-10-23, before the fun redesign)

From a read-only audit of the code. Times marked "est" are estimates for a normal player. Paths are relative to game/.

## Upgrades before the reveal
- **Gear:**
  - Bigger Saddlebag (120): bag 12 to 18.
  - Long Beam (200): reach +0.5 m.
  - Big Pen (150, holds 6), Grand Pen (480, holds 8). There is a free Paddock (3) and 4 plot slots.
  - Bloom stops at 6 or more per pen (bloom.gd CROWDED_AT), so the bigger pens block Blooms at full capacity.
- **Permits:** Orchard 150, Lake 300, Night Meadow 700, Everfree 1200. Each adds 450 upkeep, and each widens the named-pony pool.
- **The verb rule:** none of the 8 non-food upgrades changes how the player plays. The casino (the Strip) is always open, so it is never a beat.
- **After the reveal:**
  - Calm Lamp (the pen never Blooms).
  - Express Chute (the only automation).
  - Yield Lens (a pay multiplier only; its "shows grade" promise is not implemented).
  - Lure Post (DEAD: nothing reads it).
- **Food:** hay, carrot, apple, daisy, daffodil. Pens auto-feed from the pantry, the favorite first. Foods carry grow data, but no garden exists.

## Regions
- Homestead (free, 12 named), Orchard (7), Lake (8), Night Meadow (9), Everfree (7), and the Strip (the casino, no ponies).
- They differ only in their named-pony pools and phase/weather conditions. No region has its own mechanic or hazard.

## Ponies
- **Stock Drifters:** all common, hay favorite, speed 4 / stamina 1 / spirit 1. The generator rolls race, colours, name and mark talent, and all of it is cosmetic.
- **Named (43):**
  - Rarity sets gem price (5/12/30/100), delivery credit and catch difficulty.
  - Personality sets the catch window (shy 1.0, curious 0.5, bold 0.35), how she reacts, and Bloom friendships.
  - Speed, stamina and spirit matter only for racing.
- **Happiness** sets the gem rate: 1 gem per 200 s at zero, up to 1 per 20 s at full.
- **Bloom:** best case 360 s, base about 1080 s. It needs happiness of 0.45 or more, hunger of 0.75 or less, and fewer than 6 in the pen. A friend gives x1.6, a favorite meal x2.

## Story beats
- **Chapter thresholds:** chapter 1 (Act Two) starts at 3 deliveries.
- **Act One beats:**
  - arrival and Scoop (0-2 min)
  - Tumble (2-4)
  - Fennel's pen tutorial (4-8)
  - Bramble's first sale and Pip's first letter (5-10; a mild "cloud line" hint)
  - the Depot (8-15)
  - the first collection: "the rainbow got brighter" (12-20)
  - the Bloom hint (15-25)
- **Act Two clues** (wall of postcards, cloud line, dye names, Tumble and the crate, vivid bonus): est 20-30 min. That misses the 15-minute rule.
- **The invitation** needs 8 deliveries and 3 Blooms, est 35-50 min, then the next dawn adds up to 20 min. The reveal lands at est 45-70 min.
- Several letters need collection days 3 or 4, i.e. 3 to 4 hours in.

## Time and money
- **Clock:** a day is 1200 s (dawn 120, day 540, dusk 120, night 420). A collection day comes every 3 cycles (60 min), with a quota of 2.
- **Income:** a common pony makes about 8 bits per minute at default happiness. Every pre-reveal purchase is affordable within about the first hour, and income needs no player effort.

## Chores
- Not automated: catching, penning (one pony at a time), walking to the Depot for each delivery, and restocking food.
- Automated: feeding from the pantry, and gems folding into the pouch when the market opens.

## Grind walls
- The invitation (8 deliveries + 3 Blooms) is the main one; the Blooms' passive waiting is the bottleneck. Waiting for dawn adds more.

## The old driver
- scenes/test/playthrough.gd proves reachability and nothing else. It models no time, money, travel or purchases, so it cannot measure pacing.
