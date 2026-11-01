@tool
class_name SceneryPainter
extends Node2D
## Draws one stretch (CHUNK wide) of one scenery layer from its settings (a
## layer dictionary, as a place's SceneryLayer gives it): hills, trees,
## water, the ground and path and every other kind. The walk's scenery
## (Scenery) draws its layers with these as they scroll by; in the Godot
## editor a SceneryLayer draws itself with them too, so a place's scene
## shows what it looks like while you change it.
## A painter on its own draws for a screen `view_size`, still (time 0, unless
## set), with the path from `path_line` and the street lights off.

## How wide each stretch is.
const CHUNK := 384.0

var layer: Dictionary
var index: int
## Used when drawn on its own (in the editor); the walk's scenery passes
## its own instead.
var view_size := Vector2(1280, 720)
var clock_time := 0.0
var path_line := -1.0
var lights_on := false
var keep_clear := Vector2.ZERO


func _view() -> Vector2:
	return view_size


func _now() -> float:
	return clock_time


func _path() -> float:
	return path_line if path_line >= 0.0 else _view().y * 0.8


func _lit() -> bool:
	return lights_on


func _gap() -> Vector2:
	return keep_clear


## A rounded box with the app's hand-cut corners (as UI.box draws them),
## kept here so the editor can draw it too.
static func _box(fill: Color, _border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	if radius >= 99 or radius < 8:
		b.set_corner_radius_all(radius)
	else:
		b.corner_radius_top_left = radius
		b.corner_radius_top_right = roundi(radius * 1.35)
		b.corner_radius_bottom_right = roundi(radius * 0.8)
		b.corner_radius_bottom_left = roundi(radius * 1.2)
	return b


static func _noise(t: float, sd: float) -> float:
	return 0.55 * sin(t * TAU + sd) + 0.3 * sin(t * TAU * 2.3 + sd * 1.7) + 0.15 * sin(t * TAU * 5.1 + sd * 2.9)


## Stable pseudo-random 0..1 for an integer slot.
static func _hash(i: int, sd: float) -> float:
	return fposmod(sin(i * 12.9898 + sd * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var size := _view()
	var colour := Color.from_string(layer["colour"], Color.WHITE)
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
			_slots(x0, spacing, sd, 0.3, func(x, r, _i): _frond(x, h * (0.6 + 0.6 * r), colour, r, size))
		"trees":
			_slots(x0, spacing, sd, 0.25, func(x, r, i): _tree(x, y, h * (0.6 + 0.6 * r), colour.darkened(0.1 * _hash(i + 3, sd))))
		"pines":
			_slots(x0, spacing, sd, 0.2, func(x, r, i): _pine(x, y, h * (0.55 + 0.6 * r), colour.darkened(0.12 * _hash(i + 3, sd)), snow))
		"broadleaf":
			_slots(x0, spacing, sd, 0.3, func(x, r, i): _broadleaf(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.12 * _hash(i + 5, sd))))
		"canopy":
			_slots(x0, spacing, sd, 0.0, func(x, r, i): _canopy(x, y, h * (0.75 + 0.35 * r), colour, i, sd))
		"palms":
			_slots(x0, spacing, sd, 0.35, func(x, r, _i): _palm(x, y, h * (0.7 + 0.4 * r), colour, r))
		"mountains":
			_slots(x0, spacing, sd, 0.0, func(x, r, i): _mountain(x, y, h * (0.6 + 0.5 * r), spacing * (0.9 + 0.6 * _hash(i + 9, sd)), colour.darkened(0.08 * _hash(i + 2, sd)), snow))
		"mesas":
			_slots(x0, spacing, sd, 0.3, func(x, r, _i): _mesa(x, y, h * (0.6 + 0.5 * r), spacing * (0.35 + 0.3 * r), colour))
		"cacti":
			_slots(x0, spacing, sd, 0.35, func(x, r, _i): _cactus(x, y, h * (0.55 + 0.5 * r), colour, r))
		"drifts":
			_slots(x0, spacing, sd, 0.3, func(x, r, _i): _drift(x, size.y, h * (0.5 + r), colour))
		"undergrowth":
			_slots(x0, spacing, sd, float(layer.get("skip", 0.15)), func(x, r, i): _undergrowth(x, y, h * (0.6 + 0.5 * r), colour.darkened(0.15 * _hash(i + 4, sd)), r))
		"vines":
			_slots(x0, spacing, sd, float(layer.get("skip", 0.3)), func(x, r, _i): _vine(x, y, h * (0.4 + 0.7 * r), colour, r))
		"stalks":
			_slots(x0, spacing, sd, float(layer.get("skip", 0.4)), func(x, r, i): _stalk(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.1 * _hash(i + 6, sd)), r))
		"fields":
			_fields(x0, y, h, float(layer.get("wavelength", 400)), sd, colour, size)
		"barns":
			_slots(x0, spacing, sd, 0.25, func(x, r, i): _barn(x, y, h * (0.75 + 0.35 * r), colour, i))
		"fences":
			_fence(x0, y, h, spacing, colour)
		"buildings":
			_slots(x0, spacing, sd, 0.0, func(x, r, i): _building(x, y, h * (0.35 + 0.65 * r), spacing * (0.7 + 0.25 * _hash(i + 9, sd)), colour.darkened(0.12 * _hash(i + 2, sd)), i, sd))
		"lamps":
			_slots(x0, spacing, sd, 0.0, func(x, _r, _i): _lamp(x, y, h, colour))
		"acacias":
			_slots(x0, spacing, sd, 0.3, func(x, r, _i): _acacia(x, y, h * (0.7 + 0.4 * r), colour, r))
		"blossoms":
			_slots(x0, spacing, sd, 0.15, func(x, r, i): _blossom(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.1 * _hash(i + 5, sd)), i, sd))

