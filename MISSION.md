You are the sole developer, game designer, narrative designer, technical artist, and QA lead on this game. Your job is to take the existing Godot project and ship a complete, polished v1 that is fun, feels great to play, and looks great, with the charm and polish level of Slime Rancher. It must build and run natively on both Linux and Windows.

## The game
An MLP (G4-style) take on Slime Rancher with a dark twist. The player starts as a cheerful worker in a cozy, colorful pony world, collecting and tending to ponies and resources in a satisfying ranching/collection loop. Gradually the player discovers they are living in the world of the "Rainbow Factory" fan song: the work they've been doing feeds a factory that harvests ponies to make rainbows. Once they know, they can keep working for the factory (more efficient, more rewards, morally rotten) or work against it to save the ponies (harder, riskier, but right), similar to the Joja vs Community Center choice in Stardew Valley.

The existing story needs work. Improve it. Goals:
- The first hours must be genuinely cozy and fun on their own, so the twist lands because the player cares.
- Foreshadow the twist through environmental storytelling, small wrong details, and NPC behavior, not exposition dumps. A replay should reveal clues the player missed.
- The reveal should be a memorable set piece.
- After the reveal, both paths must be fully playable, mechanically distinct, and fun. The factory path should be tempting, not a strawman. The rescue path should use the systems the player already mastered in new ways.
- Multiple endings that reflect the player's choices, including mixed/partial outcomes.
- Keep the darkness implied and atmospheric rather than gory. Dread over shock. The tone shift should come through lighting, color grading, music, and sound as much as text.
- All story characters must be original OCs. Do not use canon MLP characters, the song's lyrics, or the song's audio.
Write the full story in STORY.md: world, characters, act structure, foreshadowing beats, the reveal, both paths, endings, and how each story beat ties to a gameplay mechanic.

## Autonomy rules
- Do NOT ask me any questions until v1 is done. When something is ambiguous, make the call a strong senior game designer would make, then log it in DECISIONS.md with one line of reasoning.
- Nothing in the current project is sacred EXCEPT the existing pony models, the pony character customizer, and the random pony generator. Those are core assets: keep them, build on them, and improve them, but never replace them with procedural or simplified art. Everything else can be kept, rewritten, or cut if it doesn't serve the game. Justify major changes in DECISIONS.md.
- Commit to git after every meaningful step with clear messages.
- Keep PROGRESS.md updated with what's done, what's next, and known issues. Re-read PROGRESS.md, PLAN.md, DECISIONS.md, GDD.md, and STORY.md at the start of each major phase.
- Do not stop early. "Mostly working" is not done. Keep going until every item in the Definition of Done passes.

## Usage budget
- Never run more than 2 subagents at the same time.
- Use subagents only for research, audits, and code/screenshot reviews. Do all building yourself in the main session.
- Use the Sonnet or Haiku model for research and review subagents. Reserve the main model for design and implementation.
- Don't re-research topics already covered in RESEARCH.md.
- Run targeted tests while iterating and the full suite at milestone boundaries.

## Godot technical rules
- Godot 4, latest stable. Typed GDScript everywhere. No C# unless there is a strong reason logged in DECISIONS.md.
- Forward+ renderer for desktop quality, with a quality settings menu so lower-end hardware is still playable.
- Clean architecture: autoloads only for true globals (save system, game state, audio, events), composition over deep inheritance, signals for decoupling, Resources (.tres) for data like pony types, items, upgrades, and dialogue.
- Edit .tscn and .tres files as text where practical, but keep them valid. After structural changes, run godot --headless --import and confirm no errors.
- Never leave the project with parser errors or broken scene references.

## Phase 1: Audit
Read the entire existing project. Write AUDIT.md: what the game currently is, what works, what's broken, what's missing, tech debt, and an honest assessment of what is and isn't fun right now. Specifically inventory every existing pony model, rig, animation, material, and the customizer and random generator systems: what parts and options exist, how they're assembled, and what's missing or broken.

## Phase 2: Research
Summarize in RESEARCH.md:
- What makes Slime Rancher work: core loop, cozy tone, progression pacing, discovery, minute-to-minute satisfaction.
- How Stardew handles the Joja/Community Center choice, and how Undertale, Doki Doki Literature Club, Papers Please, and Spec Ops: The Line handle moral choice, complicity, and tone shifts.
- Game feel: input responsiveness, squash and stretch, anticipation and follow-through, screen shake, hit pause, particles, layered sound, camera feel.
- Progression design, onboarding without text walls, reward schedules, avoiding grind.
- Matching the G4 show's look in 3D Godot: flat cel shading, clean outlines, the show's saturated color palettes and backgrounds, lighting that stays show-accurate in the cozy sections, and color grading, fog, and lighting changes that shift the same look toward dread for the factory.
Pull concrete, actionable principles, not generic advice.

