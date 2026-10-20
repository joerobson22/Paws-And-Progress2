class_name AnimalView
extends Node2D
## Placeholder animal drawn from simple shapes, recoloured per part.
## The origin is where its feet touch the ground; it faces right.
## Replace with Joe's sprite rig per animal (Content.animal(id).sprite_dir) later;
## keep the same properties so the screens using it don't need to change.

## Where each shape's mouth is, so it can carry a gift.
const MOUTHS := {
	"dog": Vector2(70, -54), "bear": Vector2(66, -52), "cat": Vector2(50, -46),
	"rabbit": Vector2(34, -42), "snail": Vector2(50, -14), "bird": Vector2(36, -38),
}

@export var animal_id: String = "staffy":
	set(v):
		animal_id = v
		queue_redraw()
@export var walking: bool = false
## A livelier gait for fetching: quicker steps, bigger strides and bounce.
var running := false
## Multiplier on top of the animal's own walk speed.
@export var speed: float = 1.0

var colours: Array[Color] = []:
	set(v):
		colours = v
		queue_redraw()
## How far below the water it is, in its own pixels (0 on dry land), and the
## water's colour: the part under the surface is hidden behind it.
var submerged := 0.0:
	set(v):
		submerged = v
		queue_redraw()
var water_colour := Color("#7fb2c9")
## A gift id to carry in its mouth, or "".
var held_gift := "":
	set(v):
		held_gift = v
		queue_redraw()
## 0 normally, up to 1 when it's dejected: head, ears and tail hang, the
## eyes droop and it sighs now and then.
var sad := 0.0:
	set(v):
		sad = v
		queue_redraw()

var _phase: float = 0.0
var _sigh: float = 0.0


func _process(delta: float) -> void:
	if walking:
		var walk_speed := float(Content.animal(animal_id).get("walk_speed", 1.0))
		_phase += delta * TAU * (0.6 + walk_speed) * speed * (2.4 if running else 1.0)
		queue_redraw()
	if sad > 0.0:
		_sigh += delta
		queue_redraw()


## How far the head hangs, in the animal's own pixels.
func _droop() -> Vector2:
	return Vector2(4, 14) * sad + Vector2(0, (sin(_sigh * 1.3) * 0.5 + 0.5) * 2.0 * sad)


## An eye, with a heavy lid in the head's colour when it's sad.
func _eye(at: Vector2, r: float, lid: Color) -> void:
	draw_circle(at, r, UI.INK)
	_lid(at, r, lid)


## The sad lid over an eye: lower at the outer corner (away from the nose)
## than the inner one.
func _lid(at: Vector2, r: float, lid: Color) -> void:
	if sad > 0.05:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-r - 1.5, -r - 2.0), at + Vector2(r + 1.5, -r - 2.0),
			at + Vector2(r + 1.5, -r + 2.0 * r * 0.25 * sad), at + Vector2(-r - 1.5, -r + 2.0 * r * 0.75 * sad)]), lid)


func _stride() -> float:
	return 2.2 if running else 1.0


func _part(part: String, fallback: Color) -> Color:
	var parts: Array = Content.animal(animal_id).get("parts", [])
	var i := parts.find(part)
	if i >= 0 and i < colours.size():
		return colours[i]
	var defaults := Content.animal_default_colours(animal_id)
	if i >= 0 and i < defaults.size():
		return defaults[i]
	return fallback


