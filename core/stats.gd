class_name Stats
extends RefCounted
## Stats worked out from the focus time saved per day (GameState.days). Days
## are local calendar days, numbered by local_day(); weeks start on Monday.
## `bias_minutes` is the local UTC offset in minutes
## (Time.get_time_zone_from_system().bias), passed in so tests are deterministic.

const SECONDS_PER_DAY := 86400
## A day counts towards a streak with at least this much focus.
const STREAK_MIN_SECONDS := 600
## This many work days in a row earn one rest day: missing the next day
## doesn't break the streak.
const REST_DAY_AFTER := 3


static func local_day(unix: int, bias_minutes: int) -> int:
	return floori(float(unix + bias_minutes * 60) / SECONDS_PER_DAY)


## A walk's focus time shared out over the local days it fell on, from its
## start, as [[day, seconds], ...]. Pauses are taken as at the end, so a walk
## over midnight counts the right time each side unless it paused a lot.
static func split_by_day(start_unix: int, seconds: int, bias_minutes: int) -> Array:
	var out: Array = []
	var at := start_unix
	var left := seconds
	while left > 0:
		var day := local_day(at, bias_minutes)
		var midnight := (day + 1) * SECONDS_PER_DAY - bias_minutes * 60
		var part := mini(left, midnight - at)
		out.append([day, part])
		left -= part
		at += part
	return out


## 0 = Monday ... 6 = Sunday. Day 0 (1970-01-01) was a Thursday.
static func weekday(day: int) -> int:
	return posmod(day + 3, 7)


static func week_start(day: int) -> int:
	return day - weekday(day)


## Focus per day of the week beginning `week_start_day`, Monday first.
static func daily_totals(days: Dictionary, week_start_day: int) -> Array[int]:
	var totals: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for i in 7:
		totals[i] = _day_total(days, week_start_day + i)
	return totals


## Seven {project_id: seconds} dictionaries, Monday first: each day's bar split by project.
static func daily_project_totals(days: Dictionary, week_start_day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{}, {}, {}, {}, {}, {}, {}]
	for i in 7:
		var d: Dictionary = days.get(week_start_day + i, {})
		for id in d.get("projects", {}):
			out[i][id] = int(d["projects"][id])
	return out


static func week_total(days: Dictionary, week_start_day: int) -> int:
	var total := 0
	for t in daily_totals(days, week_start_day):
		total += t
	return total


## {week_start_day: seconds} for every week that has any focus.
static func weekly_totals(days: Dictionary) -> Dictionary:
	var weeks := {}
	for day in days:
		var w := week_start(int(day))
		weeks[w] = int(weeks.get(w, 0)) + _day_total(days, int(day))
	return weeks


## Week start days from this week back to the first week with any focus (or
## `since_day`, whichever is earlier), newest first, at most `limit` weeks.
static func week_history(days: Dictionary, today: int, since_day: int = 0, limit: int = 104) -> Array[int]:
	var first := week_start(today)
	for w in weekly_totals(days):
		first = mini(first, w)
	if since_day > 0:
		first = mini(first, week_start(since_day))
	var out: Array[int] = []
	var w := week_start(today)
	while w >= first and out.size() < limit:
		out.append(w)
		w -= 7
	return out


static func best_week_total(days: Dictionary) -> int:
	var best := 0
	for total in weekly_totals(days).values():
		best = maxi(best, total)
	return best


## {project_id: seconds} for the week beginning `week_start_day`.
static func project_totals_in_week(days: Dictionary, week_start_day: int) -> Dictionary:
	var out := {}
	for d in daily_project_totals(days, week_start_day):
		for id in d:
			out[id] = int(out.get(id, 0)) + int(d[id])
	return out


## Days with at least `min_seconds` of focus, as a set {day: true}.
static func work_days(days: Dictionary, min_seconds: int = STREAK_MIN_SECONDS) -> Dictionary:
	var out := {}
	for day in days:
		if _day_total(days, int(day)) >= min_seconds:
			out[int(day)] = true
	return out


static func _day_total(days: Dictionary, day: int) -> int:
	var total := 0
	for s in days.get(day, {}).get("projects", {}).values():
		total += int(s)
	return total


## Work days in the streak ending today. A day with nothing yet doesn't break
## it until it's over, and one missed day is forgiven (a rest day) when the
## REST_DAY_AFTER days before it were all work days. Rest days don't add to
## the count.
static func current_streak(days: Dictionary, today: int, min_seconds: int = STREAK_MIN_SECONDS) -> int:
	var work := work_days(days, min_seconds)
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
static func rest_day_ready(days: Dictionary, today: int, min_seconds: int = STREAK_MIN_SECONDS) -> bool:
	var work := work_days(days, min_seconds)
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
		return Text.t("dates.hours_minutes", {"h": h, "m": "%02d" % m})
	return Text.t("dates.minutes", {"m": m})


## "3 Jan 2026" for a unix time, in local time.
static func format_date(unix: int, bias_minutes: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	return Text.t("dates.date", {"day": d["day"], "month": Text.list("dates.months")[int(d["month"]) - 1], "year": d["year"]})


## "13 Oct" for a local day number.
static func format_day(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * SECONDS_PER_DAY)
	return Text.t("dates.day", {"day": d["day"], "month": Text.list("dates.months")[int(d["month"]) - 1]})