## Calls `item(x, r, i)` for each slot starting in this chunk, skipping
## a share `skip` of them; `r` is the slot's random 0..1. An item belongs
## to the chunk its slot starts in, so none is drawn twice.
func _slots(x0: float, spacing: float, sd: float, skip: float, item: Callable) -> void:
	for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
		var slot_x := i * spacing
		if slot_x < x0 or slot_x >= x0 + CHUNK:
			continue
		var r := _hash(i, sd)
		if r < skip:
			continue
		item.call(slot_x - x0 + spacing * 0.5 * _hash(i + 7, sd), r, i)

func _hills(x0: float, y: float, h: float, wavelength: float, sd: float, colour: Color, size: Vector2) -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= CHUNK + 0.5:
		pts.append(Vector2(x, y - h * (0.5 + 0.5 * _noise((x0 + x) / wavelength, sd))))
		x += 16.0
	# Overlap the neighbours by a pixel so no seam shows between chunks.
	pts[0] = Vector2(-1.0, pts[0].y)
	pts[pts.size() - 1] = Vector2(CHUNK + 1.0, pts[pts.size() - 1].y)
	pts.append(Vector2(CHUNK + 1.0, size.y))
	pts.append(Vector2(-1.0, size.y))
	draw_colored_polygon(pts, colour)

func _water(x0: float, y: float, h: float, sd: float, colour: Color) -> void:
	draw_rect(Rect2(-1.0, y, CHUNK + 2.0, h), colour)
	var shimmer := Color(1, 1, 1, 0.35)
	var spacing := 38.0
	var t := _now()
	for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
		var r := _hash(i, sd)
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
			pts.append(Vector2(x, y + h - 3.0 + reach + 3.0 * _noise((x0 + x) / 90.0, sd + t * 0.05)))
			x += 12.0
		draw_polyline(pts, Color(1, 1, 1, 0.8), 4.0, true)

