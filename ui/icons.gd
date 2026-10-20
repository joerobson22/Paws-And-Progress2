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
	"paw": "fill:M6.5 6.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0-4.4zM12 3.6a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0-4.4zM17.5 6.8a2.2 2.2 0 1 0 0 4.4a2.2 2.2 0 1 0 0-4.4zM7.5 17.5c0-3.2 2.2-5.5 4.5-5.5s4.5 2.3 4.5 5.5c0 2-2 3-4.5 3s-4.5-1-4.5-3z",
	"flame": "M12 3c1 4 6 6 6 11a6 6 0 0 1-12 0c0-3 2-4 2-7 2 1 3 2 3 4 1-2 1-5 1-8z",
	"sound": "M4 9v6h4l5 4V5L8 9zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12",
	"mute": "M4 9v6h4l5 4V5L8 9zM17 9l5 6M22 9l-5 6",
	"gear": "M4 7h9M17 7h3M15 4.5v5M4 17h3M11 17h9M9 14.5v5",
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
	"dot": "fill:M12 5.5a6.5 6.5 0 1 0 0 13a6.5 6.5 0 1 0 0-13z",
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
