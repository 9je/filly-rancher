extends GutTest
## THE BLACKJACK TABLE, where she makes the decisions. Every test is a line of the owner's
## playtest (2026-11-05): "why blackjack i cant make decisions?", the banner whose text left
## its box, the "=====" log under the felt, and "dealer 'stand' after he bust". Hands pushed
## here are real ones from game/systems/blackjack_round.gd, pushed the way ranch.gd pushes.

const BlackjackMenuScene := preload("res://ui/blackjack_menu.tscn")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RoundScript := preload("res://systems/blackjack_round.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")
const PaintScript := preload("res://ui/casino_paint.gd")
const MouseRowsScript := preload("res://ui/mouse_rows.gd")

var _menu: BlackjackMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = BlackjackMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


func after_each() -> void:
	MenuStyleScript.text_scale = 1.0


func _find(want: Callable) -> RoundScript:
	for seed_value in range(1, 20000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if want.call(RoundScript.deal(rng, 50)):
			rng.seed = seed_value
			return RoundScript.deal(rng, 50) as RoundScript
	return null


func _live() -> RoundScript:
	return _find(func(h) -> bool: return not h.is_settled())


func _push(hand: RoundScript) -> void:
	_menu.show_hand(hand.view(), hand.payout(), hand.total_staked())
	_menu.finish_animation()


func test_before_a_hand_there_are_stakes_and_deal_and_deal_emits_the_stake() -> void:
	assert_eq(String(_menu.focused_id()), "deal")
	_menu.on_stage_hit(_menu.button_index(&"stake:2"))
	watch_signals(_menu)
	_menu.on_stage_hit(_menu.button_index(&"deal"))
	assert_signal_emitted(_menu, "deal_requested")
	assert_eq(get_signal_parameters(_menu, "deal_requested")[0], 200)


func test_an_empty_purse_cannot_deal() -> void:
	_chips = 0
	watch_signals(_menu)
	assert_false(_menu.button_enabled(&"deal"))
	assert_false(_menu.activate(&"deal"))
	assert_signal_not_emitted(_menu, "deal_requested")


## "why blackjack i cant make decisions?"
func test_a_live_hand_offers_hit_stand_and_double_and_each_emits_its_action() -> void:
	_push(_live())
	assert_true(_menu.hand_live())
	var ids: Array[String] = []
	for b: Dictionary in _menu.stage_buttons():
		ids.append(String(b["id"]))
	assert_eq(ids, ["hit", "stand", "double"] as Array[String])
	assert_eq(String(_menu.focused_id()), "hit", "the cursor waits on Hit")
	watch_signals(_menu)
	for pair: Array in [[&"hit", RoundScript.Action.HIT], [&"stand", RoundScript.Action.STAND],
			[&"double", RoundScript.Action.DOUBLE]]:
		_menu.on_stage_hit(_menu.button_index(pair[0]))
	assert_signal_emit_count(_menu, "action_requested", 3)
	assert_eq(get_signal_parameters(_menu, "action_requested", 0)[0], RoundScript.Action.HIT)
	assert_eq(get_signal_parameters(_menu, "action_requested", 2)[0],
		RoundScript.Action.DOUBLE)


func test_double_is_greyed_when_the_purse_cannot_cover_a_second_stake() -> void:
	_chips = 20
	_push(_live())
	assert_false(_menu.button_enabled(&"double"))
	assert_true(_menu.button_enabled(&"hit"))


func test_double_is_greyed_after_a_hit() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		h.hit()
		return not h.is_settled())
	hand.hit()
	_push(hand)
	assert_false(_menu.button_enabled(&"double"))


