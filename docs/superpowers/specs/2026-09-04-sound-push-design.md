# Sound Push Design -- Filly Rancher Phase 3 audio slice

**Date:** 2026-09-04
**Status:** Approved by standing autonomous loop (owner: "can we do a good sound push? I want good natural sounding sounds. i again dont care about usage rights" -- 2026-09-04). Owner-facing taste knobs parked in the slice ledger.
**Related:** docs/superpowers/specs/2026-08-30-phase3-rainbow-factory-design.md (Factory interior sound stays budgeted in slice 6, not here).

## 1. Goal and register

Give the game a full natural-sounding audio layer: ambient beds that follow the day cycle, world SFX for everything the player touches, casino table sound, and UI ticks. The game currently ships exactly one sound (the placeholder capture voice line). Silence is the biggest remaining polish gap; the owner rates this the key polish item.

Register: the world SOUNDS as cute as it looks. Real birdsong, real wind, real crowd murmur -- the dark-comedy register comes from the story, never from the audio turning ominous early. (The Factory interior in slice 6 is where sound design goes cold; that contrast only lands if the ranch sounds genuinely idyllic.)

**Quality bar (binding):** natural recordings over synthesized blips wherever a real-world source exists. UI ticks and casino jingle stingers may be designed sounds; everything ambient or physical is a recording.

**Register rule (binding, owner 2026-09-04):** the ponies are cartoon characters, not livestock -- "the mlp ponies dont make realistic horse noises." No realistic horse VOCALIZATIONS anywhere (no whinny, neigh, snort, nicker). Physical horse sound is still correct and wanted: hoofsteps ("walking is the big one we do need"), gallops under the race crowd. Moments that would have used a whinny use the capture chime or nothing. If pony vocal personality is ever added, it comes from a cute designed/voice source, a later owner-taste pass -- never from a farm recording.

**The one sanctioned exception (owner 2026-09-04: "slipping in a single realistic horse neigh in a comedic point could be pretty funny"):** exactly one realistic neigh exists in the game, as a rare deadpan gag. When a capture lands, a 1-in-24 roll on Sound's private RNG plays `neigh_real` (BBC NHU05084168, "Snort and neigh of mare", trimmed to the neigh) INSTEAD of the `capture_success` chime; the pastel pony emits one fully realistic horse neigh and the game does not comment. The joke works because the no-realistic-vocals rule holds everywhere else; a second use would kill it. Placement and rate are parked owner knobs.

## 2. Sourcing (proven feasible 2026-09-04)

Owner has waived usage-rights vetting ("i again dont care about usage rights"). Standing constraints still bind: **record the source URL for every file** in the manifest, **never create accounts**, **never use the owner's email**. All three sources below verified working with zero login:

- **BBC Sound Effects archive (PRIMARY)** -- https://sound-effects.bbcrewind.co.uk. Search: `POST https://sound-effects-api.bbcrewind.co.uk/api/sfx/search` with JSON `{"criteria":{"from":0,"size":N,"query":"..."}}`; rich metadata (description, duration ms, sample rate, channels, habitat, recordist). Download: `https://sound-effects-media.bbcrewind.co.uk/wav/<ID>.wav` (full-quality 16-bit 44.1kHz PCM, verified) or `/mp3/<ID>.mp3`. ~33k professional recordings incl. the Natural History Unit library. This is where ambient beds, animal sound, crowds, weather, and mechanical foley come from.
- **Kenney (SECONDARY)** -- https://kenney.nl direct zip downloads. Use for: UI ticks (Interface Sounds pack), casino chips/cards (Casino Audio pack -- recorded, not synthesized). Matches existing project Kenney usage.
- **freesound.org previews (GAP-FILLER)** -- search pages are scrapeable without login; preview MP3s at `https://cdn.freesound.org/previews/...` download freely (hq variant `-hq.mp3` preferred, lq verified). Use only when BBC and Kenney lack a specific foley sound; previews are 24kHz-44kHz MP3, acceptable for short one-shots after processing.

**Curation constraint (ledger this):** the build loop cannot listen. Selection is metadata-driven (BBC descriptions are detailed and honest) plus measured checks (duration fit, ffmpeg loudness/peak analysis, spectral sanity via `ffmpeg -af astats`). Every slot in the manifest records 2-3 candidate IDs so the owner can swap any sound with a one-line manifest edit and a script re-run. The owner's playtest is the real ear.

## 3. Asset pipeline

Mirrors the prop pipeline (`tools/convert_props.sh` + `prop_manifest.txt`).

