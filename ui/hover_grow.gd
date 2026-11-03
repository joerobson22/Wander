class_name HoverGrow
extends RefCounted
## Every button (and everything else you can tap) grows by a tenth from its
## centre while the pointer is over it (wide ones by at most MOST a side),
## and settles back as it leaves, both in a tenth of a second. Buttons get it without each screen wiring it up
## (App watches for them); Press.attach() gives it to tappable cards too.
## A control with its own hover animation sets the "no_grow" meta first.
## Pills with words in (dropdowns, chips, the project pill) never grow: they
## sit in rows and scroll strips that would cut a grown pill off, so they
## only shade under the pointer (their hover style).

const GROW := 1.1
const TIME := 0.1
## Wide things (a full-width button) grow at most this far past each side,
## so they stay inside the room scroll areas leave (Modal.GROW_ROOM).
const MOST := 11.0


## Gives `control` the hover grow, once, unless it opted out with "no_grow".
## Checked a frame later, so a meta set straight after creating it counts.
static func attach(control: Control) -> void:
	if control.has_meta("_hover_grow"):
		return
	control.set_meta("_hover_grow", true)
	_wire.call_deferred(control)


static func _wire(target) -> void:
	# (Gone already, if it was built and thrown away in the same frame.)
	if not is_instance_valid(target):
		return
	var control := target as Control
	if control.has_meta("no_grow") or is_pill(control):
		return
	control.resized.connect(func(): control.pivot_offset = control.size * 0.5)
	control.pivot_offset = control.size * 0.5
	control.mouse_entered.connect(func(): _to(control, GROW))
	control.mouse_exited.connect(func(): _to(control, 1.0))
	if control is BaseButton:
		# A button switched off mid-hover settles back.
		control.draw.connect(func():
			if (control as BaseButton).disabled and control.scale != Vector2.ONE:
				_to(control, 1.0))


## A button with words in and fully round ends.
static func is_pill(control: Control) -> bool:
	var b := control as Button
	if b == null or b.text == "":
		return false
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	return sb != null and sb.corner_radius_top_left >= 99 and sb.corner_radius_bottom_right >= 99


static func _to(control: Control, s: float) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	if s > 1.0 and control is BaseButton and (control as BaseButton).disabled:
		return
	# A finger doesn't hover: nothing grows in the debug phone view.
	var app := control.get_tree().root.get_node_or_null("App")
	if s > 1.0 and app and app.state and app.touch_screen():
		return
	control.pivot_offset = control.size * 0.5
	if s > 1.0:
		s = minf(s, 1.0 + 2.0 * MOST / maxf(1.0, maxf(control.size.x, control.size.y)))
	var t := Motion.tween(control, "hover_grow")
	t.tween_property(control, "scale", Vector2.ONE * s, Motion.time(TIME))
