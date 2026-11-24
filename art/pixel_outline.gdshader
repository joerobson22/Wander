shader_type canvas_item;
// Shows a small pixel-art picture drawn in a viewport (one texel per art
// pixel): a dark outline round its edge, like the animals' and gifts', and
// the viewport's darkened see-through colours put right.

uniform vec4 outline : source_color = vec4(0.149, 0.149, 0.149, 1.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.01) {
		vec2 t = TEXTURE_PIXEL_SIZE;
		float near = max(max(texture(TEXTURE, UV + vec2(t.x, 0.0)).a, texture(TEXTURE, UV - vec2(t.x, 0.0)).a),
				max(texture(TEXTURE, UV + vec2(0.0, t.y)).a, texture(TEXTURE, UV - vec2(0.0, t.y)).a));
		c = near > 0.5 ? outline : vec4(0.0);
	} else {
		c.rgb /= c.a;
	}
	COLOR = c * tint;
}
