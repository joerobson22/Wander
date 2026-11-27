class_name AnimalView
extends Node2D
## An animal: Joe's own art when there is some, else a placeholder drawn from
## simple shapes, recoloured per part. The origin is where its feet touch the
## ground; it faces right.
## Art is a scene at <sprite_dir>animal.tscn (see art/README.md): a Node2D with
## a Sprite2D per limb (head, body, each leg, tail...) that the AnimationPlayer
## moves separately, painted in pure red, green and blue: a shader maps those
## to the animal's colours (first, second and third in animals.json "parts").
## Optional Marker2Ds "Neck" (where the lead clips on) and "Mouth" (where a
## gift is held), and an AnimationPlayer with a looping "walk" and optionally
## "idle". Animals without a scene keep the placeholder, so art can arrive
## one animal at a time.

## Where each shape's mouth is, so it can carry a gift.
const SHADER := "res://art/animal_colours.gdshader"
const MOUTHS := {
	"dog": Vector2(70, -54), "bear": Vector2(66, -52), "cat": Vector2(50, -46),
	"rabbit": Vector2(34, -42), "snail": Vector2(50, -14), "bird": Vector2(36, -38),
	"sheep": Vector2(62, -50), "pig": Vector2(68, -40), "tortoise": Vector2(56, -16),
	"frog": Vector2(40, -24), "elephant": Vector2(78, -38), "giraffe": Vector2(70, -158),
	"snake": Vector2(62, -18), "lizard": Vector2(56, -12), "spider": Vector2(34, -14),
	"rhino": Vector2(80, -40), "skeleton": Vector2(70, -54), "reindeer": Vector2(70, -56),
	"egg": Vector2(34, -30), "cake": Vector2(36, -30),
	"fish": Vector2(40, -50), "crab": Vector2(30, -26), "whale": Vector2(70, -42),
	"dog2": Vector2(64, -52), "fox": Vector2(64, -46), "tiger": Vector2(58, -48),
	"leopard": Vector2(50, -46), "lion": Vector2(56, -50), "red_panda": Vector2(48, -38),
	"hyrax": Vector2(32, -24), "parakeet": Vector2(24, -42), "eagle": Vector2(36, -50),
	"mammoth": Vector2(70, -50), "monkey": Vector2(42, -48), "gorilla": Vector2(56, -58),
}
## How big a gift in the mouth is, and how far its middle hangs below the
## mouth (so the mouth closes on its top edge), in the animal's own pixels.
const HELD_SIZE := 34.0
const HELD_DROP := Vector2(3, 11)
## Where each shape's lead clips on, before any bounce in its step.
const NECKS := {
	"bear": Vector2(30, -58), "cat": Vector2(28, -46), "rabbit": Vector2(14, -40),
	"snail": Vector2(32, -12), "bird": Vector2(11, -38), "sheep": Vector2(32, -54),
	"pig": Vector2(34, -44), "tortoise": Vector2(36, -18), "frog": Vector2(22, -26),
	"elephant": Vector2(40, -78), "giraffe": Vector2(32, -96), "snake": Vector2(40, -14),
	"lizard": Vector2(30, -12), "spider": Vector2(14, -18), "rhino": Vector2(40, -62),
	"egg": Vector2(16, -40), "cake": Vector2(18, -44), "reindeer": Vector2(34, -58),
	"fish": Vector2(14, -60), "crab": Vector2(0, -30), "whale": Vector2(20, -74),
	"dog2": Vector2(32, -56), "fox": Vector2(30, -50), "tiger": Vector2(30, -52),
	"leopard": Vector2(28, -48), "lion": Vector2(26, -52), "red_panda": Vector2(24, -40),
	"hyrax": Vector2(10, -32), "parakeet": Vector2(8, -40), "eagle": Vector2(12, -46),
	"mammoth": Vector2(40, -82), "monkey": Vector2(22, -50), "gorilla": Vector2(32, -64),
}
## Where a helmet goes round the head, and how big it is, for shapes whose
## head isn't between the neck and the mouth (a crab is all body).
const HELMETS := {"crab": [Vector2(4, -26), 34.0], "snail": [Vector2(40, -22), 18.0], "spider": [Vector2(22, -18), 18.0]}

@export var animal_id: String = "dog1":
	set(v):
		animal_id = v
		_load_rig()
		queue_redraw()
@export var walking: bool = false:
	set(v):
		walking = v
		_animate()
## A livelier gait for fetching: quicker steps, bigger strides and bounce.
var running := false:
	set(v):
		running = v
		_animate()
## Multiplier on top of the animal's own walk speed.
@export var speed: float = 1.0

var colours: Array[Color] = []:
	set(v):
		colours = v
		_tint_rig()
		queue_redraw()
## How far below the water it is, in its own pixels (0 on dry land), and the
## water's colour: the part under the surface is hidden behind it.
var submerged := 0.0:
	set(v):
		submerged = v
		queue_redraw()
		if _overlay:
			_overlay.queue_redraw()
var water_colour := Color("#7fb2c9")
## A helmet round its head: "diver" (brass, for the ocean), "astronaut"
## (white, for the Moon) or "" for none. See helmet_in().
var helmet := "":
	set(v):
		helmet = v
		queue_redraw()
		if _overlay:
			_overlay.queue_redraw()
## A gift id to carry in its mouth, or "".
var held_gift := "":
	set(v):
		held_gift = v
		queue_redraw()
		if _overlay:
			_overlay.queue_redraw()
## 0 normally, up to 1 when it's dejected: head, ears and tail hang, the
## eyes droop and it sighs now and then.
var sad := 0.0:
	set(v):
		sad = v
		_animate()
		queue_redraw()

## How much of a flyer's take-off it uses (1 = all of it): a small stage,
## like the adopt carousel's, keeps it lower.
var lift_scale := 1.0
## How high a flyer's body is off the ground now, in this node's units.
var _lift := 0.0
var _air_bob := 0.0

var _phase: float = 0.0
var _sigh: float = 0.0
## Time spent afloat: swimmers bob gently even standing still.
var _swim := 0.0
## The art scene's root and its animations, if this animal has art.
var _rig: Node2D
var _player: AnimationPlayer
## Draws the water and the held gift over the art.
var _overlay: _Overlay
var _material: ShaderMaterial


## The scene holding an animal's art, or "" if it has none yet.
static func rig_path(id: String) -> String:
	var dir := str(Content.animal(id).get("sprite_dir", ""))
	var path := dir.path_join("animal.tscn")
	return path if dir != "" and ResourceLoader.exists(path) else ""


## The helmet an animal wears in a place (the place's "helmet" in
## biomes.json): none for one that lives underwater in the ocean.
static func helmet_in(place_id: String, id: String) -> String:
	var kind := str(Content.biome(place_id).get("helmet", ""))
	if kind == "diver" and bool(Content.animal(id).get("aquatic", false)):
		return ""
	return kind


## Whether it swims rather than walks (it lives only in the ocean).
func swims() -> bool:
	return str(Content.animal(animal_id).get("only_in", "")) == "ocean"


func has_art() -> bool:
	return _rig != null


## Swaps the placeholder for `scene`'s art (or back, for null).
func set_rig(scene: PackedScene) -> void:
	if _rig:
		_rig.free()
		_rig = null
		_player = null
		_material = null
	if _overlay:
		_overlay.free()
		_overlay = null
	if scene != null:
		_rig = scene.instantiate() as Node2D
	if _rig == null:
		queue_redraw()
		return
	var size_scale := float(Content.animal(animal_id).get("size", 1.0))
	_rig.scale = Vector2(size_scale, size_scale)
	add_child(_rig)
	_overlay = _Overlay.new()
	_overlay.view = self
	# Pixel art (and the pixel gifts it holds) stays crisp.
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_overlay)
	_player = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_tint_rig()
	_animate()
	queue_redraw()


## How far an animal's art reaches behind its feet (x) and ahead of them
## (y), in units at scale 1. For laying out walks (ChooseFocus.walk_spots).
static func reach(id: String) -> Vector2:
	var r := extent(id)
	return Vector2(-r.position.x, r.end.x)


## The box an animal's art fills at scale 1, its feet at the origin: from
## its rig, or a guess from its size if it has none.
static func extent(id: String) -> Rect2:
	if _extents.has(id):
		return _extents[id]
	var size := float(Content.animal(id).get("size", 1.0))
	var out := Rect2(Vector2(-49.0, -80.0) * size, Vector2(123.0, 80.0) * size)
	var path := rig_path(id)
	var scene := load(path) as PackedScene if path != "" else null
	if scene:
		var state := scene.get_state()
		for n in state.get_node_count():
			if state.get_node_name(n) != "Sprite":
				continue
			var props := {}
			for k in state.get_node_property_count(n):
				props[state.get_node_property_name(n, k)] = state.get_node_property_value(n, k)
			var tex := props.get("texture") as Texture2D
			if tex:
				var k: float = (props.get("scale", Vector2.ONE) as Vector2).x * size
				var frames := int(props.get("hframes", 1))
				var w := tex.get_width() / frames
				# Only the drawn part of the frames (they leave room to hop).
				var used := Rect2i()
				var img := tex.get_image()
				for f in frames:
					var r := img.get_region(Rect2i(f * w, 0, w, tex.get_height())).get_used_rect()
					if r.has_area():
						used = r if not used.has_area() else used.merge(r)
				if not used.has_area():
					used = Rect2i(0, 0, w, tex.get_height())
				out = Rect2((props.get("offset", Vector2.ZERO) + Vector2(used.position)) * k, Vector2(used.size) * k)
	_extents[id] = out
	return out


static var _extents := {}


## Scales and places `view` so its whole animal sits in the middle of a
## `box` (top left at the origin), `fill` of the way across its tighter side.
## A circle's box fits the animal's corners inside the circle instead.
static func fit(view: AnimalView, box: Vector2, fill: float = 0.86, circle: bool = false) -> void:
	var r := extent(view.animal_id)
	var s := minf(box.x * fill / r.size.x, box.y * fill / r.size.y)
	if circle:
		s = minf(box.x, box.y) * 0.5 * fill / (r.size.length() * 0.5)
	view.scale = Vector2(s, s)
	view.position = box * 0.5 - r.get_center() * s


