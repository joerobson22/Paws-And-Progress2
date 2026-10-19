class_name SessionClock
extends RefCounted
## Timestamp-based focus timer. Elapsed time is always derived from wall-clock
## timestamps, so backgrounding, sleep or the app being killed can't corrupt it.
## Every method takes `now` (unix seconds) so it can be tested deterministically.

## A walk left running (e.g. the app was killed overnight) is capped at this.
const MAX_SESSION_SECONDS := 12 * 60 * 60

var project_id: String = ""
var start_unix: int = 0
var paused_total: int = 0
## 0 while running.
var pause_started_unix: int = 0
## How long the player meant to walk; 0 for an open-ended walk.
var goal_seconds: int = 0
var biome_id: String = "lake"


static func begin(p_project_id: String, now: int, p_goal_seconds: int = 0, p_biome_id: String = "lake") -> SessionClock:
	var c := SessionClock.new()
	c.project_id = p_project_id
	c.start_unix = now
	c.goal_seconds = p_goal_seconds
	c.biome_id = p_biome_id
	return c


func is_paused() -> bool:
	return pause_started_unix > 0


func pause(now: int) -> void:
	if not is_paused():
		pause_started_unix = maxi(now, start_unix)


func resume(now: int) -> void:
	if is_paused():
		paused_total += maxi(0, now - pause_started_unix)
		pause_started_unix = 0


func elapsed(now: int) -> int:
	var end := pause_started_unix if is_paused() else now
	# Clamp so a clock that jumps backwards never produces negative time.
	return clampi(end - start_unix - paused_total, 0, MAX_SESSION_SECONDS)


func to_dict() -> Dictionary:
	return {
		"project_id": project_id,
		"start_unix": start_unix,
		"paused_total": paused_total,
		"pause_started_unix": pause_started_unix,
		"goal_seconds": goal_seconds,
		"biome_id": biome_id,
	}


static func from_dict(d: Dictionary) -> SessionClock:
	var c := SessionClock.new()
	c.project_id = str(d.get("project_id", ""))
	c.start_unix = int(d.get("start_unix", 0))
	c.paused_total = int(d.get("paused_total", 0))
	c.pause_started_unix = int(d.get("pause_started_unix", 0))
	c.goal_seconds = int(d.get("goal_seconds", 0))
	c.biome_id = str(d.get("biome_id", "lake"))
	return c


static func format(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