func _draw() -> void:
	var data := Content.animal(animal_id)
	var s := float(data.get("size", 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	match str(data.get("shape", "dog")):
		"cat":
			_draw_cat()
		"rabbit":
			_draw_rabbit()
		"snail":
			_draw_snail()
		"bird":
			_draw_bird()
		"bear":
			_draw_bear()
		_:
			_draw_dog()
	if submerged > 0.5:
		draw_rect(Rect2(-90, -submerged, 190, submerged + 10), Color(water_colour, 0.92))
		draw_line(Vector2(-60, -submerged), Vector2(80, -submerged), Color(1, 1, 1, 0.55), 2.0, true)
	if held_gift != "":
		_draw_held_gift(str(data.get("shape", "dog")))


## The gift's position in this node's own space (for glows behind it).
func mouth() -> Vector2:
	var s := float(Content.animal(animal_id).get("size", 1.0))
	return MOUTHS.get(str(Content.animal(animal_id).get("shape", "dog")), Vector2(60, -50)) * s


func _draw_held_gift(shape: String) -> void:
	var g := Content.gift(held_gift)
	var colour := Content.rarity_colour(g.get("rarity", "common"))
	var at: Vector2 = MOUTHS.get(shape, Vector2(60, -50))
	draw_circle(at, 15, Color(colour, 0.22), true, -1.0, true)
	draw_circle(at, 11, UI.SURFACE, true, -1.0, true)
	var icon := Icons.texture("gift", 16, colour)
	draw_texture(icon, at - Vector2(8, 8))


func _ellipse(centre: Vector2, radius: Vector2, colour: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(angle))
	draw_colored_polygon(pts, colour)


func _legs(xs: Array, top: float, length: float, width: float, colour: Color) -> void:
	for i in xs.size():
		var swing := sin(_phase + PI * (i % 2)) * 0.35 * _stride() if walking else 0.0
		var base := Vector2(xs[i], top)
		var foot := base + Vector2(0, length).rotated(swing)
		draw_line(base, foot, colour, width, true)
		draw_circle(foot, width * 0.5, colour)


func _draw_dog() -> void:
	var legs := _part("Legs", Color.SADDLE_BROWN)
	var body := _part("Body", Color.BURLYWOOD)
	var pattern := _part("Pattern", Color.WHITE)
	var bob := absf(sin(_phase)) * 2.0 * _stride() if walking else 0.0
	_legs([-30, -18, 18, 30], -30 - bob, 30, 9, legs)
	var tail_tip := Vector2(-58, -62 - bob + sin(_phase * 2.0) * 4.0).lerp(Vector2(-54, -24), sad)
	draw_line(Vector2(-40, -44 - bob), tail_tip, body, 7, true)
	_ellipse(Vector2(0, -42 - bob), Vector2(44, 19), body)
	_ellipse(Vector2(6, -34 - bob), Vector2(26, 10), pattern)
	var d := _droop()
	_ellipse(Vector2(46, -62 - bob) + d, Vector2(17, 15), body)
	_ellipse(Vector2(60, -57 - bob) + d, Vector2(10, 7), pattern)
	_ellipse(Vector2(38, -60 - bob) + d, Vector2(6, 12), body.darkened(0.25), 0.3 - 0.25 * sad)
	_eye(Vector2(50, -66 - bob) + d, 2.5, body)
	draw_circle(Vector2(69, -58 - bob) + d, 3.0, UI.INK)


func _draw_bear() -> void:
	var legs := _part("Legs", Color.SADDLE_BROWN)
	var body := _part("Body", Color.SADDLE_BROWN)
	var pattern := _part("Pattern", Color.TAN)
	var bob := absf(sin(_phase)) * 2.0 * _stride() if walking else 0.0
	_legs([-26, -14, 14, 26], -26 - bob, 26, 14, legs)
	_ellipse(Vector2(0, -44 - bob), Vector2(42, 24), body)
	var d := _droop()
	_ellipse(Vector2(42, -60 - bob) + d, Vector2(18, 16), body)
	draw_circle(Vector2(34, -76 - bob) + d, 6, body)
	draw_circle(Vector2(50, -76 - bob) + d, 6, body)
	_ellipse(Vector2(56, -56 - bob) + d, Vector2(9, 7), pattern)
	_eye(Vector2(46, -64 - bob) + d, 2.5, body)
	draw_circle(Vector2(63, -57 - bob) + d, 3.0, UI.INK)


func _draw_cat() -> void:
	var legs := _part("Legs", Color.DIM_GRAY)
	var body := _part("Body", Color.GRAY)
	var eyes := _part("Eyes", Color.YELLOW_GREEN)
	_legs([-24, -14, 14, 24], -26, 26, 6, legs)
	var tail := PackedVector2Array()
	for i in 10:
		var t := i / 9.0
		tail.append(Vector2(-34 - t * 16, -36 + lerpf(-t * 36.0, t * 24.0, sad) + sin(_phase + t * 3.0) * 3.0 * (1.0 - sad)))
	draw_polyline(tail, body, 5, true)
	_ellipse(Vector2(0, -36), Vector2(36, 13), body)
	var d := _droop() * 0.8
	_ellipse(Vector2(38, -52) + d, Vector2(13, 12), body)
	# Ears flatten back when it's sad.
	var flat := Vector2(-4, 5) * sad
	draw_colored_polygon(PackedVector2Array([Vector2(28, -58) + d, Vector2(31, -72) + d + flat, Vector2(37, -61) + d]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(39, -62) + d, Vector2(45, -73) + d + flat, Vector2(48, -59) + d]), body)
	draw_circle(Vector2(43, -54) + d, 3.0, eyes)
	draw_circle(Vector2(43, -54) + d, 1.2, UI.INK)
	_lid(Vector2(43, -54) + d, 3.0, body)


func _draw_rabbit() -> void:
	var legs := _part("Legs", Color.TAN)
	var body := _part("Body", Color.WHEAT)
	var pattern := _part("Pattern", Color.WHITE)
	var hop := absf(sin(_phase * 0.5)) * 14.0 * _stride() if walking else 0.0
	_ellipse(Vector2(-14, -12 - hop), Vector2(16, 10), legs)
	_ellipse(Vector2(12, -8 - hop), Vector2(6, 8), legs)
	_ellipse(Vector2(0, -28 - hop), Vector2(26, 20), body)
	draw_circle(Vector2(-26, -30 - hop), 7, pattern)
	var d := _droop() * 0.6
	_ellipse(Vector2(22, -46 - hop) + d, Vector2(13, 12), body)
	# The ears flop down its back when it's sad.
	_ellipse(Vector2(16, -70 - hop).lerp(Vector2(4, -52), sad) + d, Vector2(5, 16), body, lerpf(-0.2, -1.35, sad))
	_ellipse(Vector2(24, -70 - hop).lerp(Vector2(10, -54), sad) + d, Vector2(5, 16), body, lerpf(0.15, -1.2, sad))
	_eye(Vector2(27, -48 - hop) + d, 2.2, body)


func _draw_snail() -> void:
	var body := _part("Body", Color.TAN)
	var shell := _part("Shell", Color.SIENNA)
	var pattern := _part("Pattern", Color.BURLYWOOD)
	var stretch := 1.0 + (sin(_phase) * 0.06 if walking else 0.0)
	_ellipse(Vector2(4, -8), Vector2(40 * stretch, 9), body)
	# The eye stalks sag when it's sad.
	var stalk := Vector2(44, -34).lerp(Vector2(50, -20), sad)
	draw_line(Vector2(36, -12), stalk, body, 3, true)
	draw_line(Vector2(30, -12), Vector2(34, -30).lerp(Vector2(40, -18), sad), body, 3, true)
	draw_circle(stalk, 3, UI.INK)
	draw_circle(Vector2(-4, -30), 24, shell)
	var spiral := PackedVector2Array()
	for i in 40:
		var a := i * 0.4
		spiral.append(Vector2(-4, -30) + Vector2(cos(a), sin(a)) * (2.0 + i * 0.45))
	draw_polyline(spiral, pattern, 3, true)


func _draw_bird() -> void:
	var wings := _part("Wings", Color.STEEL_BLUE)
	var body := _part("Body", Color.LIGHT_SKY_BLUE)
	var pattern := _part("Pattern", Color.GOLD)
	var hop := absf(sin(_phase * 0.7)) * 8.0 * _stride() if walking else 0.0
	draw_line(Vector2(-4, -12 - hop), Vector2(-6, 0), Color("#7a5236"), 2, true)
	draw_line(Vector2(6, -12 - hop), Vector2(6, 0), Color("#7a5236"), 2, true)
	_ellipse(Vector2(0, -28 - hop), Vector2(20, 16), body)
	_ellipse(Vector2(4, -22 - hop), Vector2(11, 9), pattern)
	var flap := sin(_phase * 2.0) * 0.5 if walking else 0.0
	_ellipse(Vector2(-6, -32 - hop), Vector2(15, 7), wings, -0.3 + flap)
	var d := _droop() * 0.5
	draw_circle(Vector2(18, -40 - hop) + d, 9, body)
	draw_colored_polygon(PackedVector2Array([Vector2(26, -42 - hop) + d, Vector2(34, -39 - hop) + d, Vector2(26, -36 - hop) + d]), pattern.darkened(0.2))
	_eye(Vector2(20, -43 - hop) + d, 1.8, body)
