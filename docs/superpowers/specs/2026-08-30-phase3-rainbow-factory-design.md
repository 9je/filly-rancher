# Filly Rancher, Phase 3: The Rainbow Factory

**Date:** 2026-08-30
**Status:** Design for review, pre-implementation
**Scope:** The story layer and the economy that carries it: stock ponies, the Company ledger and quota, the casino, the story beats, the insider and the fork, and the Factory interior. Six slices; each gets its own implementation plan. This document is the shape they all fit.
**Supersedes:** four rows of the 2026-08-26 spec. Pillar 3, "Nopony suffers", is retired. The Player character row ("Twilight Sparkle; full pony customization is a Phase 5+ feature") is amended: the player designs and names their own unicorn at new game; race choice and per-race capture styles stay in Phase 5+. The Collectibles row ("canon characters only, no generic breeds") is amended: canon characters stay the only *collectibles*; generic stock ponies exist as the quota's supply and are not collected. The Gambling row's "Las Pegasus casino deferred to Phase 5+" is brought forward to this phase. "Pony death" stays out of the *code* (no pony ever dies on screen); it enters the *story*.

## Why this phase exists

The owner has a bigger world and nothing to say in it. The words this design is held to:

"The game is going to start as a cute pony collecting game but will slowly reveal something darker. We're initially led to think we're helping ponies but it is slowly revealed our ponies are provided to the Rainbow Factory. Turns out we're the bad guy." And: "economy focused, a pony quota you gotta deliver, a full on casino sponsored by the Factory." And on the shape of the arc: "you pay your first few quotas, then an NPC tells you you can not pay it and gives disruptive tasks (good route: you don't pay, there's punishments, the game is harder), or you can rat them out, they get killed, and you keep helping the company. The game keeps going forever and remains fun, like Stardew Valley." And on the tone: "implied, maybe a bit of explicit, only what we can afford to build." And at spec review: "I also want the start to be character customization where you design and name your character."

Two constraints from the same conversation bind every section below:

- **The economy stays bits and gems.** Ponies affect it, and the game needs a reason to remove ponies. The casino is honest and fun; it is never rigged, on either route.
- **Repeatable.** "Last time I played I collected all 12 ponies on the map in two minutes." Whatever the story does, the wild must never run dry and the catching must stay worth doing.

The Rainbow Factory is the fan work of that name: a Cloudsdale facility that turns ponies into the spectra that rainbows are made of. The game never names its source and never shows the process. It shows the paperwork.

## The loop

**Catch** ponies in the wild: stock ponies in numbers, named ponies as the rare finds.
**Pen** them; they make gems.
**Sell** gems for bits.
**Pay** the Company: upkeep comes out of your sponsorship balance on collection day, and the balance only really moves when you deliver ponies.
**Spend** what is left on permits, gear, care, and the casino.
**Read** the mail. It is cheerful for a while.

Then the fork, and after it two loops that each run forever:

- **Company:** deliver, rank up, get rich, and watch the world go quiet.
- **Resistance:** stop paying, take the insider's tasks, absorb the punishments, and take the Company's hardware apart one piece at a time.

## Approach

Same as Phase 2: spine first, content as data. The story is authored as resources (letters, request wording, dialogue lines, tasks), keyed by chapter and read by generic systems. Writing more story means adding files. The one place this design adds code rather than data is the casino, which is four small games and a race.

Rejected alternatives, recorded so they stay rejected:

- **A general quest graph.** Prerequisites, objectives, branching rewards. Twice the work of extending the Request Board, and the arc above does not need it.
- **A finite campaign.** The Company route ending when the map is empty. Rejected by the owner: the game keeps going.
- **Delivered ponies coming back** ("cloned from retained samples"). Renewable, but it defuses the loss, which is the point.
- **A rigged casino** as a Resistance tool. Rejected by the owner: the casino stays a fun, honest money sink.
- **Sanctuary** (shelter ponies instead of delivering) as the good route's spine. Passive; the owner wants the good route to be *disruption*.

## Systems

### Character creation

A new game opens on the creation screen before the ranch loads: the player's pony on a turntable against the dawn sky, and a name box. The player is a unicorn; the beam is the game, and other races wait for their capture styles in Phase 5+.

