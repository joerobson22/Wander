class_name CharacterView
extends Node2D
## The player's character (or a friend's): Joe's own art when there is some
## (art/character/character.tscn, see art/README.md), else drawn from simple
## shapes. The origin is at the feet and it faces right.
## `look` is {skin_tone, hair_tone, cosmetics: {slot: item id}}; leave it
## empty to follow the player's own profile. `face_only` draws just the head
## and shoulders, centred on the face, for avatars. `part` draws just one
## slot's item on its own (see part_rect()), for the customise list.

const STICK := Color("#7a5236")
const ART_ROOT := "res://art/"
const SHADER := "res://art/animal_colours.gdshader"
## The rig's limbs (node names, found anywhere in the rig) and the file name
## each cosmetic uses for its piece on that limb.
const LIMBS := {"Torso": "torso", "Head": "head", "ArmBack": "arm_back", "ArmFront": "arm_front", "LegBack": "leg_back", "LegFront": "leg_front"}
## Cosmetics stack on a limb in this order, first at the bottom.
const DRESS_ORDER := ["trousers", "shoes", "gloves", "top", "neckwear", "face", "facial_hair", "hair", "hat", "walking_stick"]
const EXTENSIONS := ["png", "svg", "webp"]
## Where the head sits, standing still.
const HEAD := Vector2(2, -124)

@export var walking: bool = false:
	set(v):
		walking = v
		_animate()
@export var speed: float = 1.0:
	set(v):
		speed = v
		_animate()
## Where the art lives (the folder holding character/ and cosmetics/).
var art_root := ART_ROOT:
	set(v):
		art_root = v
		_load_rig()

var look: Dictionary = {}:
	set(v):
		look = v
		queue_redraw()
		_dress()
var face_only := false:
	set(v):
		face_only = v
		queue_redraw()
		_dress()
## A slot id ("hat", "top"...) to draw only what's worn there, or "" for
## the whole character.
var part := "":
	set(v):
		part = v
		queue_redraw()
		_dress()
## Reaching forward for the lead on a walk; arms down for portraits.
var holding_lead := true
## Wears a holiday's hat (the party hat on your birthday) over the look's
## own: always for you (no look of its own), and for a look of yours being
## changed (the customise preview).
var holiday_hat := false:
	set(v):
		holiday_hat = v
		_dress()
## Hand position in local space, so the walk screen can draw the lead.
var hand := Vector2(22, -78)
## 0 normally, up to 1 when they're dejected: shoulders down, head hung,
## a frown, and a sigh now and then.
var sad := 0.0:
	set(v):
		var changed := (v > 0.5) != (sad > 0.5)
		sad = v
		queue_redraw()
		if changed:
			_dress()

var _phase: float = 0.0
var _sigh: float = 0.0
## The art rig, its animations, each limb's node and rest pose (in the rig's
## space), the pieces of clothing laid on the limbs, and the rig's own sprites.
var _rig: Node2D
var _player: AnimationPlayer
var _limbs := {}
var _dressing: Array[Node] = []
var _body: Array[Sprite2D] = []
var _materials := {}
var _rig_base := Vector2.ZERO
static var _textures := {}


func _ready() -> void:
	_load_rig()


## The scene holding the character's art, or "" if it has none yet.
static func rig_path(root: String = ART_ROOT) -> String:
	var path := root + "character/character.tscn"
	return path if ResourceLoader.exists(path) else ""


func has_art() -> bool:
	return _rig != null


func _load_rig() -> void:
	if _rig:
		_rig.free()
		_rig = null
		_player = null
		_limbs.clear()
		_dressing.clear()
		_body.clear()
	var path := rig_path(art_root)
	if path == "":
		queue_redraw()
		return
	_rig = (load(path) as PackedScene).instantiate() as Node2D
	if _rig == null:
		return
	add_child(_rig)
	_player = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for limb in LIMBS:
		var node := _rig.find_child(limb, true, false) as Node2D
		if node:
			_limbs[limb] = {"node": node, "rest": _rest_in_rig(node)}
	for sprite in _rig.find_children("*", "Sprite2D", true, false):
		_body.append(sprite)
	queue_redraw()
	_dress()
	_animate()


## A node's transform in the rig's space as the scene has it (the standing
## pose, before any animation moves it).
func _rest_in_rig(node: Node2D) -> Transform2D:
	var t := node.transform
	var up := node.get_parent()
	while up != _rig and up is Node2D:
		t = (up as Node2D).transform * t
		up = up.get_parent()
	return t


