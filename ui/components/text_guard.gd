class_name TextGuard
extends RefCounted
## Keeps symbols out of a text box: only letters and numbers go in (and
## spaces, where a name can have them: a project, a pet, where you study;
## never in a username). Anything else typed or pasted is taken straight
## back out, and a short red line fades in under the box with a wiggle,
## saying what it takes. It stays till the next clean change.
## Text put in a box by the app itself is left as it is.

## Letters and numbers in any language, plus spaces when allowed.
static var _plain := RegEx.create_from_string("[^\\p{L}\\p{N}]")
static var _spaced := RegEx.create_from_string("[^\\p{L}\\p{N} ]")


## `text` with everything not allowed taken out.
static func clean(text: String, spaces: bool = true) -> String:
	var out := (_spaced if spaces else _plain).sub(text, "", true)
	# No run of spaces, and none at the start.
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.lstrip(" ")


## Guards `edit`. The warning goes under it, in its parent (a column).
static func attach(edit: LineEdit, spaces: bool = true) -> void:
	var warn := UI.label(Text.t("input.symbols_spaces" if spaces else "input.symbols"), 13, UI.DANGER, false, 800)
	# Only as wide as its words, so its wiggle stays small, and lined up with
	# the box's text.
	warn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if edit.alignment == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_SHRINK_BEGIN
	warn.visible = false
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit.set_meta("text_guard", warn)
	var place := func():
		if warn.get_parent() == null and edit.get_parent() is Container:
			edit.get_parent().add_child(warn)
			edit.get_parent().move_child(warn, edit.get_index() + 1)
	if edit.get_parent():
		place.call()
	else:
		edit.tree_entered.connect(place, CONNECT_ONE_SHOT)
	# (Never put in a column: it goes with the box.)
	edit.tree_exited.connect(func():
		if is_instance_valid(warn) and warn.get_parent() == null:
			warn.free())
	var fixing := [false]
	edit.text_changed.connect(func(text: String):
		if fixing[0]:
			return
		var fixed := clean(text, spaces)
		if fixed == text:
			_hide(warn)
			return
		var caret := edit.caret_column - (text.length() - fixed.length())
		edit.text = fixed
		edit.caret_column = clampi(caret, 0, fixed.length())
		# (Setting the text doesn't say it changed: tell whoever listens,
		# after this, with the clean text.)
		fixing[0] = true
		edit.text_changed.emit(fixed)
		fixing[0] = false
		_show(warn))


## Fades in and wiggles a warning label of your own (for boxes TextGuard
## doesn't guard itself, like the birthday's numbers).
static func flag(label: Label) -> void:
	_show(label)


## Puts a warning shown with `flag` away.
static func unflag(label: Label) -> void:
	_hide(label)


static func _show(warn: Label) -> void:
	if not is_instance_valid(warn) or not warn.is_inside_tree():
		return
	if not warn.visible:
		warn.visible = true
		warn.modulate.a = 0.0
	Motion.fade(warn, 1.0, Motion.FAST)
	Motion.wiggle(warn)


static func _hide(warn: Label) -> void:
	if is_instance_valid(warn) and warn.visible:
		Motion.fade(warn, 0.0, Motion.FAST).tween_callback(func(): warn.visible = false)
