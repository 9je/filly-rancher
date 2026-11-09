# Credits

Filly Rancher is a non-commercial fan game. Every original character, story, line of
dialogue, generated cutie mark and Blender-built prop in it was made for this project. The
third-party material it uses is listed below with its source and licence.

## Source works

- *My Little Pony: Friendship is Magic* (Hasbro, DHX Media; developed by Lauren Faust): the characters, places and look this fan game is built on. Not for redistribution.
- *Rainbow Factory*, the fan story by Aurora Dawn (and WoodenToaster's song of the same name): the Factory's premise.

## Music

All licensed music is by **Kevin MacLeod** (incompetech.com) and is licensed under Creative Commons:
By Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/). Each track is credited as the
licence asks:

- "Morning" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Evening" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Carefree" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Gone Beyond" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Ossuary 6 - Air" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Stay the Course" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Promises to Keep" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Lost Time" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License
- "Backbay Lounge" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License

The Market's tune ("Market Stalls", `music/market_stalls.ogg`) is original to this project,
synthesised by `tools/make_market_tune.py`. "Carefree" stays on disk but no longer plays.

## Sound effects and ambience

Fetched and processed by `tools/fetch_sounds.sh` from the rows in `tools/sound_manifest.txt`,
which records the exact source URL (and pack member) of every file. `AUDIO_AUDIT.md` lists
every file in the game with its measurements and its source. (Rewritten by the audio audit
of 2026-10-24 to match the manifest: the list it replaced named an OpenGameArt and Wikimedia
swap that was planned and then reverted, and never named the BBC rows the game ships.)

**CC0 (public domain dedication), Kenney (kenney.nl):**
- Impact Sounds: every hoofstep (grass, dirt, wood, stone and metal sets), the delivery
  thud, the mail stamp, the reel stop.
- RPG Audio: the gate creak, the letterbox clack, the letter's paper and the page turn.
- Casino Audio: the chips, the cards, the coin grant, the roulette ball settling.
- Interface Sounds: the menu ticks, the capture chime, the slots win, the sparkle, the reel
  tick and the wheel ratchet.

**CC0, OpenGameArt.org:** "bubbles 'pop'" (the Scoop pop) and the PositiveChoice jingle (the
Bloom fanfare).

**BBC Sound Effects** (sound-effects.bbcrewind.co.uk, RemArc licence: personal, educational
and research use; this build is private and not redistributed, DECISIONS.md 2026-10-22): the
nine ambient beds, the beam's charge hum, the race crowd, gallop and cheer, and the single
rare capture neigh. Each row's BBC catalogue number is in the manifest.

## Fonts

See "Fonts (added)" below.

## Pony models (fan works, core assets)

The ponies are built on community fan models of the "My Little Pony: Friendship Is Magic"
art style:
- the **ReVAmped** SFM pony pack;
- the **CreatorOfPony** Blender models, via MythicSpeed's archive.

The game never shows them as the characters they were made to depict. They are anonymous
donor bodies, recoloured and re-marked by the game's own generator, and every pony in the game
is an original character.

These are fan works of Hasbro's intellectual property, distributed freely by their authors with
a request for credit. They are credited here, and the game is distributed non-commercially.

"My Little Pony" is a trademark of Hasbro. This game is not affiliated with or endorsed by
Hasbro.

## Environment props (fan works)

The town, farm and casino buildings are **PonySFM** community ports of show-style props:
- Sweet Apple Acres;
- Ponyville Environments and General;
- the Schoolhouse;
- Scenebuild;
- Las Pegasus.

A few Kenney low-poly packs (CC0) are also used. Everything is restyled at load by the game's
toon shader. The PonySFM ports carry no licence of their own beyond fan redistribution; they are
credited here on the same non-commercial basis as the pony models.

## Tools

Godot Engine (MIT), Blender (GPL; used offline only), SourceIO (for importing SFM models), and
GUT (MIT, tests only, not shipped).

### Fonts (added)
- **Fredoka** by The Fredoka Project Authors, SIL Open Font License 1.1 (game/assets/fonts/OFL.txt).
