class_name CharacterView
extends Node2D
## The player's character (or a friend's), drawn from simple shapes until
## real art exists. The origin is at the feet and it faces right.
## `look` is {skin_tone, hair_tone, cosmetics: {slot: item id}}; leave it
## empty to follow the player's own profile. `face_only` draws just the head
## and shoulders, centred on the face, for avatars.

const STICK := Color("#7a5236")

@export var walking: bool = false
@export var speed: float = 1.0

var look: Dictionary = {}:
	set(v):
		look = v
		queue_redraw()
var face_only := false:
	set(v):
		face_only = v
		queue_redraw()
## Reaching forward for the lead on a walk; arms down for portraits.
var holding_lead := true
## Hand position in local space, so the walk screen can draw the lead.
var hand := Vector2(22, -78)
## 0 normally, up to 1 when they're dejected: shoulders down, head hung,
## a frown, and a sigh now and then.
var sad := 0.0:
	set(v):
		sad = v
		queue_redraw()

var _phase: float = 0.0
var _sigh: float = 0.0


func _process(delta: float) -> void:
	if walking:
		_phase += delta * TAU * 1.4 * speed
		queue_redraw()
	if sad > 0.0:
		_sigh += delta
		queue_redraw()


## Redraws after the look it follows has changed.
func refresh() -> void:
	queue_redraw()


func _look() -> Dictionary:
	return look if not look.is_empty() else App.state.profile


func _item(slot: String) -> Dictionary:
	var cosmetics: Dictionary = _look().get("cosmetics", {})
	var id := str(cosmetics.get(slot, ""))
	var item := Content.cosmetic(id) if id != "" else {}
	return item if not item.is_empty() else Content.default_cosmetic(slot)


static func _style(item: Dictionary) -> String:
	return str(item.get("style", "none"))


func _draw() -> void:
	var l := _look()
	var skin: Color = Content.skin_tones[clampi(int(l.get("skin_tone", 0)), 0, Content.skin_tones.size() - 1)]
	var hair: Color = Content.hair_tones[clampi(int(l.get("hair_tone", 0)), 0, Content.hair_tones.size() - 1)]
	var top := _item("top")
	var top_colour := Content.cosmetic_colour(top, Color("#b4533f"))
	var bob := absf(sin(_phase)) * 2.0 if walking and not face_only else 0.0
	# Slumped: everything above the hips sinks a little, and the head hangs.
	if not face_only:
		bob -= 4.0 * sad + (sin(_sigh * 1.3) * 0.5 + 0.5) * 1.5 * sad
	var head := Vector2(2 + 5.0 * sad, -124 - bob + 7.0 * sad)
	if face_only:
		draw_set_transform(-head)

	if _style(top) == "cape" and not face_only:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10, -106 - bob), Vector2(6, -106 - bob), Vector2(-8, -38 - bob), Vector2(-30, -42 - bob + sin(_phase) * 3.0)]),
			top_colour.darkened(0.1))
	if _style(top) == "hoodie":
		draw_circle(head + Vector2(-10, 8), 11, top_colour.darkened(0.18), true, -1.0, true)

	var shoulder := Vector2(0, -100 - bob)
	var sleeve := top_colour if _style(top) != "cape" else top_colour.lightened(0.35)
	if face_only:
		draw_rect(Rect2(-17, -110, 36, 40), sleeve)
	else:
		_draw_body(skin, top, sleeve, shoulder, bob)

	_draw_neckwear(bob)
	_draw_head(head, skin, hair)


