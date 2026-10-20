# Paws & Progress

Walk your animals through beautiful scenery while you work. Every project or
course module gets its own animal, every focus session is a walk, and every
walk over 10 minutes ends with a gift.

This is the v2 rebuild in **Godot 4.5** (GDScript), targeting iOS, Android,
macOS, Windows, Linux and Steam from one project. See [ROADMAP.md](ROADMAP.md).

<p>
  <img src="docs/screenshots/focus-phone.png" width="200" alt="The focus screen">
  <img src="docs/screenshots/choose-focus-phone.png" width="200" alt="Choosing a pet and a place to walk">
  <img src="docs/screenshots/walk-phone.png" width="200" alt="A walk on the beach, with the gift button filling up">
  <img src="docs/screenshots/focus-complete-phone.png" width="200" alt="Focus complete: the gift and the XP bar">
</p>

<img src="docs/screenshots/places.png" width="820" alt="The seven places at midday: lakeside, forest, jungle, tundra, desert, beach and the moon">

<p>
  <img src="docs/screenshots/day-cycle.png" width="600" alt="The lakeside through a day: dawn, morning, midday with the sun high, sunset, dusk and night with the moon and stars">
  <img src="docs/screenshots/walk-jungle-phone.png" width="160" alt="A jungle walk, with leaves and vines passing in front">
  <img src="docs/screenshots/walk-night-phone.png" width="160" alt="A walk at night under the moon">
</p>

<p>
  <img src="docs/screenshots/weather.png" width="600" alt="Weather at the lakeside: sun and cloud, cloud, rain and a storm, then snow in the forest and a blizzard in the tundra">
  <img src="docs/screenshots/focus-ended-phone.png" width="160" alt="Focus ended: the walker and pet hang their heads after the app was closed mid-walk">
</p>

## How it's laid out

The app is five screens arranged like a plus sign. Swipe between them, or use
the arrow keys on a keyboard (Esc comes back to the middle). The little map at
the bottom shows where you are:

```
                 Profile
                    ↑
    Gifts   ←   Focus orb   →   Completed
                    ↓
                  Stats
```

- **Focus** (middle): a greeting (from a long list in `data/greetings.json`)
  above the orb (it grows under the pointer), and the sun/moon switch for dark
  mode. Tap the orb and the choose focus screen grows out of it, set in the
  place you'll walk (holding still, with the place's growth in front of your
  pets): pick the place from the row at the top (in the order they unlock),
  with the project and the pet's name under it. Swipe through your pets (each
  one's kind and time focused is under it), tap one to start a walk, adopt a
  new one with the + (what it's for, the pet's name, its animal and three
  colours; a locked animal hides the colours), or complete or delete one.
  Debug builds (running from the editor) also show a debug bar in the top
  left: a switch that unlocks every animal and place, and a weather picker.
- **Gifts** (left): a shelf for your three favourites (press and hold a gift to
  drag it up), every gift you've found (filter by rarity, A–Z or animal; pick
  the same one again to reverse it), and trade-ins (10 commons for a rare,
  5 rares for an epic, 3 epics for a legendary).
- **Completed** (right): a panel per finished project; tap one to give it a
  GCSE, A-Level or university grade badge.
- **Profile** (up): your character (tap to customise) with your level along
  the bottom (tap it for every reward), account details, and the settings
  behind the gear in the top left.
- **Stats** (down): this week's focus split by project, past weeks, your
  streak (one rest day allowed after three days in a row) and the friends
  leaderboard.

On a walk, the button in the corner shows what gift you've earned: grey, then
green at 10 minutes, then filling with blue, purple and gold as rarer gifts
become guaranteed. When you finish, your pet dives into a bush and comes back
with the gift, the camera zooms in, and the XP you earned pours into your level
bar.

**Levels.** Every minute focused is 1 XP, plus a bonus for the walk's gift.
Levelling up unlocks new animals and places (lakeside, forest, jungle, tundra,
desert, beach and the moon), all set in `data/levels.json`. Locked ones are
shown greyed out with a padlock and the level they open at. Like the stats,
XP is worked out from the walk log, never kept as a running total.

**Real time.** The places follow the clock. The sky gets lighter until
midday and darker after it; the sun comes up from behind the hills, crosses
the sky and sets, and then the moon does the same overnight. Stars and
fireflies come out at dusk, and the birdsong gives way to the night chorus.
The light at each hour is set in `data/biomes.json` (`day_cycle`) and blended
in between (`core/day_cycle.gd`). In the jungle, big leaves, hanging vines and
tall plants keep passing in front of you and your pet; in the forest, now and
then.

