class_name Scenery
extends Control
## Endless parallax scenery for one place, drawn from data/biomes.json.
## Each layer is cut into chunks a few hundred pixels wide. A chunk is drawn
## once when it scrolls into view and freed once it has scrolled off, so a
## long walk costs little more than moving a handful of nodes each frame;
## only the few animated layers (water, reeds, fronds) redraw as they move.
## Weather (snow, wind, stars, fireflies) is a thin layer on top. Layers
## marked "front" (the jungle's big leaves and vines) go in `front`, which a
## host can lift in front of its walker and pet with front_into(). A host can
## instead stand() its walker and pet among the layers, so a pet running off
## into the distance goes behind the trees standing nearer than it.
##
## The light follows the real clock (see DayCycle), with the real sunrise
## and sunset where you are once you've allowed it (Outdoors): the sky
## brightens until midday and darkens after, the sun and then the moon
## cross it, and every layer is tinted to match through its node's
## modulate, so a change of light costs no redrawing. The real weather
## shows too, the way this place shows it (Weather): clouds, rain and
## lightning, snow, a blizzard. A layer with "art" repeats that scene instead
## of drawing its kind (see art/README.md).

const CHUNK := 384.0
## The screen height (in pixels) that layer art scenes are drawn for.
const ART_HEIGHT := 720.0
## Layers that move with the time and so redraw every frame.
const ANIMATED := ["water", "reeds", "fronds", "undergrowth", "vines", "stalks"]
## How often the light catches up with the clock, in seconds.
const LIGHT_EVERY := 5.0
## Every scenery's front growth is in this group, wherever it's been moved.
const FRONT_GROUP := "scenery_front"
## A storm flashes about this often, in seconds.
const STORM_EVERY := 7.0
## Layers that grow up from the bottom of the screen (or hang from the top),
## so stand nearer than anyone on the path.
const NEAREST := ["reeds", "fronds", "drifts", "undergrowth", "stalks", "vines"]
## Layers with lights that come on after dark (lit windows, street lamps):
## they're drawn again as night falls and as day breaks.
const LIGHTS := ["buildings", "lamps"]

## Ground-layer pixels walked so far; every layer scrolls by this × its parallax.
var scroll: float = 0.0
var biome: Dictionary = {}
## The hour shown (14.5 is half past two), or -1 to follow the real clock.
var clock: float = -1.0:
	set(v):
		clock = v
		_update_light()
## A weather kind to show here instead of the real one (see Weather.KINDS);
## "" follows Outdoors.
var weather := "":
	set(v):
		weather = v
		_update_light()

var _time: float = 0.0
## Whether the lights (LIGHTS) were last drawn on.
var _lights_on := false
## DayCycle.at() for the hour shown, with the weather's cloud cover, plus
## "glow": how much of the sun or moon shows through it.
var _light: Dictionary = {}
var _light_check := 0.0
## The weather as this place shows it, and how that looks (Weather.look).
var _weather_kind := "sunny"
var _look: Dictionary = {}
## A storm's lightning: how bright the flash is now, which flash is drawing
## its bolt (-1 for none), and the last one thunder was played for.
var _flash := 0.0
var _bolt := -1
var _thunder_for := -1
## One entry per layer: {data, node, chunks: {index: _Chunk}, animated}.
var _layers: Array = []
var _sky: _Sky
var _clouds: _Clouds
var _fx: _Fx
## The growth in front of everything else. It's the scenery's own top child
## until a host moves it with front_into(); it then keeps following the
## scenery's place, size and fade.
var front: Control
## Multiplied into the front growth's colour, e.g. to darken it along with a
## sheet laid over the rest of the scene, or to fade it on its own.
var front_tint := Color.WHITE
## A stretch of the screen (from x, to x) kept clear of tall plants, so one
## never stands in front of the pet everyone's looking at. Empty: none.
var front_gap := Vector2.ZERO
## Multiplied into everything the scenery draws, but not into anyone stood
## in it, e.g. to dim the scene behind a pet in the spotlight.
var shade := Color.WHITE:
	set(v):
		shade = v
		_update_shade()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sky = _Sky.new()
	_sky.scenery = self
	_sky.set_meta("foot", -INF)
	add_child(_sky)
	_clouds = _Clouds.new()
	_clouds.scenery = self
	_clouds.set_meta("foot", -INF)
	add_child(_clouds)
	front = Control.new()
	front.name = "SceneryFront"
	front.add_to_group(FRONT_GROUP)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.clip_contents = true
	for layer in biome.get("layers", []):
		if layer["kind"] == "planet":
			continue  # drawn with the sky
		var node := Node2D.new()
		node.set_meta("foot", 1.0 if NEAREST.has(str(layer["kind"])) else float(layer["y"]))
		if layer.get("front", false):
			front.add_child(node)
		else:
			add_child(node)
		var tile = _art_tile(layer)
		_layers.append({"data": layer, "node": node, "chunks": {}, "animated": ANIMATED.has(str(layer["kind"])), "tile": tile})
	_fx = _Fx.new()
	_fx.scenery = self
	add_child(_fx)
	add_child(front)
	resized.connect(_rebuild)
	Outdoors.changed.connect(_update_light)
	_update_light()
	_update_shade()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(front) and front.get_parent() != self:
		front.queue_free()


## Moves the front growth into `parent` (the scenery's own parent, or one
## standing in the same place) as its last child, so it's drawn over
## whatever was added before it, like the walker and the pet.
func front_into(parent: Node) -> void:
	front.reparent(parent, false)


## Draws `actor` (one of the scenery's own children, or a child of a node
## standing in the same place) among the layers by how far back its feet are:
## in front of the layers further back, behind any standing nearer (and
## behind everyone nearer). Call it again as the actor moves.
func stand(actor: CanvasItem, feet_y: float) -> void:
	if actor.get_parent() == null:
		add_child(actor)
	elif actor.get_parent() != self:
		actor.reparent(self, false)
	var foot := feet_y / maxf(1.0, size.y)
	actor.set_meta("foot", foot)
	var at := 0
	for child in get_children():
		if child == actor:
			continue
		if float(child.get_meta("foot", INF)) > foot:
			break
		at += 1
	move_child(actor, at)


func _process(delta: float) -> void:
	_time += delta
	_light_check -= delta
	if _light_check <= 0.0:
		_update_light()
	_place_chunks()
	if bool(_look.get("lightning", false)):
		_storm()
	elif _flash > 0.0 or _bolt >= 0:
		_flash = 0.0
		_bolt = -1
	_fx.queue_redraw()
	if not is_instance_valid(front):
		return
	if front.get_parent() != self:
		front.position = position
		front.size = size
		front.modulate = modulate * front_tint * shade
		front.visible = visible
	else:
		front.size = size
		front.modulate = front_tint * shade


## The hour of the day shown.
func hour() -> float:
	return clock if clock >= 0.0 else DayCycle.hour_now()