func _load_rig() -> void:
	var path := rig_path(animal_id)
	set_rig(load(path) as PackedScene if path != "" else null)


## Every limb (Sprite2D) in the art gets the colour-mapping shader, which
## turns its red, green and blue paint into the animal's three colours.
func _tint_rig() -> void:
	if _rig == null:
		return
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER) as Shader
		_paint_limbs(_rig)
	var parts: Array = Content.animal(animal_id).get("parts", [])
	for i in 3:
		var part: String = parts[i] if i < parts.size() else ""
		_material.set_shader_parameter(["colour_r", "colour_g", "colour_b"][i], _part(part, Color.WHITE))


func _paint_limbs(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			(child as CanvasItem).material = _material
		_paint_limbs(child)


func _animate() -> void:
	if _player == null:
		return
	var anim := "walk" if walking else "idle"
	if not walking and sad > 0.5 and _player.has_animation("sad"):
		anim = "sad"
	if not _player.has_animation(anim):
		if walking or not _player.has_animation("walk"):
			return
		_player.stop()
		return
	_player.speed_scale = _anim_speed()
	if _player.current_animation != anim or not _player.is_playing():
		_player.play(anim)


func _anim_speed() -> float:
	return (0.6 + float(Content.animal(animal_id).get("walk_speed", 1.0))) * speed * (2.4 if running else 1.0)


## A point marked in the art (a Marker2D by that name), in this node's space.
func _marker(marker: String, fallback: Vector2) -> Vector2:
	var node := _rig.find_child(marker, true, false) as Node2D if _rig else null
	if node == null:
		return fallback * float(Content.animal(animal_id).get("size", 1.0))
	if not node.is_inside_tree() or not is_inside_tree():
		return _rig.transform * node.position
	return global_transform.affine_inverse() * node.global_position


## Whether it flies (animals.json "flies"): it takes off while it walks.
func flies() -> bool:
	return bool(Content.animal(animal_id).get("flies", false))


## How high it flies while walking, in this node's units (bigger flyers
## fly higher).
func hover_height() -> float:
	return (40.0 + 20.0 * float(Content.animal(animal_id).get("size", 1.0))) * lift_scale


## How far its body is off the ground right now, in this node's units.
func lift() -> float:
	return _lift


## A flyer rises as it sets off and settles back down when it stops, with a
## gentle bob in the air; its whole body (wings, legs, head) moves as one.
func _fly(delta: float) -> void:
	var goal := hover_height() if walking else 0.0
	_lift = move_toward(_lift, goal, delta * maxf(90.0, hover_height() * 2.2))
	_air_bob += delta
	if _rig:
		var high := _lift / maxf(1.0, hover_height())
		_rig.position.y = -_lift - sin(_air_bob * 3.2) * 3.0 * high


func _process(delta: float) -> void:
	if flies():
		_fly(delta)
	if _rig:
		_animate_rig(delta)
		return
	if swims():
		_swim += delta
		queue_redraw()
	if walking:
		var walk_speed := float(Content.animal(animal_id).get("walk_speed", 1.0))
		_phase += delta * TAU * (0.6 + walk_speed) * speed * (2.4 if running else 1.0)
		queue_redraw()
	if sad > 0.0:
		_sigh += delta
		queue_redraw()


func _animate_rig(delta: float) -> void:
	if _player and _player.has_animation("walk"):
		_player.speed_scale = _anim_speed()
	if sad > 0.0 and (_player == null or not _player.has_animation("sad")):
		_sigh += delta
		_rig.position = Vector2(2, 3) * sad + Vector2(0, (sin(_sigh * 1.3) * 0.5 + 0.5) * sad)


## How far the head hangs, in the animal's own pixels.
func _droop() -> Vector2:
	return Vector2(4, 14) * sad + Vector2(0, (sin(_sigh * 1.3) * 0.5 + 0.5) * 2.0 * sad)


## An eye, with a heavy lid in the head's colour when it's sad.
func _eye(at: Vector2, r: float, lid: Color) -> void:
	draw_circle(at, r, UI.INK)
	_lid(at, r, lid)


## The sad lid over an eye: lower at the outer corner (away from the nose)
## than the inner one.
func _lid(at: Vector2, r: float, lid: Color) -> void:
	if sad > 0.05:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-r - 1.5, -r - 2.0), at + Vector2(r + 1.5, -r - 2.0),
			at + Vector2(r + 1.5, -r + 2.0 * r * 0.25 * sad), at + Vector2(-r - 1.5, -r + 2.0 * r * 0.75 * sad)]), lid)


func _stride() -> float:
	return 2.2 if running else 1.0


func _part(part: String, fallback: Color) -> Color:
	var parts: Array = Content.animal(animal_id).get("parts", [])
	var i := parts.find(part)
	if i >= 0 and i < colours.size():
		return colours[i]
	var defaults := Content.animal_default_colours(animal_id)
	if i >= 0 and i < defaults.size():
		return defaults[i]
	return fallback


