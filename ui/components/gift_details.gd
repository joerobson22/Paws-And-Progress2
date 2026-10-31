class_name GiftDetails
extends RefCounted
## A closer look at one gift, in a popup: its picture, rarity, which animal
## it's from and how many you have. Opened after a trade for the gift it
## brought, and from a friend's shelf (just to look at: no count). Trading
## in happens on the gifts screen itself (GiftTile, GiftInfo).


## `fresh` celebrates a gift that's just arrived from a trade. `yours` off
## leaves out how many you have, for a friend's gift.
static func open(id: String, fresh: bool = false, yours: bool = true) -> void:
	var g := Content.gift(id)
	if g.is_empty():
		return
	var count := App.state.gift_count(id)
	var rarity: String = g["rarity"]
	var m := Modal.open(400)
	m.body.add_child(m.heading_row(g["name"]))
	var art := GiftArt.new(id, 1.0)
	art.custom_minimum_size = Vector2(0, 170)
	m.body.add_child(art)
	if fresh:
		Audio.play("trade_new_gift", 1.0, -4.0, "chime")
		art.get_tree().create_timer(Motion.time(Motion.NORMAL)).timeout.connect(func():
			if is_instance_valid(art):
				Motion.pop(art, 0.2, 0.5))

	var meta := UI.hbox(8)
	meta.add_child(UI.tag(Content.rarity_name(rarity).to_upper(), Content.rarity_colour(rarity), UI.ON_COLOUR))
	var table_name: String = Content.table(g["table"]).get("name", "")
	meta.add_child(UI.label(Text.t("gift.from", {"table": table_name.to_lower()}), 14, UI.INK_SOFT, false, 700))
	if fresh:
		meta.add_child(UI.spacer())
		meta.add_child(UI.tag(Text.t("gift.new"), UI.INK, UI.BG))
	m.body.add_child(meta)
	m.body.add_child(UI.para(g.get("description", ""), 16, UI.INK))
	if not yours:
		return
	if g.has("slot"):
		m.body.add_child(UI.para(Text.t("gift.wearable", {"slot": Content.slot_name(g["slot"]).to_lower()}), 14))
	m.body.add_child(UI.label(Text.t("gift.you_have", {"n": count}), 15, UI.INK_SOFT, false, 800))
