extends TestCase


func test_elapsed_counts_wall_time() -> void:
	var c := SessionClock.begin("p", 1000)
	eq(c.elapsed(1000), 0)
	eq(c.elapsed(1600), 600)


func test_pause_excludes_paused_time() -> void:
	var c := SessionClock.begin("p", 0)
	c.pause(100)
	eq(c.elapsed(500), 100, "frozen while paused")
	c.resume(400)
	eq(c.elapsed(500), 200, "paused stretch excluded")
	c.pause(600)
	c.pause(700)
	c.resume(900)
	eq(c.elapsed(1000), 400, "double pause is harmless")


func test_survives_save_and_reload_mid_pause() -> void:
	var c := SessionClock.begin("p", 0)
	c.pause(300)
	var back := SessionClock.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(back.is_paused())
	back.resume(1000)
	eq(back.elapsed(1100), 400)


func test_clock_going_backwards_never_negative() -> void:
	var c := SessionClock.begin("p", 1000)
	eq(c.elapsed(500), 0)


func test_forgotten_walk_is_capped() -> void:
	var c := SessionClock.begin("p", 0)
	eq(c.elapsed(3 * 86400), SessionClock.MAX_SESSION_SECONDS)


func test_format() -> void:
	eq(SessionClock.format(3725), "01:02:05")


func test_walk_left_running_stops_when_the_app_was_last_seen() -> void:
	var c := SessionClock.begin("p", 1000)
	c.last_seen_unix = 2500
	eq(c.left_at(9000, 99999), 2500, "the last heartbeat wins")
	var old := SessionClock.begin("p", 1000)
	eq(old.left_at(3000, 99999), 3000, "else when the save was last written")
	eq(old.left_at(0, 99999), 1000, "else it never really started")
	eq(old.left_at(500, 99999), 1000, "never before it started")
	c.last_seen_unix = 200000
	eq(c.left_at(0, 5000), 5000, "never after now")
	var back := SessionClock.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	eq(back.last_seen_unix, 200000, "saved")
