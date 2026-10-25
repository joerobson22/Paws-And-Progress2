class_name KnockoutButton
extends Button
## A rounded square with a plus cut clean out of it, so whatever's behind
## (the scenery) shows through the plus: the "new pet" button. It can turn
## its plus into a tick (`set_tick`), and take another colour (`fill_colour`)
## to stand out on a light page.

const SHADER := """
shader_type canvas_item;
uniform vec4 fill : source_color = vec4(1.0);
uniform vec2 box_size = vec2(48.0);
uniform float radius = 14.0;
// 0 cuts a plus, 1 a tick; in between morphs from one to the other.
uniform float tick = 0.0;

float round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float segment(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * box_size;
	float m = min(box_size.x, box_size.y);
	float t = m * 0.06;
	float arm = m * 0.24;
	float outer = round_box(p, box_size * 0.5, radius);
	float plus = min(round_box(p, vec2(arm, t), t), round_box(p, vec2(t, arm), t));
	vec2 knee = vec2(-0.07, 0.15) * m;
	float check = min(segment(p, vec2(-0.24, -0.02) * m, knee, t), segment(p, knee, vec2(0.25, -0.19) * m, t));
	float d = max(outer, -mix(plus, check, tick));
	COLOR = vec4(fill.rgb, fill.a * clamp(0.5 - d, 0.0, 1.0));
}
"""

static var _shader: Shader

var fill_colour := Color.WHITE:
	set(v):
		fill_colour = v
		_refresh()
var _face := ColorRect.new()
var _tick := 0.0


func _init(side: int = 48) -> void:
	custom_minimum_size = Vector2(side, side)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flat = true
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	_face.material = mat
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	resized.connect(_refresh)
	mouse_entered.connect(_refresh)
	mouse_exited.connect(_refresh)
	button_down.connect(_refresh)
	button_up.connect(_refresh)
	_refresh.call_deferred()


func set_disabled_look(off: bool) -> void:
	disabled = off
	_refresh()


## Morphs the plus into a tick, or back.
func set_tick(on: bool) -> void:
	Motion.method(self, "tick", _set_tick, _tick, 1.0 if on else 0.0, Motion.FAST)


func _set_tick(v: float) -> void:
	_tick = v
	(_face.material as ShaderMaterial).set_shader_parameter("tick", v)


func _refresh() -> void:
	var mat := _face.material as ShaderMaterial
	if mat == null:
		return
	var fill := fill_colour
	if disabled:
		fill.a *= 0.4
	elif is_pressed():
		fill = fill.darkened(0.14)
	elif is_hovered():
		fill = fill.darkened(0.06)
	mat.set_shader_parameter("fill", fill)
	mat.set_shader_parameter("box_size", size)
	mat.set_shader_parameter("radius", minf(16.0, size.x * 0.3))
