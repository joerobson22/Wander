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
## A helmet over the head: "diver" in the ocean, "astronaut" on the Moon
## (the place's "helmet" in biomes.json), or "" for none. It hides the hat.
var helmet := "":
	set(v):
		helmet = v
		queue_redraw()
		if _rig:
			_helmet_over_rig()
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
## Draws the helmet over the art rig, at its head.
var _helmet_node: Node2D
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
	if _helmet_node and _limbs.has("Head") and is_inside_tree():
		_helmet_node.position = global_transform.affine_inverse() * (_limbs["Head"]["node"] as Node2D).global_position


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


## An item's pattern over its colour ("stripes", "spots", "patches"), or "".
static func _pattern(item: Dictionary) -> String:
	return str(item.get("pattern", ""))


## A pattern laid over `area` of a garment in colour `base`.
func _draw_pattern(pattern: String, area: Rect2, base: Color) -> void:
	match pattern:
		"stripes":
			for k in 4:
				var y := area.position.y + area.size.y * (0.15 + 0.22 * k)
				draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y + 3), UI.INK, 2.5, true)
		"spots":
			for p in [Vector2(0.2, 0.15), Vector2(0.7, 0.3), Vector2(0.35, 0.55), Vector2(0.8, 0.75), Vector2(0.25, 0.85)]:
				draw_circle(area.position + area.size * p, 2.4, UI.INK.lightened(0.15), true, -1.0, true)
		"patches":
			for p in [Vector2(0.15, 0.1), Vector2(0.6, 0.18), Vector2(0.3, 0.45), Vector2(0.72, 0.55), Vector2(0.18, 0.78), Vector2(0.62, 0.85)]:
				draw_rect(Rect2(area.position + area.size * p, Vector2(6, 5)), base.darkened(0.35))


## The room `part` takes when drawn on its own, in this node's space, so a
## box can scale it to fit. The head is drawn with a hairstyle or a face.
static func part_rect(slot: String, item: Dictionary) -> Rect2:
	match slot:
		"hat":
			var tops := {"witch": 52, "party": 48, "bunny_ears": 44, "antlers": 42, "top_hat": 40, "tophat": 40, "pot": 38, "alpine": 36, "feather_cap": 32, "ears": 32, "crown": 28, "beanie": 28, "nest": 28, "bucket_hat": 28, "salmon_hat": 26}
			var top := float(tops.get(_style(item), 22))
			if _style(item) == "pumpkin":
				return Rect2(HEAD.x - 25, HEAD.y - 28, 50, 52)
			if _style(item) == "salmon_hat":
				return Rect2(HEAD.x - 32, HEAD.y - top, 57, top + 2)
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

	# Everything has a back and a front: what's behind goes on first (a
	# cape, a hood, the hair behind the head, a hat's far side, a scarf
	# round the back of the neck), then the body, then what's in front.
	if _style(top) == "cape" and not face_only:
		_draw_cape_back(top_colour, bob)
	if _style(top) == "hoodie":
		_draw_hood(head, top_colour)
	var hair_colour := _hair_colour(hair)
	_draw_hair(head, hair_colour, true)
	if helmet == "" or face_only:
		_draw_hat(head, true)
	_draw_neckwear(bob, true)

	var shoulder := Vector2(0, -100 - bob)
	var sleeve := top_colour if _style(top) != "cape" else top_colour.lightened(0.35)
	if face_only:
		draw_rect(Rect2(-17, -110, 36, 40), sleeve)
	else:
		_draw_body(skin, top, sleeve, shoulder, bob)
	if _style(top) == "cape" and not face_only:
		_draw_cape_front(top_colour, bob)

	_draw_neckwear(bob, false)
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
	_draw_cuff(shoulder, back_hand, top)
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
	# The picture sits on the chest, the front of the body, under the arm:
	# you only see it when the arm swings out of the way.
	if top.has("emblem"):
		_draw_emblem(str(top["emblem"]), Vector2(9, -84 - bob), 0.9, sleeve)

	# Front arm, holding the lead (or hanging down when there isn't one).
	hand = Vector2(22, -78 - bob) if holding_lead else shoulder + Vector2(3, 40).rotated(sin(_phase) * 0.35 if walking else 0.0)
	_draw_arm(shoulder, hand, sleeve, skin, tee)
	_draw_cuff(shoulder, hand, top)
	_draw_stick(hand)
	_draw_hand(hand, skin, gloves, 0.0)


## Only what's worn in `part`, standing still.
func _draw_part(skin: Color, hair: Color) -> void:
	var item := _item(part)
	match part:
		"hat":
			_draw_hat(HEAD, true)
			_draw_hat(HEAD, false)
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
			# On its own, only a scarf or collar shows its back: a bow tie's
			# band and a necklace's string would just float there.
			if _style(item) in ["scarf", "collar"]:
				_draw_neckwear(0.0, true)
			_draw_neckwear(0.0, false)
		"top":
			_draw_top_flat(item, skin)
		"gloves":
			_draw_hand(Vector2(-8, 0), skin.darkened(0.1), item, 0.1)
			_draw_hand(Vector2(8, 0), skin, item, 0.0, true)
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
	if style == "cape":
		if _pattern(top) == "spots":
			for p in [Vector2(-17, -78), Vector2(17, -74), Vector2(-14, -70), Vector2(15, -84)]:
				draw_circle(p, 2.0, UI.INK.lightened(0.15), true, -1.0, true)
	else:
		_draw_pattern(_pattern(top), Rect2(-12, -106, 24, 34), body)
	match style:
		"jumper":
			_draw_hem(Rect2(-12, -74, 24, 4), top, body)
			if top.has("rarity") and not top.has("emblem"):
				draw_circle(Vector2(0, -92), 4.5, body.lightened(0.35), true, -1.0, true)
		"hoodie":
			draw_rect(Rect2(-8, -84, 16, 8), body.darkened(0.12))
			draw_line(Vector2(-3, -108), Vector2(-3, -98), UI.SURFACE, 1.5, true)
			draw_line(Vector2(3, -108), Vector2(3, -98), UI.SURFACE, 1.5, true)
		"tee":
			draw_arc(Vector2(0, -110), 5, 0, PI, 10, body.darkened(0.15), 2.0, true)
		"tree":
			_tree_costume(Vector2.ZERO, body)
	if top.has("emblem"):
		_draw_emblem(str(top["emblem"]), Vector2(0, -91), 1.4, body)
	if top.has("trim"):
		# Cuffs in the trim colour at the end of each sleeve.
		for side in [-1.0, 1.0]:
			draw_line(Vector2(19 * side, -80), Vector2(23.5 * side, -77), Color(top["trim"]), 3.5, true)


