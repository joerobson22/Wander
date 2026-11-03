class_name HolidayLook
extends Resource
## How a holiday dresses the app up (art/holidays/<id>/look.tres: open it in
## the Godot editor to change it). When it's on is data/holidays.json.

## Pins the time of day shown, in hours (0 is midnight); below 0 follows the clock.
@export_range(-1.0, 24.0, 0.25) var hour := -1.0
## Pins the weather on every walk (see Weather.KINDS); "" follows the real weather.
@export var weather := ""

@export_group("Walks")
## Every tree in every place is bare and dead.
@export var dead_trees := false
## Snow on the tree tops and the ground, and snow piling up as you walk.
@export var snow := false
## How long a walk takes to pile the snow up fully, in minutes...
@export var snow_pile_minutes := 30.0
## ...and how high it piles, as a share of the screen's height.
@export_range(0.0, 0.5) var snow_pile_height := 0.1
## Pictures dotted along the grass beside the path (pumpkins, eggs), picked at random.
@export var ground_props: Array[Texture2D] = []
## Roughly how far apart they are, and how tall, in pixels on a 720 tall screen.
@export var prop_spacing := 220.0
@export var prop_height := 34.0
## The share of trees hung with lights (0 for none), and the bulbs' colours.
@export_range(0.0, 1.0) var lit_trees := 0.0
@export var light_colours := PackedColorArray()
## Fireworks going off in the sky (on walks and behind the menus).
@export var fireworks := false
@export var firework_colours := PackedColorArray()

@export_group("Menus")
## Added to the hilltop view behind the menus: a Node2D whose children are
## named after its layers (Hilltop, ForestNear...) and laid out in that
## layer's picture's pixels (1600 by 1000). See art/holidays/halloween/home.tscn.
@export var home_scene: PackedScene
## Hung over the menus (under popups and walks): a Control filling the
## screen, e.g. lights or bunting along the top.
@export var menu_scene: PackedScene
## Pictures that replace layers of the hilltop view, by layer name (dead
## forests for Halloween).
@export var backdrop_swaps: Dictionary = {}
## The focus orb's colours: its blobs drift through these in turn instead
## of its usual greens and blues (none keeps those).
@export var orb_colours := PackedColorArray()

@export_group("You")
## A hat you wear all day whatever you've picked (a gift id); "" for none.
@export var hat := ""