func _draw() -> void:
	if _rig:
		return
	var data := Content.animal(animal_id)
	var s := float(data.get("size", 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	match str(data.get("shape", "dog")):
		"cat":
			_draw_cat()
		"rabbit":
			_draw_rabbit()
		"snail":
			_draw_snail()
		"bird":
			_draw_bird()
		"bear":
			_draw_bear()
		"sheep":
			_draw_sheep()
		"pig":
			_draw_pig()
		"tortoise":
			_draw_tortoise()
		"frog":
			_draw_frog()
		"elephant":
			_draw_elephant()
		"giraffe":
			_draw_giraffe()
		"snake":
			_draw_snake()
		"lizard":
			_draw_lizard()
		"spider":
			_draw_spider()
		"rhino":
			_draw_rhino()
		"skeleton":
			_draw_skeleton()
		"reindeer":
			_draw_reindeer()
		"egg":
			_draw_egg()
		"cake":
			_draw_cake()
		"fish":
			_draw_fish()
		"crab":
			_draw_crab()
		"whale":
			_draw_whale()
		"dog2":
			_draw_dog2()
		"fox":
			_draw_fox()
		"tiger":
			_draw_tiger()
		"leopard":
			_draw_leopard()
		"lion":
			_draw_lion()
		"red_panda":
			_draw_red_panda()
		"hyrax":
			_draw_hyrax()
		"parakeet":
			_draw_parakeet()
		"eagle":
			_draw_eagle()
		"mammoth":
			_draw_mammoth()
		"monkey":
			_draw_monkey()
		"gorilla":
			_draw_gorilla()
		_:
			_draw_dog()
	_draw_over(self, str(data.get("shape", "dog")))


## The water over the legs and the gift in the mouth, on whichever node
## draws last.
func _draw_over(canvas: CanvasItem, shape: String) -> void:
	if submerged > 0.5:
		canvas.draw_rect(Rect2(-90, -submerged, 190, submerged + 10), Color(water_colour, 0.92))
		canvas.draw_line(Vector2(-60, -submerged), Vector2(80, -submerged), Color(1, 1, 1, 0.55), 2.0, true)
	if helmet != "":
		_draw_helmet(canvas, shape)
	if held_gift != "":
		_draw_held_gift(canvas, shape)


## A round glass helmet over the head with a collar where it meets the
## neck: brass for diving, white for space.
func _draw_helmet(canvas: CanvasItem, shape: String) -> void:
	var s := float(Content.animal(animal_id).get("size", 1.0))
	var at: Vector2
	var r: float
	if HELMETS.has(shape):
		at = HELMETS[shape][0] + Vector2(0, -_float())
		r = HELMETS[shape][1]
	else:
		var n := neck() / s
		var m := (MOUTHS.get(shape, Vector2(60, -50)) as Vector2) - Vector2(0, _float())
		at = n.lerp(m, 0.62) + Vector2(0, -3)
		r = clampf(n.distance_to(m) * 0.62 + 6.0, 16.0, 30.0)
	at += _droop() * 0.6
	# On the animals' pixel grid: an art pixel is 3 / size of this node's units.
	CharacterView.draw_helmet(PixelDraw.new(canvas, PixelDraw.size_for(720.0) / s), at, r, helmet)


## Where a lead clips on, in this node's own space: the neck, just behind
## the head, rising and falling with each step.
func neck() -> Vector2:
	if _rig:
		return _marker("Neck", Vector2(34, -55))
	var data := Content.animal(animal_id)
	var shape := str(data.get("shape", "dog"))
	var at: Vector2 = NECKS.get(shape, Vector2(34, -55))
	var lift := 0.0
	if walking:
		match shape:
			"cat", "snail", "snake", "lizard", "spider", "tortoise":
				lift = 0.0
			"rabbit":
				lift = absf(sin(_phase * 0.5)) * 14.0 * _stride()
			"hyrax":
				lift = _hop(0.5, 8.0)
			"frog":
				lift = _hop(0.5, 16.0)
			"bird", "parakeet":
				lift = _hop(0.7, 8.0)
			"eagle":
				lift = _hop(0.7, 6.0)
			"tiger", "lion", "red_panda":
				lift = _bob(1.5)
			"leopard":
				lift = _bob(1.2)
			"mammoth", "monkey":
				lift = _bob(2.5)
			_:
				lift = absf(sin(_phase)) * 2.0 * _stride()
	return (at - Vector2(0, lift + _float())) * float(data.get("size", 1.0))


## The held gift's middle in this node's own space (for glows behind it).
func mouth() -> Vector2:
	var s := float(Content.animal(animal_id).get("size", 1.0))
	return (_mouth_point(str(Content.animal(animal_id).get("shape", "dog"))) + HELD_DROP) * s


## The gift hangs from the mouth, bitten by its top edge, drawn on its own
## with nothing behind it.
func _draw_held_gift(canvas: CanvasItem, shape: String) -> void:
	var at := _mouth_point(shape) + HELD_DROP
	var art := GiftArt.texture_for(held_gift)
	if art:
		canvas.draw_texture_rect(art, Rect2(at - Vector2.ONE * HELD_SIZE * 0.5, Vector2.ONE * HELD_SIZE), false)
	else:
		var colour := Content.rarity_colour(Content.gift(held_gift).get("rarity", "common"))
		var px := int(HELD_SIZE * 0.8)
		canvas.draw_texture(Icons.texture("gift", px, colour), at - Vector2(px, px) * 0.5)


## The mouth in the animal's own (unscaled) pixels.
func _mouth_point(shape: String) -> Vector2:
	var fallback: Vector2 = MOUTHS.get(shape, Vector2(60, -50))
	if _rig:
		return _marker("Mouth", fallback) / float(Content.animal(animal_id).get("size", 1.0))
	return fallback - Vector2(0, _float())


## Sits above the art so the water and the gift in the mouth draw over it.
class _Overlay extends Node2D:
	var view: AnimalView

	func _draw() -> void:
		var s := float(Content.animal(view.animal_id).get("size", 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		view._draw_over(self, str(Content.animal(view.animal_id).get("shape", "dog")))


func _ellipse(centre: Vector2, radius: Vector2, colour: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(angle))
	draw_colored_polygon(pts, colour)


func _legs(xs: Array, top: float, length: float, width: float, colour: Color) -> void:
	for i in xs.size():
		var swing := sin(_phase + PI * (i % 2)) * 0.35 * _stride() if walking else 0.0
		var base := Vector2(xs[i], top)
		var foot := base + Vector2(0, length).rotated(swing)
		draw_line(base, foot, colour, width, true)
		draw_circle(foot, width * 0.5, colour)


func _draw_dog() -> void:
	var legs := _part("Legs", Color.SADDLE_BROWN)
	var body := _part("Body", Color.BURLYWOOD)
	var pattern := _part("Pattern", Color.WHITE)
	var bob := absf(sin(_phase)) * 2.0 * _stride() if walking else 0.0
	_legs([-30, -18, 18, 30], -30 - bob, 30, 9, legs)
	var tail_tip := Vector2(-58, -62 - bob + sin(_phase * 2.0) * 4.0).lerp(Vector2(-54, -24), sad)
	draw_line(Vector2(-40, -44 - bob), tail_tip, body, 7, true)
	_ellipse(Vector2(0, -42 - bob), Vector2(44, 19), body)
	_ellipse(Vector2(6, -34 - bob), Vector2(26, 10), pattern)
	var d := _droop()
	_ellipse(Vector2(46, -62 - bob) + d, Vector2(17, 15), body)
	_ellipse(Vector2(60, -57 - bob) + d, Vector2(10, 7), pattern)
	_ellipse(Vector2(38, -60 - bob) + d, Vector2(6, 12), body.darkened(0.25), 0.3 - 0.25 * sad)
	_eye(Vector2(50, -66 - bob) + d, 2.5, body)
	draw_circle(Vector2(69, -58 - bob) + d, 3.0, UI.INK)


func _draw_bear() -> void:
	var legs := _part("Legs", Color.SADDLE_BROWN)
	var body := _part("Body", Color.SADDLE_BROWN)
	var pattern := _part("Pattern", Color.TAN)
	var bob := absf(sin(_phase)) * 2.0 * _stride() if walking else 0.0
	_legs([-26, -14, 14, 26], -26 - bob, 26, 14, legs)
	_ellipse(Vector2(0, -44 - bob), Vector2(42, 24), body)
	var d := _droop()
	_ellipse(Vector2(42, -60 - bob) + d, Vector2(18, 16), body)
	draw_circle(Vector2(34, -76 - bob) + d, 6, body)
	draw_circle(Vector2(50, -76 - bob) + d, 6, body)
	_ellipse(Vector2(56, -56 - bob) + d, Vector2(9, 7), pattern)
	_eye(Vector2(46, -64 - bob) + d, 2.5, body)
	draw_circle(Vector2(63, -57 - bob) + d, 3.0, UI.INK)


func _draw_cat() -> void:
	var legs := _part("Legs", Color.DIM_GRAY)
	var body := _part("Body", Color.GRAY)
	var eyes := _part("Eyes", Color.YELLOW_GREEN)
	_legs([-24, -14, 14, 24], -26, 26, 6, legs)
	var tail := PackedVector2Array()
	for i in 10:
		var t := i / 9.0
		tail.append(Vector2(-34 - t * 16, -36 + lerpf(-t * 36.0, t * 24.0, sad) + sin(_phase + t * 3.0) * 3.0 * (1.0 - sad)))
	draw_polyline(tail, body, 5, true)
	_ellipse(Vector2(0, -36), Vector2(36, 13), body)
	var d := _droop() * 0.8
	_ellipse(Vector2(38, -52) + d, Vector2(13, 12), body)
	# Ears flatten back when it's sad.
	var flat := Vector2(-4, 5) * sad
	draw_colored_polygon(PackedVector2Array([Vector2(28, -58) + d, Vector2(31, -72) + d + flat, Vector2(37, -61) + d]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(39, -62) + d, Vector2(45, -73) + d + flat, Vector2(48, -59) + d]), body)
	draw_circle(Vector2(43, -54) + d, 3.0, eyes)
	draw_circle(Vector2(43, -54) + d, 1.2, UI.INK)
	_lid(Vector2(43, -54) + d, 3.0, body)


func _draw_rabbit() -> void:
	var legs := _part("Legs", Color.TAN)
	var body := _part("Body", Color.WHEAT)
	var pattern := _part("Pattern", Color.WHITE)
	var hop := absf(sin(_phase * 0.5)) * 14.0 * _stride() if walking else 0.0
	_ellipse(Vector2(-14, -12 - hop), Vector2(16, 10), legs)
	_ellipse(Vector2(12, -8 - hop), Vector2(6, 8), legs)
	_ellipse(Vector2(0, -28 - hop), Vector2(26, 20), body)
	draw_circle(Vector2(-26, -30 - hop), 7, pattern)
	var d := _droop() * 0.6
	_ellipse(Vector2(22, -46 - hop) + d, Vector2(13, 12), body)
	# The ears flop down its back when it's sad.
	_ellipse(Vector2(16, -70 - hop).lerp(Vector2(4, -52), sad) + d, Vector2(5, 16), body, lerpf(-0.2, -1.35, sad))
	_ellipse(Vector2(24, -70 - hop).lerp(Vector2(10, -54), sad) + d, Vector2(5, 16), body, lerpf(0.15, -1.2, sad))
	_eye(Vector2(27, -48 - hop) + d, 2.2, body)


func _draw_snail() -> void:
	var body := _part("Body", Color.TAN)
	var shell := _part("Shell", Color.SIENNA)
	var pattern := _part("Pattern", Color.BURLYWOOD)
	var stretch := 1.0 + (sin(_phase) * 0.06 if walking else 0.0)
	_ellipse(Vector2(4, -8), Vector2(40 * stretch, 9), body)
	# The eye stalks sag when it's sad.
	var stalk := Vector2(44, -34).lerp(Vector2(50, -20), sad)
	draw_line(Vector2(36, -12), stalk, body, 3, true)
	draw_line(Vector2(30, -12), Vector2(34, -30).lerp(Vector2(40, -18), sad), body, 3, true)
	draw_circle(stalk, 3, UI.INK)
	draw_circle(Vector2(-4, -30), 24, shell)
	var spiral := PackedVector2Array()
	for i in 40:
		var a := i * 0.4
		spiral.append(Vector2(-4, -30) + Vector2(cos(a), sin(a)) * (2.0 + i * 0.45))
	draw_polyline(spiral, pattern, 3, true)


func _draw_bird() -> void:
	var wings := _part("Wings", Color.STEEL_BLUE)
	var body := _part("Body", Color.LIGHT_SKY_BLUE)
	var pattern := _part("Pattern", Color.GOLD)
	var hop := absf(sin(_phase * 0.7)) * 8.0 * _stride() if walking else 0.0
	draw_line(Vector2(-4, -12 - hop), Vector2(-6, 0), Color("#7a5236"), 2, true)
	draw_line(Vector2(6, -12 - hop), Vector2(6, 0), Color("#7a5236"), 2, true)
	_ellipse(Vector2(0, -28 - hop), Vector2(20, 16), body)
	_ellipse(Vector2(4, -22 - hop), Vector2(11, 9), pattern)
	var flap := sin(_phase * 2.0) * 0.5 if walking else 0.0
	_ellipse(Vector2(-6, -32 - hop), Vector2(15, 7), wings, -0.3 + flap)
	var d := _droop() * 0.5
	draw_circle(Vector2(18, -40 - hop) + d, 9, body)
	draw_colored_polygon(PackedVector2Array([Vector2(26, -42 - hop) + d, Vector2(34, -39 - hop) + d, Vector2(26, -36 - hop) + d]), pattern.darkened(0.2))
	_eye(Vector2(20, -43 - hop) + d, 1.8, body)


## How high a hopping animal is off the ground now.
func _hop(rate: float, height: float) -> float:
	return absf(sin(_phase * rate)) * height * _stride() if walking else 0.0


## A gentle up and down with each step.
func _bob(height: float = 2.0) -> float:
	return absf(sin(_phase)) * height * _stride() if walking else 0.0


func _draw_sheep() -> void:
	var legs := _part("Legs", Color("#3a3330"))
	var wool := _part("Wool", Color("#f1ece2"))
	var face := _part("Face", Color("#2f2a28"))
	var bob := _bob()
	_legs([-24, -12, 14, 26], -26 - bob, 26, 7, legs)
	# A cloud of wool: overlapping puffs, a shade darker underneath.
	for k in 7:
		var a := PI + PI * k / 6.0
		draw_circle(Vector2(0, -44 - bob) + Vector2(cos(a) * 32.0, sin(a) * 15.0 + 4.0), 15.0, wool.darkened(0.06), true, -1.0, true)
	_ellipse(Vector2(0, -46 - bob), Vector2(36, 19), wool)
	draw_circle(Vector2(-30, -50 - bob), 8, wool, true, -1.0, true)
	var d := _droop()
	_ellipse(Vector2(42, -56 - bob) + d, Vector2(12, 14), face, -0.3)
	_ellipse(Vector2(34, -64 - bob) + d, Vector2(9, 4), face.lightened(0.1), -0.5 - 0.6 * sad)
	draw_circle(Vector2(38, -70 - bob) + d, 7, wool, true, -1.0, true)
	draw_circle(Vector2(46, -60 - bob) + d, 2.0, Color.WHITE)


func _draw_pig() -> void:
	var legs := _part("Legs", Color("#d98f92"))
	var body := _part("Body", Color("#f2b5b5"))
	var snout := _part("Snout", Color("#e58f96"))
	var bob := _bob()
	_legs([-26, -14, 16, 28], -22 - bob, 22, 9, legs)
	# A curly tail.
	var tail := PackedVector2Array()
	for k in 12:
		var a := k / 11.0 * TAU * 1.2
		tail.append(Vector2(-44, -42 - bob) + Vector2(-4.0 - cos(a) * 5.0, sin(a) * 5.0 - k * 0.4))
	draw_polyline(tail, body.darkened(0.1), 3, true)
	_ellipse(Vector2(0, -36 - bob), Vector2(42, 22), body)
	var d := _droop() * 0.8
	draw_circle(Vector2(44, -46 - bob) + d, 17, body, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(32, -58 - bob) + d, Vector2(36, -72 - bob) + d + Vector2(4, 6) * sad, Vector2(44, -60 - bob) + d]), legs)
	_ellipse(Vector2(62, -42 - bob) + d, Vector2(7, 9), snout)
	draw_circle(Vector2(63, -45 - bob) + d, 1.6, snout.darkened(0.4))
	draw_circle(Vector2(63, -39 - bob) + d, 1.6, snout.darkened(0.4))
	_eye(Vector2(50, -52 - bob) + d, 2.4, body)


func _draw_tortoise() -> void:
	var legs := _part("Legs", Color("#8a8f5a"))
	var shell := _part("Shell", Color("#6b5a35"))
	var pattern := _part("Pattern", Color("#a68c55"))
	var step := sin(_phase) * 3.0 if walking else 0.0
	for x in [-24, 20]:
		_ellipse(Vector2(x + step, -6), Vector2(8, 8), legs)
	for x in [-14, 30]:
		_ellipse(Vector2(x - step, -6), Vector2(7, 7), legs.darkened(0.1))
	var d := _droop() * 0.5
	_ellipse(Vector2(46, -18) + d + Vector2(0, 4) * sad, Vector2(12, 9), legs)
	_eye(Vector2(51, -21) + d + Vector2(0, 4) * sad, 2.0, legs)
	# The domed shell, its rim and a few plates.
	var dome := PackedVector2Array()
	for k in 25:
		var a := PI + PI * k / 24.0
		dome.append(Vector2(cos(a) * 40.0, sin(a) * 34.0 - 8.0))
	draw_colored_polygon(dome, shell)
	draw_rect(Rect2(-42, -12, 84, 6), shell.darkened(0.2))
	for k in 3:
		var c := Vector2(-20 + k * 20, -24 - (6 if k == 1 else 0))
		var plate := PackedVector2Array()
		for j in 7:
			var a := TAU * j / 6.0
			plate.append(c + Vector2(cos(a), sin(a)) * 8.0)
		draw_polyline(plate, pattern, 2.5, true)


func _draw_frog() -> void:
	var legs := _part("Legs", Color("#4f8a3a"))
	var body := _part("Body", Color("#6fae4a"))
	var belly := _part("Belly", Color("#d9e6a0"))
	var hop := _hop(0.5, 16.0)
	var stretch := clampf(hop / 16.0, 0.0, 1.0)
	# Back legs fold under it, and kick out as it jumps.
	_ellipse(Vector2(-16 - 6 * stretch, -8 - hop * 0.6), Vector2(16, 7), legs, -0.2 - 0.4 * stretch)
	_ellipse(Vector2(-4, -6 - hop * 0.6), Vector2(9, 5), legs)
	_ellipse(Vector2(16, -6 - hop), Vector2(4, 8), legs)
	_ellipse(Vector2(0, -20 - hop), Vector2(26, 15), body)
	_ellipse(Vector2(10, -16 - hop), Vector2(14, 8), belly)
	var d := _droop() * 0.4
	for x in [14, 28]:
		draw_circle(Vector2(x, -36 - hop) + d, 7, body, true, -1.0, true)
		_eye(Vector2(x + 1, -37 - hop) + d, 3.0, body)
	draw_arc(Vector2(30, -22 - hop) + d, 8, 0.2 + 0.6 * sad, 1.4 - 0.4 * sad, 8, UI.INK, 1.5, true)


func _draw_elephant() -> void:
	var legs := _part("Legs", Color("#7d7f86"))
	var body := _part("Body", Color("#9a9ca3"))
	var ears := _part("Ears", Color("#b8a5a5"))
	var bob := _bob(2.5)
	var step := 0.25 * _stride()
	for i in 4:
		var x: float = [-30, -12, 16, 34][i]
		var swing := sin(_phase + PI * (i % 2)) * step if walking else 0.0
		draw_line(Vector2(x, -34 - bob), Vector2(x, -34 - bob) + Vector2(0, 34).rotated(swing), legs if i % 2 == 0 else legs.darkened(0.08), 16, true)
	draw_line(Vector2(-46, -58 - bob), Vector2(-54, -34 - bob + sin(_phase * 2.0) * 3.0), body, 3, true)
	_ellipse(Vector2(0, -60 - bob), Vector2(48, 30), body)
	var d := _droop() * 0.6
	_ellipse(Vector2(50, -72 - bob) + d, Vector2(20, 19), body)
	# The trunk curls down from the face.
	var trunk := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		trunk.append(Vector2(64, -68 - bob) + d + Vector2(10.0 * sin(t * 1.6), 46.0 * t) + Vector2(sin(_phase + t * 2.0) * 3.0 * t, 0))
	draw_polyline(trunk, body, 9, true)
	draw_line(Vector2(60, -58 - bob) + d, Vector2(72, -52 - bob) + d, Color("#f4efe2"), 4, true)
	_ellipse(Vector2(38, -70 - bob) + d, Vector2(15, 20), ears, 0.2 + 0.3 * sad)
	_eye(Vector2(56, -78 - bob) + d, 2.5, body)


func _draw_giraffe() -> void:
	var legs := _part("Legs", Color("#c99a5a"))
	var body := _part("Body", Color("#e8c07a"))
	var patches := _part("Patches", Color("#9a5a2c"))
	var bob := _bob(2.5)
	_legs([-24, -14, 16, 26], -60 - bob, 60, 7, legs)
	draw_line(Vector2(-34, -78 - bob), Vector2(-40, -56 - bob + sin(_phase * 2.0) * 3.0), body, 3, true)
	_ellipse(Vector2(0, -74 - bob), Vector2(36, 20), body)
	# The long neck leans forward, and lower when it's sad.
	var head := Vector2(54, -150 - bob).lerp(Vector2(66, -96 - bob), sad * 0.6)
	draw_line(Vector2(22, -80 - bob), head + Vector2(-8, 10), body, 15, true)
	for k in 4:
		var t := (k + 0.5) / 4.0
		draw_circle(Vector2(22, -80 - bob).lerp(head + Vector2(-8, 10), t), 3.5, patches, true, -1.0, true)
	for c in [Vector2(-18, -78), Vector2(2, -68), Vector2(16, -80), Vector2(-6, -86)]:
		draw_circle(c - Vector2(0, bob), 5.5, patches, true, -1.0, true)
	_ellipse(head, Vector2(15, 9), body, 0.2)
	draw_line(head + Vector2(-6, -8), head + Vector2(-6, -18), patches, 3, true)
	draw_line(head + Vector2(0, -8), head + Vector2(0, -18), patches, 3, true)
	_eye(head + Vector2(0, -2), 2.2, body)


func _draw_snake() -> void:
	var belly := _part("Belly", Color("#e2d2a0"))
	var body := _part("Body", Color("#a6763a"))
	var pattern := _part("Pattern", Color("#5a3b25"))
	var wave := _phase * 0.8 if walking else 0.0
	var pts := PackedVector2Array()
	for k in 24:
		var t := k / 23.0
		pts.append(Vector2(-60 + 110 * t, -8 - sin(t * 9.0 - wave) * 5.0 * (1.0 - t * 0.5)))
	draw_polyline(pts, belly, 12, true)
	draw_polyline(pts, body, 9, true)
	for k in range(2, 22, 3):
		draw_circle(pts[k], 2.5, pattern, true, -1.0, true)
	var d := _droop() * 0.4
	var lift := 18.0 * (1.0 - sad)
	var head := Vector2(58, -10 - lift) + d
	draw_line(pts[pts.size() - 1], head, body, 9, true)
	_ellipse(head + Vector2(4, 0), Vector2(10, 7), body)
	_eye(head + Vector2(6, -3), 1.8, body)
	if walking and fmod(_phase, 3.0) < 0.8:
		draw_polyline(PackedVector2Array([head + Vector2(13, 2), head + Vector2(20, 2), head + Vector2(23, -1)]), Color("#d04a4a"), 1.5, true)


func _draw_lizard() -> void:
	var legs := _part("Legs", Color("#5a7a3a"))
	var body := _part("Body", Color("#8aae5a"))
	var pattern := _part("Pattern", Color("#e2c046"))
	var sway := sin(_phase * 1.5) * 4.0 if walking else 0.0
	var tail := PackedVector2Array()
	for k in 10:
		var t := k / 9.0
		tail.append(Vector2(-22 - 40 * t, -12 + t * 6.0 + sin(t * 3.0 + _phase) * 3.0 * t))
	draw_polyline(tail, body, 7.0, true)
	for i in 4:
		var x: float = [-16, -12, 18, 22][i]
		var swing := (1 if i % 2 == 0 else -1) * sway
		draw_line(Vector2(x, -12), Vector2(x + swing, -2), legs, 4, true)
		draw_line(Vector2(x + swing, -2), Vector2(x + swing + 5, 0), legs, 3, true)
	_ellipse(Vector2(0, -14), Vector2(26, 8), body)
	for k in 3:
		draw_circle(Vector2(-12 + k * 10, -18), 2.2, pattern, true, -1.0, true)
	var d := _droop() * 0.3
	_ellipse(Vector2(34, -16) + d, Vector2(11, 6), body, -0.1)
	_eye(Vector2(36, -19) + d, 1.8, body)


func _draw_spider() -> void:
	var legs := _part("Legs", Color("#2b2523"))
	var body := _part("Body", Color("#3e3430"))
	var pattern := _part("Pattern", Color("#c9a046"))
	var bob := _bob(1.5)
	# Four legs a side, each bent at the knee, stepping in turn.
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var k := i % 4
		var swing := sin(_phase * 1.5 + k * 1.2 + (PI if side > 0 else 0.0)) * 4.0 if walking else 0.0
		var hip := Vector2(-2 + k * 5, -18 - bob)
		var knee := hip + Vector2(side * (12 + k * 3) + swing, -16 + k * 3)
		var foot := Vector2(hip.x + side * (24 + k * 6) + swing * 1.5, 0)
		draw_polyline(PackedVector2Array([hip, knee, foot]), legs if side > 0 else legs.lightened(0.12), 2.5, true)
	_ellipse(Vector2(-12, -22 - bob), Vector2(17, 14), body)
	draw_circle(Vector2(-12, -24 - bob), 4, pattern, true, -1.0, true)
	var d := _droop() * 0.3
	draw_circle(Vector2(10, -18 - bob) + d, 9, body, true, -1.0, true)
	for e in [Vector2(14, -22), Vector2(18, -20)]:
		_eye(e - Vector2(0, bob) + d, 1.6, body)


func _draw_rhino() -> void:
	var legs := _part("Legs", Color("#6e6a66"))
	var body := _part("Body", Color("#8c8782"))
	var horn := _part("Horn", Color("#e2dccf"))
	var bob := _bob()
	_legs([-30, -16, 16, 30], -30 - bob, 30, 15, legs)
	draw_line(Vector2(-46, -52 - bob), Vector2(-52, -34 - bob + sin(_phase * 2.0) * 3.0), body, 3, true)
	_ellipse(Vector2(0, -52 - bob), Vector2(48, 26), body)
	var d := _droop() * 0.6
	# A long, low head, carried lower when it's sad.
	draw_colored_polygon(PackedVector2Array([
		Vector2(34, -66 - bob) + d, Vector2(72, -52 - bob) + d, Vector2(80, -38 - bob) + d,
		Vector2(66, -32 - bob) + d, Vector2(36, -38 - bob) + d]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(68, -50 - bob) + d, Vector2(80, -74 - bob) + d, Vector2(78, -46 - bob) + d]), horn)
	draw_colored_polygon(PackedVector2Array([Vector2(56, -56 - bob) + d, Vector2(62, -66 - bob) + d, Vector2(64, -54 - bob) + d]), horn)
	draw_colored_polygon(PackedVector2Array([Vector2(36, -64 - bob) + d, Vector2(38, -78 - bob) + d + Vector2(4, 6) * sad, Vector2(44, -64 - bob) + d]), body.darkened(0.1))
	_eye(Vector2(50, -56 - bob) + d, 2.2, body)


