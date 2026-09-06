# R0 Save Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every automated boot of this game -- the GUT suite, every headless gate scene, every screenshot script -- write its saves and its settings somewhere that is not the player's own `user://saves`, through one environment variable read once per process.

**Architecture:** `game/systems/save_io.gd` gains a pure `resolve_save_dir(env_value)` and a `static func _static_init()` that reads `FILLY_TEST_SAVE_DIR` exactly once, at class load, into `session_save_dir` and `save_dir`. Because the read happens at class initialization, every existing consumer of `SaveIO.save_dir` -- gates, tests, the live game -- is redirected with zero call-site changes. `game/systems/settings.gd` hangs off the same resolved directory, so `settings.cfg` moves with the saves. `tools/run_tests.sh` and every documented gate command export the variable; a new `tools/prove_save_safety.sh` proves a real gate boot leaves the player's directory byte-identical, with a negative control proving that proof can fail.

**Tech Stack:** Godot 4.5.2, GDScript (static functions on `RefCounted` classes, `_static_init`), GUT 9.5.0 under `game/test/`, bash harness scripts under `tools/`.

**Spec:** `docs/superpowers/specs/2026-09-04-presentation-redesign-design.md` section 3 (slice R0), with the standing constraints in section 2.

## Global Constraints

- **`game/systems/` is frozen for this whole phase except this fix.** Spec section 2: "THE MATH DOES NOT CHANGE -- `game/systems/` is read-only for this whole phase except the save-safety fix in section 3." The only two files under `game/systems/` this plan may touch are `save_io.gd` and `settings.gd`, and only to add the redirect. No economy, casino, story, ledger or state logic changes. No behaviour change to `stage()`, `commit()`, `load()`, `migrate()` or `_first_unrepresentable()`.
- **No em dashes anywhere**, in code, comments, docs, commit messages or printed output. The house dash is ` -- ` (space, two hyphens, space).
- **Comment voice.** Comments state constraints the code cannot show -- why a thing is the way it is, and what breaks otherwise. Match `game/systems/save_io.gd`'s register: full sentences, the failure mode named. Do not narrate what the next line does.
- **Tests are GUT, under `game/test/`,** files named `test_*.gd`, one `test_*()` per case, the idiom of `game/test/test_save_io.gd`. **Every test asserts something.** Use `assert_push_error` for an expected `push_error`; nothing in this slice should produce one.
- **No new `.gd` files in this slice.** Every test added here goes into an existing `test_*.gd`, so no `.gd.uid` sidecar has to be generated. If an implementer nonetheless adds a new `.gd`, they must run `tools/bin/godot --headless --path game --import` once and commit the generated `.uid` beside it. **No `.tscn.uid` files ever** (project convention).
- **`MIN_TESTS` in `tools/run_tests.sh` is 1412 today and never decreases.** This slice adds 8 tests; Task 3 counts the real number off a green run and raises the floor to exactly that.
- **Godot binary is `tools/bin/godot`.** Gate invocations use `--headless --audio-driver Dummy`; never `xvfb-run` for a gate.
- **The parse sweep runs every `game/**/*.gd` outside `addons/` through `--check-only --script`.** A bare autoload identifier (`Sound`, `GameState`) fails that pass because no scene tree exists there. `SaveIO` and `Settings` are `class_name` globals and are safe to reference statically from any script.
- **Frequent commits**, one per task, lowercase imperative summary lines (`fix: gate boots stop touching the live saves`). Commit message trailers are whatever the repository's attribution rule says at the time.

**Parked, deliberately, with reasons:**

- **The per-gate innocence check is not rolled out past the sound gate.** `game/scenes/test/sound_test.gd` already lists `user://saves` in and out and asserts the two match, and Task 2 generalizes it. Giving the other ten hosted gates the same check would add one `_set_check` to each, which moves every documented `checks=` count in `docs/testing.md` (MARKET_OK 69, REGION_OK 49, WORLD_OK 32, COLLECTION_OK 73, LEDGER_OK 87, DEPOT_OK 72, CREATION_OK 93, CASINO_OK 76, STORY_OK 55) and turns a small slice into a wide one. `tools/prove_save_safety.sh` (Task 3) proves the same property about a real hosted gate from outside the engine, which is the stronger claim anyway.
- **`tools/publish_release.sh` and `tools/run_windows_build.sh` are untouched.** They export a build; they never boot a scene, so they cannot write a save.

---

## File Structure

| Path | Change | Responsibility after this slice |
|---|---|---|
| `game/systems/save_io.gd` | Modify (`:117-139`) | Owns the environment variable name, the pure resolver, the one read of the environment, and `session_save_dir`. |
| `game/systems/settings.gd` | Modify (`:11`, `:31-51`) | Resolves `settings.cfg` from `SaveIO.session_save_dir`; both file methods default to it. |
| `game/test/test_save_io.gd` | Modify (`:61-68`, append) | Five new tests for the resolver and the wiring; `after_each` restores the session directory rather than the default. |
| `game/test/test_settings.gd` | Modify (`:6`, append) | Three new tests for the settings path rule. |
| `game/test/test_game_state.gd` | Modify (`:19-20`, `:47`) | `after_each` restores the session directory. |
| `game/test/test_ranch_creation.gd` | Modify (`:49`) | `after_each` restores the session directory. |
| `game/scenes/test/sound_test.gd` | Modify (`:9-13`, `:28`, `:45-57`, `:204-207`) | Proves innocence about BOTH the player's directory and this run's directory, and prints which is which. |
| `tools/run_tests.sh` | Modify (`:40-42`, `:97-98`, `:186`) | Exports a fresh `mktemp -d` save directory for the whole run and cleans it up; carries the new floor. |
| `tools/sky_sheet.sh` | Modify (`:33-34`) | Exports the same variable before rendering sixteen ranch boots. |
| `tools/roster_sheet.sh` | Modify (after its `cd`) | Same, before rendering the roster sheet. |
| `tools/prove_save_safety.sh` | **Create** | The regression proof and its negative control, both inside a sandboxed `XDG_DATA_HOME`. |
| `docs/testing.md` | Modify (many lines, all listed in Task 2 and Task 3) | Every documented boot command carries the prefix; a new section states the switch and the proof. |

---

### Task 1: The redirect -- one read of the environment, two systems following it

