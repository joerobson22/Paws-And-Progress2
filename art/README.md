# Art

Everything here is optional. Anything without art keeps its code-drawn
placeholder, so you can add art one animal, gift or layer at a time.

```
art/
  animal_colours.gdshader     maps red/green/blue paint to an animal's colours
  animals/<animal id>/animal.tscn   an animal's rig (and its limb images beside it)
  gifts/<gift id>.png          a gift's picture (.svg and .webp work too)
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
