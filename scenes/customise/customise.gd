class_name Customise
extends RefCounted
## The character editor popup, as in the original app: a preview on the left
## and a row per part on the right (hat, hair, face, neckwear, top, gloves,
## walking stick, trousers, shoes, then skin and hair colour), each stepped
## through with left and right arrows. The cross top left throws the changes
## away; the green tick top right keeps them.


static func open() -> Modal:
	var p := App.state.profile
	var draft := {
		"skin_tone": int(p["skin_tone"]),
		"hair_tone": int(p["hair_tone"]),
		"cosmetics": (p["cosmetics"] as Dictionary).duplicate(),
	}
	var m := Modal.open(620, false, 20)

	var top := UI.hbox(10)
	top.add_child(UI.round_button("close", "Cancel", m.close.bind(null), UI.SURFACE_SOFT, UI.INK, 44, false))
	var title := UI.label("Customise", 22, UI.INK, true, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UI.round_button("check", "Save", func():
		App.set_look(draft)
		m.close(true), UI.SUCCESS, Color.WHITE, 44))
	m.body.add_child(top)

	var narrow := m.get_viewport_rect().size.x < 520.0
	var row := UI.hbox(12 if narrow else 20)
	m.body.add_child(row)
	var preview := UI.character_portrait(draft, Vector2(118 if narrow else 210, 300 if narrow else 380))
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preview)
	var view: CharacterView = preview.get_child(0)

	var rows := UI.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rows)
	for slot in Content.cosmetic_slots:
		var slot_id: String = slot["id"]
		var options := Content.cosmetic_options(slot_id, App.state.inventory)
		rows.add_child(_stepper(slot["name"],
			func() -> String:
				var item := _current(draft, slot_id, options)
				return item.get("name", ""),
			func(step: int):
				var i := options.find(_current(draft, slot_id, options))
				draft["cosmetics"][slot_id] = options[posmod(i + step, options.size())]["id"]
				view.refresh()))
	rows.add_child(_stepper("Skin",
		func() -> String: return "Tone %d" % (int(draft["skin_tone"]) + 1),
		func(step: int):
			draft["skin_tone"] = posmod(int(draft["skin_tone"]) + step, Content.skin_tones.size())
			view.refresh()))
	rows.add_child(_stepper("Hair colour",
		func() -> String: return "Shade %d" % (int(draft["hair_tone"]) + 1),
		func(step: int):
			draft["hair_tone"] = posmod(int(draft["hair_tone"]) + step, Content.hair_tones.size())
			view.refresh()))
	return m


## What's worn in a slot in the draft, falling back to the slot's first option.
static func _current(draft: Dictionary, slot: String, options: Array) -> Dictionary:
	var id := str(draft["cosmetics"].get(slot, ""))
	for o in options:
		if o["id"] == id:
			return o
	return options[0] if not options.is_empty() else {}


## One row: ‹ [part / current choice] ›.
static func _stepper(title: String, current: Callable, step: Callable) -> Control:
	var h := UI.hbox(6)
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap := UI.caption(title)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_child(cap)
	var value := UI.trimmed(current.call(), 15, UI.INK, false, 800)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_child(value)
	var move := func(d: int):
		step.call(d)
		value.text = current.call()
		Motion.pop(value, 0.08, 0.25)
	h.add_child(UI.round_button("back", "Previous %s" % title.to_lower(), move.bind(-1), UI.SURFACE_SOFT, UI.INK, 34, false))
	h.add_child(text)
	h.add_child(UI.round_button("forward", "Next %s" % title.to_lower(), move.bind(1), UI.SURFACE_SOFT, UI.INK, 34, false))
	return h
