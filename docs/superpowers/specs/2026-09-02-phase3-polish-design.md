# Filly Rancher, Phase 3: The Polish Slice

**Date:** 2026-09-02
**Status:** Design for review, pre-implementation
**Scope:** One slice. Turn the four casino games into real drawn games instead of text rows; get the floating text out of the world; give the ranch a look that is not "default Godot cube on default Godot grass"; and put one shared chrome over every menu so the non casino panels come along for free.
**Does not touch:** the dressing slice (`docs/superpowers/plans/2026-09-01-phase3-dressing.md`), which owns `game/world/props.gd`, `game/assets/converted/` and the conversion tooling. Nothing in this document edits those files.

## The directive this is held to

The owner, 2026-09-01:

> "i want a good polish update. I want the UI to be good. If theres not actual casino games in the UI i dont want it no text only bs. The floating text in game looks bad and graphics are lacking. I want strong polish and make the game actually look good rather than roblox"

And earlier, in the same vein:

> "casino is basically unusable its so unuser friedly"
> "the note on the casino looks very poor"
> "i feel all text menus are very confusing and not user friendly/polished"

Register, standing for every slice in this phase: Slime Rancher for the ranching feel, Stardew Valley for the town and the forever loop, light gambling for fun, a dark humour register that is funny the way an HR poster is funny. Cute, never grim.

There are no 2D art assets in this project and this slice does not acquire any. Everything below is drawn in code: `Control._draw()` through Godot's `draw_*` calls, `StyleBoxFlat`, `Tween`, gradients, arcs and polygons. Done well, that is enough; done lazily it is exactly the look the owner is complaining about, so the shared drawing kit in section A.1 is the first task and everything else spends it.

---

## Global Constraints

These bind every task in the slice. They are not negotiable by a planner or an implementer.

- **The menus draw and emit; `game/world/ranch.gd` transacts and owns pause.** `game/ui/table_menu.gd`'s class comment states it: "Nothing under `game/ui/` may touch `Economy`, `Casino` or `GameState`, so a table is handed `chips_provider` and `can_open` and hands back one request signal." That survives this slice intact. A stage may be TOLD an outcome; it may never compute one. Every new value a stage needs arrives through a `Callable` provider set by `ranch.gd` or through a push method `ranch.gd` calls, never through a lookup.
- **No rigging the casino.** `game/systems/slots.gd`, `game/systems/wheel.gd`, `game/systems/blackjack.gd` and `game/systems/race_card.gd` keep their outcomes, their `payout()` contracts (chips handed back, THE STAKE INCLUDED, 0 for a loss), their `house_edge()` derivations and their published wording. `Slots.STRIP_COUNTS`, `Slots.TRIPLE_PAYS`, `Wheel.NUMBER_PAYS_TO_ONE`, `Wheel.COLOUR_PAYS_TO_ONE`, `Blackjack.PUBLISHED_EDGE` and `RaceCard.TAKEOUT` do not move. No `RandomNumberGenerator` may be constructed anywhere under `game/ui/`. Animation timings are constants, never rolled.
- **Input parity.** Keyboard and gamepad must fully drive every screen. The existing model is the model: a `_selected` cursor moved by `ui_up`/`ui_down`, tabs on `ui_left`/`ui_right`, `ui_accept` to confirm, `ui_cancel` to leave, all read in each menu's own `_unhandled_input()`. No `Button` nodes, no `grab_focus()`, no engine focus chain, no mouse only affordance anywhere. A drawn control is focusable only if the cursor can reach it.
- **The headless gates stay green.** `game/world/ranch.gd` prints `RANCH_OK ponies=<n> props=<n> assets=<state>` or `RANCH_FAILED` and that marker is what CI asserts on (`docs/ci.md` section 1). `game/scenes/test/casino_test.gd` is the casino gate. Nothing in this slice may add a node that needs a GPU to exist, and every stage must instantiate and refresh in a headless run without drawing.
- **NO PONY EVER DIES.** Only `Pony._state_leaving` may call `queue_free()` on a pony. Nothing here frees, harms, moves or removes one. The race still runs `RaceRunner` stand ins and the entrant's pen body is still only hidden, exactly as `Ranch.start_race()` documents.
- **The census is untouched.** `ponies=` counts `spawner.get_spawned()`; `props=` is `Props.expected_count()` plus `$Buildings`'s child count. This slice adds nothing under `$Props` and nothing under `$Buildings`. The one node it replaces, `Buildings/Palace/Sign`, is a child of an existing building and does not move either number; see section B.1.
- **Preload by `res://` path, never by the global `class_name`.** Every construction, static call and constant read goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear only as a type annotation.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path. Every `Dictionary` read (`entry["odds"]`, `entry.get("coat", ...)`) needs one.
- **Every new `.gd` gets its `.uid` sidecar committed.** Run the editor import pass once after creating a script and `git add` the generated `game/**/*.gd.uid`.
- **No em dash and no double hyphen in any player facing string, nor in new code, comments or docs.** Use ";" or ":" or commas. The files being edited are full of pre existing occurrences in their own comments; leave those alone and do not copy the habit.

---

# Part 1: Survey

Everything below was read on `master` at `618126d`.

## 1.1 Every piece of floating and 3D text in the game

There are exactly **four Label3D sites, at three places**. There is no other billboarded or floating text mechanism: a sweep for `Label3D`, `Sprite3D`, `billboard` and `SubViewport` across `game/` finds these four, plus `game/ui/creation_screen.tscn`'s `SubViewport`, which is a 3D turntable inside a 2D panel and carries no text.

**1. `Buildings/Palace/Sign`, a `Label3D` authored in `game/world/ranch.tscn` line 168.**

```
[node name="Sign" type="Label3D" parent="Buildings/Palace"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.1, -4.1)
pixel_size = 0.0032
font_size = 48
outline_size = 6
modulate = Color(1, 0.94, 0.74, 1)
shaded = false
billboard = 0
```

Its text is written at runtime by `Ranch._build_world()`, `game/world/ranch.gd` line 846:

```gdscript
var lobby_sign := get_node_or_null(^"Buildings/Palace/Sign") as Label3D
if lobby_sign != null:
    lobby_sign.text = "\n".join(CasinoSignScript.lines())
```

`CasinoSign.lines()` returns **eleven lines**: the headline, the sponsor, two lines of preamble, four published house edge lines built by `edge_line()`, two lines about the blackjack placard, and "Please gamble responsibly. Your ponies are counting on you!". So this is an eleven line paragraph of unbacked text hanging in the air 2.1 m up and 4.1 m out from the Palace's local origin, at `pixel_size` 0.0032 with `font_size` 48, which is a cap height of about 0.15 m per line, roughly 1.7 m of text stack. This is the thing the owner called "the note on the casino looks very poor". It is the single worst offender in the game.

`game/scenes/test/casino_test.gd` lines 262 to 277 assert on this node: that it exists, that its `.text` contains `CasinoSign.edge_line()` for all four games, that no line carries a dash, and it prints `CASINO sign lines=<n>`.

**2 and 3. `MarqueeHeadline` and `MarqueeSponsor`, two `Label3D`s built by `Strip._marquee_label()`, `game/world/strip.gd` lines 318 to 339.**

These are the outdoor marquee on the Palace's front wall and they have already been through one repair pass (2026-08-31). They are BACKED: `Strip._marquee()` builds a `MarqueeBoard` `BoxMesh` in `MARQUEE_BOARD_COLOR` `Color(0.16, 0.07, 0.20)` and a `MarqueeTrim` box in `MARQUEE_TRIM_COLOR` `Color(0.98, 0.86, 0.45)` behind them, sized from the Palace's own `width`, `ridge_height` and front face via `mount_marquee()`. The text is FITTED: `label.width = _marquee_size.x / pixel` with `AUTOWRAP_WORD`, `MARQUEE_HEADLINE_FRACTION` 0.34 of the board height for "Spectra Palace" and `MARQUEE_SPONSOR_SCALE` 0.55 of that for "proudly sponsored by Cloudsdale Weather Corporation". `billboard = BILLBOARD_DISABLED`, yaw set from `_marquee_facing` so it faces the walk up to the door.

This one is basically right already. It is a sign, on a board, at a readable size. `game/test/test_strip.gd` lines 117 and 178 pin it.

**Note: `casino_sign.gd` does not draw text into a texture.** It is a static, stateless `RefCounted` returning `Array[String]` and `String`; every one of its consumers is either a `Label3D` (`ranch.gd`), two `Label3D`s (`strip.gd`) or a `Label` row in `CasinoMenu` (through the `sign_provider` `Callable`). Nothing rasterises anything.

**4. `Nameplate`, a `Label3D` built per lane by `RaceRunner._ensure_plate()`, `game/world/race_runner.gd` lines 106 to 117.**

`font_size` 48, `pixel_size = NAMEPLATE_SIZE / 48.0` with `NAMEPLATE_SIZE` 0.28, hung at `NAMEPLATE_HEIGHT` 2.5 m, `billboard = BILLBOARD_ENABLED`, `outline_size` 8. Six of them, one per lane, carrying the runner's display name. Its own comment gives the reason: "so the player can tell six recoloured ponies apart from the rail". `game/test/test_race_runner.gd` line 58 excludes `Label3D` when counting a runner's model children.

**The HUD prompt and the tutorial checklist are NOT floating text and are not in scope for section B.** `game/ui/hud.gd` owns `$Prompt` (a `Label`, styled at size 26 in `COLOR_PROMPT`, the "E: Market, sell gems" line under the reticle, written by `Interaction.prompt_for()`), `$Toast`, `$Tasks` (the tutorial checklist, fed by `RequestBoard.tutorial_rows()`) and `$Hints`. All of them are 2D `Control`s on a `CanvasLayer`. They are drawn over the world, not in it; they do not scale with distance, do not billboard and do not intersect geometry. They are covered by section D's chrome pass, not by section B.

## 1.2 The casino UI architecture

**The shape.** Six `CanvasLayer` menus, all instanced into `game/world/ranch.tscn` at lines 330 to 338 and all held by `@onready` vars in `ranch.gd` lines 440 to 445: `CasinoMenu`, `SlotsMenu`, `WheelMenu`, `BlackjackMenu`, `RaceMenu`. Every one of them is a text panel.