func _animate() -> void:
	if _player == null:
		return
	var anim := "walk" if walking else "idle"
	_player.speed_scale = 1.4 * speed
	if part != "" or not _player.has_animation(anim):
		_player.stop()
	elif _player.current_animation != anim or not _player.is_playing():
		_player.play(anim)


static func _texture(path_no_ext: String) -> Texture2D:
	if not _textures.has(path_no_ext):
		_textures[path_no_ext] = null
		for ext in EXTENSIONS:
			var path: String = path_no_ext + "." + ext
			if ResourceLoader.exists(path):
				_textures[path_no_ext] = load(path)
				break
	return _textures[path_no_ext]


## Red, green and blue paint become a colour, a shade of it and a light one.
func _tone_material(colour: Color) -> ShaderMaterial:
	var key := colour.to_html()
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(SHADER) as Shader
		m.set_shader_parameter("colour_r", colour)
		m.set_shader_parameter("colour_g", colour.darkened(0.2))
		m.set_shader_parameter("colour_b", colour.lightened(0.2))
		_materials[key] = m
	return _materials[key]


## Puts the look on the rig: skin on its own sprites, then each worn item's
## pieces on the limbs they belong to. An item <id> has a folder
## cosmetics/<id>/ with a full-canvas image per limb (torso.png, head.png,
## arm_front.png...), `_behind` after the name to go under the limb's art
## and `_sad` to replace it when they're sad. Starter items with a colour
## and hair take the colour (red, green and blue paint as for animals);
## wearable gifts show as drawn. An item with no art isn't shown.
func _dress() -> void:
	if _rig == null:
		return
	for n in _dressing:
		if is_instance_valid(n):
			n.free()
	_dressing.clear()
	var skin := _tone_material(_skin())
	for sprite in _body:
		sprite.material = skin
		# Seen on their own, items hide the body, head and all: hair, a face
		# or facial hair show just themselves.
		sprite.visible = part == ""
	for limb in ["ArmBack", "ArmFront", "LegBack", "LegFront"]:
		if _limbs.has(limb):
			(_limbs[limb]["node"] as Node2D).visible = not face_only
	_rig_base = Vector2.ZERO
	if face_only and _limbs.has("Head"):
		_rig_base = -(_limbs["Head"]["rest"] as Transform2D).origin
	_rig.position = _rig_base
	var slots: Array = [part] if part != "" else DRESS_ORDER
	for slot in slots:
		var item := _item(slot)
		var id := str(item.get("id", ""))
		if id == "":
			continue
		var tint: ShaderMaterial = null
		if slot == "hair":
			tint = _tone_material(_hair())
		elif item.has("colour") and not item.has("rarity"):
			tint = _tone_material(Color.from_string(item["colour"], Color.WHITE))
		for limb in _limbs:
			var stem: String = LIMBS[limb]
			var dir: String = art_root + "cosmetics/" + id + "/"
			var above: Texture2D = _texture(dir + stem + "_sad") if sad > 0.5 else null
			if above == null:
				above = _texture(dir + stem)
			_attach(limb, above, false, tint)
			_attach(limb, _texture(dir + stem + "_behind"), true, tint)
	_animate()


func _attach(limb: String, tex: Texture2D, behind: bool, tint: Material) -> void:
	if tex == null:
		return
	var node: Node2D = _limbs[limb]["node"]
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	# The image is a whole canvas with the feet at the bottom middle; the limb
	# moves, so lay the canvas back where it was when the limb was at rest.
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	sprite.transform = (_limbs[limb]["rest"] as Transform2D).affine_inverse()
	sprite.material = tint
	node.add_child(sprite)
	if behind:
		sprite.show_behind_parent = true
		node.move_child(sprite, 0)
	_dressing.append(sprite)


func _process(delta: float) -> void:
	if _rig:
		_process_rig(delta)
		return
	if walking:
		_phase += delta * TAU * 1.4 * speed
		queue_redraw()
	if sad > 0.0:
		_sigh += delta
		queue_redraw()


## The slump when they're sad (a hung head, sinking shoulders), on top of
## the animation, and the hand where the lead clips on.
func _process_rig(delta: float) -> void:
	if sad > 0.0:
		_sigh += delta
	var drop := 4.0 * sad + (sin(_sigh * 1.3) * 0.5 + 0.5) * 1.5 * sad if sad > 0.0 else 0.0
	_rig.position = _rig_base + Vector2(0, 0.0 if face_only else drop)
	var marker := _rig.find_child("Hand", true, false) as Node2D
	if marker and is_inside_tree():
		hand = global_transform.affine_inverse() * marker.global_position


