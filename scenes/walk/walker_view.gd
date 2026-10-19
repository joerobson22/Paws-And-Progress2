class_name WalkerView
extends Node2D
## Placeholder walker (the player character). Origin at the feet, facing right.
## Equipped cosmetics show as rarity-coloured accents until real art exists.

const SKIN_TONES: Array[Color] = [
	Color("#f3d2b3"), Color("#e2b48f"), Color("#c68d63"), Color("#9a6440"), Color("#6b4128"), Color("#4a2c1b"),
]
const HAIR_TONES: Array[Color] = [
	Color("#2b211c"), Color("#5a3b25"), Color("#8d5a32"), Color("#c99a5b"), Color("#e6cf9a"), Color("#9c9c9c"), Color("#b4533f"),
]

@export var walking: bool = false
@export var speed: float = 1.0

var _phase: float = 0.0
## Hand position in local space, so the walk screen can draw the lead.
var hand := Vector2(22, -78)


func _process(delta: float) -> void:
	if walking:
		_phase += delta * TAU * 1.4 * speed
		queue_redraw()


func _equipped(slot: String) -> Dictionary:
	var id := str(App.state.profile["cosmetics"].get(slot, ""))
	return Content.gift(id) if id != "" else {}


func _accent(slot: String, fallback: Color) -> Color:
	var g := _equipped(slot)
	return Content.rarity_colour(g["rarity"]) if not g.is_empty() else fallback


func _draw() -> void:
	var p := App.state.profile
	var skin := SKIN_TONES[clampi(int(p["skin_tone"]), 0, SKIN_TONES.size() - 1)]
	var hair := HAIR_TONES[clampi(int(p["hair_tone"]), 0, HAIR_TONES.size() - 1)]
	var trousers := _accent("trousers", Color("#4b5a6e"))
	var jumper := _accent("jumper", Color("#b4533f"))
	var bob := absf(sin(_phase)) * 2.0 if walking else 0.0

	for i in 2:
		var swing := sin(_phase + PI * i) * 0.4 if walking else 0.0
		var hip := Vector2(0, -56 - bob)
		draw_line(hip, hip + Vector2(0, 54).rotated(swing), trousers, 11, true)

	var arm_swing := sin(_phase + PI) * 0.35 if walking else 0.0
	var shoulder := Vector2(0, -100 - bob)
	draw_line(shoulder, shoulder + Vector2(0, 40).rotated(arm_swing), jumper.darkened(0.15), 9, true)
	draw_rect(Rect2(-14, -108 - bob, 28, 56), jumper)
	hand = Vector2(22, -78 - bob)
	draw_line(shoulder, hand, jumper, 9, true)
	draw_circle(hand, 5, skin)

	var stick := _equipped("walking_stick")
	if not stick.is_empty():
		draw_line(hand + Vector2(4, -8), hand + Vector2(14, 76 + bob), Color("#7a5236"), 4, true)

	var head := Vector2(2, -124 - bob)
	draw_circle(head, 16, skin)
	draw_arc(head, 16, PI, TAU, 16, hair, 9, true)
	draw_circle(head + Vector2(8, -2), 2, UI.INK)

	var neck := _equipped("neckwear")
	if not neck.is_empty():
		draw_line(Vector2(-12, -106 - bob), Vector2(12, -106 - bob), Content.rarity_colour(neck["rarity"]), 6, true)
	var hat := _equipped("hat")
	if not hat.is_empty():
		var c := Content.rarity_colour(hat["rarity"])
		draw_rect(Rect2(head.x - 20, head.y - 16, 40, 5), c)
		draw_rect(Rect2(head.x - 12, head.y - 32, 24, 17), c)