func _ground(x0: float, y: float, h: float, sd: float, colour: Color, size: Vector2) -> void:
	# A bank with a gently uneven top edge, then the path.
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= CHUNK + 0.5:
		pts.append(Vector2(x, y - 6.0 * _noise((x0 + x) / 220.0, sd)))
		x += 16.0
	pts[0] = Vector2(-1.0, pts[0].y)
	pts[pts.size() - 1] = Vector2(CHUNK + 1.0, pts[pts.size() - 1].y)
	pts.append(Vector2(CHUNK + 1.0, size.y))
	pts.append(Vector2(-1.0, size.y))
	draw_colored_polygon(pts, colour)
	var py := _path()
	var path_colour := Color.from_string(layer.get("path", "#d9c49a"), Color.TAN)
	draw_rect(Rect2(-1.0, py - h * 0.1, CHUNK + 2.0, h * 0.2), path_colour)
	if layer.get("craters", false):
		for i in range(floori(x0 / 140.0), floori((x0 + CHUNK) / 140.0) + 1):
			var r := _hash(i, sd + 3.0)
			var c := Vector2(i * 140.0 - x0 + 60.0 * r, y + h * (0.12 + 0.75 * _hash(i, sd + 8.0)))
			if absf(c.y - py) < h * 0.12:
				continue
			draw_set_transform(c, 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 10.0 + 22.0 * r, colour.darkened(0.12), true, -1.0, true)
			draw_circle(Vector2(0, 3), 8.0 + 18.0 * r, colour.darkened(0.2), true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
	# Pebbles on the path so movement reads even with flat placeholder art.
	var spacing := 54.0
	for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
		var r := _hash(i, sd + 11.0)
		draw_circle(Vector2(i * spacing - x0 + 20.0 * r, py - h * 0.08 + h * 0.16 * _hash(i, sd + 5.0)), 2.0 + 3.0 * r, path_colour.darkened(0.15))

func _reed_tuft(x: float, top: float, h: float, colour: Color, r: float, size: Vector2) -> void:
	var sway := sin(_now() * 1.2 + r * 6.0) * 6.0
	for k in 3:
		var bx := x + k * 6.0
		draw_line(Vector2(bx, size.y), Vector2(bx + sway + (k - 1) * 5.0, top - h), colour.darkened(0.1 * k), 3.0, true)

## A broad leaf on a stem, bending in the breeze (forest and jungle floor).
func _frond(x: float, h: float, colour: Color, r: float, size: Vector2) -> void:
	var sway := sin(_now() * 1.1 + r * 5.0) * 0.12
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
			var s := Color(0.95, 0.97, 1.0)
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
		var a := TAU * k / 5.0 + _hash(i, sd + 4.0) * 3.0
		var c := Vector2(x, y - th * 0.78) + Vector2(cos(a) * th * 0.22, sin(a) * th * 0.1)
		draw_circle(c, th * (0.16 + 0.05 * _hash(i + k, sd)), colour.darkened(0.07 * (k % 3)), true, -1.0, true)
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
	draw_polyline(trunk, Color("#8a6a45"), maxf(3.0, th * 0.05), true)
	for k in 7:
		var angle := -PI + PI * k / 6.0 + 0.15 * sin(_now() * 0.6 + r * 4.0)
		# Each frond arcs up then droops at the tip.
		var dir := Vector2(cos(angle), sin(angle) * 0.45 + 0.3)
		var tip := top + dir * th * 0.36 + Vector2(0, th * 0.08)
		var mid := top + dir * th * 0.2 + Vector2(0, -th * 0.05)
		# A thick curved stroke rather than a filled shape: at some angles
		# a four-point leaf folds over itself and can't be filled.
		var shade := colour.darkened(0.08 * (k % 2))
		draw_polyline(PackedVector2Array([top, mid, tip]), shade, th * 0.075, true)
		draw_polyline(PackedVector2Array([top.lerp(mid, 0.5), mid, mid.lerp(tip, 0.6)]), shade, th * 0.11, true)
	draw_circle(top, th * 0.035, Color("#6b4f33"), true, -1.0, true)

func _mountain(x: float, y: float, th: float, w: float, colour: Color, snow: bool) -> void:
	var peak := Vector2(x, y - th)
	draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.6, y + 2.0), peak, Vector2(x + w * 0.6, y + 2.0)]), colour)
	draw_colored_polygon(PackedVector2Array([peak, Vector2(x + w * 0.6, y + 2.0), Vector2(x + w * 0.12, y + 2.0)]), colour.darkened(0.1))
	if snow:
		var s := Color(0.96, 0.98, 1.0)
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
	var body := _box(colour, Color.TRANSPARENT, int(w * 0.5))
	draw_style_box(body, Rect2(x - w * 0.5, y - th, w, th))
	var arm_y := y - th * (0.45 + 0.2 * r)
	draw_style_box(body, Rect2(x - w * 1.5, arm_y - th * 0.3, w * 0.7, th * 0.32))
	draw_rect(Rect2(x - w * 1.5, arm_y - w * 0.35, w * 1.2, w * 0.6), colour)
	draw_style_box(body, Rect2(x + w * 0.8, arm_y - th * 0.15, w * 0.7, th * 0.25))
	draw_rect(Rect2(x + w * 0.3, arm_y + th * 0.02, w * 1.2, w * 0.6), colour)