**`game/ui/table_menu.gd` (256 lines), `class_name TableMenu extends CanvasLayer`,** is the shared base for the three tables. `SlotsMenu`, `WheelMenu` and `BlackjackMenu` all `extends "res://ui/table_menu.gd"` by path, never by `class_name`, "for the reason every preload in this project is by path: the class cache lives in the gitignored `game/.godot/`".

The scene tree every table's `.tscn` has, verified identical in `slots_menu.tscn`, `wheel_menu.tscn` and `blackjack_menu.tscn`:

```
CanvasLayer (layer 2, process_mode 3 = PROCESS_MODE_ALWAYS)
  Dim            ColorRect, full rect, Color(0, 0, 0, 0.42), mouse_filter 2
  Centre         CenterContainer, full rect
    Panel        PanelContainer, custom_minimum_size Vector2(860, 0),
                 theme_override_styles/panel = StyleBoxFlat "MenuPanel"
      Margin     MarginContainer, 30 / 24 / 30 / 22
        Column   VBoxContainer, separation 10
          Title  Label
          Tabs   Label
          Rows   VBoxContainer, separation 8
          Footer Label
```

The `MenuPanel` `StyleBoxFlat` is **copied verbatim into every menu `.tscn`**: `bg_color = Color(0.0392157, 0.0470588, 0.0784314, 0.88)`, 1 px border in `Color(1, 0.858824, 0.552941, 0.32)`, all four corner radii 12, all four content margins 0.

**How they render today.** `TableMenu.refresh()` is the whole of it:

```gdscript
func refresh() -> void:
    if not is_node_ready():
        return
    _footer.text = MenuStyleScript.footer_tabs_and_rows("confirm", "leave")
    MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
    _title.text = title_text()
    _tabs.text = tabs_text()
    for child in _rows.get_children():
        child.queue_free()
    var lines: Array[String] = drawn_lines()
    var caret: int = _selected + first_row_line_index()
    for i in lines.size():
        var label := Label.new()
        var picked: bool = i == caret and row_count() > 0
        label.text = MenuStyleScript.caret(picked) + lines[i]
        label.add_theme_color_override("font_color",
            MenuStyleScript.COLOR_VALUE if picked else MenuStyleScript.COLOR_NAME)
        _rows.add_child(label)
```

Every row is a plain `Label`. The only selection treatment is a two character `"> "` caret (`MenuStyle.CARET`) and a colour swap from `COLOR_NAME` to `COLOR_VALUE`. There is no panel behind a row, no highlight, no icon, no geometry of any kind anywhere in the casino.

**The four virtuals a table fills in:** `title_text()`, `tabs_text()`, `drawn_lines() -> Array[String]`, `row_count() -> int`, `first_row_line_index() -> int`, `confirm() -> bool`, `switch_tab(step: int)`. Plus the shared machinery: `STAKES: Array[int] = [10, 50, 200]` ("Even numbers, always: `Blackjack.payout()` pays three to two with integer division"), `stakes()` cut to what `chips_provider` says she is holding, `selected_stake()`, `stake_lines()`, `chips_line()`, `keys_line()`, `show_result(lines)` and `result_block()`.

`first_row_line_index()` exists because `_selected` counts SELECTABLE rows while `drawn_lines()` counts PRINTED lines, and every table prints the last result above its rows. `game/test/test_table_caret.gd` pins it by walking the actual `Label` nodes.

**What each table draws today:**

- **`slots_menu.gd` (63 lines).** `drawn_lines()` returns `chips_line()`, `keys_line()`, `result_block()`, `stake_lines()`, `"Spin for %d chips"`, a blank, then all eight lines of `Slots.paytable_lines()`. Selectable rows are the stakes only. Signal: `spin_requested(stake: int)`.
- **`wheel_menu.gd` (160 lines).** Two tabs, `Tab.COLOUR` and `Tab.NUMBER`. On COLOUR it prints six "Back Red at 5 to 1" lines; on NUMBER, twenty four "Back 7, Yellow at 23 to 1" lines. Then `stake_lines()` immediately after (no blank, deliberately), then a blank, then `Wheel.rules_lines()`. `row_count()` is `guess_count() + 1`: the guesses plus one cursor position past the last of them, which is the stake row, where `switch_tab()` moves the stake instead of the tab. `_guess_row` tracks the last actually highlighted guess separately from `_selected`. Signal: `bet_requested(kind: int, guess: int, stake: int)`, carrying the menu's own `Tab` value, which `ranch.gd._on_wheel_bet_requested()` translates into a `Wheel.Bet` value.
- **`blackjack_menu.gd` (86 lines).** Two tabs, `Tab.TABLE` and `Tab.PLACARD`. TABLE prints `chips_line()`, `keys_line()`, `result_block()`, `stake_lines()`, `"Deal for %d chips"`. PLACARD prints `Blackjack.placard_lines()` and is unselectable. Signal: `deal_requested(stake: int)`. Its class comment is explicit that there is no hit or stand decision at this table: "The house strategy card is what the player is playing".
- **`race_menu.gd` (178 lines).** Two tabs, `Tab.ENTER` (the form guide) and `Tab.CARD`. The form guide prints one line per pony from `form_lines()`: `"%s pays %s, spirits %d of 10"`. Odds are PUSHED IN, not computed: `entrants_provider` is a `Callable` set by `ranch.gd` returning `Array[Dictionary]` of `{"uid", "name", "happiness", "odds", "chance"}`. Signal: `race_requested(uid: StringName, stake: int)`.
- **`casino_menu.gd` (269 lines).** Not a `TableMenu`; it is its own `CanvasLayer` with the same tree and the same `refresh()` shape. Three tabs (`Tab.LOBBY`, `Tab.CAGE`, `Tab.RULES`), six lobby rows (`Row.CAGE`, `SLOTS`, `WHEEL`, `BLACKJACK`, `RACING`, `RULES`) whose text is `LOBBY_ROWS`, six strings of the form `"Slots: three reels, one lever, the fast one"`. `CAGE_STEPS: Array[int] = [100, 500, 2000, 10000]`, cut to what she holds by `_steps_within()`. Signals: `buy_chips_requested(bits)`, `cash_out_requested(chips)`, `room_requested(row)`. Providers: `can_open`, `bits_provider`, `chips_provider`, `sign_provider`.

**The boundary toward `ranch.gd`, which is binding and must survive.** `Ranch._bind_casino_menus()` (line 1538) sets every provider and connects every signal. The transaction functions are `buy_chips()`, `cash_out()`, `play_slots()`, `play_wheel()`, `play_blackjack()` and `start_race()`. Each one has the same shape and the same safety order, stated in `play_slots()`'s comment: "THE STAKE COMES OUT BEFORE THE REELS ARE ROLLED, always". Each ends by pushing a result back through `show_result()` and calling `_refresh_casino_menus()`, which calls `refresh()` on all five menus.

Each transaction ALSO already returns the full outcome as a `Dictionary` for the gates: `play_slots()` returns `{"ok", "reels": Array[int], "won", "stake"}`, `play_wheel()` returns `{"ok", "pocket", "won", "stake"}`, `play_blackjack()` returns `{"ok", "hand": Dictionary, "won", "stake"}` where `hand` is `{"player": Array[int], "dealer": Array[int], "outcome": int}`. **The animation layer needs exactly this data and it already exists**; section A.3 says how it reaches the stage without moving a single line of logic.

`_open_table()` closes the lobby before opening a table, "so `_no_menu_but()` is true by the time the table asks it: two open menus is the state that leaves the world unpaused under the one still on screen". `_on_menu_opened()`/`_on_menu_closed()` are the one place `get_tree().paused` and the mouse cursor are toggled. None of that moves.

**Two defects found while surveying, both worth fixing in this slice:**

- **`WheelMenu.WHEEL_FOOTER` is dead code that would violate the footer contract if it ran.** `WheelMenu._ready()` sets `_footer.text = WHEEL_FOOTER` after `super._ready()`, but `TableMenu.refresh()` overwrites `_footer.text` with `MenuStyle.footer_tabs_and_rows()` on every call, and `open()` calls `refresh()`. So the player has never seen it. Worse, the string hard codes `"Enter / A  confirm      Esc / B  leave"`, showing both input schemes at once, which is precisely what `MenuStyle.footer()` exists to prevent ("ONE SCHEME, NEVER BOTH"). The consequence is that the wheel's own class comment promises "The footer says so" about the stake sitting on the last row, and the footer does not say so, because the line that said it never renders.
- **Four `MenuStyle` constants are declared and nothing uses them.** `ROW_SELECTED_BG`, `ROW_SELECTED_BORDER`, `ROW_IDLE_BG` and `ROW_IDLE_BORDER` are the row treatment the style file already intends; no menu draws them, because rows are bare `Label`s. Making them real is the highest value single change in section D and it is already specified in the code.

## 1.3 The graphics stack

**The Environment** lives as a `sub_resource type="Environment" id="Env"` inside `game/world/ranch.tscn` (lines 40 to 52), on a `WorldEnvironment` node at line 57. In full:

```
background_mode = 2                              (BG_SKY)
sky = Sky -> ProceduralSkyMaterial
ambient_light_source = 3                         (AMBIENT_SOURCE_SKY)
ambient_light_color = Color(0.729412, 0.803922, 0.878431, 1)
ambient_light_sky_contribution = 0.35
ambient_light_energy = 0.32
tonemap_mode = 3                                 (TONE_MAPPER_ACES)
tonemap_white = 3.0
fog_enabled = true
fog_light_color = Color(0.741176, 0.803922, 0.858824, 1)
fog_density = 0.0011
fog_sky_affect = 0.35
```

**What is OFF:** glow, SSAO, SSIL, SDFGI, volumetric fog, screen space reflections, and the whole `adjustment_*` colour grading block. Every one of them is at its engine default of disabled. `tonemap_white` at 3.0 is high enough that nothing on this map ever reaches the shoulder of the curve, so ACES is currently doing little except desaturating the midtones slightly.

