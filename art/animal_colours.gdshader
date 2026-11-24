shader_type canvas_item;
// Maps an animal's art onto its colours at runtime. Draw the animal in pure
// red, green and blue; the red paint becomes the first colour in animals.json
// "parts", the green the second and the blue the third. Darker paint stays
// darker, so shading painted in the same channels still works. Pure greys
// (equal red, green and blue: black outlines, white eye shines) are drawn
// exactly as painted.
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
	float spread = max(px.r, max(px.g, px.b)) - min(px.r, min(px.g, px.b));
	COLOR = vec4(spread < 0.02 ? px.rgb : mapped, px.a) * tint;
}