## A dog made of bones: a skull, a spine with ribs, bony legs, over a dark
## shadow of a body so the bones show up on anything.
func _draw_skeleton() -> void:
	var legs := _part("Legs", Color("#efe8d8"))
	var bones := _part("Bones", Color("#f6f1e4"))
	var shadow := _part("Shadow", Color("#2b2523"))
	var bob := _bob()
	_ellipse(Vector2(0, -42 - bob), Vector2(44, 19), Color(shadow, 0.85))
	for i in 4:
		var x: float = [-30, -18, 18, 30][i]
		var swing := sin(_phase + PI * (i % 2)) * 0.35 * _stride() if walking else 0.0
		var hip := Vector2(x, -40 - bob)
		var foot := hip + Vector2(0, 40).rotated(swing)
		draw_line(hip, foot, Color(shadow, 0.85), 8, true)
		draw_line(hip, foot, legs, 4, true)
		draw_circle(hip.lerp(foot, 0.5), 3.5, legs, true, -1.0, true)
		_ellipse(foot + Vector2(3, 0), Vector2(6, 3), legs)
	var tail_tip := Vector2(-60, -64 - bob + sin(_phase * 2.0) * 4.0).lerp(Vector2(-56, -26), sad)
	draw_line(Vector2(-40, -48 - bob), tail_tip, bones, 3, true)
	draw_line(Vector2(-40, -48 - bob), Vector2(36, -54 - bob), bones, 5, true)
	for k in 5:
		var x := -22.0 + 11.0 * k
		draw_arc(Vector2(x, -38 - bob), 13, PI * 1.05, PI * 1.95, 10, bones, 3, true)
	_ellipse(Vector2(-34, -46 - bob), Vector2(10, 7), bones)
	var d := _droop()
	_ellipse(Vector2(48, -62 - bob) + d, Vector2(17, 14), bones)
	_ellipse(Vector2(62, -56 - bob) + d, Vector2(10, 6), bones)
	draw_colored_polygon(PackedVector2Array([Vector2(36, -70 - bob) + d, Vector2(40, -84 - bob) + d, Vector2(46, -72 - bob) + d]), bones)
	draw_circle(Vector2(50, -65 - bob) + d, 4.5, shadow, true, -1.0, true)
	draw_circle(Vector2(68, -58 - bob) + d, 2.5, shadow, true, -1.0, true)
	for k in 3:
		draw_line(Vector2(56 + 4 * k, -53 - bob) + d, Vector2(56 + 4 * k, -49 - bob) + d, shadow, 1.5, true)