func _draw_body(skin: Color, top: Dictionary, sleeve: Color, shoulder: Vector2, bob: float) -> void:
	var gloves := _item("gloves")
	var trousers := _item("trousers")
	var trouser_colour := Content.cosmetic_colour(trousers, Color("#4b5a6e"))
	var tee := _style(top) == "tee"

	# Back arm.
	var arm_swing := sin(_phase + PI) * 0.35 if walking else 0.0
	var back_hand := shoulder + Vector2(0, 40).rotated(arm_swing)
	_draw_arm(shoulder, back_hand, sleeve.darkened(0.15), skin.darkened(0.1), tee)
	_draw_hand(back_hand, skin.darkened(0.1), gloves, 0.1)

	# Legs and shoes, back leg a shade darker.
	for i in 2:
		var swing := sin(_phase + PI * i) * 0.4 if walking else 0.0
		var hip := Vector2(0, -56 - bob)
		var foot := hip + Vector2(0, 54).rotated(swing)
		var knee := hip.lerp(foot, 0.5)
		var shade := 0.12 if i == 0 else 0.0
		if _style(trousers) == "shorts":
			draw_line(hip, knee, trouser_colour.darkened(shade), 12, true)
			draw_line(knee, foot, skin.darkened(shade), 8, true)
		else:
			draw_line(hip, foot, trouser_colour.darkened(shade), 11, true)
		_draw_shoe(foot, shade)

	# Body.
	var body := Rect2(-14, -108 - bob, 28, 56)
	draw_rect(body, sleeve)
	match _style(top):
		"jumper":
			draw_rect(Rect2(-14, -57 - bob, 28, 5), sleeve.darkened(0.15))
			if top.has("rarity"):
				draw_circle(Vector2(5, -86 - bob), 6, sleeve.lightened(0.35), true, -1.0, true)
		"hoodie":
			draw_rect(Rect2(-6, -72 - bob, 17, 9), sleeve.darkened(0.12))
			draw_line(Vector2(6, -104 - bob), Vector2(7, -92 - bob), UI.SURFACE, 1.5, true)
		"tee":
			draw_rect(Rect2(-14, -108 - bob, 28, 4), sleeve.darkened(0.1))

	# Front arm, holding the lead (or hanging down when there isn't one).
	hand = Vector2(22, -78 - bob) if holding_lead else shoulder + Vector2(3, 40).rotated(sin(_phase) * 0.35 if walking else 0.0)
	_draw_arm(shoulder, hand, sleeve, skin, tee)
	_draw_hand(hand, skin, gloves, 0.0)

	var stick := _item("walking_stick")
	if _style(stick) != "none":
		var colour := Content.cosmetic_colour(stick, STICK)
		draw_line(hand + Vector2(4, -10), Vector2(hand.x + 14, 0), STICK, 4, true)
		draw_circle(hand + Vector2(4, -11), 4.5, colour, true, -1.0, true)


func _draw_arm(from: Vector2, to: Vector2, sleeve: Color, skin: Color, short_sleeve: bool) -> void:
	if short_sleeve:
		var elbow := from.lerp(to, 0.45)
		draw_line(from, elbow, sleeve, 10, true)
		draw_line(elbow, to, skin, 8, true)
	else:
		draw_line(from, to, sleeve, 9, true)


func _draw_hand(at: Vector2, skin: Color, gloves: Dictionary, shade: float) -> void:
	match _style(gloves):
		"mittens":
			draw_circle(at, 6.5, Content.cosmetic_colour(gloves, UI.INK).darkened(shade), true, -1.0, true)
		"ring":
			draw_circle(at, 5, skin, true, -1.0, true)
			draw_arc(at + Vector2(1, 1), 3.2, 0, TAU, 12, Content.cosmetic_colour(gloves, UI.INK), 2.0, true)
		_:
			draw_circle(at, 5, skin, true, -1.0, true)


func _draw_shoe(foot: Vector2, shade: float) -> void:
	var shoes := _item("shoes")
	var colour := Content.cosmetic_colour(shoes, Color("#5a3b25")).darkened(shade)
	match _style(shoes):
		"trainers":
			_ellipse(foot + Vector2(4, -1), Vector2(9, 4.5), colour)
			draw_line(foot + Vector2(-4, 2), foot + Vector2(12, 2), colour.darkened(0.35), 2, true)
			draw_line(foot + Vector2(0, -2), foot + Vector2(7, -3), UI.ACCENT.darkened(shade), 2, true)
		"wellies":
			draw_rect(Rect2(foot.x - 6, foot.y - 16, 13, 16), colour)
			_ellipse(foot + Vector2(5, -2), Vector2(8, 4), colour)
		_:
			draw_rect(Rect2(foot.x - 6, foot.y - 9, 12, 9), colour)
			_ellipse(foot + Vector2(5, -3), Vector2(8, 4), colour)


