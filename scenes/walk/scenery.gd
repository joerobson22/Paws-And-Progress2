class_name Scenery
extends Control
## Endless parallax scenery for one place, drawn from data/biomes.json.
## Each layer is cut into chunks a few hundred pixels wide. A chunk is drawn
## once when it scrolls into view and freed once it has scrolled off, so a
## long walk costs little more than moving a handful of nodes each frame;
## only the few animated layers (water, reeds, fronds) redraw as they move.
## Weather (snow, wind, stars, fireflies) is a thin layer on top. Real art
## will replace each layer's drawer with sprite chunks; the data stays.

const CHUNK := 384.0
## Layers that move with the time and so redraw every frame.
const ANIMATED := ["water", "reeds", "fronds"]

## Ground-layer pixels walked so far; every layer scrolls by this × its parallax.
var scroll: float = 0.0
var biome: Dictionary = {}
var period: String = "day":
	set(v):
		if v != period:
			period = v
			_redraw_all()

var _time: float = 0.0
## One entry per layer: {data, node, chunks: {index: _Chunk}, animated}.
var _layers: Array = []
var _sky: _Sky
var _fx: _Fx


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sky = _Sky.new()
	_sky.scenery = self
	add_child(_sky)
	for layer in biome.get("layers", []):
		if layer["kind"] == "planet":
			continue  # drawn with the sky
		var node := Node2D.new()
		add_child(node)
		_layers.append({"data": layer, "node": node, "chunks": {}, "animated": ANIMATED.has(str(layer["kind"]))})
	_fx = _Fx.new()
	_fx.scenery = self
	add_child(_fx)
	resized.connect(_rebuild)


func _process(delta: float) -> void:
	_time += delta
	_place_chunks()
	_fx.queue_redraw()


## Screen y of the walking path (where feet go).
func path_y() -> float:
	var g := ground_layer()
	if not g.is_empty():
		return size.y * (float(g["y"]) + float(g["height"]) * 0.32)
	return size.y * 0.8


func ground_layer() -> Dictionary:
	for layer in biome.get("layers", []):
		if layer["kind"] == "ground":
			return layer
	return {}


## The water band on screen (top y, bottom y), or an empty Vector2 if there's none.
func water_band() -> Vector2:
	for layer in biome.get("layers", []):
		if layer["kind"] == "water":
			return Vector2(float(layer["y"]), float(layer["y"]) + float(layer["height"])) * size.y
	return Vector2.ZERO


func water_colour() -> Color:
	for layer in biome.get("layers", []):
		if layer["kind"] == "water":
			return Color.from_string(layer["colour"], Color.SKY_BLUE) * tint()
	return Color.SKY_BLUE


## How the time of day colours everything (white for places with their own light).
func tint() -> Color:
	if biome.get("fixed_light", false):
		return Color.WHITE
	var tod: Dictionary = Content.times_of_day.get(period, {})
	return Color.from_string(tod.get("tint", "#ffffff"), Color.WHITE)


func is_dark() -> bool:
	return period == "night" or biome.has("sky")


func time() -> float:
	return _time


## The looping sound for this place now: daytime birds and lapping water give
## way to the night chorus after dark; wind and silence (the Moon) stay put.
func ambience() -> String:
	var own := str(biome.get("ambience", "day"))
	if period == "night" and own in ["lake", "day"]:
		return "night"
	return own


## Makes chunks that have scrolled into view, frees ones that have left, and
## moves the rest. Positions are worked out in full precision here, so hours
## of walking never make the scenery jitter.
func _place_chunks() -> void:
	for layer in _layers:
		var offset := scroll * float(layer["data"]["parallax"])
		var first := floori(offset / CHUNK) - 1
		var last := floori((offset + size.x) / CHUNK) + 1
		var chunks: Dictionary = layer["chunks"]
		for i in chunks.keys():
			if i < first or i > last:
				chunks[i].queue_free()
				chunks.erase(i)
		for i in range(first, last + 1):
			var chunk: _Chunk = chunks.get(i)
			if chunk == null:
				chunk = _Chunk.new()
				chunk.scenery = self
				chunk.layer = layer["data"]
				chunk.index = i
				layer["node"].add_child(chunk)
				chunks[i] = chunk
			chunk.position.x = i * CHUNK - offset
			if layer["animated"]:
				chunk.queue_redraw()