## A reindeer: a deer's long legs and neck, antlers and a red nose.
func _draw_reindeer() -> void:
	var legs := _part("Legs", Color("#5a3b28"))
	var body := _part("Body", Color("#8a5a3a"))
	var antlers := _part("Antlers", Color("#d9c6a8"))
	var bob := _bob()
	_legs([-30, -20, 20, 30], -34 - bob, 34, 7, legs)
	draw_line(Vector2(-40, -54 - bob), Vector2(-48, -60 - bob + sin(_phase * 2.0) * 3.0), body.lightened(0.3), 6, true)
	_ellipse(Vector2(0, -48 - bob), Vector2(42, 18), body)
	_ellipse(Vector2(4, -40 - bob), Vector2(24, 8), body.lightened(0.25))
	var d := _droop()
	draw_line(Vector2(30, -56 - bob), Vector2(42, -70 - bob) + d, body, 14, true)
	_ellipse(Vector2(50, -72 - bob) + d, Vector2(15, 11), body)
	for side in [0.0, 8.0]:
		var base := Vector2(42 + side, -80 - bob) + d
		var top := base + Vector2(-8, -22)
		draw_line(base, top, antlers, 3.5, true)
		draw_line(base.lerp(top, 0.5), base.lerp(top, 0.5) + Vector2(8, -6), antlers, 3.0, true)
		draw_line(base.lerp(top, 0.8), base.lerp(top, 0.8) + Vector2(-8, -4), antlers, 2.5, true)
	_ellipse(Vector2(40, -78 - bob) + d, Vector2(4, 7), body.darkened(0.2), -0.6)
	_eye(Vector2(52, -75 - bob) + d, 2.5, body)
	draw_circle(Vector2(64, -70 - bob) + d, 4.5, Color("#d8332a"), true, -1.0, true)


## An Easter egg out for a walk on two thin legs.
func _draw_egg() -> void:
	var legs := _part("Legs", Color("#e2a615"))
	var shell := _part("Shell", Color("#f6d6e4"))
	var stripes := _part("Stripes", Color("#8fc7e8"))
	var bob := _bob(3.0)
	var tilt := sin(_phase) * 0.08 if walking else 0.0
	for i in 2:
		var swing := sin(_phase + PI * i) * 0.45 * _stride() if walking else 0.0
		var hip := Vector2(-6 + 12 * i, -16 - bob)
		var foot := hip + Vector2(0, 16).rotated(swing)
		draw_line(hip, foot, legs, 3, true)
		draw_line(foot, foot + Vector2(7, 0), legs, 3, true)
	# Leaning side to side as it waddles (on top of the animal's size).
	var s := float(Content.animal(animal_id).get("size", 1.0))
	draw_set_transform(Vector2(0, -38 - bob) * s, tilt, Vector2(s, s))
	_ellipse(Vector2.ZERO, Vector2(19, 25), shell)
	var zig := PackedVector2Array()
	for k in 9:
		zig.append(Vector2(-18 + 4.5 * k, 2 + (4.0 if k % 2 == 0 else -4.0)))
	draw_polyline(zig, stripes, 4, true)
	draw_circle(Vector2(-8, 13), 3, stripes, true, -1.0, true)
	draw_circle(Vector2(5, 15), 3, stripes, true, -1.0, true)
	var d := _droop() * 0.3
	_eye(Vector2(8, -10) + d, 2.5, shell)
	draw_arc(Vector2(10, -4) + d, 4, 0.3 + 0.6 * sad, PI - 0.3 - 0.6 * sad, 8, UI.INK, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))


## A birthday cake on two legs, with a candle on top.
func _draw_cake() -> void:
	var legs := _part("Legs", Color("#e2a615"))
	var sponge := _part("Sponge", Color("#e8c690"))
	var icing := _part("Icing", Color("#f7a8c8"))
	var bob := _bob(2.5)
	for i in 2:
		var swing := sin(_phase + PI * i) * 0.45 * _stride() if walking else 0.0
		var hip := Vector2(-10 + 20 * i, -14 - bob)
		var foot := hip + Vector2(0, 14).rotated(swing)
		draw_line(hip, foot, legs, 3.5, true)
		draw_line(foot, foot + Vector2(7, 0), legs, 3.5, true)
	draw_style_box(UI.box(sponge, Color.TRANSPARENT, 6), Rect2(-24, -48 - bob, 48, 36))
	draw_rect(Rect2(-24, -32 - bob, 48, 4), icing.darkened(0.1))
	draw_style_box(UI.box(icing, Color.TRANSPARENT, 6), Rect2(-25, -50 - bob, 50, 10))
	for k in 4:
		_ellipse(Vector2(-17 + 11 * k, -40 - bob), Vector2(3.5, 5 + 2 * (k % 2)), icing)
	var d := _droop() * 0.4
	draw_rect(Rect2(-2, -64 - bob, 4, 14), Color("#8fc7e8"))
	if sad < 0.5:
		_ellipse(Vector2(0, -69 - bob + sin(_phase * 3.0)), Vector2(3, 5), Color("#ffb347"))
	_eye(Vector2(10, -24 - bob) + d, 2.5, sponge)
	draw_arc(Vector2(13, -18 - bob) + d, 4, 0.3 + 0.6 * sad, PI - 0.3 - 0.6 * sad, 8, UI.INK, 1.5, true)


