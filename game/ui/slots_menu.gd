class_name SlotsMenu
extends "res://ui/table_menu.gd"
## THE SLOT MACHINE. One row per stake, the paytable underneath, and the last spin above it.
## It spins nothing: ranch.gd rolls the seeded generator, settles the chips and pushes the
## result back through show_result().
##
## Extended by path rather than by the global class_name, for the reason every preload in
## this project is by path: the class cache lives in the gitignored game/.godot/.

const SlotsScript := preload("res://systems/slots.gd")

const TITLE := "Slots"

signal spin_requested(stake: int)


func title_text() -> String:
	return TITLE


func tabs_text() -> String:
	return "Pull the lever. The house keeps %.1f bits of every 100." \
		% (SlotsScript.house_edge() * 100.0)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = [chips_line(), keys_line()]
	lines.append_array(result_block())
	lines.append_array(stake_lines())
	if not stakes().is_empty():
		lines.append("Spin for %d chips" % selected_stake())
	lines.append("")
	for line in SlotsScript.paytable_lines():
		lines.append(line)
	return lines


## Only the stake rows are selectable; the paytable is reading matter.
func row_count() -> int:
	return stakes().size()


## The last spin is printed above the stake line, and now so are the chips line and the
## keys line every table carries; see SlotsMenu's own history and
## game/test/test_table_caret.gd, which pins the caret to the "Stake:" row itself rather
## than to "Spin for N chips" underneath it. See TableMenu.result_block() for what replaced
## the raw result lines this offset used to count.
func first_row_line_index() -> int:
	return 2 + result_block().size()


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))


func confirm() -> bool:
	if selected_stake() <= 0:
		return false
	spin_requested.emit(selected_stake())
	return true
