class_name Glint
extends ColorRect
## A shine for hover: one diagonal white stripe that sweeps across once.
## Add it as the last child of the thing that shines and call shine(). It
## covers its parent, or with `square` the biggest square centred in it,
## and keeps inside a rounded box whose corner radius is `corner` times the
## short side (0.5 makes it a circle).

const SHADER := """
shader_type canvas_item;

uniform float progress = -1.0;
uniform float corner = 0.5;
uniform vec2 box = vec2(64.0, 64.0);
uniform float width = 0.16;

void fragment() {
	vec2 p = UV * box;
	float r = corner * min(box.x, box.y);
	vec2 q = abs(p - box * 0.5) - (box * 0.5 - vec2(r));
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	float inside = clamp(0.5 - edge, 0.0, 1.0);
	float along = (UV.x + UV.y) * 0.5;
	float centre = mix(-width, 1.0 + width, progress);
	float stripe = 1.0 - smoothstep(0.0, width, abs(along - centre));
	COLOR = vec4(1.0, 1.0, 1.0, 0.6 * stripe * inside * step(0.0, progress));
}
"""

static var _shader: Shader

## How long one sweep takes, in seconds.
var seconds := 0.55
var _square := false


func _init(corner: float = 0.5, square: bool = false) -> void:
	_square = square
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("corner", corner)
	m.set_shader_parameter("progress", -1.0)
	material = m
	resized.connect(func(): (material as ShaderMaterial).set_shader_parameter("box", size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		var parent := get_parent() as Control
		if parent:
			parent.resized.connect(_fit)
			_fit.call_deferred()


func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	if _square:
		var side := minf(parent.size.x, parent.size.y)
		size = Vector2(side, side)
		position = (parent.size - size) * 0.5
	else:
		position = Vector2.ZERO
		size = parent.size


## One sweep across, top left to bottom right.
func shine() -> void:
	Motion.method(self, "shine", _set_progress, 0.0, 1.0, seconds).tween_callback(_set_progress.bind(-1.0))


func _set_progress(v: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("progress", v)