## Redraws after the look it follows has changed.
func refresh() -> void:
	queue_redraw()
	_dress()


func _look() -> Dictionary:
	return look if not look.is_empty() else App.state.profile


func _item(slot: String) -> Dictionary:
	var cosmetics: Dictionary = _look().get("cosmetics", {})
	var id := str(cosmetics.get(slot, ""))
	# Your own hat on a holiday that picks it (the party hat on your birthday).
	if slot == "hat" and (look.is_empty() or holiday_hat) and App.holiday_hat() != "":
		id = App.holiday_hat()
	var item := Content.cosmetic(id) if id != "" else {}
	return item if not item.is_empty() else Content.default_cosmetic(slot)


static func _style(item: Dictionary) -> String:
	return str(item.get("style", "none"))


## The room `part` takes when drawn on its own, in this node's space, so a
## box can scale it to fit. The head is drawn with a hairstyle or a face.
static func part_rect(slot: String, item: Dictionary) -> Rect2:
	match slot:
		"hat":
			var tops := {"witch": 48, "party": 48, "bunny_ears": 44, "antlers": 42, "pot": 38, "alpine": 36, "tophat": 34, "feather_cap": 32, "ears": 28, "beanie": 26, "nest": 26}
			var top := float(tops.get(_style(item), 22))
			if _style(item) == "pumpkin":
				return Rect2(HEAD.x - 25, HEAD.y - 28, 50, 52)
			return Rect2(HEAD.x - 24, HEAD.y - top, 50, top + 2)
		"hair":
			return Rect2(HEAD.x - 21, HEAD.y - 25, 42, 50 if _style(item) == "long" else 30)
		"face":
			return Rect2(HEAD.x + 1, HEAD.y - 8, 16, 18)
		"facial_hair":
			return Rect2(HEAD.x - 2, HEAD.y - 2, 22, 24)
		"neckwear":
			match _style(item):
				"bowtie":
					return Rect2(3, -111, 18, 15)
				"necklace":
					return Rect2(-9, -112, 24, 20)
			return Rect2(-15, -111, 30, 28)
		"top":
			return Rect2(-27, -120, 54, 56)
		"gloves":
			return Rect2(-16, -8, 32, 16)
		"walking_stick":
			return Rect2(0, -78, 22, 80)
		"trousers":
			return Rect2(-16, -62, 32, 62) if _style(item) != "shorts" else Rect2(-16, -62, 32, 32)
		"shoes":
			return Rect2(-18, -17, 42, 19)
	return Rect2(-20, -175, 40, 175)


func _skin() -> Color:
	return Content.skin_of(_look())


func _hair() -> Color:
	return Content.hair_of(_look())


func _draw() -> void:
	if _rig:
		return
	var skin := _skin()
	var hair := _hair()
	if part != "":
		_draw_part(skin, hair)
		return
	var top := _item("top")
	var top_colour := Content.cosmetic_colour(top, Color("#b4533f"))
	var bob := absf(sin(_phase)) * 2.0 if walking and not face_only else 0.0
	# Slumped: everything above the hips sinks a little, and the head hangs.
	if not face_only:
		bob -= 4.0 * sad + (sin(_sigh * 1.3) * 0.5 + 0.5) * 1.5 * sad
	var head := HEAD + Vector2(5.0 * sad, -bob + 7.0 * sad)
	if face_only:
		draw_set_transform(-head)

	if _style(top) == "cape" and not face_only:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10, -106 - bob), Vector2(6, -106 - bob), Vector2(-8, -38 - bob), Vector2(-30, -42 - bob + sin(_phase) * 3.0)]),
			top_colour.darkened(0.1))
	if _style(top) == "hoodie":
		draw_circle(head + Vector2(-10, 8), 11, top_colour.darkened(0.18), true, -1.0, true)

	var shoulder := Vector2(0, -100 - bob)
	var sleeve := top_colour if _style(top) != "cape" else top_colour.lightened(0.35)
	if face_only:
		draw_rect(Rect2(-17, -110, 36, 40), sleeve)
	else:
		_draw_body(skin, top, sleeve, shoulder, bob)

	_draw_neckwear(bob)
	_draw_head(head, skin, hair)