- **Looks:** coat, mane and tail, and eye colours picked from swatch rows (the same `StockPalette` machinery as stock ponies, with a wider player palette); a mane style, if more than one sourced style retargets cleanly onto the base rig, otherwise the one; and a cutie mark the player **draws**: a small square canvas (about 64x64) with a colour palette, brush sizes, an eraser, undo, and clear, plus a few optional stamp templates to start from. The drawing is applied to both flanks of the model.
- **Name:** typed, length-capped, shown everywhere text addresses the player. Every Company letter opens with it ("Dear {name},"), the Depot statement is made out to it, NPCs use it, the casino cage knows it. The Company knowing your name is part of the register.
- The result is saved as `player` (name, palette, mane, and the mark as a small base64 PNG, so the save stays one self-contained JSON blob) and the player model is tinted exactly as stock ponies are: one pipeline, two users.
- A v4 save loads with the current look and the name Twilight; no re-edit screen this phase (YAGNI). Twilight Sparkle leaves the player slot and can join the catchable roster in some later phase's authoring, not this one.

### Stock ponies

Generic ponies, one base model (two if a second sourced rig retargets cleanly), recoloured per instance from a palette: coat, mane, tail, eyes. They spawn in every region in numbers, respawn on a timer after capture or delivery, produce `COMMON` gems in a pen, and have no Compendium entry. The Company calls them "unregistered stock"; the game calls them ponies.

- `StockPalette` resource: arrays of coat, mane and eye colours; a stock pony is `(palette index triple, personality, rarity COMMON)`. Recolour is a material tint on the base model's coat and mane surfaces; the pipeline change is a one-off in `docs/pipeline.md`.
- `Spawner` keeps its map-wide no-duplicates rule for named characters and gains a stock budget per region: `stock_min`/`stock_max` on `RegionData`, refilled at `phase_changed` from the seed. Stock ponies flee, get caught, get penned, and leave exactly as named ponies do; `Pony` does not know the difference.
- `PonyInstance` gains `stock: Dictionary` (the palette triple; empty for a named pony). A stock pony in a pen is a real resident and saves as one.
- Named ponies keep their conditions and rarities. They are now the thing the player is hunting *among* the stock, which is what makes seeing one exciting again.

### The ledger

The Company's hold on the player, shown from minute one and never hidden. A `Ledger` system with:

- `balance: int`, the sponsorship balance. Starts at `LEDGER_STARTING_BALANCE` (25,000 bits; the ranch, the beam, the first pen). Shown in the pause menu and on the HUD as "CWC balance".
- **Collection day** every `LEDGER_PERIOD_CYCLES` (3 cycles, one real hour). On collection day `upkeep` is added to the balance: a base plus a charge per built plot and per open permit, times the rank multiplier. Upkeep grows with the ranch; gem income grows with the ranch; upkeep is tuned to grow faster. The player can pay down the balance in bits at the Depot at any time.
- **Deliveries** credit the balance: `DELIVERY_CREDIT_STOCK` (300 bits) per stock pony, more for a named pony by rarity (`GEM_VALUE_BY_RARITY` times `DELIVERY_NAMED_MULTIPLIER`, 40; a legendary clears 4,000). A named delivery is the best money in the game by a wide margin. That is deliberate.
- **Quota:** each collection day also demands `quota` ponies delivered since the last one (starts at 2, grows with rank). Quota unmet or balance above `LEDGER_CEILING`: a **collector** visits at the next dawn. Collectors are the punishment ladder, in order: a fee; a permit revoked (the fence closes, the ponies inside keep their leashes and stay, unreachable); a pen padlocked (no gems until the balance is back under the ceiling); the beam "recalled" for one cycle. Nothing is deleted; everything is recoverable by paying. No pony is ever taken from a pen by a collector before the fork, and after it only on the Resistance route (below).
- **Interest** is small and shown ("service charge"). It exists so the balance visibly never reaches zero on gems alone. The spec's promise: a player who never delivers a pony cannot pay the balance off. This is a tuning invariant with a test, not a hope.

### The Depot

A Company building on the ranch beside the Market: a loading dock with a crate and a logo. Interaction opens the Depot menu:

- **Deliver:** lists penned ponies (stock first, then named, with their credit). Confirm, and the pony walks from her pen to the crate and into it: `Pony.leave()` with the crate as the exit, the same departure path a runaway uses. The crate closes. Credit is applied, quota counted, a receipt letter arrives. **No pony is ever freed by anything but the departure path, and nothing gruesome happens on screen at the Depot.**
- **Pay:** bits against the balance.
- **Statement:** balance, upkeep breakdown, next collection day, quota progress, rank.
- Named deliveries set the Compendium entry to a new state, `PROCESSED`, which renders after the fork as the entry's portrait desaturated, her name, and a yield percentage. Before the fork it renders as "Delivered" with a smiley. The same state; only the words change with the chapter.

