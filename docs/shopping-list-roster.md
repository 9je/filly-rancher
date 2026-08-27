# Canon character shopping list

> **Supersedes the filly-only framing this doc started from.** The brief began
> as "find as many fillies/foals as possible" for the Filly Rancher pivot; the
> owner then widened it explicitly: *"I want to include as many canon
> characters as we can find — honestly, all of them."* Young ponies are still
> the headline (the game is *about* catching fillies and foals, and this
> research turned up far more of them than expected), but everything below
> also covers Mane 6 variants, princesses, villains, and background/fan-
> favourite adults. If a future doc needs "just the fillies," §2 is that list.

Everything below was checked by hand on **2026-08-27** — HTTP status codes,
byte sizes, and (for every PonySFM link) an actual authenticated download
request that returned a real file, not just a page load. See "How I verified
this" under each section. Links can rot after today.

**Folder convention**, same as `docs/shopping-list.md`: unzip into
`assets_raw/<source>/` at the repo root (gitignored). This doc adds no new
top-level folders — new tier-a downloads go in the existing
`assets_raw/blender-native/`, new tier-c downloads in the existing
`assets_raw/sfm/`.

**A note on PonySFM downloads specifically**, discovered while verifying this
list (not documented in the original shopping-list.md, which only downloaded
one PonySFM pack and didn't need to press on this): the `Download (x MiB)`
button's `href` carries a **session-bound token**. A token copied from one
`curl` and replayed later, or from a different cookie jar, 404s — I hit this
myself on the first attempt. The fix is trivial: `curl -c jar -b jar` the
resource page, then immediately `curl -c jar -b jar` the `/rev/<id>/download?token=...`
URL found in *that same response* (referer header on for good measure). No
PonySFM account is needed for any link below — this is a same-session replay
requirement, not a login wall — but "fetch page, then fetch its own token"
has to happen as one sequence, not two independent one-off requests.

---

## 0. Already on disk — the biggest win, zero downloads needed

**`assets_raw/sfm/SFM Ready Compiled Files/Models/reVAmped_ponies/`** (from
`docs/shopping-list.md` §2, the ReVAmped SFW Ponies pack) contains **46
distinct named-character `.mdl` files**, not the "~20" the original shopping
list estimated (that number was a description-page guess made before anyone
opened the archive; this run actually listed the directory). Every one of
these needs zero further downloading — only conversion
(`tools/convert_mdl.py`, tier c, §5 of `docs/pipeline.md`) and, per that
doc's Task 6 verdict, per-model manual work (bodygroup selection, no baked
animation).

```
aloeblossom, applebloom, applejack, berrypunch, bonbon, braeburn, caramel,
carrottop, changelingdrone (+ changeling_carapace clothing), cheerilee,
cloudchaser, cocopommel, derpyhooves, drwhooves, flitter, fluttershy,
kerfuffle, lightningdust, limestonepie, lotusblossom, lyra, mane_allgood,
marblepie, maudpie, milkyway, minuette, nightlight, octavia, pinkamena,
pinkiepie, pokeypierce, rainbowdash, raricow, rarity, redheart, scootaloo,
shiningarmor, soarin, songbirdserenade, spitfire, starlightglimmer,
sunsetshimmer, sweetiebelle, trixie, twilightsparkle, vinylscratch
```

That's most of the "background and fan-favourite" wishlist in one already-
downloaded archive: Braeburn, Cheerilee, Coco Pommel, Derpy Hooves, Dr
Whooves, Lyra, Bon Bon, Octavia, Vinyl Scratch, Maud Pie, Shining Armor,
Soarin, Songbird Serenade, Spitfire, Starlight Glimmer, Sunset Shimmer,
Trixie are all in there, plus the full Mane 6.

