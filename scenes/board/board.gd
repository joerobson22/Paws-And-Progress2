extends Control
## Noticeboard: a polaroid of the animal for every finished project, pinned
## to a cork board in a wooden frame, with a grade badge where there is one.

var params := {}

const PIN_COLOURS := [Color("#d9533b"), Color("#3c7bc4"), Color("#e2a615"), Color("#2f5a3b")]
const TILTS := [-3.0, 2.0, -1.5, 2.5, -2.0, 1.0]
const BACKDROPS := [Color("#dce9d6"), Color("#f3e7d8"), Color("#e8e4ef"), Color("#d9e8f0")]


func _ready() -> void:
	Audio.ambience("cabin")
	var done := App.state.completed_projects()
	done.sort_custom(func(a, b): return a.completed_unix > b.completed_unix)
	var total := 0
	for p in done:
		total += App.state.project_seconds(p.id)

	var col := UI.page(self, 1220)
	var sub := "Finished projects get pinned here" if done.is_empty() else \
		"%d finished · %s of walks between them" % [done.size(), Stats.format_duration(total)]
	col.add_child(UI.header("Noticeboard", Callable(), sub))

	var frame := PanelContainer.new()
	var fb := UI.box(Color("#4e6b4f"), Color("#7a5634"), 28)
	fb.set_border_width_all(14)
	fb.set_content_margin_all(36)
	fb.shadow_color = Color(0.2, 0.12, 0.05, 0.3)
	fb.shadow_size = 10
	fb.shadow_offset = Vector2(0, 6)
	frame.add_theme_stylebox_override("panel", fb)
	frame.custom_minimum_size.y = 420
	col.add_child(frame)

	var flow := HFlowContainer.new()
	var wide := UI.is_wide(self)
	flow.add_theme_constant_override("h_separation", 40 if wide else 22)
	flow.add_theme_constant_override("v_separation", 44)
	frame.add_child(flow)
	for i in done.size():
		flow.add_child(_polaroid(done[i], i, wide))
	var next := _next_up()
	if next:
		flow.add_child(_placeholder(next, wide))


## Room on the board for the active project with the most time walked.
func _next_up() -> ProjectData:
	var best: ProjectData = null
	for p in App.state.active_projects():
		if best == null or App.state.project_seconds(p.id) > App.state.project_seconds(best.id):
			best = p
	return best


func _polaroid(p: ProjectData, index: int, wide: bool) -> Control:
	var w := 236.0 if wide else 150.0
	# Holder sized like the card so the tilt doesn't upset the flow layout.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, (290.0 if wide else 210.0) + (index % 2) * 20.0)

	var card := PanelContainer.new()
	var cb := UI.box(Color("#fffdf8"), Color.TRANSPARENT, 3)
	cb.content_margin_left = 12
	cb.content_margin_right = 12
	cb.content_margin_top = 12
	cb.content_margin_bottom = 16
	cb.shadow_color = Color(0, 0, 0, 0.35)
	cb.shadow_size = 12
	cb.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", cb)
	card.custom_minimum_size.x = w
	card.position = Vector2(0, (index % 2) * 20.0)
	card.rotation_degrees = TILTS[index % TILTS.size()]
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	holder.add_child(card)

	var v := UI.vbox(6)
	card.add_child(v)
	v.add_child(UI.animal_portrait(p.animal_id, p.colours, Vector2(0, 150 if wide else 96), BACKDROPS[index % BACKDROPS.size()]))
	var name := Label.new()
	name.text = p.name
	name.add_theme_font_override("font", UI.hand_font())
	name.add_theme_font_size_override("font_size", 26 if wide else 20)
	name.add_theme_color_override("font_color", UI.INK)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name)
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	var when := Time.get_datetime_dict_from_unix_time(p.completed_unix)
	var month: String = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][int(when["month"]) - 1]
	var meta := UI.para("with the %s · %s · %s %d" % [animal_name.to_lower(), Stats.format_duration(App.state.project_seconds(p.id)), month, when["year"]], 12 if not wide else 13, Color("#6b5f51"), 700)
	v.add_child(meta)

	var pin := _Pin.new()
	pin.colour = PIN_COLOURS[index % PIN_COLOURS.size()]
	pin.position = card.position + Vector2(w * 0.5, -2)
	# Pin and sticker sit on the holder: a PanelContainer would stretch them.
	var badge := _badge(p)
	holder.add_child(badge)
	holder.add_child(pin)
	var place_badge := func(): badge.position = card.position + card.size - badge.size * 0.75
	badge.resized.connect(place_badge)
	card.resized.connect(place_badge)
	return holder


## The grade, when the project has one, else a "Done!" sticker.
func _badge(p: ProjectData) -> Control:
	var b := PanelContainer.new()
	var gold := p.grade != ""
	var sb := UI.box(Color("#e2a615") if gold else UI.FOREST, Color("#fffdf8"), 999)
	sb.set_border_width_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("panel", sb)
	b.add_child(UI.label(p.grade if gold else "Done!", 14, Color("#3a2600") if gold else UI.PAPER, true, 600))
	b.rotation_degrees = 7.0
	return b


func _placeholder(p: ProjectData, wide: bool) -> Control:
	var w := 236.0 if wide else 150.0
	var box := PanelContainer.new()
	var sb := UI.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.35), 6)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(w, 250.0 if wide else 190.0)
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)
	var portrait := UI.animal_portrait(p.animal_id, p.colours, Vector2(0, 80), Color.TRANSPARENT)
	portrait.modulate.a = 0.55
	v.add_child(portrait)
	var text := UI.para("%s lands here when you finish it" % p.name, 14, Color("#e3ede2"), 800)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(text)
	return box


## Drawing pin at the top of a polaroid.
class _Pin extends Node2D:
	var colour := Color.RED

	func _draw() -> void:
		draw_circle(Vector2(0, 3), 10.0, Color(0, 0, 0, 0.3), true, -1.0, true)
		draw_circle(Vector2.ZERO, 10.0, colour, true, -1.0, true)
		draw_circle(Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.45), true, -1.0, true)