### The casino

"Spectra Palace, proudly sponsored by Cloudsdale Weather Corporation." A building in a new free region, the **Strip**, a small paved strip at the map edge with lights and a sign, unlocked from the start. Bits buy chips at the cage one to one; chips cash out one to one. The house edge is in the games, published on a sign in the lobby, and it is real: the casino is a sink with variance, never a source. Four games, each its own scene and its own pure-logic class with tests:

- **Slots.** Three reels, pony-themed symbols, a seeded RNG, paytable data. The fast one.
- **The Wheel.** A rainbow wheel, bet on a colour or a number. Roulette without the layout.
- **Blackjack.** One deck, dealer stands on 17, the rules on a placard.
- **Racing.** The standout, and the one that uses the player's ponies. A six-lane track behind the casino. Enter one of your penned ponies (her `base_speed`, `base_stamina`, `base_spirit` and current happiness make the race; these fields have existed since Phase 1 and nothing uses them yet) against five Company-owned runners, and bet on any lane. Odds are computed from the stats and shown. The race plays out on the track with the actual models; the player watches from the rail. A pony who races comes home tired (hunger up) and happy.
- **Stretch, not required:** a loyalty tier from chips wagered, with high-stakes tables and a VIP lounge that is one of the story's places (below).

The casino is on both routes and is never a story tool beyond its branding and its lounge. On the Resistance route the Company bans the player from the Strip at high heat; the ban is a punishment, and it is lifted like the others.

### Story

A `Story` system: `chapter` and a flag set, saved. Chapters are an enum: `SUNNY`, `WEATHER`, `CONTACT`, then the fork into `COMPANY` and `RESISTANCE`, each with an open-ended rank ladder after it. Chapter advances on triggers the game already emits: deliveries made, collection days passed, named ponies delivered, tasks completed. Everything the player reads is a `StoryBeat` resource: `id`, `chapter`, `trigger` (a kind and a threshold), `sender`, `title`, `body`, and an optional `reveals` list of Compendium ids to relabel. Three channels carry the beats, in order of weight:

**Paper.** A mailbox by the ranch door and a **Mail** page in the pause menu. Company mail is the arc's spine: welcome letters, receipts ("Your 12th delivery! Shipment quality: excellent"), quota reminders, then, in `WEATHER`, letters whose numbers are wrong for what they claim to describe ("Yield: 94%. Spectra grade: A"), and a receipt that lists a named pony you delivered next to a colour. Request Board wording is also chapter-keyed: the same request reads differently in `SUNNY` and in `COMPANY`. Paper is cheap and it is where the horror lives for most of the game: the player re-reads old letters.

**People.** A handful of NPC ponies (four to six; authoring decides who) in the **Town**, a second new free region: a Ponyville corner with a few sourced buildings. NPCs stand at their spots, turn to face the player, and open a **talk box**: a line at a time, at most two choices, lines keyed by chapter and flags. NPCs are `PonyData` too (with `npc = true`, so the spawner and the Compendium ignore them). They carry the good route: the town is where the insider sends you and where the evidence goes. The talk box is the only new UI beyond menus.

**Places.** The Company's hardware has been in the world since the first slice, with a friendly logo: **weather pylons** in each region (the rain and the storms are literally Company output), the Depot crate, the casino cage, the intake pens beside the Depot. After the fork they are targets or trophies. And the **Factory interior**, a separate scene reached through the Depot on either route's ladder (below): a loading bay, a corridor, an intake room, a control room with a window. The horror budget goes here.

### The insider and the fork

In `CONTACT` (after `CONTACT_DELIVERIES`, 6 deliveries, and at least one named delivery or three collection days, whichever is first) a pony appears at the ranch fence at night: a weather pegasus with a Company tag, off the roster and not collectible. She talks (talk box), tells the player what the crate is, and asks for one thing: stop paying. The talk box's two choices are the fork.

