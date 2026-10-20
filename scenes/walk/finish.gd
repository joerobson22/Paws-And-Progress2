extends Control
## Focus complete: your pet in the middle holding the gift it found, glowing
## in the gift's rarity colour, with the time you focused and what the gift
## is. The arrow in the bottom right goes back to the focus screen.
## params: {"session": FocusSession, "gift": Dictionary} from App.finish_walk().

var params := {}

var _glow: _Glow
var _animal: AnimalView
var _stage: Control


func _ready() -> void:
	var session: FocusSession = params.get("session")
	var roll: Dictionary = params.get("gift", {})
	var project := App.state.project(session.project_id) if session else null
	Audio.ambience("")

	var bg := ColorRect.new()
	bg.color = UI.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var colour := Content.rarity_colour(roll.get("rarity", "common")) if not roll.is_empty() else UI.ACCENT
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_glow = _Glow.new()
	_glow.colour = colour
	_glow.strength = 1.0 if not roll.is_empty() else 0.35
	_stage.add_child(_glow)
	if project:
		_animal = AnimalView.new()
		_animal.animal_id = project.animal_id
		_animal.colours = project.colours
		_animal.held_gift = roll.get("gift_id", "")
		_stage.add_child(_animal)

	var insets := UI.safe_insets(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24 + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", 24 + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 56 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 26 + int(insets["bottom"]))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := UI.vbox(6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var title := _centred(UI.label("Focus complete", 40, UI.ON_DARK, true, 600))
	col.add_child(title)
	var seconds := session.focus_seconds if session else 0
	var time := _centred(UI.label(SessionClock.format(seconds), 24, UI.ON_DARK_SOFT, true, 500))
	col.add_child(time)
	col.add_child(UI.spacer(true))

	var found := UI.vbox(4)
	found.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if roll.is_empty():
		found.add_child(_centred(UI.label("No gift this time", 24, UI.ON_DARK, true, 600)))
		var why := "Walks under a minute aren't saved." if seconds < 60 else \
			"Focus for %d minutes or more and your pet finds you one." % (int(Content.drop_table.get("min_seconds", 600)) / 60)
		found.add_child(_centred(UI.para(why, 15, UI.ON_DARK_SOFT)))
	else:
		var g := Content.gift(roll["gift_id"])
		var rarity: String = roll["rarity"]
		found.add_child(_centred(UI.label("You got %s gift" % UI.a(Content.rarity_name(rarity).to_lower()), 16, colour.lightened(0.35), false, 800)))
		found.add_child(_centred(UI.label(g.get("name", "?"), 32, UI.ON_DARK, true, 600)))
		var desc := _centred(UI.para(g.get("description", ""), 15, UI.ON_DARK_SOFT))
		desc.custom_minimum_size.x = minf(420.0, size.x - 48.0)
		desc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		found.add_child(desc)
	col.add_child(found)

	var bottom := UI.hbox()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(UI.spacer())
	var next := UI.round_button("arrow_right", "Back home", go_back, UI.SURFACE, UI.INK, 64)
	bottom.add_child(next)
	col.add_child(bottom)

	resized.connect(_place)
	_place()
	# Everything arrives in turn.
	var items: Array[Control] = [title, time, found, next]
	for i in items.size():
		items[i].modulate.a = 0.0
	_appear.call_deferred(items)
	if not roll.is_empty():
		Audio.play("chime", 1.0, -6.0)


func go_back() -> void:
	App.go("home")


func _appear(items: Array[Control]) -> void:
	for i in items.size():
		Motion.enter(items[i], 0.15 + i * 0.12)
	if _animal:
		Motion.float_loop(_animal, 5.0, 2.2)


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Puts the pet in the middle, big, with the glow centred on the gift.
func _place() -> void:
	var s := minf(size.x, size.y) / 720.0 * 2.3
	var feet := Vector2(size.x * 0.47, size.y * 0.58)
	if _animal:
		var k := s / maxf(0.7, float(Content.animal(_animal.animal_id).get("size", 1.0)))
		_animal.scale = Vector2(k, k)
		_animal.position = feet
		_glow.centre = feet + _animal.mouth() * k
	else:
		_glow.centre = feet
	_glow.radius = minf(size.x, size.y) * 0.32
	_glow.size = size


## A soft, slowly breathing radial glow in the gift's rarity colour.
class _Glow extends Control:
	var colour := Color.WHITE
	var strength := 1.0
	var centre := Vector2.ZERO
	var radius := 200.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var breathe := 1.0 + 0.05 * sin(_time * 1.4)
		for i in 16:
			var t := 1.0 - i / 16.0
			draw_circle(centre, radius * breathe * (0.25 + 0.75 * t), Color(colour, 0.05 * strength), true, -1.0, true)
		draw_circle(centre, radius * 0.16 * breathe, Color(colour.lightened(0.4), 0.35 * strength), true, -1.0, true)
