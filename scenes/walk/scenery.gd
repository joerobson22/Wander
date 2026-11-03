class_name Scenery
extends Control
## Endless parallax scenery for one place, drawn from data/biomes.json.
## Each layer is cut into chunks a few hundred pixels wide. A chunk is drawn
## once when it scrolls into view and freed once it has scrolled off, so a
## long walk costs little more than moving a handful of nodes each frame;
## only the few animated layers (water, reeds, fronds) redraw as they move.
## Weather (snow, wind, stars, fireflies) is a thin layer on top. Layers
## marked "front" (the jungle's big leaves and vines) go in `front`, which a
## host can lift in front of its walker and pet with front_into(). A host can
## instead stand() its walker and pet among the layers, so a pet running off
## into the distance goes behind the trees standing nearer than it.
##
## The light follows the real clock (see DayCycle), with the real sunrise
## and sunset where you are once you've allowed it (Outdoors): the sky
## brightens until midday and darkens after, the sun and then the moon
## cross it, and every layer is tinted to match through its node's
## modulate, so a change of light costs no redrawing. The real weather
## shows too, the way this place shows it (Weather): clouds, rain and
## lightning, snow, a blizzard. A layer with "art" repeats that scene instead
## of drawing its kind (see art/README.md).
## A holiday (App.holiday_look()) dresses it up: dead trees and midnight at
## Halloween, snow everywhere at Christmas (piling up at the bottom as you
## walk), fireworks at New Year, eggs in the grass at Easter.

const CHUNK := SceneryPainter.CHUNK
## The screen height (in pixels) that layer art scenes are drawn for.
const ART_HEIGHT := 720.0
## Layers that move with the time and so redraw every frame.
const ANIMATED := ["water", "reeds", "fronds", "undergrowth", "vines", "stalks"]
## How often the light catches up with the clock, in seconds.
const LIGHT_EVERY := 5.0
## Every scenery's front growth is in this group, wherever it's been moved.
const FRONT_GROUP := "scenery_front"
## A storm flashes about this often, in seconds.
const STORM_EVERY := 7.0
## Layers that grow up from the bottom of the screen (or hang from the top),
## so stand nearer than anyone on the path.
const NEAREST := ["reeds", "fronds", "drifts", "undergrowth", "stalks", "vines"]
## Layers with lights that come on after dark (lit windows, street lamps):
## they're drawn again as night falls and as day breaks.
const LIGHTS := ["buildings", "lamps"]

## Ground-layer pixels walked so far; every layer scrolls by this × its parallax.
var scroll: float = 0.0
var biome: Dictionary = {}
## The hour shown (14.5 is half past two), or -1 to follow the real clock.
var clock: float = -1.0:
	set(v):
		clock = v
		_update_light()
## A weather kind to show here instead of the real one (see Weather.KINDS);
## "" follows Outdoors.
var weather := "":
	set(v):
		weather = v
		_update_light()

