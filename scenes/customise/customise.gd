class_name Customise
extends RefCounted
## The character editor popup, as in the original app: a preview on the left
## and a row per part on the right (hat, hair, face, neckwear, top, gloves,
## walking stick, trousers, shoes, then skin and hair colour), each showing
## a little picture of what's chosen and stepped through with left and right
## arrows. The title and the preview stay put while the parts scroll. The
## cross top left throws the changes away; the green tick top right keeps them.


static func open() -> Modal:
	var p := App.state.profile
	var draft := {
		"skin_tone": int(p["skin_tone"]),
		"hair_tone": int(p["hair_tone"]),
		"cosmetics": (p["cosmetics"] as Dictionary).duplicate(),
	}
	var m := Modal.open(620, false, 20)

	# The title and the preview stay put; only the list of parts scrolls.
	var top := UI.hbox(10)
	top.add_child(UI.round_button("close", Text.t("common.cancel"), m.close.bind(null), UI.SURFACE_SOFT, UI.INK, 44, false))
	var title := UI.label(Text.t("customise.title"), 22, UI.INK, true, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UI.round_button("check", Text.t("common.save"), func():
		App.set_look(draft)
		m.close(true), UI.SUCCESS, Color.WHITE, 44))
	m.header.add_child(top)

	var narrow := m.get_viewport_rect().size.x < 520.0
	var row := UI.hbox(12 if narrow else 20)
	m.body.add_child(row)
	var preview := UI.character_portrait(draft, Vector2(118 if narrow else 210, 0))
	preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(preview)
	var view: CharacterView = preview.get_child(0)

	var list := UI.scroll_area()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(list)
	var room := MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(room)
	UI.clear_of_bar(list, room, 8)
	var rows := UI.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.add_child(rows)
	var minis: Array[Mini] = []
	for slot in Content.cosmetic_slots:
		var slot_id: String = slot["id"]
		var options := Content.cosmetic_options(slot_id, App.state.inventory)
		var mini := Mini.new(draft, slot_id)
		minis.append(mini)
		rows.add_child(_stepper(slot["name"], mini, func(step: int):
			var i := options.find(_current(draft, slot_id, options))
			draft["cosmetics"][slot_id] = options[posmod(i + step, options.size())]["id"]
			view.refresh()))
	var skin := Mini.new(draft, "skin")
	rows.add_child(_stepper(Text.t("customise.skin"), skin, func(step: int):
		draft["skin_tone"] = posmod(int(draft["skin_tone"]) + step, Content.skin_tones.size())
		view.refresh()
		for mini in minis:
			mini.refresh()))
	var hair := Mini.new(draft, "hair_tone")
	rows.add_child(_stepper(Text.t("customise.hair"), hair, func(step: int):
		draft["hair_tone"] = posmod(int(draft["hair_tone"]) + step, Content.hair_tones.size())
		view.refresh()
		for mini in minis:
			mini.refresh()))

	# As tall as the popup allows without the whole body scrolling, up to
	# the height of every part. The preview stops at a height its width suits.
	var fit := func():
		row.custom_minimum_size.y = minf(rows.get_combined_minimum_size().y, m.room())
		preview.custom_minimum_size.y = minf(row.custom_minimum_size.y, 300.0 if narrow else 440.0)
	m.resized.connect(fit)
	fit.call()
	return m


## What's worn in a slot in the draft, falling back to the slot's first option.
static func _current(draft: Dictionary, slot: String, options: Array) -> Dictionary:
	var id := str(draft["cosmetics"].get(slot, ""))
	for o in options:
		if o["id"] == id:
			return o
	return options[0] if not options.is_empty() else {}


## One row: the part's name, then ‹ [a little picture of the choice] ›.
static func _stepper(title: String, mini: Mini, step: Callable) -> Control:
	var v := UI.vbox(2)
	var cap := UI.caption(title)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var h := UI.hbox(6)
	mini.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var move := func(d: int):
		step.call(d)
		mini.refresh()
		Motion.pop(mini, 0.08, 0.25)
	h.add_child(UI.round_button("back", Text.t("customise.previous", {"option": title.to_lower()}), move.bind(-1), UI.SURFACE_SOFT, UI.INK, 34, false))
	h.add_child(mini)
	h.add_child(UI.round_button("forward", Text.t("customise.next", {"option": title.to_lower()}), move.bind(1), UI.SURFACE_SOFT, UI.INK, 34, false))
	v.add_child(h)
	return v


## A little picture of what's chosen for one part: the item on its own, a
## crossed-out circle when it's nothing, or a swatch for skin ("skin") and
## hair colour ("hair_tone"). Its accessibility name says what it is.
class Mini extends Control:
	const SIZE := Vector2(96, 44)
	var _draft: Dictionary
	var _slot: String
	var _view := CharacterView.new()

	func _init(draft: Dictionary, slot: String) -> void:
		_draft = draft
		_slot = slot
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.look = draft
		_view.holding_lead = false
		if slot != "skin" and slot != "hair_tone":
			_view.part = slot
			add_child(_view)
		resized.connect(refresh)

	func refresh() -> void:
		pivot_offset = size * 0.5
		if _view.part != "":
			var item := _item()
			accessibility_name = str(item.get("name", ""))
			_view.visible = str(item.get("style", "none")) != "none" or _slot == "gloves"
			var r := CharacterView.part_rect(_slot, item)
			# Fit the box, but small things (gloves, shoes) stop at half as big
			# again as on the character, so they don't turn into blobs.
			var s := minf(1.5, minf(SIZE.x / r.size.x, size.y / r.size.y))
			_view.scale = Vector2(s, s)
			_view.position = size * 0.5 - r.get_center() * s
			_view.refresh()
		elif _slot == "skin":
			accessibility_name = Text.t("customise.skin_option", {"n": int(_draft["skin_tone"]) + 1})
		else:
			accessibility_name = Text.t("customise.hair_option", {"n": int(_draft["hair_tone"]) + 1})
		queue_redraw()

	func _item() -> Dictionary:
		var id := str(_draft["cosmetics"].get(_slot, ""))
		var item := Content.cosmetic(id) if id != "" else {}
		return item if not item.is_empty() else Content.default_cosmetic(_slot)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.y * 0.42
		match _slot:
			"skin", "hair_tone":
				var tones: Array = Content.skin_tones if _slot == "skin" else Content.hair_tones
				var i := clampi(int(_draft["skin_tone" if _slot == "skin" else "hair_tone"]), 0, tones.size() - 1)
				draw_circle(c, r, tones[i], true, -1.0, true)
				draw_arc(c, r, 0, TAU, 40, UI.LINE, 2.0, true)
			_:
				if not _view.visible:
					# Nothing worn here: a crossed-out circle.
					draw_arc(c, r * 0.8, 0, TAU, 40, UI.INK_FAINT, 2.5, true)
					var d := Vector2(r, -r) * 0.8 * 0.7071
					draw_line(c - d, c + d, UI.INK_FAINT, 2.5, true)