**Files:**
- Modify: `game/systems/save_io.gd:117-139` (constants and the `save_dir` declaration) and its class comment
- Modify: `game/systems/settings.gd:11` (constants) and `:31-51` (`load_from` / `save_to`)
- Test: `game/test/test_save_io.gd:61-68` (the `after_each` restore) and appended tests
- Test: `game/test/test_settings.gd:6` (a preload) and appended tests
- Modify: `game/test/test_game_state.gd:19-20,47` and `game/test/test_ranch_creation.gd:49` (the same restore)

**Interfaces:**
- Consumes: nothing from earlier tasks. Existing surface it must not change: `SaveIO.save_dir: String`, `SaveIO.DEFAULT_SAVE_DIR := "user://saves"`, `SaveIO.slot_path(slot: int) -> String`, `Settings.PATH := "user://settings.cfg"`, `Settings.SECTION`, `Settings.load_from(path)`, `Settings.save_to(path) -> bool`.
- Produces, for Tasks 2 and 3 and for every later slice:
  - `SaveIO.TEST_SAVE_DIR_ENV: String` (const, `"FILLY_TEST_SAVE_DIR"`)
  - `SaveIO.resolve_save_dir(env_value: String) -> String` (pure static)
  - `SaveIO.session_save_dir: String` (static var, resolved once at class load)
  - `SaveIO.save_dir: String` (static var, starts at `session_save_dir`)
  - `Settings.FILE_NAME: String` (const, `"settings.cfg"`)
  - `Settings.resolve_settings_path(save_directory: String) -> String` (pure static)
  - `Settings.settings_path: String` (static var, resolved once at class load)
  - `Settings.load_from(path: String = "") -> void` and `Settings.save_to(path: String = "") -> bool`, where an empty argument means `settings_path`

---

- [ ] **Step 1: Write the failing tests for the resolver and the wiring**

Append to the end of `game/test/test_save_io.gd`:

```gdscript


# --- THE TEST MODE REDIRECT ----------------------------------------------------------------
#
# resolve_save_dir() is the whole of the policy, and it is pure for the only reason that
# matters here: the environment is read ONCE, at class load, and a test cannot restart the
# engine to make it be read again. Splitting the decision out of the read is what makes the
# decision testable at all.

func test_an_unset_environment_leaves_the_saves_where_the_player_keeps_them() -> void:
	assert_eq(SaveIOScript.resolve_save_dir(""), SaveIOScript.DEFAULT_SAVE_DIR,
		"nobody asked for a redirect, so this is the player's own directory")


func test_a_blank_environment_value_names_no_directory() -> void:
	assert_eq(SaveIOScript.resolve_save_dir("   "), SaveIOScript.DEFAULT_SAVE_DIR,
		"a variable exported empty must not send saves into a directory named ' '")


func test_a_user_path_is_taken_literally() -> void:
	assert_eq(SaveIOScript.resolve_save_dir("user://gate_scratch"), "user://gate_scratch",
		"a user:// redirect is used exactly as given")


func test_a_native_absolute_path_is_taken_literally() -> void:
	# tools/run_tests.sh exports a `mktemp -d` directory, which is a native path and not a
	# user:// one. Godot's FileAccess and DirAccess take either, and the harness depends on it.
	assert_eq(SaveIOScript.resolve_save_dir("/tmp/filly-saves-1234"), "/tmp/filly-saves-1234",
		"the harness exports a native temp directory, so a native path must survive")


## THE WIRING, not the policy: that _static_init() really ran and really assigned. It claims
## something in BOTH directions on purpose -- under tools/run_tests.sh the variable is set and
## the answer must NOT be the player's directory, and run bare it is unset and the answer must
## BE the player's directory -- so there is no way to run this test and have it assert nothing.
func test_the_session_directory_is_the_one_the_environment_named() -> void:
	var named := OS.get_environment(SaveIOScript.TEST_SAVE_DIR_ENV)
	assert_eq(SaveIOScript.session_save_dir, SaveIOScript.resolve_save_dir(named),
		"_static_init() must resolve the session directory through resolve_save_dir()")
	if named.strip_edges().is_empty():
		assert_eq(SaveIOScript.session_save_dir, SaveIOScript.DEFAULT_SAVE_DIR,
			"nothing was exported, so this process saves where the player does")
	else:
		assert_ne(SaveIOScript.session_save_dir, SaveIOScript.DEFAULT_SAVE_DIR,
			"a redirected process must not be able to reach the player's own slots")
```

- [ ] **Step 2: Run the new tests and watch them fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game \
  -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd \
  -gselect=test_save_io.gd -gexit
```

Expected: the script does not load at all. GUT prints a parse/analyzer error naming the missing members and then

```
[WARNING]:  Ignoring script res://test/test_save_io.gd because it does not extend GutTest
```

with `Tests 0` from that script. That is the correct red for GDScript: a call to a static function that does not exist is an analyzer error, not a runtime failure. If instead the run reports passing tests, the file was not edited.

- [ ] **Step 3: Add the environment constant to `save_io.gd`**

In `game/systems/save_io.gd`, immediately after the `DEFAULT_SAVE_DIR` block (currently ending at line 121), insert:

```gdscript

## The environment variable that moves every save off the player's own slots for the length
## of one process. Exported by tools/run_tests.sh and by every documented gate command, and
## read exactly ONCE, at class load (see _static_init below).
##
## THE DEFECT THIS CLOSES. A headless gate scene under game/scenes/test/ instances the real
## world/ranch.tscn, and the ranch writes a save on the way through its own boot probe. Until
## this existed, only the GUT suite redirected save_dir, by assigning it; every gate boot went
## to user://saves and wrote the slots the owner plays out of. Reading the variable at class
## initialization rather than at each call site is what makes the fix total: there is no
## consumer anywhere -- gate, test, or the live game -- that has to remember to opt in.
const TEST_SAVE_DIR_ENV := "FILLY_TEST_SAVE_DIR"
```

- [ ] **Step 4: Replace the `save_dir` declaration with the resolved pair and the one read**

In `game/systems/save_io.gd`, replace lines 136-139 (the comment block ending `## Production code never assigns it.` and the `static var save_dir := DEFAULT_SAVE_DIR` line) with:

