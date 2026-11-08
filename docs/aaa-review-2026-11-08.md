# AAA pass review, 2026-11-08

Art direction and UX critique of the v1-overhaul build, from the owner's 2026-11-08 playtest
(screenshots [56] to [101] in
/tmp/claude-1000/-home-admin-Documents-filly-rancher/ecb51c6d-c04e-448f-a46c-a727201b8f91/images/),
docs/playtest-2026-11-08.md, docs/ideas-2026-11-08.md, and the code under game/ui, game/world
and game/shaders. Nothing was changed. This is the input to the next sprint's plan.

The owner's framing: "doesn't feel like a bundle of assets anymore, but UI still severely
lacking, especially icons, they universally suck, and overall the world look still feels like
a cheap Godot game. I want this to be a serious AAA pass."

The short version: the last two sweeps fixed what was broken. Nothing was ever *designed*.
There is no art bible beyond GDD section 8's half page, no icon pipeline (every icon is a
draw call written by hand in GDScript), no UI kit (there is a palette constant file and a
Theme that sets font sizes), and the lighting rig is Godot's photoreal defaults running
under a cel shader. Each of those is a system-level gap, and every screen the owner
complained about is a symptom of one of them. Fixing screens one at a time again will
produce the same verdict in a month.

---

## 1. Verdict: the five reasons it reads as cheap, ranked

### 1. The lighting rig and the shading model are fighting each other
[68][69][74][76][77][82][86][88][94]

game/world/ranch.tscn runs a photoreal stack: PCSS soft directional shadows out to 160 m in
four cascades, SSAO at intensity 0.45, glow, aerial-perspective fog, Filmic tonemap at white
6 and exposure 0.8. Under that sits game/shaders/toon.gdshader, which wants two flat tones.
The result is neither. Big smooth meshes (hills, haystacks, house walls) get a soft gradient
terminator, SSAO paints grey dirt into every crease and under every fence rail, the cascaded
shadows of trees and buildings are stencilled across house fronts and the far hill as
jagged olive blotches [68][69][76][77], and a shadow lies on the path with nothing casting it
[82]. The toon shader's own comment admits the compromise: the N.L step is hard but the
shadow term is ramped 0.2..0.8 because PCSS sampling noise turned a hard step into salt and
pepper. So the "two tone" look is a soft gradient on anything bigger than a pony [57].

At night it is worse. SkyRig parks the sun at minus 12 degrees and keeps `shadow_enabled`,
so a light under the ground rakes upward and projects tree silhouettes sideways onto walls
[68][69]. The hill glows teal because the ground half of the sky and the fog light colour
are day values dimmed, not a night palette [69]. Night is an underexposed day.

This is the single biggest reason for "cheap Godot": the default Godot look *is* soft
shadows plus SSAO plus Filmic on untextured meshes, and that is what is on screen.

### 2. Every icon is hand-rolled geometry with no shared language
[60][62][63][68][70][71][73][75][81][85][93][96][97]

There are at least six separate icon "systems", none of which share a grid, an outline
weight, a shading rule or a palette:
- game/world/place_sign.gd `icon_texture()`: a 128x128 per-pixel CPU loop of if-statements
  (the coin with a "b" in it, the crate, the "#" fence, the scroll). These are also the compass
  and objective icons [60][68][75].
- game/ui/catch_icon.gd and shop_icon.gd: polygons and lines on a 30x30 grid (the horn, the
  wing, the horseshoe, the apple, the foods, the gear) [81][97].
- game/ui/rarity_glyph.gd: circle / diamond / star / crown outlines [85].
- game/ui/casino_paint.gd: chips, suits and slot symbols as polygons; the clubs come out as
  broken dots [96], the slot reels as flat clip-art [70].
- game/ui/pantry_icon.gd, hours_icon.gd: more one-off drawings.
- game/scenes/test/decor_icons.gd and style_icons.gd: the one good route, baked 3D renders.

The Depot rows use a generic head-and-shoulders circle for every pony [73][85]. The fingerpost
carries a "#" for Pens, a "b" coin for Market, a crate for Depot and a pink star for the
Palace, none of them on the same plate or weight [60][63]. At compass size they are smudges.
The owner's "universally suck" is accurate because there is no icon *pipeline*, only drawing
code.

### 3. The UI is three kits stapled together, all of them text-first
[66][70][71][73][84][85][89][90][92]

