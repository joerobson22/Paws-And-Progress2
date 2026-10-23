extends Node
## Autoload "App": owns the GameState, saves it, runs the walk lifecycle and
## asks the app shell to move between screens.

## Screens: the five panes ("focus", "gifts", "completed", "profile",
## "stats"), the full-screen flows ("choose_focus", "walk", "finish",
## "ended"), and "home", which closes any flow and returns to the focus pane.
signal navigate(screen: String, params: Dictionary)
signal state_changed

var state: GameState
var rng := RandomNumberGenerator.new()
## Set when this launch imported a v1 save, so the app can say so.
var imported_from_v1 := false
## Set when this launch found a walk still running from before the app was
## closed: {session, biome}. The shell shows the focus ended screen for it.
var ended_walk := {}
## Friends for the leaderboard: [{name, weekly_seconds, walking, look}].
## Filled by the friends service once accounts exist (roadmap phase 4);
## never saved locally.
var friends: Array = []

var _xp := 0
var _xp_key := ""


## How often a running walk notes that the app is still open, in seconds.
const HEARTBEAT := 30.0


func _ready() -> void:
	rng.randomize()
	state = SaveSystem.read()
	if state == null:
		state = _first_launch_state()
		save()
	elif state.active:
		ended_walk = _end_left_walk()
		save()
	var heartbeat := Timer.new()
	heartbeat.wait_time = HEARTBEAT
	heartbeat.autostart = true
	heartbeat.timeout.connect(_on_heartbeat)
	add_child(heartbeat)


func _notification(what: int) -> void:
	# Mobile apps can be killed at any time once backgrounded, so save then.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if state:
				if state.active:
					state.active.last_seen_unix = now()
				save()


## While walking, notes every so often that the app is still open, so a walk
## the app is killed in the middle of stops about when that happened.
func _on_heartbeat() -> void:
	if state and state.active:
		state.active.last_seen_unix = now()
		save()


func now() -> int:
	return int(Time.get_unix_time_from_system())


func tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


func today() -> int:
	return Stats.local_day(now(), tz_bias())


func set_setting(key: String, value) -> void:
	state.settings[key] = value
	_changed()


func set_profile(key: String, value) -> void:
	state.profile[key] = value
	_changed()


func save() -> void:
	var err := SaveSystem.write(state)
	if err != OK:
		push_error("Save failed: %s" % error_string(err))


func go(screen: String, params: Dictionary = {}) -> void:
	navigate.emit(screen, params)


# --- Projects ----------------------------------------------------------------

func new_project_id() -> String:
	return "p%d_%04x" % [now(), rng.randi() & 0xffff]


func add_project(p: ProjectData) -> void:
	if p.id == "":
		p.id = new_project_id()
	if p.created_unix == 0:
		p.created_unix = now()
	state.projects.append(p)
	_changed()


func delete_project(id: String) -> void:
	state.projects.assign(state.projects.filter(func(p): return p.id != id))
	_changed()


func complete_project(id: String) -> void:
	var p := state.project(id)
	if p and not p.is_complete():
		p.completed_unix = now()
		_changed()


## `grade_ref` is "<scale>/<grade>" from data/grades.json, or "" for none.
func set_grade(id: String, grade_ref: String) -> void:
	var p := state.project(id)
	if p:
		p.grade = grade_ref
		_changed()


# --- Levels ------------------------------------------------------------------

func xp() -> int:
	# Summed from the walk log, so cached until the log changes.
	var key := "%d:%d:%d" % [state.get_instance_id(), state.sessions.size(), int(state.profile.get("legacy_total_seconds", 0))]
	if key != _xp_key:
		_xp_key = key
		_xp = Levels.total_xp(state.sessions, int(state.profile.get("legacy_total_seconds", 0)), Content.levels, Content.gift_rarity)
	return _xp


func level() -> int:
	return Levels.level_for(xp(), Content.levels)


## Whether an animal or place ("animal" / "place") is unlocked yet.
func is_unlocked(type: String, id: String) -> bool:
	if debug_unlock_all():
		return true
	return level() >= Levels.unlock_level(type, id, Content.levels)


## The debug-only "unlock everything" switch on the focus screen. Ignored
## outside debug builds (runs from the editor, debug exports).
func debug_unlock_all() -> bool:
	return OS.is_debug_build() and bool(state.settings.get("debug_unlock_all", false))


## The debug-only "phone size" switch: the window takes a phone's shape and
## the app lays itself out as on a phone (see main.gd).
func debug_phone_view() -> bool:
	return OS.is_debug_build() and bool(state.settings.get("debug_phone_view", false))


## True on phones and tablets, and in the debug phone view: swiping and a
## tap-to-open map rather than edge arrows and a map that opens under the
## pointer.
func phone_layout() -> bool:
	return OS.has_feature("mobile") or debug_phone_view()