**The `ProceduralSkyMaterial`** (lines 28 to 35): `sky_top_color` `Color(0.31, 0.51, 0.76)`, `sky_horizon_color` `Color(0.72, 0.80, 0.87)`, `sky_curve` 0.18, `ground_bottom_color` `Color(0.22, 0.29, 0.20)`, `ground_horizon_color` `Color(0.42, 0.53, 0.35)`, `sun_angle_max` 12.0, `sun_curve` 0.08.

**The sun** is `$Sun`, a `DirectionalLight3D` at line 60: `light_color = Color(1, 0.968627, 0.905882, 1)`, `light_energy = 1.15`, `shadow_enabled = true`, `shadow_bias = 0.05`, `directional_shadow_max_distance = 240.0`. Everything else is at default, which means: `directional_shadow_mode` is the 4 split PSSM, `shadow_blur` is 1.0, `light_angular_distance` is 0.0 (perfectly hard shadow edges, no penumbra), `shadow_normal_bias` is 1.0, `directional_shadow_blend_splits` is off, `directional_shadow_fade_start` is 0.8.

**240 m of shadow distance over four splits on a 220 m map is the shadow problem.** The map is `Terrain.HALF` 110.0, so 220 m square. A 4096 atlas split four ways across 240 m gives roughly 240 / 4096 metres per texel in the far cascade and even the near cascade is being asked to cover far more ground than the player can see detail in. Combined with `light_angular_distance` 0.0, every shadow in the game is a hard aliased edge, which is a strong part of the "roblox" read.

**`game/world/sky_rig.gd` (772 lines) is the only thing that turns the clock into photons** and it is genuinely good. It is a pure static mapping plus a scene writer. `_write_to_scene()` drives, per `(phase, weather)`: `Sun.rotation_degrees`, `light_energy`, `light_color`, the Environment's `ambient_light_energy`, `ambient_light_color`, `fog_density` and `fog_light_color`, and all four `ProceduralSkyMaterial` colours (`sky_top_color`, `sky_horizon_color`, `ground_horizon_color`, `ground_bottom_color`). Four phases (`DAWN`, `DAY`, `DUSK`, `NIGHT`) crossed with four weathers (`CLEAR`, `RAIN`, `FOG`, `STORM`). Transitions ramp over `TRANSITION_SECONDS` 8.0 with a smoothstep. **The fog is already colour matched to the sky per phase**: `_environment.fog_light_color = horizon`, where `horizon` is `sky_horizon(phase, weather)`. So section C does not need to invent that; it needs to extend the same discipline to the two or three Environment fields the rig does not yet drive.

`AMBIENT_SKY_CONTRIBUTION` 0.35 and `AMBIENT_SOURCE_SKY` are written by the rig on its first successful write and pinned there rather than trusted to whoever saved the scene. `PHASE_LIGHT_ENERGY` is `[0.62, 1.15, 0.58, 0.38]` and `PHASE_AMBIENT_ENERGY` is `[0.24, 0.32, 0.22, 0.70]`, with `NIGHT_WEATHER_FLOOR` 0.7 so a stormy night stays playable. `game/test/test_sky_rig.gd` asserts orderings on these; any change to the rig has to keep them.

**The terrain** is `game/world/terrain.gd` (355 lines), a `StaticBody3D` building one `ArrayMesh`: `HALF` 110.0, `CELL` 2.0, so a 110 by 110 quad grid, 24,200 triangles, 12,321 vertices. `FLAT_RADIUS` 30.0 with `BLEND_RADIUS` 44.0 gives a dead flat homestead apron. Its material, `_build_mesh()` lines 316 to 327:

```gdscript
var mat := StandardMaterial3D.new()
mat.albedo_color = Color.WHITE
mat.vertex_color_use_as_albedo = true
mat.vertex_color_is_srgb = true
mat.roughness = 0.95
mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
```

Colour comes entirely from per vertex `grass_at(x, z)`, which lerps `GRASS_LOW` `Color(0.239, 0.408, 0.196)` to `GRASS_HIGH` `Color(0.443, 0.541, 0.271)` by a tone built from the unflattened relief plus `sin(x * 0.31) * cos(z * 0.27) * 0.11` plus `sin((x - z) * 0.13 + 2.1) * 0.07`, then, inside a region, lerps that toward the region's own `grass_low`/`grass_high` by `region.weight_at(point)`. UVs are `Vector2(x, z) * 0.25`, one tile per 4 m, and the comment says they exist "so a future grass texture repeats at a believable size". Nothing samples them today.

**So the ground is not one flat colour; it is a smooth gradient between two greens at 2 m resolution.** That is subtly worse than one flat colour for the "roblox" read, because it is smooth and featureless at every scale the player actually sees. There is no texture, no high frequency break up, no slope treatment, no dirt anywhere. This is the biggest single visual tell on the map and section C.4 is about it.

**Buildings.** `game/world/building.gd` (445 lines) builds every building out of `BoxMesh` slabs. Its one material function, line 411:

```gdscript
func _material(colour: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = colour
    mat.roughness = 0.9
    mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
```

Every surface of every building: one roughness, no specular, no metallic, no variation. The six buildings in `ranch.tscn` carry `wall_color`, `roof_color` and `trim_color` exports; the Palace's are `Color(0.36, 0.16, 0.42)` purple, `Color(0.95, 0.78, 0.28)` gold roof and `Color(0.98, 0.86, 0.45)` gold trim. `game/world/pen.gd` line 981 and `game/world/race_track.gd` line 216 have the identical function at roughness 0.92 and 0.85. `game/world/strip.gd._flat_material()` is the same at 0.85. Nothing in the world has a specular highlight; the gold trim on a casino cannot glint.

**Renderer:** `game/project.godot` sets `renderer/rendering_method = "forward_plus"` and `config/features` includes `"Forward Plus"`, so SSAO, SSIL, soft shadows and glow are all available. The window is 1600 by 900 over a 1920 by 1080 base viewport with `window/stretch/mode = "canvas_items"` and `aspect = "expand"`; every 2D size in this project is in 1920 by 1080 base pixels.

## 1.4 What UI drawing capability already exists

- **Custom `_draw()` is already in use, in exactly one file, and the pattern is good.** `game/ui/hud.gd` line 237: `_crosshair.draw.connect(_draw_crosshair)` and `_pips.draw.connect(_draw_pips)`, where `$Crosshair` and `$Bag/Pips` are bare `Control` nodes in `hud.tscn`, redrawn by `queue_redraw()`. The drawing itself uses `draw_arc`, `draw_line`, `draw_circle` and `draw_rect`, always in an outline pass followed by a colour pass ("so the reticle stays visible over a bright sky as well as over grass"). The two rings of the capture meter, drawn in opposite directions so they are distinguishable in motion by a player who cannot separate them by hue, are the standard this slice's drawing should be held to.
- **`game/ui/mark_canvas.gd` (169 lines)** is a second precedent: a paintable cutie mark canvas backed by an `Image`.
- **There are no 2D art assets.** `game/assets/` holds `converted/ponies/` (glTF plus PNG skins, gitignored), `audio/voice/twilight/greeting_01.wav`, and nothing else. No sprites, no icons, no nine patches, no atlases.
- **There is no font asset and no `Theme` resource anywhere.** Every `Label` in the game renders in Godot's built in default font. Type hierarchy today is three sizes only: `MenuStyle.TITLE_SIZE` 30, `ROW_SIZE` 22, `FOOTER_SIZE` 20, plus the HUD's own 26 and 40.
- **`game/ui/menu_style.gd` (118 lines)** is the shared style file: eleven colour constants, three sizes, `CARET`/`NO_CARET`, `OUTLINE_COLOR` `Color(0, 0, 0, 0.75)` at `OUTLINE_SIZE` 5, `style_label()`, `caret()`, `tab_strip()`, `footer()`, `footer_tabs_and_rows()`, `footer_rows()`, `footer_reading()`. It changes no menu's logic; it is a palette and a footer builder. `game/systems/input_device.gd` supplies the glyphs through `hint()`, including the two composites `&"menu_rows"` ("Up Down" / "D-pad up down") and `&"menu_tabs"`.

---

# Part 2: Design

## A. Visual casino games

### A.1 The shared drawing kit: `game/ui/casino_paint.gd`

**New file, `class_name CasinoPaint extends RefCounted`, static only, no state, no scene, preloaded by path.** It is `menu_style.gd`'s sibling: `menu_style.gd` owns the panel chrome every menu shares, `casino_paint.gd` owns the casino's own vocabulary. This file is task 1 and everything else spends it.

**The palette,** derived from the Palace's own colours in `ranch.tscn` so the building and its interior agree:

```gdscript
const FELT       := Color(0.09, 0.32, 0.20)      ## table green
const FELT_DARK  := Color(0.05, 0.20, 0.13)      ## the vignette at the felt's rim
const FELT_LINE  := Color(1.00, 0.94, 0.72, 0.22) ## the hairline betting lines on the felt
const PLUM       := Color(0.36, 0.16, 0.42)      ## Palace wall_color, the cabinet body
const PLUM_DARK  := Color(0.22, 0.09, 0.27)
const GOLD       := Color(0.98, 0.86, 0.45)      ## Palace trim_color
const GOLD_DIM   := Color(0.62, 0.53, 0.28)
const CARD_FACE  := Color(0.97, 0.96, 0.93)
const CARD_RED   := Color(0.78, 0.16, 0.20)
const CARD_INK   := Color(0.11, 0.10, 0.14)
const CHIP_COLORS: Array[Color] = [ ... ]        ## one per TableMenu.STAKES entry
const BAND_COLORS: Array[Color] = [ ... ]        ## six, rainbow order, indexed by Wheel.Colour
```

`BAND_COLORS` is indexed by `Wheel.Colour` (`RED`, `ORANGE`, `YELLOW`, `GREEN`, `BLUE`, `VIOLET`) and is the SAME six colours used for the wheel's bands, the race's six lanes and the slot machine's `RAINBOW` symbol. One rainbow, three places, so the building reads as one building.

**The primitives.** Every one takes the `CanvasItem` to paint onto as its first argument, the way `hud.gd`'s helpers take `_crosshair`:

- `rounded(ci, rect, radius, fill, border, border_width)`. Built on a cached `StyleBoxFlat` and `StyleBox.draw(ci.get_canvas_item(), rect)`, not on generated polygons: `StyleBoxFlat` already has per corner radii, a border, an anti aliased edge and a shadow, and drawing one onto an arbitrary `CanvasItem` is one call. This is the single most used function in the slice.
- `ellipse(ci, centre, rx, ry, fill, rim)`. A 28 point `draw_colored_polygon` plus a `draw_polyline` rim. Godot has `draw_circle` but no ellipse, and a chip seen at a slight angle is an ellipse.
- `chip(ci, centre, radius, colour, edge_marks)`. A casino chip: filled ellipse, an inset lighter ring at 0.68 radius, six white edge dashes, a `GOLD_DIM` rim. `edge_marks` off gives the flat token used at small sizes.
- `chip_stack(ci, base, count, colour, height_per_chip)`. `count` chips drawn bottom up with a 0.34 * `ry` vertical step, the top one full and the rest showing only their rim, so a stack reads as a stack. Caps at 8 drawn chips with a small "x N" in `GOLD` beside it past that.
- `plate(ci, rect, title, body)`. The gold trimmed reading plate that carries `Wheel.rules_lines()`, `Blackjack.placard_lines()` and the race card's paragraphs, so the two "reading matter" tabs stop being loose `Label`s.
- `text(ci, font, at, string, size, colour, align, max_width)`. `draw_string_outline` in `MenuStyle.OUTLINE_COLOR` at `MenuStyle.OUTLINE_SIZE` then `draw_string`, the same two pass discipline `hud.gd`'s `_ring()` uses and for the same reason.
- `focus_ring(ci, rect, radius, t)`. The one focus treatment in the whole casino: a 3 px `GOLD` rounded stroke, inset 2 px, with the alpha breathing between 0.72 and 1.0 on `t` (a phase the stage advances in `_process`). Every focusable thing on every screen gets this and nothing else does, so "where am I" is answered identically everywhere.

**The glyphs.** Each one is split in two, and this split is what makes the kit testable headlessly:

```gdscript
static func star_points(box: Rect2) -> PackedVector2Array
static func draw_star(ci: CanvasItem, box: Rect2, fill: Color) -> void
```

The `*_points()` half is pure geometry with no `CanvasItem` in sight, so `game/test/test_casino_paint.gd` can assert that every glyph's points sit inside the box it was handed, that a star has ten points, that a hexagon has six, and that no glyph is empty. The `draw_*` half is three lines feeding the points to `draw_colored_polygon`. Nothing about a drawn shape is unverifiable.

The glyph set, all drawn inside a normalised box so any of them can be swapped for any other:

- **Slot symbols, one per `Slots.Symbol`.** `APPLE`: a red circle, a green leaf triangle, a brown stem line. `HORSESHOE`: a gold arc of width 0.18 of the box opening downward, two square heels, four nail dots. `BELL`: a rounded trapezoid, a base bar, a clapper circle. `GEM`: a hexagon with two lighter facet triangles. `STAR`: a five point star. `RAINBOW`: six nested arcs in `BAND_COLORS`.
- **Card suits.** `HEART` (two circles plus a triangle), `DIAMOND` (a rotated square), `SPADE` (an inverted heart plus a stem trapezoid), `CLUB` (three circles plus a stem).
- **Room illustrations,** one per `CasinoMenu.Row`: `CAGE` (a teller arch with a chip stack), `SLOTS` (a cabinet with three symbol windows), `WHEEL` (a small segmented disc), `BLACKJACK` (three fanned cards), `RACING` (a rail, a finish post and a running silhouette made of three rounded rects), `RULES` (a framed board). Each takes a `Rect2` and works at 60 px on a lobby tile and at 300 px as a table's own headboard, so the picker and the room agree with each other by construction.
- **Wallet icons:** `bit` (a small gold coin with a notch) and `chip`.

**Deliberately out of scope for the kit:** anything needing a texture, a shader, a `Gradient` resource on disk, a nine patch or an atlas. If it cannot be a polygon, an arc, a `StyleBoxFlat` or a string, it is not in this slice.

### A.2 The stage: how a drawn game hangs off `table_menu.gd`

The rule is that **`drawn_lines()` survives unchanged on every menu**. It is the semantic model of the screen and six test files plus `game/test/test_published_payouts.gd` read it. `test_published_payouts.gd` in particular parses the price back out of the English of `Slots.paytable_lines()`, `Wheel.rules_lines()`, `Blackjack.placard_lines()` and `RaceCard.odds_text()` and applies it to a stake; that guard is the reason no wall in the Palace can lie, and it must keep working. So the drawing is added BESIDE the text model, not instead of it.

**Scene change, applied identically to `slots_menu.tscn`, `wheel_menu.tscn`, `blackjack_menu.tscn`, `race_menu.tscn` and `casino_menu.tscn`:** one new node, `Stage`, a bare `Control` with a `custom_minimum_size`, inserted in `Centre/Panel/Margin/Column` between `Tabs` and `Rows`. `Panel.custom_minimum_size` goes from `Vector2(860, 0)` to `Vector2(1180, 0)` on the three tables and the lobby, which fits inside the 1920 base width with a 370 px margin either side.

**Script change on `table_menu.gd`,** additive only:

```gdscript
@onready var _stage: Control = $Centre/Panel/Margin/Column/Stage

func _ready() -> void:
    ...
    if _stage != null:
        _stage.draw.connect(_paint_stage)

## What this table paints. Overridden by each table; the base paints nothing, which is
## the right answer for a table that has no stage yet.
func paint(_ci: Control) -> void:
    pass

## The lines the Rows VBox actually PRINTS. drawn_lines() stays the whole text model of the
## screen and is what the tests and the payout parser read; a table whose stage already
## shows a line overrides this to leave it out of the column, so the panel does not say
## the same thing twice.
func printed_lines() -> Array[String]:
    return drawn_lines()

## Where the focus ring was last actually painted, and what it was painted on. For the
## caret test, which must keep asking the DRAWING where the cursor is rather than asking
## the number; see game/test/test_table_caret.gd for the defect that rule exists for.
func focus_rect() -> Rect2
func focused_id() -> StringName
```

`refresh()` gains `_stage.queue_redraw()` and iterates `printed_lines()` instead of `drawn_lines()`; `first_row_line_index()` indexes into `printed_lines()`. Everything else in `refresh()` is untouched.

**Animation** is a `Tween` created per play through `create_tween()` on the menu node, which is `process_mode = 3` (`PROCESS_MODE_ALWAYS`) on every menu `.tscn`, so it runs while `get_tree().paused` is true. Each stage keeps a small number of `float` animation vars that `paint()` reads and the tween writes; `_process` calls `_stage.queue_redraw()` only while an animation is live, never otherwise, the same discipline `SkyRig._needs_ticks()` follows.

**While an animation is live, `confirm()` returns `false` and `move_selection()` is ignored, but `ui_cancel` still closes.** A player who wants out of a spinning reel gets out.

### A.3 How an outcome reaches the stage without moving a line of logic

Every transaction in `ranch.gd` already computes the whole outcome and already returns it. The one change is that where it currently calls `show_result(lines)` it ALSO calls a new push method with the structured outcome, in the same block, immediately after taking the chips and settling the win. Nothing about the order, the safety or the arithmetic moves.

```gdscript
# in Ranch.play_slots(), directly beside the existing show_result() call
if slots_menu != null and slots_menu.has_method("show_spin"):
    slots_menu.call("show_spin", reels, won, stake)
```

New push methods, one per table, each a plain setter plus a tween start:

- `SlotsMenu.show_spin(reels: Array[int], won: int, stake: int)`
- `WheelMenu.show_spin(pocket: int, won: int, stake: int)`
- `BlackjackMenu.show_hand(hand: Dictionary, won: int, stake: int)`
- `RaceMenu` needs none: the race is 3D and already has `race_settled`.

**This is the no rigging boundary held exactly where it already is.** The menu is told what happened by the only thing allowed to decide it. There is no path by which a stage can influence an outcome, because the outcome is a value that arrives after the chips have already moved. The `has_method()` guard is the same one `ranch.gd` already uses for `show_result()`, so a stage that has not been built yet is simply not told.

### A.4 Slots

**The screen.** A cabinet, drawn as a `rounded()` panel in `PLUM` with a 4 px `GOLD` trim and `PLUM_DARK` shadow, occupying the left 720 px of the stage; a paytable panel on the right 400 px.

- **Headboard.** "SPECTRA SLOTS" in the title font across the cabinet's top, on a `GOLD` strip, with a row of nine small `GOLD` bulbs above it whose alpha chases left to right on a 1.2 s loop. That chase is the only thing on the screen that moves while nothing is happening, which is what makes the cabinet read as a machine that is on.
- **Three reel windows.** Each 180 by 300, `rounded()` at radius 10, filled `Color(0.06, 0.05, 0.09)`, inset into the cabinet with a 3 px `GOLD_DIM` rim. Inside each, the real strip: `Slots.strip()`, sixteen positions built from `STRIP_COUNTS` `[5, 4, 3, 2, 1, 1]`, drawn as a vertical ribbon of 96 px symbol cells at the reel's current scroll offset, wrapped. Three cells are visible; the middle one is the payline. A top and bottom shade (`draw_rect` with a vertical alpha fade, two `draw_colored_polygon` gradients) makes the ribbon read as a cylinder rather than a list.
- **The payline** is a 2 px `GOLD_DIM` line across all three windows at all times, so the player knows which row counts before she spins.
- **The lever,** right of the cabinet: a rounded shaft plus a red ball, rotating 35 degrees down over 0.12 s when a spin starts and easing back over 0.35 s. Purely cosmetic; the spin is on `ui_accept`.
- **The stake,** below the cabinet: one drawn `chip()` per entry of `stakes()` in `CHIP_COLORS`, the picked one raised 8 px with a `focus_ring()`. The amount is drawn on the chip face.
- **The chip counter,** bottom right of the cabinet: the wallet chip icon plus a number that TWEENS from the old value to the new over 0.5 s on `TRANS_QUART, EASE_OUT` when a win lands. It reads `chips_provider`, which the menu already holds.
- **The paytable panel:** one row per `Slots.paytable_lines()` entry, each drawn as three small symbol glyphs at 34 px plus the multiplier in `GOLD`. The eight rows and their exact wording ("Apple Apple Apple returns 4 for 1", "Two Rainbows anywhere returns 5 for 1", "One Rainbow anywhere hands your stake back") are unchanged and are still what `drawn_lines()` returns, so `test_published_payouts.gd` keeps parsing the same strings.

