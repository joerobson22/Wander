class_name Motion
extends RefCounted
## Every animation in the app goes through here, so everything moves the same
## way: a tween that eases in and out. Its curve, overall speed and the
## timings of the bigger moments are in ui/motion.tres, to change in the
## Godot editor (see MotionStyle); change them there and the whole app follows.

## How the app moves (ui/motion.tres).
static var style: MotionStyle = _load_style()


static func _load_style() -> MotionStyle:
	const PATH := "res://ui/motion.tres"
	var s := load(PATH) as MotionStyle if ResourceLoader.exists(PATH) else null
	return s if s else MotionStyle.new()

## Durations in seconds.
const FAST := 0.18
const NORMAL := 0.34
const SLOW := 0.6


## While true, animations jump straight to where they end: the screen is
## being rebuilt in new colours and should look exactly as it did.
static var still := false


## True when the player asked for less motion: animations run quicker and
## skip their bounces.
static func reduced() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var app: Node = tree.root.get_node_or_null("App") if tree and tree.root else null
	return app != null and app.state != null and bool(app.state.settings.get("reduce_motion", false))


## How long an animation of `seconds` should really take.
static func time(seconds: float) -> float:
	if still:
		return 0.0
	return seconds * (0.5 if reduced() else 1.0) / maxf(style.speed, 0.05)


## A tween bound to `node` with the app's curve. Starting another with the
## same `key` on the same node stops the old one, so animations never fight.
static func tween(node: Node, key: String = "") -> Tween:
	var meta := ""
	if key != "":
		meta = "_motion_" + key.replace(":", "_").replace("/", "_")
		if node.has_meta(meta):
			var old = node.get_meta(meta)
			if old is Tween and old.is_valid():
				old.kill()
	var t := node.create_tween().set_trans(style.transition).set_ease(style.easing)
	if meta != "":
		node.set_meta(meta, t)
	return t


## Animates one property of `node` to `value`.
static func to(node: Node, property: String, value: Variant, seconds: float = NORMAL) -> Tween:
	var t := tween(node, property)
	t.tween_property(node, property, value, time(seconds))
	return t


## Animates a value through `setter` (a Callable taking one argument).
static func method(node: Node, key: String, setter: Callable, from: Variant, value: Variant, seconds: float = NORMAL) -> Tween:
	var t := tween(node, key)
	t.tween_method(setter, from, value, time(seconds))
	return t


static func fade(item: CanvasItem, alpha: float, seconds: float = NORMAL) -> Tween:
	return to(item, "modulate:a", alpha, seconds)


## Fades and slides a control in from `offset` below where it sits.
static func enter(control: Control, delay: float = 0.0, offset: float = 16.0, seconds: float = NORMAL) -> Tween:
	var rest := control.position
	control.modulate.a = 0.0
	control.position = rest + Vector2(0, offset)
	var t := tween(control, "enter")
	t.set_parallel(true)
	t.tween_property(control, "modulate:a", 1.0, time(seconds)).set_delay(time(delay))
	t.tween_property(control, "position", rest, time(seconds)).set_delay(time(delay))
	return t


## A quick swell and settle, for something that just changed state.
static func pop(item: CanvasItem, amount: float = 0.18, seconds: float = 0.38) -> Tween:
	if item is Control:
		(item as Control).pivot_offset = (item as Control).size * 0.5
	var rest: Vector2 = item.get("scale")
	var t := tween(item, "scale")
	if reduced() or still:
		t.tween_property(item, "scale", rest, 0.01)
		return t
	t.tween_property(item, "scale", rest * (1.0 + amount), seconds * 0.45)
	t.tween_property(item, "scale", rest, seconds * 0.55)
	return t


## A side-to-side shake, for "not yet" (e.g. a name that's still empty).
static func shake(control: Control, distance: float = 10.0) -> Tween:
	var rest := control.position
	var t := tween(control, "shake")
	for i in 4:
		var dx := distance * (1.0 - i * 0.22) * (1.0 if i % 2 == 0 else -1.0)
		t.tween_property(control, "position", rest + Vector2(dx, 0), 0.06)
	t.tween_property(control, "position", rest, 0.06)
	return t


## A quick rock from side to side about its centre, for "that's locked" or
## "not yet" on things that sit in a layout (which a shake would fight).
static func wiggle(control: Control) -> Tween:
	control.pivot_offset = control.size * 0.5
	var t := tween(control, "wiggle")
	if reduced() or still:
		t.tween_property(control, "rotation", 0.0, 0.01)
		return t
	for i in 4:
		var a := deg_to_rad(7.0 * (1.0 - i * 0.22) * (1.0 if i % 2 == 0 else -1.0))
		t.tween_property(control, "rotation", a, 0.06)
	t.tween_property(control, "rotation", 0.0, 0.06)
	return t


## Types `text` into `label` letter by letter, pausing a moment between
## words (Motion.style.type_letter and type_space), after any words already
## there fade. Less motion: it's just there. Returns the tween (null when
## it isn't typed). With `appear` false the label's fade is left to the
## caller (it's fading in some other way).
static func type_out(label: Label, text: String, appear: bool = true) -> Tween:
	if reduced() or still:
		tween(label, "type").kill()
		label.text = text
		label.visible_characters = -1
		if appear:
			label.modulate.a = 1.0
		return null
	# Laid out as the whole text from the start, so centred words don't
	# shuffle along as each letter arrives.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	var t := tween(label, "type")
	if appear and label.modulate.a > 0.0 and label.visible_characters != 0 and label.text != "":
		t.tween_property(label, "modulate:a", 0.0, time(NORMAL))
	t.tween_callback(func():
		label.text = text
		label.visible_characters = 0
		if appear:
			label.modulate.a = 1.0)
	for i in text.length():
		t.tween_interval(time(style.type_letter + (style.type_space if text[i] == " " else 0.0)))
		t.tween_callback(func(): label.visible_characters = i + 1)
	t.tween_callback(func(): label.visible_characters = -1)
	return t


## Repeats a gentle up-and-down drift until the node leaves the tree.
static func float_loop(item: CanvasItem, height: float = 6.0, seconds: float = 1.6) -> Tween:
	var rest: Vector2 = item.get("position")
	var t := tween(item, "float")
	t.set_loops()
	t.tween_property(item, "position", rest - Vector2(0, height), seconds * 0.5)
	t.tween_property(item, "position", rest, seconds * 0.5)
	return t
