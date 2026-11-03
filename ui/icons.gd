class_name Icons
extends RefCounted
## The app's icons, one editable SVG each in assets/icons/<name>.svg (see
## the README there). Each is drawn in one colour on a 24x24 canvas and
## tinted here to the colour asked for, at any size, so it stays crisp at
## any UI scale. Optional full-colour pictures (an achievement's) are drawn
## as they are.

const DIR := "res://assets/icons/"
## The line width the icons are drawn with. Asking for another `stroke`
## swaps it for that, so a few buttons can have bolder lines.
const LINE := "2.2"

static var _cache: Dictionary = {}
static var _sources: Dictionary = {}


## Whether there's an icon called `name`.
static func has(name: String) -> bool:
	return _source(name) != ""


## A texture of `name` at `px` logical pixels, drawn in `colour`. Rendered at
## the window's content scale (and at least 2x) so it's sharp when stretched.
static func texture(name: String, px: int, colour: Color, stroke: float = 2.2) -> Texture2D:
	var oversample := _oversample()
	var key := "%s_%d_%s_%.1f_%.1f" % [name, px, colour.to_html(), oversample, stroke]
	if _cache.has(key):
		return _cache[key]
	var svg := _source(name)
	if svg == "":
		push_warning("No icon %s%s.svg" % [DIR, name])
		svg = _source("close")
	if not is_equal_approx(stroke, float(LINE)):
		svg = svg.replace('stroke-width="%s"' % LINE, 'stroke-width="%.2f"' % stroke)
	var img := Image.new()
	img.load_svg_from_string(svg, px * oversample / 24.0)
	# One colour: keep each pixel's coverage, in the colour asked for.
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(colour, a * colour.a))
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(px, px))
	_cache[key] = tex
	return tex


## A full-colour picture at `path` under assets/icons (no ".svg"), drawn as
## it is, or null if there isn't one, like "achievements/focus_10".
static func drawn(path: String, px: int) -> Texture2D:
	var key := "drawn:%s_%d" % [path, px]
	if _cache.has(key):
		return _cache[key]
	var svg := _source(path)
	if svg == "":
		return null
	var img := Image.new()
	img.load_svg_from_string(svg, px * _oversample() / 24.0)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(px, px))
	_cache[key] = tex
	return tex


static func _oversample() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return maxf(2.0, tree.root.content_scale_factor * 2.0)
	return 2.0


## The SVG text of assets/icons/<name>.svg, or "" if there's none. Read
## once; the files are kept as they are in exports (importer "keep").
static func _source(name: String) -> String:
	if not _sources.has(name):
		var path := DIR + name + ".svg"
		_sources[name] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return _sources[name]


## A place's icon at `px`, in white for a button to tint: Joe's own
## art/places/<id>.png (white on transparent) when there is one, else the
## drawn icon the place names in biomes.json.
static func place(biome: Dictionary, px: int) -> Texture2D:
	var id := str(biome.get("id", ""))
	var path := "res://art/places/%s.png" % id
	if id != "" and ResourceLoader.exists(path):
		var key := "art:%s_%d" % [id, px]
		if not _cache.has(key):
			var img := (load(path) as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			var side := maxi(px * 2, 1)
			img.resize(side, side, Image.INTERPOLATE_LANCZOS)
			var tex := ImageTexture.create_from_image(img)
			tex.set_size_override(Vector2i(px, px))
			_cache[key] = tex
		return _cache[key]
	return texture(str(biome.get("icon", "place_lake")), px, Color.WHITE, 2.0)