## A jumper's hem: darker than the jumper, or in its `trim` colour with a
## white stripe above it.
func _draw_hem(r: Rect2, top: Dictionary, body: Color) -> void:
	if top.has("trim"):
		draw_rect(r, Color(top["trim"]))
		draw_rect(Rect2(r.position.x, r.position.y - 2.5, r.size.x, 1.8), Color.WHITE)
	else:
		draw_rect(r, body.darkened(0.15))


## A cuff in the trim colour where a sleeve meets the hand.
func _draw_cuff(from: Vector2, to: Vector2, top: Dictionary) -> void:
	if not top.has("trim"):
		return
	var dir := (to - from).normalized()
	var at := to - dir * 6.0
	draw_line(at - dir * 1.5, at + dir * 1.5, Color(top["trim"]), 9.5, true)
	draw_line(at - dir * 3.4, at - dir * 2.4, Color.WHITE, 9.5, true)


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
			_draw_hem(Rect2(-14, -57 - bob, 28, 5), top, sleeve)
			if top.has("rarity") and not top.has("emblem"):
				draw_circle(Vector2(5, -86 - bob), 6, sleeve.lightened(0.35), true, -1.0, true)
		"hoodie":
			draw_rect(Rect2(-6, -72 - bob, 17, 9), sleeve.darkened(0.12))
			draw_line(Vector2(6, -104 - bob), Vector2(7, -92 - bob), UI.SURFACE, 1.5, true)
		"tee":
			draw_rect(Rect2(-14, -108 - bob, 28, 4), sleeve.darkened(0.1))
		"tree":
			_tree_costume(Vector2(0, -bob), sleeve)
	if _style(top) != "cape":
		_draw_pattern(_pattern(top), Rect2(-14, -104 - bob, 28, 50), sleeve)


## The walking stick, if they carry one, held in `hand`.
func _draw_stick(hand_at: Vector2) -> void:
	var stick := _item("walking_stick")
	var colour := Content.cosmetic_colour(stick, STICK)
	var detail := str(stick.get("detail", ""))
	var accent := Color(str(stick.get("accent", "#d9a441")))
	match _style(stick):
		"none":
			pass
		"crook":
			# A shepherd's crook: tall, with a wide hook curling over the top.
			var top := hand_at + Vector2(1, -30)
			draw_line(top, Vector2(hand_at.x + 14, 0), colour.darkened(0.1), 4, true)
			draw_arc(top + Vector2(6, 0), 6, PI, TAU + 0.6, 12, colour, 4, true)
		"cane" when detail == "giraffe":
			_draw_giraffe_cane(hand_at, colour)
		"cane":
			# Hooked over at the top, the hook in its colour.
			draw_line(hand_at + Vector2(4, -6), Vector2(hand_at.x + 14, 0), colour.darkened(0.2), 4, true)
			draw_arc(hand_at + Vector2(-1, -6), 5, PI, TAU, 10, colour, 4, true)
		"staff":
			# Taller than you hold it, with a ball on top.
			var top := hand_at + Vector2(2, -26)
			var foot := Vector2(hand_at.x + 14, 0)
			draw_line(top, foot, STICK, 4, true)
			if detail == "vines":
				_vine(top + Vector2(0.4, 6), hand_at.lerp(foot, 0.8), accent)
			if detail == "gem":
				# A purple gem held in a setting of the staff's wood.
				draw_circle(top + Vector2(0, -2), 6.2, colour, true, -1.0, true)
				draw_colored_polygon(PackedVector2Array([top + Vector2(0, -9), top + Vector2(4.2, -3), top + Vector2(0, 3.2), top + Vector2(-4.2, -3)]), accent)
				draw_colored_polygon(PackedVector2Array([top + Vector2(0, -9), top + Vector2(-4.2, -3), top + Vector2(-1.2, -3.6)]), accent.lightened(0.45))
			else:
				draw_circle(hand_at + Vector2(2, -28), 6, colour, true, -1.0, true)
				draw_circle(hand_at + Vector2(0, -30), 2, colour.lightened(0.5), true, -1.0, true)
		"wand":
			# Short and held up, with a twinkle at the tip.
			var tip := hand_at + Vector2(16, -16)
			draw_line(hand_at, tip, STICK.darkened(0.2), 3, true)
			draw_circle(tip, 5, Color(colour, 0.3), true, -1.0, true)
			draw_circle(tip, 2.6, colour, true, -1.0, true)
		_ when detail == "bamboo":
			# Bamboo all the way: its green, with a joint every so often.
			var top := hand_at + Vector2(4, -12)
			var foot := Vector2(hand_at.x + 14, 0)
			draw_line(top, foot, colour, 4.6, true)
			var side := (foot - top).normalized().orthogonal()
			for t in [0.0, 0.22, 0.5, 0.78]:
				var at := top.lerp(foot, t)
				draw_line(at - side * 3.4, at + side * 3.4, colour.darkened(0.35), 1.5, true)
				draw_line(at - side * 2.6 + Vector2(0, 1.3), at + side * 2.6 + Vector2(0, 1.3), colour.lightened(0.25), 0.9, true)
		_:
			var top := hand_at + Vector2(4, -10)
			draw_line(top, Vector2(hand_at.x + 14, 0), STICK, 4, true)
			if detail == "bear":
				# A golden ring round the top, and a little bear sitting on it.
				var ring := top.lerp(Vector2(hand_at.x + 14, 0), 0.18)
				draw_line(ring + Vector2(-3.2, -0.4), ring + Vector2(3.2, 0.4), accent, 2.6, true)
				_draw_bear(top + Vector2(-0.4, -4), colour)
			else:
				draw_circle(hand_at + Vector2(4, -11), 4.5, colour, true, -1.0, true)


## A little brown bear sitting at `at`, its feet on the stick.
func _draw_bear(at: Vector2, colour: Color) -> void:
	_ellipse(at + Vector2(0, 0.5), Vector2(4.0, 3.2), colour.darkened(0.08))
	for side in [-1.0, 1.0]:
		draw_circle(at + Vector2(3.4 * side, -9.6), 1.9, colour.darkened(0.12), true, -1.0, true)
	draw_circle(at + Vector2(0, -6.6), 3.9, colour, true, -1.0, true)
	draw_circle(at + Vector2(0.6, -5.4), 1.8, colour.lightened(0.45), true, -1.0, true)
	draw_circle(at + Vector2(0.9, -5.9), 0.7, UI.INK, true, -1.0, true)
	for x in [-1.2, 2.2]:
		draw_circle(at + Vector2(x, -7.8), 0.6, UI.INK, true, -1.0, true)