func _update_light() -> void:
	_light_check = LIGHT_EVERY
	_weather_kind = Weather.for_place(weather if weather != "" else Outdoors.weather(), biome)
	_look = Weather.look(_weather_kind, Content.weathers)
	var sun := Outdoors.sun_hours()
	_light = DayCycle.at(DayCycle.solar_hour(hour(), sun.x, sun.y, Content.day_cycle), Content.day_cycle)
	# Cloud cover greys the sky, dims the light and hides the sun and moon.
	var o := float(_look["overcast"])
	if o > 0.0:
		for key in ["sky_top", "sky_bottom"]:
			var c: Color = _light[key]
			var grey := c.get_luminance() * 0.92
			_light[key] = c.lerp(Color(grey * 0.96, grey, grey * 1.04), o * 0.85).darkened(o * 0.2)
		_light["tint"] = (_light["tint"] as Color).lerp((_light["tint"] as Color) * Color(0.8, 0.82, 0.86), o)
	_light["glow"] = 1.0 - clampf(o * 1.15, 0.0, 1.0)
	var lit := darkness() > 0.3
	if lit != _lights_on:
		_lights_on = lit
		for layer in _layers:
			if LIGHTS.has(str(layer["data"]["kind"])):
				for chunk in layer["chunks"].values():
					chunk.queue_redraw()
	_update_shade()
	if _sky:
		_sky.queue_redraw()
	if _clouds:
		_clouds.queue_redraw()


func _update_shade() -> void:
	var t := tint() * shade
	for layer in _layers:
		layer["node"].modulate = t
	for node in [_sky, _clouds, _fx]:
		if node:
			node.modulate = shade


## The weather as this place shows it now (see Weather.KINDS; "blizzard"
## in the tundra).
func weather_kind() -> String:
	return _weather_kind


## Lightning every few seconds in a storm: a double flicker, then a fading
## glow, and thunder a moment later.
func _storm() -> void:
	var k := floori(_time / STORM_EVERY)
	var since := _time - (k * STORM_EVERY + _hash(k, 31.0) * 4.0)
	if since < 0.0 or since >= 0.6:
		_flash = 0.0
		_bolt = -1
		return
	if since < 0.06:
		_flash = 0.55
	elif since < 0.12:
		_flash = 0.12
	else:
		_flash = 0.45 * (1.0 - (since - 0.12) / 0.48)
	_bolt = k if since < 0.25 else -1
	if k != _thunder_for and is_visible_in_tree():
		_thunder_for = k
		get_tree().create_timer(0.7 + _hash(k, 32.0)).timeout.connect(Audio.play.bind("thunder", 0.85 + 0.3 * _hash(k, 33.0), -3.0))


## Screen y of the walking path (where feet go).
func path_y() -> float:
	var g := ground_layer()
	if not g.is_empty():
		return size.y * (float(g["y"]) + float(g["height"]) * 0.32)
	return size.y * 0.8


func ground_layer() -> Dictionary:
	for layer in biome.get("layers", []):
		if layer["kind"] == "ground":
			return layer
	return {}


## Screen y of the far horizon: the foot of the furthest layer of hills,
## where the sun and moon come up from and the clouds sit above.
func horizon_y() -> float:
	for layer in biome.get("layers", []):
		if layer["kind"] != "planet":
			return size.y * float(layer["y"])
	return size.y * 0.5


## The water band on screen (top y, bottom y), or an empty Vector2 if there's none.
func water_band() -> Vector2:
	for layer in biome.get("layers", []):
		if layer["kind"] == "water":
			return Vector2(float(layer["y"]), float(layer["y"]) + float(layer["height"])) * size.y
	return Vector2.ZERO


func water_colour() -> Color:
	for layer in biome.get("layers", []):
		if layer["kind"] == "water":
			return Color.from_string(layer["colour"], Color.SKY_BLUE) * tint()
	return Color.SKY_BLUE


## How the light colours everything now (white for places with their own light).
func tint() -> Color:
	if biome.get("fixed_light", false) or _light.is_empty():
		return Color.WHITE
	return _light["tint"]


## 0 in broad daylight, 1 at night (always 1 under a fixed black sky).
## Cloud doesn't count: an overcast noon is dull, not dark.
func darkness() -> float:
	if biome.has("sky"):
		return 1.0
	return float(_light.get("dark", 0.0))


func is_dark() -> bool:
	return darkness() >= 0.5


func time() -> float:
	return _time


## The looping sound for this place now: daytime birds and lapping water give
## way to the night chorus after dark; wind and silence (the Moon) stay put.
func ambience() -> String:
	var own := str(biome.get("ambience", "day"))
	if int(_look.get("rain", 0)) > 0:
		return "rain"
	if float(_look.get("haze", 0.0)) > 0.0:
		return "wind"
	if darkness() >= 0.6 and own in ["lake", "day"]:
		return "night"
	return own


## Makes chunks that have scrolled into view, frees ones that have left, and
## moves the rest. Positions are worked out in full precision here, so hours
## of walking never make the scenery jitter.
func _place_chunks() -> void:
	for layer in _layers:
		var offset := scroll * float(layer["data"]["parallax"])
		if layer["tile"] != null:
			_place_tiles(layer, offset)
			continue
		var first := floori(offset / CHUNK) - 1
		var last := floori((offset + size.x) / CHUNK) + 1
		var chunks: Dictionary = layer["chunks"]
		for i in chunks.keys():
			if i < first or i > last:
				chunks[i].queue_free()
				chunks.erase(i)
		for i in range(first, last + 1):
			var chunk: _Chunk = chunks.get(i)
			if chunk == null:
				chunk = _Chunk.new()
				chunk.scenery = self
				chunk.layer = layer["data"]
				chunk.index = i
				layer["node"].add_child(chunk)
				chunks[i] = chunk
			chunk.position.x = i * CHUNK - offset
			if layer["animated"]:
				chunk.queue_redraw()


