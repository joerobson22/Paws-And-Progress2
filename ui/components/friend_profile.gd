class_name FriendProfile
extends RefCounted
## A friend's profile in a popup, laid out like your profile screen but
## fitting one popup: their character head to toe on the left; where they
## study, when they joined and their week on the right, with their gift
## shelf along the bottom (tap a gift for a closer look); then their best
## achievements, ending in "See all". Opened by tapping a friend's face or
## name anywhere. Tapping your own goes to your profile screen instead.


## `f` is a friend (see Friends), or the leaderboard's row for you.
static func open(f: Dictionary) -> void:
	if f.get("me", false):
		while Modal.top():
			Modal.top().close()
		App.go("profile")
		return
	var m := Modal.open(620)
	var narrow := m.get_viewport_rect().size.x < 560.0
	m.header.add_child(m.heading_row(str(f.get("name", ""))))

	var body := UI.hbox(22 if not narrow else 14)
	var figure := UI.character_portrait(f.get("look", {}), Vector2(180 if not narrow else 116, 0))
	body.add_child(figure)
	var side := UI.vbox(8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var school := str(f.get("institution", ""))
	var joined := int(f.get("joined_unix", 0))
	side.add_child(ProfileCard.details([
		ProfileCard.field(Text.t("profile.school"), school if school != "" else Text.t("friend.school_empty"), school == ""),
		ProfileCard.field(Text.t("profile.joined"), Stats.format_date(joined, App.tz_bias()) if joined > 0 else Text.t("friend.joined_unknown")),
		ProfileCard.field(Text.t("stats.this_week"), Stats.format_duration(int(f.get("weekly_seconds", 0)))),
	]))
	side.add_child(UI.spacer(true))
	var shelf := GiftShelf.new(f.get("shelf", ["", "", ""]), 60.0, func(tile: GiftTile, _i: int):
		tile.tappable = true
		tile.tapped.connect(func(id: String): GiftDetails.open(id, false, false)))
	side.add_child(ProfileCard.shelf(shelf))
	body.add_child(side)
	m.body.add_child(body)

	var rows := Achievements.progress(Achievements.list(Content.achievements, Content.animals, Content.gifts),
		int(f.get("focused_seconds", 0)), f.get("gifts", []), Content.gifts)
	var section := UI.vbox(8)
	section.add_child(ProfileCard.achievements_head(rows))
	var medals := MedalCard.new(rows, 1)
	# On the popup's white a thin outline sets the medals apart, rather than
	# a shadow the popup's edges would cut off.
	var outline: StyleBoxFlat = medals.get_theme_stylebox("panel").duplicate()
	outline.shadow_size = 0
	outline.border_color = UI.LINE
	outline.set_border_width_all(2)
	medals.add_theme_stylebox_override("panel", outline)
	section.add_child(medals)
	m.body.add_child(section)
