shader_type canvas_item;
// Maps an animal's art onto its colours at runtime. Draw the animal in pure
// red, green and blue; the red paint becomes the first colour in animals.json
// "parts", the green the second and the blue the third. Darker paint stays
// darker and grey stays grey (a pixel's brightness is kept), so shading and
// outlines painted in the same channels still work.
uniform vec4 colour_r : source_color = vec4(1.0);
uniform vec4 colour_g : source_color = vec4(1.0);
uniform vec4 colour_b : source_color = vec4(1.0);

// The sprite's own colour (its modulate, and the light and fade a scene puts
// on it), kept to multiply into the result.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	float total = px.r + px.g + px.b;
	vec3 mapped = (px.r * colour_r.rgb + px.g * colour_g.rgb + px.b * colour_b.rgb) / max(total, 1.0);
	COLOR = vec4(mapped, px.a) * tint;
}