## Rolling farmland: hills striped with rows of crops, a shade either side.
func _fields(x0: float, y: float, h: float, wavelength: float, sd: float, colour: Color, size: Vector2) -> void:
	_hills(x0, y, h, wavelength, sd, colour, size)
	var stripe := colour.darkened(0.12)
	var x := -fposmod(x0, 28.0)
	while x < CHUNK:
		var top := y - h * (0.5 + 0.5 * _noise((x0 + x) / wavelength, sd))
		draw_line(Vector2(x, top + 3.0), Vector2(x - 40.0, size.y), stripe, 5.0, true)
		x += 28.0

## A red barn with a white-trimmed door, and now and then a silo beside it.
func _barn(x: float, y: float, th: float, colour: Color, i: int) -> void:
	var w := th * 1.1
	var trim := Color("#f4efe2")
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - w * 0.5, y + 2.0), Vector2(x - w * 0.5, y - th * 0.6), Vector2(x, y - th),
		Vector2(x + w * 0.5, y - th * 0.6), Vector2(x + w * 0.5, y + 2.0)]), colour)
	draw_polyline(PackedVector2Array([Vector2(x - w * 0.55, y - th * 0.58), Vector2(x, y - th - 2.0), Vector2(x + w * 0.55, y - th * 0.58)]), colour.darkened(0.35), maxf(2.0, th * 0.06), true)
	var door := Rect2(x - w * 0.16, y - th * 0.42, w * 0.32, th * 0.42)
	draw_rect(door, colour.darkened(0.25))
	draw_rect(door, trim, false, 2.0)
	draw_line(door.position, door.end, trim, 2.0, true)
	draw_line(Vector2(door.position.x, door.end.y), Vector2(door.end.x, door.position.y), trim, 2.0, true)
	if i % 2 == 0:
		var silo := _box(Color("#b9b4a8"), Color.TRANSPARENT, int(w * 0.12))
		draw_style_box(silo, Rect2(x + w * 0.56, y - th * 1.1, w * 0.26, th * 1.1 + 2.0))
		draw_circle(Vector2(x + w * 0.69, y - th * 1.08), w * 0.13, Color("#8e8a80"), true, -1.0, true)

## A post-and-rail fence along the far side of the path.
func _fence(x0: float, y: float, h: float, spacing: float, colour: Color) -> void:
	var top := y - h
	for k in 2:
		var ry := top + h * (0.2 + 0.4 * k)
		draw_line(Vector2(-1.0, ry), Vector2(CHUNK + 1.0, ry), colour, maxf(2.0, h * 0.16), true)
	var x := -fposmod(x0, spacing)
	while x <= CHUNK:
		draw_rect(Rect2(x - h * 0.09, top - h * 0.1, h * 0.18, h * 1.1), colour.darkened(0.15))
		x += spacing

## A block of flats or an office: flat roof, rows of windows, and the
## windows lit warm after dark.
func _building(x: float, y: float, th: float, w: float, colour: Color, i: int, sd: float) -> void:
	draw_rect(Rect2(x - w * 0.5, y - th, w, th + 2.0), colour)
	draw_rect(Rect2(x - w * 0.5, y - th, w, maxf(2.0, th * 0.03)), colour.lightened(0.12))
	var cols := maxi(2, floori(w / 14.0))
	var rows := maxi(2, floori(th / 18.0))
	var cell := Vector2(w / cols, th / rows)
	for r in rows - 1:
		for c in cols:
			var lit := _hash(i * 97 + r * 13 + c, sd + 3.0)
			var glass := colour.lightened(0.22)
			if _lit() and lit > 0.45:
				glass = Color("#f5d77a")
			draw_rect(Rect2(x - w * 0.5 + c * cell.x + cell.x * 0.28, y - th + (r + 0.6) * cell.y, cell.x * 0.44, cell.y * 0.45), glass)