func _draw_body(skin: Color, top: Dictionary, sleeve: Color, shoulder: Vector2, bob: float) -> void:
	var gloves := _item("gloves")
	var trousers := _item("trousers")
	var trouser_colour := Content.cosmetic_colour(trousers, Color("#4b5a6e"))
	var tee := _style(top) == "tee"

	# Back arm.
	var arm_swing := sin(_phase + PI) * 0.35 if walking else 0.0
	var back_hand := shoulder + Vector2(0, 40).rotated(arm_swing)
	_draw_arm(shoulder, back_hand, sleeve.darkened(0.15), skin.darkened(0.1), tee)
	_draw_hand(back_hand, skin.darkened(0.1), gloves, 0.1)

	# Legs and shoes, back leg a shade darker.
	for i in 2:
		var swing := sin(_phase + PI * i) * 0.4 if walking else 0.0
		var hip := Vector2(0, -56 - bob)
		var foot := hip + Vector2(0, 54).rotated(swing)
		var knee := hip.lerp(foot, 0.5)
		var shade := 0.12 if i == 0 else 0.0
		if _style(trousers) == "shorts":
			draw_line(hip, knee, trouser_colour.darkened(shade), 12, true)
			draw_line(knee, foot, skin.darkened(shade), 8, true)
		else:
			draw_line(hip, foot, trouser_colour.darkened(shade), 11, true)
		_draw_shoe(foot, shade)

	_draw_torso(top, sleeve, bob)

	# Front arm, holding the lead (or hanging down when there isn't one).
	hand = Vector2(22, -78 - bob) if holding_lead else shoulder + Vector2(3, 40).rotated(sin(_phase) * 0.35 if walking else 0.0)
	_draw_arm(shoulder, hand, sleeve, skin, tee)
	_draw_hand(hand, skin, gloves, 0.0)
	_draw_stick(hand)


## Only what's worn in `part`, standing still.
func _draw_part(skin: Color, hair: Color) -> void:
	var item := _item(part)
	match part:
		"hat":
			_draw_hat(HEAD)
		"hair":
			# Just the hair, with no head under it.
			var colour := _hair_colour(hair)
			_draw_hair(HEAD, colour, true)
			_draw_hair(HEAD, colour, false)
		"face":
			_draw_face(HEAD)
		"facial_hair":
			_draw_facial_hair(HEAD, _hair_colour(hair))
		"neckwear":
			_draw_neckwear(0.0)
		"top":
			_draw_top_flat(item, skin)
		"gloves":
			_draw_hand(Vector2(-8, 0), skin.darkened(0.1), item, 0.1)
			_draw_hand(Vector2(8, 0), skin, item, 0.0)
		"walking_stick":
			_draw_stick(Vector2(3, -60))
		"trousers":
			_draw_trousers_flat(item)
		"shoes":
			_draw_shoe(Vector2(-10, 0), 0.12)
			_draw_shoe(Vector2(8, 0), 0.0)


## A top laid flat, facing out, so its shape reads at a glance: the body,
## sleeves out to the sides, and its trim (a hood, a hem, a cape behind).
func _draw_top_flat(top: Dictionary, skin: Color) -> void:
	var colour := Content.cosmetic_colour(top, Color("#b4533f"))
	var style := _style(top)
	var body := colour if style != "cape" else colour.lightened(0.35)
	if style == "cape":
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -110), Vector2(12, -110), Vector2(22, -66), Vector2(-22, -66)]), colour.darkened(0.1))
	if style == "hoodie":
		draw_circle(Vector2(0, -110), 9, colour.darkened(0.18), true, -1.0, true)
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(10 * side, -106)
		var cuff := Vector2(21 * side, -76)
		if style == "tee":
			var elbow := shoulder.lerp(cuff, 0.4)
			draw_line(shoulder, elbow, body, 10, true)
			draw_line(elbow, cuff, skin, 7, true)
		else:
			draw_line(shoulder, cuff, body.darkened(0.06), 9, true)
	draw_style_box(UI.box(body, Color.TRANSPARENT, 3), Rect2(-12, -110, 24, 40))
	match style:
		"jumper":
			draw_rect(Rect2(-12, -74, 24, 4), body.darkened(0.15))
			if top.has("rarity"):
				draw_circle(Vector2(0, -92), 4.5, body.lightened(0.35), true, -1.0, true)
		"hoodie":
			draw_rect(Rect2(-8, -84, 16, 8), body.darkened(0.12))
			draw_line(Vector2(-3, -108), Vector2(-3, -98), UI.SURFACE, 1.5, true)
			draw_line(Vector2(3, -108), Vector2(3, -98), UI.SURFACE, 1.5, true)
		"tee":
			draw_arc(Vector2(0, -110), 5, 0, PI, 10, body.darkened(0.15), 2.0, true)
		"tree":
			_tree_costume(Vector2.ZERO, body)


