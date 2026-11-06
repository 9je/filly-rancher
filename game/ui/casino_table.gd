extends "res://ui/table_menu.gd"
## THE BUTTON STAGE: what the slot machine, the wheel and the blackjack table share since the
## rebuild of 2026-11-05. Every control is a drawn thing on the felt (a chip, a lever, a tier
## pad, a Hit button) and nothing is a line of text in a column under it.
##
## WHY A LAYER BETWEEN TableMenu AND THE GAMES. TableMenu's model is "rows in a column, plus a
## stage above them", and the race card still is that. The owner's playtest of these three
## (2026-11-05) saw what that model left behind once every row had moved onto the stage: a
## text log of the last result under the felt ("Gem Apple Bell", "= = = = ="), an invisible
## column of hit targets whose hover box showed as a stray bar, key hint rows, and stake chips
## drawn on the felt that were not the things the mouse could actually click (the column rows
## were), which is why the 50 and 200 chips did nothing. Here the column is gone: the drawn
## things ARE the controls, with one list (stage_buttons()) that the painting, the pointer and
## the keyboard all read, so the three can never disagree again.
##
## ONE CURSOR. `_selected` indexes stage_buttons(). The arrow keys walk it (skipping anything
## disabled), the pointer moves it on hover, and confirm or a click activates what it is on.
## The focus ring is drawn on it by each game's paint(), with PaintScript.focus_ring().
##
## THE MENU STILL DRAWS AND EMITS; ranch.gd STILL TRANSACTS. Nothing here sees a purse.

const MenuStyleCasino := preload("res://ui/menu_style.gd")


## THE CONTROLS ON THE FELT, in keyboard order: each {"id": StringName, "rect": Rect2 in stage
## pixels, "enabled": bool}. Built fresh on every ask, so a button's rect and its enabled state
## are always what this frame paints.
func stage_buttons() -> Array[Dictionary]:
	return []


## What pressing button `id` does. Returns whether anything happened.
func activate(_id: StringName) -> bool:
	return false


## Where the cursor starts when the table opens.
func initial_focus() -> StringName:
	return &""


## The pointer's own say before the click and hover handling below: a game that wants a drag
## (the slot machine's lever) answers true for the events it took.
func stage_pointer(_event: InputEvent) -> bool:
	return false


## A right click on button `index`: the wheel takes a chip back off a tier with it.
func on_stage_alt(_index: int) -> void:
	pass


func button_index(id: StringName) -> int:
	var buttons: Array[Dictionary] = stage_buttons()
	for i: int in buttons.size():
		if StringName(buttons[i]["id"]) == id:
			return i
	return -1


func button_rect(id: StringName) -> Rect2:
	var i: int = button_index(id)
	return Rect2() if i < 0 else stage_buttons()[i]["rect"]


func button_enabled(id: StringName) -> bool:
	var i: int = button_index(id)
	return i >= 0 and bool(stage_buttons()[i].get("enabled", true))


## Whether `id` should paint lit: the cursor is on it or the pointer is over it.
func is_lit(id: StringName) -> bool:
	var i: int = button_index(id)
	return i >= 0 and (i == _selected or i == _hovered)


func focus_on(id: StringName) -> void:
	var i: int = button_index(id)
	if i >= 0:
		_selected = i
		if _stage != null:
			_stage.queue_redraw()


func open() -> bool:
	if not super.open():
		return false
	var start: int = button_index(initial_focus())
	_selected = maxi(0, start)
	return true


func row_count() -> int:
	return stage_buttons().size()


## THE COLUMN UNDER THE STAGE IS GONE, and so is the key hint footer. Title and tabs stay: they
## are the one frame every panel in the game shares.
func refresh() -> void:
	if not is_node_ready():
		return
	_footer.visible = false
	_title.text = title_text()
	MenuStyleCasino.apply_title(_title)
	MouseRowsScript.tab_strip(_tabs, tab_names(), tab(), point_at_tab, take_tab)
	_tabs.visible = not tab_names().is_empty()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.visible = false
	var n: int = row_count()
	_selected = clampi(_selected, 0, maxi(0, n - 1))
	if _hovered >= n:
		_hovered = -1
	if _stage != null:
		_stage.custom_minimum_size = stage_size()
		_stage.queue_redraw()


func printed_lines() -> Array[String]:
	return [] as Array[String]


