# Paws & Progress 2 — Roadmap

> Walk your animals through beautiful scenery while you work. Every project or module gets its own animal; every focus session is a walk; every walk over 10 minutes ends with a gift.

This roadmap rebuilds the original Godot 4.3 prototype (`Paws-And-Progress`) as a shippable product on **iOS, Android, macOS, Windows, Linux and Steam**, then grows it into a social and education platform.

---

## 0. Guiding principles

- **Calm first.** The walk screen is the product. It must look beautiful, run smoothly for hours, and never nag.
- **Offline first.** Everything core works with no account and no signal. Sync is an upgrade, not a requirement.
- **One codebase.** One Godot project exports to every platform; platform-specific bits live in small plugins.
- **Honest time.** Focus time is computed from timestamps, never from a running in-app counter, so backgrounding, sleeping or app suspension can't corrupt stats.
- **Ship small, ship often.** Each phase ends with something real people can use.

---

## 1. What carries over from v1

| v1 feature | v2 plan |
|---|---|
| 12 animals, several based on named real pets, with recolourable parts | Drop the named pets. Core cast of 11 generic animals: 5 dog varieties, 2 cat options, rabbit, snail, bird, bear. Data-driven definitions (JSON/Resource) so new animals need no code |
| Projects with an assigned animal + name | Keep; add colour, icon, optional due date, tags, and an "education module" type |
| Focus walk: parallax scenes (lake, land, logs, rocks, trees, sky, fireflies), day/night | Keep and expand into multiple biomes with seamless procedural chunking |
| Gifts on walks over 10 min (common / rare / epic, 3 per animal) | Expand to **common / rare / epic / legendary**; epic + legendary are wearable |
| Character customisation (hat, hair, face, jumper, neckwear, handwear, walking stick, trousers, skin & hair tones) | Keep slots; cosmetics now come from gifts as well as defaults |
| Completed projects notice board | Becomes a completed projects screen: a panel per project with its animal, time, gifts found and an optional GCSE / A-Level / university grade badge |
| Stats: weekly total, weekly PB, longest focus, daily bar chart, past weeks | Keep; add per-project share, streaks, weekly records, all-time history |
| Cosy room (curtains, fireplace, light levels, ambience) | Replaced by a four-sided layout that fits phones: a central focus screen with gifts, completed projects, profile and stats one swipe away on each side |
| Local JSON save | Replace with versioned local save + optional cloud sync |

---

## 2. Phases

### Phase 1 — Foundations (rebuild the core, single player)
Goal: v1 feature parity on a clean, modern architecture.

- [ ] New Godot 4.x project, mobile renderer, responsive layout for portrait phone, landscape tablet and desktop windows
- [ ] Four-sided swipe navigation round the focus screen, with a minimap; shared UI components and one animation style app-wide
- [ ] Data layer: `Project`, `Animal`, `Gift`, `Cosmetic`, `FocusSession`, `WeekStats` as typed Resources
- [ ] Versioned save file with migrations; import of a v1 `gamedata.save`
- [ ] Session timer based on start timestamps (survives backgrounding, sleep and app kill)
- [ ] Project CRUD + animal assignment + animal recolouring
- [ ] Focus walk scene: modular parallax biome system, animal walk cycles, pause / finish
- [ ] End-of-walk screen with gift roll (pet dives into a bush and brings the gift back)
- [ ] Gift shelf (three favourites, drag and drop) and trade-ins up a rarity
- [ ] Character customisation
- [ ] Completion flow → completed projects panel + grade badge
- [ ] Stats screen (weekly chart, totals, PBs)
- [ ] Settings: sound, ambience, reduce motion, light/dark theme
- [ ] Automated builds for desktop + Android in CI

**Exit criteria:** a v1 user would happily switch.

### Phase 2 — Polish & progression
- [ ] Four rarities with drop table tuned by walk length (e.g. legendary only possible on 45 min+ walks, small pity timer), plus guaranteed minimum rarities shown filling the walk's gift button
- [ ] Epic + legendary gifts equippable as cosmetics on the walker (and optionally on the animal)
- [ ] More places: lakeside, forest, jungle, tundra (snow and wind), desert, beach, moon (done, with placeholder art and the sky, sun and moon following the real clock); then mountains, snowy village, autumn park; weather tied to the real forecast
- [ ] Place unlocks (and new animals) via XP levels: 1 XP a minute plus gift bonuses, rewards set in data
- [ ] Animal bond levels (hours walked with that animal) unlocking extra idle animations / gifts
- [ ] Streaks with gentle "rest day" tokens so a missed day doesn't punish you
- [ ] Break reminders (Pomodoro-style optional mode: animal sits down for a drink)
- [ ] Ambient soundscapes + optional lo-fi music
- [ ] Accessibility: dyslexia-friendly font option, colour-blind safe rarity colours, screen reader labels, reduce motion

### Phase 3 — Platform launch
- [ ] **iOS / iPadOS** App Store release (TestFlight beta first)
- [ ] **Android** Google Play release
- [ ] **Steam** release (Windows, macOS, Linux, Steam Deck verified): achievements, cloud saves, rich presence via GodotSteam
- [ ] **Standalone desktop** builds (itch.io and/or direct download, signed + notarised on macOS)
- [ ] Desktop extras: always-on-top mini walk window, menu bar / tray timer
- [ ] Mobile extras: iOS Live Activity / Dynamic Island + lock screen widget, Android ongoing notification (native plugins)
- [ ] Store assets: trailer, screenshots, privacy policy, age rating, accessibility labels
- [ ] Free download + one-off **Supporter Pack** IAP / Steam DLC (cosmetics, extra biomes, supporter badge); nothing that affects gift odds

