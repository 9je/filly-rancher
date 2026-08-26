# Phase 0 asset shopping list

Everything below was checked by hand on **2026-08-26** (HTTP status codes,
file listings, and/or license/downloadable flags pulled live — see method
notes under each entry). Links can still rot after today; if something
404s, search the fallback terms noted inline rather than guessing.

Folder convention: unzip into `assets_raw/<source>/` at the repo root
(that directory is gitignored — see `tools/setup_env.sh`'s `.gitignore`).
Tasks 4+ read from these exact paths, so keep the folder names below.

---

## 1. Blender-native pony pack — tier a, highest priority

**Save to:** `assets_raw/blender-native/`

Original creator is **CreatorOfPony**, but their own DeviantArt download
links have been dead since December 2023. **MythicSpeed's reupload** is the
current canonical source, with a credit request to CreatorOfPony:

- Context page (credits, notes on known issues — not the actual download):
  https://www.deviantart.com/mythicspeed/art/DL-CreatorOfPony-s-Mane-6-Blender-Models-1021478045
  (verified 200 OK; no DeviantArt login needed to *view* it)

MythicSpeed points at a Mediafire folder, and a second party mirrored the
same files to **archive.org**. The archive.org copy is the better pick for
you: it needs no account of any kind and I could verify each file's exact
byte size, which Mediafire's JS-rendered folder listing wouldn't let me do.
**Use these direct links:**

| Character | Direct download | Verified size |
|---|---|---|
| Twilight Sparkle | https://archive.org/download/pony-blender-models/TwilightSparkle_1-0.zip | 14.7 MB |
| Rainbow Dash | https://archive.org/download/pony-blender-models/RainbowDash_1-1.zip | 7.9 MB |
| Fluttershy | https://archive.org/download/pony-blender-models/Fluttershy_1-0.zip | 10.0 MB |
| Applejack | https://archive.org/download/pony-blender-models/Applejack_1-0.zip | 18.5 MB |
| Rarity | https://archive.org/download/pony-blender-models/Rarity_1-0.zip | 13.9 MB |

That's Twilight Sparkle plus 4 others (brief requires Twilight + 2+). Grab
all five if you have the bandwidth — more Mane 6 coverage now saves a
second trip later. The archive also has `NightmareMoon_1-0.zip`,
`PinkiePie_1-0.7z` and a `Treebrary Chandelier.zip` prop, all optional.
Full listing: https://archive.org/details/pony-blender-models

Each zip contains a `.blend` file (per MythicSpeed's notes, these open fine
in modern Blender; Applejack's model ships with "simplify" mode on in the
viewport — harmless, just toggle it off if the mesh looks low-res).

Unzip each character's zip into `assets_raw/blender-native/` so you end up
with `assets_raw/blender-native/TwilightSparkle_1-0/...` etc. (or flatten
however you like — Task 4 will just glob `.blend` files under that folder).

**How I verified this:** fetched archive.org's file-listing API
(`archive.org/metadata/pony-blender-models`) to get the exact filenames,
then `curl`'d each download URL and confirmed HTTP 200 with a real
`Content-Length` header (sizes in the table above are from that). Also
confirmed the DeviantArt context page and the Mediafire folder itself both
return HTTP 200. I could not verify Mediafire's *internal* file listing
(it's rendered client-side by JS, invisible to a plain fetch) — if you'd
rather browse it yourself for more characters, the folder is
https://www.mediafire.com/folder/ijih1mv4e6psp/Pony (no DeviantArt account
needed to open it, per the page — but not independently confirmed since I
couldn't render its contents).

---

## 2. SFM background-pony model pack — tier c probe

**Save to:** `assets_raw/sfm/`

This exists purely to prove the SourceIO import path works — any single
`.mdl` from the pack is enough. I first checked **ReVAmped Ponies / V6**,
but that PonySFM page flags itself obsolete and points at a newer release,
so use the current one instead:

**ReVAmped SFW Ponies — Updated Release** (by DonglySFM), a "feral" (four-
legged background-pony body) base pack:
https://ponysfm.com/revamped-sfw-ponies-updated-release

- Direct download button on the page reads **"Download (93.36 MiB)"** —
  no login wall text appeared anywhere on the page.
- Contains a full Source-engine model pack: `.mdl` (models), `.vmt`
  (materials), `.vtf` (textures), plus the usual `.vvd`/`.vtx` companions
  bundled in the same archive. It covers ~20 named characters (Adult
  Applebloom, Coco Pommel, Maud Pie, Starlight Glimmer, Sunset Shimmer,
  Braeburn, Shining Armor, etc.) — you only need one working `.mdl` for the
  probe, so don't worry about which one Task 4 picks first.
- No PonySFM account required to reach the download link itself. Note:
  the site has a banner saying new-account email verification is
  currently disabled site-wide (bot/captcha issue) — irrelevant here since
  downloading this pack doesn't require an account, just flagging it in
  case you *do* want an account for something else on the site later.

Unzip the whole archive into `assets_raw/sfm/`.

**How I verified this:** `curl`'d the page with a browser user-agent (plain
WebFetch got a 403 from Cloudflare's bot check, but a normal browser UA
passes fine — Cloudflare is JS-challenging bots, not blocking real users).
Confirmed HTTP 200, found the literal download button text and file size in
the HTML, and found the "this resource is obsolete, click here for a newer
version" banner on the old V6 page that redirects to the one listed above.

---

## 3. Map props (Sketchfab) — tier b

**Save to:** `assets_raw/props/`

I checked every candidate against Sketchfab's own API
(`api.sketchfab.com/v3/models/<uid>`), which reports `isDownloadable` and
`license` authoritatively — page-scraping alone was unreliable (Sketchfab
is a heavy JS SPA and some pages returned useless static HTML). Two
`discopears` "Ponyville Building" models I found first (`OGB_2`, `Pink_B`)
looked perfect thematically but the API says `isDownloadable: False` — they
are view-only, so I dropped them. Everything below is confirmed
`isDownloadable: true` with a real license.

**Buildings (3):**

| Model | License | Link |
|---|---|---|
| Low Poly MLP Ponyville Style Medieval House | Free Standard | https://sketchfab.com/3d-models/low-poly-mlp-ponyville-style-medieval-house-219d6a66c06c4da299a20fc874b9fce1 |
| Low-Poly Stylized Cottage | CC Attribution | https://sketchfab.com/3d-models/low-poly-stylized-cottage-6bcf4819b1c542b584153504f97bab47 |
| Stylized Cottage | CC Attribution | https://sketchfab.com/3d-models/stylized-cottage-c313cc0200804b02976e520a9ce08ce5 |

**Tree/foliage set (1):**

| Model | License | Link |
|---|---|---|
| Stylized Low Poly Tree Pack for Free (18 trees) | CC Attribution | https://sketchfab.com/3d-models/stylized-low-poly-tree-pack-for-free-23d062eb4c8e4770a349cb83c6166bb9 |

For each: open the link, click **Download 3D Model**, choose the **glTF**
format in the download dialog (Sketchfab offers glTF for every downloadable
model as a standard export option alongside the original/source format).
A free Sketchfab account is required to click Download (their standard
click-through, not a paywall — all four models above are $0). Unzip each
download into `assets_raw/props/` as its own subfolder (e.g.
`assets_raw/props/ponyville-medieval-house/`, etc.) so Task 4/8 can glob
per-model.

**How I verified this:** queried the Sketchfab public API per model UID and
recorded the raw `isDownloadable` and `license.label` fields shown in the
table (not inferred from page text, which Sketchfab renders inconsistently
depending on whether Cloudflare serves the static shell or the full SPA).

---

## 4. Voice tooling note (no download needed yet — Task 9 handles it)

**Hay Say** (hydrusbeta) — the pony-voice UI mentioned in the plan:
https://github.com/hydrusbeta/hay_say_ui

Confirmed from the README: it wraps so-vits-svc (3.0/4.0/5.0), Controllable
TalkNet, and RVC behind one browser UI, but it is **Docker-based** — setup
downloads roughly 49 GB of Docker images across separate containers for the
UI and each backend architecture, then `docker compose up`. If you don't
want to install Docker, skip this for now; Task 9 will only need it if we
decide to do local voice conversion.

There's a `haysay.ai` domain that resolves (HTTP 200), but I could not
confirm it's a genuine no-install hosted service — the page returned only a
loading shell with no content when fetched, and the README's install
instructions read as self-host-only (no mention of a hosted option, and it
explicitly says the project isn't set up for Google Colab either). Treat
`haysay.ai` as unverified — check it yourself in a browser before assuming
it saves you the Docker install.

**No-Docker alternative — hosted RVC space:** the Pony Preservation Project
publishes RVC-format pony voice model weights at
https://huggingface.co/therealvul/RVCv2 (confirmed reachable, HTTP 200).
Rather than a pony-specific Space (I couldn't find one still running), pair
those weights with a live, general-purpose hosted RVC Space that lets you
load any RVC model by URL: **Ultimate RVC**
(https://huggingface.co/spaces/JackismyShephard/ultimate-rvc). Confirmed via
Hugging Face's Space API: `runtime.stage: RUNNING`, not disabled, not
gated, free `cpu-basic` hardware, last updated March 2026, MIT-licensed,
185 likes — this is a real, currently-live, no-install option. No download
needed now; this is just so the option is on record for Task 9.

---

## 5. Hand-off

Once everything above is unzipped into place:

```
assets_raw/
  blender-native/   <- Task 3.1 zips, unzipped
  sfm/              <- Task 3.2 zip, unzipped
  props/            <- Task 3.3 zips, unzipped (one subfolder per model)
```

Tell Claude: **"assets are in"** — that's the signal to resume at Task 4.
You don't need to wait for every optional extra (more Mane 6 characters,
the second tree pack, etc.) — just the tier-a Blender pack (at minimum
Twilight Sparkle + 2 others), the one SFM pack, and the 3 Sketchfab props.
If the Sketchfab or SFM downloads lag behind the Blender pack, that's fine
— Tasks 6/8 (which consume them) can be deferred independently; Task 4
only needs the Blender pack to start.
