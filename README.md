# Paws & Progress

Walk your animals through beautiful scenery while you work. Every project or
course module gets its own animal, every focus session is a walk, and every
walk over 10 minutes ends with a gift.

This is the v2 rebuild in **Godot 4.5** (GDScript), targeting iOS, Android,
macOS, Windows, Linux and Steam from one project. See [ROADMAP.md](ROADMAP.md).

<p>
  <img src="docs/screenshots/focus-phone.png" width="200" alt="The focus screen">
  <img src="docs/screenshots/choose-focus-phone.png" width="200" alt="Choosing a pet to focus with">
  <img src="docs/screenshots/walk-phone.png" width="200" alt="A walk, with the gift button filling up">
  <img src="docs/screenshots/focus-complete-phone.png" width="200" alt="Focus complete, with the gift">
</p>

## How it's laid out

The app is five screens arranged like a plus sign. Swipe between them (or use
the arrow keys, or tap the little map at the bottom):

```
                 Profile
                    ↑
    Gifts   ←   Focus orb   →   Completed
                    ↓
                  Stats
```

- **Focus** (middle): the orb. Tap it and the choose focus screen grows out of
  it: swipe through your pets, tap one to start a walk, adopt a new one with
  the + (name it, pick an animal and its three colours), or complete or
  delete one.
- **Gifts** (left): a shelf for your three favourites (press and hold a gift to
  drag it up), every gift you've found, and trade-ins (10 commons for a rare,
  5 rares for an epic, 3 epics for a legendary).
- **Completed** (right): a panel per finished project; tap one to give it a
  GCSE, A-Level or university grade badge.
- **Profile** (up): your character (tap to customise), account details and
  settings.
- **Stats** (down): this week's focus split by project, past weeks, your
  streak (one rest day allowed after three days in a row) and the friends
  leaderboard.

On a walk, the button in the corner shows what gift you've earned: grey, then
green at 10 minutes, then filling with blue, purple and gold as rarer gifts
become guaranteed. When you finish, your pet dives into a bush and comes back
with the gift.

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

The smoke run swipes between panes, drags a gift onto the shelf, trades one in,
opens every popup, adopts a pet and walks for "50 minutes" through to the gift.
CI runs all three on every push (`.github/workflows/ci.yml`). With a display,
`-s tests/smoke.gd -- --shots=<dir>` saves a screenshot of each step.

## Layout

```
core/            game logic, no UI
  app.gd           autoload "App": state, saving, walks, trades, navigation
  content.gd       autoload "Content": loads data/*.json
  audio.gd         autoload "Audio": sounds and ambience
  synth.gd         placeholder sounds made in code (bong, pops, rustle, chime)
  game_state.gd    everything that's saved
  save_system.gd   versioned JSON save, migrations, backup, v1 import
  session_clock.gd timestamp-based focus timer
  gift_roller.gd   gift odds, guaranteed rarities, pity timer, trade-ins
  stats.gd         weekly totals, records, streaks (from the session log)
  models/          ProjectData, FocusSession resources
data/            all content: animals, gifts, drop table, biomes, cosmetics,
                 grades, quotes
scenes/
  main.gd          the app shell: panes, swiping, minimap, flows, popups
  panes/           focus, gifts, completed, profile, stats (and their base, Pane)
  choose_focus/    choosing and adopting pets
  walk/            the walk, its chunked scenery, and focus complete
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
  shows up everywhere.
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
- **Biome:** add a stack of layers to `data/biomes.json`.

## Art and sound status

All art is placeholder, drawn in code, so the game runs before any sprites
exist:

- Animals: `ui/components/animal_view.gd` draws each animal from its
  recolourable parts. Real art goes in `animal.sprite_dir` (e.g.
  `res://animals/staffy/`); swap the drawing for a sprite rig with the same
  properties.
- Character: `ui/components/character_view.gd`, one look per cosmetic `style`.
- Gifts: `ui/components/gift_art.gd` (every screen showing a gift uses it).
- Scenery: `scenes/walk/scenery.gd` draws each biome layer in chunks.
- Sounds: the bong, pops, rustle and chime are generated by `core/synth.gd`.
  Drop an `.mp3` with the same name into `assets/sounds/` and it's used instead.

## Key decisions

- **Honest time.** Walk length is always `now - start - paused`, from saved
  timestamps, so backgrounding, sleep or a killed app can't corrupt it. A walk
  left running is capped at 12 hours.
- **Stats from the log.** Every finished walk is stored; weekly totals, best
  week and streaks are computed from it, never kept as running counters.
- **Saves** are written to a temp file and swapped in, with the previous save
  kept as `.bak` and used if the main file is ever damaged.
- **Light on battery.** Panes are built once and only redrawn when something
  changes; the orb stops when it's off screen; walk scenery is drawn once per
  chunk; nothing is drawn at all while the app is minimised or backgrounded.