func first_row_line_index() -> int:
	return 0


## The arrow keys, skipping disabled controls. Moving with nothing enabled stays put.
func move_selection(step: int) -> void:
	var buttons: Array[Dictionary] = stage_buttons()
	var n: int = buttons.size()
	if n <= 0:
		return
	if step == 0:
		return
	for k: int in range(1, n + 1):
		var candidate: int = posmod(_selected + step * k, n)
		if bool(buttons[candidate].get("enabled", true)):
			if candidate != _selected:
				_selected = candidate
				MenuStyleCasino.tick_move()
			break
	_hovered = -1
	if _stage != null:
		_stage.queue_redraw()


## LEFT AND RIGHT WALK THE FELT TOO, not the tabs: the tabs are buttons the pointer clicks,
## and on a felt laid out in rows and columns, left and right are where a player reaches first.
func switch_tab(step: int) -> void:
	move_selection(step)


func confirm() -> bool:
	var buttons: Array[Dictionary] = stage_buttons()
	if buttons.is_empty():
		return false
	var button: Dictionary = buttons[clampi(_selected, 0, buttons.size() - 1)]
	if not bool(button.get("enabled", true)):
		MenuStyleCasino.tick_denied()
		return false
	return activate(StringName(button["id"]))


## THE POINTER MOVES THE ONE CURSOR, even mid animation: what is refused during a spin is
## ACTING (each activate() checks), never looking.
func point_at_row(index: int) -> void:
	if not _open or index < 0 or index >= row_count():
		return
	_hovered = index
	if index != _selected:
		_selected = index
		MenuStyleCasino.tick_move()
	if _stage != null:
		_stage.queue_redraw()


func take_row(index: int) -> void:
	point_at_row(index)
	if _selected == index:
		confirm()


func focus_rect() -> Rect2:
	var buttons: Array[Dictionary] = stage_buttons()
	if buttons.is_empty():
		return Rect2()
	return to_viewport(buttons[clampi(_selected, 0, buttons.size() - 1)]["rect"])


func focused_id() -> StringName:
	var buttons: Array[Dictionary] = stage_buttons()
	if buttons.is_empty():
		return &""
	return StringName(buttons[clampi(_selected, 0, buttons.size() - 1)]["id"])


func stage_hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for button: Dictionary in stage_buttons():
		out.append(button["rect"])
	return out


func on_stage_hit(index: int) -> void:
	take_row(index)


## Paint the one focus treatment on the button under the cursor. Every game calls this last in
## its paint(), so the ring is on top of whatever it is ringing.
func paint_focus(ci: Control) -> void:
	var buttons: Array[Dictionary] = stage_buttons()
	if buttons.is_empty():
		return
	var rect: Rect2 = buttons[clampi(_selected, 0, buttons.size() - 1)]["rect"]
	PaintScript.focus_ring(ci, rect.grow(5.0), minf(22.0, rect.size.y * 0.5 + 5.0),
		anim_time())


func _on_stage_input(event: InputEvent) -> void:
	if not _open or _stage == null:
		return
	if stage_pointer(event):
		_stage.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var over: int = MouseRowsScript.hit(stage_hit_rects(), motion.position)
		if over >= 0:
			point_at_row(over)
		elif _hovered != -1:
			_hovered = -1
			_stage.queue_redraw()
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		var at: int = MouseRowsScript.hit(stage_hit_rects(), button.position)
		if at >= 0:
			on_stage_alt(at)
			_stage.accept_event()
		return
	super._on_stage_input(event)


## TAB TURNS THE PAGE on a table that has pages (blackjack's Table and Rules), since left and
## right now walk the felt. Everything else is TableMenu's own key handling.
func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_pressed() and event.is_action(&"ui_focus_next") \
			and not tab_names().is_empty():
		take_tab(posmod(tab() + 1, tab_names().size()))
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


## RUN WHATEVER IS ANIMATING TO ITS END NOW, callbacks and all. For gates and tests that play
## many rounds through the felt in one frame; the player never calls it.
func finish_animation() -> void:
	var tween: Tween = get(&"_tween") as Tween
	var guard := 0
	while tween != null and tween.is_valid() and tween.is_running() and guard < 64:
		tween.custom_step(10.0)
		guard += 1
		tween = get(&"_tween") as Tween