## A street lamp: a thin post with a lantern that glows after dark.
func _lamp(x: float, y: float, h: float, colour: Color) -> void:
	draw_line(Vector2(x, y + 2.0), Vector2(x, y - h), colour, maxf(2.0, h * 0.04), true)
	draw_line(Vector2(x, y - h), Vector2(x + h * 0.12, y - h - h * 0.04), colour, maxf(2.0, h * 0.035), true)
	var lantern := Vector2(x + h * 0.14, y - h + h * 0.02)
	if _lit():
		draw_circle(lantern, h * 0.16, Color(1.0, 0.9, 0.55, 0.2), true, -1.0, true)
	draw_circle(lantern, h * 0.045, Color("#f5d77a") if _lit() else colour.lightened(0.3), true, -1.0, true)

## A flat-topped savanna tree on a thin, forking trunk.
func _acacia(x: float, y: float, th: float, colour: Color, r: float) -> void:
	var trunk := colour.darkened(0.45)
	var top := Vector2(x + (r - 0.5) * th * 0.2, y - th * 0.78)
	draw_line(Vector2(x, y + 2.0), top, trunk, maxf(2.0, th * 0.05), true)
	draw_line(top.lerp(Vector2(x, y), 0.35), top + Vector2(-th * 0.25, -th * 0.04), trunk, maxf(1.5, th * 0.03), true)
	draw_line(top.lerp(Vector2(x, y), 0.25), top + Vector2(th * 0.28, 0), trunk, maxf(1.5, th * 0.03), true)
	var w := th * 0.75
	for k in 5:
		var t := k / 4.0
		draw_circle(top + Vector2((t - 0.5) * w, -th * 0.05 - sin(t * PI) * th * 0.06), th * 0.12, colour.darkened(0.06 * (k % 2)), true, -1.0, true)
	_ellipse_flat(top + Vector2(0, -th * 0.06), Vector2(w * 0.56, th * 0.08), colour)

## A cherry tree: a dark crooked trunk under a pink cloud of blossom.
func _blossom(x: float, y: float, th: float, colour: Color, i: int, sd: float) -> void:
	var bark := Color("#5a3b35")
	var lean := (_hash(i, sd + 8.0) - 0.5) * th * 0.18
	var fork := Vector2(x + lean, y - th * 0.5)
	draw_line(Vector2(x, y + 2.0), fork, bark, maxf(2.0, th * 0.06), true)
	draw_line(fork, fork + Vector2(-th * 0.16, -th * 0.18), bark, maxf(1.5, th * 0.035), true)
	draw_line(fork, fork + Vector2(th * 0.18, -th * 0.16), bark, maxf(1.5, th * 0.035), true)
	for k in 6:
		var a := TAU * k / 6.0 + _hash(i, sd) * 2.0
		var c := fork + Vector2(0, -th * 0.22) + Vector2(cos(a) * th * 0.2, sin(a) * th * 0.11)
		draw_circle(c, th * (0.13 + 0.04 * _hash(i + k, sd)), colour.darkened(0.05 * (k % 3)), true, -1.0, true)
	draw_circle(fork + Vector2(0, -th * 0.3), th * 0.15, colour.lightened(0.12), true, -1.0, true)

func _ellipse_flat(c: Vector2, radius: Vector2, colour: Color) -> void:
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, colour)

## A low mound along the bottom edge (snow drifts, moon dust).
## Whether something at `x` (this chunk's space), `reach` wide either
## side, would stand in the scenery's front_gap.
func _in_gap(x: float, reach: float) -> bool:
	var gap := _gap()
	if gap.y <= gap.x:
		return false
	var at := position.x + x
	return at + reach > gap.x and at - reach < gap.y