var _time: float = 0.0
## Whether the lights (LIGHTS) were last drawn on.
var _lights_on := false
## DayCycle.at() for the hour shown, with the weather's cloud cover, plus
## "glow": how much of the sun or moon shows through it.
var _light: Dictionary = {}
var _light_check := 0.0
## The weather as this place shows it, and how that looks (Weather.look).
var _weather_kind := "sunny"
var _look: Dictionary = {}
## A storm's lightning: how bright the flash is now, which flash is drawing
## its bolt (-1 for none), and the last one thunder was played for.
var _flash := 0.0
var _bolt := -1
var _thunder_for := -1
## One entry per layer: {data, node, chunks: {index: SceneryPainter}, animated}.
var _layers: Array = []
var _sky: _Sky
var _clouds: _Clouds
var _fx: _Fx
## The holiday's look the chunks were drawn with (null for none), its
## fireworks, and the snow piling up at the bottom.
var _holiday: HolidayLook
var _fireworks: Fireworks
var _pile: _Pile
## The growth in front of everything else. It's the scenery's own top child
## until a host moves it with front_into(); it then keeps following the
## scenery's place, size and fade.
var front: Control
## Multiplied into the front growth's colour, e.g. to darken it along with a
## sheet laid over the rest of the scene, or to fade it on its own.
var front_tint := Color.WHITE
## A stretch of the screen (from x, to x) kept clear of tall plants, so one
## never stands in front of the pet everyone's looking at. Empty: none.
var front_gap := Vector2.ZERO
## Multiplied into everything the scenery draws, but not into anyone stood
## in it, e.g. to dim the scene behind a pet in the spotlight.
var shade := Color.WHITE:
	set(v):
		shade = v
		_update_shade()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sky = _Sky.new()
	_sky.scenery = self
	_sky.set_meta("foot", -INF)
	add_child(_sky)
	_clouds = _Clouds.new()
	_clouds.scenery = self
	_clouds.set_meta("foot", -INF)
	add_child(_clouds)
	_fireworks = Fireworks.new()
	_fireworks.set_meta("foot", -INF)
	add_child(_fireworks)
	front = Control.new()
	front.name = "SceneryFront"
	front.add_to_group(FRONT_GROUP)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.clip_contents = true
	for layer in biome.get("layers", []):
		if layer["kind"] == "planet":
			continue  # drawn with the sky
		var node := Node2D.new()
		node.set_meta("foot", 1.0 if NEAREST.has(str(layer["kind"])) else float(layer["y"]))
		if layer.get("front", false):
			front.add_child(node)
		else:
			add_child(node)
		var tile = _art_tile(layer)
		_layers.append({"data": layer, "node": node, "chunks": {}, "animated": ANIMATED.has(str(layer["kind"])), "tile": tile})
	_fx = _Fx.new()
	_fx.scenery = self
	add_child(_fx)
	_pile = _Pile.new()
	_pile.scenery = self
	front.add_child(_pile)
	add_child(front)
	_holiday = App.holiday_look()
	resized.connect(_rebuild)
	Outdoors.changed.connect(_update_light)
	_update_light()
	_update_shade()
	# Drawn from its very first frame, not one later: a place that pops in
	# blank (only the sky) for a frame reads as a flash.
	if size.x > 0.0:
		_place_chunks()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(front) and front.get_parent() != self:
		front.queue_free()


## Moves the front growth into `parent` (the scenery's own parent, or one
## standing in the same place) as its last child, so it's drawn over
## whatever was added before it, like the walker and the pet.
func front_into(parent: Node) -> void:
	front.reparent(parent, false)


## Draws `actor` (one of the scenery's own children, or a child of a node
## standing in the same place) among the layers by how far back its feet are:
## in front of the layers further back, behind any standing nearer (and
## behind everyone nearer). Call it again as the actor moves.
func stand(actor: CanvasItem, feet_y: float) -> void:
	if actor.get_parent() == null:
		add_child(actor)
	elif actor.get_parent() != self:
		actor.reparent(self, false)
	var foot := feet_y / maxf(1.0, size.y)
	actor.set_meta("foot", foot)
	var at := 0
	for child in get_children():
		if child == actor:
			continue
		if float(child.get_meta("foot", INF)) > foot:
			break
		at += 1
	move_child(actor, at)


func _process(delta: float) -> void:
	_time += delta
	_light_check -= delta
	if _light_check <= 0.0:
		_update_light()
	_place_chunks()
	if bool(_look.get("lightning", false)):
		_storm()
	elif _flash > 0.0 or _bolt >= 0:
		_flash = 0.0
		_bolt = -1
	_fx.queue_redraw()
	_fireworks.visible = _holiday != null and _holiday.fireworks
	if _fireworks.visible:
		_fireworks.size = Vector2(size.x, horizon_y())
		if not _holiday.firework_colours.is_empty():
			_fireworks.colours = _holiday.firework_colours
	_pile.visible = _holiday != null and _holiday.snow
	if _pile.visible:
		_pile.queue_redraw()
	if not is_instance_valid(front):
		return
	if front.get_parent() != self:
		front.position = position
		front.size = size
		front.modulate = modulate * front_tint * shade
		front.visible = visible
	else:
		front.size = size
		front.modulate = front_tint * shade


