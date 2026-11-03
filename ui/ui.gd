class_name UI
extends RefCounted
## The look of the app in one place: colours, type, the theme and the small
## builders every screen uses. Screens never style things themselves, so a
## change here shows up everywhere at once.

# --- Colours -----------------------------------------------------------------
# Palette tokens, in the storybook look: warm paper with soft watercolour
# washes, cards with hand-cut uneven corners and a pencil rim, in Fraunces
# and Quicksand. They switch between light and dark (set_dark) with the time
# of day. Screens read them at build time.

## Display and body fonts.
const FONTS := ["Fraunces", "Quicksand"]
## The pencil rim round surfaces, in pixels (its colour is EDGE).
const EDGE_WIDTH := 2

const PALETTES := {
	"light": {
		"BG": "#f6efe2", "SURFACE": "#fffcf5", "SURFACE_SOFT": "#efe4cf",
		"INK": "#3d2f24", "INK_SOFT": "#776251", "INK_FAINT": "#947e65",
		"LINE": "#6e543c33", "ACCENT": "#547e4f", "ACCENT_SOFT": "#dde9d2",
		"NEUTRAL": "#c4b49c", "SHELF": "#e0cfae",
		"SCRIM": "#3d2f2459", "SHADOW": "#6e543c26",
		"EDGE": "#d6cdc1", "ON_ACCENT": "#fffaf0",
	},
	"dark": {
		"BG": "#1e2233", "SURFACE": "#2b3046", "SURFACE_SOFT": "#343a55",
		"INK": "#efe6d6", "INK_SOFT": "#b9ad9a", "INK_FAINT": "#8e8574",
		"LINE": "#dcc8aa26", "ACCENT": "#9cc792", "ACCENT_SOFT": "#34463a",
		"NEUTRAL": "#5a5f78", "SHELF": "#3c4260",
		"SCRIM": "#00000099", "SHADOW": "#00000059",
		"EDGE": "#52515c", "ON_ACCENT": "#1e2233",
	},
}

static var dark := false
static var BG := Color("#f6efe2")
static var SURFACE := Color("#fffcf5")
static var SURFACE_SOFT := Color("#efe4cf")
static var INK := Color("#3d2f24")
static var INK_SOFT := Color("#776251")
static var INK_FAINT := Color("#947e65")
static var LINE := Color("#6e543c33")
static var ACCENT := Color("#547e4f")
static var ACCENT_SOFT := Color("#dde9d2")
static var NEUTRAL := Color("#c4b49c")
## The plank under the gift shelf.
static var SHELF := Color("#e0cfae")
static var SCRIM := Color("#3d2f2459")
static var SHADOW := Color("#6e543c26")
## The pencil rim round surfaces.
static var EDGE := Color("#d6cdc1")
## Text and icons on an ACCENT fill.
static var ON_ACCENT := Color("#fffaf0")

## Settings, Accessibility, Colour vision: the "vision" setting, one of
## VISIONS. Any but "off" swaps the colours that mean something (go and
## stop, the rarities, chart lines) for SAFE ones (set_dark). One set works
## for all three kinds of colour blindness.
const VISIONS := ["off", "protanopia", "deuteranopia", "tritanopia"]
static var vision := "off"
## Colours told apart with any kind of colour blindness (from Okabe and
## Ito): blue for go and orange for stop, and the rarities sky, navy,
## vermilion and yellow. tests/test_accessibility.gd checks them.
const SAFE := {
	"light": {"ACCENT": "#2b6cb0", "ACCENT_SOFT": "#d8e5f3"},
	"dark": {"ACCENT": "#8fb8e6", "ACCENT_SOFT": "#2f3f5a"},
	"SUCCESS": "#2b6cb0", "DANGER": "#b84f00",
	"SERIES": ["#0072b2", "#e69f00", "#56b4e9", "#d55e00", "#009e73", "#f0e442", "#cc79a7", "#8a8a8a"],
	# Rarity id: [colour, text colour].
	"rarities": {"common": ["#56b4e9", "#177ab2"], "rare": ["#1b3a6b", "#1b3a6b"], "epic": ["#d55e00", "#be5400"], "legendary": ["#f0e442", "#7d750a"]},
}

