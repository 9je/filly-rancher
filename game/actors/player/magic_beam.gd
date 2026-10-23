class_name MagicBeam
extends Node3D
## THE core mechanic: Twilight's horn beam. Point at a pony, hold the `beam` button, she
## is lifted out of the world and reeled in to float in front of you; let go before she
## wriggles out and she goes in the bag (game/systems/storage.gd). This is the pony
## equivalent of Slime Rancher's vacpack, and everything else in Phase 1A exists to make
## this moment work.
##
## Interface other tasks depend on -- do not rename:
##   grab() / release()     -- start and stop beaming.
##   is_holding() -> bool   -- whether something is currently in the beam.
##   is_secured() -> bool   -- whether releasing right now would KEEP her (see below).
##   get_storage() -> Storage -- what has been caught so far.
##   release_stored()       -- let the last one caught back out into the world.
##
## A CAPTURE IS A CONTEST WITH TWO CLOCKS, which is the shape the first playtest asked
## for. The beam needs a subdue time of unbroken hold to take a pony; she has a struggle
## time of fight in her. Let go too early and she slips out; hold too long and she wins.
## Everything between is the WINDOW you are aiming for. Before this, release() stored
## whatever was in the beam the instant it was called and the struggle timers were
## decorations on a decision already made -- the owner's report was "catching is really
## quick", and it was: point, click, done, in about a third of a second. The full
## reasoning is on SECURE_SECONDS.
##
## THE WINDOW IS GRADED, JITTERED, AND ON THE HARD GRADE IT CAN BE TAKEN AWAY FROM YOU.
## That is the third playtest's brief -- "all the character super easy to catch too, no
## real challenge with the wiggling out" -- answered in four parts, and each part has its
## own constant block below:
##
##   GRADED    every pony is EASY / MEDIUM / HARD, read off the `personality` she already
##             carries (Grade, grade_for). 1.00 / 0.50 / 0.35 s of window, down from
##             3.45 / 1.85 / 1.15.
##   JITTERED  both clocks are rolled per attempt inside published bounds (SECURE_JITTER,
##             WINDOW_JITTER), so the mechanic cannot be played by counting.
##   WRENCHED  a HARD hold can tear free BEFORE it secures her (WRENCH_CHANCE_HARD),
##             implemented as nothing more than a struggle time rolled shorter than that
##             attempt's own subdue time -- so the same two clocks resolve it and the HUD
##             shows it happening.
##   BOUNDED   the wrench chance falls to zero by WRENCH_GRACE_HOLDS grabs on the same
##             pony, so repeated correct play always wins. "But will eventaully let you
##             catch" is a guarantee here, not a probability.
##
## roll_clocks() is the one function that does all four, it is static and pure with its
## randomness passed in, and every property above is swept exhaustively in
## game/test/test_magic_beam.gd rather than sampled from a few live captures.
##
## WHO OWNS A CAPTURE. This node does, outright. pony.gd used to run a beam-hold timer of
## its own and fire captured() off an exported capture_seconds -- a second capture state
## machine underneath this one, with a default (0 s) that fired a capture on the first
## held frame. That is gone (see pony.gd's SIGNALS section): a pony now only REPORTS that
## she is held and for how long, and this file decides what the hold meant and says so
## through Pony.notify_captured() / Pony.break_free(). One rule, one place.
##
## AIM COMES FROM THE CROSSHAIR, NOT FROM HER FACING. Every cast below runs along
## CameraRig.get_aim_ray(), which is a ray from the camera through the SCREEN CENTRE.
## The horn is where the beam is DRAWN from, never what it is aimed along -- those two
## agree only by coincidence (the body yaws toward movement, the camera yaws with the
## mouse), and aiming along the horn would mean the beam misses whatever the crosshair is
## sitting on. camera_rig.gd's own comment on get_aim_ray() says the same thing from the
## other end.
##
## RANGE IS MEASURED FROM THE PLAYER, NOT FROM THE CAMERA, even though the ray starts at
## the camera. The camera sits CameraRig.SPRING_DEFAULT (3.5 m) behind her head and the
## player can zoom that between 1.2 m and 6.5 m; a range measured along the raw ray would
## quietly hand a zoomed-in player two metres less reach than a zoomed-out one, for no
## reason a player could ever discover. So the anchor (the horn) is projected onto the
## ray and REACH is added past that point -- the same projection the hold point uses, so
## both are zoom-invariant.
##
## NO PONY EVER DIES. Project-wide rule, and this is the file with the most opportunity
## to break it: every exit from a hold puts a live pony back somewhere. Stored (record in
## the bag, node freed, rebuildable through PonyRegistry -> PonyVisuals), broken free --
## either because she out-lasted the struggle timer or because the beam was let go before
## it had secured her, both through _lose() (physics handed back, escaped() reported) --
## or refused by a full bag (set_held(false) and she drops where she was floating,
## unharmed). There is no fourth path, and the
## verification scene asserts the refused one specifically, because "the bag was full" is
## exactly the branch where a careless implementation would drop a pony on the floor in
## the other sense.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd: the class cache lives in the gitignored game/.godot/ and a
## fresh clone has not built it yet.

