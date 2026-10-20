class_name Stats
extends RefCounted
## Stats computed from the finished-session log. Days are local calendar days;
## weeks start on Monday. `bias_minutes` is the local UTC offset in minutes
## (Time.get_time_zone_from_system().bias), passed in so tests are deterministic.

const SECONDS_PER_DAY := 86400
## A day counts towards a streak with at least this much focus.
const STREAK_MIN_SECONDS := 600
## This many work days in a row earn one rest day: missing the next day
## doesn't break the streak.
const REST_DAY_AFTER := 3
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func local_day(unix: int, bias_minutes: int) -> int:
	return floori(float(unix + bias_minutes * 60) / SECONDS_PER_DAY)


## 0 = Monday ... 6 = Sunday. Day 0 (1970-01-01) was a Thursday.
static func weekday(day: int) -> int:
	return posmod(day + 3, 7)


static func week_start(day: int) -> int:
	return day - weekday(day)


static func daily_totals(sessions: Array, week_start_day: int, bias_minutes: int) -> Array[int]:
	var totals: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for s in sessions:
		var i := local_day(s.start_unix, bias_minutes) - week_start_day
		if i >= 0 and i < 7:
			totals[i] += s.focus_seconds
	return totals


## Seven {project_id: seconds} dictionaries, Monday first: each day's bar split by project.
static func daily_project_totals(sessions: Array, week_start_day: int, bias_minutes: int) -> Array[Dictionary]:
	var days: Array[Dictionary] = [{}, {}, {}, {}, {}, {}, {}]
	for s in sessions:
		var i := local_day(s.start_unix, bias_minutes) - week_start_day
		if i >= 0 and i < 7:
			days[i][s.project_id] = int(days[i].get(s.project_id, 0)) + s.focus_seconds
	return days


static func week_total(sessions: Array, week_start_day: int, bias_minutes: int) -> int:
	var total := 0
	for t in daily_totals(sessions, week_start_day, bias_minutes):
		total += t
	return total


## {week_start_day: seconds} for every week that has any walks.
static func weekly_totals(sessions: Array, bias_minutes: int) -> Dictionary:
	var weeks := {}
	for s in sessions:
		var w := week_start(local_day(s.start_unix, bias_minutes))
		weeks[w] = int(weeks.get(w, 0)) + s.focus_seconds
	return weeks


## Week start days from this week back to the first week with a walk (or
## `since_day`, whichever is earlier), newest first, at most `limit` weeks.
static func week_history(sessions: Array, today: int, bias_minutes: int, since_day: int = 0, limit: int = 104) -> Array[int]:
	var first := week_start(today)
	for w in weekly_totals(sessions, bias_minutes):
		first = mini(first, w)
	if since_day > 0:
		first = mini(first, week_start(since_day))
	var out: Array[int] = []
	var w := week_start(today)
	while w >= first and out.size() < limit:
		out.append(w)
		w -= 7
	return out


static func best_week_total(sessions: Array, bias_minutes: int) -> int:
	var best := 0
	for total in weekly_totals(sessions, bias_minutes).values():
		best = maxi(best, total)
	return best


static func longest_session(sessions: Array) -> int:
	var best := 0
	for s in sessions:
		best = maxi(best, s.focus_seconds)
	return best


static func total_seconds(sessions: Array) -> int:
	var total := 0
	for s in sessions:
		total += s.focus_seconds
	return total


static func totals_by_project(sessions: Array) -> Dictionary:
	var out := {}
	for s in sessions:
		out[s.project_id] = int(out.get(s.project_id, 0)) + s.focus_seconds
	return out


## {project_id: seconds} for walks started in the week beginning `week_start_day`.
static func project_totals_in_week(sessions: Array, week_start_day: int, bias_minutes: int) -> Dictionary:
	var out := {}
	for s in sessions:
		var i := local_day(s.start_unix, bias_minutes) - week_start_day
		if i >= 0 and i < 7:
			out[s.project_id] = int(out.get(s.project_id, 0)) + s.focus_seconds
	return out


## Days with at least `min_seconds` of focus, as a set {day: true}.
static func work_days(sessions: Array, bias_minutes: int, min_seconds: int = STREAK_MIN_SECONDS) -> Dictionary:
	var per_day := {}
	for s in sessions:
		var d := local_day(s.start_unix, bias_minutes)
		per_day[d] = int(per_day.get(d, 0)) + s.focus_seconds
	var out := {}
	for d in per_day:
		if per_day[d] >= min_seconds:
			out[d] = true
	return out


## Work days in the streak ending today. A day with nothing yet doesn't break
## it until it's over, and one missed day is forgiven (a rest day) when the
## REST_DAY_AFTER days before it were all work days. Rest days don't add to
## the count.
static func current_streak(sessions: Array, today: int, bias_minutes: int, min_seconds: int = STREAK_MIN_SECONDS) -> int:
	var work := work_days(sessions, bias_minutes, min_seconds)
	var day := today if work.has(today) else today - 1
	var streak := 0
	while true:
		if work.has(day):
			streak += 1
		elif _run_ending(work, day - 1) < REST_DAY_AFTER:
			break
		day -= 1
	return streak


## True when a rest day is banked: the run of work days ending today (or
## yesterday, if today has nothing yet) is long enough to forgive a miss.
static func rest_day_ready(sessions: Array, today: int, bias_minutes: int, min_seconds: int = STREAK_MIN_SECONDS) -> bool:
	var work := work_days(sessions, bias_minutes, min_seconds)
	var day := today if work.has(today) else today - 1
	return _run_ending(work, day) >= REST_DAY_AFTER


## Consecutive work days ending on `day` (counting back), up to REST_DAY_AFTER.
static func _run_ending(work: Dictionary, day: int) -> int:
	var run := 0
	while run < REST_DAY_AFTER and work.has(day - run):
		run += 1
	return run


static func format_duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h := seconds / 3600
	@warning_ignore("integer_division")
	var m := (seconds / 60) % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % m


## "3 Jan 2026" for a unix time, in local time.
static func format_date(unix: int, bias_minutes: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	return "%d %s %d" % [d["day"], MONTHS[int(d["month"]) - 1], d["year"]]


## "13 Oct" for a local day number.
static func format_day(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * SECONDS_PER_DAY)
	return "%d %s" % [d["day"], MONTHS[int(d["month"]) - 1]]
