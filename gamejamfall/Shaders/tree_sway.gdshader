shader_type canvas_item;
// Subtle wind sway for a tree layer. Rows shift sideways in a slow wave,
// most at the top and not at all at the bottom. Shifts are whole game pixels,
// so the art stays pixel-perfect.

uniform vec2 size_px = vec2(240.0, 135.0);
uniform float speed = 1.0;         // Higher = faster sway
uniform float amplitude = 1.3;     // Max sideways shift at the top, in game pixels
uniform float wavelength = 45.0;   // Vertical length of one wave, in game pixels
uniform float phase = 0.0;         // Offset so layers don't move in lockstep

void fragment() {
	vec2 px = floor(UV * size_px);
	float height = 1.0 - px.y / size_px.y;                  // 1 at the top, 0 at the bottom
	float wave = sin(TIME * speed + phase + px.y / wavelength * TAU + px.x * 0.02);
	float shift = round(wave * amplitude * height);
	COLOR = texture(TEXTURE, (px + vec2(-shift, 0.0) + 0.5) / size_px);
}