## A Christmas tree costume: three tiers of branches over the body, hung
## with baubles.
func _tree_costume(at: Vector2, colour: Color) -> void:
	for k in 3:
		var top := -116.0 + 20.0 * k
		var half := 13.0 + 6.0 * k
		draw_colored_polygon(PackedVector2Array([at + Vector2(-half, top + 28), at + Vector2(0, top), at + Vector2(half, top + 28)]), colour.darkened(0.08 * (2 - k)))
	var baubles := [[Vector2(-6, -94), "#e8483c"], [Vector2(7, -82), "#f2c53d"], [Vector2(-10, -66), "#4a8fd9"], [Vector2(9, -60), "#e8483c"], [Vector2(0, -74), "#f2c53d"]]
	for b in baubles:
		draw_circle(at + b[0], 2.6, Color(b[1]), true, -1.0, true)


## Trousers laid flat: a waistband and two legs a little apart (shorts stop
## at the knee).
func _draw_trousers_flat(trousers: Dictionary) -> void:
	var colour := Content.cosmetic_colour(trousers, Color("#4b5a6e"))
	var hem := -32.0 if _style(trousers) == "shorts" else -2.0
	for side in [-1.0, 1.0]:
		var shade := colour.darkened(0.08) if side < 0 else colour
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -54), Vector2(12 * side, -56), Vector2(14 * side, hem), Vector2(3 * side, hem)]), shade)
	draw_rect(Rect2(-12, -60, 24, 6), colour.darkened(0.2))


## The body of the top they wear, with its trim.
func _draw_torso(top: Dictionary, sleeve: Color, bob: float) -> void:
	draw_rect(Rect2(-14, -108 - bob, 28, 56), sleeve)
	match _style(top):
		"jumper":
			draw_rect(Rect2(-14, -57 - bob, 28, 5), sleeve.darkened(0.15))
			if top.has("rarity"):
				draw_circle(Vector2(5, -86 - bob), 6, sleeve.lightened(0.35), true, -1.0, true)
		"hoodie":
			draw_rect(Rect2(-6, -72 - bob, 17, 9), sleeve.darkened(0.12))
			draw_line(Vector2(6, -104 - bob), Vector2(7, -92 - bob), UI.SURFACE, 1.5, true)
		"tee":
			draw_rect(Rect2(-14, -108 - bob, 28, 4), sleeve.darkened(0.1))
		"tree":
			_tree_costume(Vector2(0, -bob), sleeve)


## The walking stick, if they carry one, held in `hand`.
func _draw_stick(hand_at: Vector2) -> void:
	var stick := _item("walking_stick")
	if _style(stick) != "none":
		var colour := Content.cosmetic_colour(stick, STICK)
		draw_line(hand_at + Vector2(4, -10), Vector2(hand_at.x + 14, 0), STICK, 4, true)
		draw_circle(hand_at + Vector2(4, -11), 4.5, colour, true, -1.0, true)


func _draw_arm(from: Vector2, to: Vector2, sleeve: Color, skin: Color, short_sleeve: bool) -> void:
	if short_sleeve:
		var elbow := from.lerp(to, 0.45)
		draw_line(from, elbow, sleeve, 10, true)
		draw_line(elbow, to, skin, 8, true)
	else:
		draw_line(from, to, sleeve, 9, true)


func _draw_hand(at: Vector2, skin: Color, gloves: Dictionary, shade: float) -> void:
	match _style(gloves):
		"mittens":
			draw_circle(at, 6.5, Content.cosmetic_colour(gloves, UI.INK).darkened(shade), true, -1.0, true)
		"ring":
			draw_circle(at, 5, skin, true, -1.0, true)
			draw_arc(at + Vector2(1, 1), 3.2, 0, TAU, 12, Content.cosmetic_colour(gloves, UI.INK), 2.0, true)
		_:
			draw_circle(at, 5, skin, true, -1.0, true)


