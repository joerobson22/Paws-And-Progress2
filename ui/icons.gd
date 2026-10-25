class_name Icons
extends RefCounted
## Line icons from the mockups, kept as SVG path data and rasterised on demand
## at the size and colour asked for, so they stay crisp at any UI scale.

## 24x24 viewBox paths. "fill:" marks a filled icon; the rest are 2px strokes.
## Pass `stroke` to texture() for a bolder or lighter line.
const PATHS := {
	"back": "M15 5l-7 7 7 7",
	"forward": "M9 5l7 7-7 7",
	"play": "fill:M7 4l13 8-13 8z",
	"pause": "fill:M6 4h4v16H6zM14 4h4v16h-4z",
	"plus": "M12 5v14M5 12h14",
	"check": "M5 12l5 5 9-10",
	"clock": "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM12 7v5l3.5 2.5",
	"trophy": "M8 4h8v5a4 4 0 0 1-8 0zM8 6H5a3 3 0 0 0 3.2 4M16 6h3a3 3 0 0 1-3.2 4M12 13v4M8.5 20h7M10 17h4v3h-4z",
	"paw": "fill:M6.5 6.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0-4.4zM12 3.6a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0-4.4zM17.5 6.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0-4.4zM7.5 17.5c0-3.2 2.2-5.5 4.5-5.5s4.5 2.3 4.5 5.5c0 2-2 3-4.5 3s-4.5-1-4.5-3z",
	"flame": "M12 3c1 4 6 6 6 11a6 6 0 0 1-12 0c0-3 2-4 2-7 2 1 3 2 3 4 1-2 1-5 1-8z",
	"sound": "M4 9v6h4l5 4V5L8 9zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12",
	"mute": "M4 9v6h4l5 4V5L8 9zM17 9l5 6M22 9l-5 6",
	"gear": "M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6zM19.4 13.1a7.6 7.6 0 0 0 0-2.2l2-1.6-2-3.4-2.4.9a7.4 7.4 0 0 0-1.9-1.1L14.8 3h-3.6l-.4 2.7a7.4 7.4 0 0 0-1.9 1.1l-2.4-.9-2 3.4 2 1.6a7.6 7.6 0 0 0 0 2.2l-2 1.6 2 3.4 2.4-.9a7.4 7.4 0 0 0 1.9 1.1l.4 2.7h3.6l.4-2.7a7.4 7.4 0 0 0 1.9-1.1l2.4.9 2-3.4z",
	"home": "M4 11l8-7 8 7v9h-5v-6H9v6H4z",
	"walk": "M13 4a1.8 1.8 0 1 0 0 3.6a1.8 1.8 0 1 0 0-3.6zM9 21l2.5-7 2.5 2.5V21M8 12l2.5-3.5h3l2.5 3.5h2M11.5 14l-1-5",
	"gift": "M3 8h18v5H3zM5 13v7h14v-7M12 8v12M12 8C10 4 6 4 6 7c0 1 1 1 6 1zm0 0c2-4 6-4 6-1 0 1-1 1-6 1z",
	"shirt": "M8 3l4 2 4-2 5 4-3 3-2-1v12H8V9l-2 1-3-3z",
	"board": "M3 4h18v14H3zM8 21h8M12 18v3",
	"stats": "M5 20V11M12 20V5M19 20v-6",
	"edit": "M4 20h4L19 9l-4-4L4 16zM14 6l4 4",
	"lock": "M5 11h14v10H5zM8 11V8a4 4 0 0 1 8 0v3",
	"star": "fill:M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z",
	"close": "M6 6l12 12M18 6L6 18",
	"bin": "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3",
	"arrow_right": "M4 12h15M13 6l6 6-6 6",
	"moon": "M19 14.5A7.5 7.5 0 1 1 9.5 5a6 6 0 0 0 9.5 9.5z",
	"user": "M12 4a4 4 0 1 0 0 8a4 4 0 1 0 0-8zM4.5 20c1-3.8 4.2-5.8 7.5-5.8s6.5 2 7.5 5.8",
	"trade": "M5 9h13l-4-4M19 15H6l4 4",
	"sun": "M12 7.6a4.4 4.4 0 1 0 0 8.8a4.4 4.4 0 1 0 0-8.8zM12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6",
	"moon_fill": "fill:M19.5 14.6A8 8 0 1 1 9.4 4.5a6.3 6.3 0 0 0 10.1 10.1z",
	"place_lake": "M3 15c2 0 2-1.5 4.5-1.5S9.5 15 12 15s2.5-1.5 4.5-1.5S19 15 21 15M3 19c2 0 2-1.5 4.5-1.5S9.5 19 12 19s2.5-1.5 4.5-1.5S19 19 21 19M5 11l4-5 3 3 2-2 4 4",
	"place_forest": "M8 3l-4.5 7h3L3 15h10l-3.5-5h3zM8 15v5M16.5 7l-3.5 5.5h2.5L12.5 17h8l-3-4.5h2.5zM16.5 17v3",
	"place_jungle": "M12 21V10M12 10C10 6 6 5 3 6c3 1 5 3 6 5M12 10c2-4 6-5 9-4-3 1-5 3-6 5M12 10c-1-4-4-6-6-7 1 3 4 5 6 7zM12 10c1-4 4-6 6-7-1 3-4 5-6 7z",
	"place_tundra": "M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9M9.5 4.5L12 7l2.5-2.5M9.5 19.5L12 17l2.5 2.5M4 10.5l3.4.9-.9 3.4M20 13.5l-3.4-.9.9-3.4",
	"place_desert": "M10 21V5a2 2 0 0 1 4 0v16M10 13H7a2 2 0 0 1-2-2V8M14 11h3a2 2 0 0 0 2-2V6M4 21h16",
	"place_beach": "M3 20h18M12 20l-2-9M5 11c1-4 4-6 7-6s6 2 7 6c-2-1.5-4.5-1.5-7 0-2.5-1.5-5-1.5-7 0zM17 3.5a1.5 1.5 0 1 0 0 .01",
	"place_moon": "M19.5 14.6A8 8 0 1 1 9.4 4.5a6.3 6.3 0 0 0 10.1 10.1zM9 11a1 1 0 1 0 0 .01M12.5 16a1.5 1.5 0 1 0 0 .01",
	"sort_down": "M6 9l6 6 6-6",
	"sort_up": "M6 15l6-6 6 6",
	"dot": "fill:M12 5.5a6.5 6.5 0 1 0 0 13a6.5 6.5 0 1 0 0-13z",
	"calendar": "M4 6h16v14H4zM4 10h16M8 3v5M16 3v5",
	"shield": "fill:M12 2.5l8 3.2v5.6c0 5-3.4 9.2-8 10.9-4.6-1.7-8-5.9-8-10.9V5.7z",
	"shelf": "M3 15h18M5 15v4M19 15v4M7 15V9h4v6M13 15v-4h4v4",
}

static var _cache: Dictionary = {}


## A texture of `name` at `px` logical pixels, drawn in `colour`. Rendered at
## the window's content scale (and at least 2x) so it's sharp when stretched.
static func texture(name: String, px: int, colour: Color, stroke: float = 2.2) -> Texture2D:
	var oversample := 2.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		oversample = maxf(2.0, tree.root.content_scale_factor * 2.0)
	var key := "%s_%d_%s_%.1f_%.1f" % [name, px, colour.to_html(), oversample, stroke]
	if _cache.has(key):
		return _cache[key]
	var path: String = PATHS.get(name, PATHS["close"])
	var hex := "#" + colour.to_html(false)
	var opacity := ' opacity="%.3f"' % colour.a if colour.a < 1.0 else ""
	var body: String
	if path.begins_with("fill:"):
		body = '<path d="%s" fill="%s"/>' % [path.trim_prefix("fill:"), hex]
	else:
		body = '<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"/>' % [path, hex, stroke]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g%s>%s</g></svg>' % [opacity, body]
	var img := Image.new()
	img.load_svg_from_string(svg, px * oversample / 24.0)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(px, px))
	_cache[key] = tex
	return tex
