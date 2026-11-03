# Icons

Every icon in the app is an SVG file here, named `<name>.svg`. Edit one, or
swap it for your own, and the app picks it up next time it runs.

## Drawing an icon

- Draw on a **24 x 24** canvas (keep `viewBox="0 0 24 24"`).
- Use **one colour**, any colour. The app recolours it to fit each place
  it's used (white on a green button, grey when locked, and so on), keeping
  only the shape and its soft edges.
- Lines are 2.2 wide with round ends. A few buttons ask for bolder lines.
  Those swap `stroke-width="2.2"` for their own width, so keep that exact
  text on lines that should follow them.
- Leave a little room at the edges, like the icons already here.
- Keep the `.svg.import` file next to each icon. It tells Godot to ship the
  file as it is (importer `keep`), so the app can read and recolour it.

## Full-colour pictures (drawn as they are)

These are optional. Without them the app uses the one-colour icon.

| File | Shows |
| --- | --- |
| `achievements/<achievement id>.svg` | An hours or gifts achievement's medal, instead of its icon. It's faded until earned. Ids are in `data/achievements.json` (hours) and `all_gifts`. |
| `art/places/<place id>.png` (in `art/`) | A place's button picture, white on transparent. See `assets/README.md`. |

## The icons

| Icon | Where it's used |
| --- | --- |
| `back` | Back buttons in flows (finishing a walk). |
| `bin` | Delete: projects, accounts, swipe-left on a project. |
| `calendar` | The date on the Projects screen. |
| `check` | Ticks: done buttons, complete swipe, chosen swatches, the current pet. |
| `clipboard` | The Projects tile on the map. |
| `clock` | Time focused: walks, projects, accounts, hours achievements. |
| `close` | Every X (close) button. |
| `dot` | Small dots in the stats key. |
| `edit` | The pencils: customise your character, edit your name and school. |
| `flame` | Your streak on the Stats screen. |
| `gear` | Settings. |
| `gift` | Gifts: the map tile, gifts found on a walk, the all-gifts achievement. |
| `home` | The Home (focus) tile on the map, and back home after a walk. |
| `hourglass` | Ongoing projects, and the swipe to put a project back. |
| `lock` | Locked places, animals and rewards. |
| `moon` | The moon in the walk's sky. |
| `mute` | Sound off during a walk. |
| `pause` | Pause a walk. |
| `paw` | Pets, the walking badge, the Pets tile on the map, the create account screen. |
| `paw_add` | Adopt a new pet. |
| `play` | Carry on a paused walk. |
| `plus` | Add: new project, custom colour, empty shelf spots. |
| `shelf` | The gift shelf. |
| `shield` | Your best week on the Stats screen. |
| `sort_down` | Dropdown arrows, and sorting from high to low. |
| `sort_up` | Sorting from low to high. |
| `sound` | Sound on during a walk. |
| `star` | Grades and favourites. |
| `stats` | The Stats tile on the map. |
| `sun` | The sun in the walk's sky. |
| `trophy` | Achievements and the leaderboard. |
| `user` | The Profile tile on the map. |
| `walk` | Start a walk. |
| `place_beach` | The Beach button, until there's `art/places/beach.png`. |
| `place_blossom` | The Blossom button. |
| `place_city` | The City button. |
| `place_desert` | The Desert button. |
| `place_farm` | The Farm button. |
| `place_forest` | The Forest button. |
| `place_jungle` | The Jungle button. |
| `place_lake` | The Lake button. |
| `place_moon` | The Moon button. |
| `place_safari` | The Safari button. |
| `place_tundra` | The Tundra button. |