# The same in both modes.
static var SUCCESS := Color("#30854a")
static var DANGER := Color("#db3835")
## Text and icons on a coloured fill (buttons, tags, badges).
const ON_COLOUR := Color.WHITE
## Text over scenery.
const ON_DARK := Color("#f4f7f5")
const ON_DARK_SOFT := Color(0.957, 0.969, 0.961, 0.66)
## The streak flame.
const FLAME := Color("#e0702b")
## Colours for each project in charts, assigned in the order projects were made.
const SERIES_STANDARD := ["#2f6b4f", "#e39b3b", "#4d84c4", "#c45b7d", "#7c62c9", "#3aa39a", "#a6763f", "#8c9a3a"]
static var SERIES: Array = SERIES_STANDARD.map(func(c): return Color(c))

const RADIUS := 18
const WIDE_BREAKPOINT := 900.0
## The side of a screen's icon tile (icon_tile).
const ICON_TILE := 44

static var _fonts: Dictionary = {}


## Switches every palette token to its light or dark colour. Screens built
## afterwards use it; the shell rebuilds what's on screen.
static func set_dark(on: bool) -> void:
	dark = on
	var p: Dictionary = PALETTES["dark" if on else "light"].duplicate()
	var safe := vision != "off"
	if safe:
		p.merge(SAFE["dark" if on else "light"], true)
	SUCCESS = Color(SAFE["SUCCESS"]) if safe else Color("#30854a")
	DANGER = Color(SAFE["DANGER"]) if safe else Color("#db3835")
	SERIES = (SAFE["SERIES"] if safe else SERIES_STANDARD).map(func(c): return Color(c))
	BG = Color(p["BG"])
	SURFACE = Color(p["SURFACE"])
	SURFACE_SOFT = Color(p["SURFACE_SOFT"])
	INK = Color(p["INK"])
	INK_SOFT = Color(p["INK_SOFT"])
	INK_FAINT = Color(p["INK_FAINT"])
	LINE = Color(p["LINE"])
	ACCENT = Color(p["ACCENT"])
	ACCENT_SOFT = Color(p["ACCENT_SOFT"])
	NEUTRAL = Color(p["NEUTRAL"])
	SHELF = Color(p["SHELF"])
	SCRIM = Color(p["SCRIM"])
	SHADOW = Color(p["SHADOW"])
	EDGE = Color(p["EDGE"])
	ON_ACCENT = Color(p["ON_ACCENT"])


# --- Type --------------------------------------------------------------------

## The body or display font (Quicksand or Fraunces) at a given weight, cached.
static func font(display: bool = false, weight: int = 700) -> Font:
	var family: String = FONTS[0 if display else 1]
	var key := "%s_%d" % [family, weight]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = load("res://ui/fonts/%s.ttf" % family)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = fv
	return _fonts[key]


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(false, 700)
	t.default_font_size = 17
	t.set_color("font_color", "Label", INK)

	_theme_button(t, "Button", INK, BG)
	t.set_font("font", "Button", font(false, 800))

	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_FAINT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.25))
	var field := box(SURFACE, LINE, 16)
	field.content_margin_left = 16
	field.content_margin_right = 16
	t.set_stylebox("normal", "LineEdit", field)
	var focused := field.duplicate()
	focused.border_color = ACCENT
	t.set_stylebox("focus", "LineEdit", focused)

	t.set_stylebox("panel", "PanelContainer", box(SURFACE, Color.TRANSPARENT, 24))
	t.set_stylebox("panel", "Panel", box(SURFACE, Color.TRANSPARENT, 24))

	# Thin, rounded scrollbars that stay out of the way.
	for bar in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color.TRANSPARENT
		track.set_content_margin_all(2)
		var grab := box(Color(INK, 0.18), Color.TRANSPARENT, 99)
		grab.set_content_margin_all(2)
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, box(Color(INK, 0.3), Color.TRANSPARENT, 99))
		t.set_stylebox("grabber_pressed", bar, box(Color(INK, 0.4), Color.TRANSPARENT, 99))
	return t