## How high a swimmer floats over the ground, bobbing as it goes.
func _float() -> float:
	return 6.0 * sin(_swim * 1.6) if swims() else 0.0


## A fish swimming along: a round body with stripes, a tail flicking
## behind and fins top and bottom.
func _draw_fish() -> void:
	var fins := _part("Fins", Color("#e8702a"))
	var body := _part("Body", Color("#ff9a3c"))
	var stripes := _part("Stripes", Color.WHITE)
	var y := -50.0 - _float()
	var flick := sin(_swim * (9.0 if walking else 4.0)) * 0.35
	var tail := Vector2(-32, y)
	var a := tail + Vector2(-24, -18).rotated(flick)
	var b := tail + Vector2(-24, 18).rotated(flick)
	draw_colored_polygon(PackedVector2Array([tail, a, tail + Vector2(-16, 0).rotated(flick), b]), fins)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 20), Vector2(6, y - 34), Vector2(16, y - 18)]), fins)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, y + 18), Vector2(2, y + 30), Vector2(12, y + 18)]), fins.darkened(0.1))
	_ellipse(Vector2(0, y), Vector2(38, 22), body)
	for x in [-16.0, 10.0]:
		_ellipse(Vector2(x, y), Vector2(5, 19 - absf(x) * 0.3), stripes)
	_ellipse(Vector2(-4, y + 8), Vector2(10, 4), fins, 0.4 + sin(_swim * 5.0) * 0.2)
	var d := _droop() * 0.3
	draw_circle(Vector2(24, y - 6) + d, 5.0, UI.SURFACE, true, -1.0, true)
	_eye(Vector2(25, y - 6) + d, 2.6, body)
	draw_arc(Vector2(34, y + 5) + d, 4, 0.3 + 0.6 * sad, PI - 0.3 - 0.6 * sad, 8, UI.INK, 1.5, true)


## A crab scuttling: a wide shell on six little legs, two claws held up and
## eyes on stalks.
func _draw_crab() -> void:
	var legs := _part("Legs", Color("#b8402c"))
	var shell := _part("Shell", Color("#d9573a"))
	var claws := _part("Claws", Color("#ee8a5e"))
	var bob := _bob(1.5)
	for i in 3:
		for side in [-1.0, 1.0]:
			var step := sin(_phase * 1.4 + i * 2.1 + (PI if side > 0 else 0.0)) * 4.0 if walking else 0.0
			var hip := Vector2(side * (10 + i * 7), -16 - bob)
			var knee := hip + Vector2(side * 12, -6 + step * 0.4)
			var foot := Vector2(side * (24 + i * 8) + step, 0)
			draw_polyline(PackedVector2Array([hip, knee, foot]), legs, 3.0, true)
	for side in [-1.0, 1.0]:
		var wave := sin(_phase * 0.8 + side) * 3.0 if walking else 0.0
		var arm := Vector2(side * 22, -24 - bob)
		var claw := Vector2(side * 34, -44 - bob + wave) + _droop() * Vector2(0.2, 0.8)
		draw_line(arm, claw, claws, 4.0, true)
		_ellipse(claw, Vector2(9, 7), claws, side * 0.3)
		draw_colored_polygon(PackedVector2Array([claw + Vector2(side * 2, -3), claw + Vector2(side * 10, -10), claw + Vector2(side * 9, -1)]), claws.darkened(0.15))
	_ellipse(Vector2(0, -22 - bob), Vector2(28, 15), shell)
	_ellipse(Vector2(0, -26 - bob), Vector2(18, 7), shell.lightened(0.15))
	var d := _droop() * 0.4
	for x in [-6.0, 8.0]:
		draw_line(Vector2(x, -34 - bob), Vector2(x + 2, -44 - bob) + d, legs, 2.0, true)
		draw_circle(Vector2(x + 2, -45 - bob) + d, 4.0, UI.SURFACE, true, -1.0, true)
		_eye(Vector2(x + 3, -45 - bob) + d, 2.0, shell)
	draw_arc(Vector2(2, -18 - bob) + d, 5, 0.3 + 0.6 * sad, PI - 0.3 - 0.6 * sad, 8, UI.INK, 1.5, true)


## A whale gliding along: a long body with a pale belly, a flipper, and
## its tail flukes beating slowly up and down.
func _draw_whale() -> void:
	var fins := _part("Fins", Color("#34557d"))
	var body := _part("Body", Color("#4a76a8"))
	var belly := _part("Belly", Color("#d6e3ec"))
	var y := -46.0 - _float()
	var beat := sin(_swim * (2.6 if walking else 1.4)) * 10.0
	var root := Vector2(-58, y - 2)
	var tip := Vector2(-84, y - 8 + beat)
	draw_line(Vector2(-40, y), root, body, 18, true)
	draw_colored_polygon(PackedVector2Array([root, tip + Vector2(-10, -14), tip + Vector2(2, 0), tip + Vector2(-10, 14)]), fins)
	var shape := PackedVector2Array()
	for k in 33:
		var t := TAU * k / 32.0
		# A blunt head on the right, tapering to the tail on the left.
		var rx := 64.0 if cos(t) > 0 else 54.0
		var ry := 28.0 * (1.0 if cos(t) > 0 else 0.85)
		shape.append(Vector2(6 + cos(t) * rx, y + sin(t) * ry))
	draw_colored_polygon(shape, body)
	_ellipse(Vector2(14, y + 14), Vector2(48, 11), belly)
	for k in 4:
		draw_line(Vector2(-6 + k * 12, y + 10), Vector2(-4 + k * 12, y + 22), belly.darkened(0.15), 1.6, true)
	_ellipse(Vector2(4, y + 16), Vector2(18, 7), fins, 0.5 + sin(_swim * 1.4) * 0.15)
	var d := _droop() * 0.3
	_eye(Vector2(44, y - 2) + d, 3.0, body)
	draw_arc(Vector2(60, y + 6) + d, 9, 0.2 + 0.5 * sad, PI * 0.5, 10, UI.INK, 1.8, true)
	draw_circle(Vector2(20, y - 26), 2.5, fins.darkened(0.2), true, -1.0, true)


## Round blobs along a line, one per point with its own radius: a smooth
## tail, mane or trunk of any curl (a polygon can't cross itself).
func _blobs(line: PackedVector2Array, radii: Array, colour: Color) -> void:
	for i in line.size():
		draw_circle(line[i], float(radii[i]), colour, true, -1.0, true)


## A golden, floppy-eared dog: rounder than the first dog, with long ears
## hanging by its cheeks, a fluffy chest and a plumed tail held high.
func _draw_dog2() -> void:
	var legs := _part("Legs", Color("#c9a46a"))
	var body := _part("Body", Color("#e2c48f"))
	var pattern := _part("Pattern", Color("#f3e3c3"))
	var bob := _bob()
	_legs([-28, -16, 16, 28], -28 - bob, 28, 10, legs)
	var tail := PackedVector2Array()
	var radii := []
	for k in 10:
		var t := k / 9.0
		var up := Vector2(-40 - 16.0 * sin(t * 1.4), -48 - 26.0 * t + sin(_phase * 2.0 + t) * 3.0 * t)
		tail.append(up.lerp(Vector2(-42 - 8.0 * t, -44 + 20.0 * t), sad))
		radii.append(7.0 - 3.0 * t)
	_blobs(tail, radii, body.lightened(0.08))
	_ellipse(Vector2(0, -44 - bob), Vector2(40, 21), body)
	var d := _droop()
	draw_circle(Vector2(28, -42 - bob), 13, pattern, true, -1.0, true)
	draw_circle(Vector2(22, -32 - bob), 9, pattern, true, -1.0, true)
	draw_circle(Vector2(44, -62 - bob) + d, 16, body, true, -1.0, true)
	_ellipse(Vector2(57, -55 - bob) + d, Vector2(9, 7), pattern)
	_ellipse(Vector2(35, -52 - bob) + d, Vector2(7, 16), legs, 0.15 + 0.2 * sad)
	_eye(Vector2(49, -66 - bob) + d, 2.5, body)
	draw_circle(Vector2(65, -57 - bob) + d, 3.2, UI.INK, true, -1.0, true)


## A fox: slim on dark legs, tall pointed ears, a long thin snout with a
## pale cheek, and a big brush of a tail with a pale tip.
func _draw_fox() -> void:
	var legs := _part("Legs", Color("#3a2a22"))
	var body := _part("Body", Color("#d46a2c"))
	var pattern := _part("Pattern", Color("#f5ead8"))
	var bob := _bob()
	_legs([-26, -16, 16, 26], -30 - bob, 30, 6, legs)
	var tail := PackedVector2Array()
	var radii := []
	for k in 14:
		var t := k / 13.0
		var out := Vector2(-32 - 40.0 * t, -40 - 10.0 * sin(t * PI) + sin(_phase * 1.5 - t * 2.0) * 3.0 * t)
		tail.append(out.lerp(Vector2(-34 - 22.0 * t, -38 + 34.0 * t), sad))
		radii.append(4.0 + 9.0 * sin(t * PI * 0.85))
	_blobs(tail, radii, body)
	_blobs(tail.slice(11), radii.slice(11), pattern)
	_ellipse(Vector2(0, -40 - bob), Vector2(36, 13), body)
	_ellipse(Vector2(24, -34 - bob), Vector2(12, 8), pattern)
	var d := _droop()
	var flat := Vector2(-5, 6) * sad
	draw_colored_polygon(PackedVector2Array([Vector2(30, -58 - bob) + d, Vector2(32, -80 - bob) + d + flat, Vector2(41, -62 - bob) + d]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(39, -62 - bob) + d, Vector2(46, -81 - bob) + d + flat, Vector2(50, -58 - bob) + d]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(33, -61 - bob) + d, Vector2(33, -74 - bob) + d + flat, Vector2(38, -63 - bob) + d]), legs)
	_ellipse(Vector2(40, -54 - bob) + d, Vector2(14, 12), body)
	draw_colored_polygon(PackedVector2Array([Vector2(46, -60 - bob) + d, Vector2(70, -51 - bob) + d, Vector2(66, -47 - bob) + d, Vector2(46, -46 - bob) + d]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(38, -48 - bob) + d, Vector2(66, -47 - bob) + d, Vector2(46, -41 - bob) + d]), pattern)
	draw_circle(Vector2(69, -50 - bob) + d, 2.6, UI.INK, true, -1.0, true)
	_eye(Vector2(46, -58 - bob) + d, 2.2, body)