Menus are translucent plum glass (Depot, Market, pause, casino frame). The HUD, letters and
catch card are cream paper with a purple border. The tables are green felt. The compass is a
fourth thing (a semi-opaque cream bar). Each is a StyleBoxFlat rounded rectangle with a 2 to
4 px border; there is no texture, no depth, no illustration, no motion beyond a 0.22 s scale
on toasts. One font (Fredoka) does every job from a 128 px sign to a 17 px caption, and at
small sizes its round forms blur [71][85]. The information design is sentences: "Lark Wish
moved into the pen. It is now full." [77], "Cloudsdale Weather Corporation: 55th shipment
received. 105 bits off your balance, 18,535 to go. +26 bits for you." [80], "Pick a stake on
the stake row, then Enter to play. Esc leaves." [71]. Every reference title says the same
things with a pictogram and a number.

menu_style.gd's own header documents the history: six menus each had their own palette and
footer, and the fix was to centralise the constants. That was a consistency fix, not a design.

### 4. The world is a kit-bash of four sources at three scales, with primitives still in it
[60][61][63][64][74][76][77][80][98]

PonySFM buildings (good), converted Kenney props (the lamp posts, the white fences, the dock),
in-code BoxMesh/PrismMesh scenery (signs, fingerpost arms, the Strip's lamps, the pens'
rails, the brick plinth), and a terrain that is a two-green lerp with a noise break-up too
subtle to see. Signs are 2D cards that vanish edge-on [61][62]. The fingerpost has five arms
with a drooping Pens board [63]. The barn is smaller than its haystacks, the well is knee
high [76][83]. The casino's brick base and path cut off hard against grass [74], the arcade
props stand on a bare paving slab outside [64]. The lake has reeds as triangles and dock
planks as flat dark boxes [98]. The town is packed into 30 m while the rest of the map is
empty [60].

MISSION.md's addendum says "never ship environments built from primitive shapes or CSG". The
`building.gd` fallback shell and every sign, rail, post and plinth still are.

### 5. The ponies are the standard, and everything beyond the body model is undercooked
[56][57][58][63][65][68][69][76][82][83][86][95]

The player's mane is a flat cutout with a hard edge over one eye [56][63]; NPC tails are
shapeless blobs [68][76]; the mane strands in [58] read as a stiff white sheet. The outline
fades out past 18 m so distant ponies become colour blobs with no drawing [94]. The player is
half-transparent at ordinary camera distance in three shots [69][83][95] (camera_rig.gd:
FADE_START 1.7 m from the withers pivot, so the default arm is inside the fade). Spike's eyes
have no white or highlight [82]. The casino crowd is one grey-purple pony cloned six times
and frozen [65] when the random generator that MISSION.md says every NPC must come from is
sitting right there. Nothing in the world idles, breathes, blinks or plays.

---

## 2. Area by area

Each area: what is wrong, what the reference does concretely, the Godot 4 technique, and
where it agrees or disagrees with docs/ideas-2026-11-08.md.

### 2.1 World look and lighting

**Wrong.** See verdict 1. Specifically, in ranch.tscn: `ssao_enabled = true` (GDD 8.3 says
off or very low), `tonemap_mode = 2` Filmic at `tonemap_white = 6.0` (crushes flat colour
into mud; GDD says low-contrast AgX or Filmic), `directional_shadow_max_distance = 160`,
`shadow_blur = 0.6` plus PCSS angular distance (the comment in toon.gdshader names 0.9 and
1.1), sun shadows on at night. The sky is ProceduralSkyMaterial with no clouds and no sun
disc. The terrain is the lerp plus 5% noise. The rain is streak particles. Weather dims the
whole frame rather than regrading it.

**Reference.** The show's backgrounds: flat vector shapes in two or three value steps, no cast
shadows at all except a soft oval under each character, foliage as stacked rounded blobs with
a darker band at the bottom, a sky with a smooth gradient and two or three soft clouds, and
a strong palette shift between day (warm, saturated) and night (blue, with warm lit windows).
Slime Rancher: a gradient-ramp toon, a saturated sky that the fog fades to, hard-edged blob
shadows, visible grass texture, AO baked in the textures. Animal Crossing NH: a textured
ground with tufts, blob shadows, and a night that is readable because lamps and windows are
the brightest things on screen. A Short Hike: tiny textures, but every object has value
separation from its neighbour.

**Technique.**
- Decide the rule: real-time sun, hard cascaded shadows, toon-stepped. Set the project's
  `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality` to hard, drop
  `light_angular_distance` and `shadow_blur` to 0, cap `directional_shadow_max_distance` at
  about 60 m with `directional_shadow_fade_start` 0.8. With hard shadows the noise goes away
  at source and toon.gdshader can step ATTENUATION tightly again (0.45..0.55) so cast shadows
  are flats, the way the band is.
- Replace the N.L smoothstep with a 1D ramp texture (light / mid / shadow, authored once as a
  16x1 PNG) so the look is tunable by an artist and shared by terrain, props and ponies.