static func _theme_button(t: Theme, type: String, fill: Color, ink: Color) -> void:
	var styles := button_styles(fill, 16)
	for state in styles:
		t.set_stylebox(state, type, styles[state])
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, type, ink)
	t.set_color("font_disabled_color", type, Color(ink, 0.5))


# --- Boxes -------------------------------------------------------------------

## A box: its hand-cut corners (see corners()), and the pencil rim round
## plain surfaces (SURFACE, SURFACE_SOFT, BG) unless `border` gives one.
static func box(fill: Color, border: Color = Color.TRANSPARENT, radius: int = RADIUS) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	corners(b, radius)
	b.content_margin_left = 20
	b.content_margin_right = 20
	b.content_margin_top = 12
	b.content_margin_bottom = 12
	if border.a > 0.0:
		b.set_border_width_all(2)
		b.border_color = border
	elif is_surface(fill) and (radius < 99 or EDGE.a >= 1.0):
		# (A see-through rim shows specks where a circle's segments meet,
		# so circles only get one when it's solid.)
		edge(b)
	return b


## A box with the hand-cut corners but never the rim, for thin bars.
static func bar_box(fill: Color, radius: int = 99) -> StyleBoxFlat:
	var b := box(fill, Color.TRANSPARENT, radius)
	b.set_border_width_all(0)
	return b


## Whether `fill` is one of the plain surface colours (any see-through).
static func is_surface(fill: Color) -> bool:
	if fill.a <= 0.0:
		return false
	for c in [SURFACE, SURFACE_SOFT, BG]:
		if is_equal_approx(fill.r, c.r) and is_equal_approx(fill.g, c.g) and is_equal_approx(fill.b, c.b):
			return true
	return false


## Gives `b` the pencil rim.
static func edge(b: StyleBoxFlat) -> StyleBoxFlat:
	if EDGE.a > 0.0:
		b.set_border_width_all(EDGE_WIDTH)
		b.border_color = EDGE
	return b


## Rounds `b`'s corners by `radius`: pills and circles (99 or more) stay
## round, and other boxes get each corner cut a little differently, by hand.
static func corners(b: StyleBoxFlat, radius: int) -> StyleBoxFlat:
	if radius >= 99 or radius < 8:
		b.set_corner_radius_all(radius)
	else:
		b.corner_radius_top_left = radius
		b.corner_radius_top_right = roundi(radius * 1.35)
		b.corner_radius_bottom_right = roundi(radius * 0.8)
		b.corner_radius_bottom_left = roundi(radius * 1.2)
	return b


## A soft shadow under `b`, deeper with `strength`.
static func with_shadow(b: StyleBoxFlat, strength: float = 1.0) -> StyleBoxFlat:
	b.shadow_color = Color(SHADOW, SHADOW.a * strength)
	b.shadow_size = int(14 * strength)
	b.shadow_offset = Vector2(0, 4 * strength)
	return b


## Styleboxes for every button state from one fill colour.
static func button_styles(fill: Color, radius: int, shadow: bool = false) -> Dictionary:
	var out := {}
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var shade := fill
		match state:
			"hover":
				shade = _shift(fill, 0.07)
			"pressed", "hover_pressed":
				shade = _shift(fill, 0.12)
			"disabled":
				shade = Color(fill, fill.a * 0.45)
		var sb := box(shade, Color.TRANSPARENT, radius)
		if state == "focus":
			sb = focus_ring(radius)
		else:
			if shadow and state != "disabled":
				with_shadow(sb, 0.8)
		out[state] = sb
	return out


## The green ring round whatever the keyboard is on (Tab moves it). It
## only shows when you got there with keys, not with a tap or a click.
static func focus_ring(radius: int) -> StyleBoxFlat:
	var sb := box(Color.TRANSPARENT, ACCENT, radius)
	sb.draw_center = false
	sb.expand_margin_left = 3
	sb.expand_margin_right = 3
	sb.expand_margin_top = 3
	sb.expand_margin_bottom = 3
	return sb


## Darkens light colours and lightens dark ones, for hover and press states.
static func _shift(c: Color, amount: float) -> Color:
	if c.a == 0.0:
		return Color(INK, amount)
	return c.darkened(amount) if c.get_luminance() > 0.3 else c.lightened(amount * 1.4)


