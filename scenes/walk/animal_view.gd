class_name AnimalView
extends Node2D
## Placeholder animal drawn from simple shapes, recoloured per part.
## The origin is where its feet touch the ground; it faces right.
## Replace with Joe's sprite rig per animal (Content.animal(id).sprite_dir) later;
## keep the same properties so the walk screen doesn't need to change.

@export var animal_id: String = "staffy":
	set(v):
		animal_id = v
		queue_redraw()
@export var walking: bool = false
## Multiplier on top of the animal's own walk speed.
@export var speed: float = 1.0

var colours: Array[Color] = []:
	set(v):
		colours = v
		queue_redraw()

var _phase: float = 0.0


func _process(delta: float) -> void:
	if walking:
		var walk_speed := float(Content.animal(animal_id).get("walk_speed", 1.0))
		_phase += delta * TAU * (0.6 + walk_speed) * speed
		queue_redraw()


func _part(name: String, fallback: Color) -> Color:
	var parts: Array = Content.animal(animal_id).get("parts", [])
	var i := parts.find(name)
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


func _ellipse(centre: Vector2, radius: Vector2, colour: Color, rotation: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(rotation))
	draw_colored_polygon(pts, colour)


func _legs(xs: Array, top: float, length: float, width: float, colour: Color) -> void:
	for i in xs.size():
		var swing := sin(_phase + PI * (i % 2)) * 0.35 if walking else 0.0
		var base := Vector2(xs[i], top)
		var foot := base + Vector2(0, length).rotated(swing)
		draw_line(base, foot, colour, width, true)
		draw_circle(foot, width * 0.5, colour)


func _draw_dog() -> void:
	var legs := _part("Legs", Color.SADDLE_BROWN)
	var body := _part("Body", Color.BURLYWOOD)
	var pattern := _part("Pattern", Color.WHITE)
	var bob := absf(sin(_phase)) * 2.0 if walking else 0.0
	_legs([-30, -18, 18, 30], -30 - bob, 30, 9, legs)
	draw_line(Vector2(-40, -44 - bob), Vector2(-58, -62 - bob + sin(_phase * 2.0) * 4.0), body, 7, true)
	_ellipse(Vector2(0, -42 - bob), Vector2(44, 19), body)
	_ellipse(Vector2(6, -34 - bob), Vector2(26, 10), pattern)
	_ellipse(Vector2(46, -62 - bob), Vector2(17, 15), body)
	_ellipse(Vector2(60, -57 - bob), Vector2(10, 7), pattern)
	_ellipse(Vector2(38, -60 - bob), Vector2(6, 12), body.darkened(0.25), 0.3)
	draw_circle(Vector2(50, -66 - bob), 2.5, UI.INK)
	draw_circle(Vector2(69, -58 - bob), 3.0, UI.INK)


func _draw_bear() -> void:
	var legs := _part("Legs", Color.SADDLE_BROWN)
	var body := _part("Body", Color.SADDLE_BROWN)
	var pattern := _part("Pattern", Color.TAN)
	var bob := absf(sin(_phase)) * 2.0 if walking else 0.0
	_legs([-26, -14, 14, 26], -26 - bob, 26, 14, legs)
	_ellipse(Vector2(0, -44 - bob), Vector2(42, 24), body)
	_ellipse(Vector2(42, -60 - bob), Vector2(18, 16), body)
	draw_circle(Vector2(34, -76 - bob), 6, body)
	draw_circle(Vector2(50, -76 - bob), 6, body)
	_ellipse(Vector2(56, -56 - bob), Vector2(9, 7), pattern)
	draw_circle(Vector2(46, -64 - bob), 2.5, UI.INK)
	draw_circle(Vector2(63, -57 - bob), 3.0, UI.INK)


func _draw_cat() -> void:
	var legs := _part("Legs", Color.DIM_GRAY)
	var body := _part("Body", Color.GRAY)
	var eyes := _part("Eyes", Color.YELLOW_GREEN)
	_legs([-24, -14, 14, 24], -26, 26, 6, legs)
	var tail := PackedVector2Array()
	for i in 10:
		var t := i / 9.0
		tail.append(Vector2(-34 - t * 16, -36 - t * 36 + sin(_phase + t * 3.0) * 3.0))
	draw_polyline(tail, body, 5, true)
	_ellipse(Vector2(0, -36), Vector2(36, 13), body)
	_ellipse(Vector2(38, -52), Vector2(13, 12), body)
	draw_colored_polygon(PackedVector2Array([Vector2(28, -58), Vector2(31, -72), Vector2(37, -61)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(39, -62), Vector2(45, -73), Vector2(48, -59)]), body)
	draw_circle(Vector2(43, -54), 3.0, eyes)
	draw_circle(Vector2(43, -54), 1.2, UI.INK)


func _draw_rabbit() -> void:
	var legs := _part("Legs", Color.TAN)
	var body := _part("Body", Color.WHEAT)
	var pattern := _part("Pattern", Color.WHITE)
	var hop := absf(sin(_phase * 0.5)) * 14.0 if walking else 0.0
	_ellipse(Vector2(-14, -12 - hop), Vector2(16, 10), legs)
	_ellipse(Vector2(12, -8 - hop), Vector2(6, 8), legs)
	_ellipse(Vector2(0, -28 - hop), Vector2(26, 20), body)
	draw_circle(Vector2(-26, -30 - hop), 7, pattern)
	_ellipse(Vector2(22, -46 - hop), Vector2(13, 12), body)
	_ellipse(Vector2(16, -70 - hop), Vector2(5, 16), body, -0.2)
	_ellipse(Vector2(24, -70 - hop), Vector2(5, 16), body, 0.15)
	draw_circle(Vector2(27, -48 - hop), 2.2, UI.INK)


func _draw_snail() -> void:
	var body := _part("Body", Color.TAN)
	var shell := _part("Shell", Color.SIENNA)
	var pattern := _part("Pattern", Color.BURLYWOOD)
	var stretch := 1.0 + (sin(_phase) * 0.06 if walking else 0.0)
	_ellipse(Vector2(4, -8), Vector2(40 * stretch, 9), body)
	draw_line(Vector2(36, -12), Vector2(44, -34), body, 3, true)
	draw_line(Vector2(30, -12), Vector2(34, -30), body, 3, true)
	draw_circle(Vector2(44, -34), 3, UI.INK)
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
	var hop := absf(sin(_phase * 0.7)) * 8.0 if walking else 0.0
	draw_line(Vector2(-4, -12 - hop), Vector2(-6, 0), Color("#7a5236"), 2, true)
	draw_line(Vector2(6, -12 - hop), Vector2(6, 0), Color("#7a5236"), 2, true)
	_ellipse(Vector2(0, -28 - hop), Vector2(20, 16), body)
	_ellipse(Vector2(4, -22 - hop), Vector2(11, 9), pattern)
	var flap := sin(_phase * 2.0) * 0.5 if walking else 0.0
	_ellipse(Vector2(-6, -32 - hop), Vector2(15, 7), wings, -0.3 + flap)
	draw_circle(Vector2(18, -40 - hop), 9, body)
	draw_colored_polygon(PackedVector2Array([Vector2(26, -42 - hop), Vector2(34, -39 - hop), Vector2(26, -36 - hop)]), pattern.darkened(0.2))
	draw_circle(Vector2(20, -43 - hop), 1.8, UI.INK)