## A giraffe-headed cane: a spotted shaft with the giraffe's head as its
## handle, looking back over its shoulder.
func _draw_giraffe_cane(hand_at: Vector2, colour: Color) -> void:
	var top := hand_at + Vector2(1, -8)
	var foot := Vector2(hand_at.x + 14, 0)
	draw_line(top, foot, colour, 4.2, true)
	var dir := (foot - top).normalized()
	var spot := colour.darkened(0.45)
	for t in [0.18, 0.38, 0.58, 0.78, 0.94]:
		draw_circle(top.lerp(foot, t) + dir.orthogonal() * (0.9 if int(t * 10) % 2 == 0 else -0.9), 1.0, spot, true, -1.0, true)
	var head := top + Vector2(-2.6, -5.2)
	draw_line(top, head, colour, 3.6, true)
	_ellipse(head + Vector2(-2.6, -0.8), Vector2(4.6, 2.6), colour, 0.35)
	_ellipse(head + Vector2(-5.6, 0.2), Vector2(1.9, 1.6), colour.lightened(0.2))
	draw_circle(head + Vector2(-0.6, -1.8), 0.7, UI.INK, true, -1.0, true)
	draw_circle(head + Vector2(-6.2, 0.4), 0.45, spot, true, -1.0, true)
	for dx in [1.2, 3.6]:
		draw_line(head + Vector2(dx - 1.6, -2.4), head + Vector2(dx - 1.6, -5.6), spot, 1.1, true)
		draw_circle(head + Vector2(dx - 1.6, -5.9), 0.9, spot, true, -1.0, true)
	draw_circle(head + Vector2(1.4, 0.2), 0.9, spot, true, -1.0, true)


func _draw_arm(from: Vector2, to: Vector2, sleeve: Color, skin: Color, short_sleeve: bool) -> void:
	if short_sleeve:
		var elbow := from.lerp(to, 0.45)
		draw_line(from, elbow, sleeve, 10, true)
		draw_line(elbow, to, skin, 8, true)
	else:
		draw_line(from, to, sleeve, 9, true)


## `palm` shows the palm side, for a pair of paws laid out on their own.
func _draw_hand(at: Vector2, skin: Color, gloves: Dictionary, shade: float, palm: bool = false) -> void:
	match _style(gloves):
		"mittens":
			var mitt := Content.cosmetic_colour(gloves, UI.INK).darkened(shade)
			draw_circle(at, 6.5, mitt, true, -1.0, true)
			match str(gloves.get("detail", "")):
				"claw":
					# A claw cut out of the mitten's tip.
					draw_colored_polygon(PackedVector2Array([at + Vector2(-0.8, -5.0), at + Vector2(3.4, -5.6), at + Vector2(6.2, -10.0), at + Vector2(1.6, -7.2)]), Color("#f3ead8"))
					_ellipse(at + Vector2(1.2, -4.4), Vector2(2.6, 1.3), mitt.darkened(0.55), -0.3)
				"spike":
					draw_colored_polygon(PackedVector2Array([at + Vector2(-2.4, -5.4), at + Vector2(2.4, -5.4), at + Vector2(0.4, -11.5)]), mitt.lightened(0.35))
					draw_line(at + Vector2(-2.4, -5.4), at + Vector2(2.4, -5.4), mitt.darkened(0.35), 1.2, true)
		"ring":
			# A gold band with its stone on top.
			draw_circle(at, 5, skin, true, -1.0, true)
			draw_arc(at + Vector2(1, 1), 3.2, 0, TAU, 12, Color("#d9a441"), 1.6, true)
			draw_circle(at + Vector2(1, -2.2), 1.8, Content.cosmetic_colour(gloves, UI.INK), true, -1.0, true)
		"paws":
			var fur := Content.cosmetic_colour(gloves, UI.INK).darkened(shade)
			draw_circle(at, 7.5, fur, true, -1.0, true)
			# The back of the paw is just fur; the palm has its toe beans.
			if str(gloves.get("detail", "")) == "plain_back" and not palm:
				return
			for k in 3:
				draw_circle(at + Vector2(-3 + 3 * k, -3.5 - (1.0 if k == 1 else 0.0)), 1.4, fur.lightened(0.35), true, -1.0, true)
			if _pattern(gloves) == "stripes":
				draw_arc(at + Vector2(0, -1), 6.2, PI * 0.15, PI * 0.45, 4, UI.INK, 1.4, true)
				draw_arc(at + Vector2(0, -1), 6.2, PI * 0.55, PI * 0.85, 4, UI.INK, 1.4, true)
		"falconry_glove":
			var leather := Content.cosmetic_colour(gloves, UI.INK).darkened(shade)
			draw_rect(Rect2(at.x - 6, at.y - 11, 12, 8), leather.darkened(0.15))
			draw_circle(at, 6.5, leather, true, -1.0, true)
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
			if _pattern(shoes) == "spots":
				for p in [Vector2(-2, -3), Vector2(4, -4), Vector2(9, -2)]:
					draw_circle(foot + p, 1.1, UI.INK.lightened(0.15), true, -1.0, true)
		"wellies":
			draw_rect(Rect2(foot.x - 6, foot.y - 16, 13, 16), colour)
			_ellipse(foot + Vector2(5, -2), Vector2(8, 4), colour)
		"flippers":
			_ellipse(foot + Vector2(10, -1), Vector2(16, 3.5), colour)
			draw_rect(Rect2(foot.x - 6, foot.y - 7, 11, 6), colour.darkened(0.15))
		"sandals":
			draw_rect(Rect2(foot.x - 6, foot.y - 2, 18, 3), colour)
			draw_line(foot + Vector2(-2, -1), foot + Vector2(4, -7), colour.darkened(0.2), 2, true)
			draw_line(foot + Vector2(4, -7), foot + Vector2(10, -1), colour.darkened(0.2), 2, true)
		"slippers":
			_ellipse(foot + Vector2(4, -4), Vector2(10, 5.5), colour)
			draw_circle(foot + Vector2(11, -8), 3, colour.lightened(0.35), true, -1.0, true)
		_:
			draw_rect(Rect2(foot.x - 6, foot.y - 9, 12, 9), colour)
			_ellipse(foot + Vector2(5, -3), Vector2(8, 4), colour)