- **"I'm done with them."** → `RESISTANCE`. The Board gains a second sender: her notes, pinned over the Company's requests. Deliveries at the Depot still work (the player can always cave) but each one sets the insider back a step.
- **"I'm calling this in."** → `COMPANY`. The next letter thanks the player for the report, notes that the "irregular employee" has been "processed", and encloses a promotion. The word killed never appears. The insider is never seen again. This is the darkest thing the player does on screen, and it is a menu choice.

The fork is once per save and shown as such before the choice.

### The Company route

A rank ladder, open-ended: `RANKS` is data (title, quota, upkeep multiplier, perks). Perks are shop discounts, casino comps, exclusive gear, and named-pony bounties ("Requested: Derpy Hooves. Bonus 400"). Each rank's letter is warmer than the last and each mentions the yield. At `TOUR_RANK` the player is invited to the Factory for a tour: the interior scene, walked with a Company guide's talk box, in which every room is described in the Company's words while the player looks at what is in it. The final room's window is the explicit beat. After the tour the game continues; the guide's thank-you letter is the last chapter-scripted beat, and the ladder keeps going on data alone.

World consequences that make the route legible without a cutscene: named ponies delivered stop appearing (they were unique already); the weather table shifts toward `STORM` and `RAIN` by one weight per rank; the town NPCs' lines get shorter.

### The Resistance route

Quotas stop being paid, so the Company's punishments arrive on schedule, and they escalate with **heat**, a saved integer: every missed collection day and every task completed raises it. The punishment ladder is the ledger's collector ladder, extended: at high heat the collector takes a pony from a pen on collection day (she leaves by the departure path; the Compendium entry goes `PROCESSED`; this is the one place after the fork where the Company reaches into the ranch, and it is the reason to finish the tasks). Prices rise with heat. The casino bans at `BAN_HEAT`.

**Tasks** from the insider are `InsiderTask` resources on the Board's second sender: kind, target, text, and what completing it *removes*. Kinds, all using verbs the player already has:

- **Cut a pylon** (beam it at night while its light is off, holding the beam for `PYLON_CUT_SECONDS`; a Company patrol pony walks the region and sneak matters). The region's weather table loses `STORM`, and the rainbow over the Factory in the sky loses a band. The sky is the progress bar.
- **Empty an intake pen** beside the Depot after dark: beam the waiting ponies out (stock and, sometimes, a named one on a bounty). Rescued named ponies join the ranch marked `RESCUED` in the Compendium.
- **Leak** a letter: carry a specific `StoryBeat` (the ones with `evidence = true`) to a named town NPC. Unlocks that NPC's next lines and the next task.
- **Race** for the town: win a race at the casino with a rescued pony (the casino stays honest; the task is just to win).

Each completed task lowers heat by its `relief` and permanently removes one Company effect (a punishment tier, a weather weight, a price increase). The ladder ends at `SHUTDOWN` (all pylons cut, all leaks delivered): the final task is to walk into the Factory through the Depot with the town at the gate, cross the same interior, and pull the switch in the control room. After that the rainbow is gone from the sky for good, `STORM` leaves the weather table, the balance is written off, the intake pens are empty, rescued ponies live on the ranch, and the game continues: catching, penning, selling, racing, with the Board back to plain requests and stock ponies still roaming. Poor and free.

### The Factory interior

One scene, walked twice in the design (tour and shutdown) and once per save. Rooms in order: loading bay (the crate from the other side), corridor (posters, a yield chart with names from the Compendium), intake (empty pens with tags), control room (a window, a switch). What the window shows is the explicit beat and is bounded by what the asset pool can build well: silhouettes behind frosted glass, a colour that changes, the sound, a Company voice line. Anything that would look silly with fan models is cut before it is built. The rule: implied by default, explicit once, gruesome only in words and sound.

The interior's talk-box lines differ by route; the geometry does not.

### Pacing

The numbers the plans tune to, and the reason the phase is fun rather than merely dark:

- A fresh save reaches the first collection day in one real hour with the balance up, not down: the player has been told the rules and has felt them once.
- The first named pony takes minutes to find, not seconds: stock ponies are the crowd; named ponies are at most one in five wild spawns in the ranch region and rarer beyond it.
- A stock pony is caught in the current capture flow unchanged; capture difficulty stays keyed to personality and rarity as Phase 2 slice 2 set it. Repeatability comes from supply, not from making every catch a chore.
- A full session (three cycles) at a mid ranch earns roughly one collection day of upkeep in gems, so the delivery decision comes up every session and the casino is affordable in between.
- The fork is reachable in about three sessions and never later than five; the tour and the shutdown are each about ten sessions past it. After either ending, nothing is time-gated and everything still pays.

