# Licences

Everything the app ships that someone else made, and what each licence asks
of you. Checked 1 November 2026. Settings, Licences shows the licence texts
in the app (`Legal.licences_text()`), which covers the "include the notice"
part of every licence below.

## Code

| What | Licence | What it asks | Done |
| --- | --- | --- | --- |
| Godot Engine 4.6 | MIT | Ship its copyright notice and licence text | Yes: Settings, Licences, from `Engine.get_license_text()` |
| What Godot is built from (FreeType, HarfBuzz, ICU, mbedTLS, libpng, zlib and more) | MIT, BSD, Apache 2.0, FreeType licence, zlib, and others | The same: notices and licence texts | Yes: Settings, Licences lists every part from `Engine.get_copyright_info()` and every licence text from `Engine.get_license_info()` |
| The app's own GDScript | Yours | Nothing | The repository has no LICENSE file, so it's all rights reserved. Keep it that way for a closed-source app, or add one |

No other code libraries are used (no plugins or addons).

## Fonts

| Font | Licence | What it asks | Done |
| --- | --- | --- | --- |
| Fraunces | SIL Open Font License 1.1 | Ship the licence with the font; don't sell the font on its own | Yes: `ui/fonts/Fraunces-OFL.txt`, exported and shown in Settings, Licences |
| Quicksand | SIL Open Font License 1.1, Reserved Font Name "Quicksand" | As above, and a changed version can't be called Quicksand | Yes, as above; the font is used unchanged |

## Pictures

| What | Who made it | Licence |
| --- | --- | --- |
| Icons (`assets/icons/`) | Drawn for this project | Yours |
| Home backdrop (`art/home/`), scenery, animals, characters and gifts drawn in code | Drawn for this project | Yours |
| App icon and launch screen (`assets/brand/`) | Drawn for this project | Yours |
| Your own art as you add it | You | Yours |

## Sounds

| What | Source | Licence |
| --- | --- | --- |
| The bong, pops, rustle, chime, level-up, splash, wind, rain and thunder | Made in code (`core/synth.gd`) | Yours |
| The 12 recordings in `assets/sounds/*.mp3` (barks, meows, birdsong, water, fire, night, button click, project complete) | Copied from the first version of the app | **Unknown: please check** |

## Online services

| Service | Used for | Terms | Done |
| --- | --- | --- | --- |
| Open-Meteo (open-meteo.com) | The weather, with Local sunrise and weather on | Data under CC BY 4.0: credit "Weather data by Open-Meteo.com". The free API is for non-commercial use only | Credit is in Settings, Licences. **Check commercial use** |
| GeoJS (geojs.io) | The rough location, from the internet address | Free, no key | Named in the privacy policy |

## Open questions for you

1. **Where did the 12 recordings in `assets/sounds/` come from?** If they're
   from a site like Freesound or Pixabay, note each one's licence here. CC BY
   needs a credit line in Settings, Licences; CC BY-NC can't be used in an
   app with a paid Supporter Pack; anything without a clear licence should
   be replaced.
2. **Open-Meteo's free API is non-commercial.** An app with a paid
   Supporter Pack probably counts as commercial. Either take their paid
   plan before release, or move to a free-for-commercial weather service.
3. Add a `LICENSE` file to the repository only if you want others to reuse
   the code. Without one, nobody may.