## The layer's art as {scene, width}, or null: a layer with "art" (a scene
## path in biomes.json) repeats that scene instead of drawing its kind.
## The scene is drawn for a screen ART_HEIGHT tall, its origin on the line
## the layer stands on (its "y"), and is as wide as its ReferenceRect named
## "TileBounds" (else the layer's "tile_width", else 768).
func _art_tile(layer: Dictionary) -> Variant:
	var path := str(layer.get("art", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var probe := scene.instantiate()
	var bounds := probe.get_node_or_null("TileBounds") as Control
	var width := bounds.size.x if bounds and bounds.size.x > 0.0 else float(layer.get("tile_width", 768))
	probe.free()
	return {"scene": scene, "width": width}


## Lays copies of a layer's art scene side by side, making ones that scroll
## into view and freeing ones that leave, like the drawn chunks.
func _place_tiles(layer: Dictionary, offset: float) -> void:
	var k := size.y / ART_HEIGHT
	var width: float = layer["tile"]["width"] * k
	if width <= 1.0:
		return
	var first := floori(offset / width) - 1
	var last := floori((offset + size.x) / width) + 1
	var tiles: Dictionary = layer["chunks"]
	for i in tiles.keys():
		if i < first or i > last:
			tiles[i].queue_free()
			tiles.erase(i)
	for i in range(first, last + 1):
		var tile: Node2D = tiles.get(i)
		if tile == null:
			tile = (layer["tile"]["scene"] as PackedScene).instantiate()
			tile.scale = Vector2(k, k)
			layer["node"].add_child(tile)
			tiles[i] = tile
		tile.position = Vector2(i * width - offset, size.y * float(layer["data"]["y"]))


func _rebuild() -> void:
	for layer in _layers:
		for chunk in layer["chunks"].values():
			chunk.queue_free()
		layer["chunks"].clear()
	_sky.queue_redraw()
	_place_chunks()


static func _noise(t: float, sd: float) -> float:
	return 0.55 * sin(t * TAU + sd) + 0.3 * sin(t * TAU * 2.3 + sd * 1.7) + 0.15 * sin(t * TAU * 5.1 + sd * 2.9)


## Stable pseudo-random 0..1 for an integer slot.
static func _hash(i: int, sd: float) -> float:
	return fposmod(sin(i * 12.9898 + sd * 78.233) * 43758.5453, 1.0)


## One stretch of one layer, drawn in its own space: x runs 0..CHUNK across it.
class _Chunk extends Node2D:
	var scenery: Scenery
	var layer: Dictionary
	var index: int

	func _draw() -> void:
		var size := scenery.size
		var colour := Color.from_string(layer["colour"], Color.WHITE)
		var y := size.y * float(layer["y"])
		var h := size.y * float(layer["height"])
		var sd := float(layer.get("seed", 0))
		var spacing := float(layer.get("spacing", 70))
		var snow := bool(layer.get("snow", false))
		# World x where this chunk starts, in the layer's own scrolling space.
		var x0 := index * CHUNK
		match str(layer["kind"]):
			"hills":
				_hills(x0, y, h, float(layer.get("wavelength", 400)), sd, colour, size)
			"water":
				_water(x0, y, h, sd, colour)
			"ground":
				_ground(x0, y, h, sd, colour, size)
			"reeds":
				_slots(x0, spacing, sd, 0.35, func(x, r, _i): _reed_tuft(x, y, h * r, colour, r, size))
			"fronds":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _frond(x, h * (0.6 + 0.6 * r), colour, r, size))
			"trees":
				_slots(x0, spacing, sd, 0.25, func(x, r, i): _tree(x, y, h * (0.6 + 0.6 * r), colour.darkened(0.1 * Scenery._hash(i + 3, sd))))
			"pines":
				_slots(x0, spacing, sd, 0.2, func(x, r, i): _pine(x, y, h * (0.55 + 0.6 * r), colour.darkened(0.12 * Scenery._hash(i + 3, sd)), snow))
			"broadleaf":
				_slots(x0, spacing, sd, 0.3, func(x, r, i): _broadleaf(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.12 * Scenery._hash(i + 5, sd))))
			"canopy":
				_slots(x0, spacing, sd, 0.0, func(x, r, i): _canopy(x, y, h * (0.75 + 0.35 * r), colour, i, sd))
			"palms":
				_slots(x0, spacing, sd, 0.35, func(x, r, _i): _palm(x, y, h * (0.7 + 0.4 * r), colour, r))
			"mountains":
				_slots(x0, spacing, sd, 0.0, func(x, r, i): _mountain(x, y, h * (0.6 + 0.5 * r), spacing * (0.9 + 0.6 * Scenery._hash(i + 9, sd)), colour.darkened(0.08 * Scenery._hash(i + 2, sd)), snow))
			"mesas":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _mesa(x, y, h * (0.6 + 0.5 * r), spacing * (0.35 + 0.3 * r), colour))
			"cacti":
				_slots(x0, spacing, sd, 0.35, func(x, r, _i): _cactus(x, y, h * (0.55 + 0.5 * r), colour, r))
			"drifts":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _drift(x, size.y, h * (0.5 + r), colour))
			"undergrowth":
				_slots(x0, spacing, sd, float(layer.get("skip", 0.15)), func(x, r, i): _undergrowth(x, y, h * (0.6 + 0.5 * r), colour.darkened(0.15 * Scenery._hash(i + 4, sd)), r))
			"vines":
				_slots(x0, spacing, sd, float(layer.get("skip", 0.3)), func(x, r, _i): _vine(x, y, h * (0.4 + 0.7 * r), colour, r))
			"stalks":
				_slots(x0, spacing, sd, float(layer.get("skip", 0.4)), func(x, r, i): _stalk(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.1 * Scenery._hash(i + 6, sd)), r))
			"fields":
				_fields(x0, y, h, float(layer.get("wavelength", 400)), sd, colour, size)
			"barns":
				_slots(x0, spacing, sd, 0.25, func(x, r, i): _barn(x, y, h * (0.75 + 0.35 * r), colour, i))
			"fences":
				_fence(x0, y, h, spacing, colour)
			"buildings":
				_slots(x0, spacing, sd, 0.0, func(x, r, i): _building(x, y, h * (0.35 + 0.65 * r), spacing * (0.7 + 0.25 * Scenery._hash(i + 9, sd)), colour.darkened(0.12 * Scenery._hash(i + 2, sd)), i, sd))
			"lamps":
				_slots(x0, spacing, sd, 0.0, func(x, _r, _i): _lamp(x, y, h, colour))
			"acacias":
				_slots(x0, spacing, sd, 0.3, func(x, r, _i): _acacia(x, y, h * (0.7 + 0.4 * r), colour, r))
			"blossoms":
				_slots(x0, spacing, sd, 0.15, func(x, r, i): _blossom(x, y, h * (0.7 + 0.4 * r), colour.darkened(0.1 * Scenery._hash(i + 5, sd)), i, sd))

	## Calls `item(x, r, i)` for each slot starting in this chunk, skipping
	## a share `skip` of them; `r` is the slot's random 0..1. An item belongs
	## to the chunk its slot starts in, so none is drawn twice.
	func _slots(x0: float, spacing: float, sd: float, skip: float, item: Callable) -> void:
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var slot_x := i * spacing
			if slot_x < x0 or slot_x >= x0 + CHUNK:
				continue
			var r := Scenery._hash(i, sd)
			if r < skip:
				continue
			item.call(slot_x - x0 + spacing * 0.5 * Scenery._hash(i + 7, sd), r, i)

	func _hills(x0: float, y: float, h: float, wavelength: float, sd: float, colour: Color, size: Vector2) -> void:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= CHUNK + 0.5:
			pts.append(Vector2(x, y - h * (0.5 + 0.5 * Scenery._noise((x0 + x) / wavelength, sd))))
			x += 16.0
		# Overlap the neighbours by a pixel so no seam shows between chunks.
		pts[0] = Vector2(-1.0, pts[0].y)
		pts[pts.size() - 1] = Vector2(CHUNK + 1.0, pts[pts.size() - 1].y)
		pts.append(Vector2(CHUNK + 1.0, size.y))
		pts.append(Vector2(-1.0, size.y))
		draw_colored_polygon(pts, colour)

	func _water(x0: float, y: float, h: float, sd: float, colour: Color) -> void:
		draw_rect(Rect2(-1.0, y, CHUNK + 2.0, h), colour)
		var shimmer := Color(1, 1, 1, 0.35)
		var spacing := 38.0
		var t := scenery.time()
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var r := Scenery._hash(i, sd)
			var x := i * spacing - x0
			var ly := y + h * (0.15 + 0.7 * r)
			var a := 0.5 + 0.5 * sin(t * 1.5 + r * TAU)
			draw_line(Vector2(x, ly), Vector2(x + 10 + 14 * r, ly), Color(shimmer, shimmer.a * a), 2.0)
		if layer.get("foam", false):
			# Surf rolling up the sand, in and out.
			var pts := PackedVector2Array()
			var x := 0.0
			var reach := sin(t * 0.8) * 4.0
			while x <= CHUNK + 0.5:
				pts.append(Vector2(x, y + h - 3.0 + reach + 3.0 * Scenery._noise((x0 + x) / 90.0, sd + t * 0.05)))
				x += 12.0
			draw_polyline(pts, Color(1, 1, 1, 0.8), 4.0, true)

	func _ground(x0: float, y: float, h: float, sd: float, colour: Color, size: Vector2) -> void:
		# A bank with a gently uneven top edge, then the path.
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= CHUNK + 0.5:
			pts.append(Vector2(x, y - 6.0 * Scenery._noise((x0 + x) / 220.0, sd)))
			x += 16.0
		pts[0] = Vector2(-1.0, pts[0].y)
		pts[pts.size() - 1] = Vector2(CHUNK + 1.0, pts[pts.size() - 1].y)
		pts.append(Vector2(CHUNK + 1.0, size.y))
		pts.append(Vector2(-1.0, size.y))
		draw_colored_polygon(pts, colour)
		var py := scenery.path_y()
		var path_colour := Color.from_string(layer.get("path", "#d9c49a"), Color.TAN)
		draw_rect(Rect2(-1.0, py - h * 0.1, CHUNK + 2.0, h * 0.2), path_colour)
		if layer.get("craters", false):
			for i in range(floori(x0 / 140.0), floori((x0 + CHUNK) / 140.0) + 1):
				var r := Scenery._hash(i, sd + 3.0)
				var c := Vector2(i * 140.0 - x0 + 60.0 * r, y + h * (0.12 + 0.75 * Scenery._hash(i, sd + 8.0)))
				if absf(c.y - py) < h * 0.12:
					continue
				draw_set_transform(c, 0.0, Vector2(1.0, 0.35))
				draw_circle(Vector2.ZERO, 10.0 + 22.0 * r, colour.darkened(0.12), true, -1.0, true)
				draw_circle(Vector2(0, 3), 8.0 + 18.0 * r, colour.darkened(0.2), true, -1.0, true)
				draw_set_transform(Vector2.ZERO)
		# Pebbles on the path so movement reads even with flat placeholder art.
		var spacing := 54.0
		for i in range(floori(x0 / spacing), floori((x0 + CHUNK) / spacing) + 1):
			var r := Scenery._hash(i, sd + 11.0)
			draw_circle(Vector2(i * spacing - x0 + 20.0 * r, py - h * 0.08 + h * 0.16 * Scenery._hash(i, sd + 5.0)), 2.0 + 3.0 * r, path_colour.darkened(0.15))

	func _reed_tuft(x: float, top: float, h: float, colour: Color, r: float, size: Vector2) -> void:
		var sway := sin(scenery.time() * 1.2 + r * 6.0) * 6.0
		for k in 3:
			var bx := x + k * 6.0
			draw_line(Vector2(bx, size.y), Vector2(bx + sway + (k - 1) * 5.0, top - h), colour.darkened(0.1 * k), 3.0, true)

	## A broad leaf on a stem, bending in the breeze (forest and jungle floor).
	func _frond(x: float, h: float, colour: Color, r: float, size: Vector2) -> void:
		var sway := sin(scenery.time() * 1.1 + r * 5.0) * 0.12
		for k in 3:
			var angle := -PI * 0.5 + (k - 1) * 0.55 + sway
			var tip := Vector2(x, size.y) + Vector2(cos(angle), sin(angle)) * h
			var mid := Vector2(x, size.y).lerp(tip, 0.55)
			var side := Vector2(-sin(angle), cos(angle)) * h * 0.16
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), mid + side, tip, mid - side]), colour.darkened(0.08 * k))

	func _tree(x: float, y: float, th: float, colour: Color) -> void:
		var w := th * 0.38
		draw_rect(Rect2(x - w * 0.07, y - th * 0.25, w * 0.14, th * 0.3), colour.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, y - th * 0.2), Vector2(x, y - th), Vector2(x + w * 0.5, y - th * 0.2)]), colour)

	## A tall, layered conifer, with snow on its tiers in the tundra.
	func _pine(x: float, y: float, th: float, colour: Color, snow: bool) -> void:
		var w := th * 0.42
		draw_rect(Rect2(x - w * 0.06, y - th * 0.18, w * 0.12, th * 0.2), colour.darkened(0.4))
		for k in 3:
			var top := y - th * (0.45 + 0.27 * k) - th * 0.1
			var bottom := y - th * (0.12 + 0.24 * k)
			var half := w * (0.5 - 0.12 * k)
			draw_colored_polygon(PackedVector2Array([Vector2(x - half, bottom), Vector2(x, top), Vector2(x + half, bottom)]), colour)
			if snow:
				var s := Color(0.95, 0.97, 1.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - half * 0.45, top + (bottom - top) * 0.45), Vector2(x, top), Vector2(x + half * 0.45, top + (bottom - top) * 0.45)]), s)

	## A round-topped deciduous tree.
	func _broadleaf(x: float, y: float, th: float, colour: Color) -> void:
		draw_rect(Rect2(x - th * 0.04, y - th * 0.45, th * 0.08, th * 0.45), colour.darkened(0.45))
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			draw_circle(Vector2(x, y - th * 0.7) + Vector2(cos(a), sin(a) * 0.6) * th * 0.13, th * 0.22, colour.darkened(0.06 * k), true, -1.0, true)
		draw_circle(Vector2(x, y - th * 0.82), th * 0.2, colour.lightened(0.05), true, -1.0, true)

	## Dense jungle: big overlapping leaf clusters with vines hanging down.
	func _canopy(x: float, y: float, th: float, colour: Color, i: int, sd: float) -> void:
		draw_rect(Rect2(x - th * 0.035, y - th * 0.6, th * 0.07, th * 0.6), colour.darkened(0.5))
		for k in 5:
			var a := TAU * k / 5.0 + Scenery._hash(i, sd + 4.0) * 3.0
			var c := Vector2(x, y - th * 0.78) + Vector2(cos(a) * th * 0.22, sin(a) * th * 0.1)
			draw_circle(c, th * (0.16 + 0.05 * Scenery._hash(i + k, sd)), colour.darkened(0.07 * (k % 3)), true, -1.0, true)
		for k in 2:
			var vx := x + (k - 0.5) * th * 0.3
			draw_line(Vector2(vx, y - th * 0.72), Vector2(vx + 4.0, y - th * (0.3 + 0.15 * k)), colour.lightened(0.15), 2.0, true)

	func _palm(x: float, y: float, th: float, colour: Color, r: float) -> void:
		var lean := (r - 0.5) * th * 0.25
		var top := Vector2(x + lean, y - th)
		var trunk := PackedVector2Array()
		for k in 9:
			var t := k / 8.0
			trunk.append(Vector2(x, y).lerp(top, t) + Vector2(sin(t * PI) * th * 0.05, 0))
		draw_polyline(trunk, Color("#8a6a45"), maxf(3.0, th * 0.05), true)
		for k in 7:
			var angle := -PI + PI * k / 6.0 + 0.15 * sin(scenery.time() * 0.6 + r * 4.0)
			# Each frond arcs up then droops at the tip.
			var dir := Vector2(cos(angle), sin(angle) * 0.45 + 0.3)
			var tip := top + dir * th * 0.36 + Vector2(0, th * 0.08)
			var mid := top + dir * th * 0.2 + Vector2(0, -th * 0.05)
			# A thick curved stroke rather than a filled shape: at some angles
			# a four-point leaf folds over itself and can't be filled.
			var shade := colour.darkened(0.08 * (k % 2))
			draw_polyline(PackedVector2Array([top, mid, tip]), shade, th * 0.075, true)
			draw_polyline(PackedVector2Array([top.lerp(mid, 0.5), mid, mid.lerp(tip, 0.6)]), shade, th * 0.11, true)
		draw_circle(top, th * 0.035, Color("#6b4f33"), true, -1.0, true)

	func _mountain(x: float, y: float, th: float, w: float, colour: Color, snow: bool) -> void:
		var peak := Vector2(x, y - th)
		draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.6, y + 2.0), peak, Vector2(x + w * 0.6, y + 2.0)]), colour)
		draw_colored_polygon(PackedVector2Array([peak, Vector2(x + w * 0.6, y + 2.0), Vector2(x + w * 0.12, y + 2.0)]), colour.darkened(0.1))
		if snow:
			var s := Color(0.96, 0.98, 1.0)
			var k := 0.3
			# A jagged lower edge, with every point inside the slopes so the
			# outline never crosses itself.
			draw_colored_polygon(PackedVector2Array([
				peak, peak + Vector2(w * 0.6 * k, th * k), peak + Vector2(w * 0.1, th * k * 0.8),
				peak + Vector2(0, th * k), peak + Vector2(-w * 0.08, th * k * 0.78), peak + Vector2(-w * 0.6 * k, th * k)]), s)

	## A flat-topped desert rock.
	func _mesa(x: float, y: float, th: float, w: float, colour: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.7, y + 2.0), Vector2(x - w * 0.45, y - th), Vector2(x + w * 0.45, y - th), Vector2(x + w * 0.7, y + 2.0)]), colour)
		draw_rect(Rect2(x - w * 0.45, y - th, w * 0.9, th * 0.12), colour.lightened(0.12))
		draw_rect(Rect2(x - w * 0.6, y - th * 0.45, w * 1.2, th * 0.06), colour.darkened(0.12))

	func _cactus(x: float, y: float, th: float, colour: Color, r: float) -> void:
		var w := th * 0.16
		var body := UI.box(colour, Color.TRANSPARENT, int(w * 0.5))
		draw_style_box(body, Rect2(x - w * 0.5, y - th, w, th))
		var arm_y := y - th * (0.45 + 0.2 * r)
		draw_style_box(body, Rect2(x - w * 1.5, arm_y - th * 0.3, w * 0.7, th * 0.32))
		draw_rect(Rect2(x - w * 1.5, arm_y - w * 0.35, w * 1.2, w * 0.6), colour)
		draw_style_box(body, Rect2(x + w * 0.8, arm_y - th * 0.15, w * 0.7, th * 0.25))
		draw_rect(Rect2(x + w * 0.3, arm_y + th * 0.02, w * 1.2, w * 0.6), colour)

	## Rolling farmland: hills striped with rows of crops, a shade either side.
	func _fields(x0: float, y: float, h: float, wavelength: float, sd: float, colour: Color, size: Vector2) -> void:
		_hills(x0, y, h, wavelength, sd, colour, size)
		var stripe := colour.darkened(0.12)
		var x := -fposmod(x0, 28.0)
		while x < CHUNK:
			var top := y - h * (0.5 + 0.5 * Scenery._noise((x0 + x) / wavelength, sd))
			draw_line(Vector2(x, top + 3.0), Vector2(x - 40.0, size.y), stripe, 5.0, true)
			x += 28.0

	## A red barn with a white-trimmed door, and now and then a silo beside it.
	func _barn(x: float, y: float, th: float, colour: Color, i: int) -> void:
		var w := th * 1.1
		var trim := Color("#f4efe2")
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, y + 2.0), Vector2(x - w * 0.5, y - th * 0.6), Vector2(x, y - th),
			Vector2(x + w * 0.5, y - th * 0.6), Vector2(x + w * 0.5, y + 2.0)]), colour)
		draw_polyline(PackedVector2Array([Vector2(x - w * 0.55, y - th * 0.58), Vector2(x, y - th - 2.0), Vector2(x + w * 0.55, y - th * 0.58)]), colour.darkened(0.35), maxf(2.0, th * 0.06), true)
		var door := Rect2(x - w * 0.16, y - th * 0.42, w * 0.32, th * 0.42)
		draw_rect(door, colour.darkened(0.25))
		draw_rect(door, trim, false, 2.0)
		draw_line(door.position, door.end, trim, 2.0, true)
		draw_line(Vector2(door.position.x, door.end.y), Vector2(door.end.x, door.position.y), trim, 2.0, true)
		if i % 2 == 0:
			var silo := UI.box(Color("#b9b4a8"), Color.TRANSPARENT, int(w * 0.12))
			draw_style_box(silo, Rect2(x + w * 0.56, y - th * 1.1, w * 0.26, th * 1.1 + 2.0))
			draw_circle(Vector2(x + w * 0.69, y - th * 1.08), w * 0.13, Color("#8e8a80"), true, -1.0, true)

	## A post-and-rail fence along the far side of the path.
	func _fence(x0: float, y: float, h: float, spacing: float, colour: Color) -> void:
		var top := y - h
		for k in 2:
			var ry := top + h * (0.2 + 0.4 * k)
			draw_line(Vector2(-1.0, ry), Vector2(CHUNK + 1.0, ry), colour, maxf(2.0, h * 0.16), true)
		var x := -fposmod(x0, spacing)
		while x <= CHUNK:
			draw_rect(Rect2(x - h * 0.09, top - h * 0.1, h * 0.18, h * 1.1), colour.darkened(0.15))
			x += spacing

	## A block of flats or an office: flat roof, rows of windows, and the
	## windows lit warm after dark.
	func _building(x: float, y: float, th: float, w: float, colour: Color, i: int, sd: float) -> void:
		draw_rect(Rect2(x - w * 0.5, y - th, w, th + 2.0), colour)
		draw_rect(Rect2(x - w * 0.5, y - th, w, maxf(2.0, th * 0.03)), colour.lightened(0.12))
		var cols := maxi(2, floori(w / 14.0))
		var rows := maxi(2, floori(th / 18.0))
		var cell := Vector2(w / cols, th / rows)
		for r in rows - 1:
			for c in cols:
				var lit := Scenery._hash(i * 97 + r * 13 + c, sd + 3.0)
				var glass := colour.lightened(0.22)
				if scenery._lights_on and lit > 0.45:
					glass = Color("#f5d77a")
				draw_rect(Rect2(x - w * 0.5 + c * cell.x + cell.x * 0.28, y - th + (r + 0.6) * cell.y, cell.x * 0.44, cell.y * 0.45), glass)

	## A street lamp: a thin post with a lantern that glows after dark.
	func _lamp(x: float, y: float, h: float, colour: Color) -> void:
		draw_line(Vector2(x, y + 2.0), Vector2(x, y - h), colour, maxf(2.0, h * 0.04), true)
		draw_line(Vector2(x, y - h), Vector2(x + h * 0.12, y - h - h * 0.04), colour, maxf(2.0, h * 0.035), true)
		var lantern := Vector2(x + h * 0.14, y - h + h * 0.02)
		if scenery._lights_on:
			draw_circle(lantern, h * 0.16, Color(1.0, 0.9, 0.55, 0.2), true, -1.0, true)
		draw_circle(lantern, h * 0.045, Color("#f5d77a") if scenery._lights_on else colour.lightened(0.3), true, -1.0, true)

	## A flat-topped savanna tree on a thin, forking trunk.
	func _acacia(x: float, y: float, th: float, colour: Color, r: float) -> void:
		var trunk := colour.darkened(0.45)
		var top := Vector2(x + (r - 0.5) * th * 0.2, y - th * 0.78)
		draw_line(Vector2(x, y + 2.0), top, trunk, maxf(2.0, th * 0.05), true)
		draw_line(top.lerp(Vector2(x, y), 0.35), top + Vector2(-th * 0.25, -th * 0.04), trunk, maxf(1.5, th * 0.03), true)
		draw_line(top.lerp(Vector2(x, y), 0.25), top + Vector2(th * 0.28, 0), trunk, maxf(1.5, th * 0.03), true)
		var w := th * 0.75
		for k in 5:
			var t := k / 4.0
			draw_circle(top + Vector2((t - 0.5) * w, -th * 0.05 - sin(t * PI) * th * 0.06), th * 0.12, colour.darkened(0.06 * (k % 2)), true, -1.0, true)
		_ellipse_flat(top + Vector2(0, -th * 0.06), Vector2(w * 0.56, th * 0.08), colour)

	## A cherry tree: a dark crooked trunk under a pink cloud of blossom.
	func _blossom(x: float, y: float, th: float, colour: Color, i: int, sd: float) -> void:
		var bark := Color("#5a3b35")
		var lean := (Scenery._hash(i, sd + 8.0) - 0.5) * th * 0.18
		var fork := Vector2(x + lean, y - th * 0.5)
		draw_line(Vector2(x, y + 2.0), fork, bark, maxf(2.0, th * 0.06), true)
		draw_line(fork, fork + Vector2(-th * 0.16, -th * 0.18), bark, maxf(1.5, th * 0.035), true)
		draw_line(fork, fork + Vector2(th * 0.18, -th * 0.16), bark, maxf(1.5, th * 0.035), true)
		for k in 6:
			var a := TAU * k / 6.0 + Scenery._hash(i, sd) * 2.0
			var c := fork + Vector2(0, -th * 0.22) + Vector2(cos(a) * th * 0.2, sin(a) * th * 0.11)
			draw_circle(c, th * (0.13 + 0.04 * Scenery._hash(i + k, sd)), colour.darkened(0.05 * (k % 3)), true, -1.0, true)
		draw_circle(fork + Vector2(0, -th * 0.3), th * 0.15, colour.lightened(0.12), true, -1.0, true)

	func _ellipse_flat(c: Vector2, radius: Vector2, colour: Color) -> void:
		var pts := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			pts.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		draw_colored_polygon(pts, colour)

	## A low mound along the bottom edge (snow drifts, moon dust).
	## Whether something at `x` (this chunk's space), `reach` wide either
	## side, would stand in the scenery's front_gap.
	func _in_gap(x: float, reach: float) -> bool:
		var gap := scenery.front_gap
		if gap.y <= gap.x:
			return false
		var at := position.x + x
		return at + reach > gap.x and at - reach < gap.y

	## A leaf from `base` along `angle`, `length` long and `width` across at
	## its widest, curving sideways by `bend` (a share of its length). Both
	## edges run steadily from base to tip, so the outline never crosses.
	func _leaf(base: Vector2, angle: float, length: float, width: float, bend: float, colour: Color) -> void:
		var dir := Vector2(cos(angle), sin(angle))
		var side := Vector2(-dir.y, dir.x)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var spine := PackedVector2Array([base])
		for k in range(1, 8):
			var t := k / 8.0
			var c := base + dir * length * t + side * length * bend * t * t
			var half := width * 0.5 * sin(t * PI) * (1.0 - 0.25 * t)
			left.append(c + side * half)
			right.append(c - side * half)
			spine.append(c)
		var tip := base + dir * length + side * length * bend
		spine.append(tip)
		var pts := PackedVector2Array([base])
		pts.append_array(left)
		pts.append(tip)
		right.reverse()
		pts.append_array(right)
		draw_colored_polygon(pts, colour)
		draw_polyline(spine, colour.lightened(0.16), maxf(1.0, width * 0.05), true)

	## A clump of big leaves fanning up from the bottom edge.
	func _undergrowth(x: float, bottom: float, h: float, colour: Color, r: float) -> void:
		var t := scenery.time()
		var count := 4 + int(r * 3.0)
		for k in count:
			var share := (k + 0.5) / count - 0.5
			var sway := sin(t * 0.9 + r * 5.0 + k * 1.3) * 0.06
			var length := h * (0.75 + 0.35 * Scenery._hash(k, r * 10.0))
			_leaf(Vector2(x + share * h * 0.5, bottom + h * 0.08), -PI * 0.5 + share * 1.9 + sway, length, length * 0.4, share * 0.25,
				colour.darkened(0.08 * (k % 2)))

	## A vine hanging from the top edge with leaves down its length.
	func _vine(x: float, top: float, length: float, colour: Color, r: float) -> void:
		var sway := sin(scenery.time() * 0.7 + r * 4.0) * length * 0.05
		var pts := PackedVector2Array()
		for k in 13:
			var t := k / 12.0
			pts.append(Vector2(x + sin(t * 3.0 + r * 6.0) * length * 0.05 + sway * t * t, top - 2.0 + length * t))
		draw_polyline(pts, colour.darkened(0.2), maxf(2.0, length * 0.012), true)
		var leaf := clampf(length * 0.14, 14.0, 48.0)
		for k in range(2, 13, 2):
			var out := 1.0 if k % 4 == 0 else -1.0
			_leaf(pts[k], PI * 0.5 - out * 0.95, leaf, leaf * 0.48, out * 0.1, colour.darkened(0.06 * (k % 3)))
		_leaf(pts[12], PI * 0.5 + 0.3, leaf * 1.1, leaf * 0.5, -0.08, colour)
		_leaf(pts[12], PI * 0.5 - 0.35, leaf, leaf * 0.48, 0.08, colour.darkened(0.08))

	## A tall leafy plant growing up from the bottom edge, close enough to
	## pass in front of the walker (but never inside the front_gap).
	func _stalk(x: float, bottom: float, h: float, colour: Color, r: float) -> void:
		if _in_gap(x, h * 0.45):
			return
		var lean := (r - 0.5) * h * 0.3 + sin(scenery.time() * 0.8 + r * 5.0) * h * 0.03
		var stem := PackedVector2Array()
		for k in 11:
			var t := k / 10.0
			stem.append(Vector2(x + lean * t * t, bottom + 10.0 - (h + 10.0) * t))
		draw_polyline(stem, colour.darkened(0.15), maxf(4.0, h * 0.025), true)
		for k in 4:
			var at := stem[3 + k * 2]
			var out := 1.0 if k % 2 == 0 else -1.0
			var length := h * (0.34 - 0.04 * k)
			_leaf(at, -PI * 0.5 + out * (1.15 - 0.1 * k), length, length * 0.42, out * 0.14, colour.darkened(0.05 * k))
		_leaf(stem[10], -PI * 0.5 + (r - 0.5) * 0.5, h * 0.22, h * 0.09, 0.05, colour)

	func _drift(x: float, bottom: float, h: float, colour: Color) -> void:
		draw_set_transform(Vector2(x, bottom), 0.0, Vector2(1.0, h / 40.0))
		draw_circle(Vector2.ZERO, 40.0, colour, true, -1.0, true)
		draw_circle(Vector2(34, 8), 30.0, colour, true, -1.0, true)
		draw_set_transform(Vector2.ZERO)



