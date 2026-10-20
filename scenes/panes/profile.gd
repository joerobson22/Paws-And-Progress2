extends Pane
## Your profile, above the focus screen: your character head to toe (tap it,
## or the pencil, to change how they look) with your level badge in the
## bottom left and your XP filling a bar along the bottom (tap the badge for
## everything levelling up unlocks), your account details and a few lifetime
## numbers. The gear in the top left opens the settings. It's kept short
## enough to fit a phone screen, so swiping back down works from anywhere.


func build() -> void:
	var col := page(720, 16)
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
	numbers.add_theme_constant_override("h_separation", 12)
	var all_time := Stats.total_seconds(App.state.sessions) + int(p.get("legacy_total_seconds", 0))
	var gifts := 0
	for n in App.state.inventory.values():
		gifts += int(n)
	numbers.add_child(_number("Focused", Stats.format_duration(all_time)))
	numbers.add_child(_number("Gifts", str(gifts)))
	numbers.add_child(_number("Completed", str(App.state.completed_projects().size())))
	col.add_child(numbers)


## The character: tap it, or the pencil, to change how they look. Your
## level badge sits in the bottom left with your XP filling a bar along the
## bottom; the badge grows under the pointer, and tapping it shows every
## reward levelling up brings.
func _figure() -> Control:
	var figure := UI.character_portrait({}, Vector2(230 if wide else 0, 300 if wide else 250), false, UI.ACCENT_SOFT, 48.0)
	figure.mouse_filter = Control.MOUSE_FILTER_STOP
	figure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	figure.tooltip_text = "Customise your character"
	Press.attach(figure).tapped.connect(Customise.open)
	var pencil := UI.round_button("edit", "Customise your character", Customise.open, UI.SURFACE, UI.INK, 36)
	figure.add_child(pencil)

	var level := LevelBar.new(App.xp(), false, false)
	figure.add_child(level)
	var badge := level.badge()
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.tooltip_text = "Levels and rewards"
	Press.attach(badge).tapped.connect(open_rewards)
	badge.mouse_entered.connect(func(): Motion.to(badge, "scale", Vector2.ONE * 1.15, Motion.FAST))
	badge.mouse_exited.connect(func(): Motion.to(badge, "scale", Vector2.ONE, Motion.FAST))
	figure.resized.connect(func():
		pencil.size = pencil.get_combined_minimum_size()
		pencil.position = Vector2(figure.size.x - pencil.size.x - 8, 8)
		level.size = Vector2(figure.size.x - 20, level.get_combined_minimum_size().y)
		level.position = Vector2(10, figure.size.y - level.size.y - 10)
		badge.pivot_offset = badge.size * 0.5)
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


func _number(title: String, value: String) -> Control:
	var card := UI.card(UI.SURFACE, 14, 20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(0)
	v.add_child(UI.caption(title))
	v.add_child(UI.trimmed(value, 22, UI.INK, true, 600))
	card.add_child(v)
	return card


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
## filled to where you are now.
func open_rewards() -> void:
	var table := Content.levels
	var xp := App.xp()
	var p := Levels.progress(xp, table)
	# Where you are, as a level with a fraction: 7.4 is 40% of the way to 8.
	var at := float(p["level"]) + float(p["into"]) / maxf(1.0, float(p["needed"]))
	var m := Modal.open(460)
	m.body.add_child(m.heading_row("Rewards"))
	var head := UI.hbox(12)
	head.add_child(UI.level_badge(p["level"], 44))
	var words := UI.vbox(0)
	words.add_child(UI.label("Level %d" % p["level"], 18, UI.INK, true, 600))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UI.para("%d XP to level %d. You get 1 XP for each minute focused, and more for gifts." % [int(p["needed"]) - int(p["into"]), int(p["level"]) + 1], 13, UI.INK_SOFT, 700))
	head.add_child(words)
	m.body.add_child(head)

	var rows := _reward_list()
	var list := UI.vbox(0)
	for i in rows.size():
		var before: int = rows[i - 1]["level"] if i > 0 else 1
		var after: int = rows[i + 1]["level"] if i + 1 < rows.size() else rows[i]["level"] + 1
		list.add_child(_reward_row(rows[i], before, after, at))
	m.body.add_child(list)


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
