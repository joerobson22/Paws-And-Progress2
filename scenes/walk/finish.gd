extends Control
## Focus complete. It carries straight on from the walk's scene: a quarter-
## black sheet settles over the scenery so the animal stands out, the camera
## zooms in on it holding its gift (glowing in the gift's rarity colour), and
## the words fade in. Then your level bar appears with "+X xp" underneath and
## fills, X counting down as it goes, popping and starting again at each new
## level. Once it's done, the home button fades in.
##
## Easter egg: press and hold the gift to take it. Drag it about, and let go
## with a flick to throw it (up the screen throws it into the distance, to
## the sides off the screen). Your pet runs after it, wading if it lands in
## water, and brings it back. You can take it again once they're home.
## params: {"session", "gift", "scene": {biome, scroll, period, walker, animal, unit}}

var params := {}

## How strongly the sheet darkens the scenery.
const SHEET_ALPHA := 0.25
## Throws slower than this (pixels a second) just put the gift back.
const THROW_SPEED := 450.0

var _stage := Control.new()
var _scenery: Scenery
var _back_actors := Node2D.new()
var _front_actors := Node2D.new()
var _sheet := ColorRect.new()
var _walker: CharacterView
var _animal: AnimalView
var _glow: _Glow
var _catcher := Control.new()
var _ui := Control.new()
var _hand := Control.new()
var _words: Array[Control] = []
var _bar: LevelBar
var _xp_label: Label
var _home: Button
var _project: ProjectData
var _gift_id := ""
var _unit := 1.0
var _rest := Vector2.ZERO  # where the animal stands, in stage space
var _rest_scale := 1.0
var _xp_to := 0

# The easter egg: "intro" until the zoom ends, then "ready", "pressing",
# "holding", "flying" and "fetching".
var _state := "intro"
var _held: GiftArt
var _hold_target := Vector2.ZERO
var _press_at := Vector2.ZERO
var _velocity := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _last_time := 0
var _fly: GiftArt
var _fly_state := {}  # x, z, h, vx, vz, vh


func _ready() -> void:
	var session: FocusSession = params.get("session")
	var roll: Dictionary = params.get("gift", {})
	_project = App.state.project(session.project_id) if session else null
	_gift_id = str(roll.get("gift_id", ""))
	var scene: Dictionary = params.get("scene", {})
	_unit = float(scene.get("unit", minf(size.x, size.y) / 720.0))
	Audio.ambience("")

	_stage.size = size
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_scenery = Scenery.new()
	_scenery.biome = Content.biome(str(scene.get("biome", App.state.settings.get("walk_biome", "lake"))))
	_scenery.period = str(scene.get("period", Content.time_of_day(int(Time.get_datetime_dict_from_system()["hour"]))))
	_scenery.scroll = float(scene.get("scroll", 0.0))
	_scenery.size = size
	_stage.add_child(_scenery)
	_stage.add_child(_back_actors)
	_sheet.color = Color(0, 0, 0, 0)
	_sheet.size = size
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_sheet)
	_stage.add_child(_front_actors)

	var feet := _scenery.path_y()
	_walker = CharacterView.new()
	_walker.scale = Vector2(_unit, _unit)
	_walker.position = scene.get("walker", Vector2(size.x * 0.38, feet))
	_back_actors.add_child(_walker)
	_glow = _Glow.new()
	_glow.colour = Content.rarity_colour(roll.get("rarity", "common")) if not roll.is_empty() else UI.ACCENT
	_glow.strength = 0.0
	_front_actors.add_child(_glow)
	if _project:
		_animal = AnimalView.new()
		_animal.animal_id = _project.animal_id
		_animal.colours = _project.colours
		_animal.held_gift = _gift_id
		_animal.water_colour = _scenery.water_colour()
		_rest = scene.get("animal", Vector2(size.x * 0.38 + 170.0 * _unit, feet + 4.0 * _unit))
		_rest_scale = _unit
		_animal.position = _rest
		_animal.scale = Vector2(_unit, _unit)
		_front_actors.add_child(_animal)
		_glow.radius = 70.0 * _unit
		_place_glow()

	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_input)
	add_child(_catcher)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_hand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)
	_build_words(session, roll)
	_play.call_deferred()
	if not roll.is_empty():
		Audio.play("chime", 1.0, -6.0)