## The hour of the day shown: the clock's, unless a holiday pins it
## (midnight all Halloween).
func hour() -> float:
	if clock >= 0.0:
		return clock
	var look := App.holiday_look()
	return look.hour if look and look.hour >= 0.0 else DayCycle.hour_now()


func _update_light() -> void:
	_light_check = LIGHT_EVERY
	# A new holiday (or the end of one) draws everything again.
	var look := App.holiday_look()
	if look != _holiday:
		_holiday = look
		if is_inside_tree():
			_rebuild()
	# A holiday's weather shows the same everywhere (snow even in the desert).
	if weather == "" and look and look.weather in Weather.KINDS:
		_weather_kind = look.weather
	else:
		_weather_kind = Weather.for_place(weather if weather != "" else Outdoors.weather(), biome)
	_look = Weather.look(_weather_kind, Content.weathers)
	var sun := Outdoors.sun_hours()
	_light = DayCycle.at(DayCycle.solar_hour(hour(), sun.x, sun.y, Content.day_cycle), Content.day_cycle)
	# Cloud cover greys the sky, dims the light and hides the sun and moon.
	var o := float(_look["overcast"])
	if o > 0.0:
		for key in ["sky_top", "sky_bottom"]:
			var c: Color = _light[key]
			var grey := c.get_luminance() * 0.92
			_light[key] = c.lerp(Color(grey * 0.96, grey, grey * 1.04), o * 0.85).darkened(o * 0.2)
		_light["tint"] = (_light["tint"] as Color).lerp((_light["tint"] as Color) * Color(0.8, 0.82, 0.86), o)
	_light["glow"] = 1.0 - clampf(o * 1.15, 0.0, 1.0)
	var lit := darkness() > 0.3
	if lit != _lights_on:
		_lights_on = lit
		for layer in _layers:
			if LIGHTS.has(str(layer["data"]["kind"])):
				for chunk in layer["chunks"].values():
					chunk.queue_redraw()
	_update_shade()
	if _sky:
		_sky.queue_redraw()
	if _clouds:
		_clouds.queue_redraw()


func _update_shade() -> void:
	var t := tint() * shade
	for layer in _layers:
		layer["node"].modulate = t
	for node in [_sky, _clouds, _fx]:
		if node:
			node.modulate = shade


## The weather as this place shows it now (see Weather.KINDS; "blizzard"
## in the tundra).
func weather_kind() -> String:
	return _weather_kind


## Lightning every few seconds in a storm: a double flicker, then a fading
## glow, and thunder a moment later.
func _storm() -> void:
	var k := floori(_time / STORM_EVERY)
	var since := _time - (k * STORM_EVERY + _hash(k, 31.0) * 4.0)
	if since < 0.0 or since >= 0.6:
		_flash = 0.0
		_bolt = -1
		return
	if since < 0.06:
		_flash = 0.55
	elif since < 0.12:
		_flash = 0.12
	else:
		_flash = 0.45 * (1.0 - (since - 0.12) / 0.48)
	_bolt = k if since < 0.25 else -1
	if k != _thunder_for and is_visible_in_tree():
		_thunder_for = k
		get_tree().create_timer(0.7 + _hash(k, 32.0)).timeout.connect(Audio.play.bind("thunder", 0.85 + 0.3 * _hash(k, 33.0), -3.0))


## Screen y of the walking path (where feet go).
func path_y() -> float:
	var g := ground_layer()
	if not g.is_empty():
		return size.y * (float(g["y"]) + float(g["height"]) * 0.32)
	return size.y * 0.8


func ground_layer() -> Dictionary:
	for layer in biome.get("layers", []):
		if layer["kind"] == "ground":
			return layer
	return {}