## The walk's debug time buttons: the walk started `minutes` earlier.
## Does nothing outside debug builds.
func debug_add_minutes(minutes: int) -> void:
	if not OS.is_debug_build() or state.active == null:
		return
	state.active.start_unix -= minutes * 60
	_changed()


# --- Gifts -------------------------------------------------------------------

## Trades gifts up a rarity. Returns the new gift's id, or "" if it can't.
func trade_in(gift_id: String) -> String:
	var g := Content.gift(gift_id)
	if g.is_empty():
		return ""
	var new_id := GiftRoller.trade(state.inventory, gift_id, Content.gifts, Content.trade_cost(g["rarity"]))
	if new_id != "":
		state.tidy_gift_references()
		_changed()
	return new_id


func place_on_shelf(gift_id: String, index: int) -> void:
	state.place_on_shelf(gift_id, index)
	_changed()


func remove_from_shelf(index: int) -> void:
	state.remove_from_shelf(index)
	_changed()


# --- Character ---------------------------------------------------------------

## Saves a look from the customise popup: {skin_tone, hair_tone, cosmetics}.
func set_look(look: Dictionary) -> void:
	state.profile["skin_tone"] = int(look.get("skin_tone", 0))
	state.profile["hair_tone"] = int(look.get("hair_tone", 0))
	state.profile["cosmetics"] = (look.get("cosmetics", {}) as Dictionary).duplicate()
	_changed()


# --- Walks -------------------------------------------------------------------

func start_walk(project_id: String, goal_seconds: int = -1, biome_id: String = "") -> void:
	if goal_seconds < 0:
		goal_seconds = int(state.settings.get("walk_goal_seconds", 0))
	if biome_id == "":
		biome_id = str(state.settings.get("walk_biome", "lake"))
	state.active = SessionClock.begin(project_id, now(), goal_seconds, biome_id)
	_changed()


func pause_walk() -> void:
	if state.active:
		state.active.pause(now())
		_changed()


func resume_walk() -> void:
	if state.active:
		state.active.resume(now())
		_changed()


## Ends the walk, logs it, rolls the gift and returns a summary for the
## focus complete screen: {session: FocusSession, gift: Dictionary}.
func finish_walk() -> Dictionary:
	var clock := state.active
	if clock == null:
		return {}
	var t := now()
	var seconds := clock.elapsed(t)
	var project := state.project(clock.project_id)
	var animal_id := project.animal_id if project else ""

	var pity := int(state.profile.get("walks_since_epic", 0))
	var gift := GiftRoller.roll(seconds, animal_id, pity, Content.drop_table, Content.gifts, rng)
	state.profile["walks_since_epic"] = GiftRoller.next_pity_count(pity, seconds, gift.get("rarity", ""), Content.drop_table)

	var s := _log_walk(clock, t, gift.get("gift_id", ""))
	if s.gift_id != "":
		state.inventory[s.gift_id] = int(state.inventory.get(s.gift_id, 0)) + 1
	state.active = null
	_changed()
	return {"session": s, "gift": gift}


func cancel_walk() -> void:
	state.active = null
	_changed()


## A walk still running at launch means the app was closed (or killed) in
## the middle of it. It stops where the app was last seen open and the time
## still counts, but the pet never got to finish looking: no gift.
func _end_left_walk() -> Dictionary:
	var clock := state.active
	var s := _log_walk(clock, clock.left_at(SaveSystem.saved_unix(), now()), "")
	state.active = null
	return {"session": s, "biome": clock.biome_id}


## Logs a walk that ended at `end_unix` (walks under a minute, mis-taps,
## aren't worth keeping) and returns it either way.
func _log_walk(clock: SessionClock, end_unix: int, gift_id: String) -> FocusSession:
	var project := state.project(clock.project_id)
	var s := FocusSession.new()
	s.id = "s%d_%04x" % [end_unix, rng.randi() & 0xffff]
	s.project_id = clock.project_id
	s.animal_id = project.animal_id if project else ""
	s.start_unix = clock.start_unix
	s.end_unix = end_unix
	s.focus_seconds = clock.elapsed(end_unix)
	s.gift_id = gift_id
	if s.focus_seconds >= 60:
		state.sessions.append(s)
	return s


# --- Internals ---------------------------------------------------------------

func _changed() -> void:
	save()
	state_changed.emit()


func _first_launch_state() -> GameState:
	var v1_path := SaveSystem.v1_save_path()
	if FileAccess.file_exists(v1_path):
		var imported := SaveSystem.import_v1(FileAccess.get_file_as_string(v1_path), now())
		imported_from_v1 = true
		return imported
	var s := GameState.new()
	s.profile["created_unix"] = now()
	return s