**The spin, on `show_spin(reels, won, stake)`:**

1. Lever drops, 0.12 s.
2. All three reels accelerate over 0.15 s and then run at a constant 22 positions per second.
3. Reel `i` begins its landing at `0.60 + i * 0.35` seconds, so they settle left to right at 0.60, 0.95 and 1.30 s.
4. Each landing is a `TRANS_BACK, EASE_OUT` tween of 0.45 s onto the exact strip position of `reels[i]`, which overshoots by about one third of a symbol and settles back. That overshoot is what makes a reel feel like a physical object.
5. Total, 1.75 s. Nothing is rolled, nothing is chosen; the tween's target is the value `Slots.spin()` already produced.
6. If `won > 0`, the payline flashes: three alpha pulses over 0.6 s, `GOLD` for an ordinary win and cycling through `BAND_COLORS` for a triple `RAINBOW`. The chip counter ticks up over the same window.
7. If `won == 0`, nothing flashes. A loss is quiet; a machine that celebrates a loss is a machine that is lying.

**Input model: entirely unchanged.** `row_count()` stays `stakes().size()`, `move_selection()` still moves the stake index, `confirm()` still emits `spin_requested(selected_stake())`. `printed_lines()` returns `[chips_line(), keys_line()] + result_block()` only; the stake line, the "Spin for N chips" line and the eight paytable lines are all on the stage, so the column under it shrinks from about fifteen `Label`s to two or five.

### A.5 The Wheel

**The screen.** A wheel on the left 560 px, a betting felt on the right 580 px.

- **The wheel:** `Wheel.POCKETS` = 25 annular sectors between inner radius 78 and outer radius 236, each a `draw_colored_polygon` of 2 + 2 * 6 points. Pockets 1 to 24 run in six bands of `Wheel.COLOUR_RUN` = 4 in `BAND_COLORS`, in rainbow order, which is where the wheel gets its name. Pocket 0, `Wheel.HOUSE_POCKET`, is painted a pale cloud silver with a small drawn cloud glyph and no number, because no bet may name it. Each numbered sector carries its number at radius 165, rotated to sit along the sector. A `GOLD` hub disc at radius 70 with six spokes, and a `GOLD_DIM` outer rim.
- **The pointer:** a `GOLD` triangle at 12 o'clock. It ratchets: the stage tracks which pocket index is under the pointer and, each time that changes, kicks the pointer 8 degrees back and springs it home over 0.09 s. On a fast spin that is a visible flutter; as the wheel slows it becomes individual clicks, which is the entire reason a real wheel feels like it is slowing down.
- **The felt,** right side: a `FELT` `rounded()` panel with `FELT_LINE` hairlines.
  - On `Tab.COLOUR`: six pads in a 3 by 2 grid, each a `rounded()` rect in its `BAND_COLORS` colour carrying the colour's name from `Wheel.COLOUR_NAMES` and "pays 5 to 1" from `Wheel.COLOUR_PAYS_TO_ONE`.
  - On `Tab.NUMBER`: a 6 by 4 grid of 24 pads, each tinted by `Wheel.colour_of(pocket)` and carrying its number. "A number pays 23 to 1" (`Wheel.NUMBER_PAYS_TO_ONE`) is printed once above the grid rather than 24 times inside it.
  - The pad `_guess_row` names carries the `focus_ring()` and a drawn `chip_stack()` of the current stake sitting on it, so "my bet is on green" is a thing on the table rather than a caret next to a sentence.
- **The stake row** sits under the grid as drawn chips, exactly as on the slot machine, and is the cursor position past the last guess. **The input model is unchanged in every particular:** `row_count()` is still `guess_count() + 1`, `switch_tab()` still moves the stake on the last row and switches tabs everywhere else, `_guess_row` still tracks the last actually highlighted guess separately from `_selected`.
- `Wheel.rules_lines()` moves onto a `plate()` under the wheel. The four lines are unchanged.

**The spin, on `show_spin(pocket, won, stake)`:** the wheel rotates by a FIXED 5 full turns plus the angle that brings `pocket` under the pointer, over 3.2 s on `TRANS_CUBIC, EASE_OUT`, which is a friction curve. **The turn count is a constant, not a roll:** no `RandomNumberGenerator` exists under `game/ui/`, and a spin whose length varied would be a generator in the UI. When it stops, the landed sector brightens and takes a 4 px `GOLD` stroke for 0.8 s; the chips on a winning pad slide to the player's stack over 0.4 s, and on a losing pad slide off the felt's house edge and fade.

**Fix carried in this task:** delete `WheelMenu.WHEEL_FOOTER` and its `_ready()` assignment. It never renders (see the survey), and it hard codes both input schemes. The stake hint it was trying to give is drawn on the stake row itself instead, as a small `GOLD_DIM` `menu_tabs` glyph beside the chips, which is where the player is actually looking.

### A.6 Blackjack

**The screen.** A felt arc across the whole stage: dealer's area on a shallow upward arc across the top, player's on a downward arc across the bottom, a drawn shoe at the top right, a chip stack for the stake at bottom left.

- **Cards.** 76 by 106 at radius 8. Face: `CARD_FACE` fill, a 1 px `CARD_INK` rim, the rank in the top left and again rotated 180 degrees in the bottom right, and the suit pips laid out in the traditional arrangement for 2 through 10, a single large centred pip for an Ace, and a drawn monogram panel for Jack, Queen and King (a rounded inner rect in `GOLD_DIM` with the letter, not a portrait). Back: `PLUM` fill with a `GOLD_DIM` lattice of crossed lines and a `GOLD` border.
- **The card index maths, and why it cannot affect an outcome.** `Blackjack` numbers cards 0 to 51 and reads `card % Blackjack.RANKS` for the rank, where rank 0 is an Ace and ranks 9 through 12 are the ten count cards; `Blackjack.RANK_NAMES` gives the words. **It never names a suit at all.** So the stage derives the suit as `card / Blackjack.RANKS` (0 to 3, drawn as hearts, diamonds, spades, clubs, with 0 and 1 in `CARD_RED`) and this is a pure presentation choice that no payout, no total and no edge can see. Say so in the file's comment, because the next reader will wonder.
- **Totals:** `Blackjack.hand_total()` drawn in a small `GOLD` pill beside each hand, and a "BUST" stamp when it exceeds 21.
- **The stake:** `chip_stack()` in front of the player, built from `TableMenu.STAKES` colours.
- **The deal, on `show_hand(hand, won, stake)`.** The hand is already settled; the pacing is presentation only. Cards slide from the shoe to their seat over 0.18 s each with 0.12 s between, flipping as they land (a scale on X from 1 to 0 to 1 over 0.16 s, with the back drawn while the scale is negative). Order: player, dealer, player, dealer, then `hand["player"]` beyond the first two in order, then `hand["dealer"]` beyond its first two. About 1.4 s for a two card push, about 2.4 s for a hand with three draws on each side.
- **THE CARD IS PLAYED IN THE OPEN.** As each drawn card lands, a small `GOLD` chip reading "HIT" flashes over the hand it went to, and when a hand stops drawing, one reading "STAND" flashes over it. `Blackjack.STRATEGY_DRAWS_BELOW` is 17 for the player and `Blackjack.DEALER_STANDS_ON` is 17 for the dealer, so the player watches the placard's own rules being executed on her behalf rather than reading three lines afterwards saying what happened. This is the whole of what makes a one press hand feel like a hand and it costs no logic change at all.
- **The outcome plate:** `Blackjack.outcome_text(hand)` on a `plate()` sliding up from the felt over 0.25 s. `Blackjack.placard_lines()` stays on `Tab.PLACARD`, redrawn as a `plate()`.

**On hit, stand and double as real buttons.** The directive asks for them. This slice does not build them, and that is a deliberate call rather than an omission. `game/ui/blackjack_menu.gd`'s class comment and `game/systems/blackjack.gd` are built around a settled hand: `Blackjack.play_hand(rng)` deals and plays the whole thing in one call against the strategy card, and `Blackjack.PUBLISHED_EDGE = 0.0520` is measured against that card by `measure_edge(REFERENCE_SEED, REFERENCE_HANDS)` over 100,000 hands, re measured by `game/test/test_blackjack.gd` on every suite run, and printed on the lobby sign by `CasinoSign.edge_line()`. An interactive hand means a hand state machine in `game/systems/blackjack.gd`, a double down that changes the stake mid hand (and therefore a second call into `Casino.remove_chips()` mid transaction, which breaks the "stake comes out first" invariant every table shares), a new measured edge, a new number on the sign, and a re write of the placard. That is a slice, not a task. **What this slice does instead is the second best thing and it is genuinely good: the table is real, the cards are real, the deal is real, and the strategy card plays out visibly in front of the player.** The question is parked for the owner in the last section with an honest cost.

### A.7 Racing: the form guide card

The 3D race already exists in `game/world/race_track.gd` and `game/world/race_runner.gd` and was the owner's favourite thing in the build. It is not rebuilt. What gets polished is the screen you enter from.

- **One card per entrant,** a `rounded()` panel 1080 by 96 in `FELT` with a `GOLD_DIM` rim, stacked with 10 px gaps. Each carries, left to right:
  - **A silks swatch:** two overlapping rounded rects, her coat colour behind and her mane colour in front, plus a small `BAND_COLORS[0]` lane flash, because the player always runs on `RaceCard.PLAYER_LANE` = 0.
  - **Her name,** in the title font at size 26.
  - **A drawn odds chip:** `chip()` at radius 34 in `GOLD`, carrying `RaceCard.odds_text(odds)`, which is the "%.2f for 1" total return wording `test_published_payouts.gd` parses. Unchanged wording, drawn on a chip instead of printed in a sentence.
  - **A spirits meter:** ten pips, `roundi(happiness * 10.0)` of them filled in `GOLD`, the rest hollow. Same number `form_lines()` already prints.
  - **A win chance bar:** a 220 px track with `entry["chance"]` filled, in `BAND_COLORS[3]`. This is the number the odds are built from and showing it is what makes the odds legible.
