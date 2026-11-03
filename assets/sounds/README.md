# Sounds

Every sound the app makes, and the file name that replaces it.

Drop a file named `<name>.wav`, `<name>.ogg` or `<name>.mp3` into this folder.
The app plays it instead of the placeholder. If more than one type exists, `.wav` wins, then `.ogg`, then `.mp3`.
Sounds marked "made in code" are generated until you add a file.
Animal sounds with no file are silent.

Tip: trim any silence at the start of a file. Even 30ms of silence makes a sound feel late.

## Taps and screens

| File name | When it plays | Now |
|---|---|---|
| `button_click` | Any button goes down | file |
| `orb_tap` | Tapping the focus orb to choose a focus | made in code (bong) |
| `map_open` | The minimap opens | made in code (pop) |
| `locked` | Tapping a locked place or animal (it wiggles) | made in code (pop) |
| `level_up` | The level bar reaches a new level | made in code |

## Walking

| File name | When it plays | Now |
|---|---|---|
| `first_gift` | The gift button reaches its first gift (10 minutes) | made in code (ding) |
| `gift_odds_up` | The gift button's odds go up a rarity (rises in pitch) | made in code (pop) |
| `bush_rustle` | Your pet dives into a bush for a gift | made in code (rustle) |
| `gift_found` | Your pet comes back out with a gift | made in code (chime) |
| `walk_end` | The walk ends | made in code (bong) |
| `thunder` | Lightning during a storm | made in code |

## Ending a walk

| File name | When it plays | Now |
|---|---|---|
| `walk_gifts` | The end-of-walk screen shows what you found | made in code (chime) |
| `gift_pick_up` | You pick up a gift to throw | made in code (pop) |
| `gift_throw` | You throw it | made in code (whoosh) |
| `gift_splash` | It lands in water | made in code (splash) |
| `gift_land` | It lands on the ground | made in code (pop) |

## Gifts and projects

| File name | When it plays | Now |
|---|---|---|
| `trade_new_gift` | A trade-in brings a new gift | made in code (chime) |
| `trade_not_yet` | Clicking a gift without enough to trade | made in code (pop) |
| `shelf_pick_up` | Picking a gift up in the shelf editor | made in code (pop) |
| `shelf_place` | Dropping it onto the shelf | made in code (pop) |
| `shelf_remove` | Dragging it off the shelf | made in code (pop) |
| `project_complete` | Swiping a project to complete it | file |

## Ambience (loops while you walk or choose)

| File name | Where | Now |
|---|---|---|
| `water_ambience` | Lake and beach by day | file |
| `daytime_birds` | Forest, farm, jungle and others by day | file |
| `night_ambience` | Lake and day places after dark | file |
| `wind_ambience` | Desert, tundra and hazy weather | made in code |
| `rain_ambience` | Any place while it rains | made in code |

The Moon has no ambience.

`fire_crackling.mp3` is in the folder but nothing plays it yet.

## Animals

Each animal plays its sound when it brings back a gift, fetches a thrown one, or is adopted.

| File name | Animals | Now |
|---|---|---|
| `dog_bark` | Dog 1, Dog 2, Dog 3 | file |
| `cat_meow` | Cat 1, Cat 2 | file |
| `rabbit_squeak` | Rabbit | file |
| `bird_tweet` | Bird | file |
| `snail_sludge` | Snail | file |
| `bear_roar` | Bear | file |
| `sheep_baa` | Sheep | silent |
| `pig_oink` | Pig | silent |
| `tortoise_munch` | Tortoise | silent |
| `frog_croak` | Frog | silent |
| `fox_yip` | Fox | silent |
| `parakeet_chirp` | Parakeet | silent |
| `spider_skitter` | Spider | silent |
| `hyrax_squeak` | Rock Hyrax | silent |
| `lizard_chirp` | Lizard | silent |
| `snake_hiss` | Snake | silent |
| `monkey_ooh` | Monkey | silent |
| `gorilla_grunt` | Gorilla | silent |
| `tiger_roar` | Tiger | silent |
| `giraffe_hum` | Giraffe | silent |
| `elephant_trumpet` | Elephant | silent |
| `rhino_snort` | Rhino | silent |
| `leopard_growl` | Leopard | silent |
| `lion_roar` | Lion | silent |
| `eagle_screech` | Eagle | silent |
| `red_panda_squeak` | Red Panda | silent |

Change which sound an animal uses with its `sound` field in `data/animals.json`.