## What's worn round the neck: `behind` is the part going round the back
## of the neck (under the body), else the front.
func _draw_neckwear(bob: float, behind: bool) -> void:
	var neck := _item("neckwear")
	var colour := Content.cosmetic_colour(neck, Color("#d9a441"))
	var y := -106 - bob
	var far := colour.darkened(0.3)
	match _style(neck):
		"scarf":
			if behind:
				# The wrap round the back of the neck, a little wider.
				draw_line(Vector2(-16, y - 1), Vector2(14, y - 1), far, 8, true)
				return
			draw_line(Vector2(-13, y), Vector2(14, y + 1), colour, 7, true)
			draw_line(Vector2(-13, y - 2), Vector2(14, y - 1), colour.lightened(0.15), 2, true)
			# The knot in front, and both tails hanging down.
			draw_circle(Vector2(10, y + 2), 4.5, colour.darkened(0.08), true, -1.0, true)
			draw_line(Vector2(10, y + 4), Vector2(15, y + 22), colour.darkened(0.12), 6, true)
			draw_line(Vector2(8, y + 4), Vector2(9, y + 20), colour, 6, true)
			for k in 3:
				draw_line(Vector2(6 + k * 1.6, y + 21), Vector2(6 + k * 1.6, y + 24), colour.darkened(0.2), 1.0, true)
			if _pattern(neck) == "stripes":
				for x in [-9.0, -3.0, 3.0]:
					draw_line(Vector2(x, y - 3), Vector2(x + 1, y + 3), UI.INK, 2.0, true)
				for t in [0.35, 0.7]:
					draw_line(Vector2(5.5, y + 4 + 16 * t), Vector2(11.5, y + 4 + 16 * t), UI.INK, 2.0, true)
		"bowtie":
			if behind:
				# The band round the back of the collar.
				draw_line(Vector2(-14, y - 1), Vector2(12, y), far, 3, true)
				return
			draw_colored_polygon(PackedVector2Array([Vector2(12, y + 2), Vector2(4, y - 4), Vector2(4, y + 8)]), colour.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([Vector2(12, y + 2), Vector2(20, y - 4), Vector2(20, y + 8)]), colour)
			draw_circle(Vector2(12, y + 2), 2.5, colour.darkened(0.25), true, -1.0, true)
		"necklace":
			if behind:
				# The string round the back of the neck.
				draw_arc(Vector2(-2, y - 1), 13, PI * 1.05, PI * 1.6, 10, Color("#a8925a"), 1.4, true)
				return
			draw_arc(Vector2(3, y - 3), 11, 0.35, PI - 0.35, 12, Color("#d8c27a"), 1.6, true)
			for k in 4:
				var a := 0.6 + k * 0.6
				draw_circle(Vector2(3, y - 3) + Vector2(cos(a), sin(a)) * 11.0, 1.4, colour.lightened(0.3), true, -1.0, true)
			draw_circle(Vector2(5, y + 8), 3.5, colour, true, -1.0, true)
			draw_circle(Vector2(4, y + 7), 1.1, colour.lightened(0.5), true, -1.0, true)
		"collar":
			if behind:
				draw_line(Vector2(-15, y - 1), Vector2(13, y - 1), far, 6, true)
				return
			draw_line(Vector2(-13, y + 1), Vector2(13, y + 1), colour, 5, true)
			for x in [-8.0, -2.0, 4.0]:
				draw_circle(Vector2(x, y + 1), 1.0, colour.lightened(0.45), true, -1.0, true)
			draw_circle(Vector2(9, y + 6), 3, colour.lightened(0.3), true, -1.0, true)
			draw_circle(Vector2(9, y + 6), 1.2, colour.darkened(0.2), true, -1.0, true)


## A cape: most of it hangs behind you, swaying as you walk.
func _draw_cape_back(colour: Color, bob: float) -> void:
	var sway := sin(_phase) * 3.0 if walking else 0.0
	var hem := PackedVector2Array()
	var pts := PackedVector2Array([Vector2(-8, -108 - bob), Vector2(8, -108 - bob)])
	for i in 7:
		var t := i / 6.0
		pts.append(Vector2(lerpf(6, -34 + sway, t), -40 - bob + sin(t * PI * 3.0) * 2.0 - t * 4.0))
	draw_colored_polygon(pts, colour.darkened(0.1))
	# Its lining shows along the inside edge.
	draw_line(Vector2(8, -108 - bob), Vector2(6, -40 - bob), colour.darkened(0.35), 3, true)
	if _pattern(_item("top")) == "spots":
		for p in [Vector2(-17, -70), Vector2(-21, -57), Vector2(-28, -48), Vector2(-17, -50)]:
			draw_circle(p + Vector2(sway * (-p.y - 40) / 68.0, -bob), 2.4, UI.INK.lightened(0.15), true, -1.0, true)
	hem.append(Vector2(-12, -100 - bob))
	hem.append(Vector2(-30 + sway, -46 - bob))
	draw_polyline(hem, colour.lightened(0.12), 2, true)


## The cape's front: over the shoulder to a clasp at the neck.
func _draw_cape_front(colour: Color, bob: float) -> void:
	var y := -107 - bob
	draw_colored_polygon(PackedVector2Array([Vector2(-15, y - 2), Vector2(6, y - 2), Vector2(4, y + 9), Vector2(-15, y + 13)]), colour)
	draw_line(Vector2(-15, y - 2), Vector2(6, y - 2), colour.lightened(0.2), 2, true)
	draw_circle(Vector2(8, y + 2), 3.2, Color("#e2c046"), true, -1.0, true)
	draw_circle(Vector2(7.4, y + 1.4), 1.0, Color(1, 1, 1, 0.7), true, -1.0, true)


## A hoodie's hood, down behind the head.
func _draw_hood(h: Vector2, colour: Color) -> void:
	_ellipse(h + Vector2(-11, 12), Vector2(10, 9), colour.darkened(0.18), -0.4)
	_ellipse(h + Vector2(-9, 13), Vector2(6, 5), colour.darkened(0.36), -0.4)


func _draw_head(h: Vector2, skin: Color, hair_tone: Color) -> void:
	var colour := _hair_colour(hair_tone)
	draw_circle(h, 16, skin, true, -1.0, true)
	draw_circle(h + Vector2(-3, 2), 4, skin.darkened(0.08), true, -1.0, true)
	_draw_face(h)
	_draw_facial_hair(h, colour)
	_draw_hair(h, colour, false)
	if helmet == "" or face_only or part != "":
		_draw_hat(h, false)
	else:
		draw_helmet(self, h + Vector2(1, -2), 25.0, helmet)