- **The focused card** lifts 6 px, takes a `focus_ring()`, and the rest dim to alpha 0.72.
- **The stake row** under the last card, as drawn chips, exactly as everywhere else. `row_count()` stays `entrants().size() + 1` and `_on_stake_row()` is unchanged.
- **`Tab.CARD`** becomes a `plate()` carrying the same eight lines `drawn_lines()` already returns.
- **`EMPTY_TEXT`** ("Nobody is standing in your pens. Catch a pony and move her in.") gets a drawn empty state: a dimmed rail and finish post illustration with the sentence under it.

**One provider change, and it belongs to `ranch.gd`.** The menu cannot draw a coat swatch from `{"uid", "name", "happiness", "odds", "chance"}`. `Ranch`'s `entrants_provider` lambda gains two keys, `"coat": Color` and `"mane": Color`, read off the instance's `stock` triple through `StockPalette` for a stock pony and off her `PonyData` for a named one. **The menu still never sees a `PonyInstance`, never reads a pen and cannot compute anything**, which is exactly the split `race_menu.gd`'s class comment already insists on. `RaceMenu.form_lines()` is unchanged so `game/test/test_race_menu.gd` stays green, and the swatch falls back to a neutral grey when the keys are absent, so a gate that builds a bare entrant dictionary still works.

### A.8 The casino lobby: a floor plan, not a list

`casino_menu.gd`'s `Tab.LOBBY` becomes a picker of six tiles in a 3 by 2 grid, each 340 by 200:

- Each tile is a `rounded()` panel at radius 14, filled `PLUM_DARK`, with the room's illustration from `casino_paint.gd` filling its top 120 px and its words underneath, split at the colon of its own `LOBBY_ROWS` entry: the part before the colon as the title in the title font at 26, the part after as the description in `COLOR_DIM` at 18. **`LOBBY_ROWS` is not rewritten**; the six strings stay exactly as they are, because `game/test/test_casino_menu.gd` and the no dash sweeps read them and because the wording is already good ("Slots: three reels, one lever, the fast one").
- The focused tile lifts 6 px, takes a `focus_ring()` and a `GOLD` border; the other five sit at alpha 0.74. That is the whole selection model and it is `_selected`, unchanged.
- **The wallet strip** across the top of the stage: the bit icon and the bits number, then the chip icon and the chips number, then "one for one at the cage" in `COLOR_DIM`. `header_line()` keeps returning its sentence for `drawn_lines()` and the tests.
- **`Tab.CAGE`** keeps its rows and gains a drawn exchange illustration above them: a pile of bits, a double headed arrow, a pile of chips, and `Casino.CHIP_RATE` on the arrow. `CasinoSign.cage_explainer()`'s three lines stay as printed text under it. The buy and cash rows become drawn chip rows in the same treatment as the stake rows elsewhere, still built by `buy_amounts()` and `cash_amounts()` from `CAGE_STEPS`, still cut to what she holds by `_steps_within()`.
- **`Tab.RULES`** becomes a `plate()` carrying the eleven lines `sign_provider` returns from `CasinoSign.lines()`. This is where the published house edges live from now on; see section B.1.
- `Tab`, `Row`, `_row_count()`, `confirm()`, `first_row_line_index()`, `switch_tab()` and the three signals are untouched.

### A.9 What section A deliberately does not do

- **No mouse support anywhere.** Not a regression: there is none today, the game captures the cursor during play, and adding it would double the input surface of every stage for no owner request.
- **No sound.** There is no sound in this game except one voice wav and `audio_safety.gd`. A slot machine with no click is half a slot machine, but audio is an asset acquisition question and belongs with the dressing work, not here. Parked.
- **No new games.** Four games and a race is what the building has.
- **No animated dealer, no 3D casino interior, no walking between tables.** The Palace's interior does not exist; the tables are menus opened at the door. Building a room is a slice.
- **No variable bet sizing beyond `TableMenu.STAKES`.** Three stakes, unchanged, for `Blackjack.payout()`'s integer division reason.
- **No history, no statistics, no session tracking.** A "you have lost 400 chips today" panel is a different game's tone.

---

## B. Floating text: every Label3D, decided

### B.1 `Buildings/Palace/Sign`: REPLACE the label with a real sign, and move the eleven lines into the UI

**Verdict: the `Label3D` goes. A physical `LobbySign` assembly replaces it, and the published house edges move to the casino lobby's House rules page, where they are already drawn.**

This is the worst floating text in the game: an eleven line paragraph hanging unbacked in the air at a cap height of about 0.15 m, which is the thing the owner saw and called "very poor". It is also a paragraph nobody can read from a distance and nobody needs to read while standing outside a door.

What replaces it, built by a new `Building` child or by `ranch.gd` in the same place it writes the sign today (`_build_world()`, around line 846):

- A `LobbySign` `MeshInstance3D` board with a trim behind it, sized off the Palace's own `width` and `door_height` the way `Strip.mount_marquee()` sizes the marquee off the same numbers, standing beside the door rather than floating in front of it.
- Two fitted `Label3D` lines on that board, built by the same fitted method `Strip._marquee_label()` uses (`label.width = board_width / pixel`, `AUTOWRAP_WORD`, `billboard` disabled, yaw from the facing): **"House rules"** as the headline and **"every edge we keep, printed inside"** underneath.
- A drawn arrow or hoof glyph is not available in 3D without an asset, so the second line carries the information.

**Where the edges go, and why this keeps the promise.** `casino_sign.gd`'s whole ethical position is that "the odds on this sign are the real ones" and that the sign "ASKS EACH GAME what its edge is". Nothing about that changes: `CasinoSign.lines()` is untouched, it still derives all four numbers from `Slots.house_edge()`, `Wheel.house_edge()`, `Blackjack.house_edge()` and `RaceCard.TAKEOUT`, and `CasinoMenu`'s `sign_provider` still calls it. The eleven lines are drawn on `Tab.RULES` as a `plate()`, reachable from the lobby's own "House rules" tile, which is one of the six things the player sees the moment she walks in. **The edges become MORE visible, not less: today they are a distant paragraph outside the door; after this they are a page inside the building that the lobby's own picker points at.**

**Gate consequence, and it must be carried in the same task.** `game/scenes/test/casino_test.gd` lines 262 to 277 currently read `Buildings/Palace/Sign` as a `Label3D` and assert its `.text` contains every `edge_line()`. That assertion is retargeted, not deleted: it moves onto `CasinoMenu`'s own `drawn_lines()` on `Tab.RULES`, which is the surface a player actually reads, plus a new check that the `LobbySign` board is standing and that its two lines carry no dash. `print("CASINO sign lines=%d")` keeps printing, counting the rules page's lines. This is a strictly better gate: it now asserts the thing the player sees rather than a node that happens to hold a string.

`props=` and `ponies=` do not move: `Sign` is a child of `Buildings/Palace`, not a child of `Buildings`, and `prop_count` is `props.build() + buildings.get_child_count()`.

### B.2 `MarqueeHeadline` and `MarqueeSponsor`: KEEP, and light them

**Verdict: keep both. This is the one place in the game where floating letters are correct, because a marquee is letters.** They are already backed by `MarqueeBoard` and `MarqueeTrim`, already fitted to the board's width, already facing the walk up from the homestead, and already went through a repair pass on 2026-08-31 for exactly the "66 characters across a 14 metre building" problem.

What this slice adds, all in `game/world/strip.gd`:

- **A bulb rail.** Ten small emissive spheres around the trim's perimeter, `MARQUEE_TRIM_COLOR`, built as one `MultiMeshInstance3D` so it is ten instances and one draw call. With glow enabled (section C.2) they bloom gently at dusk and night and read as a lit sign, which is the whole point of a marquee.
- **A wash light.** One `SpotLight3D` on the board's own face, `LAMP_COLOR`, `shadow_enabled = false` for the reason `strip.gd` already gives about its lamp ring ("A lamp post out in the open has nothing to leak through").
- **Emissive letters.** `Label3D` has `modulate` and `shaded = false`, which already renders full bright; with glow on, `MARQUEE_COLOR` `Color(1.0, 0.92, 0.62)` will bloom on its own. No change needed to the labels themselves.

`Strip.marquee_lines()`, `LIGHT_COUNT`, `light_count()` and every constant `game/test/test_strip.gd` pins stay exactly as they are. The bulbs go under the marquee assembly, not into `_lights`, so `light_count()` still answers 9 and the gate's "the Strip's lamps are standing, minus the one skipped clear of the Palace" check is unaffected.

### B.3 `RaceRunner.Nameplate`: REMOVE, and replace with lane colour and a chevron

**Verdict: the six billboarded names go. The information they carry moves into geometry.**

They exist for a real reason, stated in `race_runner.gd`: "so the player can tell six recoloured ponies apart from the rail". Six names bobbing over six galloping ponies is also the most Roblox looking thing in a 3D scene. The information is "which one is which" and "which one is mine", and both are better answered by colour.

What replaces them:

- **A lane saddlecloth.** A thin `BoxMesh` on each runner's barrel, tinted `CasinoPaint.BAND_COLORS[lane]`, built in `RaceRunner.dress()` beside the model. Six lanes, six rainbow colours, the same six the wheel's bands and the slots `RAINBOW` symbol use.
- **Lane markers on the rail.** `game/world/race_track.gd` already builds rails and posts in `RAIL_COLOR` and `POST_COLOR`; the six starting posts take their lane's colour, so the colour on the pony matches the colour on the gate she left.
- **The form guide already agrees.** Section A.7 puts `BAND_COLORS[0]` on the player's own card, and `RaceCard.PLAYER_LANE` is 0, so the pony the player backed is the one wearing the first colour of the rainbow, on the rail, every time, and the guide told her so before the off.
- **One chevron for your own runner.** A small `GOLD` cone `MeshInstance3D` floating 2.4 m over `PLAYER_LANE`'s runner, bobbing on a 1.6 s sine. Geometry, not text, and it points at the only pony the player has money on.

