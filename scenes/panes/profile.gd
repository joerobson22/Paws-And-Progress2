extends Pane
## Your profile, above the focus screen. One card at the top: your
## character head to toe on the left (the pencil changes how they look),
## with your level badge in the bottom left and your XP filling a bar along
## the bottom (tap the badge for everything levelling up unlocks). On the
## right, your details at the top and your gift shelf at the bottom, with a
## pencil to arrange it. Under the card, as many of your best achievements
## as fit; "See all" lists every one. It all fits the screen without scrolling. The
## gear in the top right opens the settings.


func build() -> void:
	var col := frame(720, 14)
	var head := title_row(Text.t("profile.title"))
	head.add_child(UI.round_button("gear", Text.t("settings.title"), open_settings, UI.SURFACE, UI.INK, 44))
	col.add_child(head)

	var me := UI.card(UI.SURFACE, 14)
	# On a tall screen the card and the achievements share the spare room:
	# the character grows, and more medals fit.
	me.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := UI.hbox(22 if wide else 14)
	me.add_child(body)
	col.add_child(me)
	body.add_child(_figure())
	var side := UI.vbox(8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_details())
	side.add_child(UI.spacer(true))
	side.add_child(_shelf())
	body.add_child(side)

	col.add_child(_achievements())


## The character, with a pencil in the corner to change how they look. Your
## level badge sits in the bottom left with your XP filling a bar along the
## bottom; the badge shines under the pointer, and tapping it shows every
## reward levelling up brings. It's as tall as the card.
func _figure() -> Control:
	var figure := UI.character_portrait({}, Vector2(220 if wide else 128, 0), false, UI.ACCENT_SOFT, 48.0)
	var pencil := UI.round_button("edit", Text.t("profile.customise"), Customise.open, UI.SURFACE, UI.INK, 34)
	figure.add_child(pencil)

	var level := LevelBar.new(App.xp(), false, false)
	figure.add_child(level)
	var badge := level.badge()
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Cursor.HOVER
	badge.accessibility_name = Text.t("profile.levels")
	Press.attach(badge).tapped.connect(open_rewards)
	var shine := Glint.new(0.5)
	badge.add_child(shine)
	badge.mouse_entered.connect(shine.shine)
	figure.resized.connect(func():
		pencil.size = pencil.get_combined_minimum_size()
		pencil.position = Vector2(figure.size.x - pencil.size.x - 8, 8)
		level.size = Vector2(figure.size.x - 16, level.get_combined_minimum_size().y)
		level.position = Vector2(8, figure.size.y - level.size.y - 8))
	return figure


## Your name, where you study and when you joined: small, at the top.
func _details() -> Control:
	var p := App.state.profile
	var username := str(p.get("username", ""))
	var school := str(p.get("institution", ""))
	var joined := int(p.get("created_unix", 0))
	return ProfileCard.details([
		ProfileCard.field(Text.t("profile.username"), username if username != "" else Text.t("profile.username_empty"), username == "",
			_edit.bind("username", Text.t("profile.username_prompt"), Text.t("profile.username_placeholder"), 24)),
		ProfileCard.field(Text.t("profile.school"), school if school != "" else Text.t("profile.school_empty"), school == "",
			_edit.bind("institution", Text.t("profile.school_prompt"), Text.t("profile.school_placeholder"), 60)),
		ProfileCard.field(Text.t("profile.joined"), Stats.format_date(joined, App.tz_bias()) if joined > 0 else Text.t("profile.joined_today")),
	])


## Your gift shelf, along the bottom of the card, with a pencil that opens
## the shelf editor. The gifts here are only to look at.
func _shelf() -> Control:
	return ProfileCard.shelf(GiftShelf.new(GiftShelf.mine(), 66.0 if wide else 60.0), ShelfEditor.open)


func _edit(key: String, title: String, placeholder: String, max_length: int) -> void:
	Modal.prompt(title, str(App.state.profile.get(key, "")), placeholder, max_length).closed.connect(func(text):
		if text is String:
			App.set_profile(key, text))


