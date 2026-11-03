shader_type canvas_item;
// The paper behind screens (see UI.backdrop()): a gradient from top through
// middle to bottom, up to three soft watercolour washes and paper grain.

uniform vec4 top : source_color;
uniform vec4 middle : source_color;
uniform vec4 bottom : source_color;
// Each wash: colour (its alpha is its strength), and centre.xy + radius.
uniform vec4 wash_a : source_color = vec4(0.0);
uniform vec3 at_a = vec3(0.3, 0.7, 0.4);
uniform vec4 wash_b : source_color = vec4(0.0);
uniform vec3 at_b = vec3(0.8, 0.85, 0.35);
uniform vec4 wash_c : source_color = vec4(0.0);
uniform vec3 at_c = vec3(0.5, 0.1, 0.3);
uniform float grain = 0.0;
// The rect's size, for the grain and to keep washes round.
uniform vec2 rect_size = vec2(720.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 wash(vec3 base, vec4 colour, vec3 at, vec2 uv) {
	float aspect = rect_size.x / max(rect_size.y, 1.0);
	vec2 d = (uv - at.xy) * vec2(aspect, 1.0);
	float k = 1.0 - smoothstep(0.0, at.z, length(d));
	return mix(base, colour.rgb, colour.a * k);
}

void fragment() {
	vec2 uv = UV;
	// Diagonal, as the boards' 160deg gradients.
	float t = clamp(uv.y * 0.85 + uv.x * 0.15, 0.0, 1.0);
	vec3 c = t < 0.5 ? mix(top.rgb, middle.rgb, t * 2.0) : mix(middle.rgb, bottom.rgb, (t - 0.5) * 2.0);
	c = wash(c, wash_a, at_a, uv);
	c = wash(c, wash_b, at_b, uv);
	c = wash(c, wash_c, at_c, uv);
	if (grain > 0.0) {
		vec2 p = uv * rect_size;
		float n = noise(p * 0.9) * 0.5 + noise(p * 0.23) * 0.3 + noise(p * 0.05) * 0.2;
		c *= 1.0 - grain * (n - 0.5);
	}
	COLOR = vec4(c, COLOR.a);
}