**Test consequence:** `game/test/test_race_runner.gd` line 58 currently excludes `Label3D` when counting a runner's model children; it is rewritten to exclude the saddlecloth and the chevron by node name.

**This removes the last billboarded text in the game.** After section B the world contains exactly two pieces of 3D text, both on the Palace, both on physical boards, both fitted to their board's width, and both reading as signage because that is what they are.

### B.4 What section B deliberately does not do

- **It does not touch the HUD.** `$Prompt`, `$Toast`, `$Tasks` and `$Hints` are 2D and stay 2D. Making the interaction prompt a floating world label would be moving in exactly the wrong direction.
- **It does not add name labels anywhere else.** Ponies in pens, wild ponies, the vendor and the teller carry no text today and gain none.
- **It does not build a 3D dialogue or nameplate system.** Phase 3 slice 4 brings the talk box, per `game/world/attendant.gd`'s own note.

---

## C. The graphics and look upgrade

Everything in this section is an Environment field, a light property, a material property or one small shader. No assets, no textures, no LODs, no new nodes on the census.

### C.1 Tonemapping and grading

- **Keep `tonemap_mode = 3` (ACES). Reject AgX.** AgX (`tonemap_mode = 4`) is the fashionable answer and it is the wrong one here: it deliberately desaturates as values rise, which is correct for photographic realism and directly against a bright saturated Slime Rancher palette. ACES already does some of that; the fix is to grade the saturation back rather than to pick a mapper that does more of it.
- **`tonemap_white` from 3.0 to 1.8.** At 3.0 nothing on this map reaches the curve's shoulder, so the mapper is doing nothing but a slight midtone desaturation. At 1.8 the sky, the gold trim and the lamp cores actually roll off, which is what gives a scene the feeling of light rather than the feeling of paint.
- **Turn on the adjustment block:** `adjustment_enabled = true`, `adjustment_saturation = 1.14`, `adjustment_contrast = 1.05`, `adjustment_brightness = 1.0`. No `adjustment_color_correction` texture: that is an asset, and these three floats get most of the way. This is the single cheapest change in the whole slice and it is most of the "cute palette" answer.

### C.2 Glow

`glow_enabled = true`, tuned subtle:

```
glow_intensity      = 0.55
glow_strength       = 1.0
glow_bloom          = 0.03
glow_blend_mode     = 0            (ADDITIVE)
glow_hdr_threshold  = 1.05
glow_hdr_scale      = 2.0
glow_levels/2       = 0.0
glow_levels/3       = 0.55
glow_levels/4       = 0.85
glow_levels/5       = 0.45
```

Threshold above 1.0 so only genuinely bright things bloom: the sky near the sun, the lamp cores on the Strip, the marquee bulbs, the gold trim in direct sun. Levels 3 to 5 and not 1 to 2, so the bloom is a wide soft halo rather than a smear on every edge. **Additive rather than softlight** because the one thing this game needs glow for is a lit sign at night, and softlight will not carry that.

### C.3 Shadows

On `$Sun`:

```
shadow_bias                     0.05  ->  0.02
shadow_normal_bias                    ->  1.2
light_angular_distance          0.0   ->  0.9      (degrees; a real penumbra)
directional_shadow_max_distance 240.0 ->  85.0
directional_shadow_split_1            ->  0.06
directional_shadow_split_2            ->  0.17
directional_shadow_split_3            ->  0.42
directional_shadow_blend_splits       ->  true
directional_shadow_fade_start         ->  0.92
shadow_blur                     1.0   ->  1.1
```

**85 m rather than 240 m** is the change that matters. The camera rig pulls out to `SPRING_MAX` 6.5 m behind the player; nothing beyond about 80 m is legible as a shadow anyway, and cutting the range by nearly three times gives every cascade nearly three times the texel density for free. `blend_splits` on removes the hard cascade seam that appears once the splits are tight. `light_angular_distance` 0.9 degrees gives the soft contact shadow that separates a "lit 3D scene" from a "3D scene with shadows in it" more than any other single property.

**Fog is already correct and stays.** `SkyRig._write_to_scene()` writes `fog_light_color = horizon` per phase and `fog_density` per weather from `WEATHER_FOG_DENSITY` `[0.0011, 0.004, 0.010, 0.008]`. Two additions: `fog_aerial_perspective = 0.35` on the Environment so distant geometry picks up the sky rather than only the fog colour, and `fog_sky_affect` stays at 0.35. Both are static fields the rig does not drive, so there is no conflict.

**SSAO on, SSIL off.**

```
ssao_enabled       = true
ssao_radius        = 0.9
ssao_intensity     = 1.35
ssao_power         = 1.5
ssao_detail        = 0.5
ssao_horizon       = 0.06
ssao_sharpness     = 0.98
ssao_light_affect  = 0.15
ssao_ao_channel_affect = 0.0
```

`ssao_light_affect` at 0.15 rather than 0 matters: at 0 the occlusion applies to ambient only, which on a scene lit 35 percent from sky ambient makes every interior corner go to near black at night. **SSIL is deliberately off:** it is roughly the cost of SSAO again, and on a world of flat single colour boxes it has almost nothing to bounce. That is a YAGNI, recorded so it stays one.

### C.4 The terrain: the biggest single win

The flat gradient ground is the strongest "roblox" signal on the map. The fix is one small shader and no assets.

**Replace the `StandardMaterial3D` in `Terrain._build_mesh()` with a `ShaderMaterial` over a new `game/world/terrain.gdshader`.** The mesh, the vertex colours, `grass_at()`, `height_at()`, the regions and the collider are all untouched; `create_trimesh_shape()` is taken from the mesh before any material matters.

What the shader does, in order:

1. **Takes `COLOR` as the base.** `grass_at()` and every region palette stay the single authority on what colour the ground is at a point. **The shader MUST convert `COLOR` from sRGB to linear itself**, because `vertex_color_is_srgb = true` is a `StandardMaterial3D` flag with no shader equivalent, and dropping it is exactly the bug `terrain.gd`'s own comment records: "the first render of this terrain was a pale mint sheet, not grass". This is the one trap in the whole slice most likely to be missed.
2. **Adds hash based value noise at two frequencies,** 0.9 m and 4.5 m in world XZ, amplitude about 0.055 on value and about 0.03 pulled toward the region's own `GRASS_HIGH` hue. No texture: a 2D integer hash plus smoothstep interpolation is about twelve lines of shader. This is what stops the ground being smooth at every scale.
3. **A slope mask.** `1.0 - NORMAL.y` in world space, smoothstepped between 0.30 and 0.68, blends the grass toward a `DIRT` uniform (`Color(0.36, 0.28, 0.19)` by default). Hillsides and the lake basin walls become earth, which is both more believable and free relief reading: a slope you can see is a slope you can plan a walk around.
4. **A ridge lift.** `WORLD_MATRIX` Y, remapped over the map's own relief, lifts the tops about 6 percent toward `GRASS_HIGH`. Small, because `grass_at()` already does some of this per vertex; the shader's version is continuous where the vertex version is 2 m stepped.
5. **A distance fade.** The 0.9 m noise octave fades out between 30 m and 70 m of view distance, so the middle distance does not shimmer under a moving camera. Without this the noise buys aliasing instead of detail.
6. `render_mode cull_back, diffuse_burley, specular_disabled;` and `ROUGHNESS = 0.95`, matching exactly what the `StandardMaterial3D` did.

Every tunable is a shader `uniform` with a default, so no `.tres` is created and nothing new needs importing.

**Headless safety.** Godot compiles shaders lazily and the headless renderer never rasterises, so a `ShaderMaterial` on a mesh in a headless run is inert. The one real risk is a shader that fails to PARSE, which prints an error at load and would be invisible to a gate that only checks `RANCH_OK`. So `game/test/test_terrain.gd` gains one assertion: the built mesh's surface 0 material is a `ShaderMaterial`, its `shader` is non null, and `shader.code` is non empty. That is cheap and it catches the only failure mode that matters.

### C.5 Building and prop materials

`Building._material()` currently gives every surface of every building roughness 0.9 and no specular. Split it three ways:

- **Walls:** roughness 0.88, specular disabled. Unchanged in feel.
- **Roofs:** roughness 0.70. A roof that is slightly less rough than its wall reads as a different material without a texture.
- **Trim:** roughness 0.45 and a new `@export var trim_metallic := 0.0` on `Building`, with `specular_mode` left at its default (not disabled) whenever `trim_metallic > 0.0`.

Then in `game/world/ranch.tscn`, `Buildings/Palace` gets `trim_metallic = 0.45`. **Only the Palace.** Every other building keeps 0.0 and therefore renders byte for byte as it does today. The result is that the casino's gold trim catches the sun and the marquee bulbs, and nothing else in the game changes at all. That is a lot of "this building is special" for one exported float.

`game/world/pen.gd._material_static()` (roughness 0.92), `game/world/race_track.gd` (0.85) and `game/world/strip.gd._flat_material()` (0.85) are left alone. `game/world/props.gd` is owned by the dressing slice and is not touched.

### C.6 What section C deliberately does not do

- **No volumetric fog.** Expensive, and `SkyRig`'s density fog already carries the weather.
- **No SDFGI.** Very expensive, needs a static world it does not have, and the scene is already lit 35 percent from sky ambient.
- **No SSIL, no SSR.** See C.3.
- **No new sky.** `ProceduralSkyMaterial` driven by `SkyRig` is good and is the most carefully reasoned file in the repository. Nothing here touches its mapping, its transitions, its constants or its orderings.
- **No terrain textures, no splat maps, no normal maps, no detail meshes, no grass instancing.** All of them are asset or performance questions.
- **No water shader.** `Terrain.build_water()`'s translucent disc stays.
- **No post processing that needs a `SubViewport` or a screen shader.**
- **No change to `Terrain.CELL`, `HALF`, `FLAT_RADIUS` or the heightfield's shape.** Moving any of them moves `height_at()`, which the mesh, the collider, the props, the pens, the spawner and the gates all read.