func go_back() -> void:
	App.go("home")


# --- The words ---------------------------------------------------------------

func _build_words(session: FocusSession, roll: Dictionary) -> void:
	var insets := UI.safe_insets(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24 + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", 24 + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 46 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 24 + int(insets["bottom"]))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(margin)
	var col := UI.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var seconds := session.focus_seconds if session else 0
	var title := _word(UI.label("Focus complete", 40, UI.ON_DARK, true, 600))
	col.add_child(title)
	var time := _word(UI.label(SessionClock.format(seconds), 24, UI.ON_DARK_SOFT, true, 500))
	col.add_child(time)
	col.add_child(UI.spacer(true))

	var found := UI.vbox(2)
	found.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var colour := Content.rarity_colour(roll.get("rarity", "common"))
	if roll.is_empty():
		found.add_child(_word(UI.label("No gift this time", 24, UI.ON_DARK, true, 600)))
		var why := "Walks under a minute aren't saved." if seconds < 60 else \
			"Focus for %d minutes or more and your pet finds you one." % (int(Content.drop_table.get("min_seconds", 600)) / 60)
		found.add_child(_word(UI.para(why, 15, UI.ON_DARK_SOFT)))
	else:
		var g := Content.gift(_gift_id)
		var finder := Content.pet_called(_project, true) if _project else "Your pet"
		found.add_child(_word(UI.label("%s found you %s gift" % [finder, UI.a(Content.rarity_name(roll["rarity"]).to_lower())], 16, colour.lightened(0.4), false, 800)))
		found.add_child(_word(UI.label(g.get("name", "?"), 30, UI.ON_DARK, true, 600)))
		var desc := _word(UI.para(g.get("description", ""), 15, UI.ON_DARK_SOFT))
		desc.custom_minimum_size.x = minf(420.0, size.x - 48.0)
		desc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		found.add_child(desc)
	col.add_child(found)
	_words = [title, time, found]
	for w in _words:
		w.modulate.a = 0.0

	# Your level, then the XP this walk earned.
	var earned := Levels.walk_xp(seconds, str(roll.get("rarity", "")), Content.levels) if seconds >= 60 else 0
	_xp_to = App.xp()
	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = LevelBar.new(_xp_to - earned, true)
	_bar.custom_minimum_size.x = minf(380.0, size.x - 140.0)
	level_row.add_child(_bar)
	level_row.modulate.a = 0.0
	col.add_child(UI.spacer())
	col.add_child(level_row)
	_xp_label = _word(UI.label("+%d xp" % earned, 18, UI.ON_DARK, true, 600))
	_xp_label.modulate.a = 0.0
	col.add_child(_xp_label)
	_bar.shown_changed.connect(func(xp: int): _xp_label.text = "+%d xp" % maxi(0, _xp_to - xp))
	_bar.levelled_up.connect(_on_level_up)

	var bottom := UI.hbox()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(UI.spacer())
	_home = UI.round_button("home", "Home", go_back, Color.WHITE, UI.ACCENT.darkened(0.2), 64)
	_home.modulate.a = 0.0
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_home)
	col.add_child(bottom)