## Screen y of the far horizon: the foot of the furthest layer of hills,
## where the sun and moon come up from and the clouds sit above.
func horizon_y() -> float:
	for layer in biome.get("layers", []):
		if layer["kind"] != "planet":
			return size.y * float(layer["y"])
	return size.y * 0.5


## The water band on screen (top y, bottom y), or an empty Vector2 if there's none.
func water_band() -> Vector2:
	for layer in biome.get("layers", []):
		if layer["kind"] == "water":
			return Vector2(float(layer["y"]), float(layer["y"]) + float(layer["height"])) * size.y
	return Vector2.ZERO


func water_colour() -> Color:
	for layer in biome.get("layers", []):
		if layer["kind"] == "water":
			return Color.from_string(layer["colour"], Color.SKY_BLUE) * tint()
	return Color.SKY_BLUE


## How the light colours everything now (white for places with their own light).
func tint() -> Color:
	if biome.get("fixed_light", false) or _light.is_empty():
		return Color.WHITE
	return _light["tint"]


## 0 in broad daylight, 1 at night (always 1 under a fixed black sky).
## Cloud doesn't count: an overcast noon is dull, not dark.
func darkness() -> float:
	if biome.has("sky"):
		return 1.0
	return float(_light.get("dark", 0.0))


func time() -> float:
	return _time


## The looping sound for this place now: daytime birds and lapping water give
## way to the night chorus after dark; wind and silence (the Moon) stay put.
func ambience() -> String:
	var own := str(biome.get("ambience", "day"))
	if int(_look.get("rain", 0)) > 0:
		return "rain"
	if float(_look.get("haze", 0.0)) > 0.0:
		return "wind"
	if darkness() >= 0.6 and own in ["lake", "day"]:
		return "night"
	return own


## Makes chunks that have scrolled into view, frees ones that have left, and
## moves the rest. Positions are worked out in full precision here, so hours
## of walking never make the scenery jitter.
func _place_chunks() -> void:
	for layer in _layers:
		var offset := scroll * float(layer["data"]["parallax"])
		if layer["tile"] != null:
			_place_tiles(layer, offset)
			continue
		var first := floori(offset / CHUNK) - 1
		var last := floori((offset + size.x) / CHUNK) + 1
		var chunks: Dictionary = layer["chunks"]
		for i in chunks.keys():
			if i < first or i > last:
				chunks[i].queue_free()
				chunks.erase(i)
		for i in range(first, last + 1):
			var chunk: SceneryPainter = chunks.get(i)
			if chunk == null:
				chunk = SceneryPainter.new()
				chunk.scenery = self
				chunk.layer = layer["data"]
				chunk.index = i
				layer["node"].add_child(chunk)
				chunks[i] = chunk
			chunk.position.x = i * CHUNK - offset
			if layer["animated"]:
				chunk.queue_redraw()


