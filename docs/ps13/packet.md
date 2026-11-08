# PS13 acceptance packet

For each item: the owner's words (docs/playtest-2026-11-05.md), the owner's screenshot tags, and the evidence to judge it by. Judge each MET or NOT-MET from the evidence and the code alone. A missing render, or a test that does not assert what the owner asked for, is NOT-MET.

## 1

**Owner:** Fullscreen set during loading snaps back small on ranch load (ranch.gd apply_graphics -> apply_window forces the saved mode).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Tests:** test_fullscreen_kept

## 2

**Owner:** A Random button in the pony creator.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png

**Tests:** none

## 3

**Owner:** Better cutie mark creation.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item3/, build/ps_evidence/item3/creator_stamps.png, build/ps_evidence/item3/flank_stamped_mark.png, build/ps_evidence/item3/flank_surprise_mark.png

**Tests:** test_mark_layout, test_mark_canvas_stamps

## 4

**Owner:** Mane style isn't under the "Mane and tail" tab.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png

**Tests:** none

## 5

**Owner:** The mane streak option is always shown though it's rarely used.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png

**Tests:** none

## 6

**Owner:** More customisation.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** game/scenes/test/style_icons.gd, tools/blender_props/build_props.py, build/ps_evidence/item6/, build/ps_evidence/item6/accessories.png, build/ps_evidence/item6/cards.png, build/ps_evidence/item6/eyes.png, build/ps_evidence/item6/goggles_close.png, build/ps_evidence/item6/hat_every_mane.png, build/ps_evidence/item6/sheet_side.png, build/ps_evidence/item6/style_step_bags.png, build/ps_evidence/item6/style_step_hat.png, build/ps_evidence/item6/tuned.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Finishing touches"

**Tests:** test_pony_customisation, test_creation_style_step, test_creation_screen

## 7

**Owner:** Creator: spinning the pony makes the mane fly spiky and the tail clip the body (hair springs react to the spin).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/creator_spin_a/b/c.png

**Tests:** none

## 8

**Owner:** The welcome letter: a text wall, empty right side, "Enter close" plus Close.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item8/before/welcome_letter.png, build/ps_evidence/item8/before/mailbox_survey.png, build/ps_evidence/item8/before/market_buy_decor_a.png, build/ps_evidence/item8/before/market_buy_decor_b.png, build/ps_evidence/item8/before/market_buy_decor_c.png

**Tests:** test_letter_panel, test_the_welcome_letters_four_steps_are_four_rows_not_one_paragraph, test_every_button_on_the_sheet_is_ink_on_paper_not_white_on_cream

## 9

**Owner:** Player tail stutters between frames while walking.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item9/tail_measure.txt, build/ps_evidence/item9/strip144_before_pt11.png, build/ps_evidence/item9/strip144_after.png

**Tests:** test_player_draw_between_ticks

## 10

**Owner:** A pony walked through the conversation.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item10/crossing_strip.png, build/ps_evidence/item10/crossing_positions.txt

**Tests:** test_conversation_space

## 11

**Owner:** Pip's "Rainbow Factory / cloud line's for staff only" line is confusing.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item16/guide_log.txt, build/ps_evidence/item16/item16_step0_letter.png, build/ps_evidence/item16/item16_step0_mail_as_she_stands.png, build/ps_evidence/item16/item16_step5_catch_as_she_stands.png, build/ps_evidence/item16/item16_step5_catch_from_above.png, build/ps_evidence/item16/item16_step5_catch_turned_to_goal.png, build/ps_evidence/item16/steps_sheet.png, build/ps_evidence/item16/after/guide_log.txt, build/ps_evidence/item16/after/item16_step0_catch_as_she_stands.png, build/ps_evidence/item16/after/item16_step0_catch_from_above.png, build/ps_evidence/item16/after/item16_step0_catch_turned_to_goal.png, build/ps_evidence/item16/after/step0_pair.png

