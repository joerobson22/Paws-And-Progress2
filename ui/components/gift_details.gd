class_name GiftDetails
extends RefCounted
## A closer look at one gift, in a popup: its picture, rarity, which animal
## it's from, how many you have and its trade-in. Opened from the gifts
## screen's collection, after a trade for the gift it brought, and from a
## friend's shelf (just to look at: no count and no trade-in).


## `fresh` celebrates a gift that's just arrived from a trade. `yours` off
## leaves out how many you have and the trade-in, for a friend's gift.
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
		Audio.play("chime", 1.0, -4.0)
		art.get_tree().create_timer(Motion.time(Motion.NORMAL)).timeout.connect(func():
			if is_instance_valid(art):
				Motion.pop(art, 0.2, 0.5))

	var meta := UI.hbox(8)
	meta.add_child(UI.tag(Content.rarity_name(rarity).to_upper(), Content.rarity_colour(rarity), UI.ON_COLOUR))
	var animal_name: String = Content.animal(g["animal"]).get("name", "")
	meta.add_child(UI.label(Text.t("gift.from", {"animal": animal_name.to_lower()}), 14, UI.INK_SOFT, false, 700))
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

	var cost := Content.trade_cost(rarity)
	var next := Content.next_rarity(rarity)
	if cost > 0 and next != "":
		var next_name := Content.rarity_name(next).to_lower()
		if count >= cost:
			var trade := UI.button(Text.t("gift.trade", {"cost": cost, "a_rarity": UI.a(next_name)}), func(): trade(m, id), "accent")
			trade.icon = Icons.texture("trade", 18, Color.WHITE)
			trade.add_theme_constant_override("h_separation", 10)
			m.body.add_child(trade)
		else:
			m.body.add_child(UI.para(Text.t("gift.trade_short", {"cost": cost, "a_rarity": UI.a(next_name), "left": cost - count}), 14, UI.INK_FAINT))
	else:
		m.body.add_child(UI.para(Text.t("gift.no_trade"), 14, UI.INK_FAINT))


## Trades the gift in from its popup `m`, then shows what it brought.
## Trading away the last of a shelf gift takes it off the shelf too.
static func trade(m: Modal, id: String) -> void:
	var new_id := App.trade_in(id)
	m.close()
	if new_id != "":
		open(new_id, true)
