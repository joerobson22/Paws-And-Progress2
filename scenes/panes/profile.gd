extends Pane
## Your profile, above the focus screen. At the top: your character head to
## toe (the pencil changes how they look) with your level badge in the
## bottom left and your XP filling a bar along the bottom (tap the badge for
## everything levelling up unlocks), your account details and a few lifetime
## numbers. At the bottom: your achievements. The gear in the top left opens
## the settings.


func build() -> void:
	var col := page(720, 16, true)
	var head := UI.title_row("Profile")
	var gear := UI.round_button("gear", "Settings", open_settings, UI.SURFACE, UI.INK, 44)
	head.add_child(gear)
	head.move_child(gear, 0)
	col.add_child(head)
	var p := App.state.profile

	var me := UI.card(UI.SURFACE, 18)
	var body: BoxContainer
	if wide:
		body = UI.hbox(24)
	else:
		body = UI.vbox(12)
	me.add_child(body)
	col.add_child(me)
	body.add_child(_figure())

	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var username := str(p.get("username", ""))
	info.add_child(_field("Username", username if username != "" else "Add your name", username == "",
		_edit.bind("username", "Your name", "What should we call you?", 24)))
	info.add_child(UI.divider())
	var school := str(p.get("institution", ""))
	info.add_child(_field("School, college or university", school if school != "" else "Add where you study", school == "",
		_edit.bind("institution", "Where do you study?", "e.g. University of Leeds", 60)))
	info.add_child(UI.divider())
	var joined := int(p.get("created_unix", 0))
	info.add_child(_field("Joined", Stats.format_date(joined, App.tz_bias()) if joined > 0 else "Today", false, Callable()))
	body.add_child(info)

	var numbers := GridContainer.new()
	numbers.columns = 3
	# Snug on a phone, so "Completed" and its icon fit side by side.
	var narrow := col.custom_minimum_size.x < 420.0
	numbers.add_theme_constant_override("h_separation", 8 if narrow else 12)
	var all_time := Stats.total_seconds(App.state.sessions) + int(p.get("legacy_total_seconds", 0))
	var gifts := 0
	for n in App.state.inventory.values():
		gifts += int(n)
	numbers.add_child(_number("Focused", Stats.format_duration(all_time), "clock", narrow))
	numbers.add_child(_number("Gifts", str(gifts), "gift", narrow))
	numbers.add_child(_number("Completed", str(App.state.completed_projects().size()), "check", narrow))
	col.add_child(numbers)

	# The details above stay at the top; the achievements sit at the bottom.
	col.add_child(UI.spacer(true))
	col.add_child(_achievements(all_time, col.custom_minimum_size.x))


## The character, with a pencil in the corner to change how they look. Your
## level badge sits in the bottom left with your XP filling a bar along the
## bottom; the badge shines under the pointer, and tapping it shows every
## reward levelling up brings.
func _figure() -> Control:
	var figure := UI.character_portrait({}, Vector2(230 if wide else 0, 300 if wide else 250), false, UI.ACCENT_SOFT, 48.0)
	var pencil := UI.round_button("edit", "Customise your character", Customise.open, UI.SURFACE, UI.INK, 36)
	figure.add_child(pencil)

	var level := LevelBar.new(App.xp(), false, false)
	figure.add_child(level)
	var badge := level.badge()
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.tooltip_text = "Levels and rewards"
	Press.attach(badge).tapped.connect(open_rewards)
	var shine := Glint.new(0.5)
	badge.add_child(shine)
	badge.mouse_entered.connect(shine.shine)
	figure.resized.connect(func():
		pencil.size = pencil.get_combined_minimum_size()
		pencil.position = Vector2(figure.size.x - pencil.size.x - 8, 8)
		level.size = Vector2(figure.size.x - 20, level.get_combined_minimum_size().y)
		level.position = Vector2(10, figure.size.y - level.size.y - 10))
	return figure


## A labelled detail; tappable to edit when `on_tap` is given.
func _field(title: String, value: String, placeholder: bool, on_tap: Callable) -> Control:
	var row := UI.hbox(10)
	row.custom_minimum_size.y = 52
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UI.caption(title))
	text.add_child(UI.trimmed(value, 18, UI.INK_FAINT if placeholder else UI.INK, false, 800))
	row.add_child(text)
	if on_tap.is_valid():
		var b := UI.round_button("edit", "Edit %s" % title.to_lower(), on_tap, UI.SURFACE_SOFT, UI.INK, 38, false)
		row.add_child(b)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		Press.attach(row).tapped.connect(on_tap)
	return row


func _edit(key: String, title: String, placeholder: String, max_length: int) -> void:
	Modal.prompt(title, str(App.state.profile.get(key, "")), placeholder, max_length).closed.connect(func(text):
		if text is String:
			App.set_profile(key, text))


## A lifetime number, with an icon in the top right saying what it counts.
func _number(title: String, value: String, icon: String, narrow: bool) -> Control:
	var card := UI.card(UI.SURFACE, 12 if narrow else 14, 20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(0)
	# The icon shares the caption's line, so the number gets the full width.
	var row := UI.hbox(4 if narrow else 6)
	var cap := UI.caption(title)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.clip_text = true
	if narrow:
		cap.add_theme_font_size_override("font_size", 11)
	row.add_child(cap)
	var mark := UI.icon_rect(icon, 14 if narrow else 16, UI.INK_FAINT)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	v.add_child(row)
	v.add_child(UI.trimmed(value, 22, UI.INK, true, 600))
	card.add_child(v)
	return card


## Every achievement as a medal: in colour once earned; grey otherwise, with
## a ring round it showing how far along you are. Tap one to see what it's for.
func _achievements(focused_seconds: int, width: float) -> Control:
	var rows := Achievements.progress(Achievements.list(Content.achievements, Content.animals, Content.gifts),
		focused_seconds, App.state.inventory.keys(), Content.gifts)
	var section := UI.vbox(10)
	var head := UI.hbox(8)
	head.add_child(UI.caption("Achievements"))
	head.add_child(UI.spacer())
	head.add_child(UI.caption("%d of %d" % [rows.filter(func(r): return r["earned"]).size(), rows.size()], UI.INK_FAINT))
	section.add_child(head)
	var card := UI.card(UI.SURFACE, 16)
	var grid := GridContainer.new()
	grid.columns = clampi(int((width - 32.0) / 80.0), 4, 8)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 14)
	for r in rows:
		grid.add_child(_Medal.new(r))
	card.add_child(grid)
	section.add_child(card)
	return section