## The sky behind everything, with the sun or moon on its way across:
## redrawn only when the size or the light changes (every few seconds). A
## place with its own sky (the Moon) keeps it whatever the time.
class _Sky extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var size := scenery.size
		var sky: Dictionary = scenery.biome.get("sky", {})
		var light := scenery._light
		var top: Color = Color.from_string(sky["top"], Color.BLACK) if sky.has("top") else light.get("sky_top", Color("#8ec3e6"))
		var bottom: Color = Color.from_string(sky["bottom"], Color.BLACK) if sky.has("bottom") else light.get("sky_bottom", Color("#d7ecf6"))
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
		var glow := float(light.get("glow", 1.0))
		if not sky.has("top") and glow > 0.01:
			var r := clampf(size.y * 0.045, 16.0, 40.0)
			if float(light.get("sun", -1.0)) >= 0.0:
				_sun(_on_arc(float(light["sun"]), r, size), r, float(light["sun"]), glow)
			if float(light.get("moon", -1.0)) >= 0.0:
				_moon(_on_arc(float(light["moon"]), r, size), r * 0.8, glow)
		for layer in scenery.biome.get("layers", []):
			if layer["kind"] == "planet":
				_planet(Vector2(size.x * 0.72, size.y * float(layer["y"])), size.y * float(layer["height"]), Color.from_string(layer["colour"], Color.ROYAL_BLUE))

	## Where something `progress` of the way across the sky is: it comes up
	## from behind the furthest hills on the left, peaks in the middle (below
	## the words at the top of the screen) and goes down behind them on the
	## right.
	func _on_arc(progress: float, r: float, size: Vector2) -> Vector2:
		var horizon := scenery.horizon_y()
		var high := minf(size.y * 0.2 + r, horizon - r * 2.0)
		return Vector2(lerpf(size.x * 0.06, size.x * 0.94, progress), lerpf(horizon + r * 1.2, high, sin(progress * PI)))

	## Warm and orange near the horizon, pale yellow when it's high; `glow`
	## is how much shows through the cloud.
	func _sun(c: Vector2, r: float, progress: float, glow: float) -> void:
		var high := sin(progress * PI)
		var colour := Color("#ff9b54").lerp(Color("#fff3b0"), clampf(high * 1.6, 0.0, 1.0))
		draw_circle(c, r * 3.2, Color(colour, 0.08 * glow), true, -1.0, true)
		draw_circle(c, r * 1.9, Color(colour, 0.16 * glow), true, -1.0, true)
		draw_circle(c, r, Color(colour, glow), true, -1.0, true)

	func _moon(c: Vector2, r: float, glow: float) -> void:
		var colour := Color("#f2efe0")
		draw_circle(c, r * 2.6, Color(colour, 0.06 * glow), true, -1.0, true)
		draw_circle(c, r * 1.6, Color(colour, 0.1 * glow), true, -1.0, true)
		draw_circle(c, r, Color(colour, glow), true, -1.0, true)
		var shade := Color("#cfcab6", glow)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.22, shade, true, -1.0, true)
		draw_circle(c + Vector2(r * 0.35, r * 0.15), r * 0.16, shade, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.05, r * 0.45), r * 0.12, shade, true, -1.0, true)

	## A big blue planet hanging still in the sky (the Earth, seen from the Moon).
	func _planet(c: Vector2, r: float, colour: Color) -> void:
		draw_circle(c, r * 1.25, Color(colour, 0.12), true, -1.0, true)
		draw_circle(c, r, colour, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.35, Color("#5fa65a"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.35, r * 0.3), r * 0.28, Color("#5fa65a"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.1, -r * 0.55), r * 0.25, Color(1, 1, 1, 0.75), true, -1.0, true)
		draw_arc(c, r * 0.8, PI * 0.1, PI * 0.9, 16, Color(0, 0, 0, 0.18), r * 0.45, true)


