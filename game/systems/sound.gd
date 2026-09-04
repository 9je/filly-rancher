extends Node
## THE ONE GATEWAY TO SOUND. Every effect, tick and ambient bed in this game is played by
## this autoload and by nothing else. A caller passes an id and, for a world sound, a
## position; it never picks a file, a pitch, a bus or a player. That is not tidiness for its
## own sake: it is the only way to keep the promise below.
##
## THE MATH DOES NOT CHANGE. The variation this file adds (which hoofstep, which chip clink,
## what pitch) is decided on _rng, a RandomNumberGenerator this file owns and seeds from
## entropy at boot. It is the only generator in the audio path. No casino outcome, capture
## roll, economy payout or seeded draw may ever be perturbed because a sound played, and
## making the choice here rather than at the call site is what guarantees it: a menu that
## cannot construct a generator cannot spend one.
##
## REGISTERED AFTER AudioSafety, on purpose. AudioSafety._ready() mutes the Master bus for
## every headless and offscreen capture run; the three buses this file plays into all send
## to Master, so that one mute covers the lot. Autoloads run in declaration order, so
## AudioSafety is finished before the first player here exists.
##
## PAUSE. UI sounds run PROCESS_MODE_ALWAYS because menus are open while the tree is
## paused. World sounds, casino sounds and every ambient bed run PROCESS_MODE_PAUSABLE, so
## opening the pause menu stills the world's noise exactly as it stills its motion.

const BUS_MASTER := &"Master"
const BUS_AMBIENT := &"Ambient"
const BUS_EFFECTS := &"Effects"
const BUS_UI := &"UI"

## Pool sizes. Twelve 2D voices is comfortably past the busiest real moment measured in
## this game (a slots spin ticking three reels under a casino bed); the pool steals its
## oldest voice rather than growing, so a runaway caller degrades into overlap and never
## into an allocation storm.
const POOL_2D := 12
const POOL_3D := 8
## One voice per simultaneously audible bed, PLUS headroom for the ones still fading out.
## The worst case the tables in Task 3 can produce is five simultaneous beds (NIGHT plus
## the Strip), and a crossfade holds the departing set's voices for CROSSFADE_SECONDS on
## top of that, so the pool is sized for both halves of a change rather than for one.
const BED_VOICES := 10

const CROSSFADE_SECONDS := 4.0
## What "off" means for a bed voice. Not -inf dB: the bus accepts it and then behaves
## oddly, which is the same reason Settings.apply_audio() mutes at zero instead.
const SILENT_DB := -60.0
## Distance at which a 3D one shot has fallen away to nothing. The whole playable map is
## about 160 m across and a pen is 20 m, so this is "the next building over, faintly".
const ATTENUATION_METRES := 22.0

const ZONE_NONE := &""
const ZONE_STRIP := &"strip"
const ZONE_CASINO := &"casino"

# --- the one sanctioned neigh -------------------------------------------------------------
#
# Exactly one realistic horse vocalization exists in this game, by owner directive: a rare
# gag where a landed capture plays a fully deadpan mare neigh instead of the chime. The
# roll happens on the private RNG, so THE MATH DOES NOT CHANGE. Nothing else may reference
# GAG_ID, and the corpus test holds both facts.
const GAG_SOURCE := &"capture_success"
const GAG_ID := &"neigh_real"
const GAG_CHANCE := 0.042