- **`tools/sound_manifest.txt`** -- one row per sound: `dest_path|source_url|recipe`. Recipe is a comma-separated processing chain understood by the fetch script: `trim=START-END`, `fade=IN:OUT`, `loop` (seamless-loop treatment), `gain=TARGET_LUFS`, `mono`, `rate=44100`. Comments (`#`) carry the human note: what the sound is for, the BBC description snippet, alternate candidate IDs.
- **`tools/fetch_sounds.sh`** -- reads the manifest, curls each source into a cache dir (skips existing), runs the ffmpeg recipe, writes the processed file to its dest under `game/assets/audio/`, then prints a report table (dest, duration, integrated LUFS, true peak). Idempotent; a changed manifest row reprocesses only that row. Loudness targets: ambient beds -24 LUFS, world/casino SFX -18 LUFS, UI -20 LUFS; true peak ceiling -1.5 dBTP everywhere (the report FAILS a row that clips).
- **Seamless loops:** beds get the crossfade-loop treatment -- take N seconds, `acrossfade` the tail into the head so the file butt-loops cleanly -- then export **OGG Vorbis q5**. Godot's ogg importer gets `loop=true` via the committed `.import` file. Short SFX stay **WAV 16-bit 44.1kHz** (instant trigger, no decode latency), `loop=false`.
- **Committed to git:** processed files under `game/assets/audio/{ambient,world,casino,ui}/` plus their `.import` sidecars after an editor `--import` pass, the manifest, and the script. Raw downloads stay in the git-ignored cache. Budget: beds ~1-2 MB each as OGG, SFX tens of KB; the whole slice should land well under 30 MB.

## 4. Architecture

### 4.1 Bus layout

`game/default_bus_layout.tres` (committed, referenced from project.godot):

```
Master
├── Ambient   (beds only)
├── Effects   (world + casino SFX, 3D and 2D)
└── UI        (menu ticks, paper, stamps)
```

`AudioSafety` keeps muting Master for automated runs -- unchanged, and every existing `--audio-driver Dummy` invocation stays. `Settings.apply_audio()` grows two sliders' worth of state: `ambient_volume` and `effects_volume` (UI bus rides the effects slider; a fourth slider is knob clutter). Same clamp/step/persist pattern as `master_volume`; zero still mutes rather than -inf dB. The settings page gains the two rows with the existing row-drawing idiom.

### 4.2 The Sound autoload (`game/systems/sound.gd`)

Registered in `[autoload]` after AudioSafety. The single gateway for all playback; no other file constructs an AudioStreamPlayer for SFX (the magic_beam voice player stays as-is, out of scope).

- **Registry:** `const LIBRARY: Dictionary` mapping `StringName` sound ids to entries: `{path, bus, volume_db, pitch_min, pitch_max, variants: [paths...]}`. Preloaded at `_ready()` into streams. A missing file is a push_error, never a crash.
- **`play(id: StringName) -> void`** -- 2D one-shot on a pooled AudioStreamPlayer (pool of 12, oldest-steal). Picks a variant and a pitch inside the entry's range.
- **`play_at(id: StringName, pos: Vector3) -> void`** -- 3D one-shot on a pooled AudioStreamPlayer3D (pool of 8) with the entry's attenuation defaults.
- **`ambient_set_phase(phase: int) -> void`** -- crossfades the phase's bed set in over ~4s and the outgoing set out. Beds per phase are declared in a `BEDS` table (phase -> array of {id, volume_db}). Multiple simultaneous beds allowed (e.g. NIGHT = insects + owl distance + wind).
- **`ambient_set_zone(zone: StringName) -> void`** -- zone overlays on top of the phase beds: `&"strip"` (electric hum + distant crowd) and `&"casino"` (interior murmur + slot bed) fade in when the player enters those areas, out when they leave. Zone detection uses the ranch's existing area logic (the Strip lamp region / Palace interior state ranch.gd already tracks for other purposes; the plan pins exact hooks).
- **RNG (BINDING):** Sound owns a **private `RandomNumberGenerator`**, seeded from entropy at boot. It never touches the shared/game RNG streams. THE MATH DOES NOT CHANGE: no casino outcome, capture roll, or economy path may consume or perturb game RNG because a sound played. `game/ui/` stays RNG-free -- menus call `Sound.play(&"ui_tick")` and every variation decision happens inside the system.
- **Ranch owns pause:** SFX/UI players run with `process_mode = PROCESS_MODE_ALWAYS` for UI ticks (menus are open while paused) but world/casino one-shots and beds use pausable mode so opening the pause menu stills the world exactly as the visuals do.