## Clouds drifting across the sky: in front of the sun and moon, behind the
## hills. A few white puffs on a fair day; more, greyer and under a dull
## blanket as it clouds over; dark and quick in a storm.
class _Clouds extends Node2D:
	var scenery: Scenery

	func _process(_delta: float) -> void:
		if int(scenery._look.get("clouds", 0)) > 0:
			queue_redraw()

	func _draw() -> void:
		var look := scenery._look
		var count := int(look.get("clouds", 0))
		if count <= 0:
			return
		var size := scenery.size
		var o := float(look.get("overcast", 0.0))
		var t := scenery.time()
		var unit := minf(size.x, size.y) / 720.0
		var colour := Color.WHITE.lerp(Color(0.6, 0.63, 0.68), clampf((o - 0.3) / 0.6, 0.0, 1.0)) * scenery.tint()
		if o >= 0.4:
			var a := (o - 0.3) * 0.9
			var low := scenery.horizon_y()
			draw_polygon(
				PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, low), Vector2(0, low)]),
				PackedColorArray([Color(colour, a), Color(colour, a), Color(colour, 0.0), Color(colour, 0.0)]))
		var wind := 1.0 + float(look.get("wind", 0.0)) * 2.5
		var span := size.x + 400.0 * unit
		for i in count:
			var s := (0.6 + 0.7 * Scenery._hash(i, 21.0)) * unit
			var speed := (6.0 + 10.0 * Scenery._hash(i, 22.0)) * wind * unit
			var x := fposmod(Scenery._hash(i, 23.0) * span + t * speed + scenery.scroll * 0.02, span) - 200.0 * unit
			var y := scenery.horizon_y() * (0.08 + 0.62 * Scenery._hash(i, 24.0))
			_cloud(Vector2(x, y), s, colour.darkened(0.1 * Scenery._hash(i, 25.0)))

	## One cloud: overlapping puffs on a flat base.
	func _cloud(at: Vector2, s: float, colour: Color) -> void:
		for p in [[-60, 0, 30], [-24, -18, 42], [20, -22, 46], [58, -4, 34], [0, -10, 40]]:
			draw_circle(at + Vector2(p[0], p[1]) * s, p[2] * s, colour, true, -1.0, true)
		draw_rect(Rect2(at + Vector2(-60, 0) * s, Vector2(118, 30) * s), colour)