# --- Settings ----------------------------------------------------------------

func open_settings() -> void:
	var m := Modal.open(480)
	m.body.add_child(m.heading_row("Settings"))
	var s := UI.vbox(10)
	s.add_child(_toggle("Sound effects", "Taps, pops, barks and the bong.", "sound"))
	s.add_child(UI.divider())
	s.add_child(_toggle("Ambience", "Water, birdsong and wind while you walk.", "ambience"))
	s.add_child(UI.divider())
	s.add_child(_toggle("Reduce motion", "Gentler scenery and quicker, simpler animations.", "reduce_motion"))
	s.add_child(UI.divider())
	s.add_child(_toggle("Keep the screen on", "Stops your phone or laptop sleeping during a walk.", "keep_screen_on"))
	s.add_child(UI.divider())
	s.add_child(_location_toggle())
	m.body.add_child(s)
	var about := UI.para("Paws & Progress %s  ·  Fonts: Fredoka and Nunito (SIL Open Font License)" % ProjectSettings.get_setting("application/config/version", ""), 13, UI.INK_FAINT)
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
	sw.tooltip_text = title
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
	text.add_child(UI.label("Local sunrise and weather", 16, UI.INK, false, 800))
	var detail := "Walks follow the real sky where you are, from your rough location (worked out from your internet connection)."
	if Outdoors.place_name() != "":
		detail += " Now: %s, %s." % [Outdoors.place_name(), Weather.look(Outdoors.weather(), Content.weathers)["name"].to_lower()]
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	var sw := Switch.new(Outdoors.enabled())
	sw.tooltip_text = "Local sunrise and weather"
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
	m.header.add_child(m.heading_row("Rewards"))
	var head := UI.hbox(12)
	head.add_child(UI.level_badge(p["level"], 44))
	var words := UI.vbox(0)
	words.add_child(UI.label("Level %d" % p["level"], 18, UI.INK, true, 600))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UI.para("%d XP to level %d. You get 1 XP for each minute focused, and more for gifts." % [int(p["needed"]) - int(p["into"]), int(p["level"]) + 1], 13, UI.INK_SOFT, 700))
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
	var kind := "place" if r["type"] == "place" else "animal"
	var when := ("From the start" if level == 1 else "Level %d" % level) + "  ·  new " + kind
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


## One achievement: a disc with its icon (or its animal) and its name under.
class _Medal extends VBoxContainer:
	const SIZE := 52.0
	var info: Dictionary

	func _init(row: Dictionary) -> void:
		info = row
		add_theme_constant_override("separation", 4)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		var goal := int(row["goal"])
		var unit := " hours" if row["kind"] == "hours" else " gifts"
		tooltip_text = "%s\n%s (%d of %d%s)" % [row["name"], row["description"], row["have"], goal, unit]
		var disc := Control.new()
		disc.custom_minimum_size = Vector2(SIZE, SIZE)
		disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.draw.connect(_draw_disc.bind(disc))
		add_child(disc)
		if row["animal"] != "":
			var pet := AnimalView.new()
			pet.animal_id = row["animal"]
			pet.colours = Content.animal_default_colours(row["animal"])
			pet.scale = Vector2.ONE * 0.3
			pet.position = Vector2(SIZE * 0.42, SIZE * 0.78)
			pet.modulate = Color.WHITE if row["earned"] else Color(1, 1, 1, 0.35)
			disc.add_child(pet)
		else:
			var icon := UI.icon_rect(str(row["icon"]), 24, Color.WHITE if row["earned"] else UI.INK_FAINT)
			icon.position = Vector2(SIZE - 24.0, SIZE - 24.0) * 0.5
			disc.add_child(icon)
		var name_label := UI.label(row["name"], 11, UI.INK if row["earned"] else UI.INK_FAINT, false, 800)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.x = 64
		add_child(name_label)
		UI.ignore_mouse(disc)
		Press.attach(self).tapped.connect(func():
			Toast.show_text("%s: %s" % [row["name"], row["description"].to_lower()], "trophy" if row["earned"] else "lock"))

	func _draw_disc(disc: Control) -> void:
		var c := disc.size * 0.5
		var r := SIZE * 0.5
		if info["earned"]:
			var fill := UI.ACCENT
			if info["kind"] == "all_gifts":
				fill = Content.rarity_colour("legendary")
			elif info["kind"] == "animal":
				fill = Content.rarity_colour("rare").lerp(Color.WHITE, 0.55)
			disc.draw_circle(c, r, fill, true, -1.0, true)
			disc.draw_arc(c, r - 3.0, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0, true)
		else:
			disc.draw_circle(c, r, UI.SURFACE_SOFT, true, -1.0, true)
			var share := float(info["have"]) / maxf(1.0, float(info["goal"]))
			if share > 0.0:
				disc.draw_arc(c, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * share, 48, UI.ACCENT, 3.0, true)