## The layer's art as {scene, width}, or null: a layer with "art" (a scene
## path in biomes.json) repeats that scene instead of drawing its kind.
## The scene is drawn for a screen ART_HEIGHT tall, its origin on the line
## the layer stands on (its "y"), and is as wide as its ReferenceRect named
## "TileBounds" (else the layer's "tile_width", else 768).
func _art_tile(layer: Dictionary) -> Variant:
	# Sprites drawn straight into the place's scene, inside the layer.
	if layer.has("art_tile"):
		return layer["art_tile"]
	var path := str(layer.get("art", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var probe := scene.instantiate()
	var bounds := probe.get_node_or_null("TileBounds") as Control
	var width := bounds.size.x if bounds and bounds.size.x > 0.0 else float(layer.get("tile_width", 768))
	probe.free()
	return {"scene": scene, "width": width}


## Lays copies of a layer's art scene side by side, making ones that scroll
## into view and freeing ones that leave, like the drawn chunks.
func _place_tiles(layer: Dictionary, offset: float) -> void:
	var k := size.y / ART_HEIGHT
	var width: float = layer["tile"]["width"] * k
	if width <= 1.0:
		return
	var first := floori(offset / width) - 1
	var last := floori((offset + size.x) / width) + 1
	var tiles: Dictionary = layer["chunks"]
	for i in tiles.keys():
		if i < first or i > last:
			tiles[i].queue_free()
			tiles.erase(i)
	for i in range(first, last + 1):
		var tile: Node2D = tiles.get(i)
		if tile == null:
			var source: Dictionary = layer["tile"]
			tile = (source["node"] as Node).duplicate() if source.has("node") else (source["scene"] as PackedScene).instantiate()
			tile.scale = Vector2(k, k)
			layer["node"].add_child(tile)
			tiles[i] = tile
		tile.position = Vector2(i * width - offset, size.y * float(layer["data"]["y"]))


func _rebuild() -> void:
	for layer in _layers:
		for chunk in layer["chunks"].values():
			chunk.queue_free()
		layer["chunks"].clear()
	_sky.queue_redraw()
	_place_chunks()


static func _noise(t: float, sd: float) -> float:
	return SceneryPainter._noise(t, sd)


## Stable pseudo-random 0..1 for an integer slot.
static func _hash(i: int, sd: float) -> float:
	return SceneryPainter._hash(i, sd)


## Snow piling up along the bottom of the screen as you walk at Christmas:
## nothing at first, as high as the look's snow_pile_height once you've
## walked its snow_pile_minutes. It moves with the ground as you go.
class _Pile extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var look := scenery._holiday
		if look == null:
			return
		var size := scenery.size
		var walked := float(App.state.active.elapsed(App.now())) if App.state.active else scenery.time()
		var depth := clampf(walked / maxf(60.0, look.snow_pile_minutes * 60.0), 0.0, 1.0)
		var high := size.y * look.snow_pile_height * (0.15 + 0.85 * depth)
		var g := scenery.ground_layer()
		var moved := scenery.scroll * float(g.get("parallax", 1.0))
		var pts := PackedVector2Array()
		var x := -16.0
		while x <= size.x + 16.0:
			pts.append(Vector2(x, size.y - high * (0.7 + 0.3 * Scenery._noise((x + moved) / 260.0, 5.0))))
			x += 16.0
		var top := pts.duplicate()
		pts.append(Vector2(size.x + 16.0, size.y + 2.0))
		pts.append(Vector2(-16.0, size.y + 2.0))
		var light := scenery.tint().lightened(0.25)
		draw_colored_polygon(pts, Color(0.93, 0.95, 1.0) * Color(light, 1.0))
		draw_polyline(top, Color(1, 1, 1) * Color(light, 1.0), 3.0, true)


## The sky behind everything, with the sun or moon on its way across:
## redrawn only when the size or the light changes (every few seconds). A
## place with its own sky (the Moon) keeps it whatever the time.
class _Sky extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var size := scenery.size
		var sky: Dictionary = scenery.biome.get("sky", {})
		var light := scenery._light
		var top: Color = Color.from_string(sky["top"], Color.BLACK) if sky.has("top") else light.get("sky_top", Color("#8ec3e6"))
		var bottom: Color = Color.from_string(sky["bottom"], Color.BLACK) if sky.has("bottom") else light.get("sky_bottom", Color("#d7ecf6"))
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
		var glow := float(light.get("glow", 1.0))
		if not sky.has("top") and glow > 0.01:
			var r := clampf(size.y * 0.045, 16.0, 40.0)
			if float(light.get("sun", -1.0)) >= 0.0:
				_sun(_on_arc(float(light["sun"]), r, size), r, float(light["sun"]), glow)
			if float(light.get("moon", -1.0)) >= 0.0:
				_moon(_on_arc(float(light["moon"]), r, size), r * 0.8, glow)
		for layer in scenery.biome.get("layers", []):
			if layer["kind"] == "planet":
				_planet(Vector2(size.x * 0.72, size.y * float(layer["y"])), size.y * float(layer["height"]), Color.from_string(layer["colour"], Color.ROYAL_BLUE))

	## Where something `progress` of the way across the sky is: it comes up
	## from behind the furthest hills on the left, peaks in the middle (below
	## the words at the top of the screen) and goes down behind them on the
	## right.
	func _on_arc(progress: float, r: float, size: Vector2) -> Vector2:
		var horizon := scenery.horizon_y()
		var high := minf(size.y * 0.2 + r, horizon - r * 2.0)
		return Vector2(lerpf(size.x * 0.06, size.x * 0.94, progress), lerpf(horizon + r * 1.2, high, sin(progress * PI)))

	## Warm and orange near the horizon, pale yellow when it's high; `glow`
	## is how much shows through the cloud.
	func _sun(c: Vector2, r: float, progress: float, glow: float) -> void:
		var high := sin(progress * PI)
		var colour := Color("#ff9b54").lerp(Color("#fff3b0"), clampf(high * 1.6, 0.0, 1.0))
		draw_circle(c, r * 3.2, Color(colour, 0.08 * glow), true, -1.0, true)
		draw_circle(c, r * 1.9, Color(colour, 0.16 * glow), true, -1.0, true)
		draw_circle(c, r, Color(colour, glow), true, -1.0, true)

	func _moon(c: Vector2, r: float, glow: float) -> void:
		var colour := Color("#f2efe0")
		draw_circle(c, r * 2.6, Color(colour, 0.06 * glow), true, -1.0, true)
		draw_circle(c, r * 1.6, Color(colour, 0.1 * glow), true, -1.0, true)
		draw_circle(c, r, Color(colour, glow), true, -1.0, true)
		var shade := Color("#cfcab6", glow)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.22, shade, true, -1.0, true)
		draw_circle(c + Vector2(r * 0.35, r * 0.15), r * 0.16, shade, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.05, r * 0.45), r * 0.12, shade, true, -1.0, true)

	## A big blue planet hanging still in the sky (the Earth, seen from the Moon).
	func _planet(c: Vector2, r: float, colour: Color) -> void:
		draw_circle(c, r * 1.25, Color(colour, 0.12), true, -1.0, true)
		draw_circle(c, r, colour, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.35, Color("#5fa65a"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.35, r * 0.3), r * 0.28, Color("#5fa65a"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.1, -r * 0.55), r * 0.25, Color(1, 1, 1, 0.75), true, -1.0, true)
		draw_arc(c, r * 0.8, PI * 0.1, PI * 0.9, 16, Color(0, 0, 0, 0.18), r * 0.45, true)