func _rebuild() -> void:
	for layer in _layers:
		for chunk in layer["chunks"].values():
			chunk.queue_free()
		layer["chunks"].clear()
	_sky.queue_redraw()
	_place_chunks()


func _redraw_all() -> void:
	if _sky:
		_sky.queue_redraw()
	for layer in _layers:
		for chunk in layer["chunks"].values():
			chunk.queue_redraw()
	if _fx:
		_fx.queue_redraw()


static func _noise(t: float, sd: float) -> float:
	return 0.55 * sin(t * TAU + sd) + 0.3 * sin(t * TAU * 2.3 + sd * 1.7) + 0.15 * sin(t * TAU * 5.1 + sd * 2.9)


## Stable pseudo-random 0..1 for an integer slot.
static func _hash(i: int, sd: float) -> float:
	return fposmod(sin(i * 12.9898 + sd * 78.233) * 43758.5453, 1.0)


## One stretch of one layer, drawn in its own space: x runs 0..CHUNK across it.
class _Chunk extends Node2D:
	var scenery: Scenery
	var layer: Dictionary
	var index: int

	func _draw() -> void:
		var size := scenery.size
		var colour := Color.from_string(layer["colour"], Color.WHITE) * scenery.tint()
		var y := size.y * float(layer["y"])
		var h := size.y * float(layer["height"])
		var sd := float(layer.get("seed", 0))
		var spacing := float(layer.get("spacing", 70))
		var snow := bool(layer.get("snow", false))
		# World x where this chunk starts, in the layer's own scrolling space.
		var x0 := index * CHUNK
		match str(layer["kind"]):
			"hills":
				_hills(x0, y, h, float(layer.get("wavelength", 400)), sd, colour, size)
			"water":
				_water(x0, y, h, sd, colour)
			"ground":
				_ground(x0, y, h, sd, colour, size)
			"reeds":
				_slots(x0, spacing, sd, 0.35, func(x, r, _i): _reed_tuft(x, y, h * r, colour, r, size))
			"fronds":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _frond(x, y, h * (0.6 + 0.6 * r), colour, r, size))
			"trees":
				_slots(x0, spacing, sd, 0.25, func(x, r, i): _tree(x, y, h * (0.6 + 0.6 * r), colour.darkened(0.1 * Scenery._hash(i + 3, sd))))
			"pines":
				_slots(x0, spacing, sd, 0.2, func(x, r, i): _pine(x, y, h * (0.55 + 0.6 * r), colour.darkened(0.12 * Scenery._hash(i + 3, sd)), snow))
			"broadleaf":
				_slots(x0, spacing, sd, 0.3, func(x, r, i): _broadleaf(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.12 * Scenery._hash(i + 5, sd))))
			"canopy":
				_slots(x0, spacing, sd, 0.0, func(x, r, i): _canopy(x, y, h * (0.75 + 0.35 * r), colour, i, sd))
			"palms":
				_slots(x0, spacing, sd, 0.35, func(x, r, i): _palm(x, y, h * (0.7 + 0.4 * r), colour, r))
			"mountains":
				_slots(x0, spacing, sd, 0.0, func(x, r, i): _mountain(x, y, h * (0.6 + 0.5 * r), spacing * (0.9 + 0.6 * Scenery._hash(i + 9, sd)), colour.darkened(0.08 * Scenery._hash(i + 2, sd)), snow))
			"mesas":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _mesa(x, y, h * (0.6 + 0.5 * r), spacing * (0.35 + 0.3 * r), colour))
			"cacti":
				_slots(x0, spacing, sd, 0.35, func(x, r, _i): _cactus(x, y, h * (0.55 + 0.5 * r), colour, r))
			"drifts":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _drift(x, size.y, h * (0.5 + r), colour))

	## Calls `item(x, r, i)` for each slot starting in this chunk, skipping
	## a share `skip` of them; `r` is the slot's random 0..1. An item belongs
	## to the chunk its slot starts in, so none is drawn twice.
	func _slots(x0: float, spacing: float, sd: float, skip: float, item: Callable) -> void:
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var slot_x := i * spacing
			if slot_x < x0 or slot_x >= x0 + CHUNK:
				continue
			var r := Scenery._hash(i, sd)
			if r < skip:
				continue
			item.call(slot_x - x0 + spacing * 0.5 * Scenery._hash(i + 7, sd), r, i)

	func _hills(x0: float, y: float, h: float, wavelength: float, sd: float, colour: Color, size: Vector2) -> void:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= CHUNK + 0.5:
			pts.append(Vector2(x, y - h * (0.5 + 0.5 * Scenery._noise((x0 + x) / wavelength, sd))))
			x += 16.0
		# Overlap the neighbours by a pixel so no seam shows between chunks.
		pts[0] = Vector2(-1.0, pts[0].y)
		pts[pts.size() - 1] = Vector2(CHUNK + 1.0, pts[pts.size() - 1].y)
		pts.append(Vector2(CHUNK + 1.0, size.y))
		pts.append(Vector2(-1.0, size.y))
		draw_colored_polygon(pts, colour)

	func _water(x0: float, y: float, h: float, sd: float, colour: Color) -> void:
		draw_rect(Rect2(-1.0, y, CHUNK + 2.0, h), colour)
		var shimmer := Color(1, 1, 1, 0.35) * scenery.tint()
		var spacing := 38.0
		var t := scenery.time()
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var r := Scenery._hash(i, sd)
			var x := i * spacing - x0
			var ly := y + h * (0.15 + 0.7 * r)
			var a := 0.5 + 0.5 * sin(t * 1.5 + r * TAU)
			draw_line(Vector2(x, ly), Vector2(x + 10 + 14 * r, ly), Color(shimmer, shimmer.a * a), 2.0)
		if layer.get("foam", false):
			# Surf rolling up the sand, in and out.
			var pts := PackedVector2Array()
			var x := 0.0
			var reach := sin(t * 0.8) * 4.0
			while x <= CHUNK + 0.5:
				pts.append(Vector2(x, y + h - 3.0 + reach + 3.0 * Scenery._noise((x0 + x) / 90.0, sd + t * 0.05)))
				x += 12.0
			draw_polyline(pts, Color(1, 1, 1, 0.8) * scenery.tint(), 4.0, true)

	func _ground(x0: float, y: float, h: float, sd: float, colour: Color, size: Vector2) -> void:
		# A bank with a gently uneven top edge, then the path.
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= CHUNK + 0.5:
			pts.append(Vector2(x, y - 6.0 * Scenery._noise((x0 + x) / 220.0, sd)))
			x += 16.0
		pts[0] = Vector2(-1.0, pts[0].y)
		pts[pts.size() - 1] = Vector2(CHUNK + 1.0, pts[pts.size() - 1].y)
		pts.append(Vector2(CHUNK + 1.0, size.y))
		pts.append(Vector2(-1.0, size.y))
		draw_colored_polygon(pts, colour)
		var py := scenery.path_y()
		var path_colour := Color.from_string(layer.get("path", "#d9c49a"), Color.TAN) * scenery.tint()
		draw_rect(Rect2(-1.0, py - h * 0.1, CHUNK + 2.0, h * 0.2), path_colour)
		if layer.get("craters", false):
			for i in range(floori(x0 / 140.0), floori((x0 + CHUNK) / 140.0) + 1):
				var r := Scenery._hash(i, sd + 3.0)
				var c := Vector2(i * 140.0 - x0 + 60.0 * r, y + h * (0.12 + 0.75 * Scenery._hash(i, sd + 8.0)))
				if absf(c.y - py) < h * 0.12:
					continue
				draw_set_transform(c, 0.0, Vector2(1.0, 0.35))
				draw_circle(Vector2.ZERO, 10.0 + 22.0 * r, colour.darkened(0.12), true, -1.0, true)
				draw_circle(Vector2(0, 3), 8.0 + 18.0 * r, colour.darkened(0.2), true, -1.0, true)
				draw_set_transform(Vector2.ZERO)
		# Pebbles on the path so movement reads even with flat placeholder art.
		var spacing := 54.0
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var r := Scenery._hash(i, sd + 11.0)
			draw_circle(Vector2(i * spacing - x0 + 20.0 * r, py - h * 0.08 + h * 0.16 * Scenery._hash(i, sd + 5.0)), 2.0 + 3.0 * r, path_colour.darkened(0.15))

	func _reed_tuft(x: float, top: float, h: float, colour: Color, r: float, size: Vector2) -> void:
		var sway := sin(scenery.time() * 1.2 + r * 6.0) * 6.0
		for k in 3:
			var bx := x + k * 6.0
			draw_line(Vector2(bx, size.y), Vector2(bx + sway + (k - 1) * 5.0, top - h), colour.darkened(0.1 * k), 3.0, true)

	## A broad leaf on a stem, bending in the breeze (forest and jungle floor).
	func _frond(x: float, base: float, h: float, colour: Color, r: float, size: Vector2) -> void:
		var sway := sin(scenery.time() * 1.1 + r * 5.0) * 0.12
		for k in 3:
			var angle := -PI * 0.5 + (k - 1) * 0.55 + sway
			var tip := Vector2(x, size.y) + Vector2(cos(angle), sin(angle)) * h
			var mid := Vector2(x, size.y).lerp(tip, 0.55)
			var side := Vector2(-sin(angle), cos(angle)) * h * 0.16
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), mid + side, tip, mid - side]), colour.darkened(0.08 * k))

	func _tree(x: float, y: float, th: float, colour: Color) -> void:
		var w := th * 0.38
		draw_rect(Rect2(x - w * 0.07, y - th * 0.25, w * 0.14, th * 0.3), colour.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, y - th * 0.2), Vector2(x, y - th), Vector2(x + w * 0.5, y - th * 0.2)]), colour)

	## A tall, layered conifer, with snow on its tiers in the tundra.
	func _pine(x: float, y: float, th: float, colour: Color, snow: bool) -> void:
		var w := th * 0.42
		draw_rect(Rect2(x - w * 0.06, y - th * 0.18, w * 0.12, th * 0.2), colour.darkened(0.4))
		for k in 3:
			var top := y - th * (0.45 + 0.27 * k) - th * 0.1
			var bottom := y - th * (0.12 + 0.24 * k)
			var half := w * (0.5 - 0.12 * k)
			draw_colored_polygon(PackedVector2Array([Vector2(x - half, bottom), Vector2(x, top), Vector2(x + half, bottom)]), colour)
			if snow:
				var s := Color(0.95, 0.97, 1.0) * scenery.tint()
				draw_colored_polygon(PackedVector2Array([Vector2(x - half * 0.45, top + (bottom - top) * 0.45), Vector2(x, top), Vector2(x + half * 0.45, top + (bottom - top) * 0.45)]), s)

	## A round-topped deciduous tree.
	func _broadleaf(x: float, y: float, th: float, colour: Color) -> void:
		draw_rect(Rect2(x - th * 0.04, y - th * 0.45, th * 0.08, th * 0.45), colour.darkened(0.45))
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			draw_circle(Vector2(x, y - th * 0.7) + Vector2(cos(a), sin(a) * 0.6) * th * 0.13, th * 0.22, colour.darkened(0.06 * k), true, -1.0, true)
		draw_circle(Vector2(x, y - th * 0.82), th * 0.2, colour.lightened(0.05), true, -1.0, true)

	## Dense jungle: big overlapping leaf clusters with vines hanging down.
	func _canopy(x: float, y: float, th: float, colour: Color, i: int, sd: float) -> void:
		draw_rect(Rect2(x - th * 0.035, y - th * 0.6, th * 0.07, th * 0.6), colour.darkened(0.5))
		for k in 5:
			var a := TAU * k / 5.0 + Scenery._hash(i, sd + 4.0) * 3.0
			var c := Vector2(x, y - th * 0.78) + Vector2(cos(a) * th * 0.22, sin(a) * th * 0.1)
			draw_circle(c, th * (0.16 + 0.05 * Scenery._hash(i + k, sd)), colour.darkened(0.07 * (k % 3)), true, -1.0, true)
		for k in 2:
			var vx := x + (k - 0.5) * th * 0.3
			draw_line(Vector2(vx, y - th * 0.72), Vector2(vx + 4.0, y - th * (0.3 + 0.15 * k)), colour.lightened(0.15), 2.0, true)

	func _palm(x: float, y: float, th: float, colour: Color, r: float) -> void:
		var lean := (r - 0.5) * th * 0.25
		var top := Vector2(x + lean, y - th)
		var trunk := PackedVector2Array()
		for k in 9:
			var t := k / 8.0
			trunk.append(Vector2(x, y).lerp(top, t) + Vector2(sin(t * PI) * th * 0.05, 0))
		draw_polyline(trunk, Color("#8a6a45") * scenery.tint(), maxf(3.0, th * 0.05), true)
		for k in 7:
			var angle := -PI + PI * k / 6.0 + 0.15 * sin(scenery.time() * 0.6 + r * 4.0)
			# Each frond arcs up then droops at the tip.
			var dir := Vector2(cos(angle), sin(angle) * 0.45 + 0.3)
			var tip := top + dir * th * 0.36 + Vector2(0, th * 0.08)
			var mid := top + dir * th * 0.2 + Vector2(0, -th * 0.05)
			# A thick curved stroke rather than a filled shape: at some angles
			# a four-point leaf folds over itself and can't be filled.
			var shade := colour.darkened(0.08 * (k % 2))
			draw_polyline(PackedVector2Array([top, mid, tip]), shade, th * 0.075, true)
			draw_polyline(PackedVector2Array([top.lerp(mid, 0.5), mid, mid.lerp(tip, 0.6)]), shade, th * 0.11, true)
		draw_circle(top, th * 0.035, Color("#6b4f33") * scenery.tint(), true, -1.0, true)

	func _mountain(x: float, y: float, th: float, w: float, colour: Color, snow: bool) -> void:
		var peak := Vector2(x, y - th)
		draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.6, y + 2.0), peak, Vector2(x + w * 0.6, y + 2.0)]), colour)
		draw_colored_polygon(PackedVector2Array([peak, Vector2(x + w * 0.6, y + 2.0), Vector2(x + w * 0.12, y + 2.0)]), colour.darkened(0.1))
		if snow:
			var s := Color(0.96, 0.98, 1.0) * scenery.tint()
			var k := 0.3
			# A jagged lower edge, with every point inside the slopes so the
			# outline never crosses itself.
			draw_colored_polygon(PackedVector2Array([
				peak, peak + Vector2(w * 0.6 * k, th * k), peak + Vector2(w * 0.1, th * k * 0.8),
				peak + Vector2(0, th * k), peak + Vector2(-w * 0.08, th * k * 0.78), peak + Vector2(-w * 0.6 * k, th * k)]), s)

	## A flat-topped desert rock.
	func _mesa(x: float, y: float, th: float, w: float, colour: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.7, y + 2.0), Vector2(x - w * 0.45, y - th), Vector2(x + w * 0.45, y - th), Vector2(x + w * 0.7, y + 2.0)]), colour)
		draw_rect(Rect2(x - w * 0.45, y - th, w * 0.9, th * 0.12), colour.lightened(0.12))
		draw_rect(Rect2(x - w * 0.6, y - th * 0.45, w * 1.2, th * 0.06), colour.darkened(0.12))

	func _cactus(x: float, y: float, th: float, colour: Color, r: float) -> void:
		var w := th * 0.16
		var body := UI.box(colour, Color.TRANSPARENT, int(w * 0.5))
		draw_style_box(body, Rect2(x - w * 0.5, y - th, w, th))
		var arm_y := y - th * (0.45 + 0.2 * r)
		draw_style_box(body, Rect2(x - w * 1.5, arm_y - th * 0.3, w * 0.7, th * 0.32))
		draw_rect(Rect2(x - w * 1.5, arm_y - w * 0.35, w * 1.2, w * 0.6), colour)
		draw_style_box(body, Rect2(x + w * 0.8, arm_y - th * 0.15, w * 0.7, th * 0.25))
		draw_rect(Rect2(x + w * 0.3, arm_y + th * 0.02, w * 1.2, w * 0.6), colour)

	## A low mound along the bottom edge (snow drifts, moon dust).
	func _drift(x: float, bottom: float, h: float, colour: Color) -> void:
		draw_set_transform(Vector2(x, bottom), 0.0, Vector2(1.0, h / 40.0))
		draw_circle(Vector2.ZERO, 40.0, colour, true, -1.0, true)
		draw_circle(Vector2(34, 8), 30.0, colour, true, -1.0, true)
		draw_set_transform(Vector2.ZERO)