```gdscript
## What TEST_SAVE_DIR_ENV named for this process, or DEFAULT_SAVE_DIR when it named nothing.
## Resolved once and never again: two consumers that each re-read the environment could
## disagree about where the saves are, and the one that lost would write into the player's own
## directory, which is the whole failure being fixed. Tests restore save_dir to THIS rather
## than to DEFAULT_SAVE_DIR -- restoring the default is how a redirected process quietly finds
## its way back to the player's slots.
static var session_save_dir := DEFAULT_SAVE_DIR

## The directory saves are read from and written to. A plain static var rather than a constant
## for exactly one reason: a test points it at its own scratch directory for the length of one
## test (game/test/test_save_io.gd). Production code never assigns it -- it starts at
## session_save_dir and stays there.
static var save_dir := DEFAULT_SAVE_DIR


## Which directory an environment value names, and the whole of the policy. An unset or blank
## value is the player's own directory; anything else is taken literally, whether it is a
## user:// path or a native absolute one (the harness exports a `mktemp -d`, which is native).
##
## PURE, AND SEPARATE FROM THE READ BELOW ON PURPOSE. A value read once per process cannot be
## tested any other way: a test cannot restart the engine to read a different environment. The
## decision is the part worth testing, so the decision is the part that is a function.
static func resolve_save_dir(env_value: String) -> String:
	var named := env_value.strip_edges()
	if named.is_empty():
		return DEFAULT_SAVE_DIR
	return named


## THE ONE READ OF THE ENVIRONMENT. Godot calls this once, when the class is loaded, before any
## caller can reach a static member of it, which is what lets the redirect cover every consumer
## in the project with no call site changes at all.
static func _static_init() -> void:
	session_save_dir = resolve_save_dir(OS.get_environment(TEST_SAVE_DIR_ENV))
	save_dir = session_save_dir
```

- [ ] **Step 5: Record the switch in the class comment**

In `game/systems/save_io.gd`, insert this section immediately before the final paragraph of the class comment (the one beginning `## RefCounted with only static members:`, currently line 104):

```gdscript
## --- WHERE THE SAVES GO ON AN AUTOMATED RUN --------------------------------------------
##
## FILLY_TEST_SAVE_DIR, read once at class load, moves the whole save directory for one
## process. Every automated boot of this game sets it: tools/run_tests.sh exports a fresh
## mktemp -d for the suite, and every gate command in docs/testing.md carries it as a prefix.
## A gate boots the real world/ranch.tscn, the ranch writes a save while it boots, and the
## owner plays out of this same checkout -- so before this existed, running the gates cost the
## owner their slots. See resolve_save_dir() for the policy and tools/prove_save_safety.sh for
## the proof that a gate boot with it set leaves user://saves byte-identical.
##
```

- [ ] **Step 6: Run the save_io tests to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game \
  -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd \
  -gselect=test_save_io.gd -gexit
```

Expected: `---- All tests passed! ----`, with the script's test count 5 higher than before this task (42 tests in `test_save_io.gd`). The `test_the_session_directory...` case takes its redirected branch here, because the command above exports the variable.

- [ ] **Step 7: Fix the three `after_each` restores that would undo the redirect**

Restoring `DEFAULT_SAVE_DIR` after a test hands the rest of the file back to the player's directory. Three files do it. In `game/test/test_save_io.gd:68`, `game/test/test_game_state.gd:47` and `game/test/test_ranch_creation.gd:49`, replace

```gdscript
	SaveIOScript.save_dir = SaveIOScript.DEFAULT_SAVE_DIR
```

with

```gdscript
	# session_save_dir, NOT DEFAULT_SAVE_DIR: on a harness run the process was redirected off
	# the player's slots at class load, and restoring the default would walk every test that
	# runs after this one straight back onto them.
	SaveIOScript.save_dir = SaveIOScript.session_save_dir
```

Leave `test_save_io.gd:155` alone. That assignment is inside `test_the_slot_path_is_the_documented_one`, where pinning the literal default is the point of the test, and `after_each` puts the session directory back straight afterwards.

Then in `game/test/test_game_state.gd`, replace the class comment lines 19-20:

```gdscript
## Saves go to a scratch directory under user:// (SaveIO.save_dir is redirected in
## before_each), so running the suite can never overwrite the developer's real game.
```

with

```gdscript
## Saves go to a scratch directory (SaveIO.save_dir is redirected in before_each), and the
## whole process is already redirected off the player's slots by FILLY_TEST_SAVE_DIR, which
## tools/run_tests.sh exports -- so running the suite can never overwrite the developer's real
## game, whether a test remembered to redirect or not.
```

- [ ] **Step 8: Write the failing tests for the settings path**

In `game/test/test_settings.gd`, add a preload beside the existing one at line 6:

```gdscript
const SaveIOScript := preload("res://systems/save_io.gd")
```

and append to the end of the file:

```gdscript


# --- THE TEST MODE REDIRECT ----------------------------------------------------------------
#
# settings.cfg is the same class of defect as the save slots: a gate boot that opened the pause
# menu and changed a knob rewrote the player's own settings file. It follows SaveIO's session
# directory rather than reading the environment a second time, so there is exactly one read of
# FILLY_TEST_SAVE_DIR in the whole project.

func test_a_redirected_save_directory_takes_the_settings_file_with_it() -> void:
	assert_eq(SettingsScript.resolve_settings_path("/tmp/filly-saves-1234"),
		"/tmp/filly-saves-1234/settings.cfg",
		"a run that saves elsewhere must not be able to rewrite the player's own knobs")


func test_the_default_directory_leaves_the_settings_file_where_it_was() -> void:
	assert_eq(SettingsScript.resolve_settings_path(SaveIOScript.DEFAULT_SAVE_DIR),
		SettingsScript.PATH,
		"settings.cfg sits beside saves/, not inside it, when nothing was redirected")


## The wiring, in both directions, exactly like test_save_io.gd's session directory test.
func test_the_session_settings_path_follows_the_session_save_directory() -> void:
	assert_eq(SettingsScript.settings_path,
		SettingsScript.resolve_settings_path(SaveIOScript.session_save_dir),
		"_static_init() must resolve the settings path from SaveIO's session directory")
	if SaveIOScript.session_save_dir == SaveIOScript.DEFAULT_SAVE_DIR:
		assert_eq(SettingsScript.settings_path, SettingsScript.PATH,
			"nothing was exported, so the settings file is the player's own")
	else:
		assert_ne(SettingsScript.settings_path, SettingsScript.PATH,
			"a redirected process must not be able to reach the player's settings file")
```

- [ ] **Step 9: Run the settings tests and watch them fail**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game \
  -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd \
  -gselect=test_settings.gd -gexit
```

Expected: the same shape of red as Step 2 -- an analyzer error naming `resolve_settings_path` and `settings_path`, then `Ignoring script res://test/test_settings.gd because it does not extend GutTest`.

- [ ] **Step 10: Implement the settings redirect**

In `game/systems/settings.gd`, replace line 11 (`const PATH := "user://settings.cfg"`) with:

```gdscript
## Where the settings file lives when nothing has been redirected. Kept as the literal it has
## always been: it is the path bug reports and docs name.
const PATH := "user://settings.cfg"

## The file name on its own, for the redirected case below.
const FILE_NAME := "settings.cfg"

## The settings file this process actually reads and writes. Resolved once, at class load, from
## SaveIO's already-resolved session directory -- NOT by reading the environment a second time,
## so there is exactly one read of FILLY_TEST_SAVE_DIR in the project and no way for two
## systems to disagree about whether this run is a test run.
static var settings_path := PATH


## Where settings.cfg belongs given the directory the saves are going to. The player's own save
## directory leaves it exactly where it has always been, beside saves/ rather than inside it;
## any other directory takes it along, because a redirected run must not be able to rewrite the
## volume and sensitivity of whoever owns the machine.
static func resolve_settings_path(save_directory: String) -> String:
	if save_directory == SaveIO.DEFAULT_SAVE_DIR:
		return PATH
	return save_directory.path_join(FILE_NAME)


## Referenced by class_name rather than by preload on purpose: SaveIO is a global class, so it
## resolves under tools/run_tests.sh's --check-only parse sweep, which an autoload identifier
## would not. Touching SaveIO here is what loads it, which is what runs its own _static_init and
## fills session_save_dir before this line reads it.
static func _static_init() -> void:
	settings_path = resolve_settings_path(SaveIO.session_save_dir)
```

Then change both file methods to default to it. Replace line 31 (`func load_from(path: String = PATH) -> void:`) and its first two body lines with:

```gdscript
## An empty path means "this process's settings file" (settings_path). A caller that names one
## -- the tests do -- is taken at its word.
func load_from(path: String = "") -> void:
	var target := settings_path if path.is_empty() else path
	var cfg := ConfigFile.new()
	if cfg.load(target) != OK:
		return
```

and replace line 44 (`func save_to(path: String = PATH) -> bool:`) with:

```gdscript
## Same rule as load_from(): empty means this process's settings file.
func save_to(path: String = "") -> bool:
	var target := settings_path if path.is_empty() else path
```

and the method's last line (`	return cfg.save(path) == OK`) with:

```gdscript
	return cfg.save(target) == OK
```

Finally, extend the class comment at line 4 so the file states the rule. Replace:

```gdscript
## sensitivity, invert look. Persisted in user://settings.cfg, deliberately NOT in the
## save file: a save is a ranch two players trade by pasting; a setting is about one
## person's hand and one machine's speakers.
```

with:

```gdscript
## sensitivity, invert look. Persisted in user://settings.cfg, deliberately NOT in the
## save file: a save is a ranch two players trade by pasting; a setting is about one
## person's hand and one machine's speakers.
##
## ON AN AUTOMATED RUN IT MOVES WITH THE SAVES. FILLY_TEST_SAVE_DIR redirects SaveIO's save
## directory for one process (see game/systems/save_io.gd), and settings.cfg follows it into
## that directory. Same defect, same fix: a gate boot that opened the pause menu and nudged a
## slider used to rewrite the settings file of whoever owns the machine.
```

- [ ] **Step 11: Run both test files to green**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game \
  -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd \
  -gselect=test_settings.gd -gexit
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game \
  -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd \
  -gselect=test_save_io.gd -gexit
```

Expected: `---- All tests passed! ----` from both, `test_settings.gd` now reporting 15 tests and `test_save_io.gd` 42.

- [ ] **Step 12: Prove both files still parse under the analyzer**

The suite's parse sweep is the pass that promotes some warnings to errors, and it is what a scene load goes through. Check the four changed scripts directly:

```bash
for s in systems/save_io.gd systems/settings.gd test/test_save_io.gd test/test_settings.gd; do
  tools/bin/godot --headless --audio-driver Dummy --path game --check-only --script "res://$s" \
    && echo "OK   $s" || echo "FAIL $s"
done
```

Expected: four `OK` lines. A `FAIL` on `systems/settings.gd` most likely means the `SaveIO` reference did not resolve, which would be a real problem and not a warning to suppress.

- [ ] **Step 13: Commit**

```bash
git add game/systems/save_io.gd game/systems/settings.gd \
        game/test/test_save_io.gd game/test/test_settings.gd \
        game/test/test_game_state.gd game/test/test_ranch_creation.gd
git commit -m "fix: saves and settings follow FILLY_TEST_SAVE_DIR instead of the player's slots"
```

---

### Task 2: The harness, the gate that proves its innocence, and every documented command

**Files:**
- Modify: `tools/run_tests.sh:40-42` (export), `:97-98` (the trap)
- Modify: `tools/sky_sheet.sh:33-34`, `tools/roster_sheet.sh` (after its `cd`)
- Modify: `game/scenes/test/sound_test.gd:9-13,28,45-57,204-207`
- Modify: `docs/testing.md` -- lines 429, 465, 510, 523, 686, 774, 844, 894, 904, 955, 1043, 1109, 1152, plus the sound gate prose at 1118-1126, plus a new section after line 56

**Interfaces:**
- Consumes: `SaveIO.TEST_SAVE_DIR_ENV`, `SaveIO.resolve_save_dir`, `SaveIO.session_save_dir`, `SaveIO.save_dir`, `SaveIO.DEFAULT_SAVE_DIR` from Task 1.
- Produces: `FILLY_TEST_SAVE_DIR` exported by `tools/run_tests.sh`, `tools/sky_sheet.sh` and `tools/roster_sheet.sh`; the sound gate's two save-directory checks and its `SOUND saves` line, which Task 3's proof reads as a human check.

---

- [ ] **Step 1: Export the redirect from `tools/run_tests.sh`**

In `tools/run_tests.sh`, replace lines 40-42:

```bash
cd "$(dirname "$0")/.."

GUT_TEST_DIR="${GUT_TEST_DIR:-res://test}"
```

with:

```bash
cd "$(dirname "$0")/.."

# EVERY GODOT THIS SCRIPT STARTS WRITES ITS SAVES SOMEWHERE ELSE. game/systems/save_io.gd reads
# FILLY_TEST_SAVE_DIR once, at class load, so exporting it here moves the save directory and the
# settings file for the parse sweep, for GUT, and for anything either of them boots -- without a
# single call site having to remember. Before this, a suite run wrote the player's own slots:
# only the tests that assigned SaveIO.save_dir themselves were safe, and the ones that did not
# (game/test/test_pen.gd, game/test/test_ranch_collection.gd) went straight to user://saves.
# A fresh directory per run, so nothing a previous run left can make a test pass.
FILLY_TEST_SAVE_DIR="$(mktemp -d)"
export FILLY_TEST_SAVE_DIR
out=""
trap 'rm -f "$out"; rm -rf "$FILLY_TEST_SAVE_DIR"' EXIT
echo "Saves for this run: $FILLY_TEST_SAVE_DIR (FILLY_TEST_SAVE_DIR). The player's own are untouched."

