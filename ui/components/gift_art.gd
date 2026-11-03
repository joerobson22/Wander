class_name GiftArt
extends Control
## A gift's picture: the image at art/gifts/<gift id>.png (or .svg, .webp)
## when there is one, else a gift box, on a disc of its rarity's colour with
## an optional glow. Every screen that shows a gift uses this.

const DIR := "res://art/gifts/"
const EXTENSIONS := ["png", "svg", "webp"]

static var _textures := {}


## The gift's own picture, or null while it has none.
static func texture_for(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = null
		for ext in EXTENSIONS:
			var path: String = DIR + id + "." + ext
			if ResourceLoader.exists(path):
				_textures[id] = load(path)
				break
	return _textures[id]

var gift_id := "":
	set(v):
		gift_id = v
		queue_redraw()
## 0..1: how strongly it glows in its rarity's colour.
var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()
## Dimmed for gifts you've found but have none of right now.
var faded := false


func _init(id: String = "", glow_amount: float = 0.0) -> void:
	gift_id = id
	glow = glow_amount
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = str(Content.gift(id).get("name", "")) if id != "" else ""


func colour() -> Color:
	return Content.rarity_colour(Content.gift(gift_id).get("rarity", "common"))


func _draw() -> void:
	if gift_id == "":
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var col := colour()
	if faded:
		col = col.lerp(UI.NEUTRAL, 0.7)
	if glow > 0.0:
		for i in 10:
			var t := 1.0 + i * 0.09
			draw_circle(c, r * t, Color(col, 0.05 * glow * (1.0 - i / 10.0)), true, -1.0, true)
	draw_circle(c, r * 0.92, UI.SURFACE.lerp(col, 0.18), true, -1.0, true)
	draw_circle(c, r * 0.74, UI.SURFACE.lerp(col, 0.32), true, -1.0, true)
	var art := texture_for(gift_id)
	if art:
		var box := Vector2.ONE * r * 1.5
		draw_texture_rect(art, Rect2(c - box * 0.5, box), false, Color(1, 1, 1, 0.45) if faded else Color.WHITE)
		return
	var px := maxi(8, int(r * 0.95))
	draw_texture(Icons.texture("gift", px, col.darkened(0.12), 2.0), c - Vector2(px, px) * 0.5)