func _draw_shoe(foot: Vector2, shade: float) -> void:
	var shoes := _item("shoes")
	var colour := Content.cosmetic_colour(shoes, Color("#5a3b25")).darkened(shade)
	match _style(shoes):
		"trainers":
			_ellipse(foot + Vector2(4, -1), Vector2(9, 4.5), colour)
			draw_line(foot + Vector2(-4, 2), foot + Vector2(12, 2), colour.darkened(0.35), 2, true)
			draw_line(foot + Vector2(0, -2), foot + Vector2(7, -3), UI.ACCENT.darkened(shade), 2, true)
		"wellies":
			draw_rect(Rect2(foot.x - 6, foot.y - 16, 13, 16), colour)
			_ellipse(foot + Vector2(5, -2), Vector2(8, 4), colour)
		_:
			draw_rect(Rect2(foot.x - 6, foot.y - 9, 12, 9), colour)
			_ellipse(foot + Vector2(5, -3), Vector2(8, 4), colour)


func _draw_neckwear(bob: float) -> void:
	var neck := _item("neckwear")
	var colour := Content.cosmetic_colour(neck, Color("#d9a441"))
	var y := -106 - bob
	match _style(neck):
		"scarf":
			draw_line(Vector2(-13, y), Vector2(13, y), colour, 7, true)
			draw_line(Vector2(8, y + 2), Vector2(12, y + 20), colour.darkened(0.1), 6, true)
		"bowtie":
			draw_colored_polygon(PackedVector2Array([Vector2(12, y + 2), Vector2(4, y - 4), Vector2(4, y + 8)]), colour)
			draw_colored_polygon(PackedVector2Array([Vector2(12, y + 2), Vector2(20, y - 4), Vector2(20, y + 8)]), colour)
			draw_circle(Vector2(12, y + 2), 2.5, colour.darkened(0.2), true, -1.0, true)
		"necklace":
			draw_arc(Vector2(3, y - 3), 11, 0.35, PI - 0.35, 12, Color("#d8c27a"), 1.6, true)
			draw_circle(Vector2(5, y + 8), 3.5, colour, true, -1.0, true)
		"collar":
			draw_line(Vector2(-13, y + 1), Vector2(13, y + 1), colour, 5, true)
			draw_circle(Vector2(9, y + 6), 3, colour.lightened(0.3), true, -1.0, true)


func _draw_head(h: Vector2, skin: Color, hair_tone: Color) -> void:
	var colour := _hair_colour(hair_tone)
	_draw_hair(h, colour, true)
	draw_circle(h, 16, skin, true, -1.0, true)
	draw_circle(h + Vector2(-3, 2), 4, skin.darkened(0.08), true, -1.0, true)
	_draw_face(h)
	_draw_facial_hair(h, colour)
	_draw_hair(h, colour, false)
	_draw_hat(h)


## The hair's colour: the player's, or a hair gift's own.
func _hair_colour(hair_tone: Color) -> Color:
	var hair := _item("hair")
	return Content.cosmetic_colour(hair, hair_tone) if hair.has("rarity") else hair_tone


## The hairstyle: what hangs behind the head (`behind`) or sits on top.
## Bald draws nothing.
func _draw_hair(h: Vector2, colour: Color, behind: bool) -> void:
	var style := _style(_item("hair"))
	if behind:
		if style == "long":
			draw_rect(Rect2(h.x - 17, h.y - 6, 17, 30), colour)
		return
	match style:
		"none":
			pass
		"buzz":
			draw_arc(h, 15, PI * 1.02, TAU * 0.99, 16, colour, 4, true)
		"curly":
			for i in 8:
				var a := PI + PI * i / 7.0
				draw_circle(h + Vector2(cos(a), sin(a)) * 14.5, 6.5, colour, true, -1.0, true)
		"bun":
			draw_arc(h, 12, PI, TAU, 16, colour, 9, true)
			draw_circle(h + Vector2(-9, -17), 7, colour, true, -1.0, true)
		_:
			draw_arc(h, 12, PI, TAU, 16, colour, 9, true)
			draw_circle(h + Vector2(11, -9), 4.5, colour, true, -1.0, true)