const LayersScript := preload("res://world/collision_layers.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const StorageScript := preload("res://systems/storage.gd")

## Emitted after a pony's record has gone into storage and her node has been freed.
##
## Carries the PonyInstance -- the INDIVIDUAL who was caught, with her own uid and state --
## not the shared PonyData. It used to carry the PonyData, which meant a listener could not
## tell the second Twilight from the first (Phase 1B Task 1's whole reason for existing).
## Her character record is one `instance.data()` away for anything that needs it.
signal captured(instance: PonyInstance)

## Emitted after a stored pony has been put back into the world as a live Pony node --
## see release_stored(). Carries both halves because both are useful: the node to look at,
## and the instance whose state she came back with.
signal released(pony: Node3D, instance: PonyInstance)
## Emitted when a held body wins its struggle and is handed back to the world. The body
## is still alive and still in the scene -- that is the point.
signal escaped(body: Node3D)
## Emitted when a hold ended over a full bag (or over a pony with no record to store), so
## she was set down instead. A HUD hangs its "storage full!" nag off this.
signal capture_refused(body: Node3D)

## The input action, bound in project.godot to right mouse / right trigger.
const BEAM_ACTION := &"beam"

## Why the last hold that did not end in a capture ended. Both values report `escaped()`
## -- from the pony's side they are the same event -- but they are two different MISTAKES,
## and a HUD that tells them apart is what makes the capture window learnable instead of
## mysterious. Read through get_last_loss().
enum Loss {
	NONE,       ## Nothing has been lost yet this session.
	SLIPPED,    ## Let go before the beam had secured her: it never subdued her.
	STRUGGLED,  ## Held past her struggle time: she won on her own.
	WRENCHED,   ## She tore out of a HARD hold BEFORE it could secure her -- see WRENCH_CHANCE_HARD.
}

## Twilight's greeting line, played once on the FIRST successful capture as a placeholder
## for the future voice system (docs/notes-voice.md). Deliberately a plain constant path
## rather than PonyData.voice_bank: this is the player character reacting to her own
## success, not a line belonging to whoever was caught, and there is exactly one take in
## the repo so far. When the voice system lands, this is the one call site to rewrite.
## Empty in v1: the canon placeholder take was removed (no canon voices; the player is an
## OC). The player's voice returns as babble with the talk system.
const VOICE_LINE := ""

## How far past the player the beam reaches, in metres.
##
## THE COMMENT THAT USED TO BE HERE ARGUED FOR EXACTLY THE WRONG RELATIONSHIP, AND THE
## GAME SHIPPED WITH IT. It read: "sized against the pony's own DETECTION_RADIUS (5 m):
## ... 8.5 m leaves a clear couple of metres of 'spot her, aim, take her' before she has
## even noticed you." That is a description of the bug, written down as if it were the
## design. A beam that out-reaches a pony's own senses means the player can ALWAYS take
## her before she reacts -- so the flee behaviour, which works perfectly, never once
## happens in play. The owner's first session found it immediately: "I could just hold
## click and walk up and catch them -- they should start running away farther than the
## range of the beam."
##
## The relationship is now the other way round and Pony.DETECTION_RADIUS (12 m) is the
## number that moved, not this one: REACH stays at 8.5 m because it is bounded by
## something real and unrelated -- past ~10 m the far end of the beam is a few pixels on
## screen and you cannot tell what you have hit. What the beam gains from here is
## upgrades: Phase 1B's shop sells reach, and every metre it sells eats into the 3.5 m of
## warning a pony currently gets, which is exactly what makes buying it feel like
## something. That is also the reason MIN_DETECTION_MARGIN below is stated as a margin
## rather than the two constants simply being compared: an upgrade path that can raise
## REACH needs a floor under how little warning a pony may be left with.
##
## THE SECOND PLAYTEST ADDED THE ONE SANCTIONED WAY TO BEAT THAT HEAD START: sneaking.
## Pony.SNEAK_NOTICE_FACTOR halves a pony's notice radius while the player holds
## Player.SNEAK_ACTION, which puts every personality's sneaking radius (6.0 - 7.0 m) INSIDE
## this reach. That inverts the invariant deliberately, and only for a player who has
## chosen to move at a quarter speed -- which is the entire point of a stealth option.
const REACH := 8.5

## Gear. The shop's unlock ids this beam knows how to apply (game/systems/shop_item.gd's
## GEAR kind, game/data/shop/*.tres). apply_unlocks() reads GameState.unlocks on boot and
## after every purchase; an id it does not know is ignored, so an unlock aimed at some
## other system does not have to be filtered out before it gets here.
const GEAR_BIGGER_SADDLEBAG := &"bigger_saddlebag"
const GEAR_LONG_BEAM := &"long_beam"
const BIGGER_SADDLEBAG_CAPACITY := 18
## Metres added to REACH by the long beam, and the whole of what the shop has left to sell.
##
## THE ARITHMETIC, IN FULL, BECAUSE IT IS THE ONLY THING SIZING THIS NUMBER. The least
## sighted personality is a CURIOUS or BOLD pony, who notices a running player from
## Pony.DETECTION_RADIUS (12.0 m); that exceeds REACH (8.5 m) by 3.5 m. MIN_DETECTION_MARGIN
## below is a hard floor of 3.0 m under that warning. 3.5 minus 3.0 leaves 0.5 m, and this
## constant is all 0.5 of it: the long beam reaches 9.0 m and a CURIOUS or BOLD pony is left
## with exactly the floor. There is no slack behind it. Any FURTHER reach the shop wants to
## sell needs Pony.DETECTION_RADIUS raised first; it cannot be bought by tuning this number
## on its own, and raising it alone would sell the invariant rather than an upgrade.
##
## Selling the whole 0.5 m rather than a cautious fraction is deliberate: the upgrade is
## meant to be felt, and a tenth of a metre nobody notices is not worth a shop slot.
## game/data/shop/long_beam.tres promises the player half a metre, and that promise is this
## constant.
##
## 1.0 m WAS TRIED FIRST AND DOES NOT FIT, which is worth recording because it is the
## obvious number: it reaches 9.5 m, leaving a CURIOUS or BOLD pony 2.5 m of warning, half a
## metre under the floor. That is the invariant the first playtest was lost to being sold
## back to the player one upgrade at a time. It was caught by test_magic_beam.gd, which
## checks this arithmetic against the real per-personality notice radii rather than trusting
## a comment like this one.
const LONG_BEAM_BONUS := 0.5

## Metres by which a pony's notice radius must exceed REACH FOR A RUNNING PLAYER: the head
## start a pony is guaranteed even after every reach upgrade the shop can sell. 3.0 m is
## about six tenths of a second of the player's run, which is the least that can still read
## as "she saw me coming" -- and it also has to swallow GRAB_ASSIST_RADIUS, since the
## forgiveness pass makes the beam's EFFECTIVE grab distance half a metre longer than REACH
## says. Today's actual margin is 3.5 m for a CURIOUS or BOLD pony and 5.5 m for a SHY
## one, and 3.0 m / 5.0 m once the shop's long beam is bought. LONG_BEAM_BONUS above is
## sized to land exactly on this floor and no further past it.
##
## "FOR A RUNNING PLAYER" IS LOAD-BEARING AND IS NOT A WEAKENING OF THE INVARIANT. Running
## is the default gait -- it is what happens when you press a movement key and nothing
## else -- so this is still a promise about how the game behaves unless the player takes a
## deliberate, slow, costly action to change it. Asserted over EVERY personality in
## game/test/test_magic_beam.gd and re-checked live in scenes/test/capture_test.gd, which
## also demonstrates both halves behaviourally: a running player is bolted from at 10.25 m,
## and a sneaking one at the same spot is not noticed at all.
const MIN_DETECTION_MARGIN := 3.0

## Metres past the player, along the aim ray, that a held body floats. 2.2 m puts a pony
## (about 1.4 m nose to tail, 1.16 m at the withers) clearly in front of the player and
## clearly in front of the camera -- with the camera at its 3.5 m default she is roughly
## 5.9 m from the lens, which frames her whole body without her filling the shot. It is
## also comfortably outside her own 0.42 m capsule plus the player's, so a held pony does
## not visually intersect the pony holding her.
const HOLD_LEAD := 2.2

## Metres the hold point is pushed sideways (screen right) and up, PERPENDICULAR to the
## aim ray.
##
## THIS IS NOT DECORATION -- it is the fix for a bug the first offscreen render caught and
## no assertion in this task could have. The hold point started dead on the aim ray, which
## is the obviously right answer in a first-person game and the obviously wrong one here:
## the aim ray goes from the camera through the SCREEN CENTRE, and in a third-person rig
## with no shoulder offset (camera_rig.gd mounts the arm directly behind her) the player's
## own body is what sits at the screen centre. So a captured pony was reeled in and parked
## exactly, perfectly behind the player from the camera's point of view -- fully occluded,
## with the beam foreshortened into a couple of pixels behind her head. Every number in
## the gate was green: she was at the hold point, at a sensible distance, not clipping the
## near plane. The picture showed a pony holding still and nothing else happening.
##
## THE FIRST SIZING OF THESE OFFSETS WAS DERIVED FROM THE COLLISION CAPSULE AND WAS TOO
## SMALL. It reasoned: the player's 0.42 m capsule at 3.5 m subtends about 6 degrees, so
## 1.4 m across at the hold point's ~5.6 m clears it. Phase 1A Task 9's integration pass
## rendered an actual capture in the actual ranch and the picture disagreed -- a held
## Fluttershy sat with only her ears and mane showing above Twilight's head, and a held
## Rainbow Dash was a coloured smudge behind Twilight's neck. Two things the capsule
## arithmetic left out: the capsule is not the SILHOUETTE (the mane, the ears and the
## horn are all outside it, and her head is what the offset has to clear, not her
## barrel), and the vertical lift was small enough that the held pony landed ON her head
## rather than above it.
##
## The numbers below are sized off the RENDERED frame instead. At the default zoom the
## hold point sits ~5.6 m from the lens, and with a 16:9 viewport (half-width
## tan(hfov/2) = 1.34) 2.4 m across projects to ~256 px of a 800 px half-screen -- about
## two and a half times the player's own on-screen half-width, so the held pony is fully
## in the clear at every zoom the player can select (at SPRING_MIN she is 428 px out,
## still well inside the frame; at SPRING_MAX, 167 px, still clear). The 1.0 m lift puts
## her above the player's back rather than on her head.
##
## Both are perpendicular to the RAY, not to the world, so they stay screen-right and
## screen-up at any pitch. And a bigger offset makes the BEAM more legible too, for free:
## the ribbon from the horn to the held body is longer on screen and less foreshortened.
const HOLD_SIDE := 2.4
const HOLD_LIFT := 1.0

## Floor on the hold distance measured from the CAMERA, in metres. Only bites when the
## player has zoomed all the way in (CameraRig.SPRING_MIN is 1.2 m): without it, a fully
## zoomed-in hold would put a pony 1.2 + 2.2 m away -- fine -- but a future shorter spring
## or a rig mounted somewhere else could push the hold point through the near plane and
## turn a captured pony into a screenful of nostril. Cheap insurance against a number in
## another file changing.
const MIN_HOLD_DISTANCE := 1.6

## Exponential rate at which a held body is reeled toward the hold point, in 1/seconds.
## Framerate-independent (1 - exp(-k*dt)), same idiom as the player's and the pony's turn
## smoothing. At 6.0 a body closes 90% of the gap in ln(10)/6 = 0.38 s.
##
## Slowed from 8.0 (0.29 s) after the playtest. On its own this is a small change -- the
## reel is a third longer and you get to watch her come -- and it is NOT the fix for
## "catching is really quick"; SECURE_SECONDS below is. It matters because the pull-in
## used to BE the whole capture: she arrived in 0.29 s and was stowable from that instant,
## so the struggle timers underneath were decoration. Now the pull is the first beat of a
## capture rather than the whole of it.
const PULL_RESPONSE := 6.0

## Radius, in metres, of the forgiveness pass -- see _try_acquire(). Half a metre is about
## one pony-capsule diameter, so "I was aiming at the grass just under her hooves" works
## and "I was aiming at the next pony along" does not.
const GRAB_ASSIST_RADIUS := 0.5

## Height above a pony's origin that the hold point should line up with, in metres.
## Exactly the centre of her collision capsule (pony.tscn: height 1.30, centred at 0.65),
## so the crosshair ends up on her barrel rather than on her hooves. Without this she
## floats with her feet where her chest should be and reads as sinking.
const PONY_HOLD_LIFT := 0.65

## Radians per second a held body turns while suspended. Purely feel: a held pony that
## keeps a fixed yaw looks like a bug (a mesh nailed to a point in space), and a slow
## rotation reads as "something else is moving her". ~52 deg/s is one turn every 7 s.
const HELD_SPIN_RATE := 0.9

## Metres in front of the player a released pony is set down, and metres above the
## player's own feet she starts from. RELEASE_LEAD is a little under HOLD_LEAD (2.2 m), so
## she appears roughly where a held pony floats -- the player's mental "in front of me"
## spot -- but clear of the player's own 0.42 m capsule plus her own, so the two do not
## spawn interpenetrating and shove each other apart. RELEASE_LIFT is deliberately small:
## enough that a slight rise in the ground under her does not bury her hooves, little
## enough that the drop reads as her landing rather than as her falling.
const RELEASE_LEAD := 2.0
const RELEASE_LIFT := 0.15

## Seconds after a body wins its struggle during which the beam refuses to acquire
## anything. Without it, the beam is still on when she breaks free, so it re-grabs her on
## the very next frame and the escape means nothing at all.
##
## Raised from 0.75 s once losing a pony became a real outcome (see SECURE_SECONDS). At
## 0.75 s an escapee got back roughly to where she started -- she is set down at the hold
## point, about 3.3 m from the player, and 0.75 s of accelerating from a standstill buys
## her about 1.4 m, still deep inside REACH -- so "she wriggled free" cost the player a
## button press. 1.25 s puts her at her full flee speed and about 3 m further out, so the
## second attempt is a moving target at the edge of the beam and you have to work for it.
const ESCAPE_COOLDOWN := 1.25

## The same cooldown after a WRENCH -- the one loss the player did not cause (see
## WRENCH_CHANCE_HARD). Deliberately shorter, and the reasoning is the acceptance criterion
## the owner put above every number here: "i dont want the mechanic to get annoying".
## ESCAPE_COOLDOWN is a PRICE for a mistake -- you let go too soon, or you held too long --
## and a price for a mistake nobody made is just dead time. It is also dead time that buys
## nothing on the grade it can actually happen to: a BOLD pony has no reaction to the player
## at all (Pony.reaction_state -> NO_REACTION), so she does not use the head start to become
## a moving target the way a fleeing pony would; she stands there while you wait. Long
## enough to read as a real escape and to let the beam visibly let go of her, short enough
## that "she got me that time" is a beat rather than a punishment.
const WRENCH_COOLDOWN := 0.55

## Seconds the beam must have a pony in it before she can be stowed -- the NOMINAL value,
## before the per-attempt jitter below. THE FIX FOR THE OWNER'S FIRST COMPLAINT: "catching
## is really quick -- it took me several tries to get a screenshot of one."
##
## Before this constant existed, release() stored whatever was in the beam, unconditionally
## and instantly. The pull-in finishes in ~0.3 s, so the entire mechanic was: point,
## click, done. The per-personality struggle timers below were real, ran correctly, and
## were tuned with care -- and no player would ever have discovered any of it, because
## nobody has a reason to hold a button down when letting go already won.
##
## So a capture is a two-sided clock. The beam needs this long to subdue her; she has a
## struggle time of her own. Let go inside the first and she slips out of the field and
## drops back into the world -- alive, and now spooked. Hold past the second and she wins
## outright. Between them is the WINDOW, and the window is the mechanic.
##
## LOWERED FROM 1.15 s BY THE THIRD PLAYTEST, along with every window (see WINDOW_EASY).
## The owner's report was "all the character super easy to catch too, no real challenge
## with the wiggling out", and the shape of the fix he asked for was "graded, id decrease
## the current values". Shrinking the windows without also shortening the subdue would have
## made every catch a longer wait for a tighter target, which is the one combination that
## turns a mechanic into a chore. 1.0 s is still comfortably past the 0.38 s pull-in, so
## the whole of the secure phase is spent watching a pony who has actually arrived and is
## visibly fighting -- see the floor asserted in game/test/test_magic_beam.gd.
##
## WHY THE SUBDUE TIME IS THE SAME FOR EVERYONE and only the resistance varies: it keeps
## one number as "what the beam does" and one as "who she is", so the grades stay legible.
## A player learns "Rainbow Dash is a handful" from her ring draining fast, not from the
## beam behaving differently in her hooves.
const SECURE_SECONDS := 1.0

## Seconds of jitter either side of SECURE_SECONDS, rolled once per attempt (0.85 - 1.15 s).
##
## THIS IS THE "MORE VARIANCE AND RANDOMNESS TO KEEP IT FUN" HALF OF THE OWNER'S BRIEF, and
## it is on the SUBDUE clock rather than only on the struggle clock for a specific reason:
## with a fixed subdue time a player stops watching the ring after about six catches and
## starts counting "one... and let go", which is a rhythm game, not a contest. Jittering
## when the ring completes makes WATCHING the ring the only way to play it -- and watching
## is not punished, because the ring is drawn from the rolled value, so it always tells the
## truth about this particular attempt (game/ui/hud.gd's outer catch ring).
##
## Bounded on purpose, and the bound is what stops this being a slot machine: the low end
## must stay clear of the pull-in (a subdue that completed while she was still in transit
## would put the contest back where it was, invisible), and the high end must stay short
## enough that the twelfth catch of a session is a second of commitment rather than a
## chore. Both ends are asserted in game/test/test_magic_beam.gd.
const SECURE_JITTER := 0.15

## THE DIFFICULTY GRADE OF A HOLD. Not a new field on anything -- it is a READING of the
## personality a pony already carries (PonyData.personality), which is the tier this
## mechanic has always been keyed on. The owner asked to "tag them with different
## difficulties"; this is that tag, named, so the rest of the file can talk about EASY /
## MEDIUM / HARD instead of restating which personality happens to be which this month.
##
## SHY IS THE EASY ONE AND BOLD THE HARD ONE, and that ordering was inverted deliberately
## by the second playtest -- do not "fix" it back. "It makes sense Fluttershy runs but
## freezes": a terrified prey animal in a magic field goes rigid, so a SHY pony is the
## hardest to REACH (Pony.SHY_NOTICE_BONUS -- she sees you from 14 m and she is the only
## personality that runs) and the easiest to HOLD. A BOLD pony has no reaction to the
## player at all, so you walk straight up to her, and the whole of her difficulty is here.
## It also puts difficulty and rarity in agreement: BOLD is Rainbow Dash, who is RARE.
enum Grade {
	EASY,    ## SHY. She has frozen. The exhale after the chase.
	MEDIUM,  ## CURIOUS. Comfortable if you are paying attention.
	HARD,    ## BOLD. A scramble -- and the one grade that can tear free before you land her.
}

## The capture window each grade gets, in seconds: the slack between "the beam has subdued
## her" and "she has won". This is the number that says how hard she is to catch.
##
## STRAIGHT OUT OF THE THIRD PLAYTEST, in the owner's own words: "medium ones only have
## like a half sec window and easy have the full second window something like that", with
## the hard grade tighter still. The build he played gave 3.45 / 1.85 / 1.15 s, and this
## file's own comment conceded the easy case "is not meant to be a challenge at all" --
## which is exactly what he found: "all the character super easy to catch too, no real
## challenge with the wiggling out".
##
##   EASY    1.00 s   you have to be looking at the screen, and that is all
##   MEDIUM  0.50 s   about two reaction times: you must be watching the ring
##   HARD    0.35 s   one deliberate release -- plus WRENCH_CHANCE_HARD on top
##
## 0.35 s IS NOT A REACTION TEST, and the difference matters for whether this is fun.
## Reacting to an unheralded flash takes ~0.25 s, which would make the hard grade a coin
## toss; but the outer ring fills toward a visible finish line, so the player is
## ANTICIPATING a converging target rather than reacting to a surprise, and anticipatory
## timing lands inside ~0.1 s. The jitter is what keeps the anticipation honest: you can
## see when the ring will close, but you cannot know it in advance.
const WINDOW_EASY := 1.00
const WINDOW_MEDIUM := 0.50
const WINDOW_HARD := 0.35

## Fraction of its own width a window is jittered by, rolled once per attempt. 0.15 gives
## 0.85-1.15 s easy, 0.43-0.58 s medium, 0.30-0.40 s hard.
##
## Applied to the WINDOW rather than to the struggle time, which is the part that keeps
## this bounded: the struggle clock is then computed as the rolled subdue plus the rolled
## window, so the two jitters cannot stack into a hold that is over before it starts. The
## worst roll on the hardest grade still leaves 0.30 s, which is longer than an
## un-anticipated visual reaction, and game/test/test_magic_beam.gd asserts that floor over
## every grade rather than trusting the arithmetic here.
##
## 0.15 IS NOT A TASTE CALL -- IT IS THE WIDEST JITTER THE GRADING PERMITS, and the first
## draft got it wrong at 0.20, which is why the constraint is written down. The grades only
## teach a player anything if a harder grade is ALWAYS harder: the worst EASY roll has to
## beat the best MEDIUM one and the worst MEDIUM roll the best HARD one, or the same pony
## is sometimes a tougher hold than a pony of a tougher grade and there is nothing to
## learn. MEDIUM and HARD are 0.50 against 0.35, so that ceiling is 0.50(1-j) > 0.35(1+j),
## i.e. j < 0.176 -- and the test that pins it went red on 0.20 rather than this being
## noticed by eye. Widening the variance any further means moving the grades apart first.
const WINDOW_JITTER := 0.15

## Chance that a HARD hold is torn out of before it can secure her -- "the hardest ones
## have a chance to wiggle out before you catch (but will eventaully let you catch)".
##
## HOW IT IS IMPLEMENTED IS THE POINT: there is no second state machine. A wrenching
## attempt simply rolls a struggle time SHORTER than its own subdue time (see
## WRENCH_AT_MIN), so the existing two clocks resolve it, and -- crucially -- the HUD shows
## the truth for free: the inner red ring visibly outruns the outer green one, and the
## player can SEE that this one is lost rather than being told so after the fact. A
## mechanic that takes a catch away has to show its working or it reads as a bug.
##
## AND IT CANNOT LOOP, WHICH IS THE HALF THE OWNER'S "but" WAS CARRYING. The chance falls
## by WRENCH_CHANCE_FALLOFF for every previous time the beam has had hold of THIS pony
## (Pony.beam_holds), so it reaches exactly zero on her third grab and stays there: she
## tires. 0.50 then 0.25 then 0.00 means the expected cost of taking a hard pony is about
## 0.6 wrenches -- usually one, never more than two, and never a dice roll you can lose
## indefinitely. That guarantee is proved rather than asserted, twice: as a sweep over
## every seed in game/test/test_magic_beam.gd, and live, by playing a wrenching pony
## correctly until she is caught, in game/scenes/test/capture_test.gd's WRENCH phase.
const WRENCH_CHANCE_HARD := 0.50
const WRENCH_CHANCE_FALLOFF := 0.25

## Prior holds after which a pony can no longer wrench free, whatever her grade -- derived
## from the two constants above rather than typed, so a retune of either cannot leave a
## pony who fights forever. Read by the gates, which lean on the guarantee.
const WRENCH_GRACE_HOLDS := int(ceil(WRENCH_CHANCE_HARD / WRENCH_CHANCE_FALLOFF))

## When a wrench lands, as a fraction of that attempt's own subdue time: she tears out
## between 60% and 90% of the way to being secured.
##
## Both ends are sized off what the player SEES. Earlier than 0.6 and she is barely out of
## the pull-in when she goes, which reads as the beam failing to pick her up rather than as
## her winning; later than 0.9 and the outer ring is close enough to full that a player
## letting go on instinct cannot tell a wrench from their own mistimed release, which would
## teach exactly the wrong lesson. Between them she gets most of the way round the ring and
## then takes it back, which is the beat this is for.
const WRENCH_AT_MIN := 0.60
const WRENCH_AT_MAX := 0.90

## Struggle time for anything that is not a pony, in seconds. Props do not resist; a crate
## stays in the beam until the player lets go.
const STRUGGLE_NEVER := INF

## Secure time for anything that is not a pony, in seconds. A crate is not subdued, it is
## simply carried, so there is nothing to wait out before dropping it -- and a drag-and-
## drop toy with a mandatory 1.15 s arming delay would be a worse toy.
const SECURE_NEVER := 0.0

@export_group("Storage")
## How many ponies the player can carry. Twelve is a placeholder for whatever the barn
## economy decides in a later phase -- it is a data question, not a beam question.
@export var storage_capacity := 12

## Segments in the beam ribbon. Sixteen is enough that the bow reads as a curve rather
## than as a bent stick at any length the beam can reach.
const BEAM_SEGMENTS := 16

## How far the beam bows sideways, as a fraction of its own length, and the absolute
## ceiling on that. 0.30 of a typical 4 m hold is about 1.2 m of clearance -- comfortably
## past the player's 0.42 m capsule from every camera angle.
##
## THE CAP IS THE PLAYTEST FIX for "the curve as well is nice, curved a bit odd". A pure
## fraction keeps growing: at the far end of REACH the control point was 2.55 m out to one
## side, which puts the arc's apex more than a metre off the line between the horn and
## what you are pointing at. Since the bow is always taken toward CAMERA-right, aiming at
## something on your LEFT sent the beam swerving out to the right and back again -- the
## beam visibly went somewhere other than where it was going. The clearance the bow exists
## to buy is a fixed thing (getting past the player's own silhouette), so the sideways
## offset should saturate rather than scale: short beams keep the same clearance they
## always had and long ones straighten out into a clean lob.
const BOW_FRACTION := 0.30
const BOW_SIDE_MAX := 1.2

## How far the beam also lofts upward, as a fraction of its own length. Deliberately NOT
## capped, unlike the sideways bow: the loft is the one part of the arc that is doing
## legible work at range. It puts the apex of a long reach against the SKY rather than
## against the green ground the pony at the far end is also standing on (a pink ribbon on
## grass at 8 m is a lot harder to pick out than the same ribbon on grey) -- and because it
## keeps growing with length, HOW HIGH THE ARC RIDES IS ITSELF A DISTANCE CUE, which is
## exactly what the owner said was missing ("hard to gauge distance of beam"). Raised from
## 0.14 now that the sideways swerve is no longer competing with it for the eye.
const BOW_LIFT_FRACTION := 0.18

## Half-width of the ribbon at the horn and at the far end, in metres. Narrow where it
## leaves her and flared where it lands, so it reads as something being projected rather
## than as a rod -- and so the far end is still legible at REACH.
const BEAM_WIDTH_NEAR := 0.06
const BEAM_WIDTH_FAR := 0.30

## Radius of the glow at the far end, in metres: a bright bead while the beam is sweeping
## for something, and a wider, fainter aura wrapping whatever it has hold of.
const GLOW_TIP_RADIUS := 0.28
const GLOW_HELD_RADIUS := 0.70

# --- the landing marker ----------------------------------------------------------------
# THE OTHER HALF OF "HARD TO GAUGE DISTANCE OF BEAM". An arc hanging in the air has no
# ground reference, and a third-person camera 3.5 m behind the player flattens depth
# further -- so a beam ending 4 m away and a beam ending 8 m away look much the same. The
# fix is the oldest one in 3D games: put a mark ON THE GROUND under where the beam lands.
# The ground is a surface the player is already reading perspective off, so a ring on it
# is unambiguous in a way a floating bead is not, and it moves with the crosshair, which
# makes sweeping for range a thing you can DO rather than guess at.
#
# It doubles as the in-range answer: the ring is one colour over bare ground and another,
# larger one when there is actually something grabbable within reach under the crosshair.
# "Can I take her from here?" stops being a question you answer by trying.
#
# STRICTLY IT IS A LANDING MARK, NOT A GROUND MARK -- it lies on whatever surface the beam
# actually reached, oriented to that surface's normal, and only falls back to a downward
# probe when the beam ran out over open air. Over an empty field that is the grass, which
# is the case this was built for. Over a pony it is HER, and the render showed that reads
# as a target-lock ring around her, which is the right answer for the wrong reason and is
# kept deliberately: the rule stays the simple one ("the mark is where the beam lands"),
# and the picture is better than a ring hidden under her hooves would have been.

## Outer radius of the landing ring in metres, sweeping and locked-on.
##
## SIZED FROM A RENDER, not from what looks reasonable in the source. The first pass used
## 0.45 m and it was invisible in practice: the ring lies FLAT, and the camera sits about
## two metres off the ground, so at the far end of REACH it is foreshortened to roughly a
## twentieth of its width and reads as a couple of pink pixels lost in the grass. That
## foreshortening is not a flaw -- it is exactly the perspective cue that makes a ground
## marker worth drawing at all -- but the ring has to be big enough to survive it. At
## 0.75 m it is about a pony's own footprint, which is also the honest size for something
## that means "this is where the beam lands".
const MARK_RADIUS := 0.75
const MARK_LOCKED_RADIUS := 1.15
## Radial thickness of the ring's band. Wide enough that the near edge of a heavily
## foreshortened ring is still a band rather than a line.
const MARK_THICKNESS := 0.14
## Segments around the ring. 32 is smooth at the near distances where it is biggest.
const MARK_SEGMENTS := 32
## Metres the ring is lifted off the surface it was found on, so it does not z-fight with
## the terrain it is lying on.
const MARK_LIFT := 0.04
## How far above and below the beam's far end the ground is probed for, when the beam is
## pointing at open sky and there is no ray hit to sit the ring on.
const MARK_PROBE_UP := 3.0
const MARK_PROBE_DOWN := 40.0
## Colour of the ring when the crosshair has something grabbable in range. Deliberately
## NOT the beam's pink: this is the one piece of the effect that has to be readable AS a
## different state, and a brighter shade of the same hue reads as "the beam, but more".
## Matches the HUD reticle's own in-range colour so the two are obviously one signal.
const MARK_LOCKED_COLOR := Color(1.0, 0.86, 0.42)

## Half-width of the drop line, in metres: the thin vertical connector from the beam's far
## end down to the ring, drawn only when the beam ends in mid-air rather than on a surface
## (aimed over a hollow, or out at open sky). Without it those two are just a ribbon
## stopping at nothing and an unrelated circle on the grass some way below; with it the
## whole thing reads as one plumb line, which is the same trick every level editor's
## translate gizmo uses for the same reason.
const MARK_DROP_WIDTH := 0.045
## Metres of separation below which the drop line is not worth drawing.
const MARK_DROP_MIN := 0.20

@export_group("Look")
## The beam's colour: Twilight's magic aura. Exported so a future second caster (or a
## debug build) can be told apart at a glance without editing this file.
@export var beam_color := Color(0.98, 0.55, 0.95)

## Optional explicit override for the node providing get_aim_ray() (the CameraRig). Left
## empty, the beam finds it under the Player it is mounted on -- see _resolve_mount().
@export var aim_source_path: NodePath

var _storage: Storage

## The Player this beam is mounted under, and the Marker3D at her horn. Both may be null
## if the beam is used standalone, in which case the beam draws from its own origin.
var _player: Node3D
var _beam_anchor: Node3D
## Whatever answers get_aim_ray() -- normally the CameraRig.
var _aim_source: Node

## The live aim ray, refreshed once per physics frame. Kept as two plain Vectors rather
## than CameraRig.AimRay so the fallback path (no rig at all, just the viewport camera)
## does not have to construct a type that belongs to another file.
var _aim_origin := Vector3.ZERO
var _aim_direction := Vector3.FORWARD

## Is the button down? (Not the same as is_holding(): the beam can be on and empty, which
## is exactly the state you sweep across a field in.)
var _beaming := false

## Whether the Company has "recalled" the horn (game/systems/ledger.gd's collector ladder).
## A recalled beam will not start, and a recall while she is holding somebody puts that pony
## DOWN through the ordinary release path. It is a punishment, and every punishment in this
## game is reversible and takes nothing away: the pony is still there, the bag is still
## full, and paying the balance down hands the horn straight back.
var _recalled := false

var _held: Node3D
var _hold_seconds := 0.0
## The two clocks THIS hold is running on, rolled once at _begin_hold() -- not the nominal
## constants. Read back through get_struggle_seconds() / get_secure_seconds(), which is
## what the HUD draws its two rings from, so what is on screen is always the truth about
## the attempt in progress rather than an average of attempts in general.
var _struggle_seconds := STRUGGLE_NEVER
var _secure_seconds := SECURE_NEVER
## Whether this hold is one she is going to tear out of before it can secure her. Decided
## at acquisition, never mid-hold: the outcome is fixed the moment the beam takes her, and
## the two rings then play it out honestly. Nothing the player does after the grab can
## change it, which is exactly why the falloff in wrench_chance_for() has to be the thing
## that guarantees they eventually win.
var _wrenching := false
## Offset from the hold point to the held body's ORIGIN -- see PONY_HOLD_LIFT.
var _hold_offset := Vector3.ZERO
## RigidBody3D state borrowed at grab time and handed back on release.
var _prev_freeze := false
var _prev_freeze_mode := RigidBody3D.FREEZE_MODE_STATIC

## The generator behind every per-attempt roll -- the jitter on both clocks, and whether a
## HARD hold wrenches. Entropy-seeded in _ready() so two players do not get the same run of
## luck; replaceable through set_capture_rng() so a gate can have a reproducible one.
var _rng := RandomNumberGenerator.new()

## Metres of extra reach bought from the shop: 0.0 or LONG_BEAM_BONUS, set by
## apply_unlocks(). Read only through reach(); nothing should add it to REACH by hand.
var _reach_bonus := 0.0

var _cooldown := 0.0
## Why the most recent lost hold was lost -- see the Loss enum.
var _last_loss := Loss.NONE
## Where the beam visual currently ends when nothing is held: the ray's hit point, or the
## end of its reach.
var _ray_end := Vector3.ZERO
var _elapsed := 0.0

## Whether the last scan found something grabbable inside REACH under the crosshair --
## refreshed every frame the beam is on and empty, INDEPENDENTLY of whether the beam was
## allowed to take it (the post-escape cooldown must not blank the reticle's answer to
## "is she in range", or the readout lies for a second and a quarter at exactly the moment
## the player is re-aiming at an escapee).
var _has_target := false
## Where the landing ring sits and which way it lies, from the last scan.
var _mark_point := Vector3.ZERO
var _mark_normal := Vector3.UP
var _mark_valid := false

var _beam_mesh: MeshInstance3D
var _beam_material: StandardMaterial3D
var _glow_mesh: MeshInstance3D
var _mark_mesh: MeshInstance3D
var _mark_material: StandardMaterial3D
var _voice: AudioStreamPlayer
var _voice_played := false
var _assist_shape: SphereShape3D


func _ready() -> void:
	_storage = StorageScript.new(storage_capacity)
	# Entropy, not a fixed seed: a capture that played out identically for every player on
	# their first Rainbow Dash would make the variance pointless. Gates override it.
	_rng.randomize()
	_assist_shape = SphereShape3D.new()
	_assist_shape.radius = GRAB_ASSIST_RADIUS
	_resolve_mount()
	_build_effect()
	_build_voice()
	_hide_effect()


## Hand back anything still in the beam when the beam itself goes away.
##
## THE ONE HOLD-EXIT NOTHING ELSE COVERED. A pony in State.HELD runs no gravity, no
## steering and no move_and_slide -- pony.gd's HELD branch returns before all of it,
## deliberately, so the beam can own her transform. If the beam (or the Player it hangs
## off) is freed mid-hold -- a scene change, a despawn, a level reload -- nothing is left
## to let go of her and she hangs in the air in HELD forever. She does not die, so the
## project rule holds, but "stranded mid-air until the process ends" is not a state any
## pony should be able to reach.
##
## Deliberately NOT release(): a tree being torn down is not the player deciding to
## capture something, and quietly storing a record into a Storage that is about to be
## collected would be a capture nobody asked for and nobody could see. She is simply
## handed back to herself, wherever she was floating.
func _exit_tree() -> void:
	var body := _held
	_held = null
	_beaming = false
	if body == null or not is_instance_valid(body):
		return
	_take_back_physics(body)
	if body is PonyScript:
		body.set_held(false)


# --- public interface -----------------------------------------------------------------

## Hand the beam a seeded generator so a scene's captures are reproducible -- the same
## affordance Pony.set_rng() gives the herd, and for the same reason. Call before the first
## grab. Without it the beam rolls off its own entropy-seeded generator and no gate can pin
## which attempt wrenched.
##
## NOT A BYPASS. A seeded generator still rolls the real rules; a gate that wants a hold
## which cannot wrench says so through the published rule instead, by handing the beam a
## pony whose `beam_holds` is already past WRENCH_GRACE_HOLDS.
func set_capture_rng(rng: RandomNumberGenerator) -> void:
	if rng != null:
		_rng = rng


## Switch the beam on. Acquisition happens on the next physics frame (the space-state
## query has to run inside the physics step), so is_holding() is still false immediately
## after this returns -- wait a frame.
func grab() -> void:
	_start_beam()


## The guts of grab(), factored out so the recall guard has one place to live. Private:
## grab() is the interface other tasks depend on (see the class comment), so nothing
## outside this file should call this directly except a test that wants to check the
## guard without going through Input.
func _start_beam() -> void:
	if _recalled:
		return
	_beaming = true


## Switch the beam off, and settle whatever was in it.
##
## THE OUTCOME NOW DEPENDS ON HOW LONG YOU HELD HER, which is the whole of the capture
## contest (see SECURE_SECONDS). A pony held at least that long is SECURED: she goes into
## storage if there is room -- her record is stored, `captured()` fires, her node is freed
## -- and otherwise is set down in the world unharmed with `capture_refused()`. A pony let
## go before that has not been subdued at all; the field slips off her and she drops back
## into the world exactly the way she does when she out-lasts the struggle timer, reported
## the same way (`escaped()`), because from her point of view it is the same event: the
## beam let go and she is still free. A held prop was never being subdued and just drops.
func release() -> void:
	_beaming = false
	var body := _held
	var was_secured := is_secured()
	_take_back_physics(body)
	_held = null

	if body != null and is_instance_valid(body):
		if body is PonyScript:
			if was_secured:
				_settle_pony(body)
			else:
				_lose(body, Loss.SLIPPED)
	_hide_effect()


## Whether something is in the beam right now.
func is_holding() -> bool:
	return _held != null and is_instance_valid(_held)


## Whether the beam is switched on at all (holding or sweeping for something to hold).
func is_active() -> bool:
	return _beaming


## THE COLLECTOR'S RECALL (game/systems/ledger.gd). Called by game/world/ranch.gd's
## _apply_beam_recall(), never by the beam itself. Idempotent: setting the same value
## twice is a no-op, so a phase change that fires twice in one frame cannot double-release
## whatever she happens to be holding.
func set_recalled(value: bool) -> void:
	if _recalled == value:
		return
	_recalled = value
	if not _recalled:
		return
	if is_holding():
		release()
	_beaming = false


func is_recalled() -> bool:
	return _recalled


## What is currently in the beam, or null.
func get_held_body() -> Node3D:
	return _held if is_holding() else null


## The player's capture storage. The beam owns it because the beam is what fills it; a
## later inventory/barn system should read it from here rather than making a second one.
func get_storage() -> Storage:
	return _storage


## How far the beam reaches right now, gear included. Every ray and hold-point
## calculation reads this rather than REACH so an upgrade applies everywhere at once.
func reach() -> float:
	return REACH + _reach_bonus


## Apply every gear unlock in `unlocks` this beam understands. Idempotent.
##
## Idempotent by being ABSOLUTE rather than incremental: each gear id sets its effect to
## the value that owning it means, so calling this twice (which Ranch does, once on boot
## and again after every purchase) cannot stack a bonus or grow a bag twice.
##
## For THE REACH, absolute also means reversible: an unlock that disappeared from the array
## takes its bonus away with it, so this is safe to call with whatever GameState currently
## holds. The SADDLEBAG does not come back down, and deliberately: Storage.set_capacity()
## refuses to shrink below the ponies already in the bag, because a capacity under the
## contents would refuse every future store() while the bag sat over its own limit. A
## revoked saddlebag would therefore have to decide which ponies to drop, and no pony ever
## dies.
func apply_unlocks(unlocks: Array) -> void:
	if unlocks.has(String(GEAR_BIGGER_SADDLEBAG)):
		_storage.set_capacity(BIGGER_SADDLEBAG_CAPACITY)
	_reach_bonus = LONG_BEAM_BONUS if unlocks.has(String(GEAR_LONG_BEAM)) else 0.0


## Let the most recently caught pony back OUT of the bag and into the world, as a live
## Pony node carrying the state she went in with. Returns her, or null if the bag was empty
## or her `data_id` does not resolve on this build's roster.
##
## THIS RETIRES A REAL FINDING. `Storage.release()` shipped with ZERO CALLERS -- the bag
## was a one-way trip and nothing in the game could open it. That was flagged in Phase 1A's
## review and carried into Phase 1B's plan as a named carried fact; this is the caller.
##
## SHE IS THE SAME PONY, NOT A NEW COPY OF HER CHARACTER. The PonyInstance comes out of
## storage intact -- uid, happiness, hunger, caught_at_ms -- and is handed to Pony.adopt(),
## which keeps it. So letting her out and catching her again does not reset her, and the
## beam's capture path (see _settle_pony) reuses the instance she is already carrying.
## Rebuilding from her `data_id` rather than from a cached node is also what keeps the
## mane/tail spring simulation attached: PonyRegistry -> PonyVisuals is the only sanctioned
## spawn path (docs/notes-hair-sim.md), and adopt() -> setup() goes through it.
##
## `parent` defaults to whatever the Player is parented to (the world root in ranch.tscn),
## so a released pony ends up a sibling of the spawner's herd rather than a child of the
## player who would then drag her around. `at` defaults to RELEASE_LEAD metres in front of
## the player, lifted RELEASE_LIFT so she falls the last few centimetres onto the ground
## under her own gravity instead of being born inside it.
##
## COLLISION LAYERS ARE ASSIGNED HERE, exactly as game/world/spawner.gd assigns them to a
## freshly spawned wild pony and for the same reason: pony.tscn is shared with Phase 0-era
## test scenes built entirely on the default layer 1, so the world's layer policy is
## applied per instance rather than baked into the scene. Keeping the two in step matters
## -- a released pony on the wrong layer would walk through the barn that a spawned one
## bumps into.
##
## Task 3's pens will do the same three things (take an instance, instantiate pony.tscn,
## adopt) with their own placement and leash, so this is the player's door out of the bag
## rather than a general-purpose spawner they should be routed through.
func release_stored(parent: Node = null, at: Vector3 = Vector3.INF) -> Node3D:
	var instance: PonyInstance = _storage.peek()
	if instance == null:
		return null
	if instance.data() == null:
		# Refused BEFORE the pop, so a pony whose character this build cannot build stays
		# in the bag rather than being destroyed by trying to let her out. She is still
		# there, and still hers, when a build that has her record loads the save.
		push_error("MagicBeam.release_stored: '%s' has no PonyData on this build's roster ('%s')"
			% [String(instance.uid), String(instance.data_id)])
		return null

	var host := parent
	if host == null:
		host = _player.get_parent() if _player != null else null
	if host == null:
		host = get_tree().current_scene if get_tree() != null else null
	if host == null:
		host = self

	instance = _storage.release()

	var pony: Node3D = PonyScene.instantiate()
	pony.name = "Pony_%s" % String(instance.uid).replace(PonyInstanceScript.UID_SEPARATOR, "_")
	pony.collision_layer = LayersScript.PONY
	# PONY_WALKABLE, not WALKABLE: WALKABLE plus the PEN_GATE bit a pen's gate leaf sits on.
	# Every pony carries it whether or not she has ever seen a pen -- a pony who acquired it
	# only on moving into one would walk out of the first pen she was ever put in.
	pony.collision_mask = LayersScript.PONY_WALKABLE
	var detection := pony.get_node_or_null("DetectionArea") as Area3D
	if detection != null:
		detection.collision_layer = LayersScript.INTERACTION
		detection.collision_mask = LayersScript.PLAYER

	# Positioned BEFORE add_child(): Pony._ready() records wherever she is standing at that
	# moment as her roam anchor, and a pony added at the origin and moved afterwards spends
	# the rest of her life being leashed back to the origin (pony.gd's setup() says so).
	#
	# Written as a LOCAL position converted through the host, not as global_position: a node
	# that is not in the tree yet has no global transform to write to, so assigning
	# global_position here would silently mean "local" and put her in the wrong place under
	# any host that is not sitting at the world origin. spawner.gd does the same conversion
	# for the same reason.
	var point: Vector3 = at if at != Vector3.INF else _release_point()
	pony.position = (host as Node3D).to_local(point) if host is Node3D else point
	host.add_child(pony)
	pony.adopt(instance)

	released.emit(pony, instance)
	return pony


## Where a released pony is set down when the caller does not say: in front of the player,
## slightly above the ground so she lands rather than spawns inside it. Flattened to the
## horizontal, so letting one out while looking at the sky does not launch her.
##
## The aim is REFRESHED first rather than read off `_aim_direction` as it stands.
## _physics_process only updates that while the beam is switched ON, and letting a pony out
## of the bag is something you do with the beam off -- so the stored value would be whatever
## the last grab was aimed along, or the initial Vector3.FORWARD if the player has never
## beamed at all. Either way she would appear somewhere the player is not looking, and the
## FORWARD case is the nasty one: it is a perfectly valid direction, so no degenerate-vector
## guard below would ever notice it was stale.
func _release_point() -> Vector3:
	_update_aim()
	var anchor := _anchor_node()
	var forward := Vector3(_aim_direction.x, 0.0, _aim_direction.z)
	if forward.length_squared() < 0.000001:
		forward = -anchor.global_transform.basis.z
		forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var base: Vector3 = _player.global_position if _player != null else anchor.global_position
	return base + forward * RELEASE_LEAD + Vector3.UP * RELEASE_LIFT


## Seconds the current hold has lasted (0 when nothing is held).
func get_hold_seconds() -> float:
	return _hold_seconds if is_holding() else 0.0


## Seconds the currently held body will resist before breaking free, or INF for something
## that never does.
func get_struggle_seconds() -> float:
	return _struggle_seconds if is_holding() else STRUGGLE_NEVER


## Seconds the beam needs to subdue the currently held body before it can be stowed, or 0
## for something that does not need subduing at all (a prop).
func get_secure_seconds() -> float:
	return _secure_seconds if is_holding() else SECURE_NEVER


## How far the current hold has got toward being secured, 0..1. What the HUD fills its
## capture arc from -- exposed as a fraction rather than as two clocks so there is one
## place that decides what "nearly there" means.
func get_secure_progress() -> float:
	if not is_holding() or _secure_seconds <= 0.0:
		return 1.0
	return clampf(_hold_seconds / _secure_seconds, 0.0, 1.0)


## Whether the current hold has lasted long enough that letting go would STOW her rather
## than lose her. False when nothing is held.
func is_secured() -> bool:
	return is_holding() and _hold_seconds >= _secure_seconds


## Whether the hold in progress is one she will tear out of before it can secure her (see
## WRENCH_CHANCE_HARD). Exposed for the gates, which have to be able to say "this attempt
## was a wrench" without inferring it from a timer that has already run out. The HUD does
## NOT read this -- it does not need to, because the two rings already show it happening.
func is_wrenching() -> bool:
	return is_holding() and _wrenching


## Why the most recent `escaped()` happened: Loss.SLIPPED (let go too early) or
## Loss.STRUGGLED (held too long). Loss.NONE until one has.
func get_last_loss() -> int:
	return _last_loss


## Whether the crosshair currently has something grabbable within reach -- a pony or a
## loose prop the beam could take from here. True whether or not the beam is switched on
## (see the scan note in _physics_process: an in-range readout you can only get by pressing
## the button is a readout that arrives after the decision), and true while actually
## holding something. The HUD's in-range reticle reads this; it is the answer to the
## question the owner could not answer by looking ("hard to gauge distance of beam"),
## which no amount of tuning the beam's own geometry can give on its own.
func has_target() -> bool:
	return is_holding() or _has_target


## Where the beam's landing ring is being drawn, in world space, and whether it is being
## drawn at all (false when the beam is off, or aimed at open sky over nothing).
func get_mark_point() -> Vector3:
	return _mark_point


func has_mark() -> bool:
	return _mark_valid and _beaming and not is_holding()


## Where a held body is being pulled to right now, in world space.
func get_hold_point() -> Vector3:
	return hold_point(_aim_origin, _aim_direction, _anchor_position())


## The difficulty GRADE of a hold, read off the personality a pony already carries. A
## pure view of PonyData.personality, not a second field to keep in step with it -- see
## the Grade enum for why the ordering is the way round it is.
##
## Anything a future roster adds without a grade of its own is HARD, which is the same
## fallback Pony.reaction_state() takes: a roster addition that behaved like a BOLD pony on
## the ground and like a CURIOUS one in the beam would be more confusing than one that is
## simply a handful. game/test/test_magic_beam.gd pins that the fallback still leaves a
## hittable window.
static func grade_for(personality: int) -> int:
	match personality:
		PonyDataScript.Personality.SHY:
			return Grade.EASY
		PonyDataScript.Personality.CURIOUS:
			return Grade.MEDIUM
		_:
			return Grade.HARD


## The name of a grade, for gate output and error messages.
static func grade_name(grade: int) -> String:
	return Grade.keys()[grade] if grade >= 0 and grade < Grade.size() else "INVALID(%d)" % grade


## The seconds of slack a player has to let go in, for a pony with this `personality`,
## BEFORE the per-attempt jitter: everything between "the beam has subdued her" and "she
## has won". This is the number that says how hard she is to catch. Static and pure, so
## the one rule that grades the personalities is pinned by a unit test rather than only by
## a scene (game/test/test_magic_beam.gd).
static func capture_window_for(personality: int) -> float:
	match grade_for(personality):
		Grade.EASY:
			return WINDOW_EASY
		Grade.MEDIUM:
			return WINDOW_MEDIUM
		_:
			return WINDOW_HARD


## The narrowest and widest that window can actually be rolled at, as (min, max). The
## bound on the randomness, exposed rather than left implicit in the arithmetic, because
## "bounded" is the property that separates variance from a slot machine and the floor is
## the number a human should be able to check at a glance.
static func window_bounds_for(personality: int) -> Vector2:
	var base: float = capture_window_for(personality)
	return Vector2(base * (1.0 - WINDOW_JITTER), base * (1.0 + WINDOW_JITTER))


## The narrowest and widest the subdue clock can be rolled at, as (min, max).
static func secure_bounds() -> Vector2:
	return Vector2(SECURE_SECONDS - SECURE_JITTER, SECURE_SECONDS + SECURE_JITTER)


## How long a pony with this `personality` resists the beam, in seconds, on a NOMINAL
## attempt -- the middle of the distribution, with no jitter and no wrench. What a gate or
## a design note should quote when it wants to say "roughly this long"; what an actual hold
## runs on is rolled per attempt by roll_clocks() and read back through
## get_struggle_seconds().
static func struggle_seconds_for(personality: int) -> float:
	return SECURE_SECONDS + capture_window_for(personality)


## The chance that a hold on this `personality` is torn out of before it can secure her,
## given how many times the beam has ALREADY had hold of this particular pony.
##
## THE FALLOFF IS THE WHOLE ANSWER TO "but will eventaully let you catch". It is not a pity
## timer bolted on beside a dice roll -- it is the dice themselves being taken away, one
## face at a time, until by WRENCH_GRACE_HOLDS prior grabs there is nothing left to roll.
## So a player who keeps doing it right cannot be held off indefinitely, and the bound is
## small: at most WRENCH_GRACE_HOLDS wrenches from any one pony, ever.
static func wrench_chance_for(personality: int, prior_holds: int) -> float:
	if grade_for(personality) != Grade.HARD:
		return 0.0
	return maxf(0.0,
		WRENCH_CHANCE_HARD - WRENCH_CHANCE_FALLOFF * float(maxi(prior_holds, 0)))


## The two clocks ONE attempt runs on, plus whether this is a wrenching attempt, as
## {"secure": float, "struggle": float, "wrenches": bool}.
##
## PURE, WITH THE RANDOMNESS PASSED IN. The three rolls are unit floats the caller draws
## (see _begin_hold, which draws them from the beam's own RandomNumberGenerator); nothing
## in here touches a generator or a clock. That is what lets every property this mechanic
## claims -- the bounds, the grading, the wrench falloff, the convergence -- be swept
## exhaustively in milliseconds by game/test/test_magic_beam.gd instead of inferred from a
## handful of live captures.
##
## EXACTLY THREE ROLLS ARE DRAWN, WHATEVER HAPPENS, and that is deliberate rather than
## incidental: a draw count that depended on the outcome would make a seeded run's whole
## future sequence depend on how the last attempt went, and every seeded gate downstream
## would shift the moment any of this was retuned. So the window roll doubles as the roll
## for WHEN a wrench lands -- on a wrenching attempt the window is not used for anything
## else, and on any other attempt the wrench moment is not.
static func roll_clocks(personality: int, prior_holds: int,
		wrench_roll: float, secure_roll: float, window_roll: float) -> Dictionary:
	var secure: float = SECURE_SECONDS \
		+ lerpf(-SECURE_JITTER, SECURE_JITTER, clampf(secure_roll, 0.0, 1.0))
	var wrenches: bool = wrench_roll < wrench_chance_for(personality, prior_holds)
	var bounds: Vector2 = window_bounds_for(personality)
	var struggle: float = secure + lerpf(bounds.x, bounds.y, clampf(window_roll, 0.0, 1.0))
	if wrenches:
		# SHORTER than the subdue clock she is racing, which is the whole of the
		# implementation: the existing struggle timer fires first, _run_struggle sees the
		# hold had not secured her yet, and reports Loss.WRENCHED.
		struggle = secure * lerpf(WRENCH_AT_MIN, WRENCH_AT_MAX,
			clampf(window_roll, 0.0, 1.0))
	return {"secure": secure, "struggle": struggle, "wrenches": wrenches}


## The point a held body floats at: `anchor` projected onto the aim ray, plus HOLD_LEAD
## along it (floored at MIN_HOLD_DISTANCE from the ray's origin), then pushed HOLD_SIDE
## screen-right and HOLD_LIFT screen-up so the held body is not hidden behind the player.
## Static and pure so both the zoom invariance and the offset are testable without a
## camera.
static func hold_point(origin: Vector3, direction: Vector3, anchor: Vector3) -> Vector3:
	var along := (anchor - origin).dot(direction)
	var forward := origin + direction * maxf(along + HOLD_LEAD, MIN_HOLD_DISTANCE)

	# Screen-right and screen-up for this ray. UP is the natural reference; RIGHT covers
	# the degenerate case of aiming straight up or straight down, where the first cross
	# product collapses.
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.000001:
		right = direction.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(direction).normalized()
	return forward + right * HOLD_SIDE + up * HOLD_LIFT


## How far along the aim ray the beam can reach, given where the player sits on it. Same
## projection as hold_point(), for the same zoom-invariance reason.
##
## `p_reach` is how far the beam reaches past her, and the live caller passes reach() so
## the shop's long beam lengthens the scan ray. It stays a PARAMETER, and this function
## stays static and pure, because the zoom invariance above it is the property worth
## pinning and it is worth pinning without a scene; the default is the unupgraded beam,
## which is what the tests measure.
static func reach_distance(origin: Vector3, direction: Vector3, anchor: Vector3,
		p_reach := REACH) -> float:
	return maxf((anchor - origin).dot(direction), 0.0) + p_reach


# --- frame ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_cooldown = maxf(0.0, _cooldown - delta)

	if Input.is_action_just_pressed(BEAM_ACTION):
		grab()
	elif Input.is_action_just_released(BEAM_ACTION):
		release()

	# A held body can be freed out from under us by something else entirely (a despawn, a
	# scene change). Notice it here rather than dereferencing a dead node below.
	if _held != null and not is_instance_valid(_held):
		_held = null

	_update_aim()

	# SCANNED EVERY FRAME, INCLUDING WHEN THE BEAM IS SWITCHED OFF. Three jobs, and the
	# third is why this is not gated on `_beaming` any more:
	#   1. it finds what to grab;
	#   2. it tells the effect where to END (which is why it also runs during the
	#      post-escape cooldown, when it may not grab -- otherwise the beam would be drawn
	#      to a stale point for the whole of it);
	#   3. it answers has_target(), which the HUD reticle uses to say "she is in range".
	# That third answer is worthless if it can only be had while the beam is ON, because
	# switching the beam on with a pony in the crosshair GRABS her on the same frame -- so
	# the in-range state would exist for one frame, after the decision it was supposed to
	# inform. "Am I close enough?" has to be answerable before you commit, or the reticle
	# is telling you something you already know.
	#
	# The cost is one ray cast and one small sphere query per physics frame while idle,
	# which is nothing next to what the rest of the frame is doing; the mark and the ribbon
	# are still only DRAWN while the beam is on (see has_mark(), and _hide_effect below).
	if _held == null:
		_scan(_beaming and _cooldown <= 0.0)

	if not _beaming:
		_hide_effect()
		return

	if _held != null:
		_pull(delta)
		_run_struggle(delta)

	_draw_effect()


# --- aiming and acquisition -----------------------------------------------------------

## Refresh `_aim_origin`/`_aim_direction` from the camera rig -- or, if this beam is used
## without one, from whatever camera the viewport is actually rendering, projected through
## the screen centre exactly the way CameraRig.get_aim_ray() does it. The fallback exists
## so a test scene can use the beam without dragging a whole rig in, not because the rig
## is optional in the game.
func _update_aim() -> void:
	if _aim_source != null and is_instance_valid(_aim_source):
		var ray = _aim_source.get_aim_ray()
		_aim_origin = ray.origin
		_aim_direction = ray.direction
		return

	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		var center: Vector2 = viewport.get_visible_rect().size * 0.5
		_aim_origin = camera.project_ray_origin(center)
		_aim_direction = camera.project_ray_normal(center)
		return

	# No camera at all (a headless unit test): aim straight out of the horn.
	var anchor := _anchor_node()
	_aim_origin = anchor.global_position
	_aim_direction = -anchor.global_transform.basis.z


## Look along the aim ray: record where the beam ends (`_ray_end`, which the effect draws
## to) and, if `can_grab`, take the first grabbable thing found. The two jobs share one
## cast because they are the same cast.
##
## TWO PASSES, and the second one is not padding. A bare ray is unforgiving in exactly the
## situation the mechanic is used in: the camera looks slightly DOWN by default
## (CameraRig.default_pitch_deg is -12), so a crosshair resting on a pony standing on the
## ground reaches her capsule at a very shallow angle and grazes past its bottom into the
## grass -- verified by arithmetic against the actual capsule (radius 0.42, centre 0.65)
## before it was written. So: cast the ray; if it did not land on something grabbable,
## sweep a GRAB_ASSIST_RADIUS sphere at wherever it DID land and take the nearest
## grabbable thing overlapping it. That forgives "I was aiming at the grass under her" and
## nothing wider.
func _scan(can_grab: bool) -> void:
	_has_target = false
	_mark_valid = false

	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var distance := reach_distance(_aim_origin, _aim_direction, _anchor_position(), reach())
	var end := _aim_origin + _aim_direction * distance
	_ray_end = end

	var query := PhysicsRayQueryParameters3D.create(_aim_origin, end)
	query.exclude = _exclusions()
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_ray_end = hit["position"]
		# The surface the ray landed on IS the surface to lie the ring on, normal and all
		# -- no second cast needed, and it means the ring hugs a slope rather than floating
		# level over it.
		_mark_at(hit["position"], hit.get("normal", Vector3.UP))
		var body: Object = hit["collider"]
		if _is_grabbable(body):
			# Recorded BEFORE the cooldown gate, deliberately: "there is something in range"
			# stays true through the post-escape cooldown, because that is exactly when the
			# player is re-aiming and needs to know it.
			_has_target = true
			if can_grab:
				_begin_hold(body)
				return

	# Forgiveness pass, centred on whatever the ray actually reached. Runs whether or not
	# the beam may grab, for the same reason as above -- the reticle must answer the same
	# question the grab would.
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _assist_shape
	params.transform = Transform3D(Basis(), _ray_end)
	params.exclude = _exclusions()
	var nearest: Node3D = null
	var nearest_distance := INF
	for result in space.intersect_shape(params, 8):
		var body: Object = result["collider"]
		if not _is_grabbable(body):
			continue
		var candidate := body as Node3D
		var gap: float = candidate.global_position.distance_to(_ray_end)
		if gap < nearest_distance:
			nearest = candidate
			nearest_distance = gap
	if nearest != null:
		_has_target = true
		if can_grab:
			_begin_hold(nearest)
			return

	if not _mark_valid:
		# The beam is pointing at open sky, so the ray gave no surface to mark. Probe
		# straight down from the far end instead: the ring then sits on the ground BELOW
		# where the beam runs out, which is still the answer to "how far does this thing
		# go", and is the case a player sweeping across an empty field is in most of the
		# time.
		var probe := PhysicsRayQueryParameters3D.create(
			_ray_end + Vector3.UP * MARK_PROBE_UP, _ray_end + Vector3.DOWN * MARK_PROBE_DOWN)
		probe.exclude = _exclusions()
		var ground := space.intersect_ray(probe)
		if not ground.is_empty():
			_mark_at(ground["position"], ground.get("normal", Vector3.UP))


## Record where the landing ring goes. Degenerate normals (a collider that reports none)
## fall back to straight up rather than producing a ring lying in an undefined plane.
func _mark_at(point: Vector3, normal: Vector3) -> void:
	var up := normal
	if up.length_squared() < 0.000001:
		up = Vector3.UP
	up = up.normalized()
	_mark_point = point + up * MARK_LIFT
	_mark_normal = up
	_mark_valid = true


## A wild pony, or any loose rigid body. The rigid bodies cost almost nothing to support
## and are the part of the mechanic people play with for its own sake -- a beam that can
## only pick up quest objects is a menu, not a toy.
##
## EXCEPT A PONY WHO HAS ALREADY BEEN DELIVERED. Pony.is_being_delivered() is true for
## exactly the walk from the pen to the Depot crate, and taking her off it would hand the
## player the credit AND the pony back: release drops a held pony into
## _settle_pony(), which stores the very PonyInstance the delivery removed from the save.
## So she is declined here, at the one gate every grab in this file goes through (the ray
## hit and the forgiveness pass both ask this), which also keeps the reticle honest --
## nothing lights up over a pony the beam will not take.
##
## THIS IS THE ONE EXCEPTION TO "CAPTURE WINS", AND IT TAKES NOTHING. A declined grab is a
## beam that does not start; she keeps walking, and the only thing that ever frees her is
## still her own arrival in Pony._state_leaving. An ORDINARY departure (a pony whose hours
## ended, no target) stays grabbable to the last step, as it always was.
func _is_grabbable(body: Object) -> bool:
	if body is PonyScript:
		return not (body as PonyScript).is_being_delivered()
	return body is RigidBody3D


## RIDs the casts must ignore: the player's own body, which the ray starts inside of
## (the camera sits behind her, so a ray from the lens passes straight through her).
func _exclusions() -> Array[RID]:
	var rids: Array[RID] = []
	if _player is CollisionObject3D:
		rids.append((_player as CollisionObject3D).get_rid())
	return rids


# --- holding --------------------------------------------------------------------------

## get_node(), not the bare `Sound` identifier: tools/run_tests.sh's parse sweep runs every
## .gd file through `--check-only --script`, and that pass never boots the scene tree, so
## an autoload's name is never registered as a resolvable global identifier there, even
## though it resolves fine in a real run (the game, or GUT's own actual test pass). See
## game/test/test_sound.gd's own comment on the same limitation.
##
## is_inside_tree() first, so a beam built with `.new()` and never added anywhere (a purely
## static test fixture, if one is ever written) gets a silent no-op rather than the engine
## error get_node() prints on a treeless node.
func _sound_call(method: StringName, args: Array) -> void:
	if not is_inside_tree():
		return
	var node: Node = get_node_or_null(^"/root/Sound")
	if node != null:
		node.callv(method, args)


func _begin_hold(body: Node3D) -> void:
	_held = body
	_hold_seconds = 0.0
	# play_loop, not play_at: a pooled one-shot cannot be individually addressed, so a grab
	# released before the clip's 1.19s ran out used to ring on regardless. A dedicated,
	# stoppable voice fixes that; see _take_back_physics(), which stops it on every path a
	# hold can end. Not spatial, unlike the play_at() this replaces, but the beam is always
	# within a stride of the player who is holding it, so the loss is negligible.
	_sound_call(&"play_loop", [&"capture_charge"])
	_hold_offset = Vector3.ZERO
	_wrenching = false

	if body is PonyScript:
		body.set_held(true)
		_hold_offset = Vector3(0.0, -PONY_HOLD_LIFT, 0.0)
		var data: PonyData = body.get_data()
		var personality: int = data.personality if data != null \
			else PonyDataScript.Personality.BOLD
		# COUNTED BEFORE THIS HOLD, and counted on HER, which is what makes the wrench
		# falloff a promise about one particular pony rather than about the session. The
		# counter lives on the pony (Pony.beam_holds) so it dies with her and cannot leak
		# into a dictionary of freed nodes; the RULE it feeds stays here, in
		# wrench_chance_for(), so there is still one place that decides what a hold means.
		var prior_holds: int = body.beam_holds
		body.beam_holds += 1
		var clocks := roll_clocks(personality, prior_holds,
			_rng.randf(), _rng.randf(), _rng.randf())
		_secure_seconds = clocks["secure"]
		_struggle_seconds = clocks["struggle"]
		_wrenching = clocks["wrenches"]
		return

	if body is RigidBody3D:
		var rigid := body as RigidBody3D
		_prev_freeze = rigid.freeze
		_prev_freeze_mode = rigid.freeze_mode
		# KINEMATIC rather than STATIC so writing the transform actually moves it (and so
		# it sweeps other bodies out of the way on the trip in) instead of teleporting a
		# static obstacle around the world.
		rigid.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rigid.freeze = true
		_struggle_seconds = STRUGGLE_NEVER
		_secure_seconds = SECURE_NEVER
		_wrenching = false


## Reel the held body toward the hold point and turn it slowly while it floats.
func _pull(delta: float) -> void:
	var target := get_hold_point() + _hold_offset
	var weight := 1.0 - exp(-PULL_RESPONSE * delta)
	_held.global_position = _held.global_position.lerp(target, weight)
	_held.rotation.y += HELD_SPIN_RATE * delta


## Count the hold, and hand the body back if it outlasts its struggle time. This is the
## decision pony.gd used to make for itself; it is here now, so there is exactly one clock
## that says what a hold means.
func _run_struggle(delta: float) -> void:
	_hold_seconds += delta
	if _hold_seconds < _struggle_seconds:
		return

	var body := _held
	# WHICH KIND OF LOSS THIS WAS IS DERIVED, NOT STORED. A struggle time that runs out
	# before the subdue clock has finished can only be a wrench -- every non-wrenching
	# attempt rolls its struggle as (subdue + a positive window), so the comparison is
	# exact rather than approximate, and there is no second flag to fall out of step.
	var reason: int = Loss.WRENCHED if _hold_seconds < _secure_seconds else Loss.STRUGGLED
	_take_back_physics(body)
	_held = null
	_lose(body, reason)


## The one exit from a hold that is not a capture, used by BOTH ways of failing one: she
## out-lasted the struggle timer (_run_struggle above), or she was let go before the beam
## had subdued her (release()). Deliberately one code path -- an escape that set the
## cooldown and a slip that did not would be a mechanic with a hole in it exactly where
## the player is fumbling. Callers hand the physics back first.
##
## Reported as `escaped()` in both cases: from the pony's point of view they are the same
## event -- the beam let go and she is still free. `reason` is recorded rather than
## signalled, so listeners that do not care are unaffected and the HUD, which does care,
## can tell the player WHICH mistake they just made. Teaching "you let go too soon" is the
## difference between a mechanic a player learns and one they think is random.
func _lose(body: Node3D, reason: int) -> void:
	_last_loss = reason
	_wrenching = false
	# A wrench is the one loss the player did not cause, so it costs less -- see
	# WRENCH_COOLDOWN.
	_cooldown = WRENCH_COOLDOWN if reason == Loss.WRENCHED else ESCAPE_COOLDOWN
	if body == null or not is_instance_valid(body):
		return
	if body is PonyScript:
		# break_free() is what releases the hold AND reports escaped() -- the pony still
		# owns the announcement, this file only owns the decision.
		body.break_free()
	escaped.emit(body)


## Undo whatever _begin_hold() borrowed, WITHOUT deciding what the hold meant. Two callers
## want different outcomes afterwards (a release settles the pony, a lost struggle frees
## her), and both want the borrowing undone first.
##
## The yaw reset is not cosmetic: pony.gd documents that a pony's BODY never rotates (only
## her `Visuals` child does, and _update_facing writes that in world terms), so a body left
## spinning by the beam would offset every facing she computes for the rest of her life.
## The beam borrows that yaw for the float and hands it back at zero.
func _take_back_physics(body: Node3D) -> void:
	# UNCONDITIONAL, ahead of the body check below: every path a hold can end (a settle, an
	# escape, a wrench, the tree tearing down) runs through here, and capture_charge started
	# regardless of what _held turned out to be, so the sound stops the same way regardless.
	_sound_call(&"stop_loop", [&"capture_charge"])
	if body == null or not is_instance_valid(body):
		return
	if body is PonyScript:
		body.rotation.y = 0.0
		return
	if body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.freeze_mode = _prev_freeze_mode
		rigid.freeze = _prev_freeze


## A released pony: into the bag if there is room, back onto the grass if there is not.
##
## THE INSTANCE IS MINTED HERE, and only for a pony who does not already have one. A wild
## pony has no PonyInstance -- an individual identity is something she acquires by being
## caught -- so this is where she gets her uid. But a pony who was let back out of the bag
## and re-caught DOES have one, and re-using it is what makes her the same pony rather than
## a fresh copy of her character: same uid, same happiness, same hunger. Minting
## unconditionally here was the obvious version and it would have made release() a quiet
## amnesia machine.
func _settle_pony(pony: Node3D) -> void:
	var data: PonyData = pony.get_data()
	var instance: PonyInstance = pony.get_instance()
	# `not is_full()` guards the MINT, not the store -- store() is still the authority on
	# whether there is room. Without it, a capture into a full bag burns a uid on a pony who
	# was then set back down, and the serials in a save file would have gaps for every failed
	# grab the player ever made. Harmless, but a save file that reads like a ledger should
	# not have phantom entries in it.
	if instance == null and data != null and not _storage.is_full():
		# Time is read HERE, by the caller, and never inside PonyInstance -- that class has
		# to stay a pure function of its inputs so uids and seeded gates stay reproducible
		# (see its class comment). Unix time rather than get_ticks_msec(), because this
		# value goes into a save file and process uptime means nothing after a restart.
		instance = PonyInstanceScript.create(
			data.id, int(Time.get_unix_time_from_system() * 1000.0))
		# HER COLOURS COME OFF HER BODY. A wild stock pony has no record until this moment,
		# so the body the spawner tinted is the only thing that knows what she looks like;
		# minting without this makes every caught stock pony a differently coloured stranger
		# the next time she is stood up out of a pen.
		if pony.has_method("get_stock"):
			instance.stock = pony.get_stock()

	if instance != null and _storage.store(instance):
		pony.notify_captured()
		pony.queue_free()
		_play_first_capture_voice()
		_sound_call(&"play_at", [&"capture_success", global_position])
		captured.emit(instance)
		return

	# Full bag (or a pony with no record behind her, which is a setup bug rather than a
	# gameplay state). She is set down exactly where she was floating and falls the last
	# couple of metres on her own -- nothing here is allowed to remove her from the world.
	pony.set_held(false)
	capture_refused.emit(pony)


# --- presentation ---------------------------------------------------------------------

## Build the beam effect: a camera-facing ribbon rebuilt from an ImmediateMesh each frame,
## plus a glow at the far end. Built in code rather than in player.tscn so the geometry
## stays next to the maths that shapes it, and so anything that mounts a beam gets the
## effect without having to copy nodes into its own scene.
##
## Both nodes are `top_level`, which is load-bearing: their geometry is written in WORLD
## space every frame (from the horn to a point derived from the camera's aim ray), and
## inheriting the player's transform on top of that would apply her position twice.
func _build_effect() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.85)
	material.emission_enabled = true
	material.emission = beam_color
	material.emission_energy_multiplier = 2.0
	material.disable_receive_shadows = true
	_beam_material = material

	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "BeamMesh"
	_beam_mesh.mesh = ImmediateMesh.new()
	_beam_mesh.top_level = true
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam_mesh)

	# The glow doubles as the aura around a held body, which is why it gets its own,
	# fainter material: at the beam's own opacity a sphere big enough to wrap a pony
	# washes her out to a pink blob.
	var glow_material: StandardMaterial3D = material.duplicate()
	glow_material.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.4)

	var sphere := SphereMesh.new()
	# Radius 1.0 so the node's scale IS the glow's radius in metres.
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = glow_material

	_glow_mesh = MeshInstance3D.new()
	_glow_mesh.name = "BeamGlow"
	_glow_mesh.mesh = sphere
	_glow_mesh.top_level = true
	_glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow_mesh)

	# The landing ring. Its own material because it needs `no_depth_test`: the ring lies
	# ON the ground it is marking, and MARK_LIFT alone is not enough to keep a 4 cm offset
	# from being eaten by the depth buffer on a slope at 8 m. Drawing it through the
	# terrain is the right trade for a marker whose entire job is to be seen.
	var mark_material: StandardMaterial3D = material.duplicate()
	mark_material.no_depth_test = true
	# Rendered after everything else, so it is not sorted behind the ground it overlays.
	mark_material.render_priority = 1
	_mark_material = mark_material

	_mark_mesh = MeshInstance3D.new()
	_mark_mesh.name = "BeamMark"
	_mark_mesh.mesh = ImmediateMesh.new()
	_mark_mesh.top_level = true
	_mark_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mark_mesh)


