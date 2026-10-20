class_name Weather
extends RefCounted
## The weather on a walk. The real weather (as WMO codes, the way Open-Meteo
## reports them) comes down to one of a few kinds; each place then shows it
## its own way through its "weather" rules in data/biomes.json (the
## tundra's rain falls as snow, it never rains in the desert, and so on),
## and data/biomes.json's "weathers" say how each kind looks.

## The kinds the real weather can be, in the order the debug picker lists them.
const KINDS: Array[String] = ["sunny", "partly", "cloudy", "rainy", "stormy", "snowy"]


## The kind for a WMO weather code.
static func from_wmo(code: int) -> String:
	if code <= 1:
		return "sunny"  # clear, mainly clear
	if code == 2:
		return "partly"
	if code == 3 or code == 45 or code == 48:
		return "cloudy"  # overcast, fog
	if (code >= 51 and code <= 67) or (code >= 80 and code <= 82):
		return "rainy"  # drizzle, rain, freezing rain, showers
	if (code >= 71 and code <= 77) or code == 85 or code == 86:
		return "snowy"
	if code >= 95:
		return "stormy"
	return "sunny"


## How `kind` shows in `biome`: its rules can turn one kind into another,
## "sunny" meaning no weather at all; "*" covers every kind.
static func for_place(kind: String, biome: Dictionary) -> String:
	var rules: Dictionary = biome.get("weather", {})
	return str(rules.get(kind, rules.get("*", kind)))


## How a kind looks, from data/biomes.json's "weathers": {name, clouds,
## overcast, rain, snow, wind, lightning, haze}, with zeros for what it
## doesn't have.
static func look(kind: String, table: Dictionary) -> Dictionary:
	var out := {"name": kind.capitalize(), "clouds": 0, "overcast": 0.0, "rain": 0, "snow": 0, "wind": 0.0, "lightning": false, "haze": 0.0}
	out.merge(table.get(kind, {}), true)
	return out