## Applies one fill and text colour to every state of a button.
static func style_button(b: Button, fill: Color, ink: Color, radius: int = 16, shadow: bool = false) -> Button:
	var styles := button_styles(fill, radius, shadow)
	for state in styles:
		b.add_theme_stylebox_override(state, styles[state])
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.45))
	b.add_theme_color_override("icon_normal_color", ink)
	b.add_theme_color_override("icon_hover_color", ink)
	b.add_theme_color_override("icon_pressed_color", ink)
	b.add_theme_color_override("icon_hover_pressed_color", ink)
	b.add_theme_color_override("icon_focus_color", ink)
	b.add_theme_color_override("icon_disabled_color", Color(ink, 0.45))
	return b


static func is_wide(c: Control) -> bool:
	return c.get_viewport_rect().size.x >= WIDE_BREAKPOINT


## Space kept clear for the notch and home indicator on phones, in the
## viewport's own units: {top, bottom, left, right}. Always none on desktop:
## there the "safe area" is the whole screen's (in desktop coordinates, so a
## window on a second monitor would get the first one's width as a margin),
## and a window has nothing to keep clear of.
static func safe_insets(c: Control) -> Dictionary:
	if not c.is_inside_tree():
		return insets_for(Rect2(), Rect2(), 0.0, false)
	# The debug phone view keeps clear of its pretend camera and home bar.
	var app := c.get_tree().root.get_node_or_null("App")
	if app and app.state and app.debug_phone_view():
		return PhoneFrame.INSETS.duplicate()
	return insets_for(
		Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size())),
		Rect2(DisplayServer.get_display_safe_area()),
		c.get_viewport_rect().size.x, OS.has_feature("mobile"))


## The insets for a `window` and the display's `safe` area (both in desktop
## coordinates), scaled to a viewport `viewport_width` units wide. Measured
## from the window's own edges, never more than a quarter of it, and none
## at all off mobile.
static func insets_for(window: Rect2, safe: Rect2, viewport_width: float, mobile: bool) -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not mobile or window.size.x <= 0.0 or safe.size.x <= 0.0:
		return out
	var k := viewport_width / window.size.x
	out["top"] = clampf(safe.position.y - window.position.y, 0.0, window.size.y * 0.25) * k
	out["left"] = clampf(safe.position.x - window.position.x, 0.0, window.size.x * 0.25) * k
	out["bottom"] = clampf(window.end.y - safe.end.y, 0.0, window.size.y * 0.25) * k
	out["right"] = clampf(window.end.x - safe.end.x, 0.0, window.size.x * 0.25) * k
	return out


# --- Text --------------------------------------------------------------------

