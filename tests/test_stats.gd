extends TestCase

# 2026-10-19 is a Monday.
const MONDAY := 1792368000


## Day totals as the save keeps them, from [day after MONDAY, seconds,
## project (default "p"), place (default "lake")] entries.
func _days(entries: Array) -> Dictionary:
	var s := GameState.new()
	var monday := Stats.local_day(MONDAY, 0)
	for e in entries:
		s.log_focus(monday + int(e[0]), e[2] if e.size() > 2 else "p", e[3] if e.size() > 3 else "lake", int(e[1]))
	return s.days


func test_monday_is_weekday_zero() -> void:
	var day := Stats.local_day(MONDAY, 0)
	eq(Stats.weekday(day), 0)
	eq(Stats.week_start(day + 6), day)


func test_local_day_respects_timezone() -> void:
	# 23:30 UTC Sunday is already Monday in UTC+1.
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.local_day(MONDAY - 1800, 0), monday - 1, "UTC: Sunday")
	eq(Stats.local_day(MONDAY - 1800, 60), monday, "UTC+1: Monday")


func test_daily_totals() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var d := _days([[0, 600], [0, 300, "b"], [3, 900], [-1, 50]])
	eq(Stats.daily_totals(d, monday), [900, 0, 0, 900, 0, 0, 0] as Array[int])


func test_week_and_best_week() -> void:
	var d := _days([[0, 1000], [1, 500], [7, 2000]])
	eq(Stats.week_total(d, Stats.local_day(MONDAY, 0)), 1500)
	eq(Stats.best_week_total(d), 2000)


func test_streak() -> void:
	var d := _days([[0, 900], [1, 900], [2, 100], [3, 700], [4, 650]])
	var today := Stats.local_day(MONDAY, 0) + 4
	eq(Stats.current_streak(d, today), 2, "short day breaks it")
	eq(Stats.current_streak(d, today + 1), 2, "an empty today doesn't break it yet")
	eq(Stats.current_streak(d, today + 2), 0)


func test_short_walks_on_one_day_add_up() -> void:
	var d := _days([[0, 300], [0, 300, "b"]])
	eq(Stats.current_streak(d, Stats.local_day(MONDAY, 0)), 1, "two five minute walks make a work day")


func test_rest_day_after_three_days() -> void:
	# Work Mon-Wed, rest Thu, work Fri.
	var d := _days([[0, 900], [1, 900], [2, 900], [4, 900]])
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.current_streak(d, monday + 4), 4, "rest day forgiven, not counted")
	eq(Stats.current_streak(d, monday + 3), 3, "the rest day itself is still pending")
	check(Stats.rest_day_ready(d, monday + 2), "three days banks a rest day")
	check(not Stats.rest_day_ready(d, monday + 1), "two days doesn't")
	check(not Stats.rest_day_ready(d, monday + 4), "a rest day was just used")
	# Two missed days in a row break it.
	eq(Stats.current_streak(d, monday + 6), 0)


func test_rest_day_needs_three_days_before_it() -> void:
	# Work Mon, Tue, miss Wed, work Thu.
	var d := _days([[0, 900], [1, 900], [3, 900]])
	eq(Stats.current_streak(d, Stats.local_day(MONDAY, 0) + 3), 1)


func test_rest_day_yesterday_keeps_streak_alive_today() -> void:
	var d := _days([[0, 900], [1, 900], [2, 900]])
	# Thursday missed, Friday not over yet.
	eq(Stats.current_streak(d, Stats.local_day(MONDAY, 0) + 4), 3)


func test_daily_project_totals() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var d := _days([[0, 600, "a"], [0, 300, "b"], [2, 900, "a"]])
	var days := Stats.daily_project_totals(d, monday)
	eq(days[0], {"a": 600, "b": 300})
	eq(days[1], {})
	eq(days[2], {"a": 900})


func test_week_history() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.week_history(_days([[-14, 600]]), monday + 3), [monday, monday - 7, monday - 14] as Array[int])
	eq(Stats.week_history({}, monday + 3), [monday] as Array[int])


func test_project_totals_in_week() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var d := _days([[0, 600, "a"], [3, 900, "a"], [1, 300, "b"], [7, 5000, "a"]])
	var t := Stats.project_totals_in_week(d, monday)
	eq(t.get("a", 0), 1500, "next week's walk left out")
	eq(t.get("b", 0), 300)


func test_totals_by_project_and_place() -> void:
	var s := GameState.new()
	s.log_focus(10, "a", "lake", 10)
	s.log_focus(10, "b", "jungle", 5)
	s.log_focus(11, "a", "jungle", 7)
	s.log_focus(11, "a", "jungle", 0)
	eq(s.project_seconds("a"), 17)
	eq(s.project_seconds("b"), 5)
	eq(s.total_seconds(), 22)
	eq(s.place_seconds(), {"lake": 10, "jungle": 12})
	eq(s.days.size(), 2, "nothing logged for a zero-length walk")


func test_format_duration() -> void:
	eq(Stats.format_duration(59), "0m")
	eq(Stats.format_duration(3600 * 11 + 23 * 60), "11h 23m")
