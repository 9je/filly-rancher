# Trailer plan

A 75-second gameplay trailer for *Filly Rancher*. Research notes are in [docs/trailer_research.md](docs/trailer_research.md). The capture is staged in-engine by `game/scenes/test/trailer.gd` and recorded with Godot Movie Maker at 2560x1440 (the owner asked for 2K rather than 4K: it is their monitor's resolution), 60 fps. The edit is a script, `tools/trailer/edit.py`, built on an ffmpeg filtergraph. Each review pass is logged in [TRAILER_REVIEW.md](TRAILER_REVIEW.md).

## Who it is for (owner, 2026-10-23)

"steam trailer isnt for steam its just for my friends so try to make it interesting, maybe add some humor elements and load it with mlp references". So this is a trailer for friends who know the show:
- **Funny:** captions written as jokes.
- **Full of MLP references:** in the captions and staged in shot.
- **Still well made:** the craft rules below stay (gameplay first, cuts on the beat, a readable loop, the twist teased and never spoiled).

The Steam-specific rules (the microtrailer, no wishlist line) still hold, because they make a better trailer anyway. The limit of "at most 2 or 3 callouts" gives way to the owner's ask: six short caption cards, each one a joke, none longer than about six words.

## The jokes and references (staged, not pasted on)

The owner's favorites, and their friends' (the people this is for), each get a moment: Fluttershy (the owner), Spike (Damon), Rainbow Dash (Ben), and also Octavia, Derpy and Trixie.

| Shot | The gag |
|---|---|
| Catch, the hook | Caption: **"Gotta catch 'em all. Wrong franchise."** |
| **Fluttershy** (the owner's) | She is Skittish: she spots the player from twice as far and bolts. A tossed treat, and she trots back, calm, into the Scoop. Caption: **"Kindness. And snacks."** |
| **Rainbow Dash** (Ben's) | A Show-off and a pegasus. The Gallop Shoes chase her down, then she wins a race by a nose. Caption: **"20% cooler."** |
| **Spike** (Damon's) | At the mailbox, he burps a letter in on green dragonfire, the way he sends Twilight's mail. Caption: **"Spike: express mail."** |
| **Trixie** | The beam closes on her and she blinks away (a unicorn's trick). Caption: **"The Great and Powerful... gone."** |
| **Derpy** | A Glutton at the pantry, hay vanishing. No caption needed. |
| **Octavia** | A Loner under the moonflowers in the Night Meadow at night: the trailer's quiet beauty shot. |
| Escape Artists | Apple Bloom, Sweetie Belle and Scootaloo hop the Paddock fence at night. Caption: **"CUTIE MARK CRUSADERS FENCE HOPPERS, YAY!"** |
| Launch | A pony sails into the pen. Caption: **"Applied pony-ballistics."** |
| The twist tease | Over the grey valley: **"No ponies were harmed in the making of this rainbow.\*"** One beat of silence, then: **"\*terms and conditions apply"**. The spectrum tank cut lands on it. |
| The title card | "Filly Rancher", the rainbow underline, the tag **"Friendship is Magic. Ranching is Business."** |

## The hook

**A wild pony lifted off the grass by the Scoop's beam, kicking in the air, and popped into the saddlebag in a burst of sparkles. Then a different pony Blooms: her cutie mark appears.** Catching and Blooming are the two verbs the whole game turns on, and both read silently in under three seconds.

The opening six seconds loop: they end on a wide shot of the valley with a pony arriving in the same framing the catch began in.

## The rules this plan keeps

- Gameplay inside the first second. No logo, no fade from black.
- The core loop (catch, pen, care, Bloom, sell) is readable by 0:15.
- At least 60% real gameplay: everything except the title card and two beauty shots is played footage, HUD minimal.
- Gameplay shots run 1 to 3 s; beauty shots run 4 to 6 s, with slow, deliberate camera moves.
- Six short caption cards (the owner asked for humour), in Fredoka, the game's own font and pill style.
- Every cut lands on a beat of the track (beats detected with librosa, not assumed).
- Energy builds to the twist, then pulls back for the title.
- The twist is hinted, never spoiled: the colour drains, a tank of rainbow sits in a grey room, the music turns. No drained pony on screen, no machinery explained.
- Audio at about -14 LUFS integrated, true peak at or below -1 dBTP, verified with ffmpeg's `ebur128`.
- There is no "Wishlist" call to action: this build is not for sale or redistribution.

## Music

| Time | Track (Kevin MacLeod, CC BY 4.0, already in the game) | Notes |
|---|---|---|
| 0:00 - 0:50 | "Morning" (`day_morning.ogg`), 117.5 BPM | The cozy, bouncing theme. Cuts land on beats, every 2 to 4 beats in the variety section. |
| 0:50 - 1:08 | "Gone Beyond" (`works_gone_beyond.ogg`), also 117.5 BPM | Crossfaded in on a bar line, so the tempo holds while the key goes cold. The `dread_ossuary` drone rides underneath and rises. A one-beat drop to silence lands at the turn. |
| 1:08 - 1:15 | "Promises" (`ending_promises.ogg`) | The pull-back: a held phrase under the title card. |

At 117.5 BPM a beat is 0.511 s and a bar is 2.043 s. The timestamps below are snapped to that grid; the edit script snaps each cut to the nearest detected beat.

Game SFX under the music: the beam charge and the bag pop, the Bloom fanfare, gem chimes, the casino slot win, hoofsteps on the gallop, and the lift's hum in the twist.

## Shot list

| # | Time | Shot | Camera | What it shows |
|---|---|---|---|---|
| 1 | 0:00.0 - 0:02.0 | **Catch** | Low over the player's shoulder, a slow push in | The beam ribbon on a Drifter, who lifts and kicks, then the pop into the bag. HUD bag pips tick. |
| 2 | 0:02.0 - 0:04.1 | **Bloom** | A close orbit, a quarter turn | A penned pony rears, sparkles, her cutie mark appears, the fanfare. |
| 3 | 0:04.1 - 0:06.1 | **The valley** | High and wide, a slow rise | Ponyville, the pens, the rainbow arc. A pony trots into frame where shot 1 began (the loop seam). |
| 4 | 0:06.1 - 0:08.2 | Pen launch | Third person, a whip pan to the pen | The Scoop Launcher fires a pony in an arc into a pen. Caption: "Applied pony-ballistics." |
| 5 | 0:08.2 - 0:10.2 | Treat toss | Third person | A treat tossed into the grass; a pony trots over, ears up. |
| 6 | 0:10.2 - 0:12.3 | Gems | Close on a pen | Ponies grazing, gems popping out, the pouch count rising. |
| 7 | 0:12.3 - 0:14.3 | Market | Over the counter | Selling gems to Bramble, bits ticking up.  |
| 8 | 0:14.3 - 0:16.3 | Herd lineup | A slow track along the line | Fourteen generated Drifters: every coat, mane, race and foal different. |
| 9 | 0:16.3 - 0:18.4 | Creator | The UI, close | Coats and manes cycling on the player's own pony. |
| 10 | 0:18.4 - 0:20.4 | Everfree gallop | Low tracking, at speed | The Gallop Shoes through the dark wood. |
| 11 | 0:20.4 - 0:22.5 | The Lake | A crane down to the waterline | Lily pads, the jetty, a pegasus Drifter fluttering off. |
| 12 | 0:22.5 - 0:24.5 | The Night Meadow | A slow dolly at night | Moonflowers glowing, the standing stones. |
| 13 | 0:24.5 - 0:26.6 | Whistle | Third person | The whistle ring; a bolting unicorn stops still. |
| 14 | 0:26.6 - 0:28.6 | Unicorn blink | A side angle | A startled unicorn blinks away from the beam. |
| 15 | 0:28.6 - 0:30.6 | Canon pony | A medium shot | Tumble points; Rainbow Dash, out in the grass, is caught. |
| 16 | 0:30.6 - 0:32.7 | The Orchard | Overhead, drifting | Rows of apple trees, ponies between them. |
| 17 | 0:32.7 - 0:34.7 | The Palace | The slot reels, close | A three-of-a-kind win, chips cascading. |
| 18 | 0:34.7 - 0:36.8 | Race | A trackside pan | The six lanes; a Show-off pony wins by a nose. |
| 19 | 0:36.8 - 0:38.8 | Bloom 2 | A close shot | A second ceremony, from a different pony. |
| 20 | 0:38.8 - 0:42.9 | **Beauty: dusk** | A slow crane across the valley at dusk | The pens full, the sky salmon, the rainbow.  |
| 21 | 0:42.9 - 0:44.9 | Delivery | Behind the player at the Depot | A pony goes into the crate; a sparkle of her coat colour flies up into the rainbow, which brightens. |
| 22 | 0:44.9 - 0:46.9 | Postcards | A slow push on Fennel's wall | The postcards, all the same. |
| 23 | 0:46.9 - 0:49.0 | Tumble | Low, close | Tumble under the porch, facing the Works. |
| 24 | 0:49.0 - 0:51.0 | The lift | Rising with it | The cloud lift climbing toward the Rainbow Factory. The colour grade starts to drain. **The music turns.** |
| 25 | 0:51.0 - 0:53.1 | White hall | A slow walk forward | The pristine Welcome Hall: gold trim, "Every Pony Has a Color!" |
| 26 | 0:53.1 - 0:55.1 | Walkway | High, looking down | The grey walkway; a Collector's lantern cone sweeps past. |
| 27 | 0:55.1 - 0:56.1 | Flash | A hard cut, one beat | A spectrum tank, rainbow bands glowing in a grey room. |
| 28 | 0:56.1 - 0:57.1 | Flash | A hard cut, one beat | The ring of light on the processing floor, empty. |
| 29 | 0:57.1 - 0:59.2 | The valley, grey | The shot 3 framing, desaturated | The same valley at dread 0.8. The rainbow is louder than ever. |
| 30 | 0:59.2 - 1:02.2 | Tumble's eyes | An extreme close up, held | She looks up at the rainbow. Silence for one beat, then the drone. |
| 31 | 1:02.2 - 1:08.3 | Beauty: dawn | A slow pull back from the ranch at dawn | Warm again, but quieter: the ponies at the fence, all looking the same way. |
| 32 | 1:08.3 - 1:15.0 | **Title card** | Static | "Filly Rancher" in the game's style: a Fredoka wordmark on the dawn sky, a thin rainbow under it, a one-line tag ("a pony ranching game"). |

About 62 s of the 75 is played footage (shots 1 to 19 and 21 to 30), about 83%.

## The microtrailer moments

Steam cuts six 1-second clips, so the trailer needs six strong 1-second moments: the catch, the Bloom, the launch arc, the herd, the slot win, and the spectrum tank.

## Capture notes

- **The rig:** `scenes/test/trailer.gd` stages each shot by name. It sets the scene, pins time of day and weather, sets the dread level, and places the ponies, then runs a scripted camera path (Catmull-Rom through keyframes, eased) or a bot-driven action using the same virtual controller as `human_bot.gd`.
- **The recording:** each shot records on its own (`tools/trailer/capture.sh`): `--write-movie build/trailer/takes/<shot>_t<take>.avi --fixed-fps 60`, with the root viewport pinned to 2560x1440 through the "viewport" stretch mode for the capture run, because the desktop clamps any window larger than its work area. There are at least two takes of every gameplay shot; the best is chosen in review.
- **Clean frames:** no cursor (it is captured or hidden), no debug text, no toasts on beauty shots, and the HUD only on gameplay shots that need it (bag pips, bits), with the tutorial card, tips and the controls chip hidden.