**Weather.** Once you allow it (the app asks once; it's in settings too),
the sunrise and sunset are the real ones where you are (worked out on the
device, `core/sun_times.gd`), and the real weather comes along on your walks,
checked every half hour (`core/outdoors.gd`). Each place shows it its own way
(`data/biomes.json`): sun and cloud, cloud, rain, storms with lightning and
thunder, and snow; in the tundra rain falls as snow and a storm is a blizzard,
it never rains or snows in the desert, the jungle doesn't get snow, and the
moon has no weather at all. Your rough location comes from your internet
connection (get.geojs.io) and the weather from Open-Meteo; nothing else is
sent anywhere.

**Closing the app ends your walk.** Next time you open it, a focus ended screen
shows you and your pet with your heads hung. The time up to when you closed it
still counts, but there's no gift.

**Easter egg.** On the focus complete screen, press and hold the gift to take
it, then flick it. Your pet will fetch it, wading in if it lands in the water.

## Running it

1. Install Godot 4.5 (standard build, not .NET).
2. In the project manager, **Import** and pick this folder's `project.godot`.
3. Press **F5**. Resize the window narrow and tall to see the phone layout.

On first launch on desktop, a save from the original app
(`…/app_userdata/Paws-And-Progress/gamedata.save`) is imported automatically.

## Tests

```sh
godot --headless --path . --import                # once, builds the class cache
godot --headless --path . -s tests/run_tests.gd   # unit tests
godot --headless --path . -s tests/smoke.gd       # drives the whole app with sample data
```

The smoke run draws every place, swipes between panes, drags a gift onto the
shelf, sorts and trades gifts, opens every popup, picks a place (and tries a
locked one), adopts a pet, walks for "50 minutes" through to the gift and the
XP bar, throws the gift for the pet to fetch, and switches to dark mode and
back.
CI runs all three on every push (`.github/workflows/ci.yml`). With a display,
`-s tests/smoke.gd -- --shots=<dir>` saves a screenshot of each step.

## Layout

```
core/            game logic, no UI
  app.gd           autoload "App": state, saving, walks, trades, navigation
  content.gd       autoload "Content": loads data/*.json
  outdoors.gd      autoload "Outdoors": location (with permission), weather
  day_cycle.gd     the sky and light at any hour
  sun_times.gd     sunrise and sunset anywhere, worked out on the device
  weather.gd       weather kinds, and how each place shows them
  audio.gd         autoload "Audio": sounds and ambience
  synth.gd         placeholder sounds made in code (bong, pops, rain, thunder)
  game_state.gd    everything that's saved
  save_system.gd   versioned JSON save, migrations, backup, v1 import
  session_clock.gd timestamp-based focus timer
  gift_roller.gd   gift odds, guaranteed rarities, pity timer, trade-ins
  levels.gd        XP from the walk log, levels, and what each one unlocks
  stats.gd         weekly totals, records, streaks (from the session log)
  models/          ProjectData, FocusSession resources
data/            all content: animals, gifts, drop table, places (biomes),
                 levels, cosmetics, grades, walk quotes, home greetings
scenes/
  main.gd          the app shell: panes, swiping, minimap, flows, popups
  panes/           focus, gifts, completed, profile, stats (and their base, Pane)
  choose_focus/    choosing and adopting pets
  walk/            the walk, its chunked scenery, focus complete, focus ended
  customise/       the character popup
ui/
  ui.gd            palette, type, theme and builders every screen uses
  motion.gd        every animation: one ease-in-out tween style and timings
  modal.gd         popups, confirmations, prompts, colour picker
  components/      orb, minimap, carousel, gift tile, gift button, project
                   panel, character and animal drawings, ...
tests/           headless unit tests and the smoke run
```

## Consistent by construction

- **Look:** screens never style things themselves. Colours, type, buttons,
  cards, tags, badges and portraits all come from `ui/ui.gd`, so a change there
  shows up everywhere. Its palette has a light and a dark set; switching
  rebuilds what's on screen under a fading snapshot of the old colours.
- **Motion:** every animation goes through `ui/motion.gd`, which uses one
  ease-in-out curve and a few shared durations (and halves them, without
  bounces, when "Reduce motion" is on).
- **Popups:** every popup is a `Modal`, so they all open, dim, close and scroll
  the same way.

## Adding content (no code needed)

- **Animal:** add an entry to `data/animals.json` (with its `dive`) and its four
  gifts to `data/gifts.json` (one per rarity; epic and legendary need a `slot`
  and `style`).
- **Gift odds and guarantees:** edit `data/drop_table.json`.
- **Trade-in rates:** `trade_in` on each rarity in `data/gifts.json`.
- **Clothes:** `data/cosmetics.json`.
- **Grades:** `data/grades.json`.
- **Walk quotes:** `data/quotes.json`.
- **Place:** add a stack of layers to `data/biomes.json` (and an icon), and
  give it a level in `data/levels.json`.
- **Level rewards and XP:** `data/levels.json`.
- **Home greetings:** `data/greetings.json`.

## Art and sound status

All art is placeholder, drawn in code, so the game runs before any sprites
exist:

- Animals: `ui/components/animal_view.gd` draws each animal from its
  recolourable parts. Real art goes in `animal.sprite_dir` (e.g.
  `res://animals/staffy/`); swap the drawing for a sprite rig with the same
  properties.
- Character: `ui/components/character_view.gd`, one look per cosmetic `style`.
- Gifts: `ui/components/gift_art.gd` (every screen showing a gift uses it).
- Scenery: `scenes/walk/scenery.gd` draws each place's layers in chunks,
  the sun and moon, the growth in front of the walker, and the weather
  (clouds, rain, lightning, snow, blizzards, the tundra's wind, stars,
  fireflies). The light tints each layer through its node, so the clock
  moving on costs no redrawing.
- Sounds: the bong, pops, rustle, chime, level-up, splash, wind, rain and
  thunder are generated by `core/synth.gd`.
  Drop an `.mp3` with the same name into `assets/sounds/` and it's used instead.

## Key decisions

- **Honest time.** Walk length is always `now - start - paused`, from saved
  timestamps, so backgrounding or sleep can't corrupt it. While you walk, the
  app notes every 30 seconds that it's still open; if it's closed or killed
  mid-walk, the walk ends at the last of those (and never runs past 12 hours).
- **Stats from the log.** Every finished walk is stored; weekly totals, best
  week and streaks are computed from it, never kept as running counters.
- **Saves** are written to a temp file and swapped in, with the previous save
  kept as `.bak` and used if the main file is ever damaged.
- **Light on battery.** Panes are built once and only redrawn when something
  changes; the orb stops when it's off screen; walk scenery is drawn once per
  chunk; nothing is drawn at all while the app is minimised or backgrounded.
