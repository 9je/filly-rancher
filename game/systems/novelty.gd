class_name Novelty
extends RefCounted
## THE NOVELTY LOG (MISSION.md, "Fun and anti-repetition rules"): every first time the
## player gets something new -- a pony type, an area, a tool, an upgrade, a mechanic, a
## story beat or clue, an NPC event -- stamped with the play clock. GameState keeps one and
## saves it; the pacing test (tools/pacing.sh, scenes/test/human_bot.gd) reads it back and
## writes PACING.md with the gaps.
##
## The rules, in seconds of play:
##   - in the first hour, no gap longer than GAP_EARLY (the brief says "every 5 to 8 minutes";
##     8 is the ceiling the test enforces);
##   - after that, no gap longer than GAP_LATE;
##   - the first "something is wrong here" clue by CLUE_BY.

const KINDS: Array[String] = ["pony", "area", "tool", "upgrade", "mechanic", "story", "clue",
	"npc", "event"]
const FIRST_HOUR := 3600.0
const GAP_EARLY := 480.0
const GAP_LATE := 900.0
const CLUE_BY := 900.0

## Each entry: {t (play seconds), kind, id, label}. Ids are unique: a second note of the same
## id is ignored, so a hook may fire as often as it likes.
var entries: Array = []


func note(t: float, kind: String, id: String, label: String) -> bool:
	if has(id):
		return false
	entries.append({"t": snappedf(t, 0.1), "kind": kind, "id": id, "label": label})
	return true


func has(id: String) -> bool:
	for e: Dictionary in entries:
		if str(e.id) == id:
			return true
	return false


func to_array() -> Array:
	return entries.duplicate(true)


static func from_array(a: Variant) -> Novelty:
	var out := Novelty.new()
	if a is Array:
		for e in a:
			if e is Dictionary and (e as Dictionary).has("id"):
				out.entries.append({"t": float(e.get("t", 0.0)), "kind": str(e.get("kind", "event")),
					"id": str(e.id), "label": str(e.get("label", ""))})
	return out


## The gaps, from the start of play (t = 0) through every entry to `horizon` (the end of the
## run, which is a gap too: a run that stops getting new things counts against itself).
## Returns {gaps: [{from, to, secs, limit, ok, after}], first_clue, clue_ok, ok, failures}.
static func analyse(list: Array, horizon: float) -> Dictionary:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	var gaps: Array = []
	var failures: Array[String] = []
	var prev := 0.0
	var prev_label := "start of play"
	var points: Array = []
	for e: Dictionary in sorted:
		points.append([float(e.t), str(e.label)])
	points.append([maxf(horizon, prev), "end of run"])
	for p: Array in points:
		var t: float = p[0]
		var secs := t - prev
		var limit := GAP_EARLY if prev < FIRST_HOUR else GAP_LATE
		var ok := secs <= limit + 0.01
		gaps.append({"from": prev, "to": t, "secs": secs, "limit": limit, "ok": ok,
			"after": prev_label, "before": str(p[1])})
		if not ok:
			failures.append("%s gap of %s after \"%s\" (limit %s)" % [
				"early" if prev < FIRST_HOUR else "late", clock(secs), prev_label, clock(limit)])
		prev = t
		prev_label = str(p[1])
	var first_clue := -1.0
	for e: Dictionary in sorted:
		if str(e.kind) == "clue":
			first_clue = float(e.t)
			break
	var clue_ok := first_clue >= 0.0 and first_clue <= CLUE_BY
	if not clue_ok:
		failures.append("first clue at %s (limit %s)" % [
			clock(first_clue) if first_clue >= 0.0 else "never", clock(CLUE_BY)])
	return {"gaps": gaps, "first_clue": first_clue, "clue_ok": clue_ok,
		"ok": failures.is_empty(), "failures": failures}


static func clock(secs: float) -> String:
	var s := int(round(secs))
	return "%d:%02d" % [s / 60, s % 60]


## PACING.md: the run, the verdict, the timeline, and the gaps.
static func markdown(list: Array, horizon: float, meta: Dictionary) -> String:
	var a := analyse(list, horizon)
	var lines: Array[String] = []
	lines.append("# Pacing")
	lines.append("")
	lines.append("Written by `tools/pacing.sh`: a fresh save played by the human-paced bot (`game/scenes/test/human_bot.gd`), headless at a fixed 60 fps, so the clock below is play time. Every first-time unlock, discovery and story beat is stamped as it happens (`game/systems/novelty.gd`).")
	lines.append("")
	lines.append("**Rules** (MISSION.md): no gap over %s in the first hour, none over %s after it, and the first clue by %s." % [
		clock(GAP_EARLY), clock(GAP_LATE), clock(CLUE_BY)])
	lines.append("")
	lines.append("**Verdict: %s**" % ("PASS" if a.ok else "FAIL"))
	for f: String in a.failures:
		lines.append("- %s" % f)
	lines.append("")
	var meta_bits: Array[String] = []
	for k in meta:
		meta_bits.append("%s %s" % [k, str(meta[k])])
	lines.append("Run: %s of play, %d new things, first clue at %s. %s" % [clock(horizon), list.size(),
		clock(float(a.first_clue)) if float(a.first_clue) >= 0.0 else "never", ", ".join(meta_bits)])
	lines.append("")
	lines.append("## Timeline")
	lines.append("")
	lines.append("| Time | Kind | What |")
	lines.append("|---|---|---|")
	var sorted := list.duplicate()
	sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.t) < float(y.t))
	for e: Dictionary in sorted:
		lines.append("| %s | %s | %s |" % [clock(float(e.t)), str(e.kind), str(e.label)])
	lines.append("")
	lines.append("## Gaps")
	lines.append("")
	lines.append("| From | To | Gap | Limit | | Between |")
	lines.append("|---|---|---|---|---|---|")
	for g: Dictionary in a.gaps:
		lines.append("| %s | %s | %s | %s | %s | %s, then %s |" % [clock(float(g.from)), clock(float(g.to)),
			clock(float(g.secs)), clock(float(g.limit)), "ok" if bool(g.ok) else "**OVER**",
			str(g.after), str(g.before)])
	var longest := 0.0
	for g: Dictionary in a.gaps:
		longest = maxf(longest, float(g.secs))
	lines.append("")
	lines.append("Longest gap: %s." % clock(longest))
	return "\n".join(lines) + "\n"