## Phase 3: Design
Write GDD.md: pitch, 3 to 5 design pillars, core loop (30 seconds, 5 minutes, 1 hour), all systems and how they interconnect, how both story paths change gameplay, progression curve, content list, art direction (palette for each tone, shading style), audio direction, UI/UX flow, and scope. Scope ruthlessly: a small, deeply polished game beats a big shallow one. Every feature must serve a pillar or get cut.

## Phase 4: Plan
Write PLAN.md as ordered milestones with testable acceptance criteria:
1. Vertical slice: the core cozy loop fully playable and polished (art, feel, audio, UI) in one area.
2. The reveal set piece and branching choice, with both paths playable.
3. Expand content, areas, and both story paths using patterns proven in the slice.
4. Menus, settings (graphics, audio, keybinds, controller support), save/load, onboarding.
5. Polish pass, performance pass, bug bash.

## Phase 5: Build
Execute PLAN.md milestone by milestone. After each milestone, run all tests, capture screenshots, review them critically against the art direction, and fix anything unpolished before moving on.

## Assets
- The existing pony models are the visual standard for the whole game. They must look 1:1 with the show. Every new asset (environments, props, UI, VFX) must match that style so nothing looks out of place next to the ponies.
- Keep and extend the existing character customizer and random pony generator. Every NPC, worker, and rescuable pony in the game should come from the random generator so the world feels full and varied. Expand the customizer and generator options where it makes the player character and world better.
- Ponies need full, show-accurate animation coverage for everything they do in gameplay and story beats (idle, walk, run, jump, emotes, reactions, fear). Add missing animations on the existing rigs.
- Environments and props: build them to match the show's art style using the existing pony assets as reference.
- Any new third-party assets must be licensed for free redistribution. Log each in CREDITS.md with source and license.
- No placeholder art or programmer-colored boxes in the final build.

## Testing
- GUT or gdUnit4 unit tests for game logic: economy, progression, story flags, branching state, save/load, inventory, customizer, and random pony generation.
- Automated headless playthrough scripts that verify every ending is reachable without softlocks.
- A screenshot capture script for key scenes (both tones, both paths, customizer, a batch of randomly generated ponies) for visual review.
- Stable 60 FPS on mid-range hardware, including scenes with many ponies on screen. Profile and fix hotspots.
- export_presets.cfg for Linux and Windows. Export both with godot --headless --export-release and verify the Linux build launches with --headless --quit-after without errors.

## Definition of Done (v1)
- Full game playable start to every ending with no softlocks or crashes.
- Every pillar in GDD.md delivered. STORY.md fully implemented.
- The cozy opening is fun on its own, and the tone shift is felt through visuals and audio, not just text.
- Every player action has visual, audio, and feel feedback.
- All ponies look 1:1 with the show, and every other asset matches that style. No placeholders.
- Customizer and random generator are complete, polished, and used throughout the game.
- Complete menus, settings, save/load, and onboarding.
- All tests pass. Linux and Windows builds export and launch.
- README.md with build/run instructions. CREDITS.md complete.
- A final REVIEW.md where you critique the game as a skeptical player and reviewer, then fix the top issues before declaring done.

## Addenda (owner, 2026-10-22, mid-session)
- Use any asset packs in the project as a base and restyle them with the show's shading so they match the ponies.
- Model, UV, and texture environment and prop meshes in Blender, then export them as .glb into the Godot project. Never ship environments built from primitive shapes or CSG.
- (A references/ folder was mentioned, then withdrawn by the owner: there are no reference images.)
- (Owner, 2026-10-22, overriding the OC-only rule above): "i want them to have their real names. i have no copyright concerns whatsoever and want to lean into mlp fully. this is not for redistribution." Canon MLP characters keep their real names and looks; canon places are used.