## Centred light text with a soft shadow.
func _word(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- The sequence ------------------------------------------------------------

func _play() -> void:
	# The sheet settles and the camera moves in on the animal.
	var zoom := _zoom_target()
	var t := Motion.tween(self, "zoom")
	t.set_parallel(true)
	t.tween_property(_sheet, "color:a", SHEET_ALPHA, Motion.time(0.6))
	t.tween_property(_stage, "scale", Vector2.ONE * zoom["scale"], Motion.time(1.0))
	t.tween_property(_stage, "position", zoom["position"], Motion.time(1.0))
	t.tween_property(_glow, "strength", 1.0 if _gift_id != "" else 0.35, Motion.time(1.0))
	await t.finished
	if _animal and _gift_id != "":
		_state = "ready"

	# Then the words, one after another.
	for i in _words.size():
		Motion.enter(_words[i], i * 0.14)
	await get_tree().create_timer(Motion.time(0.4 + _words.size() * 0.14)).timeout

	# Then the level bar, the XP pouring into it, and finally the way home.
	Motion.enter(_bar.get_parent())
	await get_tree().create_timer(Motion.time(Motion.NORMAL)).timeout
	_xp_label.modulate.a = 1.0
	Motion.pop(_xp_label, 0.3, 0.4)
	await get_tree().create_timer(Motion.time(0.5)).timeout
	await _bar.animate_to(_xp_to)
	Motion.fade(_xp_label, 0.0)
	_home.mouse_filter = Control.MOUSE_FILTER_STOP
	Motion.fade(_home, 1.0, Motion.SLOW)


## The camera: zoomed so the animal fills a good share of the screen, with
## it near the middle, never showing past the scenery's edges.
func _zoom_target() -> Dictionary:
	var k := 1.6
	var focus := size * Vector2(0.5, 0.6)
	if _animal:
		k = clampf(2.5 / float(Content.animal(_animal.animal_id).get("size", 1.0)), 1.6, 3.0)
		focus = _animal.position + Vector2(0, -45.0 * _unit)
	var p := size * Vector2(0.5, 0.42) - focus * k
	p.x = clampf(p.x, size.x - k * size.x, 0.0)
	p.y = clampf(p.y, size.y - k * size.y, 0.0)
	return {"scale": k, "position": p}


func _on_level_up(level: int) -> void:
	var unlocked: Array = Levels.rewards(Content.levels).filter(func(r): return int(r["level"]) == level)
	var names := unlocked.map(func(r): return Content.biome(r["id"]).get("name", "") if r["type"] == "place" else Content.animal(r["id"]).get("name", ""))
	Toast.show_text("Level %d!%s" % [level, (" %s unlocked" % ", ".join(names)) if not names.is_empty() else ""], "star")


func _place_glow() -> void:
	if _animal:
		_glow.position = _animal.position + _animal.mouth() * _animal.scale


# --- Easter egg: throw the gift -------------------------------------------

## The gift in the animal's mouth, on screen.
func _gift_on_screen() -> Vector2:
	return _stage.position + _stage.scale * (_animal.position + _animal.mouth() * _animal.scale)


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and _state == "ready" and e.position.distance_to(_gift_on_screen()) < 56.0:
			_state = "pressing"
			_press_at = e.position
			_track(e.position, true)
			get_tree().create_timer(0.18).timeout.connect(func():
				if _state == "pressing":
					_pick_up(_press_at))
		elif not e.pressed:
			if _state == "pressing":
				# Just a tap: a happy wiggle.
				_state = "ready"
				Motion.pop(_animal, 0.08)
			elif _state == "holding":
				_let_go()
	elif e is InputEventMouseMotion:
		if _state == "pressing" and e.position.distance_to(_press_at) > Gestures.TAP_SLOP:
			_pick_up(e.position)
		if _state == "holding":
			_hold_target = e.position
			_track(e.position)


## Keeps a smoothed pointer speed, for the throw.
func _track(pointer: Vector2, reset: bool = false) -> void:
	var now := Time.get_ticks_usec()
	if reset:
		_velocity = Vector2.ZERO
	else:
		var dt := maxf((now - _last_time) / 1000000.0, 0.001)
		_velocity = _velocity.lerp((pointer - _last_pointer) / dt, 0.45)
	_last_pointer = pointer
	_last_time = now


## Takes the gift from the animal and holds it up close.
func _pick_up(pointer: Vector2) -> void:
	_state = "holding"
	var from := _gift_on_screen()
	_animal.held_gift = ""
	Motion.to(_glow, "strength", 0.0, Motion.FAST)
	_held = GiftArt.new(_gift_id, 1.0)
	_held.size = Vector2(130, 130)
	_held.pivot_offset = _held.size * 0.5
	_held.position = from - _held.size * 0.5
	_held.scale = Vector2.ONE * 0.25
	_hand.add_child(_held)
	_hold_target = pointer
	Motion.to(_held, "scale", Vector2.ONE, Motion.FAST)
	Audio.play("pop", 0.9, -6.0)


func _process(delta: float) -> void:
	if _state == "holding" and is_instance_valid(_held):
		var at := _held.position + _held.size * 0.5
		_held.position = at.lerp(_hold_target, minf(1.0, delta * 18.0)) - _held.size * 0.5
	elif _state == "flying":
		_fly_step(delta)


func _let_go() -> void:
	if _velocity.length() >= THROW_SPEED:
		_throw(_velocity)
		return
	# Not thrown: it goes back in the animal's mouth.
	_state = "intro"
	var back := _gift_on_screen()
	var held := _held
	var t := Motion.tween(held, "back")
	t.set_parallel(true)
	t.tween_property(held, "position", back - held.size * 0.5, Motion.time(Motion.FAST))
	t.tween_property(held, "scale", Vector2.ONE * 0.25, Motion.time(Motion.FAST))
	t.chain().tween_callback(func():
		held.queue_free()
		_animal.held_gift = _gift_id
		Motion.to(_glow, "strength", 1.0)
		_state = "ready")


# Depth: 0 is the path the animal stands on, 1 the far shore or treeline.

func _near_y() -> float:
	return _rest.y


## The furthest a throw can land: the far shore (or the treeline), but never
## above what the zoomed-in camera can see, so the fetch stays in view.
func _far_y() -> float:
	var water := _scenery.water_band()
	var far := water.x + 8.0 * _unit if water != Vector2.ZERO else _stage.size.y * 0.6
	var top_in_view := -_stage.position.y / _stage.scale.y + 50.0 * _unit
	return minf(maxf(far, top_in_view), _near_y() - 10.0 * _unit)


func _ground_y(z: float) -> float:
	return lerpf(_near_y(), _far_y(), clampf(z, 0.0, 1.0))


## Things further away are drawn smaller.
func _perspective(z: float) -> float:
	return lerpf(1.0, 0.35, clampf(z, 0.0, 1.0))


## Where the bank meets the water; above it on screen the animal is wading.
func _bank_y() -> float:
	var water := _scenery.water_band()
	return water.y if water != Vector2.ZERO else -INF


func _throw(v: Vector2) -> void:
	_state = "flying"
	Audio.play("whoosh", 1.1, -4.0)
	var k := _stage.scale.x
	var start := (_held.position + _held.size * 0.5 - _stage.position) / k
	var speed := v / k
	_fly = GiftArt.new(_gift_id, 0.6)
	_fly.size = Vector2(46, 46) * _unit
	_fly.pivot_offset = _fly.size * 0.5
	_front_actors.add_child(_fly)
	_held.queue_free()
	_fly_state = {
		"x": start.x, "z": 0.0, "h": maxf(0.0, _near_y() - start.y),
		"vx": speed.x * 0.85,
		"vz": clampf(-speed.y / 700.0, 0.0, 1.4),
		"vh": clampf(-speed.y * 0.3, 80.0, 700.0) * _unit + 160.0 * _unit,
	}
	_fly_step(0.0)


## One frame of the gift's flight: across, away and up, falling back down.
func _fly_step(dt: float) -> void:
	var f := _fly_state
	f["x"] += f["vx"] * dt * _perspective(f["z"])
	f["z"] = minf(1.0, f["z"] + f["vz"] * dt)
	f["h"] += f["vh"] * dt
	f["vh"] -= 1500.0 * _unit * dt
	var s := _perspective(f["z"])
	_fly.position = Vector2(f["x"], _ground_y(f["z"]) - f["h"] * s) - _fly.size * 0.5
	_fly.scale = Vector2.ONE * s
	_fly.rotation += dt * 6.0
	if f["h"] <= 0.0 and f["vh"] < 0.0:
		_land()


func _land() -> void:
	_state = "fetching"
	var f := _fly_state
	var spot := Vector2(f["x"], _ground_y(f["z"]))
	_fly.rotation = 0.0
	if spot.y < _bank_y():
		Audio.play("splash", 1.0, -2.0)
		var ripple := _Ripple.new()
		ripple.position = spot
		ripple.scale = Vector2.ONE * _perspective(f["z"]) * _unit
		_front_actors.add_child(ripple)
		_front_actors.move_child(ripple, 0)
		Motion.float_loop(_fly, 3.0 * _unit, 1.4)
	else:
		Audio.play("pop", 0.7, -8.0)
		Motion.pop(_fly, 0.15)
	_fetch(spot, f["z"])


## The animal runs out to the gift, picks it up, and runs back with it.
func _fetch(spot: Vector2, z: float) -> void:
	_animal.walking = true
	_animal.running = true
	var out_scale := _rest_scale * _perspective(z)
	await _run(_animal.position, spot + Vector2(-20.0 * out_scale, 0), _rest_scale, out_scale)
	_fly.queue_free()
	_animal.held_gift = _gift_id
	Audio.play(str(Content.animal(_animal.animal_id).get("sound", "")), 1.0, -6.0)
	Motion.pop(_animal, 0.1)
	await get_tree().create_timer(Motion.time(0.35)).timeout
	await _run(_animal.position, _rest, out_scale, _rest_scale)
	_animal.running = false
	_animal.walking = false
	_animal.submerged = 0.0
	_animal.scale = Vector2(_rest_scale, _rest_scale)
	_place_glow()
	Motion.to(_glow, "strength", 1.0)
	_state = "ready"


func _run(from: Vector2, to: Vector2, from_scale: float, to_scale: float) -> void:
	var facing := 1.0 if to.x >= from.x - 4.0 else -1.0
	# Distance as if on the near path, so far-off runs don't take forever.
	var distance := from.distance_to(to) / maxf(0.35, minf(from_scale, to_scale) / _rest_scale)
	var seconds := clampf(distance / (420.0 * _unit), 0.5, 2.4)
	var step := func(t: float):
		_animal.position = from.lerp(to, t)
		var s := lerpf(from_scale, to_scale, t)
		_animal.scale = Vector2(s * facing, s)
		# Wading: the further out past the bank, the deeper it goes.
		var into := _bank_y() - _animal.position.y
		_animal.submerged = clampf(into / maxf(0.01, s) * 1.2, 0.0, 26.0) if into > 0.0 else 0.0
	await Motion.method(self, "run", step, 0.0, 1.0, seconds).finished


## A soft glow round the gift, in its rarity's colour.
class _Glow extends Node2D:
	var colour := Color.WHITE
	var radius := 70.0
	var strength := 1.0:
		set(v):
			strength = v
			queue_redraw()
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var breathe := 1.0 + 0.06 * sin(_time * 1.4)
		for i in 14:
			var t := 1.0 - i / 14.0
			draw_circle(Vector2.ZERO, radius * breathe * (0.3 + 0.7 * t), Color(colour, 0.06 * strength), true, -1.0, true)
		draw_circle(Vector2.ZERO, radius * 0.22 * breathe, Color(colour.lightened(0.45), 0.4 * strength), true, -1.0, true)


## Rings spreading out where the gift splashed down.
class _Ripple extends Node2D:
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
		if _time > 2.4:
			queue_free()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		for i in 3:
			var t := _time - i * 0.35
			if t <= 0.0:
				continue
			var a := clampf(1.0 - t / 1.6, 0.0, 1.0)
			draw_arc(Vector2.ZERO, 12.0 + t * 55.0, 0, TAU, 40, Color(1, 1, 1, 0.7 * a), 3.0, true)
