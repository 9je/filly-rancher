extends RefCounted
## LOADS A SCENE ON THE MAIN THREAD, ONE DEPENDENCY AT A TIME, LEAVES FIRST.
##
## WHY NOT A THREAD. The loading screen used ResourceLoader.load_threaded_request(), and now
## and then (about one New game in six under the input gate, 2026-10-25) the worker stopped
## inside its load of world/ranch.tscn and never came back: the bar sat at 6% on "Saddling
## up" forever, the process idle, every thread parked on a futex. A threaded load cannot be
## cancelled, and a load() of the same path on the main thread would only wait on the stuck
## one. So nothing here ever asks a thread for anything.
##
## WHY IT DOES NOT FREEZE INSTEAD. One load() of the ranch is two and a half seconds of the
## main thread. Walked leaves first, the same load is a hundred and sixty small ones: every
## resource the scene names (ResourceLoader.get_dependencies) and every script any of them
## preload()s (read from the script's source, since a script's preloads are not listed as
## dependencies), each loaded only after everything it needs is already in the cache. Each is
## cheap by itself, the slowest being ranch.gd's own compile (about 0.6 s), and step() stops
## after the first one past its budget, so the loading screen draws and moves its bar between
## every step. Measured: 2.4 s in all, against 2.2 s threaded.
##
## THE CACHE IS WEAK: a resource nobody holds is dropped from it. Every resource loaded here
## is held in _held until the scene itself is loaded, so it is still cached when the scene's
## own load() asks for it.

const PRELOAD_PATTERN := "preload\\(\"(res://[^\"]+)\"\\)"

var _path := ""
var _seen := {}
## The walk: [path, expanded] pairs. A path is expanded (its dependencies pushed) once, and
## loaded when it comes back to the top with all of them done.
var _stack: Array = []
var _held: Array[Resource] = []
var _order: Array[String] = []
var _found := 1
var _result: Resource = null
var _done := false
var _re := RegEx.create_from_string(PRELOAD_PATTERN)


func _init(path: String) -> void:
	_path = path
	if not ResourceLoader.exists(path):
		_done = true
		return
	_seen[path] = true
	_stack.append([path, false])


func is_done() -> bool:
	return _done


## The loaded scene (null when it could not be loaded).
func result() -> Resource:
	return _result


## Every path loaded, in the order it was loaded (the tests read the leaves-first order).
func loaded_order() -> Array[String]:
	return _order


## 0 to 1: loads done over paths found so far. It never falls: the walk finds new paths only
## while it is expanding, and a path counts as done only when it is loaded.
func progress() -> float:
	if _done:
		return 1.0
	return minf(0.99, float(_order.size()) / float(maxi(1, _found)))


## Work for about `budget_ms` milliseconds of the main thread, but always at least one
## thing. True once the scene is loaded.
func step(budget_ms: float) -> bool:
	var start := Time.get_ticks_usec()
	while not _done:
		_advance()
		if float(Time.get_ticks_usec() - start) / 1000.0 >= budget_ms:
			break
	return _done


## One move of the walk: expand the top path, or load it if it is expanded.
func _advance() -> void:
	if _stack.is_empty():
		_finish()
		return
	var top: Array = _stack.back()
	var path: String = top[0]
	if not bool(top[1]):
		top[1] = true
		for dep in _needs(path):
			if _seen.has(dep):
				continue
			_seen[dep] = true
			_found += 1
			_stack.append([dep, false])
		return
	_stack.pop_back()
	if path == _path:
		_result = load(path)
		_order.append(path)
		_finish()
		return
	var res: Resource = load(path)
	if res != null:
		_held.append(res)
	_order.append(path)


## What `path` needs loaded before it: the dependencies its file names, and for a script the
## files it preload()s. Anything already in the cache is skipped, with everything under it.
func _needs(path: String) -> Array[String]:
	var out: Array[String] = []
	for d: String in ResourceLoader.get_dependencies(path):
		_add(out, d.get_slice("::", d.get_slice_count("::") - 1))
	if path.ends_with(".gd"):
		for m: RegExMatch in _re.search_all(FileAccess.get_file_as_string(path)):
			_add(out, m.get_string(1))
	return out


func _add(out: Array[String], p: String) -> void:
	if p.begins_with("uid://"):
		var id := ResourceUID.text_to_id(p)
		p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	if p == "" or p == _path or ResourceLoader.has_cached(p) or not ResourceLoader.exists(p):
		return
	out.append(p)


func _finish() -> void:
	_done = true
	_held.clear()
	_stack.clear()
