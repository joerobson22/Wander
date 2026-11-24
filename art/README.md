# Art

How to add and change every picture, place, animation and sound is in
**[assets/README.md](../assets/README.md)**.

```
art/
  animal_colours.gdshader     maps red/green/blue paint to an animal's colours
  animals/<animal id>/animal.tscn   an animal's rig: a pixel-art strip (frames.png)
  character/character.tscn     the player's character rig
  cosmetics/<item id>/         an item's pieces, one image per limb it covers
  gifts/<gift id>.png          a gift's picture, pixel art 16 x 16
  home/backdrop.tscn           the hilltop view behind every screen
  pixel_src/                   the pixel art's source; make.py rebuilds it
  places/<place id>.png        a place's button picture, white on transparent
  scenery/<place id>/place.tscn   a place's scenery: its layers, edited in Godot
  scenery/preview.tscn         run it (F6) to walk through any place
  walk/bush.tscn               the bush your pet dives into for a gift
  templates/                   working examples to copy
```