## Clouds drifting across the sky: in front of the sun and moon, behind the
## hills. A few white puffs on a fair day; more, greyer and under a dull
## blanket as it clouds over; dark and quick in a storm.
class _Clouds extends Node2D:
	var scenery: Scenery

	func _process(_delta: float) -> void:
		if int(scenery._look.get("clouds", 0)) > 0:
			queue_redraw()

	func _draw() -> void:
		var look := scenery._look
		var count := int(look.get("clouds", 0))
		if count <= 0:
			return
		var size := scenery.size
		var o := float(look.get("overcast", 0.0))
		var t := scenery.time()
		var unit := minf(size.x, size.y) / 720.0
		var colour := Color.WHITE.lerp(Color(0.6, 0.63, 0.68), clampf((o - 0.3) / 0.6, 0.0, 1.0)) * scenery.tint()
		if o >= 0.4:
			var a := (o - 0.3) * 0.9
			var low := scenery.horizon_y()
			draw_polygon(
				PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, low), Vector2(0, low)]),
				PackedColorArray([Color(colour, a), Color(colour, a), Color(colour, 0.0), Color(colour, 0.0)]))
		var wind := 1.0 + float(look.get("wind", 0.0)) * 2.5
		var span := size.x + 400.0 * unit
		for i in count:
			var s := (0.6 + 0.7 * Scenery._hash(i, 21.0)) * unit
			var speed := (6.0 + 10.0 * Scenery._hash(i, 22.0)) * wind * unit
			var x := fposmod(Scenery._hash(i, 23.0) * span + t * speed + scenery.scroll * 0.02, span) - 200.0 * unit
			var y := scenery.horizon_y() * (0.08 + 0.62 * Scenery._hash(i, 24.0))
			_cloud(Vector2(x, y), s, colour.darkened(0.1 * Scenery._hash(i, 25.0)))

	## One cloud: overlapping puffs on a flat base.
	func _cloud(at: Vector2, s: float, colour: Color) -> void:
		for p in [[-60, 0, 30], [-24, -18, 42], [20, -22, 46], [58, -4, 34], [0, -10, 40]]:
			draw_circle(at + Vector2(p[0], p[1]) * s, p[2] * s, colour, true, -1.0, true)
		draw_rect(Rect2(at + Vector2(-60, 0) * s, Vector2(118, 30) * s), colour)


