extends Control
## The focus walk. Text is kept to the time, what you're working on and a
## quiet line of encouragement. The button in the bottom right ends the walk
## and shows what gift is waiting (see GiftButton); when there is one, your
## pet dives into a bush and comes back out carrying it.
## Time on screen always comes from the session's timestamps (SessionClock),
## never from counting frames, so it stays right after the app is
## backgrounded, the laptop sleeps, or the app is killed and reopened.
## params: {"from": where the opening circle grew from}

var params := {}

## Ground pixels per second at walk speed 1.0 (at 720px tall).
const BASE_SPEED := 70.0

var _scenery: Scenery
var _actors := Node2D.new()
var _walker: CharacterView
var _animal: AnimalView
var _bush: _Bush
var _project: ProjectData
var _hud: Control
var _timer: Label
var _pause: Button
var _gift: GiftButton
var _last_second := -1
var _period_check := 0.0
var _render_check := 0.0
## Scenery speed; eases down to 0 when the pet goes to fetch a gift.
var _pace := 1.0
var _lead_alpha := 1.0
var _finishing := false
var _done := false
var _result := {}


func _ready() -> void:
	var clock := App.state.active
	_project = App.state.project(clock.project_id) if clock else null
	if _project == null:
		# The project was deleted mid-walk, or there's no walk: nothing to show.
		App.cancel_walk()
		App.go.call_deferred("home", {})
		return

	_scenery = Scenery.new()
	_scenery.biome = Content.biome(clock.biome_id)
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Start somewhere different each walk.
	_scenery.scroll = App.rng.randf_range(0.0, 100000.0)
	add_child(_scenery)

	add_child(_actors)
	_actors.draw.connect(_draw_lead)
	_walker = CharacterView.new()
	_actors.add_child(_walker)
	_animal = AnimalView.new()
	_animal.animal_id = _project.animal_id
	_animal.colours = _project.colours
	_actors.add_child(_animal)

	_build_hud(clock)
	DisplayServer.screen_set_keep_on(App.state.settings.get("keep_screen_on", true))
	resized.connect(_layout)
	_layout()
	_update_period()
	_apply_paused(clock.is_paused())
	_gift.set_seconds(clock.elapsed(App.now()))


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)
	RenderingServer.render_loop_enabled = true


func _notification(what: int) -> void:
	# Nothing to draw while the app is in the background.
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			RenderingServer.render_loop_enabled = false
		NOTIFICATION_APPLICATION_RESUMED:
			RenderingServer.render_loop_enabled = true


func _build_hud(clock: SessionClock) -> void:
	var insets := UI.safe_insets(self)
	var wide := UI.is_wide(self)
	_hud = MarginContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_theme_constant_override("margin_left", 22 + int(insets["left"]))
	_hud.add_theme_constant_override("margin_right", 22 + int(insets["right"]))
	_hud.add_theme_constant_override("margin_top", (40 if wide else 56) + int(insets["top"]))
	_hud.add_theme_constant_override("margin_bottom", 26 + int(insets["bottom"]))
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var col := UI.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(col)

	_timer = _shadowed(UI.label("00:00:00", 84 if wide else 64, UI.ON_DARK, true, 500))
	col.add_child(_timer)
	var title := _shadowed(UI.label(_project.name, 22, UI.ON_DARK, true, 500))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var quote := _shadowed(UI.label(Content.quote(clock.start_unix), 15, UI.ON_DARK_SOFT, false, 700))
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size.x = minf(440.0, size.x - 60.0)
	quote.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(quote)
	col.add_child(UI.spacer(true))

	var bottom := UI.hbox()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause = UI.round_button("pause", "Pause", _toggle_pause, UI.GLASS, Color.WHITE, 52, false)
	_pause.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(_pause)
	bottom.add_child(UI.spacer())
	_gift = GiftButton.new()
	_gift.pressed.connect(_on_gift_pressed)
	bottom.add_child(_gift)
	col.add_child(bottom)


