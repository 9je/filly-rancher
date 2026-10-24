# Trailer review

Each iteration is a full edit (`tools/trailer/edit.py --cut N`), reviewed from a frame every 0.5 s (`build/trailer/review/cutN/`) plus ffprobe and ebur128. The plan is [TRAILER_PLAN.md](TRAILER_PLAN.md).

## Iteration 1 (cut 1)

**Measured:**
- TRAILER_4K.mp4: H.264, 3840x2160, 60 fps, 71.2 s.
- TRAILER_1080p.mp4: 1920x1080, 60 fps, 71.2 s.
- ebur128: integrated -14.0 LUFS, LRA 5.3 LU, true peak -0.8 dBFS.

**What works:**
- The hook (the catch, then a Bloom) lands in the first 4 s.
- Each favorite has a readable moment: Fluttershy with her treat, Rainbow Dash, Spike's dragonfire mail, Trixie, Derpy, the Cutie Mark Crusaders hopping the Paddock fence, and Octavia under the standing stones at night.
- The color drains through the lift and the Factory.
- The grey valley carries "No ponies were harmed...*", then Tumble carries "*terms and conditions apply".
- The cut lands on dawn, then the title.

**Found, to fix:**
1. **Captions too small:** about 17% of the frame's width, too small for a TV. Scale them up by 1.5.
2. **Wrong title tag:** it reads "a pony ranching game". The plan's line is "Friendship is Magic. Ranching is Business."
3. **Lake:** the camera dips below the waterline at the end of the shot. Shorten it.
4. **Trixie:** the first frame has a pony's flank filling the lens. Trim the head of the shot.
5. **Spike:** he's small in the frame. Damon's moment needs a closer shot.
6. **True peak:** -0.8 dBFS, over the -1 dBTP rule. The AAC encode overshoots the limiter, so normalise to -1.5 dBTP.

## Iteration 2 (cut 2)

**Measured:**
- TRAILER_4K.mp4: H.264, 3840x2160, 60 fps, 70.7 s.
- TRAILER_1080p.mp4: 1920x1080, 60 fps, 70.7 s.
- ebur128: integrated -14.1 LUFS, LRA 5.1 LU, true peak -1.5 dBFS.

**Iteration 1's fixes, checked:**
- The captions are 1.5x and readable.
- The title tag reads "Friendship is Magic. Ranching is Business."
- The lake no longer dips under the water.
- Trixie opens clean.
- Spike fills the frame by his mailbox.
- The true peak is under -1 dBTP.

**Found, to fix:**
1. **Spike's dragonfire burp is invisible:** in no frame does the green fire read, and "Spike: express mail." depends on it. The burp's sprites are 0.18 m, last 0.8 s and are sparse. Make it a proper puff (bigger, denser, longer), which is also a fix for the game itself.
2. **The title's tagline is thin under the wordmark.** Enlarge it about 1.3x.

## Iteration 3 (cut 3)

**Measured:**
- TRAILER_4K.mp4: H.264, 3840x2160, 60 fps, 70.7 s.
- TRAILER_1080p.mp4: 1920x1080, 60 fps, 70.7 s.
- ebur128: integrated -14.1 LUFS, LRA 5.1 LU, true peak -1.5 dBFS.

**Iteration 2's fixes, checked:**
- Spike's green dragonfire puff reads at 20.0 s, under "Spike: express mail."
- The tagline is larger and legible.

**Found, to fix:**
1. **"Applied pony-ballistics." doesn't land.** Sampled at 5 fps, the launch shot is the player's back and a faint sparkle; the arc into the pen never reads. Two restagings didn't help:
   - **A side camera:** the first try landed inside a balcony, then a ray-cleared side view showed the whole lane but still no visible arc at trailer scale.
   - **The decision:** cut the shot and its caption. The trailer keeps every favorite's moment and stays inside 60 to 90 s.

## Iteration 4 (cut 4): final

**Measured:**
- TRAILER_4K.mp4: H.264, 3840x2160, 60 fps, 69.3 s.
- TRAILER_1080p.mp4: 1920x1080, 60 fps, 69.3 s.
- ebur128: integrated -14.0 LUFS, LRA 5.5 LU, true peak -1.5 dBFS.

**Iteration 3's fix, checked:** the launch shot is gone. The variety run now goes straight from the valley to Fluttershy's treat, and the edit stays on the beat grid (27 shots).

**Found, to fix: nothing.**
- Every shot reads.
- Every caption sits on a moment that lands:
  - "Gotta catch 'em all. Wrong franchise." on the catch.
  - "Kindness. And snacks." on Fluttershy.
  - "20% cooler." on Rainbow Dash.
  - "Spike: express mail." on the dragonfire burp.
  - "The Great and Powerful... gone." on Trixie.
  - "CUTIE MARK CRUSADERS FENCE HOPPERS, YAY!" on the fence hop.
  - The two-part disclaimer on the grey valley and on Tumble.
- The title holds on dawn with "Friendship is Magic. Ranching is Business."
- The specs are met.

**Accepted as they are (style, not defects):**
- The Everfree shot is dark (dusk under trees) and sweeps past a trunk.
- The slots shot is dim behind its menu.
- A few background ponies crowd the edges of Fluttershy's and Tumble's frames.

## Iteration 5 (cut 5): after the owner's review

The owner watched cut 4 and found the eyes buggy, the text random and the movement weird. They were right. Root causes are in DECISIONS.md (2026-10-23, evening).

**What changed before this cut:**
- **Eyes:** the stale import cache that left Fluttershy, Twilight and Rainbow Dash with hollow eyes was cleared, and the PonySFM cast's irises are drawn at Source's size.
- **Text:** no HUD in any shot.
- **Movement:** each featured pony has the stage to herself. Staged facing holds (Fluttershy, Trixie and Derpy face the camera). Dash actually bolts. Fluttershy trots to her favorite food, now that the treat bug is fixed.
- **The takes:** all 27 were re-shot.

**Measured:**
- TRAILER_4K.mp4 and TRAILER_1080p.mp4: 60 fps, 69.3 s.
- ebur128: -14.0 LUFS, true peak -1.4 dBFS.

**Checked at full resolution:** the faces of Fluttershy, Trixie, Derpy, Octavia, Tumble, Spike and the Crusaders all show proper eyes, facing the camera.

**Found, to fix:**
1. **Slots (about 27 s):** a dim menu panel of small text, which reads as exactly the "random text" the owner objected to. Cut it.
2. **Everfree (about 20 s):** nearly black, and it sweeps through a red trunk. Cut it.

## Iteration 6 (cut 6): final

**Measured:**
- TRAILER_4K.mp4: H.264, 3840x2160, 60 fps, 64.8 s.
- TRAILER_1080p.mp4: 1920x1080, 60 fps, 64.8 s.
- ebur128: integrated -14.0 LUFS, LRA 5.0 LU, true peak -1.5 dBFS.

**Iteration 5's fixes, checked:**
- The slots menu and the dark Everfree shot are gone.
- The only text on screen is now the joke captions and the title card.
- The run flows from Spike to the lake to Trixie, Derpy, the Crusaders and Octavia.

**Found, to fix: nothing.**
- Every featured pony faces the camera with proper eyes.
- No HUD appears anywhere.
- The motion is clean: Dash bolts, Fluttershy trots to her treat, and Trixie blinks out.

**Kept on purpose:** the character creator's swatch panel. It's the game's own menu, and it shows the creator is real.