GUT_TEST_DIR="${GUT_TEST_DIR:-res://test}"
```

Then replace lines 97-98 (which set up the old, narrower trap):

```bash
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
```

with:

```bash
# The trap that removes this was installed at the top of the script, beside the save directory
# it also removes: a parse sweep failure exits long before this line, and a temp directory left
# behind by every failed run is a slow leak nobody notices.
out="$(mktemp)"
```

- [ ] **Step 2: Run the suite and confirm the redirect is live and nothing regressed**

```bash
bash tools/run_tests.sh
```

Expected: the new `Saves for this run: /tmp/tmp.XXXXXXXX ...` line first, then `Parse sweep: NNN GDScript file(s) parse cleanly.`, then `---- All tests passed! ----` and exit 0. The run takes about four minutes.

- [ ] **Step 3: Confirm with your own eyes that the suite no longer touches the live saves**

```bash
ls -la ~/.local/share/godot/app_userdata/"Filly Rancher"/saves/ > /tmp/saves-before.txt
bash tools/run_tests.sh > /dev/null 2>&1
ls -la ~/.local/share/godot/app_userdata/"Filly Rancher"/saves/ > /tmp/saves-after.txt
diff /tmp/saves-before.txt /tmp/saves-after.txt && echo "UNTOUCHED"
```

Expected: `UNTOUCHED`. If `diff` reports changed mtimes on `slot_*.json`, the export did not take -- check that `export FILLY_TEST_SAVE_DIR` sits above the parse sweep and that Task 1's `_static_init` was really added.

- [ ] **Step 4: Export the same variable from the two rendering scripts**

Both boot `world/ranch.tscn` or a scene that hosts it, so both can write a save. In `tools/sky_sheet.sh`, after line 34 (`cd "$(dirname "$0")/.."`), insert:

```bash

# Sixteen boots of world/ranch.tscn, each of which writes a save on its way through the ranch's
# own boot probe. Redirected off the player's slots the same way tools/run_tests.sh does it; see
# game/systems/save_io.gd. A sheet is not worth somebody's ranch.
FILLY_TEST_SAVE_DIR="${FILLY_TEST_SAVE_DIR:-$(mktemp -d)}"
export FILLY_TEST_SAVE_DIR
```

Insert the same five lines into `tools/roster_sheet.sh` immediately after its own `cd "$(dirname "$0")/.."`, with the first comment line replaced by:

```bash
# Every render boots a scene out of this project, and a boot can write a save. Redirected off
```

- [ ] **Step 5: Generalize the sound gate's innocence check**

`game/scenes/test/sound_test.gd` is the precedent: it lists the save directory in and out and asserts the two match. It now makes the claim about two directories, and names them from `SaveIO` instead of from a literal.

Replace line 28 (`const SAVE_DIR := "user://saves"`) with:

```gdscript
const SaveIOScript := preload("res://systems/save_io.gd")
```

Replace the class comment lines 9-13:

```gdscript
## THIS GATE HOSTS NOTHING. No ranch, no player, no save. Every other gate instances
## world/ranch.tscn because a ranch is what it is checking; this one is checking four
## autoloads and a directory, and a gate that boots the ranch is a gate that can write a
## live save. It proves it rather than promising it: the last check lists user://saves
## before and after and asserts nothing moved.
```

with:

```gdscript
## THIS GATE HOSTS NOTHING. No ranch, no player, no save. Every other gate instances
## world/ranch.tscn because a ranch is what it is checking; this one is checking four
## autoloads and a directory. It proves its innocence rather than promising it, and about TWO
## directories: the player's own user://saves, which nothing on an automated run may ever
## touch, and whatever FILLY_TEST_SAVE_DIR redirected this process to, which this gate has no
## business writing either. The first of those was the parked defect that slice R0 closed --
## a gate boot used to write the live slots -- and this is the check that keeps it closed.
```

Replace the `_ready()` body lines 46-56 with:

```gdscript
	GateWatchdogScript.arm(self, "SOUND", 120.0)
	var live_before: PackedStringArray = _save_listing(SaveIOScript.DEFAULT_SAVE_DIR)
	var session_before: PackedStringArray = _save_listing(SaveIOScript.save_dir)
	print("SOUND saves live=%s session=%s" % [SaveIOScript.DEFAULT_SAVE_DIR,
		SaveIOScript.save_dir])
	_check_the_buses()
	_check_every_stream()
	_check_the_loop_flags()
	_check_the_verbs()
	_check_the_pools()
	_check_the_volume_sliders()
	_set_check("the gate wrote nothing into the player's own save directory",
		_save_listing(SaveIOScript.DEFAULT_SAVE_DIR) == live_before)
	_set_check("the gate wrote nothing into this run's save directory",
		_save_listing(SaveIOScript.save_dir) == session_before)