---

## D. Menu chrome: one pass, every panel

The non casino menus (`market_menu.gd`, `depot_menu.gd`, `build_menu.gd`, `pause_menu.gd`, `letter_panel.gd`, and the Request Board pages inside them) are not rebuilt. They inherit.

**1. The panel style stops being copy pasted.** `MenuPanel` is a `StyleBoxFlat` duplicated verbatim in all seven menu `.tscn` files. `menu_style.gd` gains `panel_style() -> StyleBoxFlat` returning a single cached instance with those exact numbers, plus `apply_panel(panel: PanelContainer)`. Every `.tscn` drops its own copy and every menu's `_ready()` calls `apply_panel($Centre/Panel)`. One place to change the look of every panel in the game.

**2. The row treatment that is already specified becomes real.** `MenuStyle.ROW_SELECTED_BG`, `ROW_SELECTED_BORDER`, `ROW_IDLE_BG` and `ROW_IDLE_BORDER` are declared and unused. `menu_style.gd` gains `row_box(picked: bool) -> StyleBoxFlat` building them into a 6 px radius box with a 4 px left inset, and every menu's `refresh()` wraps its row `Label` in a `PanelContainer` carrying it. **The `"> "` caret stays** (`MenuStyle.CARET`, `NO_CARET`, both the same width on purpose) because `game/test/test_table_caret.gd` and `game/test/test_menu_style.gd` read it and because a caret plus a highlight is more legible than either alone, not less.

**3. A type hierarchy without a font asset.** There is no `.ttf` in this project and this slice does not add one. `menu_style.gd` gains two cached `FontVariation`s over the theme's default font: `title_font()` with `variation_embolden = 0.55` and `spacing_glyph = 2`, and `numeral_font()` with `variation_embolden = 0.3`. Applied through `add_theme_font_override`. A `FontVariation` is constructed in code, ships no file and needs no import, so this is a real weight hierarchy for zero assets. `TITLE_SIZE` 30, `ROW_SIZE` 22 and `FOOTER_SIZE` 20 stay; a fourth size, `SUBTITLE_SIZE := 18`, is added for the tile descriptions and the `COLOR_DIM` second lines.

**4. A title rule.** `menu_style.gd` gains `rule(ci, from, to)` drawing a 2 px `GOLD` line fading to transparent at both ends, and every panel draws one under its `Title`. It is one line of geometry and it does more for "this looks designed" than any other single thing on a text panel.

**5. The footers.** `footer()`, `footer_tabs_and_rows()`, `footer_rows()` and `footer_reading()` are unchanged, and `WheelMenu.WHEEL_FOOTER` is deleted (see A.5). After this every footer in the game comes from `MenuStyle` and therefore shows exactly one input scheme.

**6. `game/ui/hud.gd`'s own `_style_label()`** (size, colour, `Color(0, 0, 0, 0.75)` outline at size 6) is folded onto `MenuStyle.style_label()`, whose outline is the same colour at size 5. The HUD keeps its own colour constants and its own layout; only the duplicated styling function goes. This is what makes the HUD and the menus agree, which is half of what "all text menus are very confusing" was about.

**What section D deliberately does not do:** it does not rebuild the market, depot, build, pause or letter panels, does not change any of their rows, tabs, signals or input models, and does not touch `game/ui/creation_screen.gd` or `game/ui/mark_canvas.gd`, which are their own screens with their own reasons.

---

## Slice shape: eight SDD tasks

Ordered so each one is independently shippable and green.

1. **`game/ui/casino_paint.gd` and its test.** The palette, the primitives, the glyphs, the `*_points()` / `draw_*` split, `game/test/test_casino_paint.gd` asserting every glyph's geometry sits inside its box.
2. **The chrome pass (section D).** `panel_style()`, `row_box()`, `title_font()`, `rule()`, all seven `.tscn` dropping their `StyleBoxFlat` copies, `hud.gd._style_label()` folded in, `WheelMenu.WHEEL_FOOTER` deleted. Updates `game/test/test_menu_style.gd`. **Every menu in the game is visibly better after this one task and no casino work has started yet.**
3. **The stage plumbing (section A.2).** `Stage` in five `.tscn`s, `paint()`, `printed_lines()`, `focus_rect()`, `focused_id()`, the `queue_redraw()` discipline, and the rewrite of `game/test/test_table_caret.gd` onto `focus_rect()` so it still asks the drawing rather than the number.
4. **The slot machine (A.4)**, including `Ranch.play_slots()`'s one added `show_spin()` call.
5. **The wheel (A.5)**, including `Ranch.play_wheel()`'s one added call.
6. **Blackjack (A.6)**, including `Ranch.play_blackjack()`'s one added call and the visible HIT and STAND flashes.
7. **The lobby and the form guide (A.7, A.8)**, including the two new keys on `Ranch`'s `entrants_provider`.
8. **The look pass (B and C).** Environment, sun, terrain shader, building trim metallic, the `LobbySign` replacing `Buildings/Palace/Sign`, the marquee bulbs and wash light, the saddlecloths and chevron replacing the nameplates. Retargets `game/scenes/test/casino_test.gd`'s sign checks, updates `game/test/test_race_runner.gd` and `game/test/test_terrain.gd`, and re reads every gate count into `docs/testing.md` rather than guessing one.

Task 8 is the largest and could split into 8a (the world text) and 8b (the look) if it runs long. Everything else is one sitting.

## Testing

**Existing tests that must stay green untouched:** `test_slots.gd`, `test_wheel.gd`, `test_blackjack.gd`, `test_race_card.gd`, `test_casino.gd`, `test_casino_sign.gd`, `test_published_payouts.gd`, `test_ranch_casino_rules.gd`, `test_ranch_race.gd`, `test_company_runners.gd`, `test_sky_rig.gd`, `test_strip.gd`. None of their subjects moves.

**Existing tests that need edits, and why:**

- `test_table_caret.gd`: rewritten in task 3 onto `focus_rect()` and `focused_id()`. Its spirit is preserved exactly: it must keep asking where the ring was PAINTED, because "the whole defect lived in the gap between the number and the drawing".
- `test_slots_menu.gd`, `test_wheel_menu.gd`, `test_blackjack_menu.gd`, `test_race_menu.gd`, `test_casino_menu.gd`: `drawn_lines()` is unchanged, so most assertions stand. Any assertion that walks the `Rows` children moves to `printed_lines()`.
- `test_menu_style.gd`: gains `panel_style()`, `row_box()`, `title_font()` and `rule()`; its "a real panel draws its rows with the outline" test extends to the new row box.
- `test_race_runner.gd` line 58: excludes the saddlecloth and chevron by name instead of excluding `Label3D`.
- `test_terrain.gd`: gains the `ShaderMaterial` assertion from C.4.
- `game/scenes/test/casino_test.gd`: the sign block retargets onto `CasinoMenu`'s rules page plus the new `LobbySign`.

**New tests:** `test_casino_paint.gd` (geometry), plus per stage tests asserting that `paint()` runs against a real `Control` without erroring, that `focused_id()` tracks `_selected` across every row of every tab, and that a `show_spin()`/`show_hand()` call with an out of range value (a pocket of 99, a card of 300, an empty reels array) degrades to a still frame rather than erroring, since those come in over a dynamic `call()`.

**The no dash sweep** already runs over every menu's `drawn_lines()` and over `CasinoSign`; it now also has to cover `LOBBY_ROWS`'s split halves and every string `casino_paint.gd` draws.

**`MIN_TESTS` in `tools/run_tests.sh`** is raised in the final task to the number the suite actually reports. Do not guess it. Run the suite without the sweep skip before calling any task finished.

---

## Decisions parked for the owner

Each of these is a call this spec has already made so the slice can be planned; each is one the owner may reverse.

1. **Blackjack stays a one press hand.** The call: draw the table, the cards, the deal and the strategy card playing out visibly, and do not add hit, stand and double. The reason: `Blackjack.PUBLISHED_EDGE = 0.0520` is MEASURED against the strategy card over 100,000 hands and printed on the sign; interactive play means a hand state machine, a double down that takes chips mid transaction (breaking the "stake comes out first" invariant every table in the building shares), a re measured edge, a new sign and a new placard. Honest cost if the owner wants it: a slice of its own, roughly the size of this one's tasks 3 and 6 together. **If the owner says yes, it should be its own slice and not bolted onto this one.**
2. **The eleven line published edge board leaves the world.** The call: the `Label3D` outside the Palace becomes a "House rules, every edge we keep, printed inside" board, and the numbers live on the lobby's House rules page. The promise is kept and arguably strengthened, but this does move the Palace's ethical position from the approach to the interior, and that is the owner's building.
3. **The six race nameplates are removed.** The call: lane colour saddlecloths, colour matched starting posts, colour matched form guide cards, and a gold chevron over your own runner. The owner may want the names back; if so, the cheapest honest version is a name on the chevron only, for the player's own pony, which is one label instead of six.
4. **No new font this slice.** The call: `FontVariation` over the engine default for weight and spacing. A licensed display font for the Palace's headline would be a real upgrade and costs one file plus a licence check; it belongs with the dressing slice's asset work rather than here.
5. **No sound.** The call: a silent casino this slice. A reel click, a chip clink, a wheel ratchet and a card snap would each be worth more than any single visual item in section A. Parked because it is an asset acquisition question.
6. **The wheel's number tab still walks 24 pads one at a time.** The call: keep today's input model exactly, because `row_count()` is `guess_count() + 1` and the last position is the stake, and a grid walk on the number tab would collide with both that and the tab switch on left and right. Crossing the felt is 24 presses. If the owner finds that annoying in play, the fix is a real design question (a two axis grid needs a fifth and sixth direction from somewhere) and not a polish tweak.
7. **`TableMenu.STAKES` stays `[10, 50, 200]`.** Three drawn chips. If the owner wants a fourth high stake, it must be even, for `Blackjack.payout()`'s integer division.