## 5. Content list

Every slot below is a manifest row (or several, for variant sets). BBC search terms are starting queries; the builder picks by metadata and measurement, records candidates, and the owner swaps by ear later.

### 5.1 Ambient beds (Ambient bus, OGG loops, -24 LUFS)

| Bed id | Phase/zone | Source hunt |
|---|---|---|
| `bed_dawn_chorus` | DAWN | BBC "dawn chorus" / "early morning birdsong" |
| `bed_day_meadow` | DAY | BBC "countryside atmosphere summer" / "meadow birds insects" |
| `bed_dusk_calm` | DUSK | BBC "evening atmosphere birds distant" |
| `bed_night_insects` | NIGHT | BBC "crickets night" / "night atmosphere insects" |
| `bed_night_owl` | NIGHT (quiet, -30 LUFS) | BBC "tawny owl distant" |
| `bed_wind_soft` | all phases (constant floor) | BBC "gentle wind trees leaves" |
| `bed_strip_hum` | zone `strip` | BBC "electricity hum" + "distant funfair crowd" (two beds) |
| `bed_casino_room` | zone `casino` | BBC "casino interior" / "amusement arcade atmosphere" |

### 5.2 World SFX (Effects bus, WAV one-shots, -18 LUFS)

| Id | Trigger | Source hunt |
|---|---|---|
| `mail_arrive` | letter batch posted (flag raises) | BBC "letterbox" / metal flag creak + paper |
| `mail_open` | letter opened in Mail page | paper unfold (BBC "paper rustle") |
| `mail_stamp` | Survey answered / ANSWERED stamp | rubber stamp thump |
| `capture_charge` | beam charging | BBC "electrical hum rising" (pitch-shifted magical, not scary) |
| `capture_success` | pony captured | soft chime + pop (Kenney jingle acceptable here) |
| `hoofsteps_grass_1..4` | player footsteps, surface grass | BBC "horse walking grass" (variant set, clipped single strikes) |
| `hoofsteps_hard_1..4` | player footsteps, Strip/boards | BBC "horse hooves cobbles" (variant set) |
| `gate_open` | pen gate interactions | BBC "wooden gate creak" |
| `delivery_thud` | Depot delivery handoff | BBC "crate set down" |
| `coins_grant` | Economy.grant payouts outside casino | BBC "coins pouch" |

Footstep wiring: the player controller already knows movement cadence; the plan pins a step-timer hook that calls `Sound.play_at()` with surface pick. If cadence detection turns out invasive, footsteps degrade to a fixed-interval walk loop -- the plan decides, the ledger records.

### 5.3 Casino SFX (Effects bus)

