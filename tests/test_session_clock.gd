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