## Stubble, a moustache or a beard on the face's lower half (it faces
## right), in the hair colour.
func _draw_facial_hair(h: Vector2, colour: Color) -> void:
	match _style(_item("facial_hair")):
		"stubble":
			var dot := Color(colour, 0.55)
			for i in 9:
				var a := 0.15 + 1.9 * i / 8.0
				for ring in [12.5, 14.5]:
					draw_circle(h + Vector2(cos(a), sin(a)) * ring, 0.8, dot, true, -1.0, true)
		"moustache":
			draw_line(h + Vector2(4, 4), h + Vector2(13, 3.5), colour, 3.0, true)
			draw_circle(h + Vector2(4, 4.5), 1.6, colour, true, -1.0, true)
		"short_beard":
			draw_arc(h, 14, 0.05, 2.3, 16, colour, 4.5, true)
			draw_line(h + Vector2(4, 4), h + Vector2(12, 3.5), colour, 2.6, true)
		"full_beard":
			var pts := PackedVector2Array()
			for i in 13:
				var a := -0.1 + 2.5 * i / 12.0
				pts.append(h + Vector2(cos(a), sin(a)) * (16.5 + 3.0 * sin(a)))
			for i in 13:
				var a := 2.4 - 2.5 * i / 12.0
				pts.append(h + Vector2(cos(a), sin(a)) * 9.0 + Vector2(1.5, 2.5))
			draw_colored_polygon(pts, colour)
			# The mouth shows through.
			draw_arc(h + Vector2(8, 7), 2.5, 0.2, PI - 0.6, 8, colour.darkened(0.45), 1.4, true)


func _draw_face(h: Vector2) -> void:
	var face := _item("face")
	var eye := h + Vector2(8, -2)
	draw_circle(eye, 2.2, UI.INK, true, -1.0, true)
	if sad > 0.5:
		# A sad brow, a frown and, glasses aside, nothing else.
		draw_line(eye + Vector2(-4, -3.5), eye + Vector2(3, -5.5), UI.INK, 1.4, true)
		draw_arc(h + Vector2(8, 10), 3.5, PI + 0.6, TAU - 0.2, 8, UI.INK, 1.6, true)
		if _style(face) == "glasses":
			draw_arc(eye, 5, 0, TAU, 16, UI.INK, 1.6, true)
			draw_line(eye + Vector2(-5, 0), h + Vector2(-4, 0), UI.INK, 1.4, true)
		return
	match _style(face):
		"grin":
			draw_arc(h + Vector2(8, 4), 5, 0.1, PI - 0.4, 10, UI.INK, 2.0, true)
		"glasses":
			draw_arc(eye, 5, 0, TAU, 16, UI.INK, 1.6, true)
			draw_line(eye + Vector2(-5, 0), h + Vector2(-4, 0), UI.INK, 1.4, true)
			draw_arc(h + Vector2(8, 6), 3.5, 0.2, PI - 0.6, 8, UI.INK, 1.6, true)
		"freckles":
			for p in [Vector2(11, 3), Vector2(13.5, 1), Vector2(9, 4.5)]:
				draw_circle(h + p, 0.9, Color("#a0643c"), true, -1.0, true)
			draw_arc(h + Vector2(8, 6), 3.5, 0.2, PI - 0.6, 8, UI.INK, 1.6, true)
		_:
			draw_arc(h + Vector2(8, 6), 3.5, 0.2, PI - 0.6, 8, UI.INK, 1.6, true)