## A leaf from `base` along `angle`, `length` long and `width` across at
## its widest, curving sideways by `bend` (a share of its length). Both
## edges run steadily from base to tip, so the outline never crosses.
func _leaf(base: Vector2, angle: float, length: float, width: float, bend: float, colour: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := Vector2(-dir.y, dir.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var spine := PackedVector2Array([base])
	for k in range(1, 8):
		var t := k / 8.0
		var c := base + dir * length * t + side * length * bend * t * t
		var half := width * 0.5 * sin(t * PI) * (1.0 - 0.25 * t)
		left.append(c + side * half)
		right.append(c - side * half)
		spine.append(c)
	var tip := base + dir * length + side * length * bend
	spine.append(tip)
	var pts := PackedVector2Array([base])
	pts.append_array(left)
	pts.append(tip)
	right.reverse()
	pts.append_array(right)
	draw_colored_polygon(pts, colour)
	draw_polyline(spine, colour.lightened(0.16), maxf(1.0, width * 0.05), true)

## A clump of big leaves fanning up from the bottom edge.
func _undergrowth(x: float, bottom: float, h: float, colour: Color, r: float) -> void:
	var t := _now()
	var count := 4 + int(r * 3.0)
	for k in count:
		var share := (k + 0.5) / count - 0.5
		var sway := sin(t * 0.9 + r * 5.0 + k * 1.3) * 0.06
		var length := h * (0.75 + 0.35 * _hash(k, r * 10.0))
		_leaf(Vector2(x + share * h * 0.5, bottom + h * 0.08), -PI * 0.5 + share * 1.9 + sway, length, length * 0.4, share * 0.25,
			colour.darkened(0.08 * (k % 2)))

## A vine hanging from the top edge with leaves down its length.
func _vine(x: float, top: float, length: float, colour: Color, r: float) -> void:
	var sway := sin(_now() * 0.7 + r * 4.0) * length * 0.05
	var pts := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		pts.append(Vector2(x + sin(t * 3.0 + r * 6.0) * length * 0.05 + sway * t * t, top - 2.0 + length * t))
	draw_polyline(pts, colour.darkened(0.2), maxf(2.0, length * 0.012), true)
	var leaf := clampf(length * 0.14, 14.0, 48.0)
	for k in range(2, 13, 2):
		var out := 1.0 if k % 4 == 0 else -1.0
		_leaf(pts[k], PI * 0.5 - out * 0.95, leaf, leaf * 0.48, out * 0.1, colour.darkened(0.06 * (k % 3)))
	_leaf(pts[12], PI * 0.5 + 0.3, leaf * 1.1, leaf * 0.5, -0.08, colour)
	_leaf(pts[12], PI * 0.5 - 0.35, leaf, leaf * 0.48, 0.08, colour.darkened(0.08))

## A tall leafy plant growing up from the bottom edge, close enough to
## pass in front of the walker (but never inside the front_gap).
func _stalk(x: float, bottom: float, h: float, colour: Color, r: float) -> void:
	if _in_gap(x, h * 0.45):
		return
	var lean := (r - 0.5) * h * 0.3 + sin(_now() * 0.8 + r * 5.0) * h * 0.03
	var stem := PackedVector2Array()
	for k in 11:
		var t := k / 10.0
		stem.append(Vector2(x + lean * t * t, bottom + 10.0 - (h + 10.0) * t))
	draw_polyline(stem, colour.darkened(0.15), maxf(4.0, h * 0.025), true)
	for k in 4:
		var at := stem[3 + k * 2]
		var out := 1.0 if k % 2 == 0 else -1.0
		var length := h * (0.34 - 0.04 * k)
		_leaf(at, -PI * 0.5 + out * (1.15 - 0.1 * k), length, length * 0.42, out * 0.14, colour.darkened(0.05 * k))
	_leaf(stem[10], -PI * 0.5 + (r - 0.5) * 0.5, h * 0.22, h * 0.09, 0.05, colour)

func _drift(x: float, bottom: float, h: float, colour: Color) -> void:
	draw_set_transform(Vector2(x, bottom), 0.0, Vector2(1.0, h / 40.0))
	draw_circle(Vector2.ZERO, 40.0, colour, true, -1.0, true)
	draw_circle(Vector2(34, 8), 30.0, colour, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