## Fun and anti-repetition rules
The early game is repetitive. Fixing that is the top design priority.
- Novelty cadence: in the first hour, the player must get something new (a pony type, area, tool, upgrade, mechanic, story clue, or NPC event) at least every 5 to 8 minutes. After that, at least every 15 minutes.
- The first "something is wrong here" clue must appear within the first 15 minutes so the mystery pulls the player forward.
- Upgrades must change HOW the player plays (new movement, new interactions, new options), not just bigger numbers. At least half of all upgrades must be verb-changing.
- Use the random pony generator's variety in gameplay: pony traits must matter mechanically so different ponies create different decisions, combinations, and surprises.
- Automate chores as they become chores: anything the player has done many times should get an upgrade or tool that removes the busywork and frees them for the next new thing.
- No progress gates that require repeating the same action for more than a few minutes. If a playthrough shows a grind wall, redesign it.
- Mix activity types so the player rotates between ranching, exploring, discovery, light challenge or risk, and story, never doing one for too long.
- Pacing test: the playthrough scripts must log a timestamp for every new unlock, discovery, and story beat, and write PACING.md showing the gaps. The test fails if any gap exceeds the cadence limits above.

## v1 sharpening and videos (owner, 2026-10-23)
The owner cannot playtest yet. Keep sharpening v1 without them, then make videos they can watch at work. Stay on v1-overhaul, keep logging in DECISIONS.md and PROGRESS.md, never ask questions.

Sharpening:
1. Build the pacing test, run it, and redesign the early game until it passes. Audit every upgrade against the verb-changing rule and fix the ratio.
2. Run the deferred 60-pony performance check with real rendering (not headless). Get it to a stable 60 FPS and fix whatever drops it.
3. Root-cause the exit hang. Run the full suite repeatedly under the watchdog until you can reproduce or rule it out, and fix the cause.
4. Do a rendered visual review: capture screenshots of every major scene, both tones, both paths, the customizer, a batch of random ponies, and the ending flyover. Compare against references/ (withdrawn: there are none; review against GDD.md section 8 and the show) and fix anything that looks unpolished, mismatched, empty, or off-model.

Videos: record only after all sharpening is done. Godot Movie Maker (--write-movie, --fixed-fps 60), a real renderer at the highest quality settings (virtual display and software rendering only if there is no display or GPU; slow rendering is fine).

FIRST_10_MINUTES.mp4: an uncut recording of a fresh save played by the playthrough bot, driven to look like a normal human player (smooth camera, natural pauses). No editing. 1080p60 H.264. For judging pacing honestly.

TRAILER: a Steam-store-quality gameplay trailer, a professional deliverable, not a recording.
- Pre-production: research current Steam trailer best practice and well-regarded cozy/indie trailers; write TRAILER_PLAN.md (the hook, a beat-by-beat shot list with timestamps, camera move per shot, the music track and where cuts land, text callouts).
- Structure, 60 to 90 s: 0-5 s opens directly on the most striking gameplay moment (no logos, no slow fades; the first 6 s loop standalone); 5-15 s the core loop readable; 15-50 s variety (generator ponies, customizer, exploration, areas, verb-changing upgrades, satisfying feedback); 50-70 s the twist tease (palette shifting to dread, music with it; hint, never spoil); final 5 s title card in the game's style. At least 60% real gameplay; gameplay shots 1-3 s; beauty shots longer with slow deliberate camera moves.
- Capture: every shot staged (scripted cinematic cameras for beauty shots; bot gameplay rehearsed until effortless and skilled); multiple takes, pick the best; no cursor, debug text, hitches, placeholder or off-model assets; HUD hidden on beauty shots, clean and minimal on gameplay shots; capture at 3840x2160.
- Edit: a reproducible script (MoviePy or an ffmpeg filtergraph); the game's own music; beats detected (librosa or aubio), cuts on the beat; energy builds to the twist, pulls back for the title; game SFX under the music for punch; about -14 LUFS integrated, verified with ffmpeg ebur128; at most 2 or 3 short text callouts in the game's font and style; colour-consistent.
- Review loop, at least 3 iterations: a contact sheet every 0.5 s after each cut, every frame reviewed (gameplay in the first 3 s, core loop readable by 15 s, cuts on beats, glitches, clipping, empty scenery, off-model ponies, dead air); findings and fixes per iteration in TRAILER_REVIEW.md; repeat until a full review finds nothing worth fixing.
- Deliver TRAILER_4K.mp4 (3840x2160, 60 fps) and TRAILER_1080p.mp4 (1920x1080, 60 fps), H.264 with AAC.
