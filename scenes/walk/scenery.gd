class_name Scenery
extends Control
## Endless parallax scenery for one biome, drawn from data/biomes.json.
## Each layer is cut into chunks a few hundred pixels wide. A chunk is drawn
## once when it scrolls into view and freed once it has scrolled off, so a
## long walk costs little more than moving a handful of nodes each frame;
## only the few animated layers (water, reeds) redraw as they move. Real art
## will replace each layer's drawer with sprite chunks; the data stays.

const CHUNK := 384.0

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
		var node := Node2D.new()
		add_child(node)
		var kind := str(layer["kind"])
		_layers.append({"data": layer, "node": node, "chunks": {}, "animated": kind == "water" or kind == "reeds"})
	_fx = _Fx.new()
	_fx.scenery = self
	add_child(_fx)
	resized.connect(_rebuild)


func _process(delta: float) -> void:
	_time += delta
	_place_chunks()
	if period == "night" or period == "evening":
		_fx.queue_redraw()


## Screen y of the walking path (where feet go).
func path_y() -> float:
	for layer in biome.get("layers", []):
		if layer["kind"] == "ground":
			return size.y * (float(layer["y"]) + float(layer["height"]) * 0.32)
	return size.y * 0.8


func tint() -> Color:
	var tod: Dictionary = Content.times_of_day.get(period, {})
	return Color.from_string(tod.get("tint", "#ffffff"), Color.WHITE)


func time() -> float:
	return _time


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
		# World x where this chunk starts, in the layer's own scrolling space.
		var x0 := index * CHUNK
		match str(layer["kind"]):
			"hills":
				_hills(x0, y, h, float(layer.get("wavelength", 400)), sd, colour, size)
			"trees":
				_trees(x0, y, h, float(layer.get("spacing", 70)), sd, colour)
			"water":
				_water(x0, y, h, sd, colour)
			"ground":
				_ground(x0, y, h, sd, colour, size)
			"reeds":
				_reeds(x0, y, h, float(layer.get("spacing", 40)), sd, colour, size)

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

	func _trees(x0: float, y: float, h: float, spacing: float, sd: float, colour: Color) -> void:
		var first := floori(x0 / spacing)
		var last := floori((x0 + CHUNK) / spacing)
		for i in range(first, last + 1):
			var r := Scenery._hash(i, sd)
			if r < 0.25:
				continue
			# A tree belongs to the chunk its slot starts in, so none is drawn twice.
			var slot_x := i * spacing
			if slot_x < x0 or slot_x >= x0 + CHUNK:
				continue
			var x := slot_x - x0 + spacing * 0.5 * Scenery._hash(i + 7, sd)
			var th := h * (0.6 + 0.6 * r)
			var w := th * 0.38
			draw_rect(Rect2(x - w * 0.07, y - th * 0.25, w * 0.14, th * 0.3), colour.darkened(0.35))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - w * 0.5, y - th * 0.2), Vector2(x, y - th), Vector2(x + w * 0.5, y - th * 0.2)]),
				colour.darkened(0.1 * Scenery._hash(i + 3, sd)))

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

	func _ground(x0: float, y: float, h: float, sd: float, colour: Color, size: Vector2) -> void:
		# Grassy bank with a gently uneven top edge, then the path.
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
		var path_colour := Color("#d9c49a") * scenery.tint()
		draw_rect(Rect2(-1.0, py - h * 0.1, CHUNK + 2.0, h * 0.2), path_colour)
		# Pebbles on the path so movement reads even with flat placeholder art.
		var spacing := 54.0
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var r := Scenery._hash(i, sd + 11.0)
			draw_circle(Vector2(i * spacing - x0 + 20.0 * r, py - h * 0.08 + h * 0.16 * Scenery._hash(i, sd + 5.0)), 2.0 + 3.0 * r, path_colour.darkened(0.15))

	func _reeds(x0: float, y: float, h: float, spacing: float, sd: float, colour: Color, size: Vector2) -> void:
		var t := scenery.time()
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var r := Scenery._hash(i, sd)
			if r < 0.35:
				continue
			var x := i * spacing - x0
			if x < 0.0 or x >= CHUNK:
				continue
			var sway := sin(t * 1.2 + r * 6.0) * 6.0
			for k in 3:
				var bx := x + k * 6.0
				draw_line(Vector2(bx, size.y), Vector2(bx + sway + (k - 1) * 5.0, y - h * r), colour.darkened(0.1 * k), 3.0, true)


## The sky gradient behind everything (and the stars at night): redrawn only
## when the size or time of day changes.
class _Sky extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var size := scenery.size
		var tod: Dictionary = Content.times_of_day.get(scenery.period, {})
		var top := Color.from_string(tod.get("sky_top", "#8ec3e6"), Color.SKY_BLUE)
		var bottom := Color.from_string(tod.get("sky_bottom", "#d7ecf6"), Color.WHITE)
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))


## Twinkling stars and drifting fireflies after dark: a few dozen dots a frame.
class _Fx extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var p := scenery.period
		if p != "night" and p != "evening":
			return
		var size := scenery.size
		var t := scenery.time()
		if p == "night":
			for i in 70:
				var at := Vector2(Scenery._hash(i, 1.0) * size.x, Scenery._hash(i, 2.0) * size.y * 0.45)
				var twinkle := 0.5 + 0.5 * sin(t * 2.0 + i)
				draw_circle(at, 1.0 + Scenery._hash(i, 3.0) * 1.2, Color(1, 1, 0.9, 0.4 + 0.5 * twinkle))
		for i in 18:
			var base := Vector2(Scenery._hash(i, 4.0) * size.x, size.y * (0.6 + 0.3 * Scenery._hash(i, 5.0)))
			var drift := Vector2(sin(t * 0.6 + i) * 18.0, cos(t * 0.8 + i * 1.3) * 12.0)
			var glow := 0.4 + 0.6 * absf(sin(t * 1.3 + i * 2.1))
			draw_circle(base + drift, 6.0, Color(1.0, 0.92, 0.5, 0.15 * glow))
			draw_circle(base + drift, 2.2, Color(1.0, 0.95, 0.6, glow))
