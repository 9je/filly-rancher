extends SceneTree
## P9 W3 items 35, 44, 45: the mailbox the way the owner reaches it. The first collection day's
## letter is posted (as the ladder posts it, with the ranch's own params), the player walks up
## to the mailbox and presses E; then the older-letter arrow is clicked; then a mailbox with
## everything read.
##   -s res://scenes/test/laneb_mail.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var story: Story = ranch.call("get_story")
	if not story.has_mail(&"sunny_quota_note"):
		story.post(&"sunny_quota_note", ranch.call("_story_params"))
	var box: Node3D = ranch.get_node(^"Buildings/Mailbox")
	var pl: Node3D = ranch.get("player")
	var at: Vector3 = box.global_position + (pl.global_position - box.global_position).normalized() * 1.6
	at.y = box.global_position.y + 0.3
	Boot.stand(ranch, at, box.global_position)
	await Boot.shot(self, out.path_join("mail_prompt.png"), 30)
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.press(self, &"interact")
	var lp: Node = ranch.get("letter_panel")
	await Boot.shot(self, out.path_join("mail_open.png"), 20)
	print("OPEN ", lp.call("title_text"), " | ", lp.call("pager_text"), " | ", lp.call("news_text"))
	var older: Button = lp.find_child("Older", true, false)
	await Boot.click(self, Boot.centre_of(self, older))
	await Boot.shot(self, out.path_join("mail_older.png"), 20)
	print("OLDER ", lp.call("title_text"), " | ", lp.call("pager_text"), " | ", lp.call("news_text"))
	# Read everything, close, walk back up: the no-new-mail state.
	for id in story.mail_ids():
		story.mark_read(id)
	var close: Button = lp.call("close_button_node")
	await Boot.click(self, Boot.centre_of(self, close))
	await Boot.shot(self, out.path_join("mail_closed_prompt.png"), 30)
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.press(self, &"interact")
	await Boot.shot(self, out.path_join("mail_all_read.png"), 20)
	print("ALLREAD ", lp.call("title_text"), " | ", lp.call("pager_text"), " | ", lp.call("news_text"))
	print("LANEB_MAIL_OK")
	quit(0)
