# Hair secondary motion — diagnosis, fix, and evidence

The owner, watching `walk_test`: *"hair is moving funny compared to the pony —
bobbing out of sync, looks off. Tail might be too."*

This is the full write-up. `docs/pipeline.md` §6 carries the short version —
the rules a future session must follow when adding a character.

---

## 1. Diagnosis

Two separate defects, stacked. The second one is the one everybody expected;
the first one is what was actually on screen.

### 1a. The mane and tail were exported with no skin at all

Every CreatorOfPony pack ships **two** armatures:

| Object | Bones | Visible | Role |
|---|---|---|---|
| `TS_Rig` (`RD_Rig`, `FS_Rig`) | 140 / 165 / 160 | yes | the character rig |
| `TS_RigPhysics` (`RD_…`, `FS_…`) | 23 | **`hide_viewport=True`** | hair rig: duplicate, identically-named copies of the `DEF_Mane*`/`DEF_Hair*`/`DEF_Tail*` chains, driven by spline-IK against curve objects (`ManePhysics`, `TailPhyiscs`, `HairPhysics1…`) |

The hair mesh (`TS_Hair`; Rainbow Dash has a separate `Hair` **and** `Tail`)
parents to the *physics* rig and binds its Armature modifier to it. That rig is
flagged `hide_viewport`, so it is **not in the evaluated depsgraph** — and
`export_blend.py` exports with `export_apply=True`, i.e. against the depsgraph.
The exporter therefore never saw it.

Consequence, confirmed by decoding `twilight.glb` directly: node `TS_Hair`
carried `"skin": null` and only `POSITION`/`NORMAL`/`TEXCOORD` attributes — no
`JOINTS_0`, no `WEIGHTS_0` — sitting as a **direct child of the rig root**. The
mane and tail were a rigid prop bolted to the model's origin. The body bobbed,
the head nodded, the hair did not move at all. That is the "bobbing out of
sync" the owner saw.

Nothing caught it: `meshes=17 skins=1 materials=13 textured=True
animations=['idle','walk']`, `GALLERY_OK count=3` and `WALK_OK` all passed
throughout. This is the same class of blind spot §7 of the pipeline doc already
warns about — structural gates cannot see a rendering bug.

### 1b. …and every hair bone was baked at its rest pose

`export_bake_animation=True` (needed so the IK hoof solve ships) samples *every*
bone on *every* frame. Both clips animated 143 of 158 nodes, including
`CON_Hair2/4`, `CON_Mane1-3`, `CON_Tail1-3` and all their `DEF_` counterparts —
constant, rest-pose tracks.

Those tracks are not harmless. In Godot an `AnimationPlayer` track and a
`SkeletonModifier3D` both write the same bone pose, and the animation is applied
after the modifier's input is captured. A rest-pose track on `DEF_Mane1-3`
overwrites the spring simulation every single frame. So fixing 1a alone would
have welded the hair to the skull (lockstep — the *other* half of "looks off"),
and adding spring bones without fixing 1b would have looked like the simulator
was not running at all.

### Which layer drives the mesh

The rig has a `CON_` (control) and a `DEF_` (deform) copy of every hair chain.
Decoding the rebound mesh's `JOINTS_0`/`WEIGHTS_0` settles it:

```
DEF_Head 15.10%  DEF_Hair2-2 6.50%  DEF_Tail1-5 5.82%  DEF_Tail1-7 5.79%
DEF_Tail1-2 5.66%  DEF_Mane1-6 5.36%  ... (22 bones, all DEF_)
```

**100% of the hair mesh's weight is on `DEF_` bones; exactly 0% on any `CON_`
bone.** In the source `.blend` the `CON_` chain drove spline-IK curves, and
those do not survive glTF, so after export the `CON_` hair bones are inert.
Therefore: exclude **both** layers from the bake (a keyframe on either is
pointless), simulate **only** the `DEF_` layer.

---

## 2. What changed

### `tools/author_anims.py`

