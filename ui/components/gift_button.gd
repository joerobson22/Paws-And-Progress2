class_name GiftButton
extends Button
## The round button in the corner of a walk: a pie chart of what your pet
## will bring back. For the first ten minutes a dark green slice sweeps
## round as the first gift gets closer. At ten minutes it dings, pops and
## fills from the middle with bright green: a gift is on its way. From then
## on blue, purple and gold slices show the chance of a rare, epic or
## legendary gift, growing as the walk goes on; once a rarity is certain the
## ones below it drop out, with another pop. Pressing it ends the walk.

const DIAMETER := 76.0
## How long the bright green takes to fill from the middle, in seconds.
const REVEAL := 0.5
## Rarest first, clockwise from the top.
const SLICES := ["legendary", "epic", "rare", "common"]

var _seconds := 0
var _level := -2  # -2 = not set yet, -1 = no gift, 0 = common ... 3 = legendary
## How far round the first ten minutes are (0..1).
var _progress := 0.0
## How much of the bright green has filled in from the middle (0..1).
var _reveal := 0.0
## The chances on show, blending from `_from` to `_to` while `_blend` goes 0..1.
var _from := {}
var _to := {}
var _blend := 1.0


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(func(): pivot_offset = size * 0.5)


## Updates the button for a walk this long, with a fanfare when it earns its
## first gift or a rarer one becomes certain.
func set_seconds(seconds: int) -> void:
	_seconds = seconds
	var table := Content.drop_table
	_progress = clampf(float(seconds) / maxf(1.0, float(table.get("min_seconds", 600))), 0.0, 1.0)
	var floor_rarity := GiftRoller.min_rarity(seconds, table)
	var reached := GiftRoller.RARITIES.find(floor_rarity) if floor_rarity != "" else -1
	var odds := GiftRoller.chances(seconds, table)
	if _level == -2:
		# The first look (or coming back to a walk): no fanfare.
		_reveal = 1.0 if reached >= 0 else 0.0
		_from = odds
		_to = odds
	elif reached > _level and _level < 0:
		_first_gift(odds)
	elif reached > _level:
		Motion.pop(self, 0.22, 0.45)
		Audio.play("pop", 1.0 + 0.12 * reached)
		_blend_to(odds)
	else:
		_to = odds
		if _blend >= 1.0:
			_from = odds
	_level = reached
	tooltip_text = _tip(floor_rarity)
	queue_redraw()


func level() -> int:
	return _level


## The chances the pie shows right now.
func shown() -> Dictionary:
	var out := {}
	for r in GiftRoller.RARITIES:
		out[r] = lerpf(float(_from.get(r, 0.0)), float(_to.get(r, 0.0)), _blend)
	return out


## Ten minutes: a ding and a pop, the bright green fills from the middle,
## then the rarer slices grow in.
func _first_gift(odds: Dictionary) -> void:
	Audio.play("ding", 1.0, -2.0)
	Motion.pop(self, 0.25, 0.45)
	_from = {"common": 1.0}
	_to = {"common": 1.0}
	_reveal = 0.0
	var t := Motion.method(self, "reveal", _set_reveal, 0.0, 1.0, REVEAL)
	t.tween_callback(_blend_to.bind(odds))


func _blend_to(odds: Dictionary) -> void:
	_from = shown()
	_to = odds
	_blend = 0.0
	Motion.method(self, "blend", _set_blend, 0.0, 1.0, Motion.NORMAL)


func _set_reveal(v: float) -> void:
	_reveal = v
	queue_redraw()


func _set_blend(v: float) -> void:
	_blend = v
	queue_redraw()


func _tip(floor_rarity: String) -> String:
	if floor_rarity == "":
		return "Finish walk (no gift yet)"
	var parts: Array[String] = []
	var pct := GiftRoller.percentages_for(_seconds, Content.drop_table)
	for r in GiftRoller.RARITIES:
		if int(pct[r]) > 0:
			parts.append("%d%% %s" % [pct[r], Content.rarity_name(r).to_lower()])
	return "Finish walk: at least a %s gift (%s)" % [Content.rarity_name(floor_rarity).to_lower(), ", ".join(parts)]


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var green := Content.rarity_colour("common")
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.18), true, -1.0, true)
	draw_circle(c, r, UI.NEUTRAL, true, -1.0, true)
	if _reveal < 1.0:
		# The first ten minutes sweeping round, then the green filling in.
		_slice(c, r, -PI * 0.5, TAU * _progress, green.darkened(0.4))
		if _reveal > 0.0:
			draw_circle(c, r * _reveal, green, true, -1.0, true)
	else:
		var at := -PI * 0.5
		var shares := shown()
		for rarity in SLICES:
			var sweep := TAU * float(shares.get(rarity, 0.0))
			if sweep > 0.002:
				_slice(c, r, at, sweep, Content.rarity_colour(rarity))
				at += sweep
		# Thin lines between the slices so neighbours read apart.
		at = -PI * 0.5
		for rarity in SLICES:
			var share := float(shares.get(rarity, 0.0))
			if share > 0.002 and share < 0.998:
				draw_line(c, c + Vector2(cos(at), sin(at)) * r, Color(1, 1, 1, 0.45), 1.5, true)
			at += TAU * share
	draw_arc(c, r - 1.5, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	if is_hovered() or has_focus():
		draw_circle(c, r, Color(1, 1, 1, 0.08), true, -1.0, true)


## A slice of the pie from `from` (radians, clockwise) round `sweep`.
func _slice(c: Vector2, r: float, from: float, sweep: float, colour: Color) -> void:
	if sweep >= TAU - 0.001:
		draw_circle(c, r, colour, true, -1.0, true)
		return
	if sweep <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var steps := maxi(2, ceili(sweep / TAU * 64.0))
	for i in steps + 1:
		var a := from + sweep * i / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, colour)