```

Replace `_save_listing()` at lines 204-207 with:

```gdscript
func _save_listing(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	return DirAccess.get_files_at(dir)
```

- [ ] **Step 6: Run the sound gate**

```bash
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn
```

Expected: a `SOUND saves live=user://saves session=/tmp/tmp.XXXXXXXX` line, both new checks printed `ok`, then `SOUND_OK ids=37` and exit 0. The marker prints ids rather than a check count, so no documented number moved.

- [ ] **Step 7: Put the prefix on every documented boot command in `docs/testing.md`**

Each of these is the whole line; keep the surrounding fences and prose. The `--check-only --script` line (66) and the two `--import` lines (179, 350) are left alone: neither boots a scene, so neither can write a save.

Line 429:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/market_test.tscn
```
Line 465:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/region_test.tscn
```
Line 510:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/world_test.tscn
```
Line 523:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn -- --phase=NIGHT --weather=STORM
```
Line 686:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/collection_test.tscn
```
Line 774:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/ledger_test.tscn
```
Line 844:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/depot_test.tscn
```
Line 955:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/creation_test.tscn
```
Line 1043:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn
```
Line 1109:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/story_test.tscn
```
Line 1152:
```
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn
```

The two inline commands in prose are windowed gallery runs, and they boot the project too. Line 894, replace

```
`tools/bin/godot --path game scenes/test/model_gallery.tscn -- --mark` stands three
```

with

```
`FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --path game scenes/test/model_gallery.tscn -- --mark` stands three
```

and line 904, replace

```
`tools/bin/godot --path game scenes/test/model_gallery.tscn -- --props` loads the
```

with

```
`FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --path game scenes/test/model_gallery.tscn -- --props` loads the
```

- [ ] **Step 8: Document the switch itself**

Insert this section into `docs/testing.md` immediately after line 56 (the end of the "Running the suite" section, after the passing-output example and its `exit code 0` line) and before the `---` that follows:

```markdown

---

## Where an automated run writes its saves

**`FILLY_TEST_SAVE_DIR` moves the save directory for one process.**
`game/systems/save_io.gd` reads it exactly once, at class load
(`_static_init`), into `SaveIO.session_save_dir` and `SaveIO.save_dir`; an
unset or blank value resolves to `SaveIO.DEFAULT_SAVE_DIR`, which is
`user://saves`. `game/systems/settings.gd` follows the same directory, so
`settings.cfg` moves with the slots.

`tools/run_tests.sh` exports a fresh `mktemp -d` for the whole run and removes
it afterwards, and every gate command in this file carries the same prefix.
`tools/sky_sheet.sh` and `tools/roster_sheet.sh` export it too, because every
cell they render is another boot of the ranch.

**Why this exists.** A gate scene under `game/scenes/test/` instances the real
`world/ranch.tscn`, and the ranch writes a save while it boots (its own
`GATE_SAVE_SLOT` probe, slot 9), on top of whatever scratch slot the gate uses
itself. Only the GUT suite used to redirect `SaveIO.save_dir`, by assigning it,
and only in the test files that remembered to -- so running the gates, or
running `test_pen.gd`, wrote the slots the owner actually plays out of, in the
checkout the owner actually plays from. Reading the variable at class
initialization is what makes the fix total: there is no call site anywhere that
has to opt in, and no way for two systems to disagree about whether this is a
test run.

`bash tools/prove_save_safety.sh` is the proof, and it has a negative control.
See "Proving the saves are safe" below.
```

- [ ] **Step 9: Update the sound gate's paragraph, which still describes the defect as parked**

In `docs/testing.md`, replace lines 1118-1126 (the paragraph beginning `game/scenes/test/sound_test.tscn` is the one gate...`) with:

```markdown
`game/scenes/test/sound_test.tscn` is the one gate in this project that hosts
nothing. Every other gate instances `world/ranch.tscn`, because what it is
checking is a ranch. This one is checking four autoloads and a directory of
files. It proves its own innocence rather than promising it, about two
directories at once: it lists `user://saves` (the player's own, which nothing
on an automated run may touch) and `SaveIO.save_dir` (wherever
`FILLY_TEST_SAVE_DIR` sent this run) on the way in and on the way out, and
asserts both listings match. It prints which two directories those were as
`SOUND saves live=... session=...`, so a log says where the run was pointed
rather than leaving it to be assumed.
```

- [ ] **Step 10: Run the full suite and two gates**

```bash
bash tools/run_tests.sh
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/market_test.tscn
```

Expected: `---- All tests passed! ----` and exit 0; `SOUND_OK ids=37`; `MARKET_OK checks=69`. All three exit 0.

- [ ] **Step 11: Commit**

```bash
git add tools/run_tests.sh tools/sky_sheet.sh tools/roster_sheet.sh \
        game/scenes/test/sound_test.gd docs/testing.md
git commit -m "fix: gate boots stop touching the live saves"
```

---

### Task 3: The proof, its negative control, and the test floor

**Files:**
- Create: `tools/prove_save_safety.sh`
- Modify: `tools/run_tests.sh:186` (`MIN_TESTS`)
- Modify: `docs/testing.md` -- a new section before "Proving the atomic save", and the stale floor number at line 272

**Interfaces:**
- Consumes: `FILLY_TEST_SAVE_DIR` as read by `SaveIO._static_init` (Task 1) and exported by `tools/run_tests.sh` (Task 2); `game/scenes/test/market_test.tscn`, which hosts the real ranch and writes slot 8 plus the ranch's own boot probe slot 9.
- Produces: `bash tools/prove_save_safety.sh` printing `SAVE_SAFETY_PROOF_OK`, and `bash tools/prove_save_safety.sh --negative-control` printing `SAVE_SAFETY_PROOF_NEGATIVE_CONTROL_OK`; `MIN_TESTS` at the suite's real size.

---

- [ ] **Step 1: Write the proof script**

Create `tools/prove_save_safety.sh`:

```bash
#!/usr/bin/env bash
# Proves that a headless gate boot with FILLY_TEST_SAVE_DIR set leaves the player's own save
# directory byte-identical -- by booting a real gate and looking. See game/systems/save_io.gd
# for the switch and docs/testing.md for the writeup.
#
#   bash tools/prove_save_safety.sh                     # the proof
#   bash tools/prove_save_safety.sh --negative-control  # prove the proof can fail
#
# NEITHER RUN CAN REACH THE REAL user://saves. Both point XDG_DATA_HOME at a temporary
# directory, which is where Godot resolves user:// from on Linux, so the "live" directory this
# script measures is a sandboxed copy seeded with one decoy slot. That matters most for the
# negative control, whose whole job is to WRITE the live directory: running that against the
# owner's own saves to prove a point would be the exact accident this slice exists to prevent.
#
# THE PROOF: seed a decoy slot in the sandboxed user://saves, take a checksum manifest of it,
# boot scenes/test/market_test.tscn with FILLY_TEST_SAVE_DIR pointed elsewhere, and require
# three things -- the gate passed, the manifest did not move, and the redirected directory
# actually received files. That third one is not decoration: without it a gate that wrote
# nothing anywhere would look exactly like a redirect that worked.
#
# THE NEGATIVE CONTROL: the same boot with FILLY_TEST_SAVE_DIR unset. The manifest MUST move.
# Without this half, a comparison that passed on anything at all would look like a passing
# proof -- which is the failure mode this project keeps finding in its own gates.
#
# --audio-driver Dummy on every run: this is an automated invocation and must never make noise
# on whatever machine runs it (see docs/pipeline.md and game/systems/audio_safety.gd).
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT=tools/bin/godot
GATE=scenes/test/market_test.tscn
NEGATIVE=0
[ "${1:-}" = "--negative-control" ] && NEGATIVE=1

SANDBOX_HOME="$(mktemp -d)"
REDIRECT_DIR="$(mktemp -d)"
trap 'rm -rf "$SANDBOX_HOME" "$REDIRECT_DIR"' EXIT

