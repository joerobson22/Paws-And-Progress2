extends TestCase

# 2026-10-19 is a Monday.
const MONDAY := 1792368000


func _session(start: int, seconds: int, project := "p") -> FocusSession:
	var s := FocusSession.new()
	s.start_unix = start
	s.focus_seconds = seconds
	s.project_id = project
	return s


func test_monday_is_weekday_zero() -> void:
	var day := Stats.local_day(MONDAY, 0)
	eq(Stats.weekday(day), 0)
	eq(Stats.week_start(day + 6), day)


func test_daily_totals_respect_timezone() -> void:
	# 23:30 UTC Sunday is already Monday in UTC+1.
	var s := [_session(MONDAY - 1800, 600)]
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.daily_totals(s, monday, 0)[0], 0, "UTC: Sunday, previous week")
	eq(Stats.daily_totals(s, monday, 60)[0], 600, "UTC+1: Monday")


func test_week_and_best_week() -> void:
	var s := [_session(MONDAY, 1000), _session(MONDAY + 86400, 500), _session(MONDAY + 7 * 86400, 2000)]
	eq(Stats.week_total(s, Stats.local_day(MONDAY, 0), 0), 1500)
	eq(Stats.best_week_total(s, 0), 2000)
	eq(Stats.longest_session(s), 2000)


func test_streak() -> void:
	var d := 86400
	var s := [_session(MONDAY, 900), _session(MONDAY + d, 900), _session(MONDAY + 2 * d, 100), _session(MONDAY + 3 * d, 700), _session(MONDAY + 4 * d, 650)]
	var today := Stats.local_day(MONDAY + 4 * d, 0)
	eq(Stats.current_streak(s, today, 0), 2, "short day breaks it")
	eq(Stats.current_streak(s, today + 1, 0), 2, "an empty today doesn't break it yet")
	eq(Stats.current_streak(s, today + 2, 0), 0)


func test_rest_day_after_three_days() -> void:
	var d := 86400
	# Work Mon-Wed, rest Thu, work Fri.
	var s := [_session(MONDAY, 900), _session(MONDAY + d, 900), _session(MONDAY + 2 * d, 900), _session(MONDAY + 4 * d, 900)]
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.current_streak(s, monday + 4, 0), 4, "rest day forgiven, not counted")
	eq(Stats.current_streak(s, monday + 3, 0), 3, "the rest day itself is still pending")
	check(Stats.rest_day_ready(s, monday + 2, 0), "three days banks a rest day")
	check(not Stats.rest_day_ready(s, monday + 1, 0), "two days doesn't")
	check(not Stats.rest_day_ready(s, monday + 4, 0), "a rest day was just used")
	# Two missed days in a row break it.
	eq(Stats.current_streak(s, monday + 6, 0), 0)


func test_rest_day_needs_three_days_before_it() -> void:
	var d := 86400
	# Work Mon, Tue, miss Wed, work Thu.
	var s := [_session(MONDAY, 900), _session(MONDAY + d, 900), _session(MONDAY + 3 * d, 900)]
	eq(Stats.current_streak(s, Stats.local_day(MONDAY, 0) + 3, 0), 1)


func test_rest_day_yesterday_keeps_streak_alive_today() -> void:
	var d := 86400
	var s := [_session(MONDAY, 900), _session(MONDAY + d, 900), _session(MONDAY + 2 * d, 900)]
	# Thursday missed, Friday not over yet.
	eq(Stats.current_streak(s, Stats.local_day(MONDAY, 0) + 4, 0), 3)


func test_daily_project_totals() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var s := [_session(MONDAY, 600, "a"), _session(MONDAY + 60, 300, "b"), _session(MONDAY + 2 * 86400, 900, "a")]
	var days := Stats.daily_project_totals(s, monday, 0)
	eq(days[0], {"a": 600, "b": 300})
	eq(days[1], {})
	eq(days[2], {"a": 900})


func test_week_history() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var s := [_session(MONDAY - 14 * 86400, 600)]
	eq(Stats.week_history(s, monday + 3, 0), [monday, monday - 7, monday - 14])
	eq(Stats.week_history([], monday + 3, 0), [monday])


func test_totals_by_project() -> void:
	var s := [_session(0, 10, "a"), _session(0, 5, "b"), _session(0, 7, "a")]
	eq(Stats.totals_by_project(s), {"a": 17, "b": 5})


func test_project_totals_in_week() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var s := [_session(MONDAY, 600, "a"), _session(MONDAY + 3 * 86400, 900, "a"),
		_session(MONDAY + 86400, 300, "b"), _session(MONDAY + 7 * 86400, 5000, "a")]
	var t := Stats.project_totals_in_week(s, monday, 0)
	eq(t.get("a", 0), 1500, "next week's walk left out")
	eq(t.get("b", 0), 300)


func test_format_duration() -> void:
	eq(Stats.format_duration(59), "0m")
	eq(Stats.format_duration(3600 * 11 + 23 * 60), "11h 23m")