- `ssao_enabled = false`. Bake AO into vertex colour in Blender for the buildings and props
  (one Cycles bake per glb, multiply in the shader), and put a soft blob shadow quad (a Decal
  or a transparent QuadMesh with a radial texture) under every pony, NPC and prop. This is
  what makes things sit on the ground in the show and in Slime Rancher.
- Night: when the sun's elevation is below 0, turn its shadows off and swap to a moon
  DirectionalLight3D at 35 degrees elevation, energy 0.25, blue (0.45, 0.55, 0.85), hard
  shadows. Windows get an emissive material at night (emission 2.0, glow picks it up), lamp
  posts get an OmniLight3D with a visible halo billboard. Then night is lit by its own light
  sources, not by a dimmer.
- Grading: one colour-correction LUT per tone (cozy, unease, dread, free) in
  `Environment.adjustment_color_correction`, cross-faded by WorldTone. The dread shift
  currently done per material with the `dread` global becomes one asset, and night gets its
  own LUT (lift the blacks to blue, pull the greens toward teal, keep the warm emissives).
  Tonemap AgX, `tonemap_white` 2.0, exposure 1.0.
- Sky: a painted PanoramaSkyMaterial per phase (a 2k gradient with two or three big soft
  clouds and a sun glow) cross-faded by SkyRig, or ProceduralSkyMaterial with `sun_angle_max`
  and a cloud layer quad. The current sky is a blank gradient and it is the largest surface on
  screen.
- Terrain: a hand-painted tileable grass (tri-planar, 2 m repeat, two-tone like the show),
  a MultiMesh of grass-tuft cards with a wind sway and a lighter top, a dirt path mesh with a
  painted darker edge, and a macro colour variation map. The footprints stamped in the path
  [58][61] look like a texture bug and should go.
- Rain: fewer streaks, a screen-space droplet overlay fading in, puddle decals on the path,
  and the grade going cool. Never a brightness cut.

**Vs ideas doc.** Section F (cinematics) depends on this being done first: a camera rail
across the current night lighting makes the problems bigger, not smaller. C3 decorations
should be authored against the new prop rules. No disagreement in substance; the ideas doc
simply does not cover the look.

### 2.2 Pony rendering

**Wrong.** Mane and tail cards shade flat with a hard silhouette and no interior shape
[56][58][63]. Tails on NPCs are single-colour blobs [68][76]. The outline fades 18..42 m so
mid-distance herds lose their drawing [94]. The creator preview shows a smooth gradient across
the barrel instead of two flats [57]. The player fade is inside the default arm [69][83][95].
Spike's eye shader has no sclera or highlight [82]. Cutie mark sits low and far back [57]. Far
eyes vanish and then reappear (05/54). PonyLod keeps eye surfaces at full detail but the
outline fade and distance band still change her look at 20 m.

**Reference.** The show: fill plus one hard shadow shape, outline in a darker hue of the fill,
manes as three or four big smooth shapes with two painted highlight streaks, the eye highlight
always on, the cutie mark large and centred on the upper haunch. Pokemon Legends Arceus and
Animal Crossing: a simple ramp, a soft rim, a blob shadow, and the character never changes
look with distance, only detail.

**Technique.**
- Hair: bake "shell" normals onto the mane and tail meshes in Blender (data transfer from a
  smoothed proxy volume) so the cards shade as one rounded mass; add a hair albedo with two
  lighter streaks; keep the outline at the hair's silhouette only (mask by the normal
  transfer). This is the standard anime-hair fix and it does not need new models.
- Outline: stop fading; scale `width_px` from 1.7 at 5 m to a 1.0 px floor at 40 m and keep
  it on. Eyes: an unlit material past 15 m so the pupil and highlight stay drawn.
- Band: once shadows are hard, `band_softness` 0.02 and the ATTENUATION step 0.45..0.55 so a
  pony is two flats again, and the creator's preview matches the field.
- Blob shadow under every pony (see 2.1), so penned ponies read on the grass even when the
  cascade misses them.
- Player fade: FADE_START at 1.0 m, fully gone at 0.7 m, and dither (the silhouette shader's
  trick) rather than alpha so there is never a half-transparent frame.
- Creator: its own WorldEnvironment with a neutral three-point studio (key warm 1.0, fill
  cool 0.35, rim 0.6) and the same ramp as the field; what the creator shows is the pony.
- Cutie mark: an authored anchor per rig measured in Blender (a bone or an empty) rather than
  a UV guess; the show's placement is the test.
- Life: a blink, an ear flick and a weight shift on idle for every pony; a look-at with a
  deadband so the head does not vibrate [97].

**Vs ideas doc.** E2 (named ponies remember you) and E3 (jiggle beats) both want this: a
reaction nobody can see is not a reaction.

### 2.3 Icons