## A tiger: a heavy cat with dark stripes, round ears, a pale muzzle and a
## long ringed tail.
func _draw_tiger() -> void:
	var legs := _part("Legs", Color("#c9662a"))
	var body := _part("Body", Color("#e07a30"))
	var eyes := _part("Eyes", Color("#e2c046"))
	var stripe := legs.darkened(0.62)
	var pale := body.lightened(0.6)
	var bob := _bob(1.5)
	_legs([-28, -16, 16, 28], -28 - bob, 28, 10, legs)
	var tail := PackedVector2Array()
	for i in 12:
		var t := i / 11.0
		tail.append(Vector2(-38 - 22.0 * t, -44 + lerpf(-t * 18.0, t * 34.0, sad) + sin(_phase + t * 3.0) * 3.0 * (1.0 - sad)))
	draw_polyline(tail, body, 6, true)
	for i in [4, 7, 10]:
		draw_circle(tail[i], 3.2, stripe, true, -1.0, true)
	_ellipse(Vector2(0, -42 - bob), Vector2(42, 17), body)
	_ellipse(Vector2(6, -32 - bob), Vector2(28, 7), pale)
	for x in [-30.0, -18.0, -6.0, 6.0, 18.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -58 - bob), Vector2(x + 4, -58 - bob), Vector2(x + 3, -44 - bob)]), stripe)
	var d := _droop() * 0.8
	draw_circle(Vector2(36, -66 - bob) + d, 5.5, body, true, -1.0, true)
	draw_circle(Vector2(50, -67 - bob) + d, 5.5, body, true, -1.0, true)
	draw_circle(Vector2(44, -56 - bob) + d, 15, body, true, -1.0, true)
	_ellipse(Vector2(54, -50 - bob) + d, Vector2(8, 6), pale)
	for k in 3:
		draw_line(Vector2(36 + 4 * k, -70 - bob) + d, Vector2(37 + 4 * k, -64 - bob) + d, stripe, 2.0, true)
	draw_circle(Vector2(50, -59 - bob) + d, 3.0, eyes, true, -1.0, true)
	draw_circle(Vector2(50, -59 - bob) + d, 1.3, UI.INK, true, -1.0, true)
	_lid(Vector2(50, -59 - bob) + d, 3.0, body)
	draw_circle(Vector2(60, -52 - bob) + d, 2.6, UI.INK, true, -1.0, true)


## A leopard: long, low and lean, covered in ringed spots, with a long tail
## that curls up at the tip.
func _draw_leopard() -> void:
	var legs := _part("Legs", Color("#c99a4a"))
	var body := _part("Body", Color("#e2b85a"))
	var eyes := _part("Eyes", Color("#9ac04a"))
	var spot := legs.darkened(0.6)
	var bob := _bob(1.2)
	_legs([-28, -18, 18, 28], -30 - bob, 30, 6, legs)
	var tail := PackedVector2Array()
	for i in 14:
		var t := i / 13.0
		var curl := Vector2(-36 - 30.0 * t, -38 + 14.0 * t - 22.0 * t * t * t + sin(_phase + t * 3.0) * 2.0)
		tail.append(curl.lerp(Vector2(-36 - 18.0 * t, -38 + 34.0 * t), sad))
	draw_polyline(tail, body, 5, true)
	_ellipse(Vector2(0, -40 - bob), Vector2(40, 13), body)
	for c in [Vector2(-26, -42), Vector2(-14, -48), Vector2(-4, -38), Vector2(8, -46), Vector2(20, -40), Vector2(-20, -34), Vector2(2, -50)]:
		draw_arc(c - Vector2(0, bob), 3.4, 0.0, TAU, 10, spot, 1.6, true)
	for c in [Vector2(-28, -18), Vector2(18, -16)]:
		draw_circle(c - Vector2(0, bob), 1.8, spot, true, -1.0, true)
	var d := _droop() * 0.8
	draw_circle(Vector2(34, -60 - bob) + d, 4.5, body, true, -1.0, true)
	draw_circle(Vector2(44, -61 - bob) + d, 4.5, body, true, -1.0, true)
	_ellipse(Vector2(40, -52 - bob) + d, Vector2(12, 10), body)
	draw_circle(Vector2(36, -50 - bob) + d, 1.4, spot, true, -1.0, true)
	draw_circle(Vector2(46, -55 - bob) + d, 2.6, eyes, true, -1.0, true)
	draw_circle(Vector2(46, -55 - bob) + d, 1.1, UI.INK, true, -1.0, true)
	_lid(Vector2(46, -55 - bob) + d, 2.6, body)
	draw_circle(Vector2(52, -49 - bob) + d, 2.2, UI.INK, true, -1.0, true)


## A lion: a big round mane round its head, a pale muzzle, and a thin tail
## with a dark tuft on the end.
func _draw_lion() -> void:
	var legs := _part("Legs", Color("#b8863a"))
	var body := _part("Body", Color("#d9a85a"))
	var eyes := _part("Eyes", Color("#c98a2a"))
	var mane := legs.darkened(0.3)
	var bob := _bob(1.5)
	_legs([-28, -16, 16, 28], -28 - bob, 28, 9, legs)
	var tip := Vector2(-62, -62 - bob + sin(_phase * 1.5) * 4.0).lerp(Vector2(-54, -18), sad)
	draw_line(Vector2(-38, -46 - bob), tip, body, 4, true)
	draw_circle(tip, 6, mane, true, -1.0, true)
	_ellipse(Vector2(0, -42 - bob), Vector2(40, 17), body)
	var d := _droop() * 0.8
	var head := Vector2(42, -58 - bob) + d
	for k in 12:
		var a := TAU * k / 12.0
		draw_circle(head + Vector2(cos(a) * 17.0 - 4.0, sin(a) * 19.0), 9, mane, true, -1.0, true)
	draw_circle(head + Vector2(-4, 0), 18, mane, true, -1.0, true)
	draw_circle(head + Vector2(-8, -14), 4.5, body, true, -1.0, true)
	draw_circle(head + Vector2(4, -14), 4.5, body, true, -1.0, true)
	draw_circle(head, 13, body, true, -1.0, true)
	_ellipse(head + Vector2(9, 6), Vector2(8, 6), body.lightened(0.45))
	draw_circle(head + Vector2(5, -3), 2.8, eyes, true, -1.0, true)
	draw_circle(head + Vector2(5, -3), 1.2, UI.INK, true, -1.0, true)
	_lid(head + Vector2(5, -3), 2.8, body)
	draw_circle(head + Vector2(15, 4), 2.6, UI.INK, true, -1.0, true)


## A red panda: long and low on short dark legs, a round face with pale
## cheeks, brows and ear rims, and a fat ringed tail.
func _draw_red_panda() -> void:
	var legs := _part("Legs", Color("#3a2420"))
	var body := _part("Body", Color("#b8502a"))
	var eyes := _part("Eyes", Color("#2b2523"))
	var pale := Color("#f4ede4")
	var bob := _bob(1.5)
	_legs([-22, -12, 12, 22], -22 - bob, 22, 8, legs)
	var tail := PackedVector2Array()
	var radii := []
	for k in 14:
		var t := k / 13.0
		var out := Vector2(-28 - 38.0 * t, -32 - 8.0 * sin(t * PI) + sin(_phase - t * 2.0) * 2.0 * t)
		tail.append(out.lerp(Vector2(-30 - 20.0 * t, -30 + 26.0 * t), sad))
		radii.append(8.0 + 2.0 * sin(t * PI))
	_blobs(tail, radii, body.lightened(0.2))
	for k in [4, 8, 12]:
		draw_circle(tail[k], radii[k] + 0.5, body.darkened(0.35), true, -1.0, true)
	_ellipse(Vector2(0, -32 - bob), Vector2(30, 13), body)
	_ellipse(Vector2(4, -22 - bob), Vector2(22, 5), legs)
	var d := _droop() * 0.8
	var head := Vector2(36, -44 - bob) + d
	var flat := Vector2(-3, 4) * sad
	for x in [-8.0, 6.0]:
		draw_circle(head + Vector2(x, -12) + flat, 6, pale, true, -1.0, true)
		draw_circle(head + Vector2(x, -11) + flat, 4, body.darkened(0.2), true, -1.0, true)
	draw_circle(head, 13, body, true, -1.0, true)
	_ellipse(head + Vector2(8, 4), Vector2(8, 6), pale)
	_ellipse(head + Vector2(-4, 4), Vector2(5, 4), pale)
	draw_circle(head + Vector2(3, -7), 2.6, pale, true, -1.0, true)
	draw_line(head + Vector2(4, -1), head + Vector2(2, 6), eyes.darkened(0.2), 2.0, true)
	_eye(head + Vector2(4, -2), 2.4, body)
	draw_circle(head + Vector2(15, 2), 2.4, UI.INK, true, -1.0, true)