## Data model changes

| Where | Change |
|---|---|
| `PonyData` | `npc: bool` (talk-box character, never spawned or collected). |
| `PonyInstance` | `stock: Dictionary` (palette triple; empty for a named pony). |
| `RegionData` | `stock_min`, `stock_max`, `pylon_position`. |
| `StockPalette` (new) | coat, mane, eye colour arrays; also serves character creation via a wider player palette. |
| `StoryBeat` (new) | `id`, `chapter`, `trigger`, `sender`, `title`, `body`, `reveals`, `evidence`. |
| `InsiderTask` (new) | `id`, `kind`, `target`, `text`, `relief`, `removes`. |
| `Rank` (new) | `title`, `quota`, `upkeep_multiplier`, `perks`. |
| `Compendium` | states `PROCESSED`, `RESCUED`. |
| Save | `player` (name, palette, mane, mark PNG), `ledger` (balance, period counter, quota progress, punishments), `story` (chapter, flags, heat, rank, mail read state), `casino` (chips, loyalty), `tasks`. `version` becomes 5; a v4 save loads with the ledger at its starting balance, the story at `SUNNY`, and the player named Twilight with the current look and a blank mark. |

No existing save key changes meaning.

## Testing

The project's rule stands: a gate prints its marker after the verdict; exit code is the verdict. Every system above gets pure-logic tests in `game/test/` and a headless gate per slice:

- `ledger_test`: collection day arithmetic, the collector ladder in order, recovery by paying, and the invariant that gems alone never clear the balance (a simulated ranch at the best gem rate over 50 collection days ends above zero).
- `depot_test`: a delivery leaves by the departure path, credit and quota update, the Compendium goes `PROCESSED`, and the pony count in the world never grows and never loses a pony to anything but that path.
- `casino_test`: each game's odds converge on its published house edge over a seeded run of 100,000 plays; chips and bits round-trip exactly; a race's finish order is a function of stats and seed.
- `story_test`: every `StoryBeat` in `game/data/story/` has a chapter that exists, a trigger the game can emit, and no em dash or double hyphen in its text; the fork is one-shot; each route's ladder is walkable end to end by firing triggers.
- `resistance_test`: heat rises and falls as specified; every task kind completes from its verb; a pylon cut removes `STORM` from its region's table; the shutdown leaves the world in the promised state.
- `factory_test`: the interior scene loads, both routes' walks complete, and the exit returns to the ranch with the save intact.
- `creation_test`: the creation screen round-trips every palette choice and a drawn mark into the save and back pixel-identical, the tint and the mark land on the player model, and every letter template renders with a longest-legal name without overflow.
- Save round trips for every new key, including a v4 save.
- The visual harness for the creation screen, the Strip, the Town, the recolour palette, and the interior, reviewed by eye.

## Build order

1. **Character creation, stock ponies, and the ledger.** One recolour pipeline serving the player and the crowd, the renewable supply, and the debt clock, with the Depot's deliver and pay. The game's spine changes here: after this slice the player has a reason to remove ponies. Letters are a stub sender with fixed text.
2. **The casino.** Strip region, cage, four games, racing with the player's ponies. Self-contained, and the biggest single piece of fun in the phase.
3. **Story: paper.** `Story`, `StoryBeat`, mail, chapter-keyed Board wording, `PROCESSED`. Chapters `SUNNY` through `WEATHER`, and the Company ladder's letters. The Company route is complete after this slice except for the tour.
4. **Story: people.** Town region, NPCs, the talk box, the insider, the fork. Ranks and their perks.
5. **The Resistance.** Heat, pylons, patrols, intake pens, tasks, leaks, punishments and their removal, the shutdown state.
6. **The Factory interior.** The scene, both walks, the explicit beat, and the sound.

Slices 1 and 2 are independent and can be built in either order; 3 needs 1; 4 needs 3; 5 needs 4 and 2; 6 needs 4 and 5.

## Not in this phase

- **Fusion.** Still parked.
- **Voices and music** beyond the Factory's sound design. `docs/notes-voice.md` stands.
- **Player customisation and non-unicorn capture styles.**
- **A second map or seamless Cloudsdale.** The Factory is an interior scene reached through a door.
- **Multiplayer, on-screen death, combat, distribution.** Still out.
