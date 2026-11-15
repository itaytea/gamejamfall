shader_type canvas_item;
// Night tint with a pixel-perfect, dithered pool of light at the cursor and a
// short fading trail behind it. Everything is worked out per GAME pixel
// (240x135), so the dither pattern lines up with the art.

uniform vec4 tint_color : source_color = vec4(0.04, 0.05, 0.12, 1.0);
uniform float tint_strength = 0.6;     // How dark the tint is away from the light
uniform vec2 screen_px = vec2(240.0, 135.0);
uniform float radius = 16.0;           // Fully lit circle around the cursor (game pixels)
uniform float edge = 10.0;             // Width of the dithered edge (game pixels)
uniform bool has_mouse = true;
uniform vec2 mouse = vec2(-100.0);
uniform vec2 trail[12];
uniform float trail_age[12];           // 0 = just now, 1 = about to vanish
uniform int trail_count = 0;
uniform float glow = 0.05;             // Faint warm light in the middle of the pool

float bayer4(vec2 p) {
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
						  3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (m[y * 4 + x] + 0.5) / 16.0;
}

float pool(vec2 c, vec2 centre, float r) {
	return 1.0 - smoothstep(r, r + edge, distance(c, centre));
}

void fragment() {
	vec2 px = floor(UV * screen_px);
	vec2 c = px + 0.5;
	float light = 0.0;
	if (has_mouse) {
		light = pool(c, mouse, radius);
	}
	for (int i = 0; i < 12; i++) {
		if (i >= trail_count) { break; }
		float fade = 1.0 - trail_age[i];
		light = max(light, pool(c, trail[i], radius * fade * 0.75) * fade);
	}
	float lit = step(bayer4(px), light);                 // Dither: each pixel is lit or not
	float core = has_mouse ? pool(c, mouse, radius * 0.5) : 0.0;
	vec4 dark = vec4(tint_color.rgb, tint_strength);
	vec4 warm = vec4(1.0, 0.86, 0.6, glow * step(bayer4(px), core));
	COLOR = mix(dark, warm, lit);
}