## Sound id to entry. Filled by the content tasks; see game/test/test_sound_library.gd for
## the rules every entry is held to.
##   paths      PackedStringArray, one or more res:// paths. Size > 1 is a variant set and
##              the file names must run _1 to _N with no gap.
##   bus        BUS_AMBIENT, BUS_EFFECTS or BUS_UI.
##   volume_db  offset applied on top of the file's own mastered level.
##   pitch_min  lower bound of the per play pitch roll.
##   pitch_max  upper bound; equal to pitch_min means "never vary".
##   loop       true only for the ogg beds; every wav one shot is false.
## "paths" is written as a plain array literal rather than a PackedStringArray(...) call:
## Godot 4.5.2's parser refuses to fold that constructor call as a constant expression
## inside a const Dictionary, so the call form fails to parse here even though it is legal
## at runtime. Every reader still gets a PackedStringArray back, because Dictionary.get()
## into a statically typed PackedStringArray local converts the plain array for it.
const LIBRARY: Dictionary = {
	# --- ambient beds ---
	&"bed_dawn_chorus": {
		"paths": ["res://assets/audio/ambient/bed_dawn_chorus.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_day_meadow": {
		"paths": ["res://assets/audio/ambient/bed_day_meadow.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_dusk_calm": {
		"paths": ["res://assets/audio/ambient/bed_dusk_calm.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_night_insects": {
		"paths": ["res://assets/audio/ambient/bed_night_insects.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_night_owl": {
		"paths": ["res://assets/audio/ambient/bed_night_owl.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_wind_soft": {
		"paths": ["res://assets/audio/ambient/bed_wind_soft.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_strip_hum": {
		"paths": ["res://assets/audio/ambient/bed_strip_hum.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_strip_crowd": {
		"paths": ["res://assets/audio/ambient/bed_strip_crowd.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"bed_casino_room": {
		"paths": ["res://assets/audio/ambient/bed_casino_room.ogg"],
		"bus": BUS_AMBIENT, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	# --- world ---
	&"gate_open": {
		"paths": ["res://assets/audio/world/gate_open.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.94, "pitch_max": 1.06, "loop": false},
	&"mail_arrive": {
		"paths": ["res://assets/audio/world/mail_arrive.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"mail_open": {
		"paths": ["res://assets/audio/world/mail_open.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.97, "pitch_max": 1.03, "loop": false},
	&"mail_stamp": {
		"paths": ["res://assets/audio/world/mail_stamp.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.96, "pitch_max": 1.04, "loop": false},
	&"capture_charge": {
		"paths": ["res://assets/audio/world/capture_charge.wav"],
		"bus": BUS_EFFECTS, "volume_db": -3.0, "pitch_min": 0.98, "pitch_max": 1.06, "loop": false},
	&"capture_success": {
		"paths": ["res://assets/audio/world/capture_success.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"hoofsteps_grass": {
		"paths": [
			"res://assets/audio/world/hoofsteps_grass_1.wav",
			"res://assets/audio/world/hoofsteps_grass_2.wav",
			"res://assets/audio/world/hoofsteps_grass_3.wav",
			"res://assets/audio/world/hoofsteps_grass_4.wav"],
		"bus": BUS_EFFECTS, "volume_db": -8.0, "pitch_min": 0.90, "pitch_max": 1.12, "loop": false},
	&"hoofsteps_hard": {
		"paths": [
			"res://assets/audio/world/hoofsteps_hard_1.wav",
			"res://assets/audio/world/hoofsteps_hard_2.wav",
			"res://assets/audio/world/hoofsteps_hard_3.wav",
			"res://assets/audio/world/hoofsteps_hard_4.wav"],
		"bus": BUS_EFFECTS, "volume_db": -8.0, "pitch_min": 0.90, "pitch_max": 1.12, "loop": false},
	&"delivery_thud": {
		"paths": ["res://assets/audio/world/delivery_thud.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.94, "pitch_max": 1.06, "loop": false},
	&"coins_grant": {
		"paths": ["res://assets/audio/world/coins_grant.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 0.97, "pitch_max": 1.05, "loop": false},
	&"neigh_real": {
		"paths": ["res://assets/audio/world/neigh_real.wav"],
		"bus": BUS_EFFECTS, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	# --- casino ---
	&"chip_clink": {
		"paths": [
			"res://assets/audio/casino/chip_clink_1.wav",
			"res://assets/audio/casino/chip_clink_2.wav",
			"res://assets/audio/casino/chip_clink_3.wav"],
		"bus": BUS_EFFECTS, "volume_db": -4.0, "pitch_min": 0.94, "pitch_max": 1.08, "loop": false},
	&"card_slide": {
		"paths": [
			"res://assets/audio/casino/card_slide_1.wav",
			"res://assets/audio/casino/card_slide_2.wav"],
		"bus": BUS_EFFECTS, "volume_db": -4.0, "pitch_min": 0.95, "pitch_max": 1.07, "loop": false},
	&"card_flip": {
		"paths": ["res://assets/audio/casino/card_flip.wav"],
		"bus": BUS_EFFECTS, "volume_db": -3.0, "pitch_min": 0.96, "pitch_max": 1.05, "loop": false},
	&"reel_tick": {
		"paths": ["res://assets/audio/casino/reel_tick.wav"],
		"bus": BUS_EFFECTS, "volume_db": -14.0, "pitch_min": 0.96, "pitch_max": 1.06, "loop": false},
	&"reel_stop": {
		"paths": ["res://assets/audio/casino/reel_stop.wav"],
		"bus": BUS_EFFECTS, "volume_db": -4.0, "pitch_min": 0.96, "pitch_max": 1.04, "loop": false},
	&"slots_win": {
		"paths": ["res://assets/audio/casino/slots_win.wav"],
		"bus": BUS_EFFECTS, "volume_db": -2.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"wheel_ratchet": {
		"paths": ["res://assets/audio/casino/wheel_ratchet.wav"],
		"bus": BUS_EFFECTS, "volume_db": -12.0, "pitch_min": 0.96, "pitch_max": 1.06, "loop": false},
	&"wheel_settle": {
		"paths": ["res://assets/audio/casino/wheel_settle.wav"],
		"bus": BUS_EFFECTS, "volume_db": -3.0, "pitch_min": 0.97, "pitch_max": 1.04, "loop": false},
	&"race_crowd_loop": {
		"paths": ["res://assets/audio/casino/race_crowd_loop.ogg"],
		"bus": BUS_EFFECTS, "volume_db": -6.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"race_gallop": {
		"paths": ["res://assets/audio/casino/race_gallop.ogg"],
		"bus": BUS_EFFECTS, "volume_db": -8.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": true},
	&"race_cheer": {
		"paths": ["res://assets/audio/casino/race_cheer.wav"],
		"bus": BUS_EFFECTS, "volume_db": -2.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	# --- ui ---
	&"ui_move": {
		"paths": ["res://assets/audio/ui/ui_move.wav"],
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 0.97, "pitch_max": 1.03, "loop": false},
	&"ui_confirm": {
		"paths": ["res://assets/audio/ui/ui_confirm.wav"],
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 0.98, "pitch_max": 1.02, "loop": false},
	&"ui_back": {
		"paths": ["res://assets/audio/ui/ui_back.wav"],
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 0.98, "pitch_max": 1.02, "loop": false},
	&"ui_open": {
		"paths": ["res://assets/audio/ui/ui_open.wav"],
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"ui_denied": {
		"paths": ["res://assets/audio/ui/ui_denied.wav"],
		"bus": BUS_UI, "volume_db": 0.0, "pitch_min": 1.0, "pitch_max": 1.0, "loop": false},
	&"ui_page": {
		"paths": ["res://assets/audio/ui/ui_page.wav"],
		"bus": BUS_UI, "volume_db": -2.0, "pitch_min": 0.98, "pitch_max": 1.02, "loop": false},
}

## WorldState.Phase int to the beds that phase runs. The ints are written out rather than
## read off WorldState.Phase because a const initialiser cannot preload a script; the
## corpus test asserts these four keys are exactly WorldState's four phases, so the two
## cannot drift apart in silence.
const BEDS: Dictionary = {
	0: [  # DAWN
		{"id": &"bed_dawn_chorus", "volume_db": 0.0},
		{"id": &"bed_wind_soft", "volume_db": -6.0},
	],
	1: [  # DAY
		{"id": &"bed_day_meadow", "volume_db": 0.0},
		{"id": &"bed_wind_soft", "volume_db": -8.0},
	],
	2: [  # DUSK
		{"id": &"bed_dusk_calm", "volume_db": 0.0},
		{"id": &"bed_wind_soft", "volume_db": -6.0},
	],
	3: [  # NIGHT
		{"id": &"bed_night_insects", "volume_db": 0.0},
		{"id": &"bed_night_owl", "volume_db": -4.0},
		{"id": &"bed_wind_soft", "volume_db": -4.0},
	],
}

## Zone StringName to the beds that zone overlays ON TOP of the phase's, never instead of
## them: the Strip is outdoors and the meadow is still out there behind the lamps. The
## worst case is NIGHT plus strip, which is five simultaneous beds against BED_VOICES of 10
## (the extra five are headroom for the outgoing set, which holds its voices while it fades).
const ZONE_BEDS: Dictionary = {
	ZONE_STRIP: [
		{"id": &"bed_strip_hum", "volume_db": -3.0},
		{"id": &"bed_strip_crowd", "volume_db": -8.0},
	],
	ZONE_CASINO: [
		{"id": &"bed_casino_room", "volume_db": -3.0},
	],
}


# --- state ------------------------------------------------------------------------------

var _streams: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _bed_voices: Array[AudioStreamPlayer] = []
## Held loops that are not beds, one dedicated player per id. See play_loop().
var _loops: Dictionary = {}
## Bed id to the index in _bed_voices currently carrying it.
var _bed_playing: Dictionary = {}
## Voice indices whose bed has been released and is still fading out. Held apart from
## _bed_playing so a departing bed cannot have its voice reassigned mid fade.
var _bed_releasing: Dictionary = {}
## Id to that id's own ARRIVAL tween (the fade toward its wanted level on the voice
## _bed_playing currently credits it with). Keyed by id, not by voice, because an id owns
## at most one arrival tween at a time.
var _bed_tweens: Dictionary = {}
## Voice index to that voice's own DEPARTURE tween (the fade to SILENT_DB queued by
## _fade_bed_out, whose tween_callback is the only path that clears _bed_releasing and
## frees the voice). Deliberately a SEPARATE dictionary from _bed_tweens and keyed by
## voice rather than id: an id that drops out and is requested again inside
## CROSSFADE_SECONDS is handed a DIFFERENT voice by _bed_voice_for (the old one is still
## _bed_releasing), and the new arrival's _tween_bed call must never be able to reach
## into, and stop, the old voice's own departure tween. One shared id keyed dictionary for
## both jobs was exactly that bug: the arrival's own cleanup would abort whichever tween
## was sitting at _bed_tweens[id], including the departing one, and its queued
## _release_now() callback would never fire, stranding the voice in _bed_releasing
## forever.
var _bed_release_tweens: Dictionary = {}
## Id to the last wanted_db _apply_beds() asked _fade_bed_in() for. Lets a repeat request
## at an unchanged level (a zone change under a steady phase, say) be recognised and
## skipped rather than restarting the bed's tween and spending an RNG draw on a stream
## pick nothing will use.
var _bed_wanted_db: Dictionary = {}
var _phase := -1
var _zone: StringName = ZONE_NONE
var _rng: RandomNumberGenerator = null
var _rng_seed := 0


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_rng_seed = _rng.seed
	_build_pools()
	_load_streams()


# --- construction -------------------------------------------------------------------------

func _build_pools() -> void:
	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.name = "Voice2D_%d" % i
		player.bus = String(BUS_EFFECTS)
		# Set per play; PAUSABLE is the safe default for a world sound.
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		_pool_2d.append(player)
	for i in POOL_3D:
		var player3d := AudioStreamPlayer3D.new()
		player3d.name = "Voice3D_%d" % i
		player3d.bus = String(BUS_EFFECTS)
		player3d.process_mode = Node.PROCESS_MODE_PAUSABLE
		player3d.max_distance = ATTENUATION_METRES
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player3d)
		_pool_3d.append(player3d)
	for i in BED_VOICES:
		var bed := AudioStreamPlayer.new()
		bed.name = "Bed_%d" % i
		bed.bus = String(BUS_AMBIENT)
		bed.process_mode = Node.PROCESS_MODE_PAUSABLE
		bed.volume_db = SILENT_DB
		add_child(bed)
		_bed_voices.append(bed)


## Every path named by LIBRARY, loaded once. load() rather than preload(): a missing or
## corrupt file must be a push_error a player can still play through, never a parse error
## that takes the whole autoload down and with it every other sound in the game.
func _load_streams() -> void:
	for id: StringName in LIBRARY.keys():
		var entry: Dictionary = LIBRARY[id]
		var paths: PackedStringArray = entry.get("paths", PackedStringArray())
		for path: String in paths:
			if _streams.has(path):
				continue
			var stream: Resource = load(path)
			if stream is AudioStream:
				_streams[path] = stream
			else:
				push_error("Sound: '%s' (id %s) did not load as an AudioStream" % [path, id])


# --- the public verbs ---------------------------------------------------------------------

## A 2D one shot: something the player is told about rather than something happening at a
## place. UI ticks and the capture stinger. Returns false when the id is unknown or its
## file failed to load, so a gate can assert on the refusal.
func play(id: StringName) -> bool:
	id = _resolve_play_id(id)
	# NOT `var entry :=`: a local of that name would shadow this class's own entry()
	# method, which GDScript reports as a parse error on the dependency compile path the
	# suite's sweep runs. Every reader in this file uses entry_data for the same reason.
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound.play: unknown id '%s'" % id)
		return false
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return false
	var player: AudioStreamPlayer = _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	player.stop()
	player.stream = stream
	player.bus = String(entry_data.get("bus", BUS_EFFECTS))
	player.volume_db = float(entry_data.get("volume_db", 0.0))
	player.pitch_scale = pick_pitch(
		float(entry_data.get("pitch_min", 1.0)), float(entry_data.get("pitch_max", 1.0)))
	# A UI tick has to be audible while the tree is paused; nothing else does.
	player.process_mode = Node.PROCESS_MODE_ALWAYS \
		if StringName(entry_data.get("bus", BUS_EFFECTS)) == BUS_UI \
		else Node.PROCESS_MODE_PAUSABLE
	player.play()
	return true


## A 3D one shot at a world position: hooves, a gate, a crate set down, a letterbox flap.
func play_at(id: StringName, pos: Vector3) -> bool:
	id = _resolve_play_id(id)
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound.play_at: unknown id '%s'" % id)
		return false
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return false
	var player: AudioStreamPlayer3D = _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	player.stop()
	player.stream = stream
	player.bus = String(entry_data.get("bus", BUS_EFFECTS))
	player.volume_db = float(entry_data.get("volume_db", 0.0))
	player.pitch_scale = pick_pitch(
		float(entry_data.get("pitch_min", 1.0)), float(entry_data.get("pitch_max", 1.0)))
	player.global_position = pos
	player.play()
	return true


## A HELD LOOP THAT IS NOT A BED: the race crowd and the gallop under it. They start when a
## race starts, stop when it settles, sit on the Effects bus and pause with the world, so
## they are neither a one shot nor an ambient bed. One dedicated player per id, built on
## first use and kept, because a loop stolen out of the one shot pool would never stop.
func play_loop(id: StringName) -> bool:
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound.play_loop: unknown id '%s'" % id)
		return false
	if not bool(entry_data.get("loop", false)):
		push_error("Sound.play_loop: '%s' is not a looping entry" % id)
		return false
	var player: AudioStreamPlayer = _loop_player_for(id, entry_data)
	if player == null:
		return false
	if player.playing:
		return true
	player.play()
	return true


func stop_loop(id: StringName) -> void:
	var found: Variant = _loops.get(id, null)
	if found is AudioStreamPlayer:
		found.stop()


func looping_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _loops.keys():
		var player: AudioStreamPlayer = _loops[id]
		if player.playing:
			out.append(id)
	# sort_custom rather than plain sort(): StringName's default comparator is not reliably
	# lexicographic once other scripts have interned the same names first, so compare as
	# String, the same fix game/systems/inventory.gd's ids() carries for the same reason.
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _loop_player_for(id: StringName, entry_data: Dictionary) -> AudioStreamPlayer:
	var found: Variant = _loops.get(id, null)
	if found is AudioStreamPlayer:
		return found
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % id
	player.stream = stream
	player.bus = String(entry_data.get("bus", BUS_EFFECTS))
	player.volume_db = float(entry_data.get("volume_db", 0.0))
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	_loops[id] = player
	return player


## Cross into this phase's bed set. A repeat of the phase already running is a no op, which
## matters because ranch.gd calls this from _on_world_changed(), which a weather roll can
## fire without the phase having moved at all.
func ambient_set_phase(phase: int) -> void:
	if phase == _phase:
		return
	_phase = phase
	_apply_beds()


## Overlay this zone's beds on top of the phase's. ZONE_NONE takes the overlay away.
func ambient_set_zone(zone: StringName) -> void:
	if zone == _zone:
		return
	_zone = zone
	_apply_beds()


## Everything off, immediately, and the bookkeeping back to boot. Used by the gate between
## checks and by after_each() in the suite.
func stop_all() -> void:
	for player: AudioStreamPlayer in _pool_2d:
		player.stop()
	for player3d: AudioStreamPlayer3D in _pool_3d:
		player3d.stop()
	for id: StringName in _loops.keys():
		var loop: AudioStreamPlayer = _loops[id]
		loop.stop()
	for id: StringName in _bed_tweens.keys():
		var tween: Tween = _bed_tweens[id]
		if tween != null and tween.is_valid():
			tween.kill()
	_bed_tweens.clear()
	for index: int in _bed_release_tweens.keys():
		var release_tween: Tween = _bed_release_tweens[index]
		if release_tween != null and release_tween.is_valid():
			release_tween.kill()
	_bed_release_tweens.clear()
	for bed: AudioStreamPlayer in _bed_voices:
		bed.stop()
		bed.volume_db = SILENT_DB
	_bed_playing.clear()
	_bed_releasing.clear()
	_bed_wanted_db.clear()
	_phase = -1
	_zone = ZONE_NONE


# --- readers, for callers and for the gate ------------------------------------------------

func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in LIBRARY.keys():
		out.append(id)
	# sort_custom rather than plain sort(): see the same fix and note on looping_ids() above.
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func has_id(id: StringName) -> bool:
	return LIBRARY.has(id)


func entry(id: StringName) -> Dictionary:
	var found: Variant = LIBRARY.get(id, {})
	return found if found is Dictionary else {}


func current_phase() -> int:
	return _phase


func current_zone() -> StringName:
	return _zone


func active_bed_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _bed_playing.keys():
		out.append(id)
	out.sort()
	return out


## Voice indices still fading toward SILENT_DB after their bed departed. Empty in the
## resting state; a voice lingering here after its own departure tween's
## CROSSFADE_SECONDS has elapsed is exactly the stranded voice bug the flip flop test
## guards against.
func releasing_voice_indices() -> Array[int]:
	var out: Array[int] = []
	for index: int in _bed_releasing.keys():
		out.append(index)
	out.sort()
	return out


func is_voice_releasing(index: int) -> bool:
	return _bed_releasing.has(index)


## The Tween carrying a releasing voice toward SILENT_DB, or null. Test introspection: it
## lets a test drive that Tween's own custom_step() to prove its queued _release_now()
## callback still fires after a same id arrival, deterministically and without an await.
func release_tween_for(index: int) -> Tween:
	var found: Variant = _bed_release_tweens.get(index, null)
	return found if found is Tween else null


## The voice index currently crediting this bed as playing, or -1 if none does. Test
## introspection alongside active_bed_ids(); ranch code has no legitimate reason to care
## which physical voice a bed lives on.
func voice_index_for(id: StringName) -> int:
	return int(_bed_playing.get(id, -1))


func pool_2d_size() -> int:
	return _pool_2d.size()


func pool_3d_size() -> int:
	return _pool_3d.size()


func bed_voice_size() -> int:
	return _bed_voices.size()


func has_private_rng() -> bool:
	return _rng != null


func rng_seed() -> int:
	return _rng_seed


func stream_for(path: String) -> AudioStream:
	var found: Variant = _streams.get(path, null)
	return found if found is AudioStream else null


func bus_index_for(bus: StringName) -> int:
	return AudioServer.get_bus_index(String(bus))


## The process mode the most recent play() set on its voice. Exists for the test that
## asserts UI ticks outlive a pause and world sounds do not; nothing in the game reads it.
func last_process_mode() -> int:
	if _pool_2d.is_empty():
		return Node.PROCESS_MODE_INHERIT
	var last: int = (_next_2d - 1 + _pool_2d.size()) % _pool_2d.size()
	return _pool_2d[last].process_mode


# --- the private generator, and nothing else ----------------------------------------------

## THE ONE INTERNAL RESOLUTION PATH play() and play_at() both share, before either does its
## entry lookup. The only place GAG_ID can ever be substituted in: a request for GAG_SOURCE
## rolls _rng.randf() against GAG_CHANCE and, on a hit, becomes a request for GAG_ID instead.
## Every other id passes through untouched. The roll spends _rng, Sound's own private
## generator, so THE MATH DOES NOT CHANGE for anything outside this file.
func _resolve_play_id(id: StringName) -> StringName:
	if id == GAG_SOURCE and _rng != null and _rng.randf() < GAG_CHANCE:
		return GAG_ID
	return id


## Which variant. Always in range, always on _rng, never on a shared stream.
func pick_variant(count: int) -> int:
	if count <= 1 or _rng == null:
		return 0
	return _rng.randi_range(0, count - 1)


## What pitch. An equal pair means the sound never varies, and that path spends no roll at
## all, so an unvarying sound cannot advance the generator either.
func pick_pitch(low: float, high: float) -> float:
	if _rng == null or is_equal_approx(low, high):
		return low
	return _rng.randf_range(minf(low, high), maxf(low, high))


func _pick_stream(entry_data: Dictionary) -> AudioStream:
	var paths: PackedStringArray = entry_data.get("paths", PackedStringArray())
	if paths.is_empty():
		return null
	var path: String = paths[pick_variant(paths.size())]
	var stream: AudioStream = stream_for(path)
	if stream == null:
		push_error("Sound: no loaded stream for '%s'" % path)
	return stream


# --- the beds -----------------------------------------------------------------------------

## What should be sounding right now: the phase's beds plus the zone's, keyed by id so a
## bed named by both is carried once at the louder of the two levels.
func _wanted_beds() -> Dictionary:
	var wanted: Dictionary = {}
	var phase_rows: Variant = BEDS.get(_phase, [])
	if phase_rows is Array:
		for row: Dictionary in phase_rows:
			var id: StringName = StringName(row.get("id", &""))
			wanted[id] = maxf(float(row.get("volume_db", 0.0)), float(wanted.get(id, SILENT_DB)))
	var zone_rows: Variant = ZONE_BEDS.get(_zone, [])
	if zone_rows is Array:
		for row: Dictionary in zone_rows:
			var id: StringName = StringName(row.get("id", &""))
			wanted[id] = maxf(float(row.get("volume_db", 0.0)), float(wanted.get(id, SILENT_DB)))
	return wanted


## Bring the wanted set in and take the rest out, both over CROSSFADE_SECONDS. Idempotent:
## a bed that is already sounding at the right level is left entirely alone, so a zone
## change under an unchanged phase does not restart the phase's own beds.
func _apply_beds() -> void:
	var wanted: Dictionary = _wanted_beds()
	for id: StringName in _bed_playing.keys():
		if not wanted.has(id):
			_fade_bed_out(id)
	for id: StringName in wanted.keys():
		_fade_bed_in(id, float(wanted[id]))


## Idempotent: a bed already in _bed_playing at the level _apply_beds() last asked for is
## left entirely alone, spending no RNG draw on a stream pick nothing will use and
## restarting no tween. A zone change under a steady phase re-asks every phase bed at the
## same level every time, so without this check every such change would silently churn
## every bed in the mix, not just the one the zone actually touches.
func _fade_bed_in(id: StringName, target_db: float) -> void:
	if _bed_playing.has(id) and _bed_wanted_db.has(id):
		var current_voice: AudioStreamPlayer = _bed_voices[int(_bed_playing[id])]
		if current_voice.playing and is_equal_approx(float(_bed_wanted_db[id]), target_db):
			return
	var entry_data: Dictionary = entry(id)
	if entry_data.is_empty():
		push_error("Sound: bed id '%s' is not in LIBRARY" % id)
		return
	var voice: AudioStreamPlayer = _bed_voice_for(id)
	if voice == null:
		return
	var stream: AudioStream = _pick_stream(entry_data)
	if stream == null:
		return
	var level: float = target_db + float(entry_data.get("volume_db", 0.0))
	if not voice.playing:
		voice.stream = stream
		voice.volume_db = SILENT_DB
		voice.play()
	_bed_wanted_db[id] = target_db
	_tween_bed(id, voice, level)


## A BED ON ITS WAY OUT KEEPS ITS VOICE UNTIL THE FADE ENDS, but stops counting as playing
## the moment it is released. Those are two different questions and answering them with one
## dictionary was a bug: the voice would be handed to an arriving bed while the departing
## one was still four seconds from silent, and both would write to the same volume.
func _fade_bed_out(id: StringName) -> void:
	var index: int = int(_bed_playing.get(id, -1))
	_bed_playing.erase(id)
	_bed_wanted_db.erase(id)
	# This id's own arrival tween, if one was still running, belongs to the voice being
	# vacated; it has nothing left to animate toward once that voice starts releasing.
	var previous_arrival: Variant = _bed_tweens.get(id, null)
	if previous_arrival is Tween and previous_arrival.is_valid():
		previous_arrival.kill()
	_bed_tweens.erase(id)
	if index < 0 or index >= _bed_voices.size():
		return
	var voice: AudioStreamPlayer = _bed_voices[index]
	_bed_releasing[index] = true
	# Keyed by VOICE, not by id: see _bed_release_tweens' own comment. A later arrival of
	# this same id is handed a different voice and its _tween_bed call only ever touches
	# _bed_tweens[id], so it can never reach in here and stop this departure tween out
	# from under the voice that is still fading.
	var previous_release: Variant = _bed_release_tweens.get(index, null)
	if previous_release is Tween and previous_release.is_valid():
		previous_release.kill()
	var tween: Tween = create_tween()
	tween.tween_property(voice, "volume_db", SILENT_DB, CROSSFADE_SECONDS)
	tween.tween_callback(func() -> void: _release_now(index))
	_bed_release_tweens[index] = tween


## One ARRIVAL tween per bed id, stopped and replaced rather than stacked; a phase that
## flips twice inside four seconds otherwise leaves two tweens arguing over one voice's
## volume. Only ever touches _bed_tweens, never _bed_release_tweens, so an arrival can
## never stop a different voice's departure fade; see _bed_release_tweens' comment.
func _tween_bed(id: StringName, voice: AudioStreamPlayer, target_db: float) -> void:
	var previous: Variant = _bed_tweens.get(id, null)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween: Tween = create_tween()
	tween.tween_property(voice, "volume_db", target_db, CROSSFADE_SECONDS)
	_bed_tweens[id] = tween


## Stop a releasing voice at once and put it back in the pool. The normal caller is this
## voice's own departure tween's queued callback (the fade already reached SILENT_DB); the
## other is _bed_voice_for's steal-a-releasing-voice fallback, which calls this BEFORE that
## tween has finished, so its still-running Tween is stopped here too rather than left to
## keep animating a voice that has since been handed to someone else.
func _release_now(index: int) -> void:
	if index < 0 or index >= _bed_voices.size():
		return
	var voice: AudioStreamPlayer = _bed_voices[index]
	voice.stop()
	voice.volume_db = SILENT_DB
	var release_tween: Variant = _bed_release_tweens.get(index, null)
	if release_tween is Tween and release_tween.is_valid():
		release_tween.kill()
	_bed_release_tweens.erase(index)
	_bed_releasing.erase(index)


## The voice already carrying this bed, or a free one, or, failing both, one that is on its
## way out. Never null in practice: cutting a voice that is already most of the way to
## silent is always better than refusing the bed that is arriving.
func _bed_voice_for(id: StringName) -> AudioStreamPlayer:
	var held: int = int(_bed_playing.get(id, -1))
	if held >= 0 and held < _bed_voices.size():
		return _bed_voices[held]
	var taken: Dictionary = {}
	for other: StringName in _bed_playing.keys():
		taken[int(_bed_playing[other])] = true
	for index in _bed_voices.size():
		if taken.has(index) or _bed_releasing.has(index):
			continue
		_bed_playing[id] = index
		return _bed_voices[index]
	for index in _bed_voices.size():
		if taken.has(index):
			continue
		_release_now(index)
		_bed_playing[id] = index
		return _bed_voices[index]
	push_error("Sound: no free bed voice for '%s'; raise BED_VOICES" % id)
	return null
