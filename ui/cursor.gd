class_name Cursor
extends Node
## The pointer over anything you can tap is a hand ready to grab. Every
## button gets it as it's made; other tappable things (the orb, gift tiles,
## the map) ask for it with HOVER, and Press gives it to whatever it makes
## tappable. Buttons never take focus, so nothing keeps a ring or a shade
## after it's tapped. The app shell adds one of these.

const HOVER := Control.CURSOR_CAN_DROP


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		_on_added(n)


static func _on_added(n: Node) -> void:
	if n is BaseButton:
		# Buttons never take focus: a tap leaves no ring and no shade behind.
		n.set_deferred("focus_mode", Control.FOCUS_NONE)
		if (n as Control).mouse_default_cursor_shape == Control.CURSOR_ARROW:
			# Deferred: a node can be added while its parent is still being set up.
			n.set_deferred("mouse_default_cursor_shape", HOVER)


## A finger lifting off a touch screen leaves the pretend mouse where it
## was, so whatever it tapped would stay shaded as if hovered. Moving the
## pretend mouse off the screen once the tap is done clears that.
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and not e.pressed and e.device != InputEvent.DEVICE_ID_EMULATION:
		_lift_pointer.call_deferred()


func _lift_pointer() -> void:
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-10000, -10000)
	away.global_position = away.position
	Input.parse_input_event(away)