## Weather on top of the scenery: stars coming out as it gets dark (unless
## it's cloudy), fireflies at dusk and overnight, the tundra's snow and
## wind, and the real weather's rain, lightning, snow and white-outs. A few
## hundred dots and lines a frame at most.
class _Fx extends Node2D:
	var scenery: Scenery

	func _draw() -> void:
		var fx: Array = scenery.biome.get("fx", [])
		var size := scenery.size
		var t := scenery.time()
		var dark := scenery.darkness()
		var look := scenery._look
		# Stars fade in from dusk, the brightest first, unless it's cloudy.
		var stars := clampf((dark - 0.3) / 0.6, 0.0, 1.0) * (1.0 - float(look.get("overcast", 0.0)))
		if fx.has("stars") and stars > 0.0:
			for i in 70:
				var bright := Scenery._hash(i, 3.0)
				var shown := clampf(stars * 2.0 - (1.0 - bright), 0.0, 1.0)
				if shown <= 0.0:
					continue
				var at := Vector2(Scenery._hash(i, 1.0) * size.x, Scenery._hash(i, 2.0) * size.y * 0.45)
				var twinkle := 0.5 + 0.5 * sin(t * 2.0 + i)
				draw_circle(at, 1.0 + bright * 1.2, Color(1, 1, 0.9, (0.4 + 0.5 * twinkle) * shown))
		var flies := clampf((dark - 0.15) / 0.4, 0.0, 1.0)
		if fx.has("fireflies") and flies > 0.0:
			for i in 18:
				var base := Vector2(Scenery._hash(i, 4.0) * size.x, size.y * (0.6 + 0.3 * Scenery._hash(i, 5.0)))
				var drift := Vector2(sin(t * 0.6 + i) * 18.0, cos(t * 0.8 + i * 1.3) * 12.0)
				var glow := (0.4 + 0.6 * absf(sin(t * 1.3 + i * 2.1))) * flies
				draw_circle(base + drift, 6.0, Color(1.0, 0.92, 0.5, 0.15 * glow))
				draw_circle(base + drift, 2.2, Color(1.0, 0.95, 0.6, glow))
		# Cherry blossom petals drifting down and across.
		if fx.has("petals"):
			var petal := Color("#f6c6d4") * Color(scenery.tint(), 1.0)
			for i in 40:
				var fall := fposmod(Scenery._hash(i, 21.0) * size.y + t * (24.0 + 20.0 * Scenery._hash(i, 22.0)), size.y + 20.0) - 10.0
				var x := fposmod(Scenery._hash(i, 23.0) * size.x - t * 30.0 + sin(t * 1.2 + i) * 16.0, size.x + 20.0) - 10.0
				var spin := t * 2.0 + i
				draw_set_transform(Vector2(x, fall), spin, Vector2(1.0, 0.55 + 0.45 * absf(sin(spin))))
				draw_circle(Vector2.ZERO, 3.2, petal, true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
		var gust := 0.6 + 0.4 * sin(t * 0.45)
		var area := clampf(size.x * size.y / (720.0 * 720.0), 0.5, 3.0)
		var unit := minf(size.x, size.y) / 720.0
		var wind := float(look.get("wind", 0.0)) + (0.6 if fx.has("wind") else 0.0)
		var light := scenery.tint()
		if bool(look.get("lightning", false)):
			_lightning(size)
		# Rain slants with the wind, in long quick streaks.
		var drops := int(int(look.get("rain", 0)) * area)
		var slant := 0.12 + 0.3 * wind
		var rain := Color(0.82, 0.88, 1.0, 0.42) * Color(light, 1.0)
		for i in drops:
			var speed := 760.0 + 320.0 * Scenery._hash(i, 14.0)
			var length := (14.0 + 16.0 * Scenery._hash(i, 15.0)) * unit
			var y := fposmod(Scenery._hash(i, 16.0) * size.y + t * speed * unit, size.y + length * 2.0) - length
			var x := fposmod(Scenery._hash(i, 17.0) * size.x * 1.3 - y * slant, size.x + 40.0) - 20.0
			draw_line(Vector2(x, y), Vector2(x + length * slant, y - length), rain, 1.4, true)
		# Snow: the tundra's own flurries, or the weather's. Flakes fall and
		# are blown sideways, harder in the gusts.
		var flakes := int(maxi(90 if fx.has("snow") else 0, int(look.get("snow", 0))) * area)
		var flake := Color(1, 1, 1, 0.85) * Color(light.lightened(0.3), 1.0)
		for i in flakes:
			var speed := (30.0 + 50.0 * Scenery._hash(i, 6.0)) * (1.0 + wind * 0.5)
			var fall := fposmod(Scenery._hash(i, 7.0) * size.y + t * speed, size.y + 20.0) - 10.0
			var blown := fposmod(Scenery._hash(i, 8.0) * size.x - t * (20.0 + 120.0 * wind * gust) - fall * 0.6 * wind, size.x + 20.0) - 10.0
			draw_circle(Vector2(blown, fall), 1.2 + 2.0 * Scenery._hash(i, 9.0), flake)
		if wind >= 0.5:
			for i in int(6 + 8 * wind):
				var speed := 380.0 + 260.0 * Scenery._hash(i, 10.0)
				var x := size.x - fposmod(Scenery._hash(i, 11.0) * size.x * 2.0 + t * speed * (0.6 + wind * 0.5), size.x * 2.0)
				var y := size.y * (0.15 + 0.7 * Scenery._hash(i, 12.0)) + sin(t * 2.0 + i) * 6.0
				var length := 60.0 + 90.0 * Scenery._hash(i, 13.0)
				draw_line(Vector2(x, y), Vector2(x + length, y - 4.0), Color(1, 1, 1, 0.25 * gust * minf(1.0, wind)), 1.5, true)
		# A blizzard whites everything out, more in the gusts.
		var haze := float(look.get("haze", 0.0))
		if haze > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.94, 0.96, 1.0, haze * (0.7 + 0.3 * gust)) * Color(light.lightened(0.4), 1.0))

	## The flash lights up the whole scene; the bolt forks down from the
	## clouds for a moment.
	func _lightning(size: Vector2) -> void:
		if scenery._bolt >= 0:
			var k := scenery._bolt
			var at := Vector2(size.x * (0.15 + 0.7 * Scenery._hash(k, 34.0)), 0.0)
			var bolt := PackedVector2Array([at])
			var low := scenery.horizon_y()
			for j in range(1, 9):
				at = Vector2(at.x + (Scenery._hash(k * 9 + j, 35.0) - 0.5) * size.x * 0.06, low * j / 8.0)
				bolt.append(at)
			draw_polyline(bolt, Color(1, 1, 1, 0.35), 7.0, true)
			draw_polyline(bolt, Color(1, 1, 0.92, 0.95), 2.5, true)
		if scenery._flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.94, 1.0, scenery._flash * 0.55))
