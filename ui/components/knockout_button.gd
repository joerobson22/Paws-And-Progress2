class_name KnockoutButton
extends Button
## A white rounded square with a plus cut clean out of it, so whatever's
## behind (the scenery) shows through the plus: the "new pet" button.

const SHADER := """
shader_type canvas_item;
uniform vec4 fill : source_color = vec4(1.0);
uniform vec2 box_size = vec2(48.0);
uniform float radius = 14.0;

float round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * box_size;
	float m = min(box_size.x, box_size.y);
	float t = m * 0.06;
	float arm = m * 0.24;
	float outer = round_box(p, box_size * 0.5, radius);
	float plus = min(round_box(p, vec2(arm, t), t), round_box(p, vec2(t, arm), t));
	float d = max(outer, -plus);
	COLOR = vec4(fill.rgb, fill.a * clamp(0.5 - d, 0.0, 1.0));
}
"""

static var _shader: Shader

var _face := ColorRect.new()


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


func _refresh() -> void:
	var mat := _face.material as ShaderMaterial
	var fill := Color.WHITE
	if disabled:
		fill.a = 0.4
	elif is_pressed():
		fill = fill.darkened(0.14)
	elif is_hovered():
		fill = fill.darkened(0.06)
	mat.set_shader_parameter("fill", fill)
	mat.set_shader_parameter("box_size", size)
	mat.set_shader_parameter("radius", minf(16.0, size.x * 0.3))