# Where Godot puts user:// on Linux, given XDG_DATA_HOME. The project name comes from
# game/project.godot's application/config/name.
LIVE="$SANDBOX_HOME/godot/app_userdata/Filly Rancher/saves"
mkdir -p "$LIVE"
# A decoy that stands in for the owner's ranch. "Untouched" is only a claim worth making about
# a directory that had something in it to touch.
printf '{\n  "bits": 4242,\n  "marker": "OWNER_SAVE",\n  "version": 5\n}\n' > "$LIVE/slot_0.json"

manifest() {
  ( cd "$LIVE" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum )
}

before="$(manifest)"

if [ "$NEGATIVE" -eq 1 ]; then
  echo "== NEGATIVE CONTROL: booting the gate with no redirect at all =="
  XDG_DATA_HOME="$SANDBOX_HOME" \
    "$GODOT" --headless --audio-driver Dummy --path game "$GATE" > "$SANDBOX_HOME/gate.log" 2>&1
else
  echo "== booting the gate with FILLY_TEST_SAVE_DIR=$REDIRECT_DIR =="
  XDG_DATA_HOME="$SANDBOX_HOME" FILLY_TEST_SAVE_DIR="$REDIRECT_DIR" \
    "$GODOT" --headless --audio-driver Dummy --path game "$GATE" > "$SANDBOX_HOME/gate.log" 2>&1
fi
gate_rc=$?

# A gate that crashed may have written nothing for reasons that have nothing to do with the
# redirect, so its verdict is a precondition of this proof and not an afterthought.
if [ "$gate_rc" -ne 0 ]; then
  echo "FAIL: the gate exited $gate_rc, so this run measured a broken build rather than the redirect." >&2
  tail -20 "$SANDBOX_HOME/gate.log" >&2
  exit 1
fi

after="$(manifest)"
redirected_files="$(find "$REDIRECT_DIR" -type f | wc -l)"
live_files="$(find "$LIVE" -type f | wc -l)"
echo "PROOF live_dir='$LIVE' files_before=1 files_after=$live_files redirected_files=$redirected_files"

if [ "$NEGATIVE" -eq 1 ]; then
  if [ "$before" = "$after" ]; then
    echo "FAIL: an unredirected gate boot left the live save directory identical -- this harness cannot tell a written save from an untouched one, so its positive result would mean nothing." >&2
    exit 1
  fi
  echo "SAVE_SAFETY_PROOF_NEGATIVE_CONTROL_OK -- an unredirected gate boot DOES write the live save directory, and this harness catches it."
  exit 0
fi

if [ "$before" != "$after" ]; then
  echo "FAIL: a redirected gate boot changed the live save directory." >&2
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2
  exit 1
fi
if [ "$redirected_files" -eq 0 ]; then
  echo "FAIL: the live directory is untouched but nothing was written to $REDIRECT_DIR either -- the gate wrote no save at all, so this proves nothing about the redirect." >&2
  exit 1
fi
echo "SAVE_SAFETY_PROOF_OK -- a gate boot with FILLY_TEST_SAVE_DIR set wrote $redirected_files file(s) there and left the live save directory byte-identical."
```

- [ ] **Step 2: Make it executable and run the negative control first**

The control is run first on purpose: a positive result from a harness that has not yet been shown capable of failing is not evidence.

```bash
chmod +x tools/prove_save_safety.sh
bash tools/prove_save_safety.sh --negative-control
```

Expected, on exit 0:

```
== NEGATIVE CONTROL: booting the gate with no redirect at all ==
PROOF live_dir='/tmp/tmp.XXXXXXXX/godot/app_userdata/Filly Rancher/saves' files_before=1 files_after=4 redirected_files=0
SAVE_SAFETY_PROOF_NEGATIVE_CONTROL_OK -- an unredirected gate boot DOES write the live save directory, and this harness catches it.
```

`files_after` is whatever slot 8, slot 9 and their `.bak` companions add up to; the number is not the claim, the changed manifest is. If this prints `FAIL: an unredirected gate boot left the live save directory identical`, stop: either `XDG_DATA_HOME` is not reaching Godot on this machine or the gate is not writing, and the positive run below would be meaningless.

- [ ] **Step 3: Run the proof**

```bash
bash tools/prove_save_safety.sh
```

Expected, on exit 0:

```
== booting the gate with FILLY_TEST_SAVE_DIR=/tmp/tmp.YYYYYYYY ==
PROOF live_dir='/tmp/tmp.XXXXXXXX/godot/app_userdata/Filly Rancher/saves' files_before=1 files_after=1 redirected_files=4
SAVE_SAFETY_PROOF_OK -- a gate boot with FILLY_TEST_SAVE_DIR set wrote 4 file(s) there and left the live save directory byte-identical.
```

- [ ] **Step 4: Document the proof**

Insert into `docs/testing.md` immediately before the `## Proving the atomic save (a thing a unit test cannot do)` heading. The outer fence below is four backticks only so the inner three-backtick block survives; write the inner one as three backticks:

````markdown
## Proving the saves are safe (a thing a unit test cannot do)

`game/systems/save_io.gd` reads `FILLY_TEST_SAVE_DIR` once, at class load. A
unit test can prove the resolver's policy (`game/test/test_save_io.gd`) and
that `_static_init` wired it, but it cannot prove the thing that actually
matters: that booting a real gate, which instances the real
`world/ranch.tscn`, leaves the player's own directory alone.

```bash
bash tools/prove_save_safety.sh                     # the proof
bash tools/prove_save_safety.sh --negative-control  # prove the proof can fail
```

The proof seeds a decoy `slot_0.json`, takes a `sha256sum` manifest of the live
directory, boots `scenes/test/market_test.tscn` with the variable set, and
requires three things: the gate passed, the manifest did not move, and the
redirected directory actually received files. That third one is the one worth
explaining -- a gate that wrote nothing anywhere would otherwise look exactly
like a redirect that worked.

The negative control boots the same gate with the variable unset and requires
the manifest to MOVE. Without it, a comparison that passed on anything at all
would look like a passing proof.

**Neither run can reach the real `user://saves`.** Both point `XDG_DATA_HOME`
at a temporary directory, which is where Godot resolves `user://` from on
Linux, so the "live" directory being measured is a sandboxed one seeded with a
decoy. That matters most for the negative control, whose whole job is to write
the live directory: running it against the owner's own saves to prove a point
would be exactly the accident this slice exists to prevent.

---
````

- [ ] **Step 5: Run the full suite and read the real test count**