## Weather on top of the scenery: stars coming out as it gets dark (unless
## it's cloudy), fireflies at dusk and overnight, the tundra's snow and
## wind, and the real weather's rain, lightning, snow and white-outs. A few
## hundred dots and lines a frame at most.
class _Fx extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var fx: Array = scenery.biome.get("fx", [])
		var size := scenery.size
		var t := scenery.time()
		var dark := scenery.darkness()
		var look := scenery._look
		# Stars fade in from dusk, the brightest first, unless it's cloudy.
		var stars := clampf((dark - 0.3) / 0.6, 0.0, 1.0) * (1.0 - float(look.get("overcast", 0.0)))
		if fx.has("stars") and stars > 0.0:
			for i in 70:
				var bright := Scenery._hash(i, 3.0)
				var shown := clampf(stars * 2.0 - (1.0 - bright), 0.0, 1.0)
				if shown <= 0.0:
					continue
				var at := Vector2(Scenery._hash(i, 1.0) * size.x, Scenery._hash(i, 2.0) * size.y * 0.45)
				var twinkle := 0.5 + 0.5 * sin(t * 2.0 + i)
				draw_circle(at, 1.0 + bright * 1.2, Color(1, 1, 0.9, (0.4 + 0.5 * twinkle) * shown))
		var flies := clampf((dark - 0.15) / 0.4, 0.0, 1.0)
		if fx.has("fireflies") and flies > 0.0:
			for i in 18:
				var base := Vector2(Scenery._hash(i, 4.0) * size.x, size.y * (0.6 + 0.3 * Scenery._hash(i, 5.0)))
				var drift := Vector2(sin(t * 0.6 + i) * 18.0, cos(t * 0.8 + i * 1.3) * 12.0)
				var glow := (0.4 + 0.6 * absf(sin(t * 1.3 + i * 2.1))) * flies
				draw_circle(base + drift, 6.0, Color(1.0, 0.92, 0.5, 0.15 * glow))
				draw_circle(base + drift, 2.2, Color(1.0, 0.95, 0.6, glow))
		# Cherry blossom petals drifting down and across.
		if fx.has("petals"):
			var petal := Color("#f6c6d4") * Color(scenery.tint(), 1.0)
			for i in 40:
				var fall := fposmod(Scenery._hash(i, 21.0) * size.y + t * (24.0 + 20.0 * Scenery._hash(i, 22.0)), size.y + 20.0) - 10.0
				var x := fposmod(Scenery._hash(i, 23.0) * size.x - t * 30.0 + sin(t * 1.2 + i) * 16.0, size.x + 20.0) - 10.0
				var spin := t * 2.0 + i
				draw_set_transform(Vector2(x, fall), spin, Vector2(1.0, 0.55 + 0.45 * absf(sin(spin))))
				draw_circle(Vector2.ZERO, 3.2, petal, true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
		var gust := 0.6 + 0.4 * sin(t * 0.45)
		var area := clampf(size.x * size.y / (720.0 * 720.0), 0.5, 3.0)
		var unit := minf(size.x, size.y) / 720.0
		var wind := float(look.get("wind", 0.0)) + (0.6 if fx.has("wind") else 0.0)
		var light := scenery.tint()
		if bool(look.get("lightning", false)):
			_lightning(size)
		# Rain slants with the wind, in long quick streaks.
		var drops := int(int(look.get("rain", 0)) * area)
		var slant := 0.12 + 0.3 * wind
		var rain := Color(0.82, 0.88, 1.0, 0.42) * Color(light, 1.0)
		for i in drops:
			var speed := 760.0 + 320.0 * Scenery._hash(i, 14.0)
			var length := (14.0 + 16.0 * Scenery._hash(i, 15.0)) * unit
			var y := fposmod(Scenery._hash(i, 16.0) * size.y + t * speed * unit, size.y + length * 2.0) - length
			var x := fposmod(Scenery._hash(i, 17.0) * size.x * 1.3 - y * slant, size.x + 40.0) - 20.0
			draw_line(Vector2(x, y), Vector2(x + length * slant, y - length), rain, 1.4, true)
		# Snow: the tundra's own flurries, or the weather's. Flakes fall and
		# are blown sideways, harder in the gusts.
		var flakes := int(maxi(90 if fx.has("snow") else 0, int(look.get("snow", 0))) * area)
		var flake := Color(1, 1, 1, 0.85) * Color(light.lightened(0.3), 1.0)
		for i in flakes:
			var speed := (30.0 + 50.0 * Scenery._hash(i, 6.0)) * (1.0 + wind * 0.5)
			var fall := fposmod(Scenery._hash(i, 7.0) * size.y + t * speed, size.y + 20.0) - 10.0
			var blown := fposmod(Scenery._hash(i, 8.0) * size.x - t * (20.0 + 120.0 * wind * gust) - fall * 0.6 * wind, size.x + 20.0) - 10.0
			draw_circle(Vector2(blown, fall), 1.2 + 2.0 * Scenery._hash(i, 9.0), flake)
		if wind >= 0.5:
			for i in int(6 + 8 * wind):
				var speed := 380.0 + 260.0 * Scenery._hash(i, 10.0)
				var x := size.x - fposmod(Scenery._hash(i, 11.0) * size.x * 2.0 + t * speed * (0.6 + wind * 0.5), size.x * 2.0)
				var y := size.y * (0.15 + 0.7 * Scenery._hash(i, 12.0)) + sin(t * 2.0 + i) * 6.0
				var length := 60.0 + 90.0 * Scenery._hash(i, 13.0)
				draw_line(Vector2(x, y), Vector2(x + length, y - 4.0), Color(1, 1, 1, 0.25 * gust * minf(1.0, wind)), 1.5, true)
		# A blizzard whites everything out, more in the gusts.
		var haze := float(look.get("haze", 0.0))
		if haze > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.94, 0.96, 1.0, haze * (0.7 + 0.3 * gust)) * Color(light.lightened(0.4), 1.0))

	## The flash lights up the whole scene; the bolt forks down from the
	## clouds for a moment.
	func _lightning(size: Vector2) -> void:
		if scenery._bolt >= 0:
			var k := scenery._bolt
			var at := Vector2(size.x * (0.15 + 0.7 * Scenery._hash(k, 34.0)), 0.0)
			var bolt := PackedVector2Array([at])
			var low := scenery.horizon_y()
			for j in range(1, 9):
				at = Vector2(at.x + (Scenery._hash(k * 9 + j, 35.0) - 0.5) * size.x * 0.06, low * j / 8.0)
				bolt.append(at)
			draw_polyline(bolt, Color(1, 1, 1, 0.35), 7.0, true)
			draw_polyline(bolt, Color(1, 1, 0.92, 0.95), 2.5, true)
		if scenery._flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.94, 1.0, scenery._flash * 0.55))