### Phase 4 — Accounts, sync & friends
- [ ] Backend (recommended: Supabase — Postgres, auth, row-level security, realtime)
- [ ] Sign in with Apple / Google / Steam / email
- [ ] Cross-device cloud sync (the same walk history on phone and laptop)
- [ ] Friend codes + QR invite + share link
- [ ] Friend profiles: animals, shelf, notice board, this week's stats
- [ ] Weekly leaderboards (friends, resets Monday), weekly records and badges
- [ ] "Walk together": see friends' animals walking alongside yours live during a session
- [ ] Friends see **exact minutes** (weekly totals, per-day bars, records); privacy controls limited to who can friend you, block and report
- [ ] Moderation for usernames and any free text

### Phase 5 — Schools, colleges & universities
- [ ] **Step 1: LMS course import.** Sign in to the institution's LMS (Canvas, Moodle, Blackboard, Brightspace) via OAuth and import enrolled courses as projects
- [ ] **Step 2: LTI 1.3 app.** Institutions install Paws & Progress as an LTI tool so students launch it from the LMS
- [ ] **Step 3: Grades.** Read final grades where the LMS API allows, and auto-complete modules with the same grade badges players can already set by hand
- [ ] Institution admin portal + per-institution leaderboards / study challenges
- [ ] Target audience: **college and above (16+)**. Age gate at sign-up; no under-16 accounts, which keeps COPPA out of scope
- [ ] Compliance: GDPR (UK/EU), FERPA (US), data processing agreements, minimal data retention
- [ ] Pilot with one friendly department or university before wider rollout

> Note: "pulling a transcript" directly from a student record system (SITS, Banner, PeopleSoft) is rarely exposed to third-party apps. The LMS route is far more realistic and gets ~90% of the value.

### Phase 6 — Beyond
- Seasonal events (autumn leaves, winter lights) with limited cosmetics
- Study groups with a shared walk and shared gift
- Desktop focus mode integration (block distracting sites/apps during a walk)
- Calendar / task app integration (Notion, Todoist, Google Calendar)
- Apple Watch / Wear OS mini companion
- Animal adoption charity tie-in (real shelter partnerships)

---

## 3. Technical architecture (proposed)

```
Godot 4.x client (GDScript)
├── core/        data models, save system, session timer, gift roller
├── scenes/      shell + panes (focus, gifts, completed, profile, stats), choose focus, walk, focus complete
├── biomes/      data-driven parallax chunks per biome
├── animals/     animal definitions + sprites + walk cycles
├── platform/    per-platform plugins: Steam, iOS (Live Activities, Game Center, IAP), Android
└── net/         optional sync + friends client

Backend (Phase 4+): Supabase (Postgres + Auth + Edge Functions)
├── users, projects, sessions, gifts, friendships, weekly_stats
├── weekly leaderboard materialised view, reset Monday 00:00 local
└── edge functions for LMS OAuth + grade fetch (Phase 5)
```

Solo-dev notes: keep art pipelines simple (one sprite-sheet layout per animal, shared rig), budget art time per phase, and prefer data-driven content so new animals, gifts and biomes are art drops rather than code changes.

Build & release:
- GitHub Actions: Linux/Windows/Android exports on Ubuntu runners; iOS/macOS exports, signing and notarisation on macOS runners
- Steam upload via `steamcmd` in CI
- Fastlane (or Xcode Cloud) for TestFlight / App Store uploads

---

## 4. Platform requirements checklist

| Platform | Needs |
|---|---|
| iOS | Apple Developer Program (£79 / $99 per year), a Mac (or macOS CI runner) for Xcode builds, privacy nutrition labels |
| Android | Google Play developer account (one-off $25), signing key |
| Steam | Steamworks fee ($100 per app, recoupable), GodotSteam plugin |
| macOS standalone | Developer ID certificate + notarisation |
| Windows standalone | Code-signing certificate (optional but avoids SmartScreen warnings) |

---

## 5. Decisions so far

| Topic | Decision |
|---|---|
| Engine | Godot 4.x for every platform |
| Business model | Free + one-off Supporter Pack |
| Animal cast | 5 dog varieties, 2 cats, rabbit, snail, bird, bear; no named real pets |
| Hardware | Joe has a Mac, so iOS/macOS builds and signing can run locally as well as in CI |
| Friends' stats | Exact minutes are visible to friends |
| Education audience | College and above (16+) |
| Team | Solo project; Joe does all art and sound |

### Still open
- Minimum focus time for a gift: keep 10 minutes everywhere?
- Exact Supporter Pack contents and price
- Which LMS to target first for the education pilot

---

## 6. Milestone summary

| Milestone | Outcome |
|---|---|
| M1 | Phase 1 parity build on desktop + Android |
| M2 | Phase 2 polish, iOS TestFlight beta |
| M3 | Public launch: App Store, Google Play, Steam, standalone |
| M4 | Accounts, sync, friends, leaderboards |
| M5 | First university pilot |
