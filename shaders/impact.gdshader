shader_type canvas_item;

// Full-screen impact distortion: a ring of displacement travelling outward
// from the hit, with the colour channels pulled apart along the same vector.
//
// This is the effect that reads as "electric" rather than merely animated.
// It is driven entirely by uniforms so one quad serves every impact, and at
// strength 0 it costs a branch and nothing else.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec2 centre = vec2(0.5, 0.5);   // impact point, screen UV
uniform float wave = 0.0;               // 0 -> 1 as the ring expands
uniform float strength = 0.0;           // overall amount, fades to 0
uniform float aberration = 0.0;         // channel separation
uniform float aspect = 1.777;

void fragment() {
	if (strength <= 0.001) {
		COLOR = texture(screen_tex, SCREEN_UV);
	} else {
		vec2 d = SCREEN_UV - centre;
		d.x *= aspect;
		float dist = length(d);
		vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);

		// A narrow band around the current radius, so it reads as a ring
		// passing through rather than the whole image breathing.
		float band = exp(-pow((dist - wave) * 9.0, 2.0));
		float push = band * strength * 0.045;

		vec2 uv = SCREEN_UV - dir * push / vec2(aspect, 1.0);

		// Separate the channels along the travel direction. Tiny values only:
		// past about 2px this stops looking like energy and starts looking
		// like a broken display.
		vec2 ab = dir * (aberration * band * 0.006) / vec2(aspect, 1.0);
		float r = texture(screen_tex, uv + ab).r;
		float g = texture(screen_tex, uv).g;
		float b = texture(screen_tex, uv - ab).b;

		// A faint bright lip on the leading edge of the ring.
		float lip = band * strength * 0.18;
		COLOR = vec4(vec3(r, g, b) + lip, 1.0);
	}
}