## Every achievement with how far along you are, in order: the hours
## focused, then every gift, then each animal's set.
static func achievement_rows() -> Array:
	var p := App.state.profile
	var focused := Stats.total_seconds(App.state.sessions) + int(p.get("legacy_total_seconds", 0))
	return Achievements.progress(Achievements.list(Content.achievements, Content.animals, Content.gifts),
		focused, App.state.inventory.keys(), Content.gifts)


## The achievements under the card: a heading with how many you have, then
## your best medals filling the rest of the screen, ending in "See all".
func _achievements() -> Control:
	var rows := achievement_rows()
	var section := UI.vbox(8)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(ProfileCard.achievements_head(rows))
	var medals := MedalCard.new(rows)
	medals.shrank.connect(func(): section.size_flags_vertical = Control.SIZE_FILL)
	section.add_child(medals)
	return section


# --- Settings ----------------------------------------------------------------

func open_settings() -> void:
	var m := Modal.open(480)
	m.body.add_child(m.heading_row(Text.t("settings.title")))
	var s := UI.vbox(10)
	s.add_child(_toggle(Text.t("settings.sound"), Text.t("settings.sound_note"), "sound"))
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.ambience"), Text.t("settings.ambience_note"), "ambience"))
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.reduce_motion"), Text.t("settings.reduce_motion_note"), "reduce_motion"))
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.keep_screen_on"), Text.t("settings.keep_screen_on_note"), "keep_screen_on"))
	s.add_child(UI.divider())
	s.add_child(_location_toggle())
	for row in Display.settings_rows(get_window()):
		s.add_child(UI.divider())
		s.add_child(row)
	m.body.add_child(s)
	var about := UI.para(Text.t("settings.about", {"version": ProjectSettings.get_setting("application/config/version", "")}), 13, UI.INK_FAINT)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.body.add_child(about)


func _toggle(title: String, detail: String, key: String) -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 16, UI.INK, false, 800))
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	var sw := Switch.new(bool(App.state.settings.get(key, false)))
	sw.accessibility_name = title
	sw.toggled.connect(func(on: bool):
		App.set_setting(key, on)
		if key == "ambience":
			Audio.refresh(Audio.current_ambience()))
	row.add_child(sw)
	return row


## Real sunrise, sunset and weather: on and off goes through Outdoors, which
## also says where it thinks you are once it knows.
func _location_toggle() -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(Text.t("settings.weather"), 16, UI.INK, false, 800))
	var detail := Text.t("settings.weather_note")
	if Outdoors.place_name() != "":
		detail += " " + Text.t("settings.weather_now", {"place": Outdoors.place_name(), "weather": Weather.look(Outdoors.weather(), Content.weathers)["name"].to_lower()})
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	var sw := Switch.new(Outdoors.enabled())
	sw.accessibility_name = Text.t("settings.weather")
	sw.toggled.connect(Outdoors.set_enabled)
	row.add_child(sw)
	return row


# --- Rewards -----------------------------------------------------------------

## Everything levelling up unlocks, in order, with a line down the left
## filled to where you are now. The title and your level stay at the top
## while the rewards scroll, and it opens scrolled to where you are.
func open_rewards() -> void:
	var table := Content.levels
	var xp := App.xp()
	var p := Levels.progress(xp, table)
	# Where you are, as a level with a fraction: 7.4 is 40% of the way to 8.
	var at := float(p["level"]) + float(p["into"]) / maxf(1.0, float(p["needed"]))
	var m := Modal.open(460)
	# The title and where you are stay put; only the rewards scroll.
	m.header.add_child(m.heading_row(Text.t("rewards.title")))
	var head := UI.hbox(12)
	head.add_child(UI.level_badge(p["level"], 44))
	var words := UI.vbox(0)
	words.add_child(UI.label(Text.t("rewards.level", {"level": p["level"]}), 18, UI.INK, true, 600))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UI.para(Text.t("rewards.to_next", {"xp": int(p["needed"]) - int(p["into"]), "level": int(p["level"]) + 1}), 13, UI.INK_SOFT, 700))
	head.add_child(words)
	m.header.add_child(head)

	var rows := _reward_list()
	var list := UI.vbox(0)
	# The first reward still to come: just past where you are on the line.
	var here: Control = null
	for i in rows.size():
		var before: int = rows[i - 1]["level"] if i > 0 else 1
		var after: int = rows[i + 1]["level"] if i + 1 < rows.size() else rows[i]["level"] + 1
		var row := _reward_row(rows[i], before, after, at)
		list.add_child(row)
		if here == null and float(rows[i]["level"]) > at:
			here = row
	m.body.add_child(list)
	m.scroll_to(here if here else list.get_child(list.get_child_count() - 1))