**Text quoted in the evidence (the shipped words, or the owner's):** "See the rainbow over the hills? Cloudsdale makes those. Prettiest thing in the valley, if you ask me." / "I asked to fly a bundle up myself once. Cloudsdale said the cloud line's staff only, for my safety. Very nicely, they said it."

**Tests:** none

## 12

**Owner:** Can't pause during a conversation.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Tests:** test_pause_in_talk

## 13

**Owner:** Tumble spawned mid-conversation, inside the player.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item13/join_strip.png, build/ps_evidence/item13/join_distances.txt

**Text quoted in the evidence (the shipped words, or the owner's):** "E: talk to Tumble"

**Tests:** test_tumble_arrives

## 14

**Owner:** Signs flicker on and off almost everywhere (the fingerpost's Home and Pens boards go dark; PlaceSign blocking-fade toggling) [32].

**Owner's screenshots:** [32]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/shots/item14_shot32_fingerpost_day.png, build/ps_evidence/batch/shots/item14_shot32_fingerpost_night_rain.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_day.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_night_rain.png, build/ps_evidence/batch/shots/item17_shot21_plaza_palace_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_night_rain.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_day.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_night_rain.png, build/ps_evidence/batch/shots/item29_shot27_market_door_day.png, build/ps_evidence/batch/shots/item29_shot27_market_door_night_rain.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_day.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_night_rain.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_day.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_night_rain.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_day.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_night_rain.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_day.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_night_rain.png, build/ps_evidence/batch/shots/item37_shot34_strip_day.png, build/ps_evidence/batch/shots/item37_shot34_strip_night_rain.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_day.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_night_rain.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_day.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_night_rain.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_day.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_night_rain.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_day.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_night_rain.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_day.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_night_rain.png, build/ps_evidence/batch/shots/run.log

**Tests:** test_place_sign_fade

## 15

**Owner:** Old Fennel says there's a pony in the bag when there isn't.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item16/guide_log.txt, build/ps_evidence/item16/item16_step0_letter.png, build/ps_evidence/item16/item16_step0_mail_as_she_stands.png, build/ps_evidence/item16/item16_step5_catch_as_she_stands.png, build/ps_evidence/item16/item16_step5_catch_from_above.png, build/ps_evidence/item16/item16_step5_catch_turned_to_goal.png, build/ps_evidence/item16/steps_sheet.png, build/ps_evidence/item16/after/guide_log.txt, build/ps_evidence/item16/after/item16_step0_catch_as_she_stands.png, build/ps_evidence/item16/after/item16_step0_catch_from_above.png, build/ps_evidence/item16/after/item16_step0_catch_turned_to_goal.png, build/ps_evidence/item16/after/step0_pair.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Catch yourself a Drifter and she'll need somewhere to go. That's a pen plot by your porch. Build on it, and let her out inside."

**Tests:** none

## 16

**Owner:** The start doesn't show where to go for a first catch; after that, catchable ponies are clear.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item16/steps_sheet.png, build/ps_evidence/item16/after/, build/ps_evidence/item16/guide_log.txt, build/ps_evidence/item16/item16_step0_letter.png, build/ps_evidence/item16/item16_step0_mail_as_she_stands.png, build/ps_evidence/item16/item16_step5_catch_as_she_stands.png, build/ps_evidence/item16/item16_step5_catch_from_above.png, build/ps_evidence/item16/item16_step5_catch_turned_to_goal.png, build/ps_evidence/item16/after/guide_log.txt, build/ps_evidence/item16/after/item16_step0_catch_as_she_stands.png, build/ps_evidence/item16/after/item16_step0_catch_from_above.png, build/ps_evidence/item16/after/item16_step0_catch_turned_to_goal.png, build/ps_evidence/item16/after/step0_pair.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Read your new letter 6 m" / "Somepony has news" / "Catch a Drifter 7 m" / "Hold Right Mouse on a pony to Scoop her up" / "). After render, step 0 straight after the welcome: build/ps_evidence/item16/after/ (step0_pair.png: "

**Tests:** test_guide, test_the_first_task_points_at_a_wild_pony, test_the_first_catch_beats_the_mail_and_the_news

## 17

**Owner:** Twilight twisted at a broken angle, twice [21][52]. Likely retarget/HoofPlanter on the Mane Six rig. TOP PRIORITY.

**Owner's screenshots:** [21] [52]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item17/neck_tries.png, build/ps_evidence/item65/corner_compare.png, build/ps_evidence/item17/before_after_neck.png, build/ps_evidence/item17/before_after_neck_zoom.png, build/ps_evidence/item17/pen_after_sheet.png, build/ps_evidence/item17/pen_pile_zoom.png, build/ps_evidence/item17/clips_after/cower_2.png, build/ps_evidence/item17/clips_after/cower_5.png, build/ps_evidence/item17/clips_after/cower_8.png, build/ps_evidence/item17/clips_after/gallop_2.png, build/ps_evidence/item17/clips_after/gallop_5.png, build/ps_evidence/item17/clips_after/gallop_8.png, build/ps_evidence/item17/clips_after/graze_2.png, build/ps_evidence/item17/clips_after/graze_5.png, build/ps_evidence/item17/clips_after/graze_8.png, build/ps_evidence/item17/clips_after/hop_2.png, build/ps_evidence/item17/clips_after/hop_5.png, build/ps_evidence/item17/clips_after/hop_8.png, build/ps_evidence/item17/clips_after/idle_2.png, build/ps_evidence/item17/clips_after/idle_5.png, build/ps_evidence/item17/clips_after/idle_8.png, build/ps_evidence/item17/clips_after/jump_2.png, build/ps_evidence/item17/clips_after/jump_5.png, build/ps_evidence/item17/clips_after/jump_8.png, build/ps_evidence/item17/clips_after/laugh_2.png, build/ps_evidence/item17/clips_after/laugh_5.png, build/ps_evidence/item17/clips_after/laugh_8.png, build/ps_evidence/item17/clips_after/lie_2.png, build/ps_evidence/item17/clips_after/lie_5.png, build/ps_evidence/item17/clips_after/lie_8.png, build/ps_evidence/item17/clips_after/look_2.png, build/ps_evidence/item17/clips_after/look_5.png, build/ps_evidence/item17/clips_after/look_8.png, build/ps_evidence/item17/clips_after/nod_2.png, build/ps_evidence/item17/clips_after/nod_5.png, build/ps_evidence/item17/clips_after/nod_8.png, build/ps_evidence/item17/clips_after/rear_2.png, build/ps_evidence/item17/clips_after/rear_5.png, build/ps_evidence/item17/clips_after/rear_8.png, build/ps_evidence/item17/clips_after/sad_2.png, build/ps_evidence/item17/clips_after/sad_5.png, build/ps_evidence/item17/clips_after/sad_8.png, build/ps_evidence/item17/clips_after/shake_2.png, build/ps_evidence/item17/clips_after/shake_5.png, build/ps_evidence/item17/clips_after/shake_8.png, build/ps_evidence/item17/clips_after/sit_2.png, build/ps_evidence/item17/clips_after/sit_5.png, build/ps_evidence/item17/clips_after/sit_8.png, build/ps_evidence/item17/clips_after/sleep_2.png, build/ps_evidence/item17/clips_after/sleep_5.png, build/ps_evidence/item17/clips_after/sleep_8.png, build/ps_evidence/item17/clips_after/startle_2.png, build/ps_evidence/item17/clips_after/startle_5.png, build/ps_evidence/item17/clips_after/startle_8.png, build/ps_evidence/item17/clips_after/struggle_2.png, build/ps_evidence/item17/clips_after/struggle_5.png, build/ps_evidence/item17/clips_after/struggle_8.png, build/ps_evidence/item17/clips_after/talk_2.png, build/ps_evidence/item17/clips_after/talk_5.png, build/ps_evidence/item17/clips_after/talk_8.png, build/ps_evidence/item17/clips_after/walk_2.png, build/ps_evidence/item17/clips_after/walk_5.png, build/ps_evidence/item17/clips_after/walk_8.png, build/ps_evidence/item17/pen_after/grand_night_t0.png, build/ps_evidence/item17/pen_after/grand_night_t15.png, build/ps_evidence/item17/pen_after/grand_night_t30.png, build/ps_evidence/item17/pen_after/grand_night_t45.png, build/ps_evidence/item17/pen_after/grand_night_t60.png, build/ps_evidence/item17/pen_after/grand_night_t75.png, build/ps_evidence/item17/probe_before/dropped_@CharacterBody3D@1640_TongueRoot_58.png, build/ps_evidence/item17/probe_before/dropped_@CharacterBody3D@1642_DEF_Head_80.png, build/ps_evidence/item17/probe_before/held_@CharacterBody3D@1638_DEF_Head_81.png, build/ps_evidence/item17/probe_before/held_@CharacterBody3D@1640_TongueRoot_72.png, build/ps_evidence/item17/probe_before/held_@CharacterBody3D@1644_DEF_Head_73.png, build/ps_evidence/item17/probe_before/held_@CharacterBody3D@1646_DEF_Head_75.png, build/ps_evidence/item17/probe_before/held_Pony_DEF_Head_78.png, build/ps_evidence/item17/probe_before/pen_Pony_pinkiepie_000006_Head_52.png, build/ps_evidence/item17/probe_before/pen_Pony_rarity_000005_DEF_Head_50.png, build/ps_evidence/item17/probe_before/pen_end.png, build/ps_evidence/item17/probe_before/pen_t0.png, build/ps_evidence/item17/probe_before/pen_t30.png, build/ps_evidence/item17/probe_before/pen_t60.png, build/ps_evidence/item17/probe_before/pen_t90.png, build/ps_evidence/item17/probe_before/wild_@CharacterBody3D@1640_TongueRoot_53.png, build/ps_evidence/item17/probe_before/wild_@CharacterBody3D@1642_DEF_Head_50.png, build/ps_evidence/item17/probe_before/wild_@CharacterBody3D@1644_DEF_Head_65.png, build/ps_evidence/item17/probe_before/wild_@CharacterBody3D@1646_DEF_Head_53.png, build/ps_evidence/item17/probe_before/wild_Pony_DEF_Head_51.png, build/ps_evidence/item17/clips_lyra/cower_2.png, build/ps_evidence/item17/clips_lyra/cower_5.png, build/ps_evidence/item17/clips_lyra/cower_8.png, build/ps_evidence/item17/clips_lyra/gallop_2.png, build/ps_evidence/item17/clips_lyra/gallop_5.png, build/ps_evidence/item17/clips_lyra/gallop_8.png, build/ps_evidence/item17/clips_lyra/graze_2.png, build/ps_evidence/item17/clips_lyra/graze_5.png, build/ps_evidence/item17/clips_lyra/graze_8.png, build/ps_evidence/item17/clips_lyra/hop_2.png, build/ps_evidence/item17/clips_lyra/hop_5.png, build/ps_evidence/item17/clips_lyra/hop_8.png, build/ps_evidence/item17/clips_lyra/idle_2.png, build/ps_evidence/item17/clips_lyra/idle_5.png, build/ps_evidence/item17/clips_lyra/idle_8.png, build/ps_evidence/item17/clips_lyra/jump_2.png, build/ps_evidence/item17/clips_lyra/jump_5.png, build/ps_evidence/item17/clips_lyra/jump_8.png, build/ps_evidence/item17/clips_lyra/laugh_2.png, build/ps_evidence/item17/clips_lyra/laugh_5.png, build/ps_evidence/item17/clips_lyra/laugh_8.png, build/ps_evidence/item17/clips_lyra/lie_2.png, build/ps_evidence/item17/clips_lyra/lie_5.png, build/ps_evidence/item17/clips_lyra/lie_8.png, build/ps_evidence/item17/clips_lyra/look_2.png, build/ps_evidence/item17/clips_lyra/look_5.png, build/ps_evidence/item17/clips_lyra/look_8.png, build/ps_evidence/item17/clips_lyra/nod_2.png, build/ps_evidence/item17/clips_lyra/nod_5.png, build/ps_evidence/item17/clips_lyra/nod_8.png, build/ps_evidence/item17/clips_lyra/rear_2.png, build/ps_evidence/item17/clips_lyra/rear_5.png, build/ps_evidence/item17/clips_lyra/rear_8.png, build/ps_evidence/item17/clips_lyra/sad_2.png, build/ps_evidence/item17/clips_lyra/sad_5.png, build/ps_evidence/item17/clips_lyra/sad_8.png, build/ps_evidence/item17/clips_lyra/shake_2.png, build/ps_evidence/item17/clips_lyra/shake_5.png, build/ps_evidence/item17/clips_lyra/shake_8.png, build/ps_evidence/item17/clips_lyra/sit_2.png, build/ps_evidence/item17/clips_lyra/sit_5.png, build/ps_evidence/item17/clips_lyra/sit_8.png, build/ps_evidence/item17/clips_lyra/sleep_2.png, build/ps_evidence/item17/clips_lyra/sleep_5.png, build/ps_evidence/item17/clips_lyra/sleep_8.png, build/ps_evidence/item17/clips_lyra/startle_2.png, build/ps_evidence/item17/clips_lyra/startle_5.png, build/ps_evidence/item17/clips_lyra/startle_8.png, build/ps_evidence/item17/clips_lyra/struggle_2.png, build/ps_evidence/item17/clips_lyra/struggle_5.png, build/ps_evidence/item17/clips_lyra/struggle_8.png, build/ps_evidence/item17/clips_lyra/talk_2.png, build/ps_evidence/item17/clips_lyra/talk_5.png, build/ps_evidence/item17/clips_lyra/talk_8.png, build/ps_evidence/item17/clips_lyra/trot_2.png, build/ps_evidence/item17/clips_lyra/trot_5.png, build/ps_evidence/item17/clips_lyra/trot_8.png, build/ps_evidence/item17/clips_lyra/walk_2.png, build/ps_evidence/item17/clips_lyra/walk_5.png, build/ps_evidence/item17/clips_lyra/walk_8.png, build/ps_evidence/item17/try_0.7_1.0/cower_2.png, build/ps_evidence/item17/try_0.7_1.0/cower_5.png, build/ps_evidence/item17/try_0.7_1.0/cower_8.png, build/ps_evidence/item17/try_0.7_1.0/gallop_2.png, build/ps_evidence/item17/try_0.7_1.0/gallop_5.png, build/ps_evidence/item17/try_0.7_1.0/gallop_8.png, build/ps_evidence/item17/try_0.7_1.0/graze_2.png, build/ps_evidence/item17/try_0.7_1.0/graze_5.png, build/ps_evidence/item17/try_0.7_1.0/graze_8.png, build/ps_evidence/item17/try_0.7_1.0/hop_2.png, build/ps_evidence/item17/try_0.7_1.0/hop_5.png, build/ps_evidence/item17/try_0.7_1.0/hop_8.png, build/ps_evidence/item17/try_0.7_1.0/idle_2.png, build/ps_evidence/item17/try_0.7_1.0/idle_5.png, build/ps_evidence/item17/try_0.7_1.0/idle_8.png, build/ps_evidence/item17/try_0.7_1.0/jump_2.png, build/ps_evidence/item17/try_0.7_1.0/jump_5.png, build/ps_evidence/item17/try_0.7_1.0/jump_8.png, build/ps_evidence/item17/try_0.7_1.0/laugh_2.png, build/ps_evidence/item17/try_0.7_1.0/laugh_5.png, build/ps_evidence/item17/try_0.7_1.0/laugh_8.png, build/ps_evidence/item17/try_0.7_1.0/lie_2.png, build/ps_evidence/item17/try_0.7_1.0/lie_5.png, build/ps_evidence/item17/try_0.7_1.0/lie_8.png, build/ps_evidence/item17/try_0.7_1.0/look_2.png, build/ps_evidence/item17/try_0.7_1.0/look_5.png, build/ps_evidence/item17/try_0.7_1.0/look_8.png, build/ps_evidence/item17/try_0.7_1.0/nod_2.png, build/ps_evidence/item17/try_0.7_1.0/nod_5.png, build/ps_evidence/item17/try_0.7_1.0/nod_8.png, build/ps_evidence/item17/try_0.7_1.0/rear_2.png, build/ps_evidence/item17/try_0.7_1.0/rear_5.png, build/ps_evidence/item17/try_0.7_1.0/rear_8.png, build/ps_evidence/item17/try_0.7_1.0/sad_2.png, build/ps_evidence/item17/try_0.7_1.0/sad_5.png, build/ps_evidence/item17/try_0.7_1.0/sad_8.png, build/ps_evidence/item17/try_0.7_1.0/shake_2.png, build/ps_evidence/item17/try_0.7_1.0/shake_5.png, build/ps_evidence/item17/try_0.7_1.0/shake_8.png, build/ps_evidence/item17/try_0.7_1.0/sit_2.png, build/ps_evidence/item17/try_0.7_1.0/sit_5.png, build/ps_evidence/item17/try_0.7_1.0/sit_8.png, build/ps_evidence/item17/try_0.7_1.0/sleep_2.png, build/ps_evidence/item17/try_0.7_1.0/sleep_5.png, build/ps_evidence/item17/try_0.7_1.0/sleep_8.png, build/ps_evidence/item17/try_0.7_1.0/startle_2.png, build/ps_evidence/item17/try_0.7_1.0/startle_5.png, build/ps_evidence/item17/try_0.7_1.0/startle_8.png, build/ps_evidence/item17/try_0.7_1.0/struggle_2.png, build/ps_evidence/item17/try_0.7_1.0/struggle_5.png, build/ps_evidence/item17/try_0.7_1.0/struggle_8.png, build/ps_evidence/item17/try_0.7_1.0/talk_2.png, build/ps_evidence/item17/try_0.7_1.0/talk_5.png, build/ps_evidence/item17/try_0.7_1.0/talk_8.png, build/ps_evidence/item17/try_0.7_1.0/walk_2.png, build/ps_evidence/item17/try_0.7_1.0/walk_5.png, build/ps_evidence/item17/try_0.7_1.0/walk_8.png, build/ps_evidence/item17/try_0.5_0.9/cower_2.png, build/ps_evidence/item17/try_0.5_0.9/cower_5.png, build/ps_evidence/item17/try_0.5_0.9/cower_8.png, build/ps_evidence/item17/try_0.5_0.9/gallop_2.png, build/ps_evidence/item17/try_0.5_0.9/gallop_5.png, build/ps_evidence/item17/try_0.5_0.9/gallop_8.png, build/ps_evidence/item17/try_0.5_0.9/graze_2.png, build/ps_evidence/item17/try_0.5_0.9/graze_5.png, build/ps_evidence/item17/try_0.5_0.9/graze_8.png, build/ps_evidence/item17/try_0.5_0.9/hop_2.png, build/ps_evidence/item17/try_0.5_0.9/hop_5.png, build/ps_evidence/item17/try_0.5_0.9/hop_8.png, build/ps_evidence/item17/try_0.5_0.9/idle_2.png, build/ps_evidence/item17/try_0.5_0.9/idle_5.png, build/ps_evidence/item17/try_0.5_0.9/idle_8.png, build/ps_evidence/item17/try_0.5_0.9/jump_2.png, build/ps_evidence/item17/try_0.5_0.9/jump_5.png, build/ps_evidence/item17/try_0.5_0.9/jump_8.png, build/ps_evidence/item17/try_0.5_0.9/laugh_2.png, build/ps_evidence/item17/try_0.5_0.9/laugh_5.png, build/ps_evidence/item17/try_0.5_0.9/laugh_8.png, build/ps_evidence/item17/try_0.5_0.9/lie_2.png, build/ps_evidence/item17/try_0.5_0.9/lie_5.png, build/ps_evidence/item17/try_0.5_0.9/lie_8.png, build/ps_evidence/item17/try_0.5_0.9/look_2.png, build/ps_evidence/item17/try_0.5_0.9/look_5.png, build/ps_evidence/item17/try_0.5_0.9/look_8.png, build/ps_evidence/item17/try_0.5_0.9/nod_2.png, build/ps_evidence/item17/try_0.5_0.9/nod_5.png, build/ps_evidence/item17/try_0.5_0.9/nod_8.png, build/ps_evidence/item17/try_0.5_0.9/rear_2.png, build/ps_evidence/item17/try_0.5_0.9/rear_5.png, build/ps_evidence/item17/try_0.5_0.9/rear_8.png, build/ps_evidence/item17/try_0.5_0.9/sad_2.png, build/ps_evidence/item17/try_0.5_0.9/sad_5.png, build/ps_evidence/item17/try_0.5_0.9/sad_8.png, build/ps_evidence/item17/try_0.5_0.9/shake_2.png, build/ps_evidence/item17/try_0.5_0.9/shake_5.png, build/ps_evidence/item17/try_0.5_0.9/shake_8.png, build/ps_evidence/item17/try_0.5_0.9/sit_2.png, build/ps_evidence/item17/try_0.5_0.9/sit_5.png, build/ps_evidence/item17/try_0.5_0.9/sit_8.png, build/ps_evidence/item17/try_0.5_0.9/sleep_2.png, build/ps_evidence/item17/try_0.5_0.9/sleep_5.png, build/ps_evidence/item17/try_0.5_0.9/sleep_8.png, build/ps_evidence/item17/try_0.5_0.9/startle_2.png, build/ps_evidence/item17/try_0.5_0.9/startle_5.png, build/ps_evidence/item17/try_0.5_0.9/startle_8.png, build/ps_evidence/item17/try_0.5_0.9/struggle_2.png, build/ps_evidence/item17/try_0.5_0.9/struggle_5.png, build/ps_evidence/item17/try_0.5_0.9/struggle_8.png, build/ps_evidence/item17/try_0.5_0.9/talk_2.png, build/ps_evidence/item17/try_0.5_0.9/talk_5.png, build/ps_evidence/item17/try_0.5_0.9/talk_8.png, build/ps_evidence/item17/try_0.5_0.9/walk_2.png, build/ps_evidence/item17/try_0.5_0.9/walk_5.png, build/ps_evidence/item17/try_0.5_0.9/walk_8.png, build/ps_evidence/item17/probe_before2/pen_end.png, build/ps_evidence/item17/probe_before2/pen_t0.png, build/ps_evidence/item17/probe_before2/pen_t30.png, build/ps_evidence/item17/probe_before2/pen_t60.png, build/ps_evidence/item17/probe_before2/pen_t90.png, build/ps_evidence/item17/clips/cower_2.png, build/ps_evidence/item17/clips/cower_5.png, build/ps_evidence/item17/clips/cower_8.png, build/ps_evidence/item17/clips/gallop_2.png, build/ps_evidence/item17/clips/gallop_5.png, build/ps_evidence/item17/clips/gallop_8.png, build/ps_evidence/item17/clips/graze_2.png, build/ps_evidence/item17/clips/graze_5.png, build/ps_evidence/item17/clips/graze_8.png, build/ps_evidence/item17/clips/hop_2.png, build/ps_evidence/item17/clips/hop_5.png, build/ps_evidence/item17/clips/hop_8.png, build/ps_evidence/item17/clips/idle_2.png, build/ps_evidence/item17/clips/idle_5.png, build/ps_evidence/item17/clips/idle_8.png, build/ps_evidence/item17/clips/jump_2.png, build/ps_evidence/item17/clips/jump_5.png, build/ps_evidence/item17/clips/jump_8.png, build/ps_evidence/item17/clips/laugh_2.png, build/ps_evidence/item17/clips/laugh_5.png, build/ps_evidence/item17/clips/laugh_8.png, build/ps_evidence/item17/clips/lie_2.png, build/ps_evidence/item17/clips/lie_5.png, build/ps_evidence/item17/clips/lie_8.png, build/ps_evidence/item17/clips/look_2.png, build/ps_evidence/item17/clips/look_5.png, build/ps_evidence/item17/clips/look_8.png, build/ps_evidence/item17/clips/nod_2.png, build/ps_evidence/item17/clips/nod_5.png, build/ps_evidence/item17/clips/nod_8.png, build/ps_evidence/item17/clips/rear_2.png, build/ps_evidence/item17/clips/rear_5.png, build/ps_evidence/item17/clips/rear_8.png, build/ps_evidence/item17/clips/sad_2.png, build/ps_evidence/item17/clips/sad_5.png, build/ps_evidence/item17/clips/sad_8.png, build/ps_evidence/item17/clips/shake_2.png, build/ps_evidence/item17/clips/shake_5.png, build/ps_evidence/item17/clips/shake_8.png, build/ps_evidence/item17/clips/sit_2.png, build/ps_evidence/item17/clips/sit_5.png, build/ps_evidence/item17/clips/sit_8.png, build/ps_evidence/item17/clips/sleep_2.png, build/ps_evidence/item17/clips/sleep_5.png, build/ps_evidence/item17/clips/sleep_8.png, build/ps_evidence/item17/clips/startle_2.png, build/ps_evidence/item17/clips/startle_5.png, build/ps_evidence/item17/clips/startle_8.png, build/ps_evidence/item17/clips/struggle_2.png, build/ps_evidence/item17/clips/struggle_5.png, build/ps_evidence/item17/clips/struggle_8.png, build/ps_evidence/item17/clips/talk_2.png, build/ps_evidence/item17/clips/talk_5.png, build/ps_evidence/item17/clips/talk_8.png, build/ps_evidence/item17/clips/walk_2.png, build/ps_evidence/item17/clips/walk_5.png, build/ps_evidence/item17/clips/walk_8.png, build/ps_evidence/item65/corner_before_t75.png, build/ps_evidence/item65/day_compare.png, build/ps_evidence/item65/corner_after/grand_night_t0.png, build/ps_evidence/item65/corner_after/grand_night_t15.png, build/ps_evidence/item65/corner_after/grand_night_t30.png, build/ps_evidence/item65/corner_after/grand_night_t45.png, build/ps_evidence/item65/corner_after/grand_night_t60.png, build/ps_evidence/item65/corner_after/grand_night_t75.png, build/ps_evidence/item65/day_after/grand_night_t0.png, build/ps_evidence/item65/day_after/grand_night_t15.png, build/ps_evidence/item65/day_after/grand_night_t30.png, build/ps_evidence/item65/day_after/grand_night_t45.png, build/ps_evidence/item65/day_after/grand_night_t60.png, build/ps_evidence/item65/day_after/grand_night_t75.png, build/ps_evidence/item65/after_review_day/godot.log, build/ps_evidence/item65/after_review_day/grand_night_t0.png, build/ps_evidence/item65/after_review_day/grand_night_t15.png, build/ps_evidence/item65/after_review_day/grand_night_t30.png, build/ps_evidence/item65/after_review_day/grand_night_t45.png, build/ps_evidence/item65/after_review_day/grand_night_t60.png, build/ps_evidence/item65/after_review_day/grand_night_t75.png, build/ps_evidence/item65/after_review_day/run.log, build/ps_evidence/item65/day_before/grand_night_t0.png, build/ps_evidence/item65/day_before/grand_night_t15.png, build/ps_evidence/item65/day_before/grand_night_t30.png, build/ps_evidence/item65/day_before/grand_night_t45.png, build/ps_evidence/item65/day_before/grand_night_t60.png, build/ps_evidence/item65/day_before/grand_night_t75.png, build/ps_evidence/item65/corner_before/grand_night_t0.png, build/ps_evidence/item65/corner_before/grand_night_t15.png, build/ps_evidence/item65/corner_before/grand_night_t30.png, build/ps_evidence/item65/corner_before/grand_night_t45.png, build/ps_evidence/item65/corner_before/grand_night_t60.png, build/ps_evidence/item65/corner_before/grand_night_t75.png, build/ps_evidence/item65/after_review_night/godot.log, build/ps_evidence/item65/after_review_night/grand_night_t0.png, build/ps_evidence/item65/after_review_night/grand_night_t15.png, build/ps_evidence/item65/after_review_night/grand_night_t30.png, build/ps_evidence/item65/after_review_night/grand_night_t45.png, build/ps_evidence/item65/after_review_night/grand_night_t60.png, build/ps_evidence/item65/after_review_night/grand_night_t75.png, build/ps_evidence/item65/after_review_night/run.log

**Tests:** test_mane_six_neck, test_pen_spread, test_pony, test_a_curious_resident_turns_to_watch_her_farmer_and_stays_put

## 17b

**Owner:** Ponies merge into each other (wild vs wild, a brown pony inside a purple one) [19][54].

**Owner's screenshots:** [19] [54]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item17b/after_turn_rule_closest_pair.png, build/ps_evidence/item17b/merge_compare.png, build/ps_evidence/item17b/touch_sheet.png, build/ps_evidence/item17b/touch_sheet2.png, build/ps_evidence/item17b/touch_sheet3.png, build/ps_evidence/item17b/probe_after_turn/closest_0_gap0.06.png, build/ps_evidence/item17b/probe_after_turn/closest_1_gap0.01.png, build/ps_evidence/item17b/probe_after_turn/closest_2_gap-0.32.png, build/ps_evidence/item17b/probe_after/closest_0_gap0.02.png, build/ps_evidence/item17b/probe_after/closest_1_gap-0.06.png, build/ps_evidence/item17b/probe_after/closest_2_gap-0.31.png, build/ps_evidence/item17b/probe_touch3/closest_0_gap0.04.png, build/ps_evidence/item17b/probe_touch3/closest_1_gap-0.11.png, build/ps_evidence/item17b/probe_before/closest_0_gap34.71.png, build/ps_evidence/item17b/probe_before/closest_1_gap23.98.png, build/ps_evidence/item17b/probe_before/closest_2_gap22.82.png, build/ps_evidence/item17b/probe_touch2/closest_0_gap0.04.png, build/ps_evidence/item17b/probe_touch2/closest_1_gap-0.10.png, build/ps_evidence/item17b/probe_touch/closest_0_gap0.04.png, build/ps_evidence/item17b/probe_touch/closest_1_gap-0.11.png, build/ps_evidence/item17b/probe_touch/closest_2_gap-0.21.png

**Tests:** test_wild_no_merge

## 18

**Owner:** Tumble gets in the way at catch time: in front of the camera, and her talk prompt steals E.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item18/heel_after_swings.png, build/ps_evidence/item18/heel_positions.txt

**Tests:** test_heel_out_of_shot

## 19/23

**Owner:** The rump bounce is barely seen: it only fires on a pen flop or a hard landing, and ponies land facing you in the paddock.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item19/pen_hops_from_beside.png, build/ps_evidence/item19/close_rest_and_peak.png, build/ps_evidence/item19/hop_count.txt

**Tests:** test_joy_hop

## 20

**Owner:** Text is too thick: heavy outlined lettering on cards and the HUD [22].

**Owner's screenshots:** [22]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 21

**Owner:** Dropping a pony from the beam at height should trigger the rump bounce; it doesn't.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item21/drop_strip.png, build/ps_evidence/item21/drop_ticks.txt, build/ps_evidence/item21/item21_t057_amt+0.000.png, build/ps_evidence/item21/item21_t060_amt-0.127.png, build/ps_evidence/item21/item21_t076_amt+0.103.png

**Tests:** test_rump_bounce, test_a_pony_dropped_from_a_height_bounces_on_landing

## 22

**Owner:** Catch card covers the checklist strip; the strip still shows a sentence, not chips [22].

**Owner's screenshots:** [22]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 24

**Owner:** Objective card lands on top of the "Getting started" chips [23].

**Owner's screenshots:** [23]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 25

**Owner:** The overgrown-plot brambles are a field of big green blobs [24].

**Owner's screenshots:** [24]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_day.png, build/ps_evidence/batch/shots/item14_shot32_fingerpost_day.png, build/ps_evidence/batch/shots/item14_shot32_fingerpost_night_rain.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_day.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_night_rain.png, build/ps_evidence/batch/shots/item17_shot21_plaza_palace_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_night_rain.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_day.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_night_rain.png, build/ps_evidence/batch/shots/item29_shot27_market_door_day.png, build/ps_evidence/batch/shots/item29_shot27_market_door_night_rain.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_day.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_night_rain.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_day.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_night_rain.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_day.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_night_rain.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_day.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_night_rain.png, build/ps_evidence/batch/shots/item37_shot34_strip_day.png, build/ps_evidence/batch/shots/item37_shot34_strip_night_rain.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_day.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_night_rain.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_day.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_night_rain.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_day.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_night_rain.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_day.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_night_rain.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_day.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_night_rain.png, build/ps_evidence/batch/shots/run.log

**Tests:** none

## 26

**Owner:** "CLEAR ME / 250 bits" signs: dark on brown, no light backing, unreadable [24].

**Owner's screenshots:** [24]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item26/sign_at_10m_close.png, build/ps_evidence/item26/sign_day_10m.png

**Text quoted in the evidence (the shipped words, or the owner's):** "); the [24] pose looks down at the plot and never had the sign in frame (the batch check's " / "). The post now stops at the board's bottom edge (plot_slot.gd). Test: test_clear_sign_reads (failed before: post top 2.25 m, board bottom 1.78 m). Render at eye height 10 m off, HUD hidden: build/ps_evidence/item26/sign_at_10m_close.png ("

**Tests:** test_clear_sign_reads

## 27

**Owner:** A flat yellow blob prop on the grass, unidentified [25].

**Owner's screenshots:** [25]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/shots/item25_shot25_yellow_blob_day.png, build/ps_evidence/batch/shots/item14_shot32_fingerpost_day.png, build/ps_evidence/batch/shots/item14_shot32_fingerpost_night_rain.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_day.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_night_rain.png, build/ps_evidence/batch/shots/item17_shot21_plaza_palace_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_night_rain.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_night_rain.png, build/ps_evidence/batch/shots/item29_shot27_market_door_day.png, build/ps_evidence/batch/shots/item29_shot27_market_door_night_rain.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_day.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_night_rain.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_day.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_night_rain.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_day.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_night_rain.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_day.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_night_rain.png, build/ps_evidence/batch/shots/item37_shot34_strip_day.png, build/ps_evidence/batch/shots/item37_shot34_strip_night_rain.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_day.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_night_rain.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_day.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_night_rain.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_day.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_night_rain.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_day.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_night_rain.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_day.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_night_rain.png, build/ps_evidence/batch/shots/run.log

**Tests:** none

## 28

**Owner:** Old Fennel's lines read weird ("come to themselves", "Mark comes right up on the flank").

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Text quoted in the evidence (the shipped words, or the owner's):** "Keep her fed, give her a friend in the pen, and don't rush her." / "A Drifter who's settled finds what she's good at, all on her own. One morning her cutie mark's just there, like it always was. That's a Bloom." / "Then feed her what she likes. Every pony has her own favorite, no two alike. Here. My old treat pouch. Toss one where she can see it and watch her ears." / "Try things. One who loves what you tossed comes trotting, and she'll sit quiet as a lamb in that Scoop of yours. Hay's safe. Daisies for the fussy ones." / "A pony who's fed and settled makes gems. A pony who's happy long enough... well. You'll see that too." / "come to themselves" / "comes right up"

**Tests:** none

## 29

**Owner:** Doors far too small next to buildings everywhere (Market, Depot); oversized porches and ramps [27][31].

**Owner's screenshots:** [27] [31]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item36/row_sheet.png, build/ps_evidence/item29/, build/ps_evidence/item36/item36_shot33_ponyville_row_day.png, build/ps_evidence/item36/item36_shot33_ponyville_row_night_rain.png, build/ps_evidence/item36/row_top.png, build/ps_evidence/item36/st_kerb_join.png, build/ps_evidence/item36/st_street_north.png, build/ps_evidence/item36/st_strip_join.png, build/ps_evidence/item36/st_yards_east.png, build/ps_evidence/item36/st_yards_west.png, build/ps_evidence/item29/item29_shot27_market_door_day.png, build/ps_evidence/item29/item29_shot27_market_door_night_rain.png, build/ps_evidence/item29/item29_shot31_depot_door_day.png, build/ps_evidence/item29/item29_shot31_depot_door_night_rain.png, build/ps_evidence/item29/pv_general_doorcrop.png, build/ps_evidence/item29/pv_tower_b_doorcrop.png, build/ps_evidence/item29/pv_wide_b_doorcrop.png, build/ps_evidence/item29/ramps_at_four_doors.png, build/ps_evidence/item29/row_pv_balcony_b_doors.png, build/ps_evidence/item29/row_pv_courtyard_b_doors.png, build/ps_evidence/item29/row_pv_ogb_1_doors.png, build/ps_evidence/item29/row_pv_ogb_2_doors.png, build/ps_evidence/item29/row_pv_pink_b_doors.png, build/ps_evidence/item29/saa_barn_doorcrop.png, build/ps_evidence/item29/street_sheet.png, build/ps_evidence/item29/topdown.png

**Tests:** test_doors_fit, test_scale, test_nothing_inside_buildings

## 30

**Owner:** EVERY menu: drop the key hints, one Back button (not Close plus Esc), a real scroll bar. Compendium: "The Strip 0 of 0", bare "???" rows [28].

**Owner's screenshots:** [28]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png

**Tests:** none

## 31

**Owner:** The camera passes into the Market; you see the hollow shell from inside [29].

**Owner's screenshots:** [29]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item31/item31_shot29_market_wall_camera_day.png, build/ps_evidence/item31/lens_round_sheet.png, build/ps_evidence/item31/item31_lens_round_0.png, build/ps_evidence/item31/item31_lens_round_6.png, build/ps_evidence/item31/item31_shot29_market_wall_camera_night_rain.png, build/ps_evidence/item31/lens_positions.txt

**Tests:** test_camera_terrain

## 32

**Owner:** Barn yard: barn on a tall plinth, oversized ramp, mismatched shed, wagon, hay and seed bag scale, scattered [30].

**Owner's screenshots:** [30]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item32/item32_shot30_barn_yard_day.png, build/ps_evidence/item32/item32_shot30_barn_yard_night_rain.png, build/ps_evidence/item32/shed_coop_barn_lineup.png, build/ps_evidence/item32/yard_top.png

**Tests:** test_scale, test_nothing_inside_buildings

## 33

**Owner:** Delivering ponies went against the debt when the owner expected pay; the debt isn't explained.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png

**Tests:** test_delivery_toast

## 34

**Owner:** You can't tell which ponies aren't catchable (townsfolk).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item34/crosshair_townspony_vs_wild.png

**Text quoted in the evidence (the shipped words, or the owner's):** "E: talk to Old Fennel"

**Tests:** test_townsfolk_read_as_people

## 35

**Owner:** Spike just sits there with no clear purpose.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item35/item35_prompt.png, build/ps_evidence/item35/item35_ask_1.png, build/ps_evidence/item35/item35_ask_2.png, build/ps_evidence/item35/item35_ask_3.png, build/ps_evidence/item35/spike_log.txt

**Text quoted in the evidence (the shipped words, or the owner's):** "E: ask Spike for a tip" / "Hold right mouse on a pony to scoop her up. The tricky ones wriggle, so keep your aim on her!" / "Every pony has a favorite food. Toss her a treat she loves and watch her glow!" / "E: talk to Tumble"

**Tests:** test_spike_tips

## 36

**Owner:** Ponyville row: houses lean and sink into the slope, lamp posts lean, no streets or yards, grey road meets dirt road badly [33].

**Owner's screenshots:** [33]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item36/item36_shot33_ponyville_row_day.png, build/ps_evidence/item36/item36_shot33_ponyville_row_night_rain.png, build/ps_evidence/item36/row_sheet.png, build/ps_evidence/item36/row_top.png, build/ps_evidence/item36/st_kerb_join.png, build/ps_evidence/item36/st_street_north.png, build/ps_evidence/item36/st_strip_join.png, build/ps_evidence/item36/st_yards_east.png, build/ps_evidence/item36/st_yards_west.png

**Tests:** test_street, test_scale

## 37

**Owner:** The Strip: tilted arcade machines on a grey slab, a floating track, leaning lamps, dirt road painted across the pavement [34].

**Owner's screenshots:** [34]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item37/item37_shot34_strip_day.png, build/ps_evidence/item37/item37_shot34_strip_night_rain.png, build/ps_evidence/item37/strip_sheet.png

**Tests:** test_upright_and_seated

## 38

**Owner:** Tumble's "over to the south-east" means nothing; sightings should light the compass or trail (couldn't find Octavia).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item38/sighting_sheet.png, build/ps_evidence/item38/sighting_log.txt

**Text quoted in the evidence (the shipped words, or the owner's):** "Look, look! It's Vinyl Scratch! Follow the sparkles, quick!" / "Find Vinyl Scratch 35 m"

**Tests:** test_guide, test_a_sighting_is_where_the_trail_goes

## 39

**Owner:** Two of the same named pony at once (two Sweetie Belles, two Scootaloos).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item39/test_before_fix.txt

**Tests:** test_no_duplicate_ponies, test_before_fix

## 40

**Owner:** Rain too heavy to see through; it looks cheap (falling rectangles); night plus rain is very dark [45].

**Owner's screenshots:** [45]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item40/, build/ps_evidence/item40/item40-53_shot45_paddock_trail_day.png, build/ps_evidence/item40/item40-53_shot45_paddock_trail_night_clear.png, build/ps_evidence/item40/item40-53_shot45_paddock_trail_night_rain.png, build/ps_evidence/item40/night_pair_after.png, build/ps_evidence/item40/night_pair_before.png

**Tests:** test_sky_rig, test_rain_at_night_keeps_nine_tenths_of_the_light

## 41

**Owner:** You can walk into the Depot; walls have no collision, and it rains inside [35].

**Owner's screenshots:** [35]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item41/item41-68_shot35_depot_inside_day.png, build/ps_evidence/item41/walk_strip.png, build/ps_evidence/item41/item41-68_shot35_depot_inside_night_rain.png, build/ps_evidence/item41/item41_stopped_side_view.png, build/ps_evidence/item41/item41_walk_00.png, build/ps_evidence/item41/item41_walk_09.png, build/ps_evidence/item41/walk_positions.txt

**Tests:** test_buildings_solid

## 42

**Owner:** A toast as one giant full-width line, overlapping the objective card [36].

**Owner's screenshots:** [36]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 43

**Owner:** A townspony stuck half inside the Palace plinth wall [37].

**Owner's screenshots:** [37]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item43/item43_shot37_palace_plinth_, build/ps_evidence/item43/item43_shot37_palace_plinth_day.png, build/ps_evidence/item43/item43_shot37_palace_plinth_night_clear.png, build/ps_evidence/item43/item43_shot37_palace_plinth_night_rain.png, build/ps_evidence/item43/item43_shot37_palace_plinth_side_day.png, build/ps_evidence/item43/item43_shot37_palace_plinth_side_night_clear.png, build/ps_evidence/item43/item43_shot37_palace_plinth_side_night_rain.png

**Tests:** test_townspony_plinth, test_the_teller_stands_clear_of_the_palace_plinth_as_built, test_no_attendant_body_is_inside_any_plinth_or_ramp_on_the_map

## 44

**Owner:** Casino patrons frozen in place [38].

**Owner's screenshots:** [38]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item44/, build/ps_evidence/item44/hall_strip.png, build/ps_evidence/item44/slots_strip.png, build/ps_evidence/item44/tables_strip.png

**Tests:** test_casino_patrons

## 45

**Owner:** The Wheel rebuilt like Rust's Bandit Camp wheel: one wheel, payout tiers 1x/3x/5x/10x/20x, high tiers rarer, bet on a tier. Drop the Colour and Number tabs. Fix the clipped rules box and the empty lower half [39].

**Owner's screenshots:** [39]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/casino/wheel_100_bets.png, build/ps_evidence/batch/casino/blackjack_100_dealer_busts.png, build/ps_evidence/batch/casino/blackjack_100_decide.png, build/ps_evidence/batch/casino/blackjack_100_idle.png, build/ps_evidence/batch/casino/blackjack_100_rules.png, build/ps_evidence/batch/casino/run.log, build/ps_evidence/batch/casino/slots_100_idle.png, build/ps_evidence/batch/casino/slots_100_loss.png, build/ps_evidence/batch/casino/slots_100_spinning.png, build/ps_evidence/batch/casino/slots_100_win.png, build/ps_evidence/batch/casino/wheel_100_idle.png, build/ps_evidence/batch/casino/wheel_100_spinning.png, build/ps_evidence/batch/casino/wheel_100_win.png

**Tests:** none

## 46

**Owner:** All casino games: no text log under the game (no "=====" rows); the reels and a win flash tell it. Symbols clip their windows; the paytable line is cut off; a real lever; bigger chips; a spin button [40].

**Owner's screenshots:** [40]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item46/slots_100_idle.png, build/ps_evidence/item46/slots_100_win.png, build/ps_evidence/item46/slots_150_idle.png

**Tests:** test_slots_menu

## 47

**Owner:** Slots: every reel window shows the result symbol three times stacked [40][42].

**Owner's screenshots:** [40] [42]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/casino/slots_100_idle.png, build/ps_evidence/batch/casino/blackjack_100_dealer_busts.png, build/ps_evidence/batch/casino/blackjack_100_decide.png, build/ps_evidence/batch/casino/blackjack_100_idle.png, build/ps_evidence/batch/casino/blackjack_100_rules.png, build/ps_evidence/batch/casino/run.log, build/ps_evidence/batch/casino/slots_100_loss.png, build/ps_evidence/batch/casino/slots_100_spinning.png, build/ps_evidence/batch/casino/slots_100_win.png, build/ps_evidence/batch/casino/wheel_100_bets.png, build/ps_evidence/batch/casino/wheel_100_idle.png, build/ps_evidence/batch/casino/wheel_100_spinning.png, build/ps_evidence/batch/casino/wheel_100_win.png

**Tests:** none

## 48

**Owner:** Blackjack plays itself: no Hit/Stand/Double/Split. Dealer labelled "stand" after busting. Banner text overflows its box [41].

**Owner's screenshots:** [41]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item48/, build/ps_evidence/item48/blackjack_100_pair.png, build/ps_evidence/item48/blackjack_100_split.png, build/ps_evidence/item48/blackjack_100_split_settled.png, build/ps_evidence/item48/blackjack_150_rules.png, build/ps_evidence/item48/split_sheet.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Both hands win" / "Hand 1: Dealer busts · Hand 2: Dealer busts" / "Dealer stand after bust"

**Tests:** test_blackjack_split, test_blackjack_menu

## 49

**Owner:** Slots: can't change the bet off 10 (the 50 and 200 chips do nothing) [42].

**Owner's screenshots:** [42]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/casino/slots_100_win.png, build/ps_evidence/batch/casino/blackjack_100_dealer_busts.png, build/ps_evidence/batch/casino/blackjack_100_decide.png, build/ps_evidence/batch/casino/blackjack_100_idle.png, build/ps_evidence/batch/casino/blackjack_100_rules.png, build/ps_evidence/batch/casino/run.log, build/ps_evidence/batch/casino/slots_100_idle.png, build/ps_evidence/batch/casino/slots_100_loss.png, build/ps_evidence/batch/casino/slots_100_spinning.png, build/ps_evidence/batch/casino/wheel_100_bets.png, build/ps_evidence/batch/casino/wheel_100_idle.png, build/ps_evidence/batch/casino/wheel_100_spinning.png, build/ps_evidence/batch/casino/wheel_100_win.png

**Tests:** test_slots_menu

## 50

**Owner:** The Rainbow Factory hints (the yield letter, the Mayor) are too on the nose, too early.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Text quoted in the evidence (the shipped words, or the owner's):** "Shipment quality: excellent. Yield: outstanding." / "Shipment quality: excellent. Colour: very vivid!" / "Smile! You're in the Cloudsdale newsletter!\" / " (no figure; PT10). There is no Mayor line left in the game. The " / " the batch check saw was a stand-in string in scenes/test/hud_shot.gd and test_hud_layout, never the game's; replaced so it cannot mislead again. " / " now appears only in the Factory and the chapters after the reveal (Compendium "

**Tests:** test_hud_layout, test_hints_not_on_the_nose

## 51

**Owner:** Clicking the mailbox opens "Saddlebag Copies"; the survey says "answer below" with no way to answer; the letter text has a heavy outline and is hard to read [44].

**Owner's screenshots:** [44]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item8/before/mailbox_survey.png, build/ps_evidence/item8/before/market_buy_decor_a.png, build/ps_evidence/item8/before/market_buy_decor_b.png, build/ps_evidence/item8/before/market_buy_decor_c.png, build/ps_evidence/item8/before/welcome_letter.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Post! The flag is up on your mailbox."

**Tests:** test_ranch_mail, test_a_letter_that_asks_a_question_is_answered_in_the_letter_itself, test_letter_panel, test_every_button_on_the_sheet_is_ink_on_paper_not_white_on_cream, test_the_panel_wears_the_paper_box_rather_than_the_navy_one

## 52

**Owner:** The Market buy screen is easy to miss; buying food is fiddly, so feeding feels not worth it.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png

**Tests:** none

## 53

**Owner:** The trail keeps pointing to the paddock after you've upgraded it ("0/2") [45].

**Owner's screenshots:** [45]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item53/test_before_fix.txt, build/ps_evidence/item53/before/trail_0_past_first_pen.png, build/ps_evidence/item53/trail_0_past_first_pen.png, build/ps_evidence/item53/trail_3_from_above.png, build/ps_evidence/item53/before/trail_3_from_above.png

**Text quoted in the evidence (the shipped words, or the owner's):** " is the Bloom step, whose goal was &" / ", and Ranch._guide_pen_target() answers a pen with ROOM, else an empty plot, else Plots/Slot1; with every pen upgraded and full it fell through to Slot1, the old Paddock, and stayed (the PT3 drifters=0 fix only covered " / "). Fix: the Bloom step has its own goals, &" / " (the nearest pen holding an unmarked Drifter, full or not) and &" / " (the nearest wild Drifter, not any pony). Test test_trail_after_upgrade (2): every plot a Grand Pen (Slot1 a Paddock upgraded twice), all full, a Drifter in Slot3 -> the trail goes to Slot3, not Slot1 (FAILED before: Slot1, output build/ps_evidence/item53/test_before_fix.txt); with no Drifter penned it finds a wild Drifter (passed before by luck of the nearest pony; kept as a guard). test_objective updated to the new goals. Renders (scenes/test/trail_upgrade_shot.gd, the owner's spot 8 m past the first pen): before build/ps_evidence/item53/before/trail_0_past_first_pen.png (" / ", the owner's card, ring on the first pen); after build/ps_evidence/item53/trail_0_past_first_pen.png ("

**Tests:** test_trail_after_upgrade, test_before_fix, test_objective

## 54

**Owner:** Far ponies have no eyes until close; eyes change shape between far and near [53][54].

**Owner's screenshots:** [53] [54]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/lod_sheet.png, build/ps_evidence/batch/gut.log, build/ps_evidence/batch/heel_sheet.png, build/ps_evidence/batch/input.log, build/ps_evidence/batch/lake_wedge_crop.png, build/ps_evidence/batch/ui/after_letter.png, build/ps_evidence/batch/ui/creator_hair.png, build/ps_evidence/batch/ui/creator_hair_streak_style.png, build/ps_evidence/batch/ui/creator_look.png, build/ps_evidence/batch/ui/creator_mark.png, build/ps_evidence/batch/ui/creator_spin_a.png, build/ps_evidence/batch/ui/creator_spin_b.png, build/ps_evidence/batch/ui/creator_spin_c.png, build/ps_evidence/batch/ui/depot_open.png, build/ps_evidence/batch/ui/depot_tab_0.png, build/ps_evidence/batch/ui/depot_tab_1.png, build/ps_evidence/batch/ui/depot_tab_2.png, build/ps_evidence/batch/ui/mailbox_survey.png, build/ps_evidence/batch/ui/market_open.png, build/ps_evidence/batch/ui/pause_compendium.png, build/ps_evidence/batch/ui/pause_main.png, build/ps_evidence/batch/ui/run.log, build/ps_evidence/batch/ui/welcome_letter.png, build/ps_evidence/batch/casino/blackjack_100_dealer_busts.png, build/ps_evidence/batch/casino/blackjack_100_decide.png, build/ps_evidence/batch/casino/blackjack_100_idle.png, build/ps_evidence/batch/casino/blackjack_100_rules.png, build/ps_evidence/batch/casino/run.log, build/ps_evidence/batch/casino/slots_100_idle.png, build/ps_evidence/batch/casino/slots_100_loss.png, build/ps_evidence/batch/casino/slots_100_spinning.png, build/ps_evidence/batch/casino/slots_100_win.png, build/ps_evidence/batch/casino/wheel_100_bets.png, build/ps_evidence/batch/casino/wheel_100_idle.png, build/ps_evidence/batch/casino/wheel_100_spinning.png, build/ps_evidence/batch/casino/wheel_100_win.png, build/ps_evidence/batch/heel/h_0.png, build/ps_evidence/batch/heel/h_1.png, build/ps_evidence/batch/heel/h_2.png, build/ps_evidence/batch/heel/h_3.png, build/ps_evidence/batch/heel/h_4.png, build/ps_evidence/batch/heel/h_5.png, build/ps_evidence/batch/heel/run.log, build/ps_evidence/batch/shots/item14_shot32_fingerpost_day.png, build/ps_evidence/batch/shots/item14_shot32_fingerpost_night_rain.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_day.png, build/ps_evidence/batch/shots/item17-65_shot52_pens_night_rain.png, build/ps_evidence/batch/shots/item17_shot21_plaza_palace_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_day.png, build/ps_evidence/batch/shots/item24-26_shot24_plot_brambles_night_rain.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_day.png, build/ps_evidence/batch/shots/item25_shot25_yellow_blob_night_rain.png, build/ps_evidence/batch/shots/item29_shot27_market_door_day.png, build/ps_evidence/batch/shots/item29_shot27_market_door_night_rain.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_day.png, build/ps_evidence/batch/shots/item29_shot31_depot_door_night_rain.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_day.png, build/ps_evidence/batch/shots/item31_shot29_market_wall_camera_night_rain.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_day.png, build/ps_evidence/batch/shots/item32_shot30_barn_yard_night_rain.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_day.png, build/ps_evidence/batch/shots/item36_shot33_ponyville_row_night_rain.png, build/ps_evidence/batch/shots/item37_shot34_strip_day.png, build/ps_evidence/batch/shots/item37_shot34_strip_night_rain.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_day.png, build/ps_evidence/batch/shots/item40-53_shot45_paddock_trail_night_rain.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_day.png, build/ps_evidence/batch/shots/item41-68_shot35_depot_inside_night_rain.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_day.png, build/ps_evidence/batch/shots/item43_shot37_palace_plinth_night_rain.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_day.png, build/ps_evidence/batch/shots/item61_shot48_lake_bank_night_rain.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_day.png, build/ps_evidence/batch/shots/item61_shot49_lake_close_night_rain.png, build/ps_evidence/batch/shots/run.log, build/ps_evidence/batch/ui2/after_letter.png, build/ps_evidence/batch/ui2/creator_hair.png, build/ps_evidence/batch/ui2/creator_hair_streak_style.png, build/ps_evidence/batch/ui2/creator_look.png, build/ps_evidence/batch/ui2/creator_mark.png, build/ps_evidence/batch/ui2/creator_spin_a.png, build/ps_evidence/batch/ui2/creator_spin_b.png, build/ps_evidence/batch/ui2/creator_spin_c.png, build/ps_evidence/batch/ui2/depot_open.png, build/ps_evidence/batch/ui2/depot_tab_0.png, build/ps_evidence/batch/ui2/depot_tab_1.png, build/ps_evidence/batch/ui2/depot_tab_2.png, build/ps_evidence/batch/ui2/mailbox_survey.png, build/ps_evidence/batch/ui2/market_open.png, build/ps_evidence/batch/ui2/pause_compendium.png, build/ps_evidence/batch/ui2/pause_main.png, build/ps_evidence/batch/ui2/run.log, build/ps_evidence/batch/ui2/welcome_letter.png, build/ps_evidence/batch/lod/lod_06m.png, build/ps_evidence/batch/lod/lod_10m.png, build/ps_evidence/batch/lod/lod_14m.png, build/ps_evidence/batch/lod/lod_20m.png, build/ps_evidence/batch/lod/lod_30m.png, build/ps_evidence/batch/lod/run.log, build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 55

**Owner:** Buying the Orchard felt pointless (no rares seen). Each area should show its ponies and their times before you buy, and give a guaranteed rare when it opens.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item55/market_permit_orchard.png, build/ps_evidence/item55/market_decor_hay_bales.png, build/ps_evidence/item55/market_permit_everfree.png, build/ps_evidence/item55/market_permit_lake.png, build/ps_evidence/item55/market_permit_nightmeadow.png

**Tests:** test_permit_preview

## 56a

**Owner:** The coat stallion: the dialogue says coat but there's no coat on the model.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** tools/blender_props/build_props.py, build/ps_evidence/item56/coat_and_clipboard.png, build/ps_evidence/item56/walk_by_strip.png

**Text quoted in the evidence (the shipped words, or the owner's):** "A grey stranger with a clipboard..." / "He looks over your pens..."

**Tests:** test_collector_walk_by

## 56b

**Owner:** The coat stallion should be a mysterious walk-by, not a slow shuffle up to you.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item56/walk_by_strip.png, build/ps_evidence/item56/coat_and_clipboard.png

**Tests:** test_collector_walk_by

## 57

**Owner:** A pony hidden inside a haystack: give hiding a tell, or don't spawn inside props.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item57/hay_sheet.png, build/ps_evidence/item57/item57_hay_from_above.png, build/ps_evidence/item57/item57_hay_pony_height.png, build/ps_evidence/item57/spawner_check.txt

**Tests:** test_buildings_solid, test_every_standing_region_prop_is_solid

## 58

**Owner:** Tumble gets stuck on the Orchard fence.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Tests:** test_companion_catch_up

## 59

**Owner:** Toasts and companion lines vanish too fast, and pausing clears them.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item59/toast_strip.png, build/ps_evidence/item59/item59_after_unpause.png, build/ps_evidence/item59/item59_long_toast_6.5s.png, build/ps_evidence/item59/item59_paused_5s.png, build/ps_evidence/item59/toast_log.txt

**Tests:** test_hud_layout, test_a_long_toast_stays_long_enough_to_read_and_waits_out_a_pause

## 60

**Owner:** The saddlebag pips run off the card at 18 slots [47].

**Owner's screenshots:** [47]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 61

**Owner:** Lake: ponies and the player walk under the water; ponies half sunk; grass shows through; no banks [48][49].

**Owner's screenshots:** [48] [49]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item61/, build/ps_evidence/item61/before/item61_shot48_lake_bank_day.png, build/ps_evidence/item61/before/item61_shot48_lake_bank_night_clear.png, build/ps_evidence/item61/before/item61_shot48_lake_bank_night_rain.png, build/ps_evidence/item61/before/item61_shot49_lake_close_day.png, build/ps_evidence/item61/before/item61_shot49_lake_close_night_clear.png, build/ps_evidence/item61/before/item61_shot49_lake_close_night_rain.png, build/ps_evidence/item61/after/item61_shot48_lake_bank_day.png, build/ps_evidence/item61/after/item61_shot48_lake_bank_night_clear.png, build/ps_evidence/item61/after/item61_shot48_lake_bank_night_rain.png, build/ps_evidence/item61/after/item61_shot49_lake_close_day.png, build/ps_evidence/item61/after/item61_shot49_lake_close_night_clear.png, build/ps_evidence/item61/after/item61_shot49_lake_close_night_rain.png, build/ps_evidence/item61/after/lake_bank_along.png, build/ps_evidence/item61/after/lake_canoe_jetty.png, build/ps_evidence/item61/after/lake_overview.png, build/ps_evidence/item61/after/lake_pony_at_shore.png, build/ps_evidence/item61/after/lake_positions.txt, build/ps_evidence/item61/after/lake_wading.png

**Tests:** test_lake_shore

## 62

**Owner:** Depot statement: "Quota 31 of 2", still "cycle 1" and "collections passed 0" after a long session [50].

**Owner's screenshots:** [50]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item62/test_before_fix.txt, build/ps_evidence/item62/statement_after_an_hour.png, build/ps_evidence/item62/statement_first_period.png

**Text quoted in the evidence (the shipped words, or the owner's):** "First collection: in N days" / "Collections passed: 0" / "Collections passed: 1" / ", a new account has no " / ". Renders (scenes/test/depot_shot.gd): build/ps_evidence/item62/statement_after_an_hour.png (Collections passed: 1, Quota: 2 more to deliver (0 of 2), next in 3 days), statement_first_period.png (31 delivered at cycle 1: " / "First collection: in 2 days"

**Tests:** test_statement_long_session, test_before_fix

## 63

**Owner:** Duplicates and everyone tagged "one of a kind" in the Deliver list [51].

**Owner's screenshots:** [51]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item63/test_before_fix.txt, build/ps_evidence/item63/deliver_owner_roster.png

**Text quoted in the evidence (the shipped words, or the owner's):** "from the crowd" / "one of a kind..." / "one of a kind" / "there are two of her here" / "one of a kind" / "two of her here" / "there are two of her here" / "one of a kind" / "one of a kind"

**Tests:** test_deliver_tags, test_before_fix

## 64

**Owner:** Feeding is automatic from the pantry, and nothing says so; show the pantry stock and the hungry state.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item64/hud_pantry_stocked.png, build/ps_evidence/item64/face_compare.png, build/ps_evidence/item64/hud_pantry_hungry_empty.png, build/ps_evidence/item64/pen_hungry_wide.png

**Tests:** test_pantry_shown

## 65

**Owner:** Full pen: ponies pile in one corner, overlap, push through the fence; "moved into the pen" while the prompt says the pen is full [52].

**Owner's screenshots:** [52]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item65/corner_compare.png, build/ps_evidence/item65/after_review_night/grand_night_t75.png, build/ps_evidence/item65/corner_before_t75.png, build/ps_evidence/item65/day_compare.png, build/ps_evidence/item65/corner_after/grand_night_t0.png, build/ps_evidence/item65/corner_after/grand_night_t15.png, build/ps_evidence/item65/corner_after/grand_night_t30.png, build/ps_evidence/item65/corner_after/grand_night_t45.png, build/ps_evidence/item65/corner_after/grand_night_t60.png, build/ps_evidence/item65/corner_after/grand_night_t75.png, build/ps_evidence/item65/day_after/grand_night_t0.png, build/ps_evidence/item65/day_after/grand_night_t15.png, build/ps_evidence/item65/day_after/grand_night_t30.png, build/ps_evidence/item65/day_after/grand_night_t45.png, build/ps_evidence/item65/day_after/grand_night_t60.png, build/ps_evidence/item65/day_after/grand_night_t75.png, build/ps_evidence/item65/after_review_day/godot.log, build/ps_evidence/item65/after_review_day/grand_night_t0.png, build/ps_evidence/item65/after_review_day/grand_night_t15.png, build/ps_evidence/item65/after_review_day/grand_night_t30.png, build/ps_evidence/item65/after_review_day/grand_night_t45.png, build/ps_evidence/item65/after_review_day/grand_night_t60.png, build/ps_evidence/item65/after_review_day/grand_night_t75.png, build/ps_evidence/item65/after_review_day/run.log, build/ps_evidence/item65/day_before/grand_night_t0.png, build/ps_evidence/item65/day_before/grand_night_t15.png, build/ps_evidence/item65/day_before/grand_night_t30.png, build/ps_evidence/item65/day_before/grand_night_t45.png, build/ps_evidence/item65/day_before/grand_night_t60.png, build/ps_evidence/item65/day_before/grand_night_t75.png, build/ps_evidence/item65/corner_before/grand_night_t0.png, build/ps_evidence/item65/corner_before/grand_night_t15.png, build/ps_evidence/item65/corner_before/grand_night_t30.png, build/ps_evidence/item65/corner_before/grand_night_t45.png, build/ps_evidence/item65/corner_before/grand_night_t60.png, build/ps_evidence/item65/corner_before/grand_night_t75.png, build/ps_evidence/item65/after_review_night/godot.log, build/ps_evidence/item65/after_review_night/grand_night_t0.png, build/ps_evidence/item65/after_review_night/grand_night_t15.png, build/ps_evidence/item65/after_review_night/grand_night_t30.png, build/ps_evidence/item65/after_review_night/grand_night_t45.png, build/ps_evidence/item65/after_review_night/grand_night_t60.png, build/ps_evidence/item65/after_review_night/run.log

**Tests:** test_pen_spread, test_pony, test_a_curious_resident_turns_to_watch_her_farmer_and_stays_put, test_ranch_penning, test_the_pony_that_fills_the_pen_is_told_it_is_now_full, test_a_full_pen_keeps_daylight_between_its_residents

## 66

**Owner:** The compass strip: better icons, distances, N/E/S/W, a clear goal marker.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/batch/hud/hud_busy.png, build/ps_evidence/batch/hud/hud_person.png, build/ps_evidence/batch/hud/hud_plain.png, build/ps_evidence/batch/hud/hud_toast.png, build/ps_evidence/batch/hud/run.log

**Tests:** none

## 67

**Owner:** The half-lidded "looking at you" eyes switch off as you get close (backwards). The owner LIKED them: keep them, make them deliberate and shared by more ponies.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item67/coy_then_passed.png

**Tests:** test_coy_look

## 68

**Owner:** SOFT-LOCK: walked into the Depot, fell out, stuck, couldn't move or get up [55]. Needs an unstuck (and the collision fix in 41).

**Owner's screenshots:** [55]

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item68/put_inside_strip.png, build/ps_evidence/item41/item41-68_shot35_depot_inside_day.png, build/ps_evidence/item68/item68_her_view_after.png, build/ps_evidence/item68/item68_put_inside_00.png, build/ps_evidence/item68/item68_put_inside_01.png, build/ps_evidence/item68/item68_walks_off.png, build/ps_evidence/item68/rescue_positions.txt, build/ps_evidence/item41/item41-68_shot35_depot_inside_night_rain.png, build/ps_evidence/item41/item41_stopped_side_view.png, build/ps_evidence/item41/item41_walk_00.png, build/ps_evidence/item41/item41_walk_09.png, build/ps_evidence/item41/walk_positions.txt, build/ps_evidence/item41/walk_strip.png

**Tests:** test_buildings_solid, test_the_player_put_inside_the_depot_is_out_within_a_second

## 69

**Owner:** Catching is too easy (all but the toughest) and repetitive; 49 deliveries came fast; ~800 gems per Market trip mid-game. Pacing and difficulty need a pass.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Tests:** test_beam_weave, test_flee_smarter, test_repeat_delivery, test_prices_halfway, test_pacing_model

## 70

**Owner:** Ponies escaping fully upgraded pens. The owner had every pen at its highest tier and still saw escapes, with repeats in the wild. In code, only the Paddock (pen_small) lets an Escape Artist out at night (ranch._escape_artists, PonyTraits.escapes_from). Check: (a) does the upgraded tier survive save and load, or does contents revert to pen_small; (b) does anything else free penned ponies (the night pen, the Depot cart, the full-pen "moved into the pen" path in 65); (c) the upgrade flow itself (53, stuck "0/2"). The spawner also lets an owned pony spawn again (only on-map dupes are blocked), so decide whether to block owned repeats. Failing test first.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Tests:** test_no_duplicate_ponies, test_ten_nights_upgraded_pens_a_recatch_and_a_save_make_no_second_of_anyone

## M

**Owner:** Marigold walks in front of the camera when she greets you (known gap, 2026-11-06).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemM/greet_strip.png, build/ps_evidence/itemM/greet_end.png

**Tests:** test_greet_out_of_shot

## G1

**Owner:** FS1.4: hovering a lesson chip shows its sentence as a tooltip.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG1/tests_before.txt, build/ps_evidence/itemG1/before/chip_hover_pen.png, build/ps_evidence/itemG1/before/chips_plain.png, build/ps_evidence/itemG1/after/chip_hover_pen.png, build/ps_evidence/itemG1/after/chip_hover_pen_zoom.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Worth 30 bits" / "Done!  +20 bits"

**Tests:** test_hud, test_hovering_a_lesson_chip_shows_its_sentence

## G2

**Owner:** FS2.2: the ground's fine painted grain, darker grass at prop and fence bases.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG2/fence_base_off_on.png

**Tests:** test_ground_contact

## G3

**Owner:** FS3.1: a hungry pony is SAD (with item 64).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item64/, build/ps_evidence/item64/face_compare.png, build/ps_evidence/item64/hud_pantry_hungry_empty.png, build/ps_evidence/item64/hud_pantry_stocked.png, build/ps_evidence/item64/pen_hungry_wide.png

**Tests:** test_pantry_shown

## G4

**Owner:** FS4.3: a stumble when the player lands hard.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG4/stumble_strip.png, build/ps_evidence/itemG4/stumble_frames.txt

**Tests:** test_player_stumble

## G5

**Owner:** FS5.2: Market and Depot music contexts; the duck at 4 dB.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Text quoted in the evidence (the shipped words, or the owner's):** " while the Market's counter is open (the town's carefree tune, which nothing played before) and "

**Tests:** test_music_contexts, test_music

## G6

**Owner:** FS6.1: tiles stagger in 30 ms apart; a purchase flies a coin to the wallet.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG6/tests_before_market_depot.txt, build/ps_evidence/itemG6/before/open_sheet.png, build/ps_evidence/itemG6/before/buy_sheet.png, build/ps_evidence/itemG6/before/market_buy_0094.png, build/ps_evidence/itemG6/before/market_settled.png, build/ps_evidence/itemG6/after/buy_sheet.png, build/ps_evidence/itemG6/after/market_after_buy.png, build/ps_evidence/itemG6/after/market_buy_0365.png, build/ps_evidence/itemG6/after/market_open_0159.png, build/ps_evidence/itemG6/after/market_settled.png, build/ps_evidence/itemG6/after/open_sheet.png

**Text quoted in the evidence (the shipped words, or the owner's):** " pop was added to the Panel CONTAINER, which laid it out at the panel's top left over the tiles (before/market_buy_0094.png). Now: game/ui/tile_entrance.gd deals the tiles in on a clock (tile i starts 0.03 s * i after the first, a 0.16 s scale-and-fade that lands with a small overshoot), on opening and on a new tab, never on a cursor move, in the Market, the Depot and the build menu; a buy (and a sale, as a little shower) flies the bits coin (MenuStyle.fly_coin, PlaceSign's coin, arcing and turning over) from the tile, once the grid has settled it, to a new purse line (the coin, her bits in gold, the pouch), and the pop rises beside the purse on an effects layer after the coin lands; MarketMenu emits `purchased`. Tests: test_market_tiles.test_the_tiles_stagger_in_30_ms_apart (tile k in and k+1 not at 0.03 k + 0.01 s; all in by the end; a cursor move does not deal again), test_a_purchase_flies_a_coin_to_the_wallet (emits `purchased`; one Coin leaves from the tile; followed frame by frame it ends within 6 px of the purse), test_a_refused_purchase_flies_nothing; both failed before (build/ps_evidence/itemG6/tests_before_market_depot.txt). Renders at quarter speed, file names in game ms: build/ps_evidence/itemG6/before/open_sheet.png and buy_sheet.png (the sheet fades as one; no coin; the pop at the panel's edge), after/open_sheet.png (the grid deals in row by row, 57 to 370 ms), after/buy_sheet.png (the coin leaves Daisies, arcs over Hay, lands on the purse coin at 365 ms, "

**Tests:** test_market_tiles, test_the_tiles_stagger_in_30_ms_apart, test_a_purchase_flies_a_coin_to_the_wallet, test_a_refused_purchase_flies_nothing

## G7

**Owner:** FS6.2: the Depot pays out per tile with a counter sound; the total lands on the balance.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG6/tests_before_market_depot.txt, build/ps_evidence/itemG7/before/payout_sheet.png, build/ps_evidence/itemG6/before/buy_sheet.png, build/ps_evidence/itemG6/before/market_buy_0094.png, build/ps_evidence/itemG6/before/market_settled.png, build/ps_evidence/itemG6/before/open_sheet.png, build/ps_evidence/itemG6/after/buy_sheet.png, build/ps_evidence/itemG6/after/market_after_buy.png, build/ps_evidence/itemG6/after/market_buy_0365.png, build/ps_evidence/itemG6/after/market_open_0159.png, build/ps_evidence/itemG6/after/market_settled.png, build/ps_evidence/itemG6/after/open_sheet.png, build/ps_evidence/itemG7/before/depot_payout_0360.png, build/ps_evidence/itemG7/before/depot_tiles.png

**Text quoted in the evidence (the shipped words, or the owner's):** "+credit bits"

**Tests:** test_depot_menu, test_three_deliveries_roll_up_one_by_one_and_land_once_on_the_balance, test_the_roll_up_counts_on_the_tile_she_left_from, test_a_refused_delivery_rolls_nothing_up

## G8

**Owner:** FS8.3: rarity shapes on the Depot tiles.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG8/tiles_before_above_after_below.png, build/ps_evidence/itemG8/depot_tiles_after.png, build/ps_evidence/itemG8/tiles_after_zoom.png

**Tests:** test_depot_menu, test_every_pony_tile_carries_her_rarity_shape

## G9

**Owner:** FS5.1: hoof loudness measured in the 3D mix against the beds.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** tools/measure_hooves.py, build/ps_evidence/itemG9/hoof_measure.txt

**Tests:** none

## G10

**Owner:** The real-input batch: loading, pen_upgrade and sprint fail in a full batch but pass alone.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG10/footsteps/, build/ps_evidence/itemG10/input_batch_run1..8.txt, build/ps_evidence/itemG10/footsteps/after_7_runs.txt, build/ps_evidence/itemG10/footsteps/after_dump.txt, build/ps_evidence/itemG10/footsteps/before_fail_dump.txt, build/ps_evidence/itemG10/footsteps/before_fail_out.txt, build/ps_evidence/itemG10/footsteps/before_pass_dump_with_positions.txt, build/ps_evidence/itemG10/input_batch_run1.txt, build/ps_evidence/itemG10/input_batch_run2.txt, build/ps_evidence/itemG10/input_batch_run3.txt, build/ps_evidence/itemG10/input_batch_run4.txt, build/ps_evidence/itemG10/input_batch_run5.txt, build/ps_evidence/itemG10/input_batch_run6.txt, build/ps_evidence/itemG10/input_batch_run7.txt, build/ps_evidence/itemG10/input_batch_run8.txt

**Tests:** test_magic_beam, test_a_held_pony_is_never_pulled_into_the_ground

## G11

**Owner:** 60-pony performance: p99 frame time at or under 16.6 ms.

**State claimed:** OPEN

**Renders and files:** game/scenes/test/perf.gd, build/ps_evidence/itemG11/, build/ps_evidence/itemG11/README.txt, build/ps_evidence/itemG11/g11_after_1080_1.log, build/ps_evidence/itemG11/g11_after_1080_2.log, build/ps_evidence/itemG11/g11_after_1080_3.log, build/ps_evidence/itemG11/g11_after_540_1.log, build/ps_evidence/itemG11/g11_after_540_2.log, build/ps_evidence/itemG11/g11_after_540_3.log, build/ps_evidence/itemG11/g11_before_1080_1.log, build/ps_evidence/itemG11/g11_before_1080_2.log, build/ps_evidence/itemG11/g11_before_1080_3.log, build/ps_evidence/itemG11/g11_before_540_1.log, build/ps_evidence/itemG11/g11_before_540_2.log, build/ps_evidence/itemG11/g11_before_540_3.log, build/ps_evidence/itemG11/g11_late2.log, build/ps_evidence/itemG11/g11_prof_after_1.log, build/ps_evidence/itemG11/g11_prof_after_2.log, build/ps_evidence/itemG11/g11_prof_before_1.log, build/ps_evidence/itemG11/g11_prof_before_2.log

**Tests:** test_body_space, test_the_solve_weighs_only_the_pairs_in_reach, test_the_solve_gives_what_the_pair_rules_give, test_a_turn_clear_of_everybody_weighs_no_body_line, test_a_turn_is_allowed_as_the_pair_rules_allow_it, test_a_free_turn_is_one_the_rules_would_allow, test_a_turn_too_small_to_weigh_is_always_allowed, test_a_pony_two_metres_from_everybody_turns_free, test_rump_bounce, test_a_spring_at_rest_sleeps_until_kicked, test_a_turn_only_weighs_the_bodies_in_reach

## G12

**Owner:** Proton smoke run of the Windows build.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** tools/run_windows_build.sh, build/ps_evidence/itemG12/proton_run.txt

**Text quoted in the evidence (the shipped words, or the owner's):** "RANCH save user_dir=C:/users/steamuser/AppData/Roaming/Godot/app_userdata/Filly Rancher file=.../saves/slot_9.json wrote=true reloaded=true" / "RANCH_OK ponies=46 props=112 assets=present" / "PASS: RANCH_OK marker found" / "RANCH_OK ponies=46 props=112 assets=present" / "RANCH save ... slot_9.json wrote=true reloaded=true" / "RANCH_OK ponies=46 props=112 assets=present" / "PASS: RANCH_OK marker found"

**Tests:** none

## G13

**Owner:** Found in the batch check: the paper letters' buttons (the welcome letter's Back, the survey's answer) are white on cream and nearly invisible; behind items 8 and 51.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item8/after/welcome_letter.png, build/ps_evidence/item8/after/mailbox_survey.png, build/ps_evidence/item8/after/mailbox_survey_hover.png, build/ps_evidence/item8/after/market_buy_decor_a.png, build/ps_evidence/item8/after/market_buy_decor_b.png, build/ps_evidence/item8/after/market_buy_decor_c.png

**Tests:** test_letter_panel, test_every_button_on_the_sheet_is_ink_on_paper_not_white_on_cream

## G14

**Owner:** Found in the batch check: several Market decor tiles show blank grey icons (build/ps_evidence/batch/ui/market_open.png).

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** game/scenes/test/decor_icons.gd, build/ps_evidence/item8/before/market_buy_decor_a/b/c.png, build/ps_evidence/item8/after/market_buy_decor_a/b/c.png, build/ps_evidence/itemG14/decor_icons_sheet.png, build/ps_evidence/itemG14/big_picnic_table.png, build/ps_evidence/itemG14/big_statue_rainbowdash.png

**Tests:** test_market_tiles, test_every_thing_for_sale_has_a_picture_not_a_blank_disc

## G15

**Owner:** (found 2026-11-07 rendering item 55) No decoration could be bought: the Market listed twelve since FS7.1, but Shop.refusal() had no DECOR case and refused each "Not for sale yet.", so every decor price drew red.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item55/market_decor_hay_bales.png, build/ps_evidence/item55/market_permit_everfree.png, build/ps_evidence/item55/market_permit_lake.png, build/ps_evidence/item55/market_permit_nightmeadow.png, build/ps_evidence/item55/market_permit_orchard.png

**Text quoted in the evidence (the shipped words, or the owner's):** "Not for sale yet."

**Tests:** test_decor_buyable

## G16

**Owner:** (found 2026-11-07 rendering item 3) No drawn, stamped or generated cutie mark ever showed on a pony: the mark's decals project onto one mesh, chosen as the one with the most vertices, which on the PonySFM rig is the head (13,207 against the body's 4,078), and the flank decals never reach the head.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/item3/flank_, build/ps_evidence/item3/creator_stamps.png, build/ps_evidence/item3/flank_stamped_mark.png, build/ps_evidence/item3/flank_surprise_mark.png

**Tests:** test_cutie_mark, test_the_mark_layer_goes_on_the_body_mesh

## G17

**Owner:** (found 2026-11-07 rendering G6) The Market's BUY tab opens scrolled past its first row: the pick is Hay (row 0, in the detail strip) but the grid shows Gallop Shoes' row at the top and Hay, Apples and Carrots are out of view until the cursor moves. Same before and after G6 (build/ps_evidence/itemG6/before/market_settled.png, after/market_settled.png); not looked into.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** build/ps_evidence/itemG17/market_buy_opens_at_top.png

**Tests:** test_market_tiles, test_the_buy_tab_opens_with_its_first_row_in_view

## G18

**Owner:** Found at the PS13 gate check (owner logs untouched): test launches wrote into the owner's game folder on 2026-11-07.

**State claimed:** FIXED-UNREVIEWED

**Renders and files:** none

**Tests:** test_save_io, test_a_scripted_run_that_names_no_directory_never_writes_the_players_saves, test_the_session_directory_is_the_one_the_environment_named, test_no_duplicate_ponies

