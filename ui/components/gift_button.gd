class_name GiftButton
extends Button
## The round button in the corner of a walk: just colour, no icon. Grey
## until a gift is earned, then it pops and turns green. From then on blue,
## purple and gold circles grow from its middle at their own pace; when one
## fills the whole button, that rarity is the least the walk will bring, and
## it pops again with a sound. Pressing it ends the walk.

const DIAMETER := 76.0

var _seconds := 0
var _level := -2  # -2 = not set yet, -1 = no gift, 0 = common ... 3 = legendary
var _fill := {}


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(func(): pivot_offset = size * 0.5)


## Updates the button for a walk this long; pops when it reaches a new rarity.
func set_seconds(seconds: int) -> void:
	_seconds = seconds
	_fill = GiftRoller.fill(seconds, Content.drop_table)
	var floor_rarity := GiftRoller.min_rarity(seconds, Content.drop_table)
	var reached := GiftRoller.RARITIES.find(floor_rarity) if floor_rarity != "" else -1
	if _level != -2 and reached > _level:
		Motion.pop(self, 0.22, 0.45)
		Audio.play("pop", 1.0 + 0.12 * maxi(reached, 0))
	_level = reached
	tooltip_text = _tip(floor_rarity)
	queue_redraw()


func level() -> int:
	return _level


func _tip(floor_rarity: String) -> String:
	if floor_rarity == "":
		return "Finish walk (no gift yet)"
	return "Finish walk: at least a %s gift" % Content.rarity_name(floor_rarity).to_lower()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.18), true, -1.0, true)
	draw_circle(c, r, UI.NEUTRAL if _level < 0 else Content.rarity_colour("common"), true, -1.0, true)
	if _level >= 0:
		# Drawn rare, epic, legendary: each slower circle sits on top of the faster one.
		for rarity in ["rare", "epic", "legendary"]:
			var f := float(_fill.get(rarity, 0.0))
			if f > 0.0:
				draw_circle(c, r * f, Content.rarity_colour(rarity), true, -1.0, true)
	draw_arc(c, r - 1.5, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	if is_hovered() or has_focus():
		draw_circle(c, r, Color(1, 1, 1, 0.08), true, -1.0, true)