## Placeholder voice playback. AudioStreamPlayer (not ...3D) because this is the player
## character's own voice, not a sound happening somewhere in the world.
func _build_voice() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.name = "CaptureVoice"
	# load() rather than preload(): a missing take must not be a parse error that takes
	# the whole beam -- and with it the core mechanic -- down with it.
	var stream: Resource = load(VOICE_LINE) if not VOICE_LINE.is_empty() else null
	if VOICE_LINE.is_empty():
		pass
	elif stream is AudioStream:
		_voice.stream = stream
	else:
		push_warning("MagicBeam: no voice line at '%s'; captures will be silent" % VOICE_LINE)
	add_child(_voice)


func _play_first_capture_voice() -> void:
	if _voice_played or _voice == null or _voice.stream == null:
		return
	_voice_played = true
	_voice.play()


## Draw the beam from the horn to its far end and park the glow at that end.
##
## WHY THE BEAM IS AN ARC AND NOT A STRAIGHT LINE. A straight beam from the horn to
## whatever the crosshair is on points almost directly AWAY from the camera in this rig
## (the camera sits behind the player and the crosshair is the screen centre), so it
## projects to a few pixels -- and those few pixels land behind the player's own body.
## The first offscreen render of this task showed a capture happening with no visible beam
## at all. Bowing the beam sideways, out past the player's silhouette, is what makes it
## read: the arc is longer on screen than the straight line was, and none of it is hidden.
## The bow is taken toward the CAMERA's right so it stays clear whatever direction the
## player is facing, which is the same reasoning HOLD_SIDE is built on.
func _draw_effect() -> void:
	var from := _anchor_position()
	var to := _ray_end
	if is_holding():
		# Connect to the held body's CENTRE, not its origin, or the beam visibly ends at
		# a floating pony's hooves.
		to = _held.global_position - _hold_offset

	var span := to - from
	var length := span.length()
	if length < 0.05:
		_hide_effect()
		return

	var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
	var eye: Vector3 = camera.global_position if camera != null else _aim_origin

	# Horizontal perpendicular to the beam, flipped to whichever side is camera-right.
	var side := span.cross(Vector3.UP)
	if side.length_squared() < 0.000001:
		side = span.cross(Vector3.RIGHT)
	side = side.normalized()
	if camera != null and side.dot(camera.global_transform.basis.x) < 0.0:
		side = -side
	# The sideways bow SATURATES (see BOW_SIDE_MAX) and the loft does not. Short beams --
	# the hold, mostly -- keep exactly the clearance they always had; long ones straighten
	# out sideways and gain height instead, which is both a calmer shape and a distance cue.
	var control := from + span * 0.5 \
		+ side * minf(length * BOW_FRACTION, BOW_SIDE_MAX) \
		+ Vector3.UP * (length * BOW_LIFT_FRACTION)

	# ONE ribbon plane for the whole beam, perpendicular to both the beam and the line of
	# sight to its middle. Deriving the strip's width direction PER SEGMENT (from each
	# point's own line of sight) is the obvious thing to do and it is wrong: when the beam
	# points nearly at or away from the eye, that direction sweeps through 180 degrees
	# along the beam, the strip twists through itself, and the whole effect renders as a
	# row of bow ties -- which is exactly what the offscreen render of a held crate showed.
	# A single plane cannot twist. The arc's bow is small enough that facing the eye at the
	# midpoint is right for the whole length.
	var across_dir := span.cross(eye - (from + to) * 0.5)
	if across_dir.length_squared() < 0.000001:
		# Beam pointing straight at the eye: any perpendicular will do.
		across_dir = span.cross(Vector3.UP)
		if across_dir.length_squared() < 0.000001:
			across_dir = span.cross(Vector3.RIGHT)
	across_dir = across_dir.normalized()

	var mesh: ImmediateMesh = _beam_mesh.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _beam_material)
	for i in range(BEAM_SEGMENTS + 1):
		var t := float(i) / float(BEAM_SEGMENTS)
		var point := _bezier(from, control, to, t)
		var across := across_dir * lerpf(BEAM_WIDTH_NEAR, BEAM_WIDTH_FAR, t)
		mesh.surface_add_vertex(point - across)
		mesh.surface_add_vertex(point + across)
	mesh.surface_end()

	_beam_mesh.global_transform = Transform3D.IDENTITY
	_beam_mesh.visible = true

	# At the far end: a bright bead when the beam is sweeping for something, and a wider,
	# fainter aura once it has hold of a body (a bead would simply be buried inside her).
	# The slow pulse keeps the effect visibly alive in a still frame as well as in motion.
	var radius := GLOW_HELD_RADIUS if is_holding() else GLOW_TIP_RADIUS
	var pulse := radius * (1.0 + 0.1 * sin(_elapsed * 9.0))
	_glow_mesh.global_transform = Transform3D(Basis().scaled(Vector3.ONE * pulse), to)
	_glow_mesh.visible = true

	_draw_mark()


