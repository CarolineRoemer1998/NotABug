shader_type canvas_item;

uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;

uniform float shake_power : hint_range(0.0, 0.25) = 0.06;
uniform float shake_rate : hint_range(0.0, 1.0) = 1.0;
uniform float shake_speed = 8.0;
uniform float shake_block_size = 24.0;
uniform float shake_color_rate : hint_range(0.0, 0.25) = 0.04;

uniform float fringe_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.04;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.05;
uniform float edge_softness : hint_range(0.001, 0.3) = 0.04;

float random(float seed) {
	return fract(543.2543 * sin(dot(vec2(seed, seed), vec2(3525.46, -54.3415))));
}

float rect_mask(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}

void fragment() {
	vec4 base = COLOR;

	float enable_shift = float(
		random(trunc(TIME * shake_speed)) < shake_rate
	);

	float block_y = trunc(UV.y * shake_block_size) / shake_block_size;
	float shift = (random(block_y + TIME) - 0.5) * shake_power * enable_shift;

	vec2 uv_r = UV + vec2(shift + shake_color_rate * enable_shift, 0.0);
	vec2 uv_g = UV + vec2(shift, 0.0);
	vec2 uv_b = UV + vec2(shift - shake_color_rate * enable_shift, 0.0);

	float r_mask = rect_mask(uv_r);
	float g_mask = rect_mask(uv_g);
	float b_mask = rect_mask(uv_b);

	float edge_left = smoothstep(0.0, edge_softness, UV.x);
	float edge_right = smoothstep(0.0, edge_softness, 1.0 - UV.x);
	float edge_top = smoothstep(0.0, edge_softness, UV.y);
	float edge_bottom = smoothstep(0.0, edge_softness, 1.0 - UV.y);
	float soft_mask = edge_left * edge_right * edge_top * edge_bottom;

	float line_noise = random(block_y * 91.7 + trunc(TIME * shake_speed * 1.7));
	float line_brightness = mix(1.0, 0.88 + line_noise * 0.24, noise_strength);
	float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * sin(UV.y * 140.0 + TIME * 10.0));

	vec3 fringe_rgb = vec3(base.r * r_mask, 0.0, base.b * b_mask);
	fringe_rgb *= line_brightness * scanline * soft_mask;

	vec3 final_rgb = base.rgb + fringe_rgb * fringe_alpha * effect_strength;
	float final_alpha = base.a;

	COLOR = vec4(final_rgb, final_alpha);
}