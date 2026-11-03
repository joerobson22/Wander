shader_type canvas_item;
// Snow on a picture of the hilltop view (art/home/): a white cap where snow
// would settle (along hilltops and on the tips of trees, anywhere flatter
// than 45 degrees) and a light dusting over the rest. Used at Christmas
// (art/holidays/christmas/look.tres turns snow on).

// How thick the cap is, as a share of the picture's height.
uniform float depth = 0.008;
// How much the rest of the picture whitens.
uniform float dusting = 0.18;
uniform vec4 snow : source_color = vec4(0.95, 0.97, 1.0, 1.0);
// How bright the snow is (dimmer at night).
uniform float light = 1.0;

// The layer's own colour (its modulate, and the light on it).
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	// Snow settles where the picture is clear above and diagonally above
	// either side: a top steeper than 45 degrees (a tree's side) stays bare.
	vec2 side = vec2(depth * float(textureSize(TEXTURE, 0).y) / float(textureSize(TEXTURE, 0).x), 0.0);
	vec2 up = vec2(0.0, depth);
	float above = max(texture(TEXTURE, UV - up).a, max(texture(TEXTURE, UV - up - side).a, texture(TEXTURE, UV - up + side).a));
	float cap = clamp(px.a - above, 0.0, 1.0);
	vec3 base = mix(px.rgb * tint.rgb, snow.rgb * light, dusting);
	COLOR = vec4(mix(base, snow.rgb * light, cap), px.a * tint.a);
}
