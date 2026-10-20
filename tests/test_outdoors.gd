extends TestCase

var biomes: Dictionary
var outdoors: GDScript


func _init() -> void:
	biomes = load_json("res://data/biomes.json")
	outdoors = load("res://core/outdoors.gd")


func _biome(id: String) -> Dictionary:
	for b in biomes["biomes"]:
		if b["id"] == id:
			return b
	return {}


## Within a few minutes of the published times.
func _near(hours: float, hh: int, mm: int, what: String) -> void:
	check(absf(hours - (hh + mm / 60.0)) < 5.0 / 60.0, "%s: %.2f is near %02d:%02d" % [what, hours, hh, mm])


func test_sun_times() -> void:
	var midsummer := SunTimes.for_day(51.5072, -0.1276, 2026, 6, 21, 1.0)
	_near(midsummer["sunrise"], 4, 43, "London midsummer sunrise (BST)")
	_near(midsummer["sunset"], 21, 21, "London midsummer sunset")
	var autumn := SunTimes.for_day(40.7128, -74.006, 2026, 10, 20, -4.0)
	_near(autumn["sunrise"], 7, 13, "New York sunrise in October (EDT)")
	_near(autumn["sunset"], 18, 8, "New York sunset in October")
	var south := SunTimes.for_day(-33.8688, 151.2093, 2026, 12, 21, 11.0)
	_near(south["sunrise"], 5, 41, "Sydney sunrise in December")
	_near(south["sunset"], 20, 5, "Sydney sunset in December")
	eq(SunTimes.for_day(69.65, 18.96, 2026, 6, 21, 2.0), {"polar": "day"}, "midnight sun in Tromsø")
	eq(SunTimes.for_day(69.65, 18.96, 2026, 12, 21, 1.0), {"polar": "night"}, "polar night in Tromsø")


func test_real_sun_hours_land_on_the_cycle() -> void:
	var cycle: Dictionary = biomes["day_cycle"]
	# A short winter day: up at 8, down at 4.
	eq(DayCycle.solar_hour(8.0, 8.0, 16.0, cycle), 6.0, "sunrise is the cycle's sunrise")
	eq(DayCycle.solar_hour(16.0, 8.0, 16.0, cycle), 18.0, "sunset is the cycle's sunset")
	eq(DayCycle.solar_hour(12.0, 8.0, 16.0, cycle), 12.0, "halfway through the day is midday")
	check(DayCycle.at(DayCycle.solar_hour(7.5, 8.0, 16.0, cycle), cycle)["sun"] < 0.0, "no sun before the real sunrise")
	check(DayCycle.at(DayCycle.solar_hour(15.5, 8.0, 16.0, cycle), cycle)["sun"] > 0.0, "still up before the real sunset")
	check(DayCycle.at(DayCycle.solar_hour(22.0, 8.0, 16.0, cycle), cycle)["moon"] > 0.0, "the moon's up on a long night")
	var before := DayCycle.solar_hour(7.999, 8.0, 16.0, cycle)
	check(absf(before - 6.0) < 0.01, "no jump at sunrise")


func test_weather_codes() -> void:
	eq(Weather.from_wmo(0), "sunny")
	eq(Weather.from_wmo(2), "partly")
	eq(Weather.from_wmo(3), "cloudy")
	eq(Weather.from_wmo(45), "cloudy", "fog")
	eq(Weather.from_wmo(61), "rainy")
	eq(Weather.from_wmo(81), "rainy", "showers")
	eq(Weather.from_wmo(73), "snowy")
	eq(Weather.from_wmo(95), "stormy")


func test_each_place_shows_weather_its_own_way() -> void:
	eq(Weather.for_place("rainy", _biome("lake")), "rainy")
	eq(Weather.for_place("rainy", _biome("tundra")), "snowy", "rain falls as snow in the tundra")
	eq(Weather.for_place("stormy", _biome("tundra")), "blizzard")
	for kind in ["rainy", "stormy", "snowy"]:
		eq(Weather.for_place(kind, _biome("desert")), "sunny", "no %s in the desert" % kind)
	eq(Weather.for_place("cloudy", _biome("desert")), "cloudy", "but it can cloud over")
	eq(Weather.for_place("snowy", _biome("jungle")), "sunny", "no snow in the jungle")
	eq(Weather.for_place("rainy", _biome("jungle")), "rainy")
	for kind in Weather.KINDS:
		eq(Weather.for_place(kind, _biome("moon")), "sunny", "no %s on the moon" % kind)
	var storm := Weather.look("blizzard", biomes["weathers"])
	check(storm["snow"] > Weather.look("snowy", biomes["weathers"])["snow"] and storm["haze"] > 0.0, "a blizzard is more snow and a white-out")
	eq(Weather.look("sunny", biomes["weathers"])["clouds"], 0, "a sunny sky is clear")


func test_reading_the_services() -> void:
	eq(outdoors.parse_location('{"latitude":"51.5164","longitude":"-0.093","city":"London","country":"United Kingdom"}'),
		{"lat": 51.5164, "lon": -0.093, "place": "London"})
	eq(outdoors.parse_location('{"latitude":40.7,"longitude":-74.0}'), {"lat": 40.7, "lon": -74.0, "place": ""}, "numbers work too")
	eq(outdoors.parse_location('{"error":"rate limited"}'), {})
	eq(outdoors.parse_location("not json"), {})
	eq(outdoors.parse_weather('{"latitude":51.5,"current":{"time":"2026-10-20T09:00","interval":900,"weather_code":63}}'), "rainy")
	eq(outdoors.parse_weather('{"current":{}}'), "")
	eq(outdoors.parse_weather(""), "")
