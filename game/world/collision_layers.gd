class_name CollisionLayers
extends RefCounted
## THE one place that says what lives on which physics layer. Never write a raw
## layer/mask integer anywhere else -- the whole point of this file is that a
## reader can answer "what does the camera probe against?" without decoding a
## bitmask by hand.
##
## WHY THIS EXISTS (it fixes a real latent bug, it is not tidying). Until the
## ranch, every collision object in this project sat on Godot's untouched default
## `collision_layer = 1` / `collision_mask = 1`. Everything collided with
## everything, and the camera rig's SpringArm3D pull-in appeared to work only
## because of that accident: its mask was also the default 1, so it happened to
## probe the ground and the camera_test wall. The moment the world grew geometry
## that was deliberately layered -- buildings on their own layer, so the player
## can be told apart from a wall -- an untouched `mask = 1` spring arm would stop
## seeing buildings at all and the camera would sail straight through the barn.
## That is why camera_rig.gd now takes its probe mask from WORLD below rather than
## inheriting a default, and why ranch.tscn/spawner.gd assign every body's layer
## explicitly instead of leaving it at 1.
##
## LAYER 1 IS STILL TERRAIN, deliberately. Every pre-existing test scene
## (playground, camera_test, walk_test, wild_ponies) builds its ground and its
## props on the untouched default layer 1 and is not being rewritten. Keeping
## TERRAIN on bit 1 means every mask defined here also matches those scenes'
## default-layer geometry, so the ranch's layering is additive rather than a
## flag-day change to eight passing gates.
##
## Preloaded BY PATH by its consumers, never by this `class_name`: the global
## class cache lives in the gitignored game/.godot/ and a fresh clone has not
## built it yet (the convention documented at the top of game/scripts/pony_rig.gd).

## The ground, and the invisible walls at the edge of the map. Bit 1 -- see above.
const TERRAIN := 1 << 0
## Static world props: buildings, trees, anything the player must not walk through
## and the camera must not see through. Bit 2.
const PROPS := 1 << 1
## The player's CharacterBody3D. Bit 3. Separated from PROPS so a pony's detection
## Area3D can mask for "the player" specifically instead of for "anything solid".
const PLAYER := 1 << 2
## Wild ponies' CharacterBody3D. Bit 4.
const PONY := 1 << 3
## Non-solid trigger volumes: a pony's DetectionArea, a ZoneMarker. Bit 5. Nothing
## ever *collides* with this layer; it exists so an Area3D is distinguishable from
## a body in a mask.
const INTERACTION := 1 << 4

## Solid, immovable world. What the camera's spring arm probes, and the floor
## everything walks on.
##
## The spring arm deliberately does NOT probe PLAYER or PONY: a camera that yanks
## itself in every time a pony wanders between the player and the lens is worse
## than one that lets her pass through frame, and the arm already excludes the
## player's own body by RID in camera_rig.gd anyway.
const WORLD := TERRAIN | PROPS

## What a walking character collides with: the world, plus every other character
## (so ponies jostle each other and the player instead of interpenetrating).
const CHARACTERS := PLAYER | PONY
const WALKABLE := WORLD | CHARACTERS
