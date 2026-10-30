class_name Podium
extends VBoxContainer
## The top three of something (a project's pets, or its places) on a little
## podium: first big in the middle, second and third smaller side by side
## under it. Each picture has a soft glow in its medal's colour behind it,
## and its name with the time under that. Fewer than three just shows the
## places there are; none says so in one muted line.

const MEDALS := [Color("#e2b33c"), Color("#aeb8c2"), Color("#c98a50")]
## Sides of the pictures: first, then second and third.
const BIG := 76.0
const SMALL := 54.0

## `rows` are {"picture": Callable(side) -> Control, "name": String,
## "time": String, "faded": bool}, most first; only the first three show.
func _init(title: String, rows: Array, empty_text: String) -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := UI.caption(title)
	add_child(cap)
	if rows.is_empty():
		add_child(UI.label(empty_text, 13, UI.INK_FAINT, false, 700))
		return
	var first := _spot(rows[0], 0, BIG)
	# As wide as the podium, so a long name has room before it's cut short.
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(first)
	if rows.size() > 1:
		var under := UI.hbox(8)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		under.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in range(1, mini(rows.size(), 3)):
			var spot := _spot(rows[i], i, SMALL)
			spot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			under.add_child(spot)
		# Second always sits on the left, so a lone second doesn't drift
		# into the middle under first.
		if rows.size() == 2:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			under.add_child(gap)
		add_child(under)


## One place on the podium: the picture with its medal glow and a numbered
## medal in the corner, then the name and the time, centred under it.
static func _spot(row: Dictionary, rank: int, side: float) -> VBoxContainer:
	var v := UI.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var medal: Color = MEDALS[rank]
	var glow := PanelContainer.new()
	var sb := UI.box(Color(medal, 0.0), Color.TRANSPARENT, roundi(side * 0.3))
	sb.shadow_color = Color(medal, 0.75)
	sb.shadow_size = 7 if rank == 0 else 5
	sb.set_content_margin_all(0)
	glow.add_theme_stylebox_override("panel", sb)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var picture: Control = (row["picture"] as Callable).call(side)
	if row.get("faded", false):
		picture.modulate = Color(1, 1, 1, 0.45)
	glow.add_child(picture)
	# The numbered medal overlaps the picture's bottom right corner.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side) if picture.custom_minimum_size == Vector2.ZERO else picture.custom_minimum_size
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var disc := UI.panel(medal, 999, 0)
	var d := 22.0 if rank == 0 else 18.0
	disc.custom_minimum_size = Vector2(d, d)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UI.label(str(rank + 1), int(d * 0.6), Color.WHITE, true, 600)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(n)
	holder.add_child(disc)
	disc.position = holder.custom_minimum_size - Vector2(d * 0.7, d * 0.7)
	v.add_child(holder)
	var name_label := UI.trimmed(str(row["name"]), 15 if rank == 0 else 13, UI.INK, false, 800)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Room for the medal under the corner before the words start.
	v.add_child(_spaced(name_label, d * 0.35))
	var time := UI.trimmed(str(row["time"]), 13 if rank == 0 else 12, UI.INK_SOFT, false, 700)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(time)
	return v


## `c` with `gap` of room above it.
static func _spaced(c: Control, gap: float) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(gap))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m


## A project's pets, most walked first, for a podium.
static func pet_rows(totals: Dictionary) -> Array:
	var out: Array = []
	for row in Stats.ranked(totals):
		var pet := App.state.pet(row[0])
		if pet == null:
			continue
		out.append({
			"picture": func(side: float) -> Control: return UI.animal_portrait(pet.animal_id, pet.colours, Vector2(side * 1.15, side)),
			"name": pet.name,
			"time": Text.t("podium.rehomed", {"time": Stats.format_duration(row[1])}) if pet.is_rehomed() else Stats.format_duration(row[1]),
			"faded": pet.is_rehomed(),
		})
	return out


## A project's places, most walked first, for a podium.
static func place_rows(totals: Dictionary) -> Array:
	var out: Array = []
	for row in Stats.ranked(totals):
		var biome := Content.biome(row[0])
		out.append({
			"picture": func(side: float) -> Control: return UI.place_tile(biome, roundi(side)),
			"name": str(biome.get("name", row[0])),
			"time": Stats.format_duration(row[1]),
		})
	return out