## Centred text with a soft shadow so it reads over any scenery.
func _shadowed(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## How big things are drawn: 720 is the short side of the design size, so
## phones and desktops match.
func _unit() -> float:
	return minf(size.x, size.y) / 720.0


func _layout() -> void:
	if _scenery == null:
		return
	var s := _unit()
	var feet := _scenery.path_y()
	var x := size.x * (0.3 if size.x < size.y else 0.38)
	_walker.scale = Vector2(s, s)
	_walker.position = Vector2(x, feet)
	if not _finishing:
		_animal.scale = Vector2(s, s)
		_animal.position = Vector2(x + 170.0 * s, feet + 4.0 * s)


func _process(delta: float) -> void:
	var clock := App.state.active
	if _scenery == null:
		return
	if clock == null or not clock.is_paused():
		var walk_speed := float(Content.animal(_project.animal_id).get("walk_speed", 1.0))
		var motion := 0.35 if App.state.settings.get("reduce_motion", false) else 1.0
		_scenery.scroll += delta * BASE_SPEED * walk_speed * motion * _unit() * _pace
	_actors.queue_redraw()

	if clock:
		var elapsed := clock.elapsed(App.now())
		if elapsed != _last_second:
			_last_second = elapsed
			_timer.text = SessionClock.format(elapsed)
			_gift.set_seconds(elapsed)

	_period_check -= delta
	if _period_check <= 0.0:
		_update_period()
	_render_check -= delta
	if _render_check <= 0.0:
		_render_check = 0.5
		# A minimised window shows nothing, so stop drawing until it's back.
		var hidden := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
		if RenderingServer.render_loop_enabled == hidden:
			RenderingServer.render_loop_enabled = not hidden


func _draw_lead() -> void:
	if _lead_alpha <= 0.0:
		return
	var hand := _walker.position + _walker.hand * _walker.scale
	var collar := _animal.position + Vector2(40, -55) * _animal.scale * float(Content.animal(_project.animal_id).get("size", 1.0))
	var mid := (hand + collar) * 0.5 + Vector2(0, 26.0 * _walker.scale.y)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(hand.lerp(mid, t).lerp(mid.lerp(collar, t), t))
	_actors.draw_polyline(pts, Color("#7a3b2e", _lead_alpha), 3.0 * _walker.scale.x, true)


func _update_period() -> void:
	_period_check = 30.0
	var hour := int(Time.get_datetime_dict_from_system()["hour"])
	_scenery.period = Content.time_of_day(hour)
	Audio.ambience("night" if _scenery.period == "night" else str(_scenery.biome.get("ambience", "day")))


func _toggle_pause() -> void:
	if App.state.active == null:
		return
	if App.state.active.is_paused():
		App.resume_walk()
	else:
		App.pause_walk()
	_apply_paused(App.state.active.is_paused())


func _apply_paused(paused: bool) -> void:
	_pause.icon = Icons.texture("play" if paused else "pause", 22, Color.WHITE)
	_pause.tooltip_text = "Carry on" if paused else "Pause"
	_walker.walking = not paused
	_animal.walking = not paused
	var walk_speed := float(Content.animal(_project.animal_id).get("walk_speed", 1.0))
	_walker.speed = clampf(walk_speed, 0.3, 1.2)
	Motion.fade(_timer, 0.55 if paused else 1.0)


# --- Finishing ---------------------------------------------------------------

func _on_gift_pressed() -> void:
	if _finishing or App.state.active == null:
		return
	var seconds := App.state.active.elapsed(App.now())
	if GiftRoller.min_rarity(seconds, Content.drop_table) == "":
		var left := int(Content.drop_table.get("min_seconds", 600)) - seconds
		var minutes := ceili(left / 60.0)
		var animal_name: String = Content.animal(_project.animal_id).get("name", "")
		Modal.confirm("End your walk?",
			"Your %s hasn't found a gift yet. %s more and it will." % [animal_name.to_lower(), "1 minute" if minutes == 1 else "%d minutes" % minutes],
			"End walk", "danger", "Keep walking").closed.connect(func(ok):
				if ok:
					_end())
		return
	_end()


func _end() -> void:
	_finishing = true
	_result = App.finish_walk()
	Motion.fade(_hud, 0.0)
	var gift: Dictionary = _result.get("gift", {})
	if gift.is_empty():
		_walker.walking = false
		_animal.walking = false
		_go_finish()
		return
	# Tap anywhere to skip straight to the gift.
	var skip := Control.new()
	skip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_go_finish())
	add_child(skip)
	_dive(str(gift["gift_id"]))


