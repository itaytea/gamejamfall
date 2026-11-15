shader_type canvas_item;
// Pixel-perfect TV static. Each GAME pixel (240x135) gets its own random grey
// that changes a few times a second, with the odd faint horizontal band.
// intensity 0 = invisible.

uniform vec2 screen_px = vec2(240.0, 135.0);
uniform float intensity = 0.0;     // Driven by how many people are infected
uniform float fps = 14.0;          // How often the static changes
uniform float darken = 0.6;        // Dark tint under the static, as a fraction of intensity

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 px = floor(UV * screen_px);
	float frame = floor(TIME * fps);
	float n = hash(vec3(px, frame));
	float band = step(0.97, hash(vec3(7.0, px.y, floor(TIME * fps * 0.5))));
	// Static specks on top of a very slight dark tint (both scale with intensity)
	float a_static = clamp(intensity * (0.5 + n) + band * intensity * 0.6, 0.0, 1.0);
	float a_dark = clamp(intensity * darken, 0.0, 1.0);
	float a_out = a_static + a_dark * (1.0 - a_static);
	vec3 rgb = (vec3(n) * a_static) / max(a_out, 0.0001);   // the tint itself is black
	COLOR = vec4(rgb, a_out);
}