## The sky gradient behind everything: redrawn only when the size or time of
## day changes. A place with its own sky (the Moon) ignores the time of day.
class _Sky extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var size := scenery.size
		var sky: Dictionary = scenery.biome.get("sky", {})
		var tod: Dictionary = Content.times_of_day.get(scenery.period, {})
		var top := Color.from_string(sky.get("top", tod.get("sky_top", "#8ec3e6")), Color.SKY_BLUE)
		var bottom := Color.from_string(sky.get("bottom", tod.get("sky_bottom", "#d7ecf6")), Color.WHITE)
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
		for layer in scenery.biome.get("layers", []):
			if layer["kind"] == "planet":
				_planet(Vector2(size.x * 0.72, size.y * float(layer["y"])), size.y * float(layer["height"]), Color.from_string(layer["colour"], Color.ROYAL_BLUE))

	## A big blue planet hanging still in the sky (the Earth, seen from the Moon).
	func _planet(c: Vector2, r: float, colour: Color) -> void:
		draw_circle(c, r * 1.25, Color(colour, 0.12), true, -1.0, true)
		draw_circle(c, r, colour, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.35, Color("#5fa65a"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.35, r * 0.3), r * 0.28, Color("#5fa65a"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.1, -r * 0.55), r * 0.25, Color(1, 1, 1, 0.75), true, -1.0, true)
		draw_arc(c, r * 0.8, PI * 0.1, PI * 0.9, 16, Color(0, 0, 0, 0.18), r * 0.45, true)


