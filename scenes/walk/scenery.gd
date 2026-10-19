class_name Scenery
extends Control
## Endless parallax scenery for one biome, drawn from data/biomes.json.
## Each layer is generated from deterministic noise of its world position, so
## the walk never repeats or ends and needs no chunk bookkeeping. Real art
## replaces each layer's drawer with sprite chunks later; the data stays.

## Ground-layer pixels walked so far; every layer scrolls by this × its parallax.
var scroll: float = 0.0
var biome: Dictionary = {}
var period: String = "day"
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Screen y of the walking path (where feet go).
func path_y() -> float:
	for layer in biome.get("layers", []):
		if layer["kind"] == "ground":
			return size.y * (float(layer["y"]) + float(layer["height"]) * 0.32)
	return size.y * 0.8


func _tint() -> Color:
	var tod: Dictionary = Content.times_of_day.get(period, {})
	return Color.from_string(tod.get("tint", "#ffffff"), Color.WHITE)


func _draw() -> void:
	var tod: Dictionary = Content.times_of_day.get(period, {})
	var top := Color.from_string(tod.get("sky_top", "#8ec3e6"), Color.SKY_BLUE)
	var bottom := Color.from_string(tod.get("sky_bottom", "#d7ecf6"), Color.WHITE)
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	if period == "night":
		_draw_stars()

	var tint := _tint()
	for layer in biome.get("layers", []):
		var colour := Color.from_string(layer["colour"], Color.WHITE) * tint
		var offset := scroll * float(layer["parallax"])
		var y := size.y * float(layer["y"])
		var h := size.y * float(layer["height"])
		var sd := float(layer.get("seed", 0))
		match str(layer["kind"]):
			"hills":
				_draw_hills(offset, y, h, float(layer.get("wavelength", 400)), sd, colour)
			"trees":
				_draw_trees(offset, y, h, float(layer.get("spacing", 70)), sd, colour)
			"water":
				_draw_water(offset, y, h, sd, colour)
			"ground":
				_draw_ground(offset, y, h, sd, colour)
			"reeds":
				_draw_reeds(offset, y, h, float(layer.get("spacing", 40)), sd, colour)

	if period == "night" or period == "evening":
		_draw_fireflies()


static func _noise(t: float, sd: float) -> float:
	return 0.55 * sin(t * TAU + sd) + 0.3 * sin(t * TAU * 2.3 + sd * 1.7) + 0.15 * sin(t * TAU * 5.1 + sd * 2.9)


## Stable pseudo-random 0..1 for an integer slot.
static func _hash(i: int, sd: float) -> float:
	return fposmod(sin(i * 12.9898 + sd * 78.233) * 43758.5453, 1.0)


func _draw_hills(offset: float, y: float, h: float, wavelength: float, sd: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= size.x + 16.0:
		pts.append(Vector2(x, y - h * (0.5 + 0.5 * _noise((x + offset) / wavelength, sd))))
		x += 16.0
	pts.append(Vector2(size.x + 16.0, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, colour)


func _draw_trees(offset: float, y: float, h: float, spacing: float, sd: float, colour: Color) -> void:
	var first := floori(offset / spacing) - 1
	var last := first + ceili(size.x / spacing) + 2
	for i in range(first, last + 1):
		var r := _hash(i, sd)
		if r < 0.25:
			continue
		var x := i * spacing - offset + spacing * 0.5 * _hash(i + 7, sd)
		var th := h * (0.6 + 0.6 * r)
		var w := th * 0.38
		draw_rect(Rect2(x - w * 0.07, y - th * 0.25, w * 0.14, th * 0.3), colour.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, y - th * 0.2), Vector2(x, y - th), Vector2(x + w * 0.5, y - th * 0.2)]),
			colour.darkened(0.1 * _hash(i + 3, sd)))


func _draw_water(offset: float, y: float, h: float, sd: float, colour: Color) -> void:
	draw_rect(Rect2(0, y, size.x, h), colour)
	var shimmer := Color(1, 1, 1, 0.35) * _tint()
	var spacing := 38.0
	var first := floori(offset / spacing) - 1
	for i in range(first, first + ceili(size.x / spacing) + 3):
		var r := _hash(i, sd)
		var x := i * spacing - offset
		var ly := y + h * (0.15 + 0.7 * r)
		var a := 0.5 + 0.5 * sin(_time * 1.5 + r * TAU)
		draw_line(Vector2(x, ly), Vector2(x + 10 + 14 * r, ly), Color(shimmer, shimmer.a * a), 2.0)


func _draw_ground(offset: float, y: float, h: float, sd: float, colour: Color) -> void:
	# Grassy bank with a gently uneven top edge, then the path.
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= size.x + 16.0:
		pts.append(Vector2(x, y - 6.0 * _noise((x + offset) / 220.0, sd)))
		x += 16.0
	pts.append(Vector2(size.x + 16.0, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, colour)
	var py := path_y()
	var path_colour := Color("#d9c49a") * _tint()
	draw_rect(Rect2(0, py - h * 0.1, size.x, h * 0.2), path_colour)
	# Pebbles on the path so movement reads even with flat placeholder art.
	var spacing := 54.0
	var first := floori(offset / spacing) - 1
	for i in range(first, first + ceili(size.x / spacing) + 3):
		var r := _hash(i, sd + 11.0)
		draw_circle(Vector2(i * spacing - offset + 20.0 * r, py - h * 0.08 + h * 0.16 * _hash(i, sd + 5.0)), 2.0 + 3.0 * r, path_colour.darkened(0.15))


func _draw_reeds(offset: float, y: float, h: float, spacing: float, sd: float, colour: Color) -> void:
	var first := floori(offset / spacing) - 1
	for i in range(first, first + ceili(size.x / spacing) + 3):
		var r := _hash(i, sd)
		if r < 0.35:
			continue
		var x := i * spacing - offset
		var sway := sin(_time * 1.2 + r * 6.0) * 6.0
		for k in 3:
			var bx := x + k * 6.0
			draw_line(Vector2(bx, size.y), Vector2(bx + sway + (k - 1) * 5.0, y - h * r), colour.darkened(0.1 * k), 3.0, true)


func _draw_stars() -> void:
	for i in 70:
		var p := Vector2(_hash(i, 1.0) * size.x, _hash(i, 2.0) * size.y * 0.45)
		var twinkle := 0.5 + 0.5 * sin(_time * 2.0 + i)
		draw_circle(p, 1.0 + _hash(i, 3.0) * 1.2, Color(1, 1, 0.9, 0.4 + 0.5 * twinkle))


func _draw_fireflies() -> void:
	for i in 18:
		var base := Vector2(_hash(i, 4.0) * size.x, size.y * (0.6 + 0.3 * _hash(i, 5.0)))
		var drift := Vector2(sin(_time * 0.6 + i) * 18.0, cos(_time * 0.8 + i * 1.3) * 12.0)
		var glow := 0.4 + 0.6 * absf(sin(_time * 1.3 + i * 2.1))
		draw_circle(base + drift, 6.0, Color(1.0, 0.92, 0.5, 0.15 * glow))
		draw_circle(base + drift, 2.2, Color(1.0, 0.95, 0.6, glow))
