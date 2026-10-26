# Art

Everything here is optional. Anything without art keeps its code-drawn
placeholder, so you can add art one animal, gift or layer at a time.

```
art/
  animal_colours.gdshader     maps red/green/blue paint to an animal's colours
  animals/<animal id>/animal.tscn   an animal's rig (and its limb images beside it)
  gifts/<gift id>.png          a gift's picture (.svg and .webp work too)
  character/character.tscn     the player's character rig
  cosmetics/<item id>/         an item's pieces, one image per limb it covers
  scenery/...                  tile scenes for biomes.json layers
  templates/                   working examples to copy
```

## Animals

1. Copy `templates/animal/` to `art/animals/<id>/` (the id is in
   `data/animals.json`, e.g. `art/animals/staffy/`). `sprite_dir` there
   already points at that folder.
2. Open `animal.tscn` in Godot. Replace each limb's image with your own.
   Each limb is its own `Sprite2D` (body, head, tail, four legs). Move a
   limb's pivot by changing its node position, and its image offset.
3. Paint in **pure red, green and blue**. At runtime the shader turns red into
   the animal's first colour in `parts`, green into the second, and blue into
   the third (the colours the player picks when adopting). Darker paint stays
   darker, so shading works. Any other colour is mixed by its channels, so
   keep outlines black or grey.
4. Animate in the `AnimationPlayer`: a looping `walk` (required) and a looping
   `idle` (optional). Feet should rest on the origin (0, 0); the animal faces
   right. The walk speed follows the animal's `walk_speed`.
5. Move the `Neck` marker to where the lead clips on, and the `Mouth` marker
   to where a gift is held. They follow the animation.
6. Size is set by `size` in `animals.json`; you don't need to scale the rig.

Add or remove limbs freely. Only the names `AnimationPlayer`, `Neck` and
`Mouth` matter.

## The character and cosmetics

The character is one rig that every worn item is laid onto, so a jumper's
sleeves swing with the arms and a hat sits on the head as it bobs.

1. Copy `templates/character/` to `art/character/`. Open `character.tscn`.
   It has six limbs (`Torso`, `Head`, `ArmBack`, `ArmFront`, `LegBack`,
   `LegFront`), each with an `Art` sprite. The character is about 175 tall,
   its feet at the origin, facing right. The names matter; add other nodes
   freely. The `Hand` marker on `ArmFront` is where the lead clips on, so
   the `walk` animation should have that arm reaching forward.
2. Paint the body in **pure red** (with green and blue for shading, as for
   animals). The skin tone the player picks replaces red, with a darker
   shade for green and a lighter one for blue. Clothes are separate, so draw
   the body bare. Animations are `walk` and `idle`, as for animals.
3. For every limb, export a **full canvas image** (the same size every time,
   feet at the bottom middle, Trim Layers off in Photoshop). The rig sets
   where each one sits, so you never position them by hand.
4. An item's art goes in `art/cosmetics/<item id>/` (ids are in
   `data/cosmetics.json`, and `data/gifts.json` for wearable gifts), one
   image per limb it covers, named after the limb: `torso.png`, `head.png`,
   `arm_back.png`, `arm_front.png`, `leg_back.png`, `leg_front.png`. A
   jumper is `torso.png`, `arm_front.png` and `arm_back.png`; a hat is just
   `head.png`. Add `_behind` to the name to draw behind the limb's own art
   (a cape, long hair at the back, `torso_behind.png`), and `_sad` to
   replace a piece when the character is sad (`head_sad.png` for a frown).
5. **Colour:** hair is painted red (green and blue for shading) and takes
   the chosen hair tone. Starter items that have a `colour` in
   `cosmetics.json` (a beanie, jeans) are painted the same way and take it.
   Wearable gifts show exactly as drawn, so give them their real colours.
6. While the character has a rig, an item without art isn't shown. Add art
   for the ones players start with first (the first item in each slot is
   the default).

## Gifts

Save a square image (e.g. 256 × 256) as `art/gifts/<gift id>.png`, e.g.
`art/gifts/staffy_common.png`. Ids are in `data/gifts.json`. It shows
everywhere the gift appears, on its rarity-coloured disc.

## Scenery

A layer in `data/biomes.json` can name a scene with `"art"`:

```json
{"kind": "art", "art": "res://art/scenery/forest/pines.tscn", "parallax": 0.3, "y": 0.64, "height": 0.28, "colour": "#456f50", "seed": 13}
```

1. Copy `templates/scenery/tile.tscn` to `art/scenery/<place>/<name>.tscn`.
2. Open it in Godot and drag, add and delete sprites to arrange the tile. The
   scene repeats forever to the right.
3. The origin (0, 0) is the line the layer stands on (its `y` in the data).
   Things grow up from it, so draw upwards (negative y).
4. The red box (`TileBounds`, only visible in the editor) is one tile. Resize
   it to change the tile's width. Keep things inside it, and make the left
   and right edges line up so the repeat has no seam.
5. Draw it for a screen 720 tall; it scales to fit.
6. `kind`, `parallax`, `y`, `front`, `skip` and the lighting all work as before.
   `parallax` is how fast the layer moves against the ground, and `front`
   puts it in front of the walker and pet. The layer is sorted among the walker
   and pet by its `y`, as with drawn layers.

Lighting (day, night and weather) tints art automatically, so paint it in
daytime colours.

For the ground layer, the data's `y` and `height` still decide where the path
is, whether or not it has art.
