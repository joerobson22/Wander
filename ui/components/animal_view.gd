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
}
## Where each shape's lead clips on, before any bounce in its step.
const NECKS := {
	"bear": Vector2(30, -58), "cat": Vector2(28, -46), "rabbit": Vector2(14, -40),
	"snail": Vector2(32, -12), "bird": Vector2(11, -38), "sheep": Vector2(32, -54),
	"pig": Vector2(34, -44), "tortoise": Vector2(36, -18), "frog": Vector2(22, -26),
	"elephant": Vector2(40, -78), "giraffe": Vector2(32, -96), "snake": Vector2(40, -14),
	"lizard": Vector2(30, -12), "spider": Vector2(14, -18), "rhino": Vector2(40, -62),
	"egg": Vector2(16, -40), "cake": Vector2(18, -44), "reindeer": Vector2(34, -58),
}

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
		queue_redraw()

var _phase: float = 0.0
var _sigh: float = 0.0
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
	add_child(_overlay)
	_player = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_tint_rig()
	_animate()
	queue_redraw()


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


func _process(delta: float) -> void:
	if _rig:
		_animate_rig(delta)
		return
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
	if sad > 0.0:
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
		_:
			_draw_dog()
	_draw_over(self, str(data.get("shape", "dog")))


## The water over the legs and the gift in the mouth, on whichever node
## draws last.
func _draw_over(canvas: CanvasItem, shape: String) -> void:
	if submerged > 0.5:
		canvas.draw_rect(Rect2(-90, -submerged, 190, submerged + 10), Color(water_colour, 0.92))
		canvas.draw_line(Vector2(-60, -submerged), Vector2(80, -submerged), Color(1, 1, 1, 0.55), 2.0, true)
	if held_gift != "":
		_draw_held_gift(canvas, shape)


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
			"frog":
				lift = _hop(0.5, 16.0)
			"bird":
				lift = absf(sin(_phase * 0.7)) * 8.0 * _stride()
			_:
				lift = absf(sin(_phase)) * 2.0 * _stride()
	return (at - Vector2(0, lift)) * float(data.get("size", 1.0))


## The gift's position in this node's own space (for glows behind it).
func mouth() -> Vector2:
	if _rig:
		return _marker("Mouth", MOUTHS.get(str(Content.animal(animal_id).get("shape", "dog")), Vector2(60, -50)))
	var s := float(Content.animal(animal_id).get("size", 1.0))
	return MOUTHS.get(str(Content.animal(animal_id).get("shape", "dog")), Vector2(60, -50)) * s


func _draw_held_gift(canvas: CanvasItem, shape: String) -> void:
	var g := Content.gift(held_gift)
	var colour := Content.rarity_colour(g.get("rarity", "common"))
	var at: Vector2 = _marker("Mouth", MOUTHS.get(shape, Vector2(60, -50))) / float(Content.animal(animal_id).get("size", 1.0)) if _rig else MOUTHS.get(shape, Vector2(60, -50))
	canvas.draw_circle(at, 15, Color(colour, 0.22), true, -1.0, true)
	canvas.draw_circle(at, 11, UI.SURFACE, true, -1.0, true)
	var art := GiftArt.texture_for(held_gift)
	if art:
		canvas.draw_texture_rect(art, Rect2(at - Vector2(9, 9), Vector2(18, 18)), false)
	else:
		canvas.draw_texture(Icons.texture("gift", 16, colour), at - Vector2(8, 8))


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