## The ring on the ground under where the beam lands -- the distance cue. Hidden while
## something is held (there is nothing left to judge the range of; the pony is in the
## beam) and while the beam has found no surface at all.
func _draw_mark() -> void:
	if not has_mark():
		_mark_mesh.visible = false
		return

	# Two axes spanning the marked surface, so the ring lies flat ON a slope rather than
	# hovering level over it. UP is the natural reference; the fallback covers a wall or
	# an overhang, where the first cross product collapses.
	var right := _mark_normal.cross(Vector3.UP)
	if right.length_squared() < 0.000001:
		right = _mark_normal.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(_mark_normal).normalized()

	var locked := _has_target
	var outer: float = MARK_LOCKED_RADIUS if locked else MARK_RADIUS
	# The same slow pulse the tip glow uses, so the two read as one effect.
	outer *= 1.0 + 0.06 * sin(_elapsed * 9.0)
	var inner: float = maxf(outer - MARK_THICKNESS, 0.01)
	var color: Color = MARK_LOCKED_COLOR if locked else beam_color

	var mesh: ImmediateMesh = _mark_mesh.mesh
	mesh.clear_surfaces()
	_mark_material.albedo_color = Color(color.r, color.g, color.b, 0.9 if locked else 0.55)
	_mark_material.emission = color
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mark_material)
	for i in range(MARK_SEGMENTS + 1):
		var angle := TAU * float(i) / float(MARK_SEGMENTS)
		var dir := right * cos(angle) + forward * sin(angle)
		mesh.surface_add_vertex(_mark_point + dir * inner)
		mesh.surface_add_vertex(_mark_point + dir * outer)
	mesh.surface_end()

	# The drop line, when the beam ran out in mid-air above the ground it marked.
	var drop := _ray_end - _mark_point
	if drop.length() > MARK_DROP_MIN:
		var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
		var eye: Vector3 = camera.global_position if camera != null else _aim_origin
		var across := drop.cross(eye - _mark_point)
		if across.length_squared() < 0.000001:
			across = drop.cross(Vector3.RIGHT)
		across = across.normalized() * MARK_DROP_WIDTH
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mark_material)
		mesh.surface_add_vertex(_mark_point - across)
		mesh.surface_add_vertex(_mark_point + across)
		mesh.surface_add_vertex(_ray_end - across)
		mesh.surface_add_vertex(_ray_end + across)
		mesh.surface_end()

	_mark_mesh.global_transform = Transform3D.IDENTITY
	_mark_mesh.visible = true