**Important caveat, carried over from `docs/pipeline.md` §1/§2 (shopping-
list.md's own note):** this pack's `applebloom`, `scootaloo` and
`sweetiebelle` are the **aged-up adult versions** of the CMC ("Adult
Applebloom" per the original shopping list's own description of this pack),
*not* fillies. They're valuable roster entries in the broadened scope, but
they do not answer the filly-count question — §2 below is where the actual
young versions of these three live.

**A separate agent is currently working the animation-retargeting problem for
this exact pack** — nothing in this doc duplicates that; it's mentioned here
only because it changes the economics: if that effort succeeds, these 46
characters (and anything sharing their skeleton, see §6) become the cheapest
roster entries in the game, cheaper than every new download below.

**How I verified this:** `find` on the actual unzipped directory tree
(already on disk from Phase 0), not a claim from any web page.

---

## 1. Tier a bonus — two more Blender-native characters in the *same* archive

**Save to:** `assets_raw/blender-native/`

`docs/shopping-list.md` §1 already found and partially downloaded the
CreatorOfPony/MythicSpeed archive.org mirror (Twilight, Rainbow Dash,
Fluttershy, Applejack, Rarity — all five present on disk). Its own file
listing has two more from the *same pack*, not yet downloaded:

| Character | Direct download | Verified size |
|---|---|---|
| Nightmare Moon | https://archive.org/download/pony-blender-models/NightmareMoon_1-0.zip | 8,037,533 bytes (7.7 MB) |
| Pinkie Pie | https://archive.org/download/pony-blender-models/PinkiePie_1-0.7z | 7,831,230 bytes (7.5 MB) |

No fillies exist in this archive or anywhere in the CreatorOfPony/MythicSpeed
Blender-native family — see §6. This is the ceiling of tier-a content: 7
characters total, 5 already converted, 2 more free for the taking.

**How I verified this:** re-fetched `archive.org/metadata/pony-blender-models`
(same technique as the original shopping list) and confirmed both files are
still listed with those exact byte sizes; `curl -I` on both direct download
URLs returned `302` redirects to `archive.org`'s CDN host (the normal
archive.org download flow, same pattern the original list's five links use),
not a 404 or error page.

---

## 2. Tier c — fillies, foals, and young characters (PonySFM)

**Save to:** `assets_raw/sfm/` (new subfolders — these are separate resources
from the already-downloaded `reVAmped_ponies` pack, so keep them apart, e.g.
`assets_raw/sfm/enhanced-fillies-model-pack/`, `assets_raw/sfm/mane-6-foals/`,
etc., one per row below).

All of the below are PonySFM resource pages, fetched with a browser
user-agent (`ponysfm.com` Cloudflare-challenges plain `curl`/WebFetch without
one — same finding as the original shopping list's §2). **Every single row
was independently confirmed downloadable**, not just page-reachable: I
fetched each resource page into a cookie jar, extracted its download token,
and replayed that token in the same session, and got back a real
`Content-Disposition: attachment` file (not a login redirect or a 404). No
account was needed for any of them.

### The headline find: Enhanced Fillies Model Pack — 10 fillies in one archive

| | |
|---|---|
| Page | https://ponysfm.com/enhanced-fillies-model-pack |
| Size | 7.62 MiB (`.7z`, confirmed 7,987,246 bytes on actual download) |
| Contains | **Apple Bloom, Babs Seed, Diamond Tiara, Flurry Heart, Nyx, Scootaloo, Silver Spoon, Snowdrop, Sweetie Belle, Woona** (per the page's own tag list) |
| Format | GMod/SFM `.mdl` — "A proper GMOD port" per the page's own changelog |
| Credits | AeridicCore (original models + "enhanced filly base"), ported/polished by MythicSpeed |

This is the single best return on any link in this document: ten distinct
named young characters in one archive, including the full Cutie Mark
Crusaders (young), Diamond Tiara and Silver Spoon (young), Flurry Heart, and
two non-mainline-canon-but-widely-recognized fan-canon foals (Nyx — Twilight's
adopted filly from the *Past Sins* fanfic; Woona — a chibi/filly stylization
of Luna; Snowdrop — a well-known fan-favourite blind pegasus filly). The page
also links a companion **source-file** archive:
https://ponysfm.com/enhanced-ponies-source-files (26.90 MiB, DMX/SMD format,
confirmed downloadable) — its own description says the rigging was **"borrowed
from the reVAmped base"**, which is the load-bearing clue for §6's rig
judgement.

### Other filly/foal/young-character resources

| Resource | Page | Size | Notes |
|---|---|---|---|
| Mane 6 Foals | https://ponysfm.com/Mane-6-Foals | 10.63 MiB | Title claims foal versions of the whole Mane 6; page text only credits "foal body made by FillerArtist" and doesn't itemize the roster — **unconfirmed exact character list, inspect after download** |
| Cutie Mark Crusaders Pack v1.0 | https://ponysfm.com/cutie-mark-crusaders-pack-v-1-0 | 55.95 MiB | Large — likely CMC + related props/poses bundled; roster not itemized on the page, **unconfirmed** beyond the title's promise of the 3 CMC |
| [DL] CMC - Cutiemark Crusaders Overhaul | https://ponysfm.com/dl-cutiemark-crusaders-overhaul | 5.57 MiB | Likely an alternate/older CMC rig from the "Overhaul" series (same lineage as the Diamond Spoon/Silver Tiara and Babs Seed overhauls below) — probably redundant with the Enhanced pack's CMC, listed for completeness |
| [DL] Diamond Spoon and Silver Tiara Overhaul | https://ponysfm.com/dl-diamond-spoon-and-silver-tiara-overhaul | 3.04 MiB | (title's word order is the page's own, not a typo here) — an older/alternate Diamond Tiara + Silver Spoon; the Enhanced pack likely supersedes it |
| [DL] Babs Seed Overhaul | https://ponysfm.com/dl-babs-seed-overhaul | 1.40 MiB | Alternate/older Babs Seed; Enhanced pack likely supersedes it |
| Pipsqueak Final Release DL | https://ponysfm.com/pipsqueak-final-release-dl | 24.82 MiB | Standalone; ships a Nightmare Night costume variant per its own description |
| Filly Twilight Sparkle | https://ponysfm.com/filly-twilight-sparkle | 3.22 MiB | Standalone |
| Filly Starlight Glimmer | https://ponysfm.com/filly-starlight-glimmer | 2.67 MiB | Standalone |
| Filly Tempest | https://ponysfm.com/filly-tempest | 1.47 MiB | Standalone (young Tempest Shadow, the Movie villain) |
| Filly Sunset Shimmer | https://ponysfm.com/filly-sunset-shimmer | 1.75 MiB | Standalone |
| Filly Colgate | https://ponysfm.com/filly-colgate | 1.54 MiB | Standalone (background character) |
| Filly Flurry Heart | https://ponysfm.com/filly-flurry-heart | 3.39 MiB | Standalone — likely an alternate to the Enhanced pack's Flurry Heart |
| Filly Fluttershy 2.0 | https://ponysfm.com/filly-fluttershy-2-0 | 8.50 MiB | Standalone; DeviantArt-origin (`natorni`), mirrored on PonySFM with a working direct token |
| Tia Filly | https://ponysfm.com/tia-filly | 2.22 MiB | Filly Celestia ("Tia" is the show's own nickname for young Celestia, used in the flashback episodes) |
| Filly Source Pack | https://ponysfm.com/filly-source-pack | 10.57 MiB | Ambiguous — could be SMD/QC compile sources for a shared filly base rig (relevant to §6) or a generic prop/pose pack; page gives no description, **inspect after download** |

**How I verified this section:** for every row, `curl` with a cookie jar
fetched the resource page (browser UA, 200 OK), extracted the
`/rev/<id>/download?token=...` href from that response, then replayed it in
the same jar with a `Referer` header — every single one returned HTTP 200
with a real `Content-Disposition: attachment; filename="...")` header (zip or
7z), confirmed via a 1-byte range request rather than downloading the full
file for the smaller/less-central rows. The Enhanced Fillies pack itself was
downloaded in full (7,987,246 bytes, `7-zip archive data` per `file`) as the
one end-to-end proof this technique produces a real usable archive, not just
a 200 status.

---

## 3. Tier c — princesses, villains, and other named adults not already on disk

**Save to:** `assets_raw/sfm/` (new subfolders, same pattern as §2)

Same PonySFM verification method as §2 (fetch page → extract token → replay
in-session → confirm real attachment). All confirmed downloadable, no login.

| Character/pack | Page | Size | Notes |
|---|---|---|---|
| Princess Cadance | https://ponysfm.com/princess-cadence-275b6d74-361e-409d-bac6-4101e32f2a05 | 10.33 MiB | |
| Princess Luna (Season 1 model) | https://ponysfm.com/princess-luna-s1 | 8.07 MiB | Canon early-model Luna, not a recolor/alt |
| Queen Chrysalis 1.2 | https://ponysfm.com/queen-chrysalis-1-0 | 8.59 MiB | (page's own title says "1.2", slug says "1-0" — same resource) |
| Lord Tirek | https://ponysfm.com/lord-tirek | 2.93 MiB | |
| Discord | https://ponysfm.com/discord | 4.61 MiB | |
| Granny Smith | https://ponysfm.com/granny-smith | 2.69 MiB | Page notes it's "a permitted re-upload" after the original uploader's account was deactivated — provenance is a step removed from the original author, flagged per this project's dead-link caution |
| Big Mac [DL] | https://ponysfm.com/big-mac-dl | 2.02 MiB | |
| Zecora (Overhaul Ver.) | https://ponysfm.com/zecora-overhaul-ver | 3.09 MiB | Description says it uses "the new luna rig" — another rig-lineage clue for §6 |
| AK Yearling (Daring Doo) | https://ponysfm.com/ak-yearling-daring-doo | 6.67 MiB | Daring Do's real identity/pen-name in-universe; this is the Daring Do character model |
| **Nightmare Mane 6** (multi-character) | https://ponysfm.com/nightmare-mane-6 | 21.81 MiB | 6 "nightmare"/corrupted-style recolors of the Mane 6 — stylistic variants, not 6 new canon identities, but a lot of visual variety for one archive |
| **ReVAmped Blind Bag Pack #1** (multi-character) | https://ponysfm.com/revamped-blind-bag-pack-1 | 60.94 MiB | Description: "six merch-exclusive blind bag ponies" bundled in one file, labeled "Blindbag" internally — exact character names **not confirmed**, page gives no roster, inspect after download |

Not chased further in this pass, for time: Celestia (non-"Daybreaker",
non-recolor canon adult — searches kept surfacing recolors/crossovers/alt-
universe variants rather than a plain canon model; worth a second look before
assuming she isn't obtainable), Nightmare Moon proper on PonySFM (already
covered for free in §1's tier-a bonus, so not chased here), Big
Macintosh's/Applejack's wider family, Wonderbolts beyond Soarin/Spitfire
(already on disk, §0).

**How I verified this section:** identical method to §2 — page fetch, token
extraction, same-session replay, `Content-Disposition: attachment` confirmed
via range request for every row.

---

## 4. Tier b — Sketchfab (thin results, needs a free account to actually click Download)

Per `docs/shopping-list.md` §3's own finding, Sketchfab's download button
needs a logged-in browser click regardless of price — this project verifies
`isDownloadable` via the API rather than trusting the page, same as before.

| Model | License | isDownloadable (API) | Link |
|---|---|---|---|
| My Little Pony Base | CC Attribution | **True** | https://sketchfab.com/3d-models/my-little-pony-base-0a1e010a89324e33977f2961d6af6465 |
| Pony luna | CC Attribution | **True** | https://sketchfab.com/3d-models/pony-luna-144fe93ac4f54651b25f753067e80d45 |
| Simple Filly Model (MLP) | — | **False** | (view-only; dropped, matches the pattern shopping-list.md already found with Sketchfab MLP buildings) |

"My Little Pony Base" is a generic, unbranded pony mesh (73,730 vertices) —
worth a look for the recolor-base idea in the brief, but I could not confirm
it's rigged for animation vs. a static sculpt from the API alone. "Pony luna"
(95,324 vertices) is redundant with §3's Princess Luna S1 but in a completely
different pipeline (glTF/FBX, tier b) — useful as a fallback if the SFM/tier-c
path stalls on Luna specifically.

**How I verified this:** `api.sketchfab.com/v3/search` and
`api.sketchfab.com/v3/models/<uid>`, reading `isDownloadable` and
`license.label` directly from the JSON — same method as the original list's
§3, not page-scraping. Sketchfab search for `mlp filly` / `my little pony
filly` otherwise returned almost nothing (one non-downloadable filly result,
one non-downloadable CMC clubhouse prop) — Sketchfab is not a productive
source for this roster, confirming the original list's assessment that it's
a weak channel for this project generally.

---

## 5. Not chased (leads found, not verified — flagging rather than guessing)

- **Steam Workshop "Filly Pack Overhaul"** — a web search surfaced this as
  containing the CMC, Nyx, Woona, Diamond Tiara, Silver Spoon, Babs Seed, and
  Snowdrop (i.e., overlapping heavily with §2's Enhanced Fillies pack,
  possibly its ancestor). Not verified: Steam Workshop items require the
  Steam client or `steamcmd` to actually fetch, which is a different
  toolchain than anything else in this doc, and I did not set that up. If the
  PonySFM copies in §2 turn out incomplete or broken on import, this is the
  fallback to try, via `steamcmd +workshop_download_item`.
- **PonySFM's own site search** almost certainly has more — I ran ~25 targeted
  queries (character names, "filly", "foal") and stopped once patterns became
  clear (a handful of prolific packagers — DonglySFM/reVAmped, MythicSpeed/
  Enhanced, "Overhaul" series authors — account for most named-character
  coverage). A more exhaustive crawl would likely surface more one-off named
  characters (Cheese Sandwich, Gilda, the Flim Flam Brothers, Ember, Thorax,
  and further Wonderbolts turned up as page titles in passing during
  searches for other things, but I did not open or verify any of them).

---

## 6. Assessment

### How many distinct canon characters are realistically obtainable, by tier?

| Tier | Confirmed now | Notes |
|---|---|---|
| Already on disk (tier c, §0) | **46** | Zero downloads needed; adult-aged, includes adult CMC |
| Tier a — Blender-native (§1) | **7** (5 converted, 2 more free) | Ceiling for this family — no fillies exist in it anywhere |
| Tier c — new, individually itemized (§2 + §3) | **28 solidly named** (10 from the Enhanced Fillies pack, Pipsqueak, 8 standalone fillies/young characters, and 9 solo adults: Cadance, Luna S1, Chrysalis, Tirek, Discord, Granny Smith, Big Mac, Zecora, Daring Do) | See exact roster in §2/§3 tables |
| Tier c — packs with unconfirmed rosters | **+18 to +30 possible** | Mane 6 Foals (≤6), CMC Pack v1.0 (≥3), CMC/Diamond-Spoon/Babs-Seed "Overhaul" trio (likely redundant with Enhanced Fillies, ≈0 net new), Nightmare Mane 6 (6, but recolors not new identities), Blind Bag Pack (6, names unconfirmed) |
| Tier b — Sketchfab (§4) | **2** (1 generic base, 1 Luna redundant with tier c) | Weak channel, confirmed again |

**Bottom line: a floor of 81 distinct character models (46 on disk + 7
tier-a + 28 newly-verified tier-c), with a realistic upside toward 100+**
once the unconfirmed-roster packs are opened and deduplicated against what's
already counted. That is an entirely different game than the "5 vs. 40"
question the brief raised — collection-game viability is not in doubt on
numbers alone. The real constraint, per below, is not *how many models* but
*how many animation-compatible rig families* they fall into.

**Fillies/foals specifically** (the part of this that answers the original,
narrower brief): CMC ×3, Diamond Tiara, Silver Spoon, Babs Seed, Flurry
Heart, Nyx, Snowdrop, Woona (Enhanced Fillies pack) + Pipsqueak + Filly
Twilight, Starlight Glimmer, Tempest, Sunset Shimmer, Colgate, Fluttershy,
Tia (Celestia) = **17 solidly confirmed young characters**, before counting
whatever's actually inside "Mane 6 Foals" and "Cutie Mark Crusaders Pack
v1.0". That comfortably clears "collection game," on its own, without
touching the broader adult roster at all.

### Rig-family judgement, per tier (this is the number that actually gates cost)

**Tier a (CreatorOfPony/MythicSpeed Blender family): confirmed fact, not
judgement, per `docs/pipeline.md` §6** — the three converted rigs share a
byte-identical 93-bone core skeleton, one animation set drives all of them,
and the two new bonus characters in §1 are from the *identical* pack/creator/
format, so — **judgement, not independently verified since I did not download
or inspect them** — very likely join that same family for free. **But this
family contains zero fillies.** Nothing in §2's filly haul is tier-a. This is
the load-bearing limitation of the whole roster: the one rig family with a
*proven* free animation set cannot grow the filly count at all, only the
adult count (by 2, to 7 total).

**Tier c (SFM/Source-engine — everything in §0, §2, §3): NOT one skeleton
family, and the evidence points to several sub-families, not one.**
`docs/pipeline.md` §5's Task 6 verdict already established this for the
on-disk reVAmped pack alone ("viable... NOT proven at catalog scale... says
nothing about the wider crowd-sourced catalog") and everything found in this
pass reinforces rather than overturns that:

- **One genuine positive signal for the fillies specifically:** the Enhanced
  Fillies Model Pack's own companion source-file page states its rigging was
  *"borrowed from the reVAmped base"* — i.e., its author explicitly built the
  filly rig as a derivative of the same base the already-on-disk 46-character
  pack uses. **This is a judgement, not a measurement** — I did not import
  either model into Blender/SourceIO and diff bone names the way
  `docs/pipeline.md` §6 did to *prove* tier-a's shared skeleton (that requires
  running the actual SourceIO conversion, out of scope for a research-only
  pass). If it holds up, the Enhanced Fillies pack's 10 characters could ride
  on whatever animation work the other agent is doing for the on-disk
  reVAmped pack — the single most valuable open question this doc raises.
  **The concrete next step, for whoever picks this up:** `bpy.ops.sourceio.mdl`
  one Enhanced Fillies `.mdl` next to `revamped_applebloom.mdl` and diff bone
  names, exactly as `docs/pipeline.md` §5 already did for the one tier-c
  probe against tier-a.
- **Everything else in §3 (Cadance, Luna, Chrysalis, Tirek, Discord, Granny
  Smith, Big Mac, Zecora, Daring Do) is a one-off upload from a different,
  unrelated individual packager** — PonySFM has no site-wide shared skeleton
  convention, multiple named "base" lineages exist (reVAmped, the Enhanced
  Mares/Stallions DMX kit, whatever underlies Zecora's own "new luna rig"
  mention), and nothing here was cross-checked against another. **Judgement:
  expect most of §3 to need its own per-model animation work or a bone-name
  remap layer**, not a free ride — this is the direct continuation of
  `docs/pipeline.md` §5's own "NOT proven at catalog scale" warning, now with
  9 more specific characters it applies to.
- The two "Overhaul"-series packs (Diamond Spoon/Silver Tiara, Babs Seed,
  CMC) and Nightmare Mane 6 all read, from their descriptions, as belonging to
  yet another loose cluster of related community riggers (the "Overhaul"
  naming convention recurs across several unrelated PonySFM authors per the
  search results) — plausible partial rig-sharing *within* that cluster,
  unconfirmed, and almost certainly *not* shared with reVAmped or Enhanced.

**Tier b (Sketchfab): no rig claim possible.** Neither downloadable model's
skeleton was inspected (would require the actual download-and-import a
research pass doesn't do); treat both as isolated one-offs.

### Cheapest wins, ranked

1. **The 46-character reVAmped pack, §0 — already on disk, zero downloads,
   and (per the other agent's in-flight work) may shortly have working
   animations.** The single best-value item in this entire document, and it
   cost nothing new today.
2. **The Enhanced Fillies Model Pack, §2 — 10 fillies in one 7.62 MiB
   archive, one download, and a real (if unverified) chance of inheriting the
   same animation work as #1** if the "borrowed from the reVAmped base" claim
   holds up under inspection. If it does, this pack alone could turn the
   filly roster from "17 confirmed, most needing individual rig work" into
   "17 confirmed, 10 of them nearly free."
3. **Nightmare Moon + Pinkie Pie, §1 — free extension of the one skeleton
   family already *proven* (not judged) to share animations**, at the cost of
   two more downloads through an already-working pipeline.
4. Everything in §3 — real, verified, downloadable, but each one should be
   budgeted as its own animation cost unless/until proven otherwise.