## The pet stops, dives into a bush, rustles about and comes back out with
## the gift. How it gets there comes from its "dive" in data/animals.json.
func _dive(gift_id: String) -> void:
	var s := _unit()
	var dive: Dictionary = Content.animal(_project.animal_id).get("dive", {})
	var hops := int(dive.get("hops", 1))
	var height := float(dive.get("height", 80)) * s
	var seconds := float(dive.get("seconds", 0.9))
	var feet := _scenery.path_y()

	_bush = _Bush.new()
	_bush.scale = Vector2(s, s)
	_bush.position = Vector2(size.x + 160.0 * s, feet + 6.0 * s)
	_actors.add_child(_bush)
	var t := Motion.tween(self, "dive")
	t.set_parallel(true)
	t.tween_method(_set_pace, 1.0, 0.0, Motion.time(1.0))
	t.tween_property(_bush, "position:x", minf(size.x * 0.82, _animal.position.x + 260.0 * s), Motion.time(1.0))
	t.tween_property(self, "_lead_alpha", 0.0, Motion.time(0.5))
	await t.finished
	if _done:
		return

	var start := _animal.position
	var inside := _bush.position + Vector2(-6.0 * s, -4.0 * s)
	_animal.walking = hops == 0
	t = Motion.tween(self, "dive")
	t.tween_method(_hop.bind(start, inside, hops, height, 1.0), 0.0, 1.0, Motion.time(seconds))
	t.parallel().tween_property(_animal, "modulate:a", 0.0, Motion.time(0.2)).set_delay(Motion.time(seconds * 0.85))
	await t.finished
	if _done:
		return

	Audio.play("rustle")
	t = Motion.tween(_bush, "rustle")
	for i in 7:
		t.tween_property(_bush, "rotation", 0.07 * (1.0 if i % 2 == 0 else -1.0), 0.1)
	t.tween_property(_bush, "rotation", 0.0, 0.1)
	await t.finished
	if _done:
		return

	_animal.held_gift = gift_id
	_animal.scale.x = -absf(_animal.scale.x)
	_animal.walking = hops == 0
	Audio.play(str(Content.animal(_project.animal_id).get("sound", "")), 1.0, -4.0)
	var out := start + Vector2(30.0 * s, 0)
	t = Motion.tween(self, "dive")
	t.tween_property(_animal, "modulate:a", 1.0, Motion.time(0.15))
	t.parallel().tween_method(_hop.bind(inside, out, maxi(hops, 1), height * 0.6, -1.0), 0.0, 1.0, Motion.time(maxf(0.8, seconds * 0.8)))
	await t.finished
	_animal.walking = false
	_animal.scale.x = absf(_animal.scale.x)
	Motion.pop(_animal, 0.12)
	Audio.play("chime", 1.0, -6.0)
	await get_tree().create_timer(Motion.time(0.7)).timeout
	_go_finish()


func _set_pace(v: float) -> void:
	_pace = v
	if v < 0.05:
		_walker.walking = false


## One frame of a hop (or a slide, with no hops) from `from` to `to`.
func _hop(t: float, from: Vector2, to: Vector2, hops: int, height: float, facing: float) -> void:
	var p := from.lerp(to, t)
	if hops > 0:
		p.y -= absf(sin(t * PI * hops)) * height
		_animal.rotation = -cos(t * PI * hops) * 0.22 * facing
	else:
		_animal.rotation = 0.0
	_animal.position = p


func _go_finish() -> void:
	if _done:
		return
	_done = true
	var params_out := _result.duplicate()
	params_out["from"] = _animal.get_global_transform_with_canvas() * Vector2(0, -40)
	App.go("finish", params_out)


## A round leafy bush, drawn in front of the pet as it dives in. The origin
## is where it meets the ground.
class _Bush extends Node2D:
	func _draw() -> void:
		var greens := [Color("#4e7a46"), Color("#5f8f52"), Color("#6fa45e")]
		var blobs := [[-58, -28, 34], [58, -26, 32], [-30, -58, 40], [26, -60, 42], [0, -32, 46], [-6, -86, 34], [44, -44, 30], [-48, -50, 30]]
		for i in blobs.size():
			var b: Array = blobs[i]
			draw_circle(Vector2(b[0], b[1]), b[2], greens[i % greens.size()], true, -1.0, true)
		for i in 9:
			var a := -PI + PI * i / 8.0
			draw_circle(Vector2(cos(a) * 46.0, -50.0 + sin(a) * 40.0), 4.0, Color("#86b874"), true, -1.0, true)
