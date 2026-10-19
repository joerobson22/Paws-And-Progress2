extends Control
## The focus walk. Time on screen always comes from the session's timestamps
## (SessionClock), never from counting frames, so it stays right after the app
## is backgrounded, the laptop sleeps, or the app is killed and reopened.

var params := {}

## Ground pixels per second at walk speed 1.0 (at 720px tall).
const BASE_SPEED := 70.0

var _scenery: Scenery
var _actors := Node2D.new()
var _walker: WalkerView
var _animal: AnimalView
var _project: ProjectData
var _timer_label: Label
var _hint_label: Label
var _odds_box: VBoxContainer
var _pause_button: Button
var _place_label: Label
var _sound_button: Button
var _last_second := -1
var _period_check := 0.0


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
	_walker = WalkerView.new()
	_actors.add_child(_walker)
	_animal = AnimalView.new()
	_animal.animal_id = _project.animal_id
	_animal.colours = _project.colours
	_actors.add_child(_animal)

	_build_hud()
	DisplayServer.screen_set_keep_on(App.state.settings.get("keep_screen_on", true))
	resized.connect(_layout)
	_layout()
	_update_period()
	_apply_paused(clock.is_paused())


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


func _build_hud() -> void:
	var wide := UI.is_wide(self)
	var hud := MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		hud.add_theme_constant_override("margin_" + side, 24 if wide else 14)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var col := UI.vbox(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(col)

	var top := UI.hbox(16)
	col.add_child(top)
	var who := _glass(999)
	var who_row := UI.hbox(10)
	var face := UI.animal_portrait(_project.animal_id, _project.colours, Vector2(40, 40), UI.SAGE)
	var round := face.get_theme_stylebox("panel").duplicate()
	round.set_corner_radius_all(999)
	face.add_theme_stylebox_override("panel", round)
	who_row.add_child(face)
	var animal_name: String = Content.animal(_project.animal_id).get("name", "")
	var who_text := UI.label("%s  with the %s" % [_project.name, animal_name.to_lower()], 15, UI.PAPER, false, 800)
	who_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who_row.add_child(who_text)
	who.add_child(who_row)
	var wb: StyleBoxFlat = who.get_theme_stylebox("panel")
	wb.content_margin_left = 6
	wb.content_margin_top = 6
	wb.content_margin_bottom = 6
	who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(who)
	top.add_child(UI.spacer())

	var odds := _glass()
	odds.custom_minimum_size.x = 240
	odds.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_odds_box = UI.vbox(6)
	odds.add_child(_odds_box)
	if wide:
		top.add_child(odds)

	var centre := UI.vbox(8)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_label = UI.label("00:00:00", 96 if wide else 64, UI.PAPER, true, 500)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	_timer_label.add_theme_constant_override("shadow_offset_y", 4)
	centre.add_child(_timer_label)
	var hint := _glass()
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint_label = UI.label("", 14, UI.PAPER, false, 700)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_child(_hint_label)
	centre.add_child(hint)
	col.add_child(centre)
	if not wide:
		odds.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(odds)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)

	var bottom := UI.hbox(12)
	col.add_child(bottom)
	if wide:
		bottom.add_child(UI.spacer())
	var controls := PanelContainer.new()
	var cb := UI.box(Color(UI.PAPER, 0.94), Color.TRANSPARENT, 24)
	cb.set_content_margin_all(10)
	controls.add_theme_stylebox_override("panel", cb)
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_EXPAND_FILL
	var row := UI.hbox(10)
	controls.add_child(row)
	_sound_button = UI.icon_button("sound", "Ambient sound", _toggle_ambience, UI.TRACK, UI.INK, 52, 16)
	row.add_child(_sound_button)
	_pause_button = UI.button("Pause", _toggle_pause, UI.INK, UI.PAPER)
	_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_button.add_theme_constant_override("h_separation", 10)
	row.add_child(_pause_button)
	var home := UI.with_icon(UI.cta("Head home", _finish), "home", UI.ON_APRICOT, 18)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(home)
	_update_sound_button()
	bottom.add_child(controls)
	if wide:
		var place := HBoxContainer.new()
		place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		place.alignment = BoxContainer.ALIGNMENT_END
		var tag := _glass()
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_place_label = UI.label("", 14, UI.PAPER, false, 700)
		_place_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.add_child(_place_label)
		place.add_child(tag)
		bottom.add_child(place)