## A round glass helmet at `at`, `r` across, with a collar under it where
## it meets the neck: brass and bolted for diving ("diver"), white with a
## gold visor for space ("astronaut"). Animals wear the same.
static func draw_helmet(canvas: CanvasItem, at: Vector2, r: float, kind: String) -> void:
	var diver := kind == "diver"
	var metal := Color("#c9973a") if diver else Color("#eef1f5")
	var edge := metal.darkened(0.25)
	var collar := Rect2(at.x - r * 0.72, at.y + r * 0.7, r * 1.44, r * 0.34)
	canvas.draw_rect(collar, metal)
	canvas.draw_line(collar.position + Vector2(0, collar.size.y), collar.end, edge, 1.5, true)
	canvas.draw_circle(at, r, Color(0.78, 0.92, 1.0, 0.26), true, -1.0, true)
	if not diver:
		# The gold visor across the front.
		canvas.draw_arc(at, r * 0.72, -PI * 0.4, PI * 0.4, 16, Color("#e2b33c", 0.55), r * 0.5, true)
	canvas.draw_arc(at, r, 0, TAU, 40, metal, maxf(2.5, r * 0.14), true)
	canvas.draw_arc(at, r * 0.72, PI * 1.15, PI * 1.45, 10, Color(1, 1, 1, 0.7), maxf(1.5, r * 0.08), true)
	if diver:
		for k in 3:
			canvas.draw_circle(Vector2(collar.position.x + collar.size.x * (0.2 + 0.3 * k), collar.position.y + collar.size.y * 0.5), maxf(1.2, r * 0.06), edge, true, -1.0, true)
	else:
		canvas.draw_line(at + Vector2(-r * 0.5, -r * 0.86), at + Vector2(-r * 0.62, -r * 1.3), metal, 2.0, true)
		canvas.draw_circle(at + Vector2(-r * 0.62, -r * 1.32), maxf(2.0, r * 0.09), Color("#e8483c"), true, -1.0, true)


## With art, the helmet is drawn by a node of its own over the rig, kept at
## the head as it moves.
func _helmet_over_rig() -> void:
	if helmet == "" or face_only:
		if _helmet_node:
			_helmet_node.queue_free()
			_helmet_node = null
		return
	if _helmet_node == null:
		_helmet_node = Node2D.new()
		_helmet_node.draw.connect(func(): draw_helmet(_helmet_node, Vector2.ZERO, 25.0, helmet))
		add_child(_helmet_node)
	_helmet_node.queue_redraw()


## The hair's colour: the player's, or a hair gift's own.
func _hair_colour(hair_tone: Color) -> Color:
	var hair := _item("hair")
	return Content.cosmetic_colour(hair, hair_tone) if hair.has("rarity") else hair_tone


## The hairstyle in two parts: what's behind the head (`behind`: its
## volume round the back, long hair down the back) and what's on it (the
## scalp, with a hairline over the ear, and a fringe). Under a hat that
## covers the head, only what shows below the hat is drawn. Bald draws
## nothing.
func _draw_hair(h: Vector2, colour: Color, behind: bool) -> void:
	var style := _style(_item("hair"))
	if style == "none":
		return
	var covered := _hat_covers()
	var shade := colour.darkened(0.18)
	if behind:
		match style:
			"buzz":
				return
			"long":
				# Falls down the back to below the shoulders.
				var pts := _arc(h + Vector2(-1, -1), 18.0, PI * 0.55, PI * 1.75, 16)
				pts.append(h + Vector2(4, 0))
				pts.append(h + Vector2(-2, 30))
				pts.append(h + Vector2(-19, 28))
				draw_colored_polygon(pts, shade)
				draw_line(h + Vector2(-14, 6), h + Vector2(-15, 24), shade.darkened(0.15), 1.5, true)
				draw_line(h + Vector2(-8, 8), h + Vector2(-8, 26), shade.darkened(0.15), 1.5, true)
			"curly":
				for i in 9:
					var a := PI * 0.7 + PI * 1.05 * i / 8.0
					if covered and sin(a) < -0.35:
						continue
					draw_circle(h + Vector2(-1, -1) + Vector2(cos(a), sin(a)) * 16.0, 6.5, shade, true, -1.0, true)
			"bun":
				var pts := _arc(h + Vector2(-1, -1), 17.0, PI * 0.72, PI * 1.72, 14)
				pts.append(h)
				draw_colored_polygon(pts, shade)
				if not covered:
					draw_circle(h + Vector2(-13, -14), 8, shade, true, -1.0, true)
					draw_arc(h + Vector2(-13, -14), 5, PI * 0.9, PI * 1.8, 8, shade.darkened(0.2), 1.5, true)
			_:
				var pts := _arc(h + Vector2(-2.5, -1.5), 17.5, PI * 0.7, PI * 1.72, 14)
				pts.append(h)
				draw_colored_polygon(pts, shade)
		return
	# On the head: the scalp up to a hairline that runs from the temple,
	# over the ear and down behind it.
	var cap := _arc(h, 16.6, PI * 1.02, PI * 1.84, 16)
	var line := [Vector2(11, -9), Vector2(4, -10.5), Vector2(-3, -9), Vector2(-8.5, -5), Vector2(-10.5, 1), Vector2(-12, 8), Vector2(-16.3, 3)]
	if style == "buzz":
		cap = _arc(h, 16.2, PI * 1.02, PI * 1.84, 16)
		for p in line:
			cap.append(h + p * Vector2(1, 1.05))
		draw_colored_polygon(cap, Color(colour, 0.55))
		return
	for p in line:
		cap.append(h + p)
	draw_colored_polygon(cap, colour)
	if covered:
		# Just a little shows under the hat's edge.
		draw_colored_polygon(PackedVector2Array([h + Vector2(8, -8), h + Vector2(14, -7), h + Vector2(9, -3)]), colour)
		return
	match style:
		"curly":
			for i in 6:
				var a := PI * 1.05 + PI * 0.8 * i / 5.0
				draw_circle(h + Vector2(cos(a), sin(a)) * 14.5, 5.5, colour, true, -1.0, true)
				draw_arc(h + Vector2(cos(a), sin(a)) * 14.5, 3.0, a, a + PI, 6, shade, 1.2, true)
		"bun":
			# Pulled back smooth: a line or two towards the bun.
			draw_arc(h + Vector2(-2, 2), 13, PI * 1.25, PI * 1.6, 8, shade, 1.3, true)
			draw_arc(h + Vector2(-2, 4), 16, PI * 1.3, PI * 1.55, 8, shade, 1.3, true)
		"long":
			# A fringe swept forward, and a lock falling in front of the ear.
			draw_colored_polygon(PackedVector2Array([h + Vector2(2, -16), h + Vector2(17, -6), h + Vector2(12, -3), h + Vector2(4, -9)]), colour)
			draw_line(h + Vector2(-4, -13), h + Vector2(-13, 4), shade, 1.3, true)
		_:
			# A short fringe flicking forward over the forehead.
			draw_colored_polygon(PackedVector2Array([h + Vector2(4, -16), h + Vector2(16, -9), h + Vector2(15, -5), h + Vector2(6, -9)]), colour)
			draw_line(h + Vector2(-2, -14), h + Vector2(8, -12), shade, 1.4, true)


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


## True if the hat covers the top of the head, so hair only shows below
## it (hats that sit on top, like ears on a headband, don't).
func _hat_covers() -> bool:
	if helmet != "" and not face_only and part == "":
		return false
	return _style(_item("hat")) in ["beanie", "cap", "ears", "feather_cap", "top_hat", "tophat", "bucket_hat", "witch", "alpine", "pot", "salmon_hat", "pumpkin"]


