class_name GiftDetails
extends RefCounted
## A closer look at one gift, in a popup: its picture, rarity, which animal
## it's from and how many you have. Opened after a trade for the gift it
## brought, and from a friend's shelf (just to look at: no count). Trading
## in happens on the gifts screen itself (GiftTile, GiftInfo).


## `fresh` celebrates a gift that's just arrived from a trade, and `first`
## marks it NEW beside its name: one you'd never had before. `yours` off
## leaves out how many you have, for a friend's gift. `message` is a line
## above it all ("Happy Halloween! Here's a present.").
static func open(id: String, fresh: bool = false, yours: bool = true, first: bool = false, message: String = "") -> void:
	var g := Content.gift(id)
	if g.is_empty():
		return
	var count := App.state.gift_count(id)
	var rarity: String = g["rarity"]
	var m := Modal.open(400)
	if message != "":
		m.body.add_child(UI.label(message, 15, UI.ACCENT, false, 800))
	var head := m.heading_row(g["name"])
	# NEW (one you'd never had) and COSMETIC (one you can wear) sit right
	# after the name, which keeps only the room it needs.
	var badges: Array[Control] = []
	if first:
		badges.append(UI.tag(Text.t("gift.new"), UI.INK, UI.BG))
	if g.has("slot"):
		badges.append(UI.cosmetic_tag())
	if not badges.is_empty():
		for i in badges.size():
			head.add_child(badges[i])
			head.move_child(badges[i], 1 + i)
		var gap := UI.spacer()
		head.add_child(gap)
		head.move_child(gap, 1 + badges.size())
		UI.fit_name(head.get_child(0) as Label, head)
	m.body.add_child(head)
	var art := GiftArt.new(id, 1.0)
	art.custom_minimum_size = Vector2(0, 170)
	m.body.add_child(art)
	if fresh:
		Audio.play("trade_new_gift", 1.0, -4.0, "chime")
		art.get_tree().create_timer(Motion.time(Motion.NORMAL)).timeout.connect(func():
			if is_instance_valid(art):
				Motion.pop(art, 0.2, 0.5))

	var meta := UI.hbox(8)
	meta.add_child(UI.tag(Content.rarity_name(rarity).to_upper(), Content.rarity_text_colour(rarity), UI.ON_COLOUR))
	var table_name: String = Content.table(g["table"]).get("name", "")
	meta.add_child(UI.label(Text.t("gift.from", {"table": table_name.to_lower()}), 14, UI.INK_SOFT, false, 700))
	m.body.add_child(meta)
	m.body.add_child(UI.para(g.get("description", ""), 16, UI.INK))
	if not yours:
		return
	m.body.add_child(UI.label(Text.t("gift.you_have", {"n": count}), 15, UI.INK_SOFT, false, 800))
