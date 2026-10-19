class_name CabinView
extends Control
## The illustrated cabin, cropped to fill its box like a CSS "cover" image,
## with hotspot pills pinned to spots in the picture so they stay on the
## noticeboard, shelf and door however the box is shaped.

const ART := preload("res://assets/cabin/cabin.png")

var _hotspots: Array = []  # [Control, Vector2 fraction of the art]
var _radius := 28
var _bottom_only := false


## `bottom_only` rounds just the bottom corners (the phone layout's header).
func _init(radius: int = 28, bottom_only: bool = false) -> void:
	_radius = radius
	_bottom_only = bottom_only
	clip_contents = true
	resized.connect(_place)


## Pins `control` at `at` (0..1 across and down the art), centred there.
func add_hotspot(control: Control, at: Vector2) -> void:
	add_child(control)
	_hotspots.append([control, at])
	control.resized.connect(_place)
	_place.call_deferred()


## Where the art lands inside this box once cropped to cover it.
func art_rect() -> Rect2:
	var art := Vector2(ART.get_size())
	var s := maxf(size.x / art.x, size.y / art.y)
	var drawn := art * s
	return Rect2((size - drawn) * Vector2(0.5, 0.6), drawn)


func _draw() -> void:
	draw_texture_rect(ART, art_rect(), false)
	# Darken the top so the greeting reads against the logs.
	var dark := Color(0.1, 0.06, 0.03, 0.6)
	var clear := Color(dark, 0.0)
	var h := size.y * 0.45
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)]),
		PackedColorArray([dark, dark, clear, clear]))
	_draw_corners()


## Paints the page colour over the corners, which reads as rounded corners.
func _draw_corners() -> void:
	var bg := UI.BG
	var rad := float(_radius)
	var corners := [Vector2(size.x, size.y), Vector2(0, size.y)]
	if not _bottom_only:
		corners += [Vector2(0, 0), Vector2(size.x, 0)]
	for c in corners:
		var dir := Vector2(-1 if c.x > 0 else 1, -1 if c.y > 0 else 1)
		var centre: Vector2 = c + dir * rad
		var pts := PackedVector2Array([c])
		var a1 := Vector2(-dir.x, 0).angle()
		var turn := wrapf(Vector2(0, -dir.y).angle() - a1, -PI, PI)
		for i in 9:
			var a := a1 + turn * i / 8.0
			pts.append(centre + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, bg)


func _place() -> void:
	var r := art_rect()
	for h in _hotspots:
		var c: Control = h[0]
		var at: Vector2 = h[1]
		var p := r.position + r.size * at - c.size * 0.5
		# Keep pills inside the visible box on narrow screens.
		p.x = clampf(p.x, 10.0, maxf(10.0, size.x - c.size.x - 10.0))
		p.y = clampf(p.y, 10.0, maxf(10.0, size.y - c.size.y - 10.0))
		c.position = p
	queue_redraw()