## Quadratic Bezier through `control`, used for the beam's bow.
static func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var inv := 1.0 - t
	return a * (inv * inv) + control * (2.0 * inv * t) + b * (t * t)


func _hide_effect() -> void:
	if _beam_mesh != null:
		_beam_mesh.visible = false
	if _glow_mesh != null:
		_glow_mesh.visible = false
	if _mark_mesh != null:
		_mark_mesh.visible = false


# --- mounting -------------------------------------------------------------------------

## Find the Player this beam hangs off, her horn marker, and the camera rig that answers
## get_aim_ray(). All three are optional: a beam with none of them still works, drawing
## from its own origin along the viewport camera's crosshair, which is what lets a test
## scene exercise it without assembling a whole character.
func _resolve_mount() -> void:
	var node := get_parent()
	while node != null:
		if node.has_method("get_beam_origin"):
			_player = node
			break
		node = node.get_parent()

	# The horn marker is deliberately NOT fetched here -- see _anchor_node().

	if not aim_source_path.is_empty():
		_aim_source = get_node_or_null(aim_source_path)
	if _aim_source == null and _player != null:
		for child in _player.find_children("*", "", true, false):
			if child.has_method("get_aim_ray"):
				_aim_source = child
				break


## The horn the beam is drawn from, resolved LAZILY and cached -- which is not a style
## choice, it is a bug fix. Godot runs a child's _ready() before its parent's, and
## Player.get_beam_origin() hands back an `@onready` var that the Player has not assigned
## yet at that point. Asking for it during this node's _ready() therefore returns null,
## silently falls through to `self`, and the beam draws out of the player's HOOVES
## instead of her horn -- which is exactly what the second offscreen render of this task
## showed, with every numeric check still green. Resolving on first use instead means the
## answer is asked for after the whole tree is ready.
func _anchor_node() -> Node3D:
	if (_beam_anchor == null or not is_instance_valid(_beam_anchor)) and _player != null:
		_beam_anchor = _player.get_beam_origin()
	if _beam_anchor != null and is_instance_valid(_beam_anchor):
		return _beam_anchor
	return self


## The node the beam is drawn from -- the player's horn marker when mounted on her.
## Exposed so a gate can assert it really is the horn (see above).
func get_beam_anchor() -> Node3D:
	return _anchor_node()


func _anchor_position() -> Vector3:
	return _anchor_node().global_position
