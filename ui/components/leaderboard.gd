class_name Leaderboard
extends PanelContainer
## The friends leaderboard: a card with a trophy and "Friends leaderboard"
## across the top, "See full" on the right, and everyone's week under it,
## most focus first. The heading stays put while the rows scroll. "See full"
## opens the whole list in a popup. When you're further down than the card
## shows, your row takes its last spot, so you can always see where you
## are. It only ever shows whole rows. Tapping a friend's face or name
## opens their profile; tapping yours goes to your profile screen. With
## no friends it's empty under the heading but for "No friends yet!".

## A row and the line under it.
const ROW_PITCH := 57.0

var rows: Array
var _holder: Control
var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _pinned: Control
var _mine: Control


## `list` is rows from Friends.ranked() (empty with no friends).
func _init(list: Array) -> void:
	rows = list
	var b := UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 24))
	b.content_margin_left = 20
	b.content_margin_right = 20
	b.content_margin_top = 16
	b.content_margin_bottom = 8
	add_theme_stylebox_override("panel", b)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UI.vbox(6)
	add_child(column)

	var head := UI.hbox(10)
	head.custom_minimum_size.y = 34
	var trophy := UI.icon_rect("trophy", 22, UI.ACCENT)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(trophy)
	var title := UI.trimmed(Text.t("leaderboard.title"), 20, UI.INK, true, 600)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	if list.size() > 1:
		var full := UI.button(Text.t("leaderboard.see_full"), open_full.bind(list), "quiet")
		full.custom_minimum_size = Vector2(0, 32)
		full.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		full.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = full.get_theme_stylebox(state)
			UI.corners(sb, 999)
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
		head.add_child(full)
	column.add_child(head)

	# The list and your pinned row are placed by hand in here (see _fit), so
	# their heights never push the card taller.
	_holder = Control.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.custom_minimum_size.y = ROW_PITCH
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_holder)
	_scroll = UI.scroll_area()
	_holder.add_child(_scroll)
	_list_box = _list(list)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if list.is_empty():
		var none := UI.label(Text.t("leaderboard.empty"), 16, UI.INK_FAINT, false, 700)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_holder.add_child(none)
	var room := MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.add_child(_list_box)
	_scroll.add_child(room)
	UI.clear_of_bar(_scroll, room)

	# Your row again, for when yours is out of sight below.
	var at := list.find_custom(func(r): return r.get("me", false))
	if at >= 0:
		_mine = _list_box.get_child(at * 2)
		_pinned = UI.vbox(0)
		_pinned.add_child(UI.divider())
		_pinned.add_child(row(at + 1, list[at]))
		_pinned.visible = false
		_holder.add_child(_pinned)
	_holder.resized.connect(_fit)
	# Your row's place is only known once the list is laid out.
	_list_box.resized.connect(_fit, CONNECT_DEFERRED)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _fit())


## Sizes the list to as many whole rows as fit, so none is cut in half, and
## pins your row at the bottom while yours is further down than that.
func _fit() -> void:
	var room := _holder.size
	var pin_height := _pinned.get_combined_minimum_size().y if _pinned else 0.0
	var pin: bool = _pinned != null and _mine.position.y + _mine.size.y - _scroll.scroll_vertical > _whole_rows(room.y) + 1.0
	var list_height := _whole_rows(room.y - pin_height if pin else room.y)
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(room.x, list_height)
	if _pinned:
		_pinned.visible = pin
		_pinned.position = Vector2(0, list_height)
		# As wide as the list, so its time lines up with theirs by the scrollbar.
		_pinned.size = Vector2(_list_box.size.x if _list_box.size.x > 0.0 else room.x, pin_height)


## The height of as many whole rows as fit in `room` (all of them when they do).
func _whole_rows(room: float) -> float:
	var all := _list_box.get_combined_minimum_size().y
	if all <= room:
		return all
	return maxf(0.0, floorf((room + 1.0) / ROW_PITCH) * ROW_PITCH - 1.0)


## Everyone in a popup titled "Friend leaderboard". The title stays at the
## top while the list scrolls.
static func open_full(list: Array) -> void:
	var m := Modal.open(480)
	m.header.add_child(m.heading_row(Text.t("leaderboard.full_title")))
	var room := MarginContainer.new()
	room.add_child(_list(list))
	m.body.add_child(room)
	UI.clear_of_bar(m.scroller(), room)


## The rows, a line between each.
static func _list(list: Array) -> VBoxContainer:
	var box := UI.vbox(0)
	for i in list.size():
		if i > 0:
			box.add_child(UI.divider())
		box.add_child(row(i + 1, list[i]))
	return box


## One person: their place, their face and name (tap either for their
## profile), and their week, or paw prints while they're out on a walk.
static func row(rank: int, f: Dictionary) -> Control:
	var me: bool = f.get("me", false)
	var line := UI.hbox(12)
	line.custom_minimum_size.y = 56
	var r := UI.label(str(rank), 15, UI.INK_FAINT, true, 600)
	r.custom_minimum_size.x = 18
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(r)

	var who := UI.hbox(12)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_STOP
	who.accessibility_name = Text.t("leaderboard.your_profile") if me else Text.t("leaderboard.their_profile", {"name": f.get("name", "")})
	var face := UI.character_portrait(f.get("look", {}), Vector2(40, 40), true)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(face)
	var name_label := UI.trimmed(str(f.get("name", "")), 16, UI.INK, false, 800 if me else 700)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.add_child(name_label)
	UI.ignore_mouse(face)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The name turns green under the pointer, to show it can be tapped.
	who.mouse_entered.connect(func(): name_label.add_theme_color_override("font_color", UI.ACCENT))
	who.mouse_exited.connect(func(): name_label.add_theme_color_override("font_color", UI.INK))
	Press.attach(who).tapped.connect(FriendProfile.open.bind(f))
	line.add_child(who)

	if f.get("walking", false):
		var walking := WalkingIndicator.new()
		walking.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(walking)
	else:
		var t := UI.label(Stats.format_duration(int(f.get("weekly_seconds", 0))), 16, UI.INK, true, 600)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(t)
	return line