Covered in section 3 (the strategy). The verdict is that no screen can be fixed until the
icon language exists; the signs, the compass, the objective card, the catch card, the Depot,
the Market, the slots and the cards all draw from it.

### 2.4 UI system and HUD

**Wrong.** Three kits (verdict 3). The HUD stacks a compass strip, an objective card under
it, a 3D "!" the size of the fingerpost [68], a toast pill at the bottom that is one
full-width sentence and clips at the edges [68][80], a saddlebag card that clips at the left
[79][80], a prompt pill under the reticle, and the catch card top right [87]. The compass
stacks markers at its ends [76]. The pens sign carries the same "#" as the compass. There is
no safe-area margin, so at 1600x900 things fall off. Text outline was turned off (menu_style
OUTLINE_SIZE 0) after the "too thick" note, which fixed the weight but left white-on-plum and
ink-on-cream at the mercy of whatever is behind the translucent panel.

**Reference.** Hades: every panel is an illustrated object (parchment with gold filigree),
hover lifts and glows, counters tick up, portraits are paintings. Cult of the Lamb: thick-ink
paper with hand-drawn pictograms, a little wobble on open, every number has an icon beside
it. Stardew: a wooden frame with brass corners, the shopkeeper's portrait, item pictures on
a grid, tooltips with icons. Animal Crossing NH: soft cream and leaf-green blobs with drop
shadows, icons on white plates, a bottom-centre notification that is an icon plus three
words. Slime Rancher's HUD: a vac gauge and slot pictures, no sentences.