- **`SECONDARY_MOTION_PATTERNS = ("mane", "tail", "hair", "forelock", "fringe")`**
  at the top of the file, with `is_secondary_motion_bone()` /
  `secondary_motion_bones()`. Matched case-insensitively as substrings of the
  whole bone name, so one list covers every rig layer at once. Deliberately a
  name-pattern list, not a per-character bone list: Twilight, Rainbow Dash and
  Fluttershy share the naming, and so will Applejack and Rarity. Adding a
  character needs no edit here.
- `author()` refuses to run if the `ANIMATED` set ever grows to include a
  secondary-motion bone — better a loud failure than keys silently discarded at
  export time.
- `author()` forces `arm.pose.ik_solver = "LEGACY"` — see §5.

### `tools/export_blend.py`

- **`rebind_secondary_armatures(primary, meshes)`** — for any mesh being
  exported whose Armature modifier points at something other than the primary
  rig, retarget the modifier and reparent the object (preserving world
  placement), *provided* every one of its vertex groups names a bone that
  exists on the primary rig. Otherwise it leaves the mesh alone and warns on
  stderr; a half-rebound mesh would collapse to the origin. Prints
  `REBIND <mesh> armature <secondary> -> <primary> (vertex_groups=N)`.

  Deliberately **not** fixed by clearing `hide_viewport` on the physics rig:
  that would export a second skeleton with duplicate bone names (two
  `Skeleton3D`s for one character in Godot) and would also drag in every other
  hidden object in these packs (`Base_Wings`, `TS_MeshCageWings`, the `*Physics`
  curve helpers), changing the documented mesh counts.

  Safety of the rebind: the duplicated bones' rest matrices agree between the
  two armatures to a worst case of **4.4e-5** across all three packs (checked
  before relying on it), and both objects sit at identity world transforms. All
  hair vertex groups exist on the primary rig on all three packs — zero
  missing.

- **`exclude_secondary_motion_from_bake(is_excluded)`** — wraps
  `io_scene_gltf2…armature_channels.gather_sampled_bone_channel` so it returns
  `None` for excluded bones. That function *already* returns `None` for "no need
  to animate this node", and its caller already handles it, so this rides a
  supported path rather than forcing a structural change. A missing module
  (future Blender) is a hard `SystemExit` with an explanation, not a silent
  no-op.

  Alternatives rejected: `export_def_bones` filters bones out of the *skeleton*
  (breaks skinning); `export_optimize_animation_keep_anim_armature=False` drops
  channels that merely *happen* to be constant — the right outcome for the wrong
  reason, and it would stop working the moment a hair bone picked up a
  constraint.

- **`assert_no_secondary_motion_tracks(path, is_excluded)`** — re-opens the
  written `.glb`, parses its JSON chunk, and fails the export if any animation
  channel still targets an excluded bone. This turns the pattern list into a
  checked contract instead of a hopeful one.

Export output now includes:

```
REBIND TS_Hair armature TS_RigPhysics -> TS_Rig (vertex_groups=23)
SECONDARY_MOTION_BONES 29 excluded from bake: ['CON_Hair2', ...]
SECONDARY_MOTION_FILTERED 29 bones: [...]
SECONDARY_MOTION_UNKEYED animated_nodes=114 clips=['idle', 'walk']
EXPORT_OK game/assets/converted/ponies/twilight.glb
```

Animated nodes per clip: **143 → 114** for Twilight (29 hair bones dropped),
123 for Rainbow Dash (44 dropped) and 123 for Fluttershy (39 dropped). Mesh,
skin, material counts and the `['idle','walk']` clip list are unchanged.

### `game/scripts/pony_rig.gd` (new, tracked)

The mechanism, and the answer to "where does the simulator live given the
`.glb` is gitignored and regenerated per machine". It is a static-only helper:

- `PonyRig.spawn(character) -> Node3D` — load the `.glb`, instantiate,
  attach hair, return. One call; this is what Phase 1 uses.
