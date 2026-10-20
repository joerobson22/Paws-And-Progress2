extends TestCase

var ui: GDScript


func _init() -> void:
	# UI leans on the autoloads, so it's loaded when the test runs rather than named.
	ui = load("res://ui/ui.gd")


func test_desktop_windows_keep_no_margins() -> void:
	# A window on a second monitor to the right of a 1512-wide laptop screen:
	# the "safe area" is that monitor's, far from the window's own corner.
	var none := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	eq(ui.insets_for(Rect2(1600, 40, 1280, 720), Rect2(1512, 25, 2560, 1415), 1280.0, false), none, "second monitor")
	eq(ui.insets_for(Rect2(80, 40, 1280, 720), Rect2(80, 25, 1432, 857), 1280.0, false), none, "beside the dock")


func test_phone_notch_and_home_bar() -> void:
	# A 1170 x 2532 phone, drawn at 390 points across, with its notch and home bar.
	var i: Dictionary = ui.insets_for(Rect2(0, 0, 1170, 2532), Rect2(0, 141, 1170, 2289), 390.0, true)
	eq(i["top"], 47.0, "the notch")
	eq(i["bottom"], 34.0, "the home bar")
	eq(i["left"], 0.0)
	eq(i["right"], 0.0)


func test_insets_are_measured_from_the_window_and_capped() -> void:
	var i: Dictionary = ui.insets_for(Rect2(2000, 0, 1000, 2000), Rect2(2000, 100, 1000, 1800), 1000.0, true)
	eq(i["top"], 100.0, "from the window's own top")
	eq(i["left"], 0.0, "not from the desktop's left edge")
	var wild: Dictionary = ui.insets_for(Rect2(0, 0, 1000, 2000), Rect2(5000, 0, 1000, 2000), 1000.0, true)
	eq(wild["left"], 250.0, "never more than a quarter of the window")