static func label(text: String, size: int = 17, colour: Color = INK, display: bool = false, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(display, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


## A wrapping paragraph that fills the width it's given.
static func para(text: String, size: int = 15, colour: Color = INK_SOFT, weight: int = 600) -> Label:
	var l := label(text, size, colour, false, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 80
	return l


## Small uppercase section caption.
static func caption(text: String, colour: Color = INK_SOFT) -> Label:
	var l := label(text.to_upper(), 12, colour, false, 800)
	return l


## "a rare" / "an epic": the word with its article.
static func a(word: String) -> String:
	return ("an " if not word.is_empty() and word[0].to_lower() in "aeiou" else "a ") + word


## A one-line label that trims with an ellipsis instead of growing.
static func trimmed(text: String, size: int = 15, colour: Color = INK, display: bool = false, weight: int = 700) -> Label:
	var l := label(text, size, colour, display, weight)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A pane's title, with its icon from the app map to the left, drawn as a
## green outline. Returns the row so panes can put something on the right
## (like the settings gear).
static func title_row(title: String, icon: String = "") -> HBoxContainer:
	var row := hbox(10)
	if icon != "":
		row.add_child(icon_tile(icon))
	var words := label(title, 32, INK, true, 600)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(words)
	return row


## A screen's app-map icon as a green outline with no tile behind it, as
## beside its title. It keeps the tile's square, so things line up with it.
static func icon_tile(icon: String) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(ICON_TILE, ICON_TILE)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = Icons.texture(icon, 34, ACCENT, 2.6)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(r)
	return holder


## A panel's own scrolling area, the one part of a screen that scrolls (the
## screens themselves never do). Scrolls down, or sideways with `sideways`,
## and fills the room it's given.
static func scroll_area(sideways: bool = false) -> ScrollContainer:
	var sc := ScrollContainer.new()
	if sideways:
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return sc


## A scroll_area() for a list of cards that lets their shadows show: the
## scrolling part reaches 16px past the holder's edges (into the screen's
## gutter), with the same room inside it round `content`, so the cards line
## up with everything above them yet aren't cut off flat at the sides. Put
## the returned holder in the layout; `content` goes inside it, and the
## ScrollContainer is the holder's only child.
static func shadow_scroll(content: Control) -> Control:
	var room := 16
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc := scroll_area()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = -room
	sc.offset_top = -room
	sc.offset_right = room
	sc.offset_bottom = room
	holder.add_child(sc)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, room)
	sc.add_child(margin)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	# The scrollbar takes its width from the room on the right, not from the
	# cards, so they keep lining up with what's above.
	var bar := sc.get_v_scroll_bar()
	var fit := func():
		var used := int(bar.get_combined_minimum_size().x) if bar.visible else 0
		margin.add_theme_constant_override("margin_right", maxi(0, room - used))
	bar.visibility_changed.connect(fit)
	fit.call()
	return holder


## Keeps `content` (a MarginContainer inside `sc`) clear of `sc`'s scrollbar:
## while the bar shows, `gap` more room on its side (the right for a list
## that scrolls down, the bottom for a sideways strip), so nothing touches
## it; none when everything fits.
static func clear_of_bar(sc: ScrollContainer, content: MarginContainer, gap: int = 10) -> void:
	var sideways := sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
	var bar: ScrollBar = [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()][int(sideways)]
	var side := "margin_bottom" if sideways else "margin_right"
	var fit := func():
		content.add_theme_constant_override(side, gap if bar.visible else 0)
	bar.visibility_changed.connect(fit)
	fit.call()


# --- Buttons -----------------------------------------------------------------

## A text button. `kind` picks the style: "primary" (ink), "accent" (green),
## "quiet" (soft grey), "danger", "success", "white" or "ghost" (no fill).
static func button(text: String, on_press: Callable, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	match kind:
		"accent":
			style_button(b, ACCENT, ON_ACCENT)
		"quiet":
			style_button(b, SURFACE_SOFT, INK)
		"danger":
			style_button(b, DANGER, ON_COLOUR)
		"success":
			style_button(b, SUCCESS, ON_COLOUR)
		"white":
			style_button(b, SURFACE, INK, 16, true)
		"ghost":
			style_button(b, Color.TRANSPARENT, INK)
		_:
			style_button(b, INK, BG)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Words you can tap, in green with no fill, like a link ("Privacy Policy").
static func text_link(text: String, on_press: Callable, size: int = 15) -> Button:
	var b := button(text, on_press, "ghost")
	b.custom_minimum_size = Vector2.ZERO
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := (b.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		b.add_theme_stylebox_override(state, sb)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ACCENT)
	b.add_theme_font_size_override("font_size", size)
	b.set_meta("no_grow", true)
	return b


## A round button holding one icon, like the delete and complete buttons.
static func round_button(icon: String, tip: String, on_press: Callable, fill: Color = SURFACE,
		ink: Color = INK, diameter: int = 52, shadow: bool = true) -> Button:
	var b := Button.new()
	b.accessibility_name = tip
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.icon = Icons.texture(icon, int(diameter * 0.42), Color.WHITE, 2.6)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	style_button(b, fill, ink, 999, shadow)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.set_content_margin_all(0)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## An icon with no button round it (the "x" that closes things): just the
## icon in `ink`, a `diameter` square to hit. It grows on hover like every
## button, but never shows a fill.
static func ghost_button(icon: String, tip: String, on_press: Callable, ink: Color = INK,
		diameter: int = 36, icon_px: int = 22) -> Button:
	var b := Button.new()
	b.accessibility_name = tip
	b.flat = true
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.icon = Icons.texture(icon, icon_px, Color.WHITE, 2.6)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.mouse_default_cursor_shape = Cursor.HOVER
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", focus_ring(999))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("icon_disabled_color", Color(ink, 0.45))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Round filter/segment pill: ink when selected, soft grey when not.
static func pill_button(text: String, selected: bool, on_press: Callable, height: int = 38) -> Button:
	var b := button(text, on_press, "primary" if selected else "quiet")
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		corners(sb, 999)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.content_margin_left = 16
		sb.content_margin_right = 16
	return b


# --- Layout ------------------------------------------------------------------

static func card(fill: Color = SURFACE, padding: int = 20, radius: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	var b := with_shadow(box(fill, Color.TRANSPARENT, radius))
	b.set_content_margin_all(padding)
	p.add_theme_stylebox_override("panel", b)
	return p


## A flat rounded panel with no shadow, for areas inside cards.
static func panel(fill: Color, radius: int = 18, padding: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(fill, Color.TRANSPARENT, radius)
	b.set_content_margin_all(padding)
	p.add_theme_stylebox_override("panel", b)
	return p


## The watercolour paper behind a screen, filling its parent. dress_backdrop() repaints it after the look changes.
static func backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.resized.connect(func():
		if bg.material:
			(bg.material as ShaderMaterial).set_shader_parameter("rect_size", bg.size))
	dress_backdrop(bg)
	return bg


static func dress_backdrop(bg: ColorRect) -> void:
	var m := bg.material as ShaderMaterial
	if m == null:
		m = ShaderMaterial.new()
		m.shader = preload("res://ui/backdrop.gdshader")
		bg.material = m
	bg.color = Color.WHITE
	m.set_shader_parameter("rect_size", bg.size)
	m.set_shader_parameter("top", BG)
	m.set_shader_parameter("middle", BG)
	m.set_shader_parameter("bottom", BG)
	# Watercolour washes of sky, sand and leaf on paper.
	var k := 0.16 if dark else 0.22
	m.set_shader_parameter("wash_a", Color(0.55, 0.71, 0.78, k))
	m.set_shader_parameter("wash_b", Color(0.78, 0.67, 0.47, k))
	m.set_shader_parameter("wash_c", Color(0.51, 0.67, 0.43, k))
	m.set_shader_parameter("at_a", Vector3(0.15, 0.1, 0.5))
	m.set_shader_parameter("at_b", Vector3(0.85, 0.32, 0.45))
	m.set_shader_parameter("at_c", Vector3(0.6, 0.95, 0.55))
	m.set_shader_parameter("grain", 0.05 if dark else 0.07)


static func vbox(gap: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v


static func hbox(gap: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h


static func spacer(vertical: bool = false) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func divider() -> Control:
	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## A small rounded tag, like a rarity name.
static func tag(text: String, fill: Color, colour: Color, size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(fill, Color.TRANSPARENT, 999)
	b.content_margin_left = 9
	b.content_margin_right = 9
	b.content_margin_top = 2
	b.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", b)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(label(text, size, colour, false, 800))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A thin rounded bar filled to `fraction`, e.g. a week against your best.
static func progress_line(fraction: float, fill: Color = ACCENT, height: int = 4) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_style_box(box(LINE, Color.TRANSPARENT, 99), Rect2(Vector2.ZERO, c.size))
		var w := c.size.x * clampf(fraction, 0.0, 1.0)
		if w >= 1.0:
			c.draw_style_box(box(fill, Color.TRANSPARENT, 99), Rect2(Vector2.ZERO, Vector2(maxf(w, c.size.y), c.size.y))))
	return c


static func icon_rect(icon: String, px: int, colour: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Icons.texture(icon, px, colour)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Stops `node`'s children taking clicks, so the node itself gets them.
static func ignore_mouse(node: Node) -> void:
	for c in node.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(c)


## The colour a project (or with `kind` "pets" a pet, "places" a place) is
## drawn in on charts: the palette in order of when it was made (adopted,
## or its order in biomes.json).
static func series_colour(id: String, kind: String = "projects") -> Color:
	var list: Array
	match kind:
		"pets":
			list = App.state.pets.map(func(p): return p.id)
		"places":
			list = Content.biomes.map(func(b): return b["id"])
		_:
			list = App.state.projects.map(func(p): return p.id)
	var i := list.find(id)
	return SERIES[i % SERIES.size()] if i >= 0 else INK_FAINT


# --- Pictures ----------------------------------------------------------------

## An animal standing in a fixed-size box (for panels and lists).
static func animal_portrait(animal_id: String, colours: Array[Color], box_size: Vector2) -> Control:
	var frame := PanelContainer.new()
	var fb := box(ACCENT_SOFT, Color.TRANSPARENT, 18)
	fb.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fb)
	frame.custom_minimum_size = box_size
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	var view := AnimalView.new()
	view.animal_id = animal_id
	view.colours = colours
	holder.add_child(view)
	var place := func():
		# Big animals (bear, elephant) are drawn larger, so fit by their size too.
		var s := minf(holder.size.x / 150.0, holder.size.y / 95.0) / float(Content.animal(animal_id).get("size", 1.0))
		view.scale = Vector2(s, s)
		view.position = Vector2(holder.size.x * 0.45, holder.size.y * 0.88)
	holder.resized.connect(place)
	return frame


## A place's icon in white on a tile of its ground colour (a little darker,
## so the icon shows), `side` square.
static func place_tile(biome: Dictionary, side: int) -> PanelContainer:
	var colour := ACCENT
	for layer in biome.get("layers", []):
		if layer["kind"] == "ground":
			colour = Color.from_string(layer["colour"], ACCENT).darkened(0.3)
	var tile := panel(colour, roundi(side * 0.28), 0)
	tile.custom_minimum_size = Vector2(side, side)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.place(biome, roundi(side * 0.5))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	return tile


## The player's (or a friend's) character in a box: the full figure, or just
## the face in a circle for avatars.
## `bottom_room` keeps that much clear under the character's feet, for
## something laid over the bottom of the picture.
static func character_portrait(look: Dictionary, box_size: Vector2, face_only: bool = false, fill: Color = ACCENT_SOFT, bottom_room: float = 0.0) -> Control:
	var frame := RoundFrame.new()
	frame.accessibility_name = Text.t("alt.face" if face_only else "alt.character")
	frame.fill = fill
	frame.circle = face_only
	frame.custom_minimum_size = box_size
	var view := CharacterView.new()
	view.look = look
	view.face_only = face_only
	view.holding_lead = false
	frame.add_child(view)
	var place := func():
		if face_only:
			var s := minf(frame.size.x, frame.size.y) / 44.0
			view.scale = Vector2(s, s)
			view.position = frame.size * 0.5 + Vector2(0, 4) * s
		else:
			var usable := frame.size.y - bottom_room
			# By height, but never so big the character spills out sideways.
			var s := minf(usable / 175.0, frame.size.x / 72.0)
			view.scale = Vector2(s, s)
			view.position = Vector2(frame.size.x * 0.48, usable * 0.94)
	frame.resized.connect(place)
	return frame


## A round badge with a level number in it.
static func level_badge(level: int, diameter: int = 40) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(ACCENT, Color(1, 1, 1, 0.9), 999)
	b.set_border_width_all(3)
	b.set_content_margin_all(0)
	b.shadow_color = Color(0, 0, 0, 0.15)
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", b)
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(str(level), int(diameter * 0.45), ON_ACCENT, true, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## A coloured badge for a grade ("gcse/9", "uni/first"...).
static func grade_badge(grade_ref: String, diameter: int = 44) -> Control:
	var g := Content.grade(grade_ref)
	var p := PanelContainer.new()
	var b := box(Color.from_string(g.get("colour", "#8c8c7e"), NEUTRAL), Color(1, 1, 1, 0.9), 999)
	b.set_border_width_all(3)
	b.set_content_margin_all(0)
	b.shadow_color = Color(0, 0, 0, 0.12)
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", b)
	var text: String = g.get("label", "?")
	p.custom_minimum_size = Vector2(maxf(diameter, 14.0 + text.length() * diameter * 0.3), diameter)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, int(diameter * (0.42 if text.length() < 3 else 0.34)), Color.from_string(g.get("ink", "#ffffff"), Color.WHITE), true, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.accessibility_name = Text.t("project.grade_name", {"scale": g.get("scale_name", ""), "grade": g.get("name", "")})
	return p
