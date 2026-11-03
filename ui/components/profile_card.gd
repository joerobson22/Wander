class_name ProfileCard
extends RefCounted
## The pieces of a profile card, shared by your profile screen and a
## friend's profile popup so the two look alike: labelled details down the
## right, and the gift shelf along the bottom.


## A labelled detail; tappable to edit when `on_tap` is given (with a
## pencil on the right).
static func field(title: String, value: String, placeholder: bool = false, on_tap: Callable = Callable()) -> Control:
	var row := UI.hbox(8)
	row.custom_minimum_size.y = 38
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap := UI.caption(title)
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.clip_text = true
	text.add_child(cap)
	text.add_child(UI.trimmed(value, 15, UI.INK_FAINT if placeholder else UI.INK, false, 800))
	row.add_child(text)
	if on_tap.is_valid():
		var b := UI.round_button("edit", Text.t("profile.edit_field", {"field": title.to_lower()}), on_tap, UI.SURFACE_SOFT, UI.INK, 28, false)
		row.add_child(b)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		# A whole row of details stays still under the pointer; only its
		# pencil grows.
		row.set_meta("no_grow", true)
		Press.attach(row).tapped.connect(on_tap)
	return row


## Fields stacked with a line between each.
static func details(fields: Array) -> Control:
	var info := UI.vbox(0)
	for i in fields.size():
		if i > 0:
			info.add_child(UI.divider())
		info.add_child(fields[i])
	return info


## The "Gift shelf" caption over `shelf`, with a pencil on the right when
## `on_edit` is given.
static func shelf(gift_shelf: GiftShelf, on_edit: Callable = Callable()) -> Control:
	var v := UI.vbox(2)
	var head := UI.hbox(8)
	head.custom_minimum_size.y = 28
	var cap := UI.caption(Text.t("shelf.heading"))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cap)
	if on_edit.is_valid():
		head.add_child(UI.round_button("edit", Text.t("shelf.arrange"), on_edit, UI.SURFACE_SOFT, UI.INK, 28, false))
	v.add_child(head)
	v.add_child(gift_shelf)
	return v


## An achievements heading: the caption, and how many are earned on the right.
static func achievements_head(rows: Array) -> Control:
	var head := UI.hbox(8)
	head.add_child(UI.caption(Text.t("achievements.title")))
	head.add_child(UI.spacer())
	head.add_child(UI.caption(Text.t("achievements.count", {"have": rows.filter(func(r): return r["earned"]).size(), "total": rows.size()}), UI.INK_FAINT))
	return head