## A hat in two parts: its far side (`behind`: the back of a brim, the far
## ear, a tail), drawn before the head, and the rest over it.
func _draw_hat(h: Vector2, behind: bool) -> void:
	var hat := _item("hat")
	var c := Content.cosmetic_colour(hat, Color("#c2563f"))
	var far := c.darkened(0.3)
	var style := _style(hat)
	match style:
		"beanie", "feather_cap", "ears":
			if behind:
				# The far edge of the turned-up cuff, round the back.
				draw_line(h + Vector2(-17, -3), h + Vector2(-8, -1), far, 5, true)
				if style == "ears":
					draw_colored_polygon(PackedVector2Array([h + Vector2(-9, -16), h + Vector2(-4, -31), h + Vector2(2, -18)]), far)
				return
			_cap_dome(h, c)
			draw_arc(h + Vector2(0, -4), 12, PI * 1.15, PI * 1.45, 8, c.lightened(0.18), 2.0, true)
			draw_rect(Rect2(h.x - 17, h.y - 8, 34, 6), c.darkened(0.15))
			for k in 5:
				draw_line(Vector2(h.x - 13 + k * 6.5, h.y - 7), Vector2(h.x - 13 + k * 6.5, h.y - 3), c.darkened(0.28), 1.0, true)
			if style == "beanie":
				draw_circle(h + Vector2(-2, -22), 4.5, c.lightened(0.25), true, -1.0, true)
				draw_circle(h + Vector2(-3.5, -23.5), 1.5, c.lightened(0.5), true, -1.0, true)
			elif style == "feather_cap":
				draw_line(h + Vector2(-8, -12), h + Vector2(-22, -32), Color("#f4efe2"), 3, true)
			else:
				# The near ear, with its pink inside.
				draw_colored_polygon(PackedVector2Array([h + Vector2(2, -18), h + Vector2(9, -32), h + Vector2(14, -14)]), c)
				draw_colored_polygon(PackedVector2Array([h + Vector2(5, -18), h + Vector2(9, -27), h + Vector2(11, -16)]), Color("#f2b5c4"))
		"cap":
			if behind:
				# The strap at the back.
				draw_line(h + Vector2(-16, -6), h + Vector2(-12, -2), far, 3, true)
				return
			_cap_dome(h, c)
			draw_line(h + Vector2(0, -21), h + Vector2(0, -6), c.darkened(0.12), 1.2, true)
			draw_circle(h + Vector2(0, -21), 1.8, c.darkened(0.15), true, -1.0, true)
			# The peak, curving out over the eyes.
			draw_colored_polygon(PackedVector2Array([h + Vector2(8, -9), h + Vector2(24, -7), h + Vector2(25, -4), h + Vector2(10, -4)]), c.darkened(0.2))
		"crown":
			var gems: bool = hat.get("gems", true)
			var band := h + Vector2(0, -14)
			if behind:
				# The far half of the ring, and its points.
				for i in 3:
					var x := -10.0 + 10.0 * i
					draw_colored_polygon(PackedVector2Array([band + Vector2(x - 4, -3), band + Vector2(x, -12), band + Vector2(x + 4, -3)]), far)
				draw_polyline(_ellipse_pts(band, Vector2(15, 4), PI, TAU, 10), far, 3.0, true)
				return
			for i in 4:
				var x := -13.0 + 8.7 * i
				draw_colored_polygon(PackedVector2Array([band + Vector2(x - 4, 1), band + Vector2(x, -9), band + Vector2(x + 4, 1)]), c)
				if gems:
					draw_circle(band + Vector2(x, -9), 1.8, c.lightened(0.4), true, -1.0, true)
			draw_polyline(_ellipse_pts(band, Vector2(15, 4), 0, PI, 10), c, 5.0, true)
			if gems:
				for k in 3:
					draw_circle(band + Vector2(-8 + 8 * k, 4.5 - absf(k - 1.0)), 1.8, [Color("#c0392b"), Color("#3a7bd5"), Color("#2e8b57")][k], true, -1.0, true)
			if str(hat.get("detail", "")) == "paw":
				# A raised plate on the front, with a darker paw print on it.
				draw_colored_polygon(PackedVector2Array([band + Vector2(-6.5, -6), band + Vector2(6.5, -6), band + Vector2(5.5, 6.5), band + Vector2(-5.5, 6.5)]), c.lightened(0.08))
				_draw_paw_print(band + Vector2(0, 1.2), 1.0, c.darkened(0.5))
		"top_hat", "tophat":
			var base := h + Vector2(0, -12)
			if behind:
				draw_colored_polygon(_ellipse_pts(base, Vector2(22, 5), PI, TAU, 14), far)
				return
			draw_rect(Rect2(base.x - 12, base.y - 26, 24, 26), c)
			draw_rect(Rect2(base.x + 4, base.y - 26, 8, 26), c.darkened(0.15))
			draw_rect(Rect2(base.x - 12, base.y - 7, 24, 5), Color("#b4533f"))
			_ellipse(base + Vector2(0, -26), Vector2(12, 2.5), c.lightened(0.12))
			draw_colored_polygon(_ellipse_pts(base, Vector2(22, 5), 0, PI, 14), c.darkened(0.1))
		"bucket_hat":
			var base := h + Vector2(0, -8)
			if behind:
				draw_colored_polygon(_ellipse_pts(base + Vector2(0, 1), Vector2(23, 6), PI, TAU, 14), far)
				return
			draw_colored_polygon(PackedVector2Array([base + Vector2(-14, 0), base + Vector2(-11, -15), base + Vector2(-4, -18), base + Vector2(6, -18), base + Vector2(12, -15), base + Vector2(15, 0)]), c)
			draw_rect(Rect2(base.x - 14, base.y - 5, 29, 4), c.darkened(0.18))
			# The brim droops a little all round.
			var brim := _ellipse_pts(base + Vector2(0, 1), Vector2(23, 6), 0, PI, 14)
			brim.append(base + Vector2(-23, 1))
			draw_colored_polygon(brim, c.darkened(0.08))
			draw_circle(base + Vector2(8, -12), 2, c.lightened(0.4), true, -1.0, true)
		"witch":
			var base := h + Vector2(0, -12)
			if behind:
				draw_colored_polygon(_ellipse_pts(base, Vector2(25, 5), PI, TAU, 14), far)
				return
			draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 1), base + Vector2(-4, -22), base + Vector2(6, -36), base + Vector2(14, -38), base + Vector2(8, -28), base + Vector2(12, 1)]), c)
			draw_rect(Rect2(base.x - 12, base.y - 5, 24, 5), Color("#7a4fa0"))
			draw_rect(Rect2(base.x - 2, base.y - 6, 6, 7), Color("#e2c046"))
			draw_colored_polygon(_ellipse_pts(base, Vector2(25, 5), 0, PI, 14), c.darkened(0.12))
		"alpine":
			if behind:
				draw_colored_polygon(_ellipse_pts(h + Vector2(0, -13), Vector2(20, 4), PI, TAU, 12), far)
				return
			draw_colored_polygon(PackedVector2Array([h + Vector2(-14, -13), h + Vector2(-9, -29), h + Vector2(9, -29), h + Vector2(14, -13)]), c)
			draw_colored_polygon(_ellipse_pts(h + Vector2(0, -13), Vector2(20, 4), 0, PI, 12), c.darkened(0.2))
			draw_line(h + Vector2(8, -18), h + Vector2(16, -36), Color("#3d6b45"), 3, true)
		"salmon_hat":
			# A big salmon lying over the head: its tail hangs down the back.
			var body := h + Vector2(-1, -15)
			if behind:
				draw_colored_polygon(PackedVector2Array([body + Vector2(-18, 2), body + Vector2(-30, -6), body + Vector2(-28, 12), body + Vector2(-18, 8)]), c.darkened(0.2))
				return
			_ellipse(body, Vector2(22, 9), c, -0.08)
			_ellipse(body + Vector2(0, 4), Vector2(20, 4), c.darkened(0.15), -0.08)
			for k in 3:
				draw_arc(body + Vector2(-8 + k * 7, 0), 5, -0.8, 0.8, 6, c.lightened(0.25), 1.2, true)
			draw_circle(body + Vector2(15, -2), 2.2, Color("#f4efe2"), true, -1.0, true)
			draw_circle(body + Vector2(15.6, -2), 1.1, UI.INK, true, -1.0, true)
			draw_line(body + Vector2(10, -6), body + Vector2(10, 4), c.darkened(0.25), 1.4, true)
			draw_rect(Rect2(h.x - 13, h.y - 9, 26, 3), Color("#5a7a8a"))
		"bunny_ears":
			if behind:
				# The far ear, a little behind and darker.
				_ellipse(h + Vector2(-7, -30), Vector2(4.5, 13), far, -0.25)
				return
			_ellipse(h + Vector2(4, -31), Vector2(4.5, 13), c, 0.12)
			_ellipse(h + Vector2(4.5, -30), Vector2(2.2, 9), Color("#f2b5c4"), 0.12)
			draw_arc(h, 16, PI * 1.1, TAU * 0.95, 16, c.darkened(0.2), 3.5, true)
		"nest":
			var base := h + Vector2(0, -16)
			if behind:
				# The back of the nest, and the eggs sitting in it.
				_ellipse(base + Vector2(0, -2), Vector2(17, 5), Color("#5e4630"))
				draw_circle(base + Vector2(-4, -6), 3.5, Color("#cfe4ef"), true, -1.0, true)
				draw_circle(base + Vector2(4, -6), 3.5, Color("#dbecf4"), true, -1.0, true)
				return
			draw_colored_polygon(_ellipse_pts(base, Vector2(18, 6), 0, PI, 12), Color("#8a6a45"))
			for k in 4:
				draw_line(base + Vector2(-16 + k * 8, 1 + (k % 2) * 2), base + Vector2(-8 + k * 8, 3 - (k % 2) * 2), Color("#b08a5e"), 1.4, true)
		"pot":
			if behind:
				return
			var pot := UI.box(c, Color.TRANSPARENT, 6)
			draw_style_box(pot, Rect2(h.x - 12, h.y - 36, 24, 22))
			draw_rect(Rect2(h.x - 14, h.y - 38, 28, 5), c.darkened(0.25))
			draw_circle(h + Vector2(8, -14), 3, c.lightened(0.2), true, -1.0, true)
		"party":
			if behind:
				# The elastic round the back of the head.
				draw_line(h + Vector2(-10, -12), h + Vector2(-14, 8), Color("#f4efe2", 0.8), 1.0, true)
				return
			var tip := h + Vector2(3, -46)
			draw_colored_polygon(PackedVector2Array([h + Vector2(-12, -12), tip, h + Vector2(14, -12)]), c)
			draw_colored_polygon(PackedVector2Array([h + Vector2(4, -12), tip, h + Vector2(14, -12)]), c.darkened(0.12))
			for k in 2:
				var t := 0.35 + 0.3 * k
				draw_line(h + Vector2(-12, -12).lerp(tip - h, t), h + Vector2(14, -12).lerp(tip - h, t), c.lightened(0.45), 3.0, true)
			draw_circle(tip, 4.5, Color("#f2c53d"), true, -1.0, true)
		"antlers":
			if behind:
				# The far antler, a shade darker behind the near one.
				_antler(h + Vector2(-6, -14), -1.0, far)
				return
			draw_arc(h, 16, PI * 1.12, TAU * 0.94, 16, c.darkened(0.2), 3.0, true)
			_antler(h + Vector2(7, -14), 1.0, c)
		"pumpkin":
			if behind:
				_ellipse(h + Vector2(-7, 2), Vector2(14, 21), c.darkened(0.3))
				return
			# The whole head inside a carved pumpkin.
			var at := h + Vector2(0, 2)
			_ellipse(at + Vector2(9, 0), Vector2(14, 21), c.darkened(0.12))
			_ellipse(at, Vector2(15, 22), c)
			draw_line(at + Vector2(1, -21), at + Vector2(4, -29), Color("#5b7a34"), 4.0, true)
			var glow := Color("#ffd25e")
			draw_colored_polygon(PackedVector2Array([at + Vector2(-1, -9), at + Vector2(4, -14), at + Vector2(6, -7)]), glow)
			draw_colored_polygon(PackedVector2Array([at + Vector2(9, -9), at + Vector2(14, -14), at + Vector2(15, -6)]), glow)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-2, 5), at + Vector2(17, 4), at + Vector2(12, 11), at + Vector2(3, 11)]), glow)


