class_name LevelBar
extends HBoxContainer
## Your level: a badge with the number on the left and a bar filling towards
## the next level. animate_to() fills it up from one XP total to another;
## each time the bar fills it pops, plays the level-up sound and starts again
## from empty with the badge one higher.

signal shown_changed(xp: int)
signal levelled_up(level: int)

var _badge: PanelContainer
var _number: Label
var _bar: Control
var _caption: Label
var _xp := 0.0
var _on_dark := false


## `on_dark` styles it for scenery (light text, see-through track).
func _init(xp: int, on_dark: bool = false, show_caption: bool = true) -> void:
	_on_dark = on_dark
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge = UI.level_badge(1, 40)
	_number = _badge.get_child(0)
	add_child(_badge)
	var right := UI.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	if show_caption:
		_caption = UI.label("", 12, UI.ON_DARK if on_dark else UI.INK_SOFT, false, 800)
		right.add_child(_caption)
	_bar = Control.new()
	_bar.custom_minimum_size.y = 12
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	right.add_child(_bar)
	_set_xp(xp)


func level() -> int:
	return Levels.level_for(int(_xp), Content.levels)


## The round badge with the level number, e.g. to make it tappable.
func badge() -> Control:
	return _badge


func _set_xp(v: float) -> void:
	var before := level()
	_xp = v
	var p := Levels.progress(int(v), Content.levels)
	_number.text = str(p["level"])
	if _caption:
		_caption.text = Text.t("level_bar.caption", {"level": p["level"], "xp": p["into"], "needed": p["needed"]})
	_bar.queue_redraw()
	if level() != before:
		levelled_up.emit(level())
	shown_changed.emit(int(v))


func _draw_bar() -> void:
	var p := Levels.progress(int(_xp), Content.levels)
	var part := float(p["into"]) / maxf(1.0, float(p["needed"]))
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_style_box(UI.box(Color(1, 1, 1, 0.22) if _on_dark else UI.LINE, Color.TRANSPARENT, 99), r)
	var w := r.size.x * clampf(part, 0.0, 1.0)
	if w > 0.5:
		_bar.draw_style_box(UI.box(UI.ACCENT.lightened(0.15) if _on_dark else UI.ACCENT, Color.TRANSPARENT, 99), Rect2(r.position, Vector2(maxf(w, r.size.y), r.size.y)))


## Fills the bar from the XP it shows now up to `to_xp`, level by level:
## at each full bar it pops, plays the level-up sound, and starts again.
func animate_to(to_xp: int) -> void:
	var table := Content.levels
	while int(_xp) < to_xp:
		var p := Levels.progress(int(_xp), table)
		var boundary := Levels.xp_to_reach(int(p["level"]) + 1, table)
		var target := mini(to_xp, boundary)
		var share := float(target - int(_xp)) / maxf(1.0, float(p["needed"]))
		var t := Motion.method(self, "fill", _set_xp, _xp, float(target), clampf(1.8 * share, 0.3, 1.8))
		await t.finished
		if target == boundary:
			Audio.play("level_up", 1.0, -4.0, "levelup")
			Motion.pop(_bar, 0.12, 0.4)
			Motion.pop(_badge, 0.35, 0.5)
			await get_tree().create_timer(Motion.time(0.45)).timeout