```bash
bash tools/run_tests.sh 2>&1 | tee /tmp/r0-suite.log | tail -30
grep -oP '^Tests\s+\K[0-9]+' /tmp/r0-suite.log | tail -1
```

Expected: `---- All tests passed! ----`, exit 0, and a count 8 higher than the suite was before this slice (5 added to `test_save_io.gd` in Task 1 Step 1, 3 added to `test_settings.gd` in Task 1 Step 8). With the floor at 1412 before this slice, expect **1420**. Use the number the command actually printed, not this one, if they differ -- the floor tracks the suite, not this document.

- [ ] **Step 6: Raise the floor to exactly that number**

In `tools/run_tests.sh`, replace line 186:

```bash
MIN_TESTS="${FILLY_MIN_TESTS:-1412}"
```

with (substituting the count from Step 5 if it was not 1420):

```bash
MIN_TESTS="${FILLY_MIN_TESTS:-1420}"
```

- [ ] **Step 7: Prove the floor both ways**

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh > /tmp/r0-floor-high.log 2>&1; echo "high rc=$?"
FILLY_MIN_TESTS=1 bash tools/run_tests.sh > /tmp/r0-floor-low.log 2>&1; echo "low rc=$?"
tail -3 /tmp/r0-floor-high.log
```

Expected: `high rc=1` and `low rc=0`, with the high run's tail reading

```
ERROR: GUT ran 1420 tests, below this suite's floor of 99999 -- tests have gone missing. Failing regardless of GUT's own exit code (0).
  If tests were deliberately removed, lower MIN_TESTS in tools/run_tests.sh in the same commit and say why.
```

A floor that only ever passes is not a floor; both directions are run because the committed value is the one nobody exercises.

- [ ] **Step 8: Fix the stale floor number in the docs**

`docs/testing.md:272` still says the floor is 299, which it has not been for two phases. Replace

```
`tools/run_tests.sh` — currently **299** — is a deliberate FLOOR rather than an
```

with (using the Step 5 number)

```
`tools/run_tests.sh` — currently **1420** — is a deliberate FLOOR rather than an
```

Leave the em dashes on that line exactly as they are: they are pre-existing prose in a file this slice is not rewriting, and changing them is a diff nobody asked for. Nothing this plan ADDS may contain one.

- [ ] **Step 9: Final confirmation run**

```bash
bash tools/run_tests.sh
bash tools/prove_save_safety.sh
bash tools/prove_save_safety.sh --negative-control
bash tools/prove_atomic_save.sh
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/sound_test.tscn
FILLY_TEST_SAVE_DIR="$(mktemp -d)" tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/story_test.tscn
```

Expected, all exit 0: `---- All tests passed! ----`; `SAVE_SAFETY_PROOF_OK`; `SAVE_SAFETY_PROOF_NEGATIVE_CONTROL_OK`; `ATOMIC_SAVE_PROOF_OK` (it sets `SaveIO.save_dir` to `user://atomic_write_proof` itself, so the redirect must not have disturbed it); `SOUND_OK ids=37`; `STORY_OK checks=55`.

- [ ] **Step 10: Commit**

```bash
git add tools/prove_save_safety.sh tools/run_tests.sh docs/testing.md
git commit -m "test: prove a gate boot leaves the live saves untouched"
```

---

## Self-Review

Run against spec section 3 and the task brief after the plan was written.

**Spec coverage.** Section 3 asks for four things. "A single test-mode switch (env var `FILLY_TEST_SAVE_DIR`)" -- Task 1 Steps 3-4. "That every gate and test boot uses" -- Task 2 Steps 1, 4, 7. "Plus a gate assertion that a sweep leaves `user://saves` byte-identical" -- Task 2 Step 5 (the sound gate's two checks) and Task 3 Steps 1-3 (the byte-identical manifest across a hosted-ranch gate boot, which is where the spec's word "sweep" actually bites, since the sound gate hosts nothing). "This is the only `game/systems/` change in the phase" -- Global Constraints, and only `save_io.gd` and `settings.gd` appear in the file table. Section 2's binding constraints: `MIN_TESTS` never decreases (Task 3 Step 6 raises it), every existing gate keeps passing (Task 3 Step 9), no em dashes in anything added.

**Task brief coverage.** Pure resolver unit-testable without a process restart: `resolve_save_dir`, four policy tests plus a wiring test. One read at class initialization via `static func _static_init()`: Task 1 Step 4, and Settings deliberately reads `SaveIO.session_save_dir` rather than the environment a second time, so "exactly once" is literally true. `mktemp -d` export from `run_tests.sh`: Task 2 Step 1. Exact edited command lines for docs: Task 2 Step 7 lists all thirteen verbatim. Negative control sandboxed with `XDG_DATA_HOME`: Task 3 Step 1, and the positive run is sandboxed the same way, which costs nothing and removes the last path by which this plan could write the owner's saves. Settings redirect done with the same tiny pattern rather than parked.

**Placeholder scan.** No TBD, no "add appropriate handling", no "similar to Task N". Every code step carries the literal text to write; every run step carries the command and the expected output. The one number this plan cannot know in advance is the suite's exact test count, and Task 3 Step 5 measures it rather than guessing, with 1420 stated as the expectation and the measured value declared authoritative.

**Type consistency.** `resolve_save_dir(env_value: String) -> String`, `session_save_dir: String`, `save_dir: String`, `TEST_SAVE_DIR_ENV: String` are spelled identically in Task 1's implementation, Task 1's tests, Task 2's `sound_test.gd` edit and Task 3's script. `resolve_settings_path(save_directory: String) -> String` and `settings_path: String` likewise. `load_from`/`save_to` keep their names and their return types (`void`, `bool`); only the default argument changes, from `PATH` to `""`, and both existing call sites (`ranch.gd:2012`, `ranch.gd:2257`) pass no argument, while both test call sites (`test_settings.gd`) pass an explicit path -- so every caller keeps working unchanged.

**One risk worth naming for the implementer.** This plan assumes Godot runs a script's `_static_init()` when the class is first loaded, including when it is loaded because another script referenced its `class_name` (which is how `settings.gd` reaches `SaveIO.session_save_dir`). Task 1 Step 11's wiring tests fail loudly if that ordering does not hold, and Task 3 Step 3's proof fails if it does not hold in a gate boot, so the assumption is checked twice before anything is called done. If it turns out not to hold, the fallback is one line: give `Settings._static_init()` its own `SaveIO.resolve_save_dir(OS.get_environment(SaveIO.TEST_SAVE_DIR_ENV))` call, which costs a second read of the environment and nothing else.