func _draw_hat(h: Vector2) -> void:
	var hat := _item("hat")
	var c := Content.cosmetic_colour(hat, Color("#c2563f"))
	match _style(hat):
		"beanie", "feather_cap", "ears":
			_cap_dome(h, c)
			draw_rect(Rect2(h.x - 17, h.y - 7, 34, 5), c.darkened(0.15))
			if _style(hat) == "beanie":
				draw_circle(h + Vector2(0, -22), 4, c.lightened(0.25), true, -1.0, true)
			elif _style(hat) == "feather_cap":
				draw_line(h + Vector2(-8, -12), h + Vector2(-22, -32), Color("#f4efe2"), 3, true)
			else:
				draw_colored_polygon(PackedVector2Array([h + Vector2(-13, -12), h + Vector2(-10, -28), h + Vector2(-3, -16)]), c)
				draw_colored_polygon(PackedVector2Array([h + Vector2(3, -16), h + Vector2(10, -28), h + Vector2(13, -12)]), c)
		"cap":
			_cap_dome(h, c)
			draw_rect(Rect2(h.x + 4, h.y - 9, 20, 4), c.darkened(0.2))
		"crown":
			for i in 5:
				var a := PI * 1.1 + PI * 0.8 * i / 4.0
				var p := h + Vector2(cos(a), sin(a)) * 15.0
				draw_circle(p, 5, c, true, -1.0, true)
				draw_circle(p, 2, Color("#6b4a1e"), true, -1.0, true)
		"alpine":
			draw_colored_polygon(PackedVector2Array([h + Vector2(-14, -13), h + Vector2(-9, -29), h + Vector2(9, -29), h + Vector2(14, -13)]), c)
			draw_rect(Rect2(h.x - 20, h.y - 15, 40, 4), c.darkened(0.2))
			draw_line(h + Vector2(8, -18), h + Vector2(16, -36), Color("#3d6b45"), 3, true)
		"witch":
			draw_rect(Rect2(h.x - 22, h.y - 15, 44, 4), c.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([h + Vector2(-12, -14), h + Vector2(6, -48), h + Vector2(12, -14)]), c)
		"bunny_ears":
			_ellipse(h + Vector2(-6, -30), Vector2(4.5, 13), c, -0.15)
			_ellipse(h + Vector2(5, -31), Vector2(4.5, 13), c, 0.12)
			draw_arc(h, 15, PI * 1.1, TAU * 0.95, 16, c.darkened(0.2), 4, true)
		"nest":
			_ellipse(h + Vector2(0, -17), Vector2(17, 6), Color("#8a6a45"))
			draw_circle(h + Vector2(-4, -22), 3.5, Color("#cfe4ef"), true, -1.0, true)
			draw_circle(h + Vector2(4, -22), 3.5, Color("#cfe4ef"), true, -1.0, true)
			draw_line(h + Vector2(-16, -16), h + Vector2(16, -19), Color("#6b4f33"), 1.5, true)
		"pot":
			var pot := UI.box(c, Color.TRANSPARENT, 6)
			draw_style_box(pot, Rect2(h.x - 12, h.y - 36, 24, 22))
			draw_rect(Rect2(h.x - 14, h.y - 38, 28, 5), c.darkened(0.25))
			draw_circle(h + Vector2(8, -14), 3, c.lightened(0.2), true, -1.0, true)
		"tophat":
			draw_rect(Rect2(h.x - 20, h.y - 16, 40, 5), c)
			draw_rect(Rect2(h.x - 12, h.y - 34, 24, 18), c)
		"party":
			var tip := h + Vector2(3, -46)
			draw_colored_polygon(PackedVector2Array([h + Vector2(-12, -12), tip, h + Vector2(14, -12)]), c)
			for k in 2:
				var t := 0.35 + 0.3 * k
				draw_line(h + Vector2(-12, -12).lerp(tip - h, t), h + Vector2(14, -12).lerp(tip - h, t), c.lightened(0.45), 3.0, true)
			draw_circle(tip, 4.5, Color("#f2c53d"), true, -1.0, true)
		"antlers":
			draw_arc(h, 16, PI * 1.12, TAU * 0.94, 16, c.darkened(0.2), 3.0, true)
			for side in [-1.0, 1.0]:
				var base := h + Vector2(9 * side, -14)
				var top := base + Vector2(7 * side, -26)
				draw_line(base, top, c, 3.5, true)
				draw_line(base.lerp(top, 0.45), base.lerp(top, 0.45) + Vector2(9 * side, -6), c, 3.0, true)
				draw_line(base.lerp(top, 0.75), base.lerp(top, 0.75) + Vector2(-5 * side, -8), c, 2.5, true)
		"pumpkin":
			# The whole head inside a carved pumpkin.
			var at := h + Vector2(0, 2)
			_ellipse(at + Vector2(-9, 0), Vector2(14, 21), c.darkened(0.12))
			_ellipse(at + Vector2(9, 0), Vector2(14, 21), c.darkened(0.12))
			_ellipse(at, Vector2(15, 22), c)
			draw_line(at + Vector2(1, -21), at + Vector2(4, -29), Color("#5b7a34"), 4.0, true)
			var glow := Color("#ffd25e")
			draw_colored_polygon(PackedVector2Array([at + Vector2(-1, -9), at + Vector2(4, -14), at + Vector2(6, -7)]), glow)
			draw_colored_polygon(PackedVector2Array([at + Vector2(9, -9), at + Vector2(14, -14), at + Vector2(15, -6)]), glow)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-2, 5), at + Vector2(17, 4), at + Vector2(12, 11), at + Vector2(3, 11)]), glow)


func _cap_dome(h: Vector2, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(h + Vector2(0, -4) + Vector2(cos(a), sin(a)) * 17.0)
	draw_colored_polygon(pts, c)


func _ellipse(centre: Vector2, radius: Vector2, colour: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(angle))
	draw_colored_polygon(pts, colour)