**Technique.**
- One real Theme (.tres) built from nine-patch textures: a painted paper panel with a drawn
  border (the show's rounded, slightly wobbly ink), a wood frame for the ranch, a plum velvet
  with gold piping for the Palace only. Buttons in three states as nine-patches. A chip, a
  tab, a scroll bar, a tooltip, a divider.
- Type: Fredoka stays for display (titles, numbers, signs) at 48 / 34 / 26. A readable rounded
  body face (Nunito or Quicksand, both OFL) at 22 / 19 / 16. Nothing under 16 at base res.
- Motion library (one script, tween-based): panel open 0.18 s scale 0.92 to 1 with a 1.03
  overshoot, close 0.12 s, hover lift 4 px plus a highlight, press squash 0.96, number
  count-up over 0.4 s, chip arc to the pot, card deal with an arc and flip. Every menu calls
  it; none invents its own.
- Safe area: a 48 px margin container around the whole HUD at base res, and nothing anchored
  outside it; test at 1600x900 and 2560x1440.
- Toasts become event cards: an icon plate, a bold number, three words ("+26 bits", "Pen
  full", "Lake open"), stacking bottom-left and sliding out, never a sentence. Story and
  world events get a different card (a camera cut, see 2.6).
- The "!" marker becomes a small floating icon on a plate with a soft bob, scaled by
  distance with a floor; the compass gets one marker per place and a distinct goal shape.
- Toast and menu layers: fix the CanvasLayer order so a toast never bleeds through a table
  [70].

**Vs ideas doc.** A4 (Pony Log), C2 (visit cards) and D2 (visible quota) are three new
screens; they must be built on the kit, not before it.

### 2.5 Pony creator [56][57]

**Wrong.** A two-column form: the pony on the left under dusk lighting, a wall of text tabs
and flat colour squares on the right. The preview does not match the picks (Unicorn selected,
wings and no horn shown; lilac reads tan; blue eyes read black). The cutie mark is low and
half under the wing. No random button, no drag-to-rotate affordance, no reaction from her to
a pick. Swatches are bare squares; mane styles are words.

**Reference.** Animal Crossing NH: the character in the centre of a soft room, categories as
big picture tiles (each hairstyle is a drawing of that hairstyle), the character turns with
the stick and reacts to a pick, colours as round swatches. The Sims 4 CAS: direct
manipulation (click the part on the model to edit it), a neutral studio, instant feedback.
Star Stable: the horse in a lit stable, breathing, with coat swatches that are actual coat
textures.

**Technique.** A dedicated creator scene with the studio rig (2.2); the pony centred, orbit
by drag and scroll zoom, a slow idle turntable when untouched; tabs as icon tiles; mane and
tail styles as baked thumbnails (style_icons.gd already does this for markings and eyes;
extend it to manes, tails, accessories); colour swatches as round plates with a ring and a
checkmark; a dice button with a shuffle animation; she blinks and glances at the cursor;
"This is me" as a big illustrated button. The preview bug (wings on a unicorn) is a logic
bug and goes first.

**Vs ideas doc.** Not covered there; the 2026-11-05 list asked for Random, more options and
better mark creation (items 2 to 6), all of which land here.

### 2.6 Depot [73][84][85]

**Wrong.** A dark list of identical rows, a generic head circle for every pony, "+26 bits"
and "-105 debt" swapping order between rows, "one of a kind: she asks before she goes" on
every named pony including stallions, a Pay tab that says "Nothing to settle" against a
5,000 floor nobody explained, and no sense of a place: no crate, no cart, no manifest, no
Marigold. A delivered pony lingers and animates before vanishing.

**Reference.** Stardew's shipping bin: the item pops into the bin with a sound and the night
summary shows the ledger. Slime Rancher's Plort Market: a big board with prices and trend
arrows, and the sale is a physical act. Viva Pinata: the pinata walks off and the crate
rolls away. The Company in this story is a corporation: its paperwork should look like one.

**Technique.** Portraits rendered from the pony herself (catch_card.gd already builds a
SubViewport portrait; reuse it in rows). The Deliver tab becomes a manifest on Company
stationery with a stamp; rows show the portrait, her name, a rarity glyph, and one number
with the balance bar under it. Deliver-all with a confirm. The pony walks into the Depot
cart (a 3D beat, 1.5 s) with a chime, and the row pops to coins. The Pay tab becomes the
statement: a ledger with the floor as a visible line and the quota as a bar, which is the
owner's item 4 and the ideas doc's D2. Sex-correct pronouns from PonyData.

**Vs ideas doc.** Agrees with D2 (visible quota replaces the hidden floor) and E1 (collection
day staged). The Depot menu should show the quota the E1 scene will collect on.

### 2.7 Market (no shot this round; playtest 05/52, 08/68)

**Wrong.** Does not read as buy-and-sell; the window resizes as the list scrolls; buying food
is fiddly; the decor tiles were blank until baked icons arrived.

**Reference.** Pierre's shop: shopkeeper portrait on the left with a line of dialogue, Buy
and Sell as two obvious tabs, an item grid with pictures and prices, your purse always
visible, a quantity slider. Slime Rancher's vendor: 3D stall, items on the shelf.

**Technique.** Fixed-size frame, Bramble's portrait and a greeting, the grid of baked item
icons (the decor route, extended to gear and food), a quantity chip with +1 / +10 / max, a
Sell tab that shows the saddlebag's gems as the same tiles. The stall itself in 3D should be
dressed with the items on sale so the shop reads before the menu opens.

### 2.8 Casino hall [65][72]

**Wrong.** The room is the best-dressed interior in the game and it is let down by: one
grey-purple pony with a dark mane cloned as the whole crowd, patrons frozen mid-step or in
the air, nobody playing anything, a flat tile-pattern floor, no pools of light on the tables,
the wheel and the race board running on their own loop with no names. The "House rules"
board outside and the arcade machines on bare paving [64][74] belong to nothing.

**Reference.** GTA Online Diamond Casino: warm spotlights pooled on every table, table lamps,
a crowd of distinct people seated and playing, dealers with idle animations, a constant
machine chatter, a wide red carpet to the cage. Yakuza 0 / Like a Dragon: cramped, neon,
every machine blinking in attract mode. Pokemon Let's Go Celadon Game Corner: rows of
machines with trainers sitting at them.

**Technique.** Patrons from the random generator (the brief requires it), seated at machines
and tables with a "play" idle (lean in, pull the lever, cheer or slump on a timer), two or
three walkers on a loop between them. Attract-mode lights: an emissive strip material with a
scrolling pattern on every machine, chandelier emissive, SpotLight3D over each table with
glow catching the felt. A carpet texture, not a tile pattern. The cage gets a cashier pony
and the first visit waypoints to it (owner item 57). The board shows the runners' portraits
and names. Move the arcade props inside or cut them.

**Vs ideas doc.** F12 (big win camera) needs the crowd to react, so the crowd comes first.

### 2.9 Blackjack and slots [66][70][96]

**Wrong (blackjack).** Mostly empty felt with two text labels, the chips set the bet instead
of stacking (no 100, no max, no clear), the cards' pips are wrong, clubs draw as dots, the
corner index touches the edge, the dealer is a word. **Wrong (slots).** Layout is fine; the
symbols are flat clip-art with no Equestria in them; the reels have no motion blur or win
flash; a toast bleeds through the window.

**Reference.** Red Dead Redemption 2: hand-drawn card faces, the dealer's hands dealing with
an arc, chips that stack and clink, every action a physical motion. Balatro: cards tilt and
hover under the cursor, a win punches the counter, the whole thing wobbles with feedback.
Clubhouse Games 51: a physical table, clean typography, chips you drag. Hearthstone: a board
that is a place, not a panel.

**Technique.** A card atlas (13 x 4 faces plus a back) drawn once by the icon route; deal
with a 0.25 s arc and flip, slide into place with a soft thud. Chips as stacks: clicking a
chip adds it to the bet stack with a clink and the stack grows; a Clear and a Max. A dealer
portrait (the generator again) with three expressions. Hit / Stand / Double / Split as
illustrated buttons. The felt carries the Palace crest. Slots: symbol art (apple, horseshoe,
bell, gem, star, rainbow are right; the drawings are the problem), reel motion blur during
the spin, a stepped stop with a clunk per reel, a payline flash and a coin burst on a win,
the lever as a physical pull.

### 2.10 Race betting [71][72]

**Wrong.** The worst screen in the game: dark green rows with colour-square "silks", odds
overflowing the coin, an unexplained dot row and bar, "by the card", invisible stake buttons,
keyboard text, half the panel empty, a ghost prompt behind it, and "no chips" after the slots
showed 1,400. The race itself runs on a loop in the hall with no names or faces, so a bet is
a number going up or down.

**Reference.** GTA Online Inside Track: a board with six horses, a number plate, a name, the
odds as a fraction in big numerals, a small horse portrait, a stake with +/-, Place Bet, then
the race on a screen with the camera tracking the pack, your horse ringed, commentary, and a
results board with the payout.

**Technique.** Rebuild on the kit: a form-guide board with the runner's portrait (SubViewport),
number plate, name, a fractional odds tag, a three-pip form (last three results) with a
tooltip, a chip stack stake and Place Bet. Then the race is a cinematic: the race_runner.gd
track with a rail camera, your pick with a gold outline (the outline shader's `highlight`
already does this), a photo-finish card and the payout counting up. "Your pick" stays pinned
on the HUD until the result.

**Vs ideas doc.** F10 (race finish cinematic) is this; agree, and the betting screen and
the cinematic should ship together.

### 2.11 Letters [89][90][91][92]

**Wrong.** A plain cream page with a navy band and a red circle stamp, identical for the
Company, the Academy and a postcard. The letter is the story's main evidence trail and it
has no personality. The oblique hint in "Top of the board" does not land because the page
gives it nothing to land on.

**Reference.** Stardew's letters: per-sender stationery. Cult of the Lamb's and Hades'
documents: illustrated, with a seal, a texture and a drop shadow. Papers, Please: the
corporate paperwork *is* the dread.

**Technique.** Stationery per sender via PaperPaint: the Company on cold grey stock with a
printed letterhead, a perforated edge, a serial number and a rubber stamp that is slightly
misaligned; the Academy postcard as an actual postcard with a picture side (a Cloudsdale
photo whose crop is the story crack), the message side handwritten. Open with an envelope
flap and a paper slide; a stack of unread letters in the mailbox. Keep the body text at a
readable 22 px body face.

**Vs ideas doc.** Agrees with memory "story not only letters": the letters stay as evidence,
and better paper makes evidence read.

### 2.12 Caught card [81][97]

**Wrong.** The portrait is off-centre and cropped by the SubViewport camera, Fluttershy's mane
renders white (the portrait rig's light or outline), the ring is a flat colour, the chips are
the drawn icons, the stars are plain.

**Reference.** Pokemon Legends Arceus: the caught card shows the whole Pokemon in a pose on a
coloured plate with a type chip and a sparkle burst. Slime Rancher's Slimepedia entry.

**Technique.** Frame the portrait at the head and withers with a 30 degree three-quarter
turn, a blink, the studio ramp; the plate in her coat colour with a darker ring; rarity as
the glyph plus a tier glow (legendary gets a gold shimmer); a short confetti burst and a
chime; the chips use the icon set.

### 2.13 Loading screen and title (no shot; owner: still cheap)

**Wrong.** Drawn clouds and a rainbow bar; the title is a text list with a caret.

**Reference.** Hades: a key-art painting with a spinner and one line of lore. Cult of the
Lamb: the lamb animates against a dark painted backdrop. Stardew: fade plus a tip. A Short
Hike: no loading screen worth noticing because it is instant.

**Technique.** A SubViewport with a pony walking on the spot (or her loaded-from-save look)
against a painted valley plate, with a slow parallax; the bar small; one line of tip or
lore. Title: the valley at dawn as a live 3D vignette with a slow camera drift, the logo as a
drawn wordmark, the four options as illustrated buttons.

### 2.14 Town layout and props [60][63][64][74][76][77][98]

**Wrong.** Verdict 4. Everything crowded into 30 m, signs doubled, a five-arm fingerpost,
2D sign cards, bare primitives, scale misses, no plaza, no streets, hard grass-to-paving
edges, the lake without banks.

**Reference.** A Short Hike: landmarks visible from everywhere and paths that lead the eye
to the next one. Animal Crossing NH: a plaza with one focal object (the town hall and the
tree), shops around it facing the centre, paths with painted edges, every prop from one kit.
Stardew's Pelican Town: a square, a road, yards.

**Technique.** A plaza plan: one focal object scaled up (a fountain or Marigold's office),
Market and Depot facing it, the house and pens 40 m away with a path, the Strip and Palace
on their own hill. One fingerpost, four arms max, each with a distinct icon plate. Signs as
3D hanging boards with a bracket and a thickness. Path meshes with painted edges and a
curb where paving meets grass. The lake with a bank mesh, a water shader with a foam line,
reeds as crossed cards with a painted texture, a dock with real planks. One prop kit: either
convert every remaining primitive to a glb in the PonySFM style or restyle the Kenney pieces
to match (the brief allows both); no BoxMesh scenery left.

**Vs ideas doc.** C3 (decorations that pull in kinds) is a prop-kit item; build it after.

### 2.15 Cinematics

**Wrong.** There is none: no letterbox, no rail, no skip, no input lock. Every event is a
toast. The Collectors take ponies off-screen (owner item 7), Bloom happens off-screen (22),
the sighting is a toast (14).

**Reference.** Cult of the Lamb's rituals: a camera push-in, a letterbox, a beat held a
second too long. Pokemon Legends' alpha reveal. Stardew's cutscenes: short, skippable,
in-engine.

**Technique.** One CinematicPlayer (ideas doc F tech): a Camera3D on a Path3D rail with
PathFollow3D, letterbox bars via a CanvasLayer, input lock, a skip prompt, a "hold until
menus close" gate, and scenes as data (a Resource per scene with rail, duration, actors and
sound). Build it on the fixed lighting; then F1, F3, F4 first, since those are the loop's
reward beats.

**Vs ideas doc.** Full agreement on F; the sequence point is only that lighting lands first.

---

## 3. Icon strategy

### Style spec
- **Silhouette first.** Every icon must be recognisable as a solid black shape at 24 px.
  Test by thresholding the contact sheet.
- **Master grid 64 px**, 4 px padding, optical alignment to a 56 px live area. Exported at
  128 (signs, cards), 64 (menus) and 32 (compass, chips).
- **Outline 3 px at 64 px** (about 5% of the size, same ratio as the pony outline), in the
  fill hue darkened 45%, never black. Open shapes get the same stroke so the whole set reads
  as one pen.
- **Two tones plus one highlight.** Flat fill, one hard shadow shape on the lower-right third,
  one small highlight dot top-left. No gradients, no soft shading.
- **Palette: 12 swatches** taken from the pony coat palette and the show's accents, one hue
  per family: gold for money, leaf green for pens and food, cottage pink for home, sky blue
  for mail and scrolls, violet for story and the Palace, apple red for the Orchard, lake
  blue, Everfree green, Nightmeadow indigo.
- **Plate.** Every icon has a cream circle plate with the same outline, so it reads on
  grass, on plum and on a wooden sign. The plate is part of the asset.
- **Families (about 80):** places (7), HUD (bag, pantry, bits, letter, objective, hint),
  foods (5), gear (12), permits (4), gems (4), rarity (4), races (3), quirks (about 10),
  holds (3), casino (3 chips, 6 reel symbols, 4 suits, cage, wheel, track), creator
  categories (5), event cards (catch, pen, full, bloom, sold, lake open, sighting).

### Production routes
- **Hand-drawn SVG against a template.** Consistent, scalable, Godot imports SVG natively at
  a chosen scale. Slowest per icon but the only route that gives one hand across 80 icons.
- **Generated then cleaned.** Fast; inconsistent weight and palette; every icon still needs a
  vector trace and a clean-up pass, which is most of the work.
- **Asset pack** (Kenney game icons, game-icons.net). Free and instant, but flat white
  glyphs with no show flavour; they would read as a fourth kit.
- **Commissioned.** Best result, days to weeks, costs money, and the owner is iterating
  weekly.

### Recommendation
Two routes, one studio:
1. **Vector symbols by spec.** One author (an agent working from this spec, or the owner's
   commission) draws the full set as SVG from a single template file with the grid, the
   stroke and the swatches baked in. Imported through Godot's SVG importer at 2x. A contact
   sheet gate renders all icons at 128, 64 and 32 on cream, plum and grass and the owner
   looks at it next to a row of Slime Rancher and Animal Crossing icons.
2. **Baked 3D for things that are objects.** decor_icons.gd and style_icons.gd already render
   props and pony parts under a fixed rig with the outline shader. Extend that route to gear,
   food items, permits (a region vignette) and pony portraits. Same ramp, same outline, same
   plate, so the two routes match. This is the Animal Crossing method.

Delete the per-pixel loops in place_sign.gd and the polygon icons in catch_icon.gd,
shop_icon.gd, rarity_glyph.gd and casino_paint.gd once the textures land. The "no 2D art
assets, so CI without a GPU can draw" rule in casino_paint.gd's header is a CI convenience
that has cost the whole game its icons; textures in git are fine.

---

## 4. Foundation proposal

Everything in section 2 depends on these. They come first.

### Art bible (docs/art-bible.md plus the assets it names)
- The reference board: a folder of show background frames and the ten named games, with
  one sentence each on what is borrowed. The withdrawn references folder is the reason
  every pass has drifted.
- Palette per tone (cozy, unease, dread, free) as swatches and as the four LUTs.
- The ramp texture and the three shading rules: two flats plus hard cascaded shadows to
  60 m, blob shadows under everything that moves, baked AO on everything that does not.
- The outline rule: width by distance, hue-darkened, no fade.
- Sky per phase and weather as painted plates.
- Night rule: a moon light, emissive windows and lamps, the night LUT.
- Prop rules: one kit, show-style blob foliage, the scale table (SCALE.md exists), vertex
  AO baked, no roughness or metallic, no primitives on the map.
- The studio rig scene used for the creator, the portraits and the baked icons.

### UI kit (game/ui/theme and a kit scene)
- The Theme with nine-patch panels (paper, wood, velvet), buttons, chips, tabs, scroll bar,
  tooltip, divider; the type scale and the two faces.
- The icon set and the plate.
- The motion library (open, close, hover, press, count-up, deal, chip arc).
- The HUD layout grid with the safe area, the event card, the compass marker spec.
- A kit showcase scene with every component next to a screenshot of the reference it was
  measured against; it is the acceptance test for every later screen.

---

## 5. Sprint outline

Ordered by perceived quality gain per day. "Done" is a side-by-side render against the
named reference, judged by eye, not a test.

1. **Lighting and grade reset** (2 to 3 days). Hard shadows, SSAO off, 60 m cascade cap,
   night moon with sun shadows off, emissive windows and lamps, four LUTs, AgX, painted
   skies, blob shadows, grass tufts and path edges.
   Done: the plaza at noon, dusk and night next to an Animal Crossing plaza and a show
   background; no stencilled shadows on walls at night; every terminator is a flat edge.
2. **Icon set v1** (2 to 3 days). The 80 icons and the plate, replacing PlaceSign, compass,
   objective, catch card, Depot, Market, rarity, chips, suits and reel symbols.
   Done: the contact sheet at 32, 64 and 128 on three backgrounds next to a row of Slime
   Rancher and Animal Crossing icons; a cold viewer names each icon at 24 px.
3. **UI kit v1 and HUD re-skin** (3 to 4 days). Theme, nine-patches, type, motion library,
   safe area, event cards, compass markers; the pause menu, letters, Depot and Market on it.
   Done: the HUD over the noon plaza next to Slime Rancher's and Animal Crossing's; nothing
   clipped at 1600x900 or 2560x1440; no toast is a sentence; the Depot rows show faces.
4. **Pony pass and creator studio** (2 to 3 days). Hair normals, outline floor, far eyes,
   player fade, blob shadows, idle life, the creator scene with the studio rig and tiles,
   the preview bug, the cutie mark anchor.
   Done: a creator turntable next to a show reference sheet; the player at default zoom is
   opaque; a herd at 25 m still has outlines and eyes.
5. **Town and props rebuild** (3 to 4 days). Plaza plan, one fingerpost, 3D signs, path
   meshes and curbs, primitives replaced, lake banks and dock, scale fixes, collision pass.
   Done: a top-down of the ranch next to an Animal Crossing island plaza; a 60 s walk from
   house to Palace with no snag and the Market visible from the start.
6. **Casino pass** (3 to 4 days). Generator crowd seated and playing, attract lights and
   spotlights, carpet, cashier, blackjack cards and chip stacks, slot symbols and spin
   feedback, race betting rebuilt with portraits and odds tags, the race cinematic with
   your pick ringed.
   Done: the hall next to a GTA Diamond Casino shot; the betting screen next to Inside Track;
   a race watched end to end with a photo-finish card.
7. **Cinematic player and the first three scenes** (3 days). Rail, letterbox, skip, hold;
   arrival (F1), first Bloom (F3), collection day (F4).
   Done: a 10 s clip of each, judged against a Cult of the Lamb ritual cut.
8. **Loading and title** (1 day). Live vignette, wordmark, illustrated buttons.
   Done: side by side with Hades' loading screen and Cult of the Lamb's title.

Steps 1 to 3 are the foundation and should not be reordered. Steps 4 to 8 can be
interleaved with the ideas doc's gameplay experiments (A1 to A3 catching, D1 days, C1
gating), which touch different files. The ideas doc's own order puts no visual work
anywhere; this review's position is that E1, E3 and all of F are visual deliverables and
produce the "polished turd" verdict again if they are built on the current lighting and kit.
