extends RefCounted
## A GREETING STAYS OUT OF THE SHOT (PS8, known gap M: "Marigold walks in front of the camera
## when she greets you"). Where a pony walking up to the player should head next, given where
## the camera is: she ends ahead of the player, a little to her own side, facing the camera;
## if she starts on the camera's side she first steps out to the side, walks up that side,
## and only then comes in. Pure, so the route is tested without a world
## (test/test_greet_out_of_shot.gd).
##
## Preloaded by path, never by a class_name (the class cache lives in the gitignored .godot/).

## Ahead of the player, and to her side, where she stops (metres).
const AHEAD := 2.4
const BESIDE := 1.0
## The side lane she walks up when she starts behind or beside the player.
const LANE := 2.6
## How far ahead she must be before she turns in to the stop.
const IN_FRONT := 0.8


## The camera's ground direction, camera to player, and its right hand.
static func _axes(player: Vector3, cam: Vector3) -> Array:
	var fwd := Vector3(player.x - cam.x, 0.0, player.z - cam.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	return [fwd, fwd.cross(Vector3.UP)]


## Where a pony at `x` walks next to greet the player at `player` seen from `cam`.
static func next_stop(x: Vector3, player: Vector3, cam: Vector3) -> Vector3:
	var axes := _axes(player, cam)
	var fwd: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	var rel := Vector3(x.x - player.x, 0.0, x.z - player.z)
	var along := rel.dot(fwd)
	var across := rel.dot(right)
	var side := right if across >= 0.0 else -right
	if along > IN_FRONT:
		return player + fwd * AHEAD + side * BESIDE
	if absf(across) < LANE - 0.2:
		# Out of the shot first: straight out to the side, keeping her distance along it.
		return player + side * LANE + fwd * along
	return player + side * LANE + fwd * (IN_FRONT + 0.7)


## True once she is ahead of the player, where talking puts her in view and out of the way.
static func in_front(x: Vector3, player: Vector3, cam: Vector3) -> bool:
	var fwd: Vector3 = _axes(player, cam)[0]
	return Vector3(x.x - player.x, 0.0, x.z - player.z).dot(fwd) > IN_FRONT
