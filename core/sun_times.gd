class_name SunTimes
extends RefCounted
## Sunrise and sunset for any place and day, worked out from the date and
## the place itself (the standard sunrise equation, allowing for the air
## bending the light at the horizon), so the sky can follow your real day
## without asking the internet.


## {sunrise, sunset} as local hours past midnight, for a place at
## `latitude`/`longitude` (degrees, north and east positive) on the given
## date, `utc_offset` hours ahead of UTC (1.0 for BST). Where the sun
## doesn't set or rise that day: {polar: "day"} or {polar: "night"}.
static func for_day(latitude: float, longitude: float, year: int, month: int, day: int, utc_offset: float) -> Dictionary:
	var noon := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0})
	# Whole days since noon on 1 January 2000, then the sun's position.
	var n := ceilf(noon / 86400.0 + 2440587.5 - 2451545.0 + 0.0008)
	var mean_noon := n - longitude / 360.0
	var anomaly := deg_to_rad(fposmod(357.5291 + 0.98560028 * mean_noon, 360.0))
	var centre := 1.9148 * sin(anomaly) + 0.02 * sin(2.0 * anomaly) + 0.0003 * sin(3.0 * anomaly)
	var ecliptic := deg_to_rad(fposmod(rad_to_deg(anomaly) + centre + 180.0 + 102.9372, 360.0))
	var transit := 2451545.0 + mean_noon + 0.0053 * sin(anomaly) - 0.0069 * sin(2.0 * ecliptic)
	var sin_dec := sin(ecliptic) * sin(deg_to_rad(23.4397))
	var cos_dec := cos(asin(sin_dec))
	var lat := deg_to_rad(latitude)
	var cos_hour := (sin(deg_to_rad(-0.833)) - sin(lat) * sin_dec) / (cos(lat) * cos_dec)
	if cos_hour < -1.0:
		return {"polar": "day"}
	if cos_hour > 1.0:
		return {"polar": "night"}
	var half_day := rad_to_deg(acos(cos_hour)) / 360.0
	return {
		"sunrise": _local_hour(transit - half_day, utc_offset),
		"sunset": _local_hour(transit + half_day, utc_offset),
	}


static func _local_hour(julian: float, utc_offset: float) -> float:
	return fposmod((julian - 2440587.5) * 24.0 + utc_offset, 24.0)
