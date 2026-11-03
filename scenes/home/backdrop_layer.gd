class_name BackdropLayer
extends TextureRect
## One layer of the home backdrop (art/home/backdrop.tscn): a one-colour
## picture, coloured by this node's Modulate in the editor. Further layers
## move less as you slide between screens (parallax).

## How far it moves as you slide between screens: 0 stays put, 1 moves
## with the screen.
@export_range(0.0, 1.0) var parallax := 0.2
## How bright it is at night, 0 to 1. Below 0 uses the backdrop's
## Night Brightness.
@export_range(-1.0, 1.0) var night_brightness := -1.0