## A rock hyrax: a small, round, tailless lump with tiny round ears and a
## pale belly, scampering in little hops.
func _draw_hyrax() -> void:
	var legs := _part("Legs", Color("#6e5a48"))
	var body := _part("Body", Color("#9c8468"))
	var pattern := _part("Pattern", Color("#d9c6a8"))
	var hop := _hop(0.5, 8.0)
	for x in [-14.0, 12.0]:
		_ellipse(Vector2(x, -5 - hop), Vector2(7, 6), legs)
	_ellipse(Vector2(0, -22 - hop), Vector2(25, 16), body)
	_ellipse(Vector2(2, -13 - hop), Vector2(17, 6), pattern)
	draw_circle(Vector2(-6, -32 - hop), 3.0, legs.darkened(0.2), true, -1.0, true)
	var d := _droop() * 0.5
	draw_circle(Vector2(12, -40 - hop) + d + Vector2(-2, 3) * sad, 4.5, body.darkened(0.1), true, -1.0, true)
	draw_circle(Vector2(20, -30 - hop) + d, 12, body, true, -1.0, true)
	_ellipse(Vector2(29, -26 - hop) + d, Vector2(6, 5), pattern)
	draw_circle(Vector2(34, -27 - hop) + d, 2.2, UI.INK, true, -1.0, true)
	_eye(Vector2(23, -33 - hop) + d, 2.2, body)


## A parakeet: small and upright, with a long thin tail, a hooked beak and
## a bright cheek.
func _draw_parakeet() -> void:
	var wings := _part("Wings", Color("#2f8a4a"))
	var body := _part("Body", Color("#6fcf5a"))
	var pattern := _part("Pattern", Color("#e04a3a"))
	var hop := _hop(0.7, 8.0)
	var tail := PackedVector2Array()
	var radii := []
	for k in 10:
		var t := k / 9.0
		tail.append(Vector2(-6 - 30.0 * t, -22 - hop + 18.0 * t + sin(_phase * 2.0) * 1.5 * t))
		radii.append(4.5 - 3.0 * t)
	_blobs(tail, radii, wings.darkened(0.1))
	draw_line(Vector2(-2, -12 - hop), Vector2(-4, 0), Color("#8a8f9a"), 2, true)
	draw_line(Vector2(6, -12 - hop), Vector2(7, 0), Color("#8a8f9a"), 2, true)
	_ellipse(Vector2(2, -28 - hop), Vector2(12, 18), body, 0.35)
	var flap := sin(_phase * 2.0) * 0.4 if walking else 0.0
	_ellipse(Vector2(-4, -28 - hop), Vector2(14, 7), wings, -0.6 + flap)
	var d := _droop() * 0.5
	var head := Vector2(12, -46 - hop) + d
	draw_circle(head, 9, body, true, -1.0, true)
	draw_circle(head + Vector2(3, 5), 3.0, pattern, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -4), head + Vector2(13, -2), head + Vector2(12, 4), head + Vector2(7, 3)]), pattern.lightened(0.35))
	_eye(head + Vector2(2, -3), 1.8, body)


## An eagle: a big dark bird with a white head and tail, wings folded down
## its sides, a hooked yellow beak and yellow feet.
func _draw_eagle() -> void:
	var wings := _part("Wings", Color("#4a3528"))
	var body := _part("Body", Color("#6b4c38"))
	var pattern := _part("Pattern", Color("#f5f0e6"))
	var yellow := Color("#e2a615")
	var hop := _hop(0.7, 6.0)
	for x in [-6.0, 8.0]:
		draw_line(Vector2(x, -14 - hop), Vector2(x, -2), yellow, 4, true)
		draw_line(Vector2(x - 2, -1), Vector2(x + 6, -1), yellow.darkened(0.2), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -26 - hop), Vector2(-42, -16 - hop), Vector2(-40, -6 - hop), Vector2(-14, -18 - hop)]), pattern)
	_ellipse(Vector2(0, -32 - hop), Vector2(22, 20), body, 0.3)
	var flap := sin(_phase * 2.0) * 0.25 if walking else 0.0
	_ellipse(Vector2(-8, -32 - hop), Vector2(26, 11), wings, -0.45 + flap)
	var d := _droop() * 0.5
	var head := Vector2(18, -52 - hop) + d
	draw_circle(head, 12, pattern, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(8, -6), head + Vector2(20, -2), head + Vector2(19, 6), head + Vector2(14, 2), head + Vector2(8, 3)]), yellow)
	_eye(head + Vector2(4, -3), 2.2, pattern)
	draw_line(head + Vector2(0, -7), head + Vector2(8, -5), UI.INK, 1.6, true)


## A woolly mammoth: an elephant's shape under shaggy hair, with a domed
## head, a hump, small ears and long tusks curling up.
func _draw_mammoth() -> void:
	var legs := _part("Legs", Color("#4a3528"))
	var body := _part("Body", Color("#6b4c38"))
	var pattern := _part("Pattern", Color("#a07e62"))
	var ivory := Color("#f1e6cf")
	var bob := _bob(2.5)
	for i in 4:
		var x: float = [-30, -12, 16, 34][i]
		var swing := sin(_phase + PI * (i % 2)) * 0.25 * _stride() if walking else 0.0
		draw_line(Vector2(x, -34 - bob), Vector2(x, -34 - bob) + Vector2(0, 34).rotated(swing), legs if i % 2 == 0 else legs.darkened(0.08), 17, true)
	_ellipse(Vector2(0, -60 - bob), Vector2(48, 30), body)
	draw_circle(Vector2(18, -78 - bob), 22, body, true, -1.0, true)
	# Shaggy hair hangs in a ragged fringe below its belly.
	var fringe := PackedVector2Array([Vector2(-48, -52 - bob)])
	for k in 12:
		var x := -46.0 + k * 8.0
		fringe.append(Vector2(x + 4.0, -26 - bob - (k % 3) * 3.0))
		fringe.append(Vector2(x + 8.0, -40 - bob))
	fringe.append(Vector2(48, -52 - bob))
	draw_colored_polygon(fringe, body.darkened(0.12))
	for k in 6:
		draw_arc(Vector2(-30 + k * 12, -66 - bob), 8, 0.4, 1.6, 6, pattern, 2.0, true)
	var d := _droop() * 0.6
	draw_circle(Vector2(48, -78 - bob) + d, 20, body, true, -1.0, true)
	draw_circle(Vector2(44, -94 - bob) + d, 12, body, true, -1.0, true)
	var trunk := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		trunk.append(Vector2(62, -70 - bob) + d + Vector2(8.0 * sin(t * 1.6), 46.0 * t) + Vector2(sin(_phase + t * 2.0) * 3.0 * t, 0))
	draw_polyline(trunk, body, 9, true)
	var tusk := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		tusk.append(Vector2(58, -60 - bob) + d + Vector2(28.0 * t, 18.0 * t - 36.0 * t * t))
	draw_polyline(tusk, ivory, 5, true)
	_ellipse(Vector2(36, -78 - bob) + d, Vector2(8, 11), pattern, 0.2 + 0.3 * sad)
	_eye(Vector2(54, -84 - bob) + d, 2.5, body)


## A monkey on all fours: long arms and legs, a round head with a pale face
## and big ears, and a long tail curling up behind.
func _draw_monkey() -> void:
	var legs := _part("Legs", Color("#5a3b28"))
	var body := _part("Body", Color("#7a5236"))
	var face := _part("Face", Color("#e2c4a0"))
	var bob := _bob(2.5)
	var tail := PackedVector2Array()
	for k in 18:
		var t := k / 17.0
		var a := t * PI * 1.6
		var up := Vector2(-24 - 16.0 * t, -36 - 34.0 * t) + Vector2(-cos(a) * 8.0 * t, sin(a) * 8.0 * t) + Vector2(sin(_phase + t * 3.0) * 2.0 * t, 0)
		tail.append(up.lerp(Vector2(-26 - 10.0 * t, -34 + 30.0 * t), sad))
	draw_polyline(tail, body, 4, true)
	_legs([-20, -10], -34 - bob, 34, 7, legs)
	_legs([16, 24], -40 - bob, 40, 6, legs)
	_ellipse(Vector2(0, -42 - bob), Vector2(28, 13), body, -0.2)
	var d := _droop() * 0.8
	var head := Vector2(32, -58 - bob) + d
	draw_circle(head + Vector2(-11, 0), 6, face.darkened(0.1), true, -1.0, true)
	draw_circle(head, 13, body, true, -1.0, true)
	_ellipse(head + Vector2(5, 2), Vector2(9, 10), face)
	_ellipse(head + Vector2(9, 8), Vector2(6, 4), face.lightened(0.15))
	_eye(head + Vector2(4, -3), 2.0, face)
	_eye(head + Vector2(10, -3), 2.0, face)
	draw_arc(head + Vector2(9, 8), 3, 0.3 + 0.6 * sad, PI - 0.3 - 0.6 * sad, 6, UI.INK, 1.2, true)


## A gorilla knuckle-walking: huge shoulders over long thick arms, short
## legs behind, a silver saddle on its back and a small head with a heavy
## brow.
func _draw_gorilla() -> void:
	var legs := _part("Legs", Color("#2a2628"))
	var body := _part("Body", Color("#3a3434"))
	var face := _part("Face", Color("#6e625a"))
	var bob := _bob(2.0)
	_legs([-26, -14], -26 - bob, 26, 13, legs)
	_ellipse(Vector2(0, -46 - bob), Vector2(40, 26), body, -0.25)
	_ellipse(Vector2(-10, -58 - bob), Vector2(22, 9), body.lightened(0.4), -0.2)
	for i in 2:
		var swing := sin(_phase + PI * i) * 0.3 * _stride() if walking else 0.0
		var shoulder := Vector2(24 + 8 * i, -54 - bob)
		var knuckle := shoulder + Vector2(10, 54).rotated(swing)
		draw_line(shoulder, knuckle, legs if i == 0 else legs.lightened(0.08), 15 - i, true)
		draw_circle(knuckle, 7.5, legs.lightened(0.06), true, -1.0, true)
	var d := _droop() * 0.8
	var head := Vector2(44, -66 - bob) + d
	draw_circle(head, 14, body, true, -1.0, true)
	_ellipse(head + Vector2(6, 4), Vector2(9, 9), face)
	draw_line(head + Vector2(0, -6), head + Vector2(14, -5), body.darkened(0.3), 4, true)
	_eye(head + Vector2(8, -2), 2.0, face)
	draw_circle(head + Vector2(13, 5), 1.4, UI.INK, true, -1.0, true)
