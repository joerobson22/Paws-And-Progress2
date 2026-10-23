class_name Display
## The app's window on computers: its size and mode (windowed, maximised,
## fullscreen) from the settings, the smallest it can be, and the debug
## phone view, which gives the window a phone's shape. Sizes are in points,
## so a Retina screen gets the same window as an ordinary one, just sharper.
## Phones and tablets leave all of this alone.

## Window sizes on offer, in points; only those that fit the screen show.
const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900),
	Vector2i(1680, 1050), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const MODES := {
	"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
	"maximised": DisplayServer.WINDOW_MODE_MAXIMIZED,
	"fullscreen": DisplayServer.WINDOW_MODE_FULLSCREEN,
	"exclusive": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
}
const MODE_NAMES := [["windowed", "Windowed"], ["maximised", "Maximised"],
	["fullscreen", "Fullscreen"], ["exclusive", "Exclusive fullscreen"]]
## Below this (in points) the layouts would have to squash.
const MIN_SIZE := Vector2i(800, 560)
## The debug phone view's screen, in points.
const PHONE := Vector2i(390, 844)
## The phone view's window is at most this much of the screen's height.
const PHONE_SCREEN_SHARE := 0.85

## The window's mode and size before the phone view took over, to go back to.
static var _before_phone := {}


## Whether there's a window to manage: computers, with a real display.
static func managed() -> bool:
	return not OS.has_feature("mobile") and DisplayServer.get_name() != "headless"


## Physical pixels per point: Retina/iOS report it directly; Android via DPI.
static func screen_scale() -> float:
	if OS.get_name() == "Android":
		return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	return maxf(1.0, DisplayServer.screen_get_scale())


## Puts the window in the mode and size from the settings (or the phone
## view's shape), and sets how small it can go. Called at launch and when
## any of those settings change.
static func apply(window: Window) -> void:
	if not managed():
		return
	var scale := screen_scale()
	if App.debug_phone_view():
		if _before_phone.is_empty():
			_before_phone = {"mode": window.mode, "size": window.size}
		window.min_size = Vector2i.ZERO
		window.mode = Window.MODE_WINDOWED
		var screen := Vector2(DisplayServer.screen_get_usable_rect(window.current_screen).size)
		var fit := minf(1.0, screen.y * PHONE_SCREEN_SHARE / (PHONE.y * scale))
		_resize(window, Vector2i(Vector2(PHONE) * scale * fit))
		return
	window.min_size = Vector2i(Vector2(MIN_SIZE) * scale)
	if not _before_phone.is_empty():
		# Back from the phone view: the window as it was.
		var was: Dictionary = _before_phone
		_before_phone = {}
		window.mode = was["mode"]
		if was["mode"] == Window.MODE_WINDOWED:
			_resize(window, was["size"])
		return
	var mode := str(App.state.settings.get("window_mode", "windowed"))
	if MODES.has(mode) and DisplayServer.window_get_mode() != MODES[mode]:
		DisplayServer.window_set_mode(MODES[mode])
	if mode == "windowed" and App.state.settings.has("resolution"):
		var points := parse(str(App.state.settings["resolution"]))
		if points != Vector2i.ZERO:
			_resize(window, Vector2i(Vector2(points) * scale))


static func _resize(window: Window, px: Vector2i) -> void:
	if window.size == px:
		return
	var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = px
	window.position = screen.position + (screen.size - px) / 2


## "1280x720" as a size, or zero if it isn't one.
static func parse(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


static func key(points: Vector2i) -> String:
	return "%dx%d" % [points.x, points.y]


## The window sizes that fit this screen, as [[id, label], ...].
static func resolution_options(window: Window) -> Array:
	var screen := Vector2(DisplayServer.screen_get_usable_rect(window.current_screen).size) / screen_scale()
	var out := []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append([key(r), "%d × %d" % [r.x, r.y]])
	if out.is_empty():
		out.append([key(RESOLUTIONS[0]), "%d × %d" % [RESOLUTIONS[0].x, RESOLUTIONS[0].y]])
	return out


## The window's size right now, in points, as one of the options (the
## closest), so the menu shows what you see.
static func current_resolution(window: Window, options: Array) -> String:
	if App.state.settings.has("resolution") and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return str(App.state.settings["resolution"])
	var points := Vector2(window.size) / screen_scale()
	var best := str(options[0][0])
	var best_gap := INF
	for o in options:
		var gap := (Vector2(parse(o[0])) - points).length()
		if gap < best_gap:
			best_gap = gap
			best = o[0]
	return best


static func current_mode() -> String:
	var now := DisplayServer.window_get_mode()
	for id in MODES:
		if MODES[id] == now:
			return id
	return "windowed"


## The settings rows for the window: its mode, and its size. Picking a size
## goes back to a window if it was fullscreen or maximised. Computers only;
## empty on phones and in the debug phone view.
static func settings_rows(window: Window) -> Array[Control]:
	var rows: Array[Control] = []
	if OS.has_feature("mobile") or App.debug_phone_view():
		return rows
	var mode := Dropdown.new(MODE_NAMES, current_mode(), false, "", false)
	var options := resolution_options(window)
	var size := Dropdown.new(options, current_resolution(window, options), false, "", false)
	mode.chosen.connect(func(id: String, _reversed: bool): App.set_setting("window_mode", id))
	size.chosen.connect(func(id: String, _reversed: bool):
		App.state.settings["window_mode"] = "windowed"
		mode.select("windowed")
		App.set_setting("resolution", id))
	rows.append(_row("Window", "Windowed, maximised or fullscreen.", mode))
	rows.append(_row("Window size", "How big the window is when it isn't fullscreen.", size))
	return rows


static func _row(title: String, detail: String, control: Control) -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 16, UI.INK, false, 800))
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	control.accessibility_name = title
	row.add_child(control)
	return row