func test_the_hole_card_is_face_down_and_the_dealer_total_hidden_until_she_stands() -> void:
	var hand: RoundScript = _live()
	_push(hand)
	assert_eq(_menu.shown_dealer_cards().size(), 2)
	assert_eq(_menu.shown_dealer_cards()[1], -1, "the hole card is drawn as a back")
	assert_eq(_menu.dealer_total_text(), "?")
	assert_ne(_menu.player_total_text(), "?")
	hand.stand()
	_push(hand)
	assert_eq(_menu.shown_dealer_cards(), hand.dealer)
	assert_ne(_menu.dealer_total_text(), "?")


func test_a_hit_slides_one_card_to_her_and_nothing_to_the_dealer() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		h.hit()
		return not h.is_settled())
	_push(hand)
	hand.hit()
	_push(hand)
	assert_eq(_menu.shown_player_cards().size(), 3)
	assert_eq(_menu.shown_dealer_cards().size(), 2)
	assert_eq(_menu.shown_dealer_cards()[1], -1)


## "dealer 'stand' after he bust"
func test_a_dealer_who_busts_is_said_to_bust() -> void:
	var hand: RoundScript = _find(func(h) -> bool:
		if h.is_settled():
			return false
		h.stand()
		return h.dealer_total() > 21)
	_push(hand)
	hand.stand()
	_push(hand)
	assert_true(_menu.banner_up())
	assert_eq(_menu.headline(), "Dealer busts")
	assert_eq(_menu.dealer_total_text(), "Bust")
	for line: String in [_menu.headline(), _menu.detail()]:
		assert_false(line.to_lower().contains("stand"), line)


func test_the_deal_animates_card_by_card_and_refuses_actions_meanwhile() -> void:
	_menu.show_hand(_live().view(), 0, 50)
	assert_true(_menu.animating())
	assert_lt(_menu.shown_player_cards().size(), 2, "the cards arrive one at a time")
	for b: Dictionary in _menu.stage_buttons():
		assert_false(bool(b["enabled"]), "%s waits for the deal" % b["id"])
	_menu.finish_animation()
	assert_false(_menu.animating())
	assert_eq(_menu.shown_player_cards().size(), 2)


## The banner's words stay inside its plate at every text size.
func test_the_banner_text_fits_its_box_at_every_text_size() -> void:
	var font: Font = MenuStyleScript.title_font()
	var box: Rect2 = _menu.banner_rect()
	for scale: float in [1.0, 1.25, 1.5]:
		MenuStyleScript.text_scale = scale
		for ending: int in range(1, RoundScript.Ending.TIE + 1):
			var words: String = RoundScript.headline(ending)
			var px: int = PaintScript.fit_size(font, words, 50, box.size.x - 48.0 - 150.0)
			assert_lte(font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x,
				box.size.x - 48.0 - 150.0, "%s at %.2f" % [words, scale])
	MenuStyleScript.text_scale = 1.0


## WALKING AWAY MID HAND STANDS FOR HER rather than leaving her stake in limbo.
func test_closing_mid_hand_asks_ranch_to_stand() -> void:
	_push(_live())
	watch_signals(_menu)
	_menu.close()
	assert_signal_emit_count(_menu, "action_requested", 1)
	assert_eq(get_signal_parameters(_menu, "action_requested", 0)[0], RoundScript.Action.STAND)


func test_the_rules_tab_is_a_real_tab_with_nothing_to_press() -> void:
	_menu.take_tab(BlackjackMenu.Tab.RULES)
	assert_eq(_menu.tab(), BlackjackMenu.Tab.RULES)
	assert_eq(_menu.stage_buttons().size(), 0)
	assert_eq(MouseRowsScript.active_tab(_menu.get_node("Centre/Panel/Margin/Column/Tabs")), 1)


func test_a_broken_push_is_a_still_frame() -> void:
	_menu.show_hand({}, 0, 10)
	_menu.show_hand({"player": [300, -4], "dealer": []}, 0, 10)
	assert_false(_menu.animating())
	assert_false(_menu.hand_live())


func test_nothing_it_draws_carries_a_dash() -> void:
	for line: String in _menu.drawn_lines():
		assert_false(line.contains("--") or line.contains("—"), line)