- `PonyRig.attach_hair_simulation(pony) -> SpringBoneSimulator3D` — for a model
  you already instantiated (the gallery globs a directory, so it does this).
  Idempotent.
- `PonyRig.hair_chains(skeleton) -> Array[PackedInt32Array]` — chain discovery,
  also used by the measurement scene.
- `HAIR_PATTERNS` mirrors `author_anims.SECONDARY_MOTION_PATTERNS`. **The two
  lists must agree.** A bone in one but not the other either goes limp
  (keyframed but simulated — animation wins, no follow-through) or freezes
  (excluded but not simulated — hair welded to the skull).

`game/scenes/characters/pony.tscn` + `pony.gd` are the editor-facing wrapper:
drop it in a scene, set `character` and `autoplay`.

Why a script rather than a scene with a hand-placed simulator node: anything
added inside an imported `.glb`'s node tree, or into its `.import` sidecar, is
lost the next time `export_blend.py` regenerates the file — and on a fresh
clone there is no `.glb` at all until it is regenerated. Building the simulator
in code at spawn time is the only form of this fix that survives §2's
"everything under `game/assets/converted/` is gitignored" rule.

### Chain discovery

`SpringBoneSimulator3D` settings take a root and an end bone on one unbroken
ancestor line, and no bone may appear in two settings or they fight over its
pose. So the hair bones are partitioned into disjoint linear chains: a chain
starts at a hair bone whose parent is not a hair bone (mane and tail roots,
hanging off `DEF_Head` / `DEF_Hip`) **or** whose parent has more than one hair
child (a branch point), and runs down single-child links until it ends or forks.

Twilight yields 8 chains; Rainbow Dash 19 (her tail is a fan of separate locks);
Fluttershy 3 long ones (8/8/10 joints). No hand-written per-character data.

---

## 3. The API, and the four things that are not obvious

`SpringBoneSimulator3D` (Godot 4.4+; verified against this repo's 4.5.2 via
`--doctool` output, not from memory). It is a `SkeletonModifier3D`, so it must
be a **child of the `Skeleton3D`**. Per setting `i`:
`set_root_bone_name`, `set_end_bone_name`, `set_extend_end_bone`,
`set_end_bone_direction`, `set_end_bone_length`, `set_stiffness`, `set_drag`,
`set_gravity`, `set_gravity_direction`, `set_radius`. Node-level: `active`,
`influence`, `external_force`, `reset()`.

1. **Parent it before configuring it.** A `SkeletonModifier3D` resolves bone
   *names* against `get_skeleton()`, which is null until it is in the tree.
   Configure first and parent second and you get unresolved chains that do
   nothing, silently.
2. **`get_joint_count()` is 0 until the simulator is inside the *scene* tree**,
   and every `set_joint_*` call before that is dropped. Worse, the joints are
   created at engine defaults on tree entry, so a setting flagged
   `set_individual_config(true)` then ignores the shared values too — stiffness
   1.0, drag 0.0, hair like a whip. `spawn()` deliberately configures the pony
   *before* the caller adds it to the tree (so no pony is ever visible with
   unsimulated hair), which rules out per-joint configuration. Hence the
   chain-mean scaling in §4.
3. **`extend_end_bone` matters.** Without it the last bone of a chain is only an
   endpoint and never rotates — the very tip of the mane, the part with the most
   visible swing, stays rigid. `BONE_DIRECTION_FROM_PARENT` plus a length equal
   to the last real segment adds a virtual joint past it.
4. **The modifier's output is invisible to `_process`/`_physics_process`.**
   `Skeleton3D` restores the pre-modifier pose after running its stack, and any
   later `get_bone_global_pose()` recomputes global poses from that restored
   pose. Measured directly: reading a mane bone's height from `_physics_process`
   gave `2.036` every frame whether the simulator was on or off, while the same
   read from the `skeleton_updated` signal gave `1.92`. Read from
   `skeleton_updated` (respects `influence`) or from `modification_processed`
   (raw modifier output, *before* `influence` is blended).