func _draw_neckwear(bob: float) -> void:
	var neck := _item("neckwear")
	var colour := Content.cosmetic_colour(neck, Color("#d9a441"))
	var y := -106 - bob
	match _style(neck):
		"scarf":
			draw_line(Vector2(-13, y), Vector2(13, y), colour, 7, true)
			draw_line(Vector2(8, y + 2), Vector2(12, y + 20), colour.darkened(0.1), 6, true)
		"bowtie":
			draw_colored_polygon(PackedVector2Array([Vector2(12, y + 2), Vector2(4, y - 4), Vector2(4, y + 8)]), colour)
			draw_colored_polygon(PackedVector2Array([Vector2(12, y + 2), Vector2(20, y - 4), Vector2(20, y + 8)]), colour)
			draw_circle(Vector2(12, y + 2), 2.5, colour.darkened(0.2), true, -1.0, true)
		"necklace":
			draw_arc(Vector2(3, y - 3), 11, 0.35, PI - 0.35, 12, Color("#d8c27a"), 1.6, true)
			draw_circle(Vector2(5, y + 8), 3.5, colour, true, -1.0, true)
		"collar":
			draw_line(Vector2(-13, y + 1), Vector2(13, y + 1), colour, 5, true)
			draw_circle(Vector2(9, y + 6), 3, colour.lightened(0.3), true, -1.0, true)


func _draw_head(h: Vector2, skin: Color, hair_tone: Color) -> void:
	var hair := _item("hair")
	var hair_colour := Content.cosmetic_colour(hair, hair_tone) if hair.has("rarity") else hair_tone
	var style := _style(hair)
	if style == "long":
		draw_rect(Rect2(h.x - 17, h.y - 6, 17, 30), hair_colour)
	draw_circle(h, 16, skin, true, -1.0, true)
	draw_circle(h + Vector2(-3, 2), 4, skin.darkened(0.08), true, -1.0, true)
	_draw_face(h)
	match style:
		"buzz":
			draw_arc(h, 15, PI * 1.02, TAU * 0.99, 16, hair_colour, 4, true)
		"curly":
			for i in 8:
				var a := PI + PI * i / 7.0
				draw_circle(h + Vector2(cos(a), sin(a)) * 14.5, 6.5, hair_colour, true, -1.0, true)
		"bun":
			draw_arc(h, 12, PI, TAU, 16, hair_colour, 9, true)
			draw_circle(h + Vector2(-9, -17), 7, hair_colour, true, -1.0, true)
		_:
			draw_arc(h, 12, PI, TAU, 16, hair_colour, 9, true)
			draw_circle(h + Vector2(11, -9), 4.5, hair_colour, true, -1.0, true)
	_draw_hat(h)


func _draw_face(h: Vector2) -> void:
	var face := _item("face")
	var eye := h + Vector2(8, -2)
	draw_circle(eye, 2.2, UI.INK, true, -1.0, true)
	if sad > 0.5:
		# A sad brow, a frown and, glasses aside, nothing else.
		draw_line(eye + Vector2(-4, -3.5), eye + Vector2(3, -5.5), UI.INK, 1.4, true)
		draw_arc(h + Vector2(8, 10), 3.5, PI + 0.6, TAU - 0.2, 8, UI.INK, 1.6, true)
		if _style(face) == "glasses":
			draw_arc(eye, 5, 0, TAU, 16, UI.INK, 1.6, true)
			draw_line(eye + Vector2(-5, 0), h + Vector2(-4, 0), UI.INK, 1.4, true)
		return
	match _style(face):
		"grin":
			draw_arc(h + Vector2(8, 4), 5, 0.1, PI - 0.4, 10, UI.INK, 2.0, true)
		"glasses":
			draw_arc(eye, 5, 0, TAU, 16, UI.INK, 1.6, true)
			draw_line(eye + Vector2(-5, 0), h + Vector2(-4, 0), UI.INK, 1.4, true)
			draw_arc(h + Vector2(8, 6), 3.5, 0.2, PI - 0.6, 8, UI.INK, 1.6, true)
		"freckles":
			for p in [Vector2(11, 3), Vector2(13.5, 1), Vector2(9, 4.5)]:
				draw_circle(h + p, 0.9, Color("#a0643c"), true, -1.0, true)
			draw_arc(h + Vector2(8, 6), 3.5, 0.2, PI - 0.6, 8, UI.INK, 1.6, true)
		_:
			draw_arc(h + Vector2(8, 6), 3.5, 0.2, PI - 0.6, 8, UI.INK, 1.6, true)


