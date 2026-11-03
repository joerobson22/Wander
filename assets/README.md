# Editing the app's look and sound

This is the guide to every picture, place, sound and animation in Paws &
Progress, and how to change each one in the Godot editor. Everything here
is optional: anything you haven't replaced keeps the drawing or sound the
app makes for itself, so you can swap things in one at a time.

## Contents

1. [Before you start](#before-you-start)
2. [Where everything lives](#where-everything-lives)
3. [Places (the walk's scenery)](#places-the-walks-scenery)
4. [Animals](#animals)
5. [Your character and its clothes](#your-character-and-its-clothes)
6. [Gifts](#gifts)
7. [The home view behind every screen](#the-home-view-behind-every-screen)
8. [Holidays](#holidays)
9. [The bush your pet dives into](#the-bush-your-pet-dives-into)
10. [Sounds](#sounds)
11. [Animations and timings](#animations-and-timings)
12. [Icons](#icons)
13. [Place buttons](#place-buttons)
14. [App icon and launch screen](#app-icon-and-launch-screen)
15. [Fonts](#fonts)
16. [Words](#words)
17. [Painting in red, green and blue](#painting-in-red-green-and-blue)
18. [When something doesn't show up](#when-something-doesnt-show-up)

---

## Before you start

Open the project in **Godot 4.6** (Project Manager, Import, pick
`project.godot`). The parts of the editor this guide uses:

| Part | Where | What it's for |
| --- | --- | --- |
| **FileSystem** dock | bottom left | Every file. Double-click a scene (`.tscn`) to open it, or a resource (`.tres`) to show it in the Inspector. Drag files from your computer into it to add them. |
| **Scene** dock | top left | The nodes in the open scene. Click one to change it. |
| **Inspector** | right | The settings of whatever you clicked. Changes show straight away. |
| **2D** view | middle | The open scene. Drag things about; scroll to zoom. |
| **Animation** panel | bottom | Opens when you click an `AnimationPlayer`. |

Save with **Ctrl+S** (Cmd+S on a Mac). Press **F5** to run the app, or
**F6** to run just the scene you have open.

While the app runs from the editor, the focus screen has a small debug bar:

- **Unlock all** opens every place and animal (and gives you 50 of every
  gift), so you can see your new art without earning it.
- **Phone size** shows the app exactly as on a phone (an iPhone's screen,
  with its rounded corners, camera and home bar). Turn it off to go back.
- **Time** (top right) moves the time of day, for checking art by night.
- **Theme** (under Time) shows a holiday's look whatever the date. Today's
  date follows the calendar; No holiday turns them off.

---

## Where everything lives

| What | File | How you change it |
| --- | --- | --- |
| A place's scenery | `art/scenery/<place>/place.tscn` | Open the scene; click a layer; change it in the Inspector, or put your own sprites inside it. |
| Trying a place out | `art/scenery/preview.tscn` | Open it, set the place and time in the Inspector, press F6. |
| An animal | `art/animals/<animal>/animal.tscn` | Copy `art/templates/animal/`, swap in your limbs, animate them. |
| Your character | `art/character/character.tscn` | Copy `art/templates/character/`. |
| Clothes and hats | `art/cosmetics/<item>/<limb>.png` | One image per limb the item covers. |
| A gift | `art/gifts/<gift>.png` | Save a square image with the gift's id as its name. |
| The home view | `art/home/backdrop.tscn` | Open the scene; change the layers' pictures and colours. |
| A holiday's look | `art/holidays/<holiday>/look.tres` | Double-click it; change it in the Inspector (see [Holidays](#holidays)). |
| The dive bush | `art/walk/bush.tscn` | Open the scene; put your sprites inside it. |
| Every sound | `assets/sounds/sounds.tres` | Double-click it; pick a recording, loudness and pitch per sound. |
| Timings and curves | `ui/motion.tres` | Double-click it; change any timing in the Inspector. |
| Icons | `assets/icons/<name>.svg` | Replace the SVG (one colour, 24 × 24). |
| Place buttons | `art/places/<place>.png` | White on transparent, square. |
| App icon, launch screen | `assets/brand/` | Replace the files. |
| Fonts | `ui/fonts/` | Replace the `.ttf` files. |
| Words | `data/text.json` | Edit the text. |

The ids (`<place>`, `<animal>`, `<gift>`, `<item>`) are in the `data/`
files: `biomes.json` for places, `animals.json`, `gifts.json` and
`cosmetics.json`.

---

## Places (the walk's scenery)

Each place's scenery is a scene: `art/scenery/<place>/place.tscn`
(`lake`, `farm`, `forest`, `beach`, `jungle`, `tundra`, `desert`, `city`,
`safari`, `blossom`, `moon`). Double-click one in the FileSystem dock and
the place appears in the 2D view, drawn just as the walk draws it, inside a
frame the size of the screen (1280 × 720). The dashed white line is the
path you and your pet walk along.

### Layers

The scene's children are its **layers**, drawn back to front in the order
they're listed: the first is the furthest away. Each one is a stretch of
scenery that repeats forever as you walk. Click a layer in the Scene dock
and the Inspector shows its settings:

| Setting | What it does |
| --- | --- |
| **Kind** | What's drawn: `hills`, `mountains`, `trees`, `pines`, `broadleaf`, `canopy`, `palms`, `acacias`, `blossoms`, `mesas`, `cacti`, `water`, `ground` (with the path), `fields`, `barns`, `fences`, `buildings`, `lamps` (lit after dark), `reeds`, `fronds`, `drifts` (snow), `undergrowth` (leaves up from the bottom), `vines` (hanging from the top), `stalks` (tall plants) and `planet` (a world in the Moon's sky). |
| **Parallax** | How fast it moves past. The ground is 1. Far things are slower (0.1), and growth right in front of you is faster (1.4 or more). |
| **Y** | The line it stands on: 0 is the top of the screen, 1 the bottom. You can also drag the layer up and down in the 2D view. Things grow up from this line; water and ground run down from it. |
| **Height** | How tall it is, as a share of the screen. |
| **Colour** | Its colour by day. The time of day and the weather tint it for you, so always pick daytime colours. |
| **Pattern** | Any number. A different number shuffles where things go and how hills roll. |
| Shape: **Spacing** | The gap between trees, buildings and so on, in pixels (0 uses 70). |
| Shape: **Wavelength** | How far apart hills or fields rise (0 uses 400). |
| Shape: **Skip** | The share of spaces left empty, for undergrowth, vines and stalks. |
| Shape: **Front** | Draws it in front of you and your pet (the jungle's big leaves). Tall front plants keep clear of your pet when you choose a walk. |
| Shape: **Snow**, **Foam**, **Craters** | White tips on mountains and pines; surf on water; craters in the ground. |
| Shape: **Path Colour** | The path's colour on the ground layer. Leave it see-through for sand. |

To add a layer, click one and press **Ctrl+D** to duplicate it, then drag
it up or down the Scene dock to where it belongs. To remove one, press
**Delete**. Every place needs a `ground` layer: it sets where the path is.

### Your own art in a layer

There are two ways to replace a layer's drawing with your own pictures.

**Sprites straight inside the layer** (the easiest):

1. Drag your images (PNG) into the FileSystem dock, say into
   `art/scenery/<place>/`.
2. Drag an image from there onto the layer in the Scene dock. It becomes a
   sprite inside the layer, and the layer stops drawing its kind.
3. Move and size your sprites in the 2D view. The layer's origin (its
   0, 0) is its line: draw upwards from it (negative y).
4. Add a **ReferenceRect** inside the layer, name it `TileBounds`, and size
   it to one repeat of your art (its width is what matters). Make the left
   and right edges line up so there's no seam where it repeats. Without
   one, it repeats every **Tile Width** pixels (in the layer's Your Art
   settings).

**A tile scene** (for art you want to use in more than one place): copy
`art/templates/scenery/tile.tscn`, arrange it the same way (it has a red
`TileBounds` box already), and drag the scene onto the layer's **Art**
setting in the Inspector.

Either way, the art is drawn for a screen 720 tall and scaled to fit, and
the layer's Parallax, Y, Front and the light all still apply. Paint in
daytime colours.

### Trying a place out

Open `art/scenery/preview.tscn`, click its root node, and set in the
Inspector: **Place** (an id), **Hour** (13.5 is half past one), **Weather**,
**Animal** and **Speed**. Press **F6**. You walk through the place with its
real sky, light, weather and sounds.

### The rest of a place

What a place is called, what unlocks it, its button icon, its sounds
(`ambience`), its effects (`fx`: fireflies, stars, snow, wind) and how the
weather shows there are in `data/biomes.json`. To add a new place, add it
there and make its scene: duplicate another place's folder in
`art/scenery/` and rename the folder to the new id.

---

## Animals

An animal is a little puppet: each limb is its own picture, moved by an
animation. Until an animal has one, the app draws a placeholder.

1. Copy `art/templates/animal/` to `art/animals/<animal>/` (e.g.
   `art/animals/dog1/`). Its `sprite_dir` in `data/animals.json` already
   points there.
2. Open `animal.tscn`. Each limb (body, head, tail, four legs) is a
   **Sprite2D**. Click one and drag your image onto its **Texture** in the
   Inspector. Move its pivot by moving the node, and its picture with its
   **Offset**.
3. Paint the limbs in pure red, green and blue (see
   [Painting in red, green and blue](#painting-in-red-green-and-blue)).
   Red becomes the animal's first colour, green its second and blue its
   third: the ones picked when adopting.
4. Click the **AnimationPlayer** to animate. You need a looping `walk`,
   and can add a looping `idle` (standing still). Feet rest on the origin
   (0, 0) and the animal faces right. How fast it plays follows the
   animal's `walk_speed`.
5. Move the **Neck** marker to where the lead clips on and the **Mouth**
   marker to where it holds a gift. Both follow the animation.
6. Size is set by `size` in `animals.json`, so you never scale the rig.

You can add and remove limbs freely; only the names `AnimationPlayer`,
`Neck` and `Mouth` matter. Its sound, how it dives for a gift and its
colours are in `data/animals.json`.

---

## Your character and its clothes

The character is one puppet that every item is laid onto, so a jumper's
sleeves swing with the arms and a hat bobs with the head.

1. Copy `art/templates/character/` to `art/character/` and open
   `character.tscn`. It has six limbs, `Torso`, `Head`, `ArmBack`,
   `ArmFront`, `LegBack` and `LegFront`, each with an `Art` sprite. It
   stands about 175 tall with its feet at the origin, facing right. Keep
   those names; add other nodes freely.
2. The `Hand` marker on `ArmFront` is where the lead clips on, so the
   `walk` animation should have that arm reaching forward. Animations are
   `walk` and `idle`, as for animals.
3. Paint the body in pure red, with green and blue for shading. The skin
   tone picked replaces red, with a darker shade for green and lighter for
   blue. Draw it bare: clothes are separate.
4. For every limb, export a **full canvas image** (the same size every
   time, feet at the bottom middle; in Photoshop, File > Scripts > Export
   Layers to Files with **Trim Layers off**). The rig decides where each
   sits, so you never position them by hand.

**Clothes, hats and hair:** an item's art goes in
`art/cosmetics/<item>/` (ids in `data/cosmetics.json`, and in
`data/gifts.json` for wearable gifts), one image per limb it covers, named
after the limb: `torso.png`, `head.png`, `arm_back.png`, `arm_front.png`,
`leg_back.png`, `leg_front.png`. A jumper is `torso.png`, `arm_front.png`
and `arm_back.png`; a hat is just `head.png`. Add `_behind` to draw behind
the limb (`torso_behind.png` for a cape), and `_sad` for a version shown
when the character is sad (`head_sad.png`). There's an example in
`art/templates/cosmetics/`.

Hair, and starter items with a `colour` in `cosmetics.json`, are painted in
red, green and blue and take the chosen colour. Wearable gifts show exactly
as drawn. Once the character has a puppet, an item without art isn't shown,
so draw the starter items first (the first in each slot is the default).

---

## Gifts

Save a square picture (256 × 256 or bigger) as `art/gifts/<gift>.png`, e.g.
`art/gifts/dog_common.png`. `.svg` and `.webp` work too. It shows
everywhere the gift appears, on a disc in its rarity's colour. Names,
descriptions and rarities are in `data/gifts.json`.

---

## The home view behind every screen

`art/home/backdrop.tscn` is the forest seen from a hilltop. Open it:

- **Layers**: five pictures, far to near (`Mountains`, `Hills`,
  `ForestFar`, `ForestNear`, `Hilltop`). Paint each in one colour (white is
  easiest) and set its colour with the node's **Modulate**. Each covers the
  screen with its bottom on the screen's bottom, so draw them all on the
  same canvas (1600 × 1000 now). Swap a picture by dragging yours onto the
  node's **Texture**.
- Each layer has **Parallax** (how far it moves as you slide between
  screens), **Drift** (a slow sway, in pixels) and **Night Brightness**
  (below 0 uses the backdrop's own).
- **DaySky** and **NightSky** are full-colour pictures. The night one fades
  in over about 40 minutes round sunset, and out round sunrise.
- **Sun** and **Moon** are their own pictures. They cross the sky with the
  real time of day, setting behind the hills.
- On the `Backdrop` node: **Night Brightness** (how dark the layers get at
  night), **Wash** (how much of the app's background colour lies over it,
  so the screens read on top), **Spare** (extra width for panning),
  **Horizon** and **Climb** (where the sun and moon set, and how high they
  go).

The create account screen looks down at the hilltop; making an account
tilts the view up to the forest and sky. Then the focus orb grows in, the
greeting types itself out, "Tap to focus" rises in, and last the map and
arrows fade in (timings under "Arriving home" in `ui/motion.tres`).

---

## Holidays

The app dresses up on Halloween, at Christmas, at New Year, at Easter and
on your birthday. **When** each one is, and its present, are in
`data/holidays.json`. **How it looks** is `art/holidays/<holiday>/look.tres`
(`halloween`, `christmas`, `new_year`, `easter`, `birthday`). Double-click
it and change it in the Inspector:

| Setting | What it does |
| --- | --- |
| **Hour** | Pins the time of day (0 is midnight, so Halloween is always dark). -1 follows the clock. |
| **Weather** | Pins every walk's weather (`snowy` at Christmas). Empty follows the real weather. |
| **Dead Trees** | Every tree on a walk is bare. |
| **Snow** | Snow on the trees and ground, on walks and on the home view, snow falling behind the screens, and snow piling up along the bottom as you walk. **Snow Pile Minutes** is how long it takes to pile up; **Snow Pile Height** how high it gets (a share of the screen). |
| **Ground Props** | Pictures dotted in the grass beside the path (pumpkins, eggs), picked at random. Drag in as many as you like. **Prop Spacing** and **Prop Height** are in pixels on a screen 720 tall. |
| **Lit Trees** | The share of trees on a walk hung with lights, in the **Light Colours**. |
| **Fireworks** | Fireworks in the sky, behind the screens and on walks, in the **Firework Colours**. |
| **Home Scene** | Decorations on the home view. Open it: a group named after each layer (`Hilltop`, `ForestNear`...) holds sprites laid out on that layer's picture (1600 × 1000), so they move with it. Drag the pumpkins or eggs about, or add your own. |
| **Menu Scene** | Decorations hung over the screens (under popups and walks): the Christmas lights and the birthday bunting along the top. |
| **Backdrop Swaps** | Pictures that replace home view layers while it's on, by layer name (Halloween's dead forests in `art/holidays/halloween/home/`). |
| **Orb Colours** | The focus orb's colours while it's on: its circles drift through these in turn (a rainbow on your birthday, reds and oranges at Halloween). Empty keeps its usual greens and blues. |
| **Hat** | A hat you wear all day whatever you picked (a gift id: `party_hat` on your birthday). The hats in the customise popup are held on it. |

The lights and bunting are **Festoon** nodes: set **Kind** (lights or
bunting), **Swag Width**, **Spacing**, **Bulb** (a bulb's size, or a
flag's width) and **Colours**. Make the node as tall as you want the string
to dip. The fireworks are **Fireworks** nodes (**Bursts**, **Life**,
**Reach**, **Colours**).

The pictures (`pumpkin.svg`, `egg_pink.svg`...) sit beside each look.
Replace one with your own and it shows everywhere it's used.

**Presents and pets.** Opening the app on a holiday gives you its present
(a legendary gift: `gift` in `data/holidays.json`), once a year. Each
holiday also has a pet, unlocked by focusing for 30 minutes on the day:
the animal's `unlock` rule in `data/animals.json`
(`{"holiday": "halloween", "minutes": 30}`). The pets' gifts and the
presents are in `data/gifts.json` (tables `skeleton_dog`, `reindeer`,
`easter_egg`, `birthday_cake` and `holiday`).

**Dates.** `from` and `to` are `"MM-DD"` for whole days or
`"MM-DD HH:MM"` for exact minutes (New Year is `01-01 00:00` to
`01-01 00:05`). Easter moves each year, so it's days either side of Easter
Sunday (`[-2, 1]` is Good Friday to Easter Monday). Your birthday comes
from the date of birth you give when you create your account. If two land
on the same day, the first in the file is how the app looks (your
birthday is first, so it beats every holiday), but each one still gives
its present and counts towards its pet.

---

## The bush your pet dives into

When a walk ends with a gift, your pet dives into a bush and comes back
with it. The bush is `art/walk/bush.tscn`. Until it has sprites inside, it
draws a round leafy placeholder (change its **Greens** and **Highlight** in
the Inspector). Drag your own images onto the `Bush` node to replace it.
Its origin is where it meets the ground; it's drawn for a screen 720 tall.

---

## Sounds

Every sound is listed in **`assets/sounds/sounds.tres`**. Double-click it,
open **Sounds** in the Inspector and click any one:

| Setting | What it does |
| --- | --- |
| **Id** | The sound's name. Don't change it: the app asks for sounds by name. |
| **Stream** | The recording. Drag an audio file (`.wav`, `.ogg` or `.mp3`) here from the FileSystem dock. Empty uses a file named after the sound in `assets/sounds/` (e.g. `level_up.ogg`), and failing that the sound the app makes up for itself. |
| **Volume Db** | Louder (above 0) or quieter (below 0). 6 is about twice as loud. |
| **Pitch** | Higher (above 1) or lower (below 1). |
| **Muted** | Never plays. |

To add a recording: drag the file into `assets/sounds/` in the FileSystem
dock, then onto the sound's **Stream**. Trim any silence at the start:
even 30 ms makes a sound feel late. For a looping ambience, click the file,
open the **Import** dock (next to Scene), tick **Loop** and press
**Reimport**.

Which sound plays when is listed in [sounds/README.md](sounds/README.md).
An animal's sound is its `sound` in `data/animals.json`, and a place's
ambience its `ambience` in `data/biomes.json`.

---

## Animations and timings

The animals' and the character's own movements are their
**AnimationPlayer** animations (see [Animals](#animals)).

Everything else in the app moves through one set of timings in
**`ui/motion.tres`**. Double-click it and change any of these in the
Inspector:

| Group | Setting | What it changes |
| --- | --- | --- |
| Everything | **Speed** | Every animation at once: above 1 is quicker. |
| | **Transition**, **Easing** | The shape of every animation's curve. Sine and In Out are soft and even; Back overshoots a little. |
| Choosing a place | **Place Fade** | One place fading into the next, and the place buttons' highlight sliding across. |
| Setting off on a walk | **Leave Fade** | The choose focus screen's words and buttons fading away once you pick a pet. |
| | **Pet To Path** | Your pet walking over to its place on the path. |
| | **Walk In** | You walking in from the left to join it. |
| | **Lead In** | The lead appearing. |
| | **Set Off Wait** | The pause before you set off together. |
| | **Speed Up** | The scenery getting up to walking speed. |
| | **Drop** | How far the project's name and the time drop as they fade in. |
| | **Type Letter**, **Type Space** | How fast the encouragement types itself out, and the pause between words. |
| | **Quote Every** | How often the encouragement changes, in minutes of focus. |
| Arriving home | **Account Rise** | The view tilting up from the hilltop after making an account. |
| | **Orb Grow** | Then the focus orb growing in from nothing. |
| | **Hint Rise** | How far "Tap to focus" rises as it fades in. |
| | **Home Ui Fade** | Last, the map, the arrows and the home icon fading in. |
| Focus complete | **Glow Radius** | How far the gift's glow reaches. |
| | **Dim** | How much the scenery darkens round your pet. |
| | **Turn** | Your pet turning round to show you the gift. |

If someone turns on Reduce motion in the app's settings, everything runs at
half these times.

---

## Icons

Every icon is an SVG in `assets/icons/`, named `<name>.svg`. Draw on a
**24 × 24** canvas in **one colour** (any colour): the app recolours it to
suit each place it's used. Lines are 2.2 wide with round ends. Keep the
`.svg.import` file beside each icon. The full list of icons and where each
is used is in [icons/README.md](icons/README.md), along with the optional
full-colour medals for achievements.

---

## Place buttons

The buttons for choosing a place use the `place_<place>` icons until you
add `art/places/<place>.png`: square, white on transparent, 128 × 128 or
bigger. The app tints it (green on the chosen place, faded when locked).

---

## App icon and launch screen

In `assets/brand/`:

| File | What it is |
| --- | --- |
| `app_icon.svg` | The app's icon (1024 × 1024). |
| `app_icon_dark.svg` | The icon in the phone's dark mode. |
| `splash.png` | The picture while the app opens. Its background colour is in Project > Project Settings > Application > Boot Splash. |

Replace a file with your own of the same name and size.

---

## Fonts

`ui/fonts/Fraunces.ttf` is used for headings and `ui/fonts/Quicksand.ttf`
for everything else. Replace either with another font file of the same
name (keep its licence file beside it).

---

## Words

Every word on screen is in `data/text.json`, including the greetings on
the home screen and the encouragement during a walk (`quotes`). Change the
text between the quotes; leave the names before the colons and anything in
`{curly brackets}` as they are.

---

## Painting in red, green and blue

Animals, the character's body and hair, and some clothes are painted in
**pure red (#ff0000), green (#00ff00) and blue (#0000ff)**, and the app
swaps those for the right colours as it draws them (the
`art/animal_colours.gdshader` shader does this). Darker paint stays darker,
so you can shade with darker reds, greens and blues. Any other colour is
mixed from its red, green and blue parts, so keep outlines black or grey.

---

## When something doesn't show up

- **The file isn't named exactly right.** Names are the ids from the
  `data/` files, all lower case, with underscores (`dog1`, `dog_common`).
- **Godot hasn't imported it yet.** Click into the editor window after
  adding files; a file only counts once the FileSystem dock shows it.
- **An image has see-through edges trimmed off.** Limbs and clothes need
  the full canvas (Trim Layers off), or they land in the wrong place.
- **A sound is late.** Trim the silence at its start.
- **A whole place shows nothing.** Its scene must keep a `ground` layer,
  and its folder must be named after the place's id.
- **Still stuck?** Run the app from the editor (F5) and read the Output
  panel at the bottom: missing or misnamed files are reported there.