### Tuned values

`PonyRig.PROFILES`, first match wins on the chain root's bone name:

| chains | stiffness¹ | drag | gravity¹ | radius |
|---|---|---|---|---|
| `tail` | 8.0 | 0.78 | 0.28 | 0.08 |
| `mane`, `hair`, `forelock`, `fringe` | 8.0 | 0.78 | 0.22 | 0.06 |

¹ **per unit of bone length** — see §4. The absolute values Godot receives come
out between 1.1 and 9.0 depending on the chain.

How they were chosen: a sweep of ~a dozen combinations across stiffness 3–20 and
drag 0.5–0.9, measured with `hair_lag_test` (§4), judged on three criteria —
every leaf chain must *trail* (not lead, not sit rigid), the tips must not buzz,
and the static droop must stay small.

- stiffness 20: the forelock went effectively rigid (0 ms trail) — no
  follow-through at all.
- stiffness 3–5: the mane decoupled, still travelling ~⅔ s after she stopped,
  and its root carried only 0.013 units of the body's 0.101-unit bob.
- drag below ~0.6: the mane *amplified* the bob up to 3.5× (tip swing 0.35 vs
  the body's 0.10) — the "wobbling like jelly" failure mode.
- gravity: the first pass used 0.30–0.55 as an absolute value and dragged the
  tail tip 2.17 units out of place — hanging like wet rope. The shipped numbers
  keep the mean tip offset at 0.09–0.30 units on a ~4.3-unit-tall pony.

8.0 / 0.78 is the plateau where all six of Twilight's leaf chains trail and
nothing buzzes. The tail differs only in more gravity (it hangs rather than
flicks) and a wider collision radius.

Nothing collides yet — no `SpringBoneCollision3D` nodes are attached, so
`radius` is currently inert. It is set to sensible values so that adding body
collision in Phase 1 (to stop the mane clipping the neck on a hard turn) is a
one-line change rather than a re-tune.

---

## 4. Why stiffness is expressed per unit of bone length

Godot's spring solver adds `stiffness * delta` as an **absolute** displacement
of a joint's tail and then renormalises the segment to its own length. The
*angular* restoring force a joint feels is therefore `stiffness * delta /
length`: at one fixed stiffness a long bone is far floppier than a short one.

These rigs vary ~5× in segment length within a single character (Twilight's
forelock segments are ~0.34 units, her tail's 0.34–1.13), and Fluttershy's hair
is longer again. A raw number that suited the forelock left the tail behaving
like wet rope — measured, its tip swing collapsed from 0.176 to 0.020 units and
its phase fell ~250° behind the body. That is not follow-through; that is
decoupled.

`PonyRig.configure_setting()` therefore multiplies the profile's stiffness and
gravity by the chain's **mean segment length**, so one profile behaves
comparably on every chain of every character — which is the whole point of a
name-pattern-driven rig. (Per-*joint* scaling would follow each segment exactly,
but see §3 item 2: it is not reachable from `spawn()`.)

---

## 5. The determinism regression this fix caused, and its fix

`docs/pipeline.md` promises deterministic conversion. Rebinding the hair mesh
onto the main rig broke it, and the break had to be fixed rather than accepted.

**Symptom.** With the rebind in place, exporting Fluttershy repeatedly produced
**three different `.glb` files across six runs**. The differences were confined
to the `idle` clip's front-leg chain: `DEF_LowerFrontLeg.R rotation` differed by
up to 0.576 of a quaternion component (~33°) — a flipped knee, i.e. a real
visual defect, not float noise. The unmodified scripts were byte-stable across
nine consecutive runs, so this was introduced, not pre-existing-but-unnoticed.

**Cause.** The packs ship `pose.ik_solver = 'ITASC'` (iterative damped least
squares, precision 0.005, SDLS). The front IK chain is 1.0668 long against a
1.0537 rest reach — **98.8% extended, 0.0131 of slack** — so the knee's bend
direction is very nearly under-determined and the solver picks whichever
solution it converges into first. Adding a skinned 10k-vertex hair mesh to the
rig perturbed depsgraph evaluation just enough to tip a knife edge that was
already there. (`docs/pipeline.md` §6 already documented this chain popping its
knee; `BODY_CROUCH` exists because of it.)

**Fix.** `author_anims.author()` sets `arm.pose.ik_solver = "LEGACY"` before
authoring. Blender's legacy solver is non-iterative and reproducible. It is not
a quality compromise here: every baked channel agrees with the iTaSC solve to
within **0.0028 of a quaternion component (~0.3°)**, front legs included, and no
channel differs by more than 0.01. The `.blend` is never saved back, so this
only affects our bake.

**Verified.** After the change, three consecutive exports of each of the three
packs produced byte-identical files:

```
twilight:    af86d6448437  af86d6448437  af86d6448437
rainbowdash: d81a4fcd1eac  d81a4fcd1eac  d81a4fcd1eac
fluttershy:  dc93f60ada0c  dc93f60ada0c  dc93f60ada0c
```

(Fluttershy alone was additionally run 8× on an interim build of the same fix,
all identical.)

An interim attempt — deepening `IDLE_CROUCH` from 0.03 to 0.08 to buy the chain
bend margin — did stabilise Fluttershy but not Twilight, and it changed the
authored idle pose, which is the owner's to judge. It was reverted; the solver
change is the root fix and leaves every pose as authored.

---

## 6. Objective evidence that the hair now lags

`game/scenes/test/hair_lag_test.tscn` / `.gd`. Because a visual claim cannot be
asserted headlessly, it measures the thing instead.

**Method.** One scripted manoeuvre, run twice on the same pony: 150 ticks of
`walk` on the spot (springs settle), 60 ticks travelling forwards at the clip's
own 1.32 u/s, then 150 ticks standing still. Pass 1 runs with
`simulator.influence = 0` — that *is* the pre-fix behaviour, hair welded rigidly
to the skull, lockstep by construction. Pass 2 runs at full influence. Both
passes re-seek the clip to 0 so sample *i* of one is the same point of the walk
cycle as sample *i* of the other. Everything runs on the physics tick (animation
and modifier callbacks both moved onto it) so samples are exactly 1/60 s apart
and the result is reproducible. Sampling happens inside `skeleton_updated`
(§3 item 4).

Per chain, the two passes' tip traces are normalised-cross-correlated along the
travel axis. Pass 2 is the same bone making the same journey, so if the springs
work it is pass 1's trace **arriving late**, and the correlation peak is the
follow-through in ticks.

**Why a one-shot ramp and not the walk bob.** The obvious experiment — walk on
the spot, correlate the bob — cannot answer the question. `BODY_BOB` runs at
twice the gait frequency: one period per 10 clip frames = 25 physics ticks. A
lag is only identifiable modulo 25 ticks, so a 19-tick trail is
indistinguishable from a 6-tick lead. Measured that way the tail read "−8
ticks", which was not a lead at all, just an alias. A single start-and-stop is
aperiodic, so its correlation peak means exactly one thing. (An even earlier
version compared each tip against `DEF_Head`/`DEF_Hip` rather than against its
own rigid self, and reported a **317 ms tail "lag" with the simulator switched
off entirely** — the walk clip pitches the body a quarter cycle out of phase
with the bob, and the tail's vertical motion is driven mostly by that pitch.
Both traps are documented in the scene's header so they are not walked into
again.)

**Result — Twilight, `tools/bin/godot --headless --path game
scenes/test/hair_lag_test.tscn`, byte-identical across two runs:**

```
HAIRLAG DEF_Mane1-5  interior trails body by +40 ticks (+666.7 ms) corr=0.930 | dyn_deviation=0.2768 offset=0.1952 | bob rigid=0.1010 sim=0.0138 | wobble rigid=0.031 sim=0.054
HAIRLAG DEF_Mane1-6  leaf     trails body by +40 ticks (+666.7 ms) corr=0.928 | dyn_deviation=0.3869 offset=0.2976 | bob rigid=0.1010 sim=0.0638 | wobble rigid=0.031 sim=0.021
HAIRLAG DEF_Mane3-2  leaf     trails body by +40 ticks (+666.7 ms) corr=0.933 | dyn_deviation=0.4015 offset=0.3186 | bob rigid=0.1010 sim=0.1291 | wobble rigid=0.031 sim=0.017
HAIRLAG DEF_Hair2-3  leaf     trails body by +19 ticks (+316.7 ms) corr=0.936 | dyn_deviation=0.0993 offset=0.0895 | bob rigid=0.1010 sim=0.0538 | wobble rigid=0.031 sim=0.032
HAIRLAG DEF_Hair4-3  leaf     trails body by +19 ticks (+316.7 ms) corr=0.974 | dyn_deviation=0.1207 offset=0.0952 | bob rigid=0.1010 sim=0.0601 | wobble rigid=0.031 sim=0.032
HAIRLAG DEF_Tail1-5  interior trails body by  +5 ticks ( +83.3 ms) corr=0.983 | dyn_deviation=0.0889 offset=0.0991 | bob rigid=0.1587 sim=0.0673 | wobble rigid=0.032 sim=0.023
HAIRLAG DEF_Tail1-7  leaf     trails body by  +9 ticks (+150.0 ms) corr=0.926 | dyn_deviation=0.2092 offset=0.0982 | bob rigid=0.1762 sim=0.0572 | wobble rigid=0.032 sim=0.023
HAIRLAG DEF_Tail4    leaf     trails body by  +5 ticks ( +83.3 ms) corr=0.871 | dyn_deviation=0.1562 offset=0.1402 | bob rigid=0.2130 sim=0.0862 | wobble rigid=0.031 sim=0.024
HAIRLAG_OK leaf_chains=6 moving=6 lagging=6 worst_wobble=0.032
```

Reading it:

- **Trail.** All six leaf chains trail, none leads, none is rigid. Tail tips
  **+83 to +150 ms**, forelock **+317 ms**, mane tips **≥ +667 ms** (they
  saturate the ±40-tick search window). The rigid baseline is 0 ms by
  construction — a rigid bone *is* the body's motion.
- **Not lockstep.** `dyn_deviation` is the mean distance between the simulated
  tip and where a rigid bone would have put it, after re-centring both traces so
  a static droop cannot inflate it: **0.099 to 0.402 units** on a 4.28-unit-tall
  pony, i.e. 2–9% of body height of purely dynamic displacement. Rigid hair
  would score exactly 0.
- **Not jelly.** `wobble` is RMS per-tick vertical acceleration over the settled
  bob, normalised by the swing. Simulated **0.017–0.032** against the rigid
  hair's own **0.031** — the tips are as smooth as, or smoother than, the
  animation driving them. No tick-rate buzz. (The one 0.054 is an interior
  chain, not a visible tip, and comes from dividing by its very small residual
  swing.)
- **Not drooping through the body.** `offset`, the shift in mean tip position,
  stays at **0.09–0.32 units** — 2–7% of body height.
- **Still carries the bob.** `bob sim` vs `bob rigid`: the tips retain 40–60%
  of the body's vertical swing at the tail and forelock. That is damping, which
  is what follow-through looks like — not the 3.5× amplification the underdamped
  settings produced.

**Other characters** (`-- character=<name>`, not part of the gate):

- **Fluttershy** — 3 chains found (8/8/10 joints), `HAIRLAG_OK leaf_chains=3
  moving=3 lagging=3 worst_wobble=0.019`.
- **Rainbow Dash** — 19 chains found, `HAIRLAG_FAIL leaf_chains=14 moving=14
  lagging=11 worst_wobble=0.056`. All 14 leaves move; 3 of them (short one-bone
  tail locks in her fanned tail) do not resolve to a positive trail. See §8.

**Gates, all passing after the change:**

```
GALLERY_OK count=3                      (bones=160/165/140)
WALK_OK laps_progress=1
SMOKE_OK renderer=forward_plus
PROBE_OK count=8
HAIRLAG_OK leaf_chains=6 moving=6 lagging=6 worst_wobble=0.032
validate_gltf.py twilight.glb --require-anims
  -> meshes=17 skins=1 materials=13 textured=True animations=['idle', 'walk']
```

---

## 7. What a future session must do when adding a character

1. Export as documented in `docs/pipeline.md` §3 (`--anims --rotate-z 180`).
2. **Check the export log for a `REBIND` line naming the pack's hair mesh.** No
   line means the hair mesh is not bound to the main rig and will ship rigid at
   the model root — the original defect, and no gate will tell you.
3. Check `SECONDARY_MOTION_FILTERED n` has a plausible bone count. If it is 0,
   the pack names its hair bones something the patterns do not match.
4. Run the editor import pass (§7 of the pipeline doc) — regenerated `.glb`
   files are invisible to headless runs until then.
5. Run `scenes/test/hair_lag_test.tscn -- character=<name>` and read the `CHAIN`
   listing: every hair chain the pack has should appear.
6. If a chain is missing, add the bone-name substring to **both**
   `author_anims.SECONDARY_MOTION_PATTERNS` and `PonyRig.HAIR_PATTERNS`, and
   re-export. They must always agree.
7. Spawn the character with `PonyRig.spawn("<name>")` or
   `scenes/characters/pony.tscn`. **Never `load(<glb>).instantiate()`
   directly** — that gives you a pony with no hair simulation.

---

## 8. Still imperfect

1. **No human has looked at it.** Every claim above is a measurement. An
   offscreen render check was attempted (`xvfb-run` + llvmpipe software Vulkan,
   capturing the same frame with the simulator off and on) but every capture
   came back as a uniform clear-colour frame — no geometry, not even the ground
   plane — so it proved nothing and was not committed. `docs/pipeline.md`
   §"Deferred to Phase 1" item 2 already lists the owner's visual verdict as
   outstanding; hair now belongs on that list too.
2. **Twilight's mane trails longer than ideal** — ≥667 ms, saturating the
   measurement window, versus 83–150 ms for the tail. It is her longest chain
   (5 joints) and it inherits the interior chain's lag on top of its own. It
   trails smoothly (wobble 0.017–0.021) rather than flapping, but "long flowing
   mane" and "detached from the head" are only a tuning step apart and this
   wants an eye on it. A per-chain-length stiffness term (rather than the
   per-segment-length one in §4) is the obvious next lever.
3. **Rainbow Dash has 3 non-trailing leaf chains** out of 14. They are one-bone
   locks in her fanned tail whose extended tip length is guessed from the bone's
   parent offset (§3 item 3) — the guess is worst exactly for single-bone
   chains. Not visible in any current gate (which runs Twilight) and not
   obviously wrong on screen, but it is a known soft spot.
4. **The bake filter monkey-patches a Blender addon internal.** It is guarded
   (hard failure with an explanation if the module moves) and backed by the
   post-export assertion, so it cannot regress silently — but a Blender upgrade
   is the thing most likely to need attention here.
5. **No collision.** The `radius` values are set but no `SpringBoneCollision3D`
   nodes exist, so nothing stops the mane passing through the neck or a wing on
   a hard turn. Adding a capsule or two per character under the simulator is the
   natural Phase 1 follow-up; the measured `offset` figures (≤0.32 units) say
   the hair is not currently swinging far enough for this to be egregious, but
   that is an argument about the current clips, not a guarantee.
6. **The interior mane chain's bob collapses to 0.0138** against the body's
   0.1010 — its root barely follows the head's vertical motion. Combined with
   (2), if the owner reports the mane looking detached, that number is where to
   start: raise the mane profile's stiffness and re-run the lag scene.
