# Paws & Progress

Walk your animals through beautiful scenery while you work. Every project or
course module gets its own animal, every focus session is a walk, and every
walk over 10 minutes ends with a gift.

This is the v2 rebuild in **Godot 4.5** (GDScript), targeting iOS, Android,
macOS, Windows, Linux and Steam from one project. See [ROADMAP.md](ROADMAP.md).

## Running it

1. Install Godot 4.5 (standard build, not .NET).
2. In the project manager, **Import** and pick this folder's `project.godot`.
3. Press **F5**. The window can be resized: under 900px wide it switches to the
   phone layout with a bottom tab bar.

On first launch on desktop, a save from the original app
(`…/app_userdata/Paws-And-Progress/gamedata.save`) is imported automatically.

## Tests

```sh
godot --headless --path . --import                # once, builds the class cache
godot --headless --path . -s tests/run_tests.gd   # unit tests
godot --headless --path . -s tests/smoke.gd       # opens every screen with sample data
```

CI runs all three on every push (`.github/workflows/ci.yml`).

## Layout

```
core/            game logic, no UI
  app.gd           autoload "App": state, saving, walk lifecycle, navigation
  content.gd       autoload "Content": loads data/*.json
  game_state.gd    everything that's saved
  save_system.gd   versioned JSON save, migrations, backup, v1 import
  session_clock.gd timestamp-based focus timer
  gift_roller.gd   gift odds and pity timer
  stats.gd         weekly totals, records, streaks (from the session log)
  models/          ProjectData, FocusSession resources
data/            all content: animals, gifts, drop table, biomes
scenes/          one folder per screen (cabin, walks, editor, walk, end of walk,
                 shelf, wardrobe, noticeboard, stats); main.gd is the app shell
ui/              palette, theme, fonts (Fredoka + Nunito, OFL) and UI builders
tests/           headless unit tests and the smoke run
```

## Adding content (no code needed)

- **Animal:** add an entry to `data/animals.json` and its four gifts to
  `data/gifts.json` (one per rarity; epic and legendary need a `slot`).
- **Gift odds:** edit `data/drop_table.json`.
- **Biome:** add a stack of layers to `data/biomes.json`.

## Art status

All art is placeholder, drawn in code, so the game runs before any sprites
exist:

- Animals: `scenes/walk/animal_view.gd` draws each animal from its recolourable
  parts. Real art goes in `animal.sprite_dir` (e.g. `res://animals/staffy/`);
  swap the drawing for a sprite rig with the same properties.
- Walker: `scenes/walk/walker_view.gd`.
- Scenery: `scenes/walk/scenery.gd` draws each biome layer from noise.
- Cabin: the home screen's dark panel is where the cabin illustration goes.

## Key decisions

- **Honest time.** Walk length is always `now - start - paused`, from saved
  timestamps, so backgrounding, sleep or a killed app can't corrupt it. A walk
  left running is capped at 12 hours.
- **Stats from the log.** Every finished walk is stored; weekly totals, best
  week and streaks are computed from it, never kept as running counters.
- **Saves** are written to a temp file and swapped in, with the previous save
  kept as `.bak` and used if the main file is ever damaged.