## Level 1's animals and places first, then each reward in level order.
func _reward_list() -> Array:
	var out: Array = []
	for b in Content.biomes:
		if Levels.unlock_level("place", b["id"], Content.levels) == 1:
			out.append({"level": 1, "type": "place", "id": b["id"]})
	for a in Content.animals:
		if Levels.unlock_level("animal", a["id"], Content.levels) == 1:
			out.append({"level": 1, "type": "animal", "id": a["id"]})
	out.append_array(Levels.rewards(Content.levels))
	return out


func _reward_row(r: Dictionary, before: int, after: int, at: float) -> Control:
	var level: int = r["level"]
	var open := at >= level
	var row := UI.hbox(12)
	row.custom_minimum_size.y = 72
	var track := _Track.new()
	track.custom_minimum_size.x = 22
	# How full the line is above this row's dot (coming from the row before)
	# and below it (going on to the next).
	track.above = 1.0 if before == level else clampf((at - before) / float(level - before) * 2.0 - 1.0, 0.0, 1.0)
	track.below = 1.0 if after == level else clampf((at - level) / float(after - level) * 2.0, 0.0, 1.0)
	track.reached = open
	row.add_child(track)

	var icon: Control
	var title := ""
	if r["type"] == "place":
		var b := Content.biome(r["id"])
		title = b.get("name", "")
		icon = UI.panel(_place_colour(b), 16, 0)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.add_child(UI.icon_rect(str(b.get("icon", "place_lake")), 28, Color.WHITE))
	else:
		title = Content.animal(r["id"]).get("name", "")
		icon = UI.animal_portrait(r["id"], Content.animal_default_colours(r["id"]), Vector2(56, 56))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate.a = 1.0 if open else 0.45
	row.add_child(icon)

	var words := UI.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UI.trimmed(title, 17, UI.INK if open else UI.INK_SOFT, false, 800))
	var when := Text.t("rewards.new_place" if r["type"] == "place" else "rewards.new_animal", {"when": Text.t("rewards.from_start") if level == 1 else Text.t("rewards.level", {"level": level})})
	words.add_child(UI.label(when, 13, UI.INK_FAINT, false, 700))
	row.add_child(words)
	if not open:
		row.add_child(UI.icon_rect("lock", 16, UI.INK_FAINT))
	return row


## A place's tile colour: its ground, a little darker so a white icon shows.
static func _place_colour(b: Dictionary) -> Color:
	for layer in b.get("layers", []):
		if layer["kind"] == "ground":
			return Color.from_string(layer["colour"], UI.ACCENT).darkened(0.3)
	return UI.ACCENT


## One row's piece of the progress line, with its dot.
class _Track extends Control:
	var above := 0.0
	var below := 0.0
	var reached := false

	func _draw() -> void:
		var x := size.x * 0.5
		var mid := size.y * 0.5
		var w := 4.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), UI.LINE, w)
		if above > 0.0:
			draw_line(Vector2(x, 0), Vector2(x, mid * above), UI.ACCENT, w)
		if below > 0.0:
			draw_line(Vector2(x, mid), Vector2(x, mid + mid * below), UI.ACCENT, w)
		draw_circle(Vector2(x, mid), 8.0, UI.ACCENT if reached else UI.SURFACE, true, -1.0, true)
		draw_arc(Vector2(x, mid), 8.0, 0, TAU, 24, UI.ACCENT if reached else UI.LINE, 3.0, true)