| Id | Trigger | Source hunt |
|---|---|---|
| `chip_clink_1..3` | bets placed, any table | Kenney Casino Audio chips (recorded) |
| `card_slide_1..2` | blackjack deal | Kenney Casino Audio cards |
| `card_flip` | blackjack reveal | Kenney Casino Audio |
| `reel_tick` | slots reel step (rapid, quiet) | Kenney / freesound mechanical click |
| `reel_stop` | each reel lands | soft mechanical clunk |
| `slots_win` | slots payout | short bright jingle (Kenney) -- ONE stinger, not escalating fanfares |
| `wheel_ratchet` | wheel spin ticks (rate follows the wheel's existing visual pointer steps) | BBC "ratchet" / freesound |
| `wheel_settle` | ball/pointer settles | wooden click |
| `race_crowd_loop` | race running (OGG loop) | BBC "racecourse crowd" / "crowd cheering distant" |
| `race_cheer` | race settles (`race_settled` signal) | BBC crowd cheer swell |
| `race_gallop` | race running under crowd | BBC "horses galloping" |

BINDING: casino sound is presentation only. Triggers read the same already-public state/signals the drawing code reads; no new state, no timing change, no RNG consumption from game streams.

### 5.4 UI (UI bus, -20 LUFS)

| Id | Trigger |
|---|---|
| `ui_move` | selection moves in any menu (via MenuStyle, one hook point) |
| `ui_confirm` | confirm action |
| `ui_back` | back/close |
| `ui_open` | pause menu opens |
| `ui_denied` | disabled row / can't afford |
| `ui_page` | pause menu page switch (soft paper turn -- ties into the stationery look) |

Source: Kenney Interface Sounds, chosen for softness (woody/paper ticks, not beeps), or BBC paper foley for `ui_page`.

## 6. Integration points

- **`game/world/ranch.gd`**: phase changes call `Sound.ambient_set_phase()` (hook where the world phase transitions are already handled); zone enter/exit calls `ambient_set_zone()`; mail post batch -> `mail_arrive`; delivery/capture/economy grants at their transaction sites. Ranch stays the transactor; it fires sounds at the same points it already mutates state.
- **`game/ui/menu_style.gd`**: the one shared hook for `ui_move`/`ui_confirm`/`ui_back` so all menus gain ticks without per-menu wiring. Menus keep drawing and emitting only.
- **Casino screens** (`slots/wheel/blackjack/racing/casino_menu`): each already animates its stage; sound triggers ride the existing animation state changes.
- **`game/ui/pause_menu.gd`**: `ui_open`, `ui_page`, mail open/stamp sounds beside the existing mail_opened/mail_reply signal emissions; settings page gains Ambient and Effects volume rows.
- **`game/actors/player/`**: footstep cadence hook; capture beam charge/success beside the existing voice-line call site.

## 7. Testing and the SOUND_OK gate

- **GUT corpus test (`game/test/test_sound_library.gd`)**: every LIBRARY entry's path exists on disk and under `game/assets/audio/`; every manifest dest is referenced by exactly one LIBRARY entry or BEDS table (no orphans either way); ids follow the naming scheme; variant sets are complete (`_1..N` contiguous); pitch ranges sane (0.5 <= min <= max <= 2.0); every bed entry routes to Ambient and every UI entry to UI.
- **GUT settings test extension**: ambient/effects volume clamp, step, persist, apply-to-bus, zero-mutes semantics -- same cases master_volume already has.
- **SOUND_OK gate scene (`game/scenes/test/sound_test.tscn/gd`)**: boots headless with Dummy driver (AudioSafety pattern holds), loads every stream (a corrupt OGG/WAV fails the load), asserts ambient streams report `loop=true` post-import and SFX `loop=false`, asserts bus layout (4 buses, correct routing), exercises `play`/`play_at`/`ambient_set_phase`/`ambient_set_zone` without error and asserts pool behavior (13th simultaneous play steals oldest, no crash), prints `SOUND_OK ids=N` with N asserted. Wired into `tools/run_tests.sh` beside the other thirteen gates; MIN_TESTS floor rises with the new suite count.
- **Loudness enforcement lives in the pipeline**: `tools/fetch_sounds.sh` fails any row over -1.5 dBTP or off its LUFS target by >2; the committed report (`game/assets/audio/sound_report.txt`) is regenerated by the script and a corpus test asserts every LIBRARY file appears in it with PASS.
- **Saves**: gate boots must not worsen the parked live-save-writes defect; the sound gate scene must not write saves at all.

## 8. Non-goals (this slice)

- **Music.** No composed/looped music tracks. The Strip hum, casino room bed, and slot jingles carry the casino; the ranch is carried by nature. A music pass is a parked owner knob.
- **Voice.** Stays out of THIS slice, but its direction is now set (owner 2026-09-04): ponies talk -- pony vocal personality comes from AI-generated spoken dialogue, not chimes forever. The playable character is an OC, so the Twilight greeting line gets replaced with an OC voice; core show ponies get short spoken lines (barks: greetings, pen idle, capture reactions) and slice 4's talk box consumes the same pipeline for NPC dialogue. The VOICE SLICE follows this one: it opens with an ear-test bake-off (same line rendered through 2-3 pipelines: expressive TTS source -> PPP RVC, show-audio RVC source, plain expressive TTS for the OC) that the owner judges by ear BEFORE any mass production, per the standing verdict on the flat Twilight take. In this slice, moments that want a voice use the capture chime or stay silent.
- **Factory interior sound** -- budgeted in Phase 3 slice 6 where its cold register belongs.
- **Reverb/occlusion zones, doppler, dynamic mixing/ducking.** Park; plain distance attenuation is enough at this world scale.

## 9. Parked owner knobs (ledger these at ship)

1. Every individual sound choice -- swappable by manifest edit + script run; candidates recorded per slot.
2. Music pass yes/no, and its register if yes.
3. Footstep loudness/rate (most-heard sound in the game; taste-sensitive).
4. Whether slots want a louder celebration on big wins (kept deliberately modest -- honest-edges casino, not a Vegas skinner box; the owner may want more juice).
5. UI tick character (paper/wood vs classic click).