## Translucent dark pill used for text over the scenery.
func _glass(radius: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	var b := UI.box(Color(0.08, 0.12, 0.09, 0.42), Color(1, 1, 1, 0.18), radius)
	b.border_width_left = 1
	b.border_width_right = 1
	b.border_width_top = 1
	b.border_width_bottom = 1
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	b.content_margin_left = 16
	b.content_margin_right = 16
	p.add_theme_stylebox_override("panel", b)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _layout() -> void:
	if _scenery == null:
		return
	# 720 is the short side of the design size, so phones and desktops match.
	var s := minf(size.x, size.y) / 720.0
	var feet := _scenery.path_y()
	_walker.scale = Vector2(s, s)
	_walker.position = Vector2(size.x * 0.40, feet)
	_animal.scale = Vector2(s, s)
	_animal.position = Vector2(size.x * 0.40 + 170.0 * s, feet + 4.0 * s)


func _process(delta: float) -> void:
	var clock := App.state.active
	if clock == null or _scenery == null:
		return
	if not clock.is_paused():
		var walk_speed := float(Content.animal(_project.animal_id).get("walk_speed", 1.0))
		var motion := 0.35 if App.state.settings.get("reduce_motion", false) else 1.0
		_scenery.scroll += delta * BASE_SPEED * walk_speed * motion * (minf(size.x, size.y) / 720.0)
	_actors.queue_redraw()

	var elapsed := clock.elapsed(App.now())
	if elapsed != _last_second:
		_last_second = elapsed
		_timer_label.text = SessionClock.format(elapsed)
		_update_odds(elapsed)

	_period_check -= delta
	if _period_check <= 0.0:
		_update_period()


func _draw_lead() -> void:
	var hand := _walker.position + _walker.hand * _walker.scale
	var collar := _animal.position + Vector2(40, -55) * _animal.scale * float(Content.animal(_project.animal_id).get("size", 1.0))
	var mid := (hand + collar) * 0.5 + Vector2(0, 26.0 * _walker.scale.y)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(hand.lerp(mid, t).lerp(mid.lerp(collar, t), t))
	_actors.draw_polyline(pts, Color("#7a3b2e"), 3.0 * _walker.scale.x, true)


func _update_odds(elapsed: int) -> void:
	var table := Content.drop_table
	for c in _odds_box.get_children():
		c.queue_free()
	_odds_box.add_child(UI.label("GIFT ODDS RIGHT NOW", 12, Color("#dce7dd"), false, 800))
	var pct := GiftRoller.percentages_for(elapsed, table)
	if GiftRoller.weights_for(elapsed, table).is_empty():
		_odds_box.add_child(UI.label("No gift yet", 14, UI.PAPER, false, 800))
	else:
		_odds_box.add_child(UI.odds_bar(pct, true))

	var next := _next_tier_seconds(elapsed)
	var min_s := int(table.get("min_seconds", 600))
	var goal := App.state.active.goal_seconds
	if goal > 0 and elapsed >= goal:
		_hint_label.text = "You've walked your %s. Head home whenever you like" % Stats.format_duration(goal).replace(" 00m", "")
	elif elapsed < min_s:
		_hint_label.text = "A gift unlocks in %s" % _minutes(min_s - elapsed)
	elif next > 0:
		_hint_label.text = "Better odds in %s" % _minutes(next - elapsed)
	else:
		_hint_label.text = "Best odds reached"


func _next_tier_seconds(elapsed: int) -> int:
	for tier in Content.drop_table.get("tiers", []):
		if int(tier["min_seconds"]) > elapsed:
			return int(tier["min_seconds"])
	return 0


static func _minutes(seconds: int) -> String:
	var m := ceili(seconds / 60.0)
	return "1 minute" if m == 1 else "%d minutes" % m


func _update_period() -> void:
	_period_check = 30.0
	var hour := int(Time.get_datetime_dict_from_system()["hour"])
	_scenery.period = Content.time_of_day(hour)
	Audio.ambience(_ambience_name())
	if _place_label:
		_place_label.text = "%s · %s" % [_scenery.biome.get("name", ""), _scenery.period]


## Water by the lake by day; the night ambience after dark anywhere.
func _ambience_name() -> String:
	if _scenery.period == "night":
		return "night"
	return str(_scenery.biome.get("ambience", "day"))


func _toggle_ambience() -> void:
	App.set_setting("ambience", not App.state.settings.get("ambience", true))
	Audio.refresh(_ambience_name())
	_update_sound_button()


func _update_sound_button() -> void:
	var on: bool = App.state.settings.get("ambience", true)
	_sound_button.icon = Icons.texture("sound" if on else "mute", 20, UI.INK)


func _toggle_pause() -> void:
	if App.state.active.is_paused():
		App.resume_walk()
	else:
		App.pause_walk()
	_apply_paused(App.state.active.is_paused())


func _apply_paused(paused: bool) -> void:
	_pause_button.text = "Resume" if paused else "Pause"
	_pause_button.icon = Icons.texture("play" if paused else "pause", 16, UI.PAPER)
	_walker.walking = not paused
	_animal.walking = not paused
	var walk_speed := float(Content.animal(_project.animal_id).get("walk_speed", 1.0))
	_walker.speed = clampf(walk_speed, 0.3, 1.2)
	_timer_label.modulate.a = 0.6 if paused else 1.0


func _finish() -> void:
	var result := App.finish_walk()
	App.go("end_walk", result)
