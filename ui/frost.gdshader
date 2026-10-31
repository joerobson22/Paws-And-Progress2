shader_type canvas_item;
// Frosted glass behind popups (the glass style): what's on screen, blurred,
// with the scrim's tint over it. The ColorRect's own alpha (its fade) sets
// how much shows.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float lod = 3.5;

void fragment() {
	vec2 step = SCREEN_PIXEL_SIZE * 7.0;
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.36;
	c += textureLod(screen_tex, SCREEN_UV + vec2(step.x, 0.0), lod).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV - vec2(step.x, 0.0), lod).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, step.y), lod).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, step.y), lod).rgb * 0.16;
	COLOR = vec4(mix(c, tint.rgb, tint.a), COLOR.a);
}
