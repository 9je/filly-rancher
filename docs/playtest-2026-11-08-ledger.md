# Ledger, playtest 2026-11-08 (P8)

The only source of item status (sprint plan, rule 9). Owner words: docs/playtest-2026-11-08.md
and the session transcript; screenshots in the playtest doc's folder. Status: OPEN, FIXED
(evidence linked, awaiting acceptance), MET or NOT-MET (Fable acceptance).

| # | Batch | Item (owner's report) | Situation to reproduce | Status | Evidence |
|---|---|---|---|---|---|
| 1 | S1 | SOFT-LOCK: at the Color Day reveal, picking "Give me a minute" in Marigold's lift talk leaves her saying only her generic line ("Every pony has a color!"). The lift choice never comes back, so the story cannot finish [100][101]. dialogue_src/act2.txt `wait` branch. | Owner's save at Color Day; chose 'Give me a minute' then talked again | FIXED | test_dialogue_graph (static walk of every story talk; also fixed the Jubilee and Static lifts) |
| 2 | S2 | Bloom is far too slow and has no visible state. 4 Drifters in an uncrowded, fed pen took about 25 min to give the first Bloom. Pens of 7 or more freeze Bloom silently (bloom.gd CROWDED_AT 7, but a Grand pen holds 8), and the owner's pens were packed. No meter, no reason shown ("too crowded"), no hint of what helps [75][79][86][87][93]. | 4 Drifters, fed, uncrowded; and packed pens of 7-8 | FIXED | agent S2: test_bloom, test_pen_bloom; renders shots/bloom3/* |
| 3 | S1 | Autosave only fires on house visits, so the last save on disk was 1.5 h old mid-session. A crash would have lost it all. |  | FIXED | agent S2: test_ranch_days (sleep saves; autosave every 5 min) |
| 4 | S2 | The 5,000 "principal floor" (ledger.gd PRINCIPAL_FLOOR) is never explained. The Pay tab says "Nothing to settle"; after 75 deliveries it reads as a grind trap. The owner had to sell rares to clear it and would rather the game had openly made them do that as a beat [84][85]. |  | FIXED | agent S2: quota card on the Pay tab; test_ledger, test_depot_menu; render shots/depot/colour_pay_quota.png |
| 5 | S2 | Clearing the debt does nothing: "-200 owed" in red, rows still show "-480 debt", no scene, no "what's next". The owner thought it was the end [85]. |  | FIXED | debt_cleared flag + Marigold talk (agent) + F5 beat on camera (main) |
| 6 | S2 | The economy is far too fast for the story: a full set of legendaries and the debt cleared in about 1 h, inside one in-game day. The "first collection day" letter that explains the rules arrived after the debt was paid [90]. |  | FIXED | account closes only on a collection day; rares gated (agent); test_ranch_days |
| 7 | S9 | Rare ponies were taken (probably collection-day quota) with no on-screen moment, only letters afterwards. It wants a Collectors cinematic. Check whether the special pony picked at the start is protected [no shot]. |  | FIXED | dawn cart takes only Bloomed Drifters + cart cinematic; test_ranch_days cart rule |
| 8 | S2 | The point of keeping and Blooming generic ponies is unclear: nothing shows what a bloomed pony gives (gems, value, a job, the Rescue path). Slime Rancher reference. |  | FIXED | colour loop: only Bloomed ponies count and pay (agent) |
| 9 | S2 | Drifter / marked crowd / named ponies cannot be told apart in the world or at the Depot; you cannot tell what is safe to sell. The Depot sells Drifters in one press even while the Bloom goal needs them. |  | FIXED | agent: Drifter words in crosshair, catch card, Depot tags; test_drifter_words |
| 10 | S2 | Pantry food does not obviously reach the pens; nothing shows a Drifter's favourite food or whether her feeder is stocked [79]. |  | FIXED | agent: favourite on pen readout and card |
| 11 | S2 | Late game is empty after the debt and the legendaries; there is no sleep / skip to dawn. |  | FIXED | agent: sleep till dawn |
| 12 | S2 | The rare-pony sighting event is too frequent and naggy (happenings.gd: every 7 min after minute 13; trails pile up). |  | FIXED | agent: rare_gate, 2 sightings a day |
| 13 | S1 | Sightings and Bramble's spotting fire while you are in the casino or a menu, so you miss them. World events should wait until you are back outside. |  | FIXED | agent: happenings wait for outdoors and free |
| 14 | S2 | Bramble's spotting: you get waypoints but never see what Bramble said (toast too fast or missing) [69]. |  | FIXED | agent: Tumble's line on the card for the trail |
| 15 | S9 | Tumble interrupts Marigold's first conversation. Design question: should Tumble be found a little later rather than straight away? |  | FIXED | tumble_meets after met_fennel |
| 16 | S9 | Bramble's Color Day line is the cheerful "excited for my talent" one; at this point it should be scared. |  | FIXED | Color Day barks; test_dialogue_graph |
| 17 | S1 | Marigold's lift step: the objective points at the Depot building, and the Depot prompt wins over talking to Marigold [100]. |  | FIXED | lift trail to Marigold; test_objective |
| 18 | S9 | Postcard "I found my talent!" is sent for canon ponies who already have marks (Shining Armor) [92]. Drifter-only, or a named-pony variant. ("Printed and posted by Intake" works.) |  | FIXED | postcards only from blank Drifters |
| 19 | S9 | "Top of the board" letter: the horror hint is too oblique to land [89]. |  | FIXED | letter wording: the hoof in the cropped photo |
| 20 | S1 | Repeated identical shipment letters after a big Depot run; fold them into one summary letter per batch. |  | FIXED | one card a dawn (agent + main) |
| 21 | S1 | One toast per shipment, played back for minutes after the sale ("55th shipment received"); make it one summary toast [80]. |  | FIXED | one toast per Depot batch (agent); test_delivery_toast |
| 22 | S2 | Bloom ceremonies happen off-screen when you are away from the pen; call the player over or replay it. |  | FIXED | call-over (agent) + first Bloom cinematic (main) |
| 23 | S3 | Catching: the multi-hit hold ("She slipped out! Hold her a little longer") was first called "just annoying". The owner then remembered you must keep looking at the pony; verdict pending. Either way, the look-at rule is never taught; it only matters on harder ponies [83]. |  | FIXED | agent S3: one clean catch; test_magic_beam |
| 24 | S1 | A caught pony sometimes stays on the ground in the beam; it should always lift. | Beam aimed low at a wild pony | FIXED | HOLD_MIN_LIFT; test_magic_beam |
| 25 | S3 | Always running: walking has no use. Make run the default with an optional walk, or give walking a purpose (sneaking). |  | FIXED | agent S3: walking sneaks; test_sneak_and_bait; strips shots/catch5 |
| 26 | S7 | Invisible walls and prop snags across the map: the pen/house gap near Sweet Apple Acres [77], the lake dock and boat [98]. Needs a collision pass plus an "unstuck" pause option. |  | PARTIAL | Get unstuck (main); jetty and canoe colliders, pen gap (S7 agent); no whole-map sweep |
| 27 | S7 | A sighting trail leads over a fence into an enclosed field (the graveyard) with no gate; the trail should follow a walkable route [78]. |  | FIXED | S7: trail routes through region gates (Ranch.walkable_aim) |
| 28 | S6 | TIPPING BUG IS BACK (was 05/17): Rarity pitched nose-down onto her front hooves in a crowded pen in the rain [67]. | Crowded pen, rain, Rarity, player walking near | MEASURED | stress_pen (packed Grand pen, rain then night, player walking and jumping): tip max 2.2 deg over 96 frames; no pitch onto the forehooves seen |
| 29 | S6 | Penned ponies pile into the fence corner nearest the player, clip through each other and the fence (was 05/65) [67][99]. | Packed pen, player walking up to it | PARTIAL | stress_pen: overlap max 0.00 between residents; one frame shows Pinkie leaning over the rail at the corner nearest the player |
| 30 | S6 | Player tail flips over the back into the mane on jump [58]; tail moves oddly while running (was 05/9). | Player jumping and running | MEASURED | side-on jump strip (p8_checks --only=jump, 12 frames through take-off and landing): the tail swings up behind her and settles, never over her back into the mane |
| 31 | S6 | A wild pony next to an AFK player vibrated its head (look-at tracking fighting itself) [97]. |  | FIXED | test_pony_face behind-target test |
| 32 | S6 | A pony floating in mid-air outside the pens [86]. |  | MEASURED | stress_pen: 0 frames with a resident in the air |
| 33 | S6 | The player pony renders see-through at normal distances [69][83][95]. |  | FIXED | dither fade (render pending) |
| 34 | S6 | The player mane is a flat cutout over one eye; NPC tails are shapeless blue blobs [63][68][76][86]. |  | FIXED | hair_center rounded normals (render pending) |
| 35 | S6 | Spike's eyes are darker than everyone else's, with no white or highlight; Spike looks slightly see-through [82]. |  | FIXED | render checks2/spike_close.png: sclera, iris, highlight |
| 36 | S6 | Flank jiggle: keep it everywhere; it is barely visible on small ponies and on ponies with big tails. Also wanted: comedic cinematic beats that show it (Derpy crash-landing). |  | FIXED | RumpBounce gain; test_rump_bounce |
| 37 | S6 | Still short of the vision; needs a reference creator (Animal Crossing NH, The Sims 4 Create a Sim, Spore, Star Stable) [56]. |  | OPEN |  |
| 38 | S6 | The preview does not match the picks: Unicorn chosen but the model has wings and no horn; lilac coat reads tan; blue eyes read dark [56]. |  | FIXED | render checks2/creator_race0..2: earth bare, pegasus wings, unicorn horn |
| 39 | S4 | Dusk lighting muddies the colours; a creator wants neutral, even light. |  | FIXED | neutral studio light; render checks2 creator |
| 40 | S6 | Cutie mark sits too low and too far back (by the stifle, half under the wing); the show puts it larger, centred on the upper haunch [57]. |  | FIXED | mark moved to the upper haunch (render pending) |
| 41 | S5 | Many cutie mark stamp icons still look bad. |  | FIXED | stamps restyled; sheet stamps3.png looked at |
| 42 | S7 | The town is crowded (buildings, signs and ponies on top of each other) while the rest of the map is empty. Spread it out, but keep the Market and Depot close [60]. |  | FIXED | S7: plaza; top-down s7/town_before_after.png looked at |
| 43 | S7 | Signs are flat and vanish edge-on (all of them); you walk through them [61][62][63]. | Walking past and into signs, edge-on | FIXED | signs stay side-on, solid; test_place_sign_fade |
| 44 | S5 | The fingerpost has 5+ overlapping arms, a giant drooping Pens arm and a tiny unreadable one; Market and Depot are each signed twice [60][63]. |  | FIXED | fingerpost three arms |
| 45 | S7 | A board floats detached from the building by the Tumble prompt; Favours overlaps Requests [59][60]. |  | FIXED | S7: board on its wall, one sign |
| 46 | S7 | Arcade props (dance machine and skee-ball) stand outside the casino doing nothing [64]. |  | FIXED | arcade cabinets cut |
| 47 | S7 | Remove the "House rules" sign outside the casino; the pony by it is dark and unlit [74]. |  | FIXED | House rules board cut |
| 48 | S7 | Scale misses: the Sweet Apple Acres barn is tiny next to haystacks, the shed is off, the wishing well is knee-high [76][83]. |  | FIXED | barn 1.5x, hay piles, well |
| 49 | S4 | Night lighting: blotchy stencilled tree and building shadows across house fronts and the far hill; the hill glows teal; it does not read as night [68][69]. | Night, town and far hill | FIXED | moon light + porch lamps; look_after night renders |
| 50 | S4 | Distant models break up: the chicken coop becomes an orange blotch, trees shed floating brown fragments [88][94]. |  | PARTIAL | S7: props fade from 90 m; the floating tree fragments not reproduced |
| 51 | S4 | A dark shadow on the path with nothing casting it [82]. |  | FIXED | sun at night replaced by the moon; hard shadows to 60 m |
| 52 | S7 | The house base sits crooked on the slope; casino brick base and path cut off hard against the grass [74][77]. |  | FIXED | S7: levelled pads, footings, Strip kerb |
| 53 | S7 | The pen lattice is unreadable (where one pen ends) [94]. |  | FIXED | S7: earth floors, corner posts, 4.2 m walks |
| 54 | S7 | NPCs stand in high-traffic spots (Old Fennel in the pen gate) and their talk prompt takes over [95]; "E: talk to Tumble" shows with Tumble out of view [61]. |  | FIXED | companion prompt on screen only (main); NPC spots moved off the gates (S7) |
| 55 | S7 | Reeds and grass by the lake are sharp shards; dock planks are flat dark slabs [98]. |  | FIXED | S7: reed cards, plank jetty |
| 56 | S8 | The casino still looks bad: a cloned crowd (same grey-purple coat, dark mane), patrons frozen in the air or clipping, nobody plays anything. Wants an AAA reference (GTA Online Diamond Casino, Yakuza 0 / Like a Dragon casinos, Pokemon Let's Go Celadon Game Corner) [65]. (was 05/44) | Casino hall, crowd idle | FIXED | render checks4/hall.png: varied coats and manes |
| 57 | S8 | First casino visit should waypoint to the cashier cage. |  | FIXED | cage beacon; test_palace_interior |
| 58 | S8 | Blackjack: you cannot bet 100 (the chips set the bet instead of stacking; no max or clear); the table is mostly empty felt with text labels [66]. |  | FIXED | chips stack, Clear, Max; test_blackjack_menu |
| 59 | S8 | Blackjack cards: clubs render as broken dots, pip layouts are wrong, corner numbers touch the edge [96]. |  | FIXED | suits from the icon set, inset index |
| 60 | S8 | Slots: the layout is fine, the reel icons are flat clip-art with no Equestria flavour; a toast bleeds through behind the window [70]. |  | FIXED | icon set reels; kit paper is opaque, so no toast shows through |
| 61 | S8 | Race betting is the worst screen: invisible stake buttons, keyboard-only text ("Enter to play, Esc leaves"), colour-square portraits, odds spilling out of the coin, unclear dots and "by the card", a ghost prompt behind it, half the panel empty, "no chips" after 1,400 shown in slots [71]. |  | FIXED | race guide rebuilt; render checks2/race_guide.png |
| 62 | S8 | The race board in the hall runs on its own loop (one race, then another straight away), with no names or faces [72]. |  | FIXED | tote mirrors the real race |
| 63 | S8 | Watch the race: a cinematic for the race you bet on (reference GTA Online Inside Track) [72]. |  | FIXED | race cinematic |
| 64 | S8 | After betting, nothing says who you backed; keep a "your pick" card and highlight her in the race. |  | FIXED | pick ringed and named |
| 65 | S8 | The casino UI as a whole needs a reference pass with the 3D (Balatro, Red Dead Redemption 2 cards, Clubhouse Games 51, Hearthstone). |  | PARTIAL | felt nap and crest, chips, race guide, jackpot; dealer portrait not done |
| 66 | S7 | Market music is a recognisable NCS track and grating; replace it with something original or obscure. |  | FIXED | S7: original Market tune (tools/make_market_tune.py); not judged by ear |
| 67 | S10 | The loading screen still feels cheap (references: Hades, Stardew, A Short Hike). |  | FIXED | key art captured from the game (plaza at dusk); title_shot.gd render looked at |
| 68 | S5 | The Market does not read as buy-and-sell (Stardew's Pierre's shop is the reference); the window resizes as the pony list scrolls. |  | FIXED | Market named and fixed size |
| 69 | S5 | Depot: a delivered pony lingers and animates before it goes; it should pop to coins at once. Rows swap "+bits" and "-debt" order; icons are generic shapes, not faces; no deliver-all [73][85]. |  | FIXED | portraits, coins at once, deliver all; test_depot_menu |
| 70 | S1 | Depot rows call every pony "she" (Braeburn, Doctor Whooves, Mane Allgood) [85]. |  | FIXED | agent: pronouns; test_depot_menu |
| 71 | S5 | The caught card portrait is off-centre and cropped; Fluttershy shows a white mane with no pink; Fluttershy rated Uncommon [81][97]. |  | PARTIAL | Fluttershy Rare; portrait reframed lower and further back, not yet seen on a render (the probe's catch missed) |
| 72 | S5 | Toasts and HUD cut off at screen edges (the saddlebag on the left, "That pen is full" on the right, toasts at the bottom) [68][79][80][83]. |  | NO CHANGE | the clipping was the screenshot's crop (owner said so of another) |
| 73 | S5 | A giant "!" quest marker sits on the fingerpost; the compass stacks markers and clips them at the edge [68][76]. |  | FIXED | news bubble from the icon set, smaller |
| 74 | S2 | "Feed Drifters to Bloom" means nothing to a new player: Drifter and Bloom are never explained [75]. |  | FIXED | agent: plain words + explainers |
| 75 | S2 | Two objectives compete ("Read your new letter" over "Sell gems to Bramble") [89]. |  | FIXED | agent: Sell gems tip hidden while the card points elsewhere |
| 76 | S2 | A pen filling up is only a toast; show "full" on the pen [77]. |  | FIXED | agent: Pen full on the gate |
| 77 | S5 | A letter appeared to reopen after Back (unconfirmed) [90][91]. |  | OPEN |  |
| 78 | S9 | Event cinematics: Sonic Rainboom, Derpy crashing, races, and the Bloom ceremony get a camera cut instead of a toast. |  | FIXED | Derpy crash, Rainboom, cinematic player; renders checks/derpy, rainboom |
| 79 | all | A references pass: for each weak area (creator, casino and its UI, loading screen, town layout), pick 1 or 2 polished games to work towards before rebuilding. |  | OPEN |  |
