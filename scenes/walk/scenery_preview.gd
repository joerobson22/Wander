extends Control
## Try a place out: open art/scenery/preview.tscn and press F6 (Run Current
## Scene). It walks a pet through the place, with its real sky, light and
## weather. Click the root node to change what you see in the Inspector,
## then run it again. Changes to a place's scene show the next time it runs.

## The place (its id in data/biomes.json).
@export var place := "lake"
## The time of day, 0 to 24 (13.5 is half past one); below 0 follows the clock.
@export_range(-1.0, 24.0, 0.25) var hour := 12.0
## The weather. Empty follows the real weather, if it's allowed.
@export_enum("sunny", "partly", "cloudy", "rainy", "stormy", "snowy") var weather := "sunny"
## Who walks (an id from data/animals.json).
@export var animal := "dog1"
## Scenery speed (0 stands still).
@export_range(0.0, 5.0, 0.1) var speed := 1.0

var _scenery: Scenery
var _walker: CharacterView
var _animal: AnimalView


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scenery = Scenery.new()
	_scenery.biome = Content.biome(place)
	_scenery.clock = hour
	_scenery.weather = weather
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scenery)
	_walker = CharacterView.new()
	_walker.walking = speed > 0.0
	_scenery.add_child(_walker)
	_animal = AnimalView.new()
	_animal.animal_id = animal
	_animal.colours = Content.animal_default_colours(animal)
	_animal.walking = speed > 0.0
	_scenery.add_child(_animal)
	resized.connect(_layout)
	_layout.call_deferred()
	Audio.ambience(_scenery.ambience())


func _layout() -> void:
	var spots := ChooseFocus.walk_spots(size, _scenery.path_y())
	var s: float = spots["unit"]
	_walker.scale = Vector2(s, s)
	_walker.position = spots["walker"]
	_animal.scale = Vector2(s, s)
	_animal.position = spots["animal"]
	_scenery.stand(_walker, _walker.position.y)
	_scenery.stand(_animal, _animal.position.y)


func _process(delta: float) -> void:
	_scenery.scroll += delta * 70.0 * speed * minf(size.x, size.y) / 720.0
