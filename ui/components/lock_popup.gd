class_name LockPopup
extends RefCounted
## The popup a locked animal or place opens when tapped: what it is, what it
## takes to unlock (its rule in data/animals.json or data/biomes.json) and
## how far along you are.


static func open(type: String, id: String) -> Modal:
	var p := App.unlock_progress(type, id)
	var title := str(Content.biome(id).get("name", "") if type == "place" else Content.animal(id).get("name", ""))
	var m := Modal.open(380)
	m.body.add_child(m.heading_row(Text.t("unlock.locked_title", {"name": title})))

	var row := UI.hbox(14)
	var picture: Control
	if type == "place":
		picture = UI.place_tile(Content.biome(id), 64)
	else:
		var greys: Array[Color] = []
		for k in Content.animal(id).get("parts", []).size():
			greys.append(UI.NEUTRAL.lerp(UI.INK_FAINT, k * 0.3))
		picture = UI.animal_portrait(id, greys, Vector2(64, 64), UI.SURFACE_SOFT)
	# A padlock on a white disc over the picture's top right corner.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var badge := UI.panel(UI.SURFACE, 999, 5)
	badge.add_child(UI.icon_rect("lock", 16, UI.INK_SOFT))
	holder.add_child(badge)
	badge.position = Vector2(44, -8)
	row.add_child(holder)

	var words := UI.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var rule := UI.para(Unlocks.describe(p["rule"]), 17, UI.INK, 800)
	words.add_child(rule)
	var goal := float(p["goal"])
	words.add_child(UI.progress_line(float(p["have"]) / goal if goal > 0.0 else 0.0, UI.ACCENT, 8))
	words.add_child(UI.label(Unlocks.describe_progress(p), 14, UI.INK_SOFT, false, 700))
	row.add_child(words)
	m.body.add_child(row)
	return m
