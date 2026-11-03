extends TestCase
## Colours that people can read and tell apart: text against what it sits
## on, in light and dark, and the colours that mean something (go and stop,
## rarities) under each kind of colour blindness, with the colour vision
## setting on.

## What each kind of colour blindness sees (Machado, Oliveira and Fernandes
## 2009, full strength), as rows in linear RGB.
const SIMULATE := {
	"protanopia": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	"deuteranopia": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	"tritanopia": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
## How far apart (in OKLab) two colours that mean different things must look.
const APART := 0.15


func after() -> void:
	UI.vision = "off"
	UI.set_dark(false)


func test_text_is_readable_in_light_and_dark() -> void:
	for mode in ["light", "dark"]:
		var p: Dictionary = UI.PALETTES[mode]
		for bg in ["BG", "SURFACE", "SURFACE_SOFT"]:
			check(_contrast(p["INK"], p[bg]) >= 7.0, "%s INK on %s" % [mode, bg])
			check(_contrast(p["INK_SOFT"], p[bg]) >= 4.5, "%s INK_SOFT on %s (%.2f)" % [mode, bg, _contrast(p["INK_SOFT"], p[bg])])
			# Faint text is only ever hints and things that are off.
			check(_contrast(p["INK_FAINT"], p[bg]) >= 3.0, "%s INK_FAINT on %s (%.2f)" % [mode, bg, _contrast(p["INK_FAINT"], p[bg])])
		check(_contrast(p["ON_ACCENT"], p["ACCENT"]) >= 4.5, "%s words on green buttons" % mode)


func test_coloured_buttons_and_tags_are_readable() -> void:
	for vision in ["off", "deuteranopia"]:
		for dark in [false, true]:
			UI.vision = vision
			UI.set_dark(dark)
			check(_contrast(UI.ON_COLOUR, UI.DANGER) >= 4.5, "%s danger button" % vision)
			check(_contrast(UI.ON_COLOUR, UI.SUCCESS) >= 4.5, "%s success button" % vision)
			check(_contrast(UI.ON_ACCENT, UI.ACCENT) >= 4.5, "%s accent button, dark %s" % [vision, dark])
			for r in ["common", "rare", "epic", "legendary"]:
				# Rarity tags are white on the text shade, and the text shade
				# is used as words on cards.
				check(_contrast(UI.ON_COLOUR, Content.rarity_text_colour(r)) >= 4.5, "%s %s tag" % [vision, r])
				check(_contrast(Content.rarity_text_colour(r), Color("#fffcf5")) >= 4.5, "%s %s words" % [vision, r])
	after()


func test_meaningful_colours_stay_apart_with_colour_blindness() -> void:
	for kind in SIMULATE:
		UI.vision = kind
		for dark in [false, true]:
			UI.set_dark(dark)
			var d := _apart(UI.ACCENT, UI.DANGER, kind)
			check(d >= APART, "%s go and stop, dark %s (%.3f)" % [kind, dark, d])
		var rarities := ["common", "rare", "epic", "legendary"].map(func(r): return Content.rarity_colour(r))
		for i in rarities.size():
			for j in range(i + 1, rarities.size()):
				var d := _apart(rarities[i], rarities[j], kind)
				check(d >= APART, "%s rarities %d and %d (%.3f)" % [kind, i, j, d])
	after()


func test_every_vision_has_a_name() -> void:
	for id in UI.VISIONS:
		check(Text.lookup("settings.visions." + id) is String, id)


static func _contrast(a, b) -> float:
	var la := Color(a).srgb_to_linear().get_luminance()
	var lb := Color(b).srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## How far apart `a` and `b` look to someone with `kind`, in OKLab.
static func _apart(a: Color, b: Color, kind: String) -> float:
	return _oklab(_seen(a, kind)).distance_to(_oklab(_seen(b, kind)))


static func _seen(c: Color, kind: String) -> Vector3:
	var lin := c.srgb_to_linear()
	var m: Array = SIMULATE[kind]
	var v := Vector3(lin.r, lin.g, lin.b)
	return Vector3(Vector3(m[0][0], m[0][1], m[0][2]).dot(v), Vector3(m[1][0], m[1][1], m[1][2]).dot(v),
		Vector3(m[2][0], m[2][1], m[2][2]).dot(v)).clamp(Vector3.ZERO, Vector3.ONE)


static func _oklab(c: Vector3) -> Vector3:
	var l := 0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z
	var m := 0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z
	var s := 0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z
	l = pow(l, 1.0 / 3.0)
	m = pow(m, 1.0 / 3.0)
	s = pow(s, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
