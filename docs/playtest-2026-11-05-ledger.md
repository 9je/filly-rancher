# Playtest 2026-11-05 ledger

One row per item of docs/playtest-2026-11-05.md (the owner's words as recorded there), plus the known
gaps (M, G1 to G12). States: OPEN, FIXED-UNREVIEWED (fixed, evidence looked at by me), MET and
NOT-MET (set only by the PS13 acceptance reviewer). A row moves only with evidence: a test name
and/or render paths under build/ps_evidence/. Checked by game/test/test_ledger_complete.gd.

Liked and kept (checked in PS6): the rare capture neigh; the half-lidded look (67); the game overall.

| Item | Owner's words | Shots | Task | State | Evidence | Commit | Judged by |
|---|---|---|---|---|---|---|---|
| 1 | Fullscreen set during loading snaps back small on ranch load (ranch.gd apply_graphics -> apply_window forces the saved mode). | -- | PS6 | OPEN |  |  |  |
| 2 | A Random button in the pony creator. | -- | PS7 | OPEN |  |  |  |
| 3 | Better cutie mark creation. | -- | PS7 | OPEN |  |  |  |
| 4 | Mane style isn't under the "Mane and tail" tab. | -- | PS7 | OPEN |  |  |  |
| 5 | The mane streak option is always shown though it's rarely used. | -- | PS7 | OPEN |  |  |  |
| 6 | More customisation. | -- | PS7 | OPEN |  |  |  |
| 7 | Creator: spinning the pony makes the mane fly spiky and the tail clip the body (hair springs react to the spin). | -- | PS1 | OPEN |  |  |  |
| 8 | The welcome letter: a text wall, empty right side, "Enter close" plus Close. | -- | PS6 | OPEN |  |  |  |
| 9 | Player tail stutters between frames while walking. | -- | PS1 | OPEN |  |  |  |
| 10 | A pony walked through the conversation. | -- | PS1 | OPEN |  |  |  |
| 11 | Pip's "Rainbow Factory / cloud line's for staff only" line is confusing. | -- | PS8 | OPEN |  |  |  |
| 12 | Can't pause during a conversation. | -- | PS6 | OPEN |  |  |  |
| 13 | Tumble spawned mid-conversation, inside the player. | -- | PS1 | OPEN |  |  |  |
| 14 | Signs flicker on and off almost everywhere (the fingerpost's Home and Pens boards go dark; PlaceSign blocking-fade toggling) [32]. | [32] | PS4 | OPEN |  |  |  |
| 15 | Old Fennel says there's a pony in the bag when there isn't. | -- | PS3 | OPEN |  |  |  |
| 16 | The start doesn't show where to go for a first catch; after that, catchable ponies are clear. | -- | PS8 | OPEN |  |  |  |
| 17 | Twilight twisted at a broken angle, twice [21][52]. Likely retarget/HoofPlanter on the Mane Six rig. TOP PRIORITY. | [21] [52] | PS1 | FIXED-UNREVIEWED | Two causes, both fixed. (1) The borrowed graze/sleep folded the Mane Six head joint 66 deg: test_mane_six_neck; before/after build/ps_evidence/item17/neck_tries.png. (2) [52] is the corner heap of item 65 (Twilight is curious): test_pen_spread, test_pony.test_a_curious_resident_turns_to_watch_her_farmer_and_stays_put; build/ps_evidence/item65/corner_compare.png. Body roll measured never above 3.1 deg (scenes/test/twist_probe.gd) |  |  |
| 17b | Ponies merge into each other (wild vs wild, a brown pony inside a purple one) [19][54]. | [19] [54] | PS1 | OPEN |  |  |  |
| 18 | Tumble gets in the way at catch time: in front of the camera, and her talk prompt steals E. | -- | PS8 | OPEN |  |  |  |
| 19/23 | The rump bounce is barely seen: it only fires on a pen flop or a hard landing, and ponies land facing you in the paddock. | -- | PS1 | OPEN |  |  |  |
| 20 | Text is too thick: heavy outlined lettering on cards and the HUD [22]. | [22] | PS6 | OPEN |  |  |  |
| 21 | Dropping a pony from the beam at height should trigger the rump bounce; it doesn't. | -- | PS1 | OPEN |  |  |  |
| 22 | Catch card covers the checklist strip; the strip still shows a sentence, not chips [22]. | [22] | PS6 | OPEN |  |  |  |
| 24 | Objective card lands on top of the "Getting started" chips [23]. | [23] | PS6 | OPEN |  |  |  |
| 25 | The overgrown-plot brambles are a field of big green blobs [24]. | [24] | PS4 | OPEN |  |  |  |
| 26 | "CLEAR ME / 250 bits" signs: dark on brown, no light backing, unreadable [24]. | [24] | PS4 | OPEN |  |  |  |
| 27 | A flat yellow blob prop on the grass, unidentified [25]. | [25] | PS4 | OPEN |  |  |  |
| 28 | Old Fennel's lines read weird ("come to themselves", "Mark comes right up on the flank"). | -- | PS8 | OPEN |  |  |  |
| 29 | Doors far too small next to buildings everywhere (Market, Depot); oversized porches and ramps [27][31]. | [27] [31] | PS4 | OPEN |  |  |  |
| 30 | EVERY menu: drop the key hints, one Back button (not Close plus Esc), a real scroll bar. Compendium: "The Strip 0 of 0", bare "???" rows [28]. | [28] | PS6 | OPEN |  |  |  |
| 31 | The camera passes into the Market; you see the hollow shell from inside [29]. | [29] | PS2 | OPEN |  |  |  |
| 32 | Barn yard: barn on a tall plinth, oversized ramp, mismatched shed, wagon, hay and seed bag scale, scattered [30]. | [30] | PS4 | OPEN |  |  |  |
| 33 | Delivering ponies went against the debt when the owner expected pay; the debt isn't explained. | -- | PS9 | OPEN |  |  |  |
| 34 | You can't tell which ponies aren't catchable (townsfolk). | -- | PS8 | OPEN |  |  |  |
| 35 | Spike just sits there with no clear purpose. | -- | PS8 | OPEN |  |  |  |
| 36 | Ponyville row: houses lean and sink into the slope, lamp posts lean, no streets or yards, grey road meets dirt road badly [33]. | [33] | PS4 | OPEN |  |  |  |
| 37 | The Strip: tilted arcade machines on a grey slab, a floating track, leaning lamps, dirt road painted across the pavement [34]. | [34] | PS4 | OPEN |  |  |  |
| 38 | Tumble's "over to the south-east" means nothing; sightings should light the compass or trail (couldn't find Octavia). | -- | PS8 | OPEN |  |  |  |
| 39 | Two of the same named pony at once (two Sweetie Belles, two Scootaloos). | -- | PS3 | OPEN | partial, not closing: test_old_save_loads (an escapee home on a load counts as owned) |  |  |
| 40 | Rain too heavy to see through; it looks cheap (falling rectangles); night plus rain is very dark [45]. | [45] | PS4 | OPEN |  |  |  |
| 41 | You can walk into the Depot; walls have no collision, and it rains inside [35]. | [35] | PS2 | OPEN |  |  |  |
| 42 | A toast as one giant full-width line, overlapping the objective card [36]. | [36] | PS6 | OPEN |  |  |  |
| 43 | A townspony stuck half inside the Palace plinth wall [37]. | [37] | PS2 | OPEN |  |  |  |
| 44 | Casino patrons frozen in place [38]. | [38] | PS5 | OPEN |  |  |  |
| 45 | The Wheel rebuilt like Rust's Bandit Camp wheel: one wheel, payout tiers 1x/3x/5x/10x/20x, high tiers rarer, bet on a tier. Drop the Colour and Number tabs. Fix the clipped rules box and the empty lower half [39]. | [39] | PS5 | OPEN |  |  |  |
| 46 | All casino games: no text log under the game (no "=====" rows); the reels and a win flash tell it. Symbols clip their windows; the paytable line is cut off; a real lever; bigger chips; a spin button [40]. | [40] | PS5 | OPEN |  |  |  |
| 47 | Slots: every reel window shows the result symbol three times stacked [40][42]. | [40] [42] | PS5 | OPEN |  |  |  |
| 48 | Blackjack plays itself: no Hit/Stand/Double/Split. Dealer labelled "stand" after busting. Banner text overflows its box [41]. | [41] | PS5 | OPEN |  |  |  |
| 49 | Slots: can't change the bet off 10 (the 50 and 200 chips do nothing) [42]. | [42] | PS5 | OPEN |  |  |  |
| 50 | The Rainbow Factory hints (the yield letter, the Mayor) are too on the nose, too early. | -- | PS8 | OPEN |  |  |  |
| 51 | Clicking the mailbox opens "Saddlebag Copies"; the survey says "answer below" with no way to answer; the letter text has a heavy outline and is hard to read [44]. | [44] | PS6 | OPEN |  |  |  |
| 52 | The Market buy screen is easy to miss; buying food is fiddly, so feeding feels not worth it. | -- | PS9 | OPEN |  |  |  |
| 53 | The trail keeps pointing to the paddock after you've upgraded it ("0/2") [45]. | [45] | PS3 | OPEN |  |  |  |
| 54 | Far ponies have no eyes until close; eyes change shape between far and near [53][54]. | [53] [54] | PS1 | OPEN |  |  |  |
| 55 | Buying the Orchard felt pointless (no rares seen). Each area should show its ponies and their times before you buy, and give a guaranteed rare when it opens. | -- | PS9 | OPEN |  |  |  |
| 56a | The coat stallion: the dialogue says coat but there's no coat on the model. | -- | PS8 | OPEN |  |  |  |
| 56b | The coat stallion should be a mysterious walk-by, not a slow shuffle up to you. | -- | PS8 | OPEN |  |  |  |
| 57 | A pony hidden inside a haystack: give hiding a tell, or don't spawn inside props. | -- | PS2 | OPEN |  |  |  |
| 58 | Tumble gets stuck on the Orchard fence. | -- | PS2 | OPEN |  |  |  |
| 59 | Toasts and companion lines vanish too fast, and pausing clears them. | -- | PS6 | OPEN |  |  |  |
| 60 | The saddlebag pips run off the card at 18 slots [47]. | [47] | PS6 | OPEN |  |  |  |
| 61 | Lake: ponies and the player walk under the water; ponies half sunk; grass shows through; no banks [48][49]. | [48] [49] | PS2 | OPEN |  |  |  |
| 62 | Depot statement: "Quota 31 of 2", still "cycle 1" and "collections passed 0" after a long session [50]. | [50] | PS3 | OPEN |  |  |  |
| 63 | Duplicates and everyone tagged "one of a kind" in the Deliver list [51]. | [51] | PS3 | OPEN | partial, not closing: test_old_save_loads (an escapee home on a load counts as owned) |  |  |
| 64 | Feeding is automatic from the pantry, and nothing says so; show the pantry stock and the hungry state. | -- | PS9 | OPEN |  |  |  |
| 65 | Full pen: ponies pile in one corner, overlap, push through the fence; "moved into the pen" while the prompt says the pen is full [52]. | [52] | PS1 | FIXED-UNREVIEWED | Corner heap reproduced (player at a corner; curious residents walked to the rails and heaped) and fixed: residents turn to watch instead. test_pen_spread (no one past the rails, no persistent overlap, herd not in a corner, nobody walking to the farmer), test_pony.test_a_curious_resident_turns_to_watch_her_farmer_and_stays_put, test_ranch_penning.test_the_pony_that_fills_the_pen_is_told_it_is_now_full; before/after build/ps_evidence/item65/corner_compare.png. Not changed: eight ponies in a 7.8 m Grand Pen still read as crowded (every tier is the same size); a bigger pen per tier would be a layout change |  |  |
| 66 | The compass strip: better icons, distances, N/E/S/W, a clear goal marker. | -- | PS6 | OPEN |  |  |  |
| 67 | The half-lidded "looking at you" eyes switch off as you get close (backwards). The owner LIKED them: keep them, make them deliberate and shared by more ponies. | -- | PS1 | OPEN |  |  |  |
| 68 | SOFT-LOCK: walked into the Depot, fell out, stuck, couldn't move or get up [55]. Needs an unstuck (and the collision fix in 41). | [55] | PS2 | OPEN |  |  |  |
| 69 | Catching is too easy (all but the toughest) and repetitive; 49 deliveries came fast; ~800 gems per Market trip mid-game. Pacing and difficulty need a pass. | -- | PS9 | OPEN |  |  |  |
| 70 | Ponies escaping fully upgraded pens. The owner had every pen at its highest tier and still saw escapes, with repeats in the wild. In code, only the Paddock (pen_small) lets an Escape Artist out at night (ranch._escape_artists, PonyTraits.escapes_from). Check: (a) does the upgraded tier survive save and load, or does contents revert to pen_small; (b) does anything else free penned ponies (the night pen, the Depot cart, the full-pen "moved into the pen" path in 65); (c) the upgrade flow itself (53, stuck "0/2"). The spawner also lets an owned pony spawn again (only on-map dupes are blocked), so decide whether to block owned repeats. Failing test first. | -- | PS3 | OPEN | partial, not closing: test_old_save_loads (an escapee home on a load counts as owned) |  |  |
| M | Marigold walks in front of the camera when she greets you (known gap, 2026-11-06). | -- | PS8 | OPEN |  |  |  |
| G1 | FS1.4: hovering a lesson chip shows its sentence as a tooltip. | -- | PS10 | OPEN |  |  |  |
| G2 | FS2.2: the ground's fine painted grain, darker grass at prop and fence bases. | -- | PS10 | OPEN |  |  |  |
| G3 | FS3.1: a hungry pony is SAD (with item 64). | -- | PS10 | OPEN |  |  |  |
| G4 | FS4.3: a stumble when the player lands hard. | -- | PS10 | OPEN |  |  |  |
| G5 | FS5.2: Market and Depot music contexts; the duck at 4 dB. | -- | PS10 | OPEN |  |  |  |
| G6 | FS6.1: tiles stagger in 30 ms apart; a purchase flies a coin to the wallet. | -- | PS10 | OPEN |  |  |  |
| G7 | FS6.2: the Depot pays out per tile with a counter sound; the total lands on the balance. | -- | PS10 | OPEN |  |  |  |
| G8 | FS8.3: rarity shapes on the Depot tiles. | -- | PS10 | OPEN |  |  |  |
| G9 | FS5.1: hoof loudness measured in the 3D mix against the beds. | -- | PS10 | OPEN |  |  |  |
| G10 | The real-input batch: loading, pen_upgrade and sprint fail in a full batch but pass alone. | -- | PS11 | OPEN |  |  |  |
| G11 | 60-pony performance: p99 frame time at or under 16.6 ms. | -- | PS11 | OPEN |  |  |  |
| G12 | Proton smoke run of the Windows build. | -- | PS11 | OPEN |  |  |  |
