class_name Stats
extends RefCounted
## Stats computed from the finished-session log. Days are local calendar days;
## weeks start on Monday. `bias_minutes` is the local UTC offset in minutes
## (Time.get_time_zone_from_system().bias), passed in so tests are deterministic.

const SECONDS_PER_DAY := 86400


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


## Consecutive days with at least `min_seconds` of walking, ending today.
## A day with nothing yet doesn't break the streak until it's over, so the
## count runs back from yesterday if today is still empty.
static func current_streak(sessions: Array, today: int, bias_minutes: int, min_seconds: int = 600) -> int:
	var per_day := {}
	for s in sessions:
		var d := local_day(s.start_unix, bias_minutes)
		per_day[d] = int(per_day.get(d, 0)) + s.focus_seconds
	var day := today
	if int(per_day.get(day, 0)) < min_seconds:
		day -= 1
	var streak := 0
	while int(per_day.get(day, 0)) >= min_seconds:
		streak += 1
		day -= 1
	return streak


static func format_duration(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds / 60) % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % m