## Weather on top of the scenery: stars after dark, fireflies in the evening,
## snow and gusts of wind in the tundra. A few dozen dots and lines a frame.
class _Fx extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var fx: Array = scenery.biome.get("fx", [])
		var size := scenery.size
		var t := scenery.time()
		var p := scenery.period
		if fx.has("stars") and scenery.is_dark():
			for i in 70:
				var at := Vector2(Scenery._hash(i, 1.0) * size.x, Scenery._hash(i, 2.0) * size.y * 0.45)
				var twinkle := 0.5 + 0.5 * sin(t * 2.0 + i)
				draw_circle(at, 1.0 + Scenery._hash(i, 3.0) * 1.2, Color(1, 1, 0.9, 0.4 + 0.5 * twinkle))
		if fx.has("fireflies") and (p == "night" or p == "evening"):
			for i in 18:
				var base := Vector2(Scenery._hash(i, 4.0) * size.x, size.y * (0.6 + 0.3 * Scenery._hash(i, 5.0)))
				var drift := Vector2(sin(t * 0.6 + i) * 18.0, cos(t * 0.8 + i * 1.3) * 12.0)
				var glow := 0.4 + 0.6 * absf(sin(t * 1.3 + i * 2.1))
				draw_circle(base + drift, 6.0, Color(1.0, 0.92, 0.5, 0.15 * glow))
				draw_circle(base + drift, 2.2, Color(1.0, 0.95, 0.6, glow))
		var gust := 0.6 + 0.4 * sin(t * 0.45)
		if fx.has("snow"):
			# Flakes fall and are blown sideways, harder in the gusts.
			for i in 90:
				var speed := 30.0 + 50.0 * Scenery._hash(i, 6.0)
				var fall := fposmod(Scenery._hash(i, 7.0) * size.y + t * speed, size.y + 20.0) - 10.0
				var blown := fposmod(Scenery._hash(i, 8.0) * size.x - t * (60.0 + 90.0 * gust) - fall * 0.4, size.x + 20.0) - 10.0
				draw_circle(Vector2(blown, fall), 1.2 + 2.0 * Scenery._hash(i, 9.0), Color(1, 1, 1, 0.85))
		if fx.has("wind"):
			for i in 10:
				var speed := 380.0 + 260.0 * Scenery._hash(i, 10.0)
				var x := size.x - fposmod(Scenery._hash(i, 11.0) * size.x * 2.0 + t * speed, size.x * 2.0)
				var y := size.y * (0.15 + 0.7 * Scenery._hash(i, 12.0)) + sin(t * 2.0 + i) * 6.0
				var length := 60.0 + 90.0 * Scenery._hash(i, 13.0)
				draw_line(Vector2(x, y), Vector2(x + length, y - 4.0), Color(1, 1, 1, 0.25 * gust), 1.5, true)