## One antler from `base`, curving up and out (`side` -1 back, 1 front).
func _antler(base: Vector2, side: float, c: Color) -> void:
	var top := base + Vector2(6 * side, -26)
	draw_line(base, top, c, 3.5, true)
	draw_line(base.lerp(top, 0.45), base.lerp(top, 0.45) + Vector2(9 * side, -6), c, 3.0, true)
	draw_line(base.lerp(top, 0.75), base.lerp(top, 0.75) + Vector2(-5 * side, -8), c, 2.5, true)


func _cap_dome(h: Vector2, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(h + Vector2(0, -4) + Vector2(cos(a), sin(a)) * 17.0)
	draw_colored_polygon(pts, c)


## Points round a circle from angle `a0` to `a1` (radians, clockwise on
## screen), `n` of them.
static func _arc(centre: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	return _ellipse_pts(centre, Vector2(r, r), a0, a1, n)


static func _ellipse_pts(centre: Vector2, radius: Vector2, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts


func _ellipse(centre: Vector2, radius: Vector2, colour: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(angle))
	draw_colored_polygon(pts, colour)


## A paw print: a pad with four toes above it, about 9 wide at `s` = 1.
func _draw_paw_print(c: Vector2, s: float, colour: Color) -> void:
	draw_circle(c + Vector2(0, 1.8) * s, 2.5 * s, colour, true, -1.0, true)
	for k in 4:
		draw_circle(c + Vector2(-3.3 + 2.2 * k, -2.0 - (1.0 if k in [1, 2] else 0.0)) * s, 1.1 * s, colour, true, -1.0, true)


## A pointed leaf of `length` and `width` along `angle`, centred on `c`.
func _leaf(c: Vector2, length: float, width: float, angle: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for side in [1.0, -1.0]:
		for i in 7:
			var t := i / 6.0 if side > 0.0 else 1.0 - i / 6.0
			pts.append(c + Vector2((t - 0.5) * length, side * sin(t * PI) * width * 0.5).rotated(angle))
	draw_colored_polygon(pts, colour)


## A vine winding down a stick from `a` to `b`, with a few leaves.
func _vine(a: Vector2, b: Vector2, colour: Color) -> void:
	var dir := (b - a).normalized()
	var side := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pts.append(a.lerp(b, t) + side * sin(t * TAU * 2.5) * 2.7)
	draw_polyline(pts, colour, 1.7, true)
	for k in 3:
		var t := 0.18 + 0.27 * k
		var at := a.lerp(b, t) + side * sin(t * TAU * 2.5) * 2.7
		_leaf(at + side * (3.0 if k % 2 == 0 else -3.0), 5.0, 2.8, side.angle() + (0.0 if k % 2 == 0 else PI), colour.lightened(0.15))


## A small picture on a top, about 12 wide at `s` = 1, on a body of `base`.
func _draw_emblem(kind: String, c: Vector2, s: float, base: Color) -> void:
	match kind:
		"leaf":
			var axis := Vector2.RIGHT.rotated(-PI / 4.0)
			draw_line(c - axis * 5.5 * s, c - axis * 8.0 * s, Color("#a8541c"), 1.2 * s, true)
			_leaf(c, 11.0 * s, 7.0 * s, -PI / 4.0, Color("#f0b73e"))
			draw_line(c - axis * 5.0 * s, c + axis * 4.0 * s, Color("#a8541c"), 1.0 * s, true)
		"tree":
			draw_line(c + Vector2(0, -1), c + Vector2(0, 6) * s, Color("#7a5236"), 2.4 * s, true)
			for p in [Vector2(-3.2, -1.2), Vector2(3.2, -1.2), Vector2(0, -4.2)]:
				draw_circle(c + p * s, 3.7 * s, Color("#b5d96a"), true, -1.0, true)
		"snowflake":
			for k in 6:
				var d := Vector2.RIGHT.rotated(k * PI / 3.0)
				draw_line(c, c + d * 6.0 * s, Color.WHITE, 1.2 * s, true)
				for e in [-0.7, 0.7]:
					draw_line(c + d * 3.6 * s, c + d * 3.6 * s + d.rotated(e) * 2.4 * s, Color.WHITE, 1.0 * s, true)
		"lilypad":
			_ellipse(c, Vector2(6.0, 4.4) * s, Color("#a9dc9a"))
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(7.5, -1.8) * s, c + Vector2(7.5, 2.2) * s]), base)
			draw_circle(c + Vector2(-1.2, -0.6) * s, 1.9 * s, Color("#f4a8c0"), true, -1.0, true)
			draw_circle(c + Vector2(-1.2, -0.6) * s, 0.8 * s, Color("#f6d860"), true, -1.0, true)
		"elephant":
			for side in [-1.0, 1.0]:
				draw_circle(c + Vector2(5.2 * side, -0.4) * s, 3.9 * s, base.darkened(0.25), true, -1.0, true)
			draw_circle(c, 4.8 * s, base.lightened(0.5), true, -1.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, 1.2) * s, c + Vector2(0.4, 4.6) * s, c + Vector2(-0.8, 6.4) * s]), base.lightened(0.2), 2.2 * s, true)
			for side in [-1.0, 1.0]:
				draw_circle(c + Vector2(2.0 * side, -1.2) * s, 0.8 * s, UI.INK, true, -1.0, true)
		"oasis":
			_ellipse(c + Vector2(0, 5.2) * s, Vector2(6.0, 1.9) * s, Color("#5ab0d8"))
			draw_polyline(PackedVector2Array([c + Vector2(-1.2, 5) * s, c + Vector2(0.2, -0.5) * s, c + Vector2(1.4, -3.6) * s]), Color("#8a5a3a"), 1.7 * s, true)
			for a in [-2.7, -2.0, -1.2, -0.45]:
				_leaf(c + Vector2(1.4, -3.6) * s + Vector2.RIGHT.rotated(a) * 3.4 * s, 7.0 * s, 2.8 * s, a, Color("#3f8f4f"))
		"feather_gold":
			_draw_feather(c, s, [Color("#f0c040")], Color("#b8861e"))
		"feather_colour":
			_draw_feather(c, s, [Color("#d9402c"), Color("#f2c230"), Color("#3a7bd5")], Color("#5a3b25"))
		"mountain":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 5) * s, c + Vector2(4.6, -2) * s, c + Vector2(8.8, 5) * s]), Color("#6a7a92"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-7.5, 5) * s, c + Vector2(-1.6, -5.6) * s, c + Vector2(4.4, 5) * s]), Color("#3f4a5a"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.6, -5.6) * s, c + Vector2(-4.0, -1.8) * s, c + Vector2(-2.6, -2.4) * s, c + Vector2(-1.4, -1.2) * s, c + Vector2(0.4, -2.4) * s, c + Vector2(0.9, -1.8) * s]), Color.WHITE)


## A feather, its barbs in `bands` (outermost first) and its shaft in `shaft`.
func _draw_feather(c: Vector2, s: float, bands: Array, shaft: Color) -> void:
	var angle := -PI / 4.0 - 0.15
	var axis := Vector2.RIGHT.rotated(angle)
	for i in bands.size():
		var f := 1.0 - i * 0.28
		_leaf(c + axis * (1.0 - f) * 4.5 * s, 14.0 * s * f, 6.0 * s * f, angle, bands[i])
	draw_line(c - axis * 8.5 * s, c + axis * 6.0 * s, shaft, 1.0 * s, true)