func _draw_hat(h: Vector2) -> void:
	var hat := _item("hat")
	var c := Content.cosmetic_colour(hat, Color("#c2563f"))
	match _style(hat):
		"beanie", "feather_cap", "ears":
			_cap_dome(h, c)
			draw_rect(Rect2(h.x - 17, h.y - 7, 34, 5), c.darkened(0.15))
			if _style(hat) == "beanie":
				draw_circle(h + Vector2(0, -22), 4, c.lightened(0.25), true, -1.0, true)
			elif _style(hat) == "feather_cap":
				draw_line(h + Vector2(-8, -12), h + Vector2(-22, -32), Color("#f4efe2"), 3, true)
			else:
				draw_colored_polygon(PackedVector2Array([h + Vector2(-13, -12), h + Vector2(-10, -28), h + Vector2(-3, -16)]), c)
				draw_colored_polygon(PackedVector2Array([h + Vector2(3, -16), h + Vector2(10, -28), h + Vector2(13, -12)]), c)
		"cap":
			_cap_dome(h, c)
			draw_rect(Rect2(h.x + 4, h.y - 9, 20, 4), c.darkened(0.2))
		"crown":
			for i in 5:
				var a := PI * 1.1 + PI * 0.8 * i / 4.0
				var p := h + Vector2(cos(a), sin(a)) * 15.0
				draw_circle(p, 5, c, true, -1.0, true)
				draw_circle(p, 2, Color("#6b4a1e"), true, -1.0, true)
		"alpine":
			draw_colored_polygon(PackedVector2Array([h + Vector2(-14, -13), h + Vector2(-9, -29), h + Vector2(9, -29), h + Vector2(14, -13)]), c)
			draw_rect(Rect2(h.x - 20, h.y - 15, 40, 4), c.darkened(0.2))
			draw_line(h + Vector2(8, -18), h + Vector2(16, -36), Color("#3d6b45"), 3, true)
		"witch":
			draw_rect(Rect2(h.x - 22, h.y - 15, 44, 4), c.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([h + Vector2(-12, -14), h + Vector2(6, -48), h + Vector2(12, -14)]), c)
		"bunny_ears":
			_ellipse(h + Vector2(-6, -30), Vector2(4.5, 13), c, -0.15)
			_ellipse(h + Vector2(5, -31), Vector2(4.5, 13), c, 0.12)
			draw_arc(h, 15, PI * 1.1, TAU * 0.95, 16, c.darkened(0.2), 4, true)
		"nest":
			_ellipse(h + Vector2(0, -17), Vector2(17, 6), Color("#8a6a45"))
			draw_circle(h + Vector2(-4, -22), 3.5, Color("#cfe4ef"), true, -1.0, true)
			draw_circle(h + Vector2(4, -22), 3.5, Color("#cfe4ef"), true, -1.0, true)
			draw_line(h + Vector2(-16, -16), h + Vector2(16, -19), Color("#6b4f33"), 1.5, true)
		"pot":
			var pot := UI.box(c, Color.TRANSPARENT, 6)
			draw_style_box(pot, Rect2(h.x - 12, h.y - 36, 24, 22))
			draw_rect(Rect2(h.x - 14, h.y - 38, 28, 5), c.darkened(0.25))
			draw_circle(h + Vector2(8, -14), 3, c.lightened(0.2), true, -1.0, true)
		"tophat":
			draw_rect(Rect2(h.x - 20, h.y - 16, 40, 5), c)
			draw_rect(Rect2(h.x - 12, h.y - 34, 24, 18), c)


func _cap_dome(h: Vector2, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(h + Vector2(0, -4) + Vector2(cos(a), sin(a)) * 17.0)
	draw_colored_polygon(pts, c)


func _ellipse(centre: Vector2, radius: Vector2, colour: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(angle))
	draw_colored_polygon(pts, colour)
