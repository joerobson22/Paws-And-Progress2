class_name Motion
extends RefCounted
## Every animation in the app goes through here, so everything moves the same
## way: a tween that eases in and out. Change the curve or the timings here
## and the whole app follows.

const TRANS := Tween.TRANS_SINE
const EASE := Tween.EASE_IN_OUT

## Durations in seconds.
const FAST := 0.18
const NORMAL := 0.34
const SLOW := 0.6


## True when the player asked for less motion: animations run quicker and
## skip their bounces.
static func reduced() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var app: Node = tree.root.get_node_or_null("App") if tree and tree.root else null
	return app != null and app.state != null and bool(app.state.settings.get("reduce_motion", false))


## How long an animation of `seconds` should really take.
static func time(seconds: float) -> float:
	return seconds * (0.5 if reduced() else 1.0)


## A tween bound to `node` with the app's curve. Starting another with the
## same `key` on the same node stops the old one, so animations never fight.
static func tween(node: Node, key: String = "") -> Tween:
	var meta := ""
	if key != "":
		meta = "_motion_" + key.replace(":", "_").replace("/", "_")
		if node.has_meta(meta):
			var old = node.get_meta(meta)
			if old is Tween and old.is_valid():
				old.kill()
	var t := node.create_tween().set_trans(TRANS).set_ease(EASE)
	if meta != "":
		node.set_meta(meta, t)
	return t


## Animates one property of `node` to `value`.
static func to(node: Node, property: String, value: Variant, seconds: float = NORMAL) -> Tween:
	var t := tween(node, property)
	t.tween_property(node, property, value, time(seconds))
	return t


## Animates a value through `setter` (a Callable taking one argument).
static func method(node: Node, key: String, setter: Callable, from: Variant, value: Variant, seconds: float = NORMAL) -> Tween:
	var t := tween(node, key)
	t.tween_method(setter, from, value, time(seconds))
	return t


static func fade(item: CanvasItem, alpha: float, seconds: float = NORMAL) -> Tween:
	return to(item, "modulate:a", alpha, seconds)


## Fades and slides a control in from `offset` below where it sits.
static func enter(control: Control, delay: float = 0.0, offset: float = 16.0, seconds: float = NORMAL) -> Tween:
	var rest := control.position
	control.modulate.a = 0.0
	control.position = rest + Vector2(0, offset)
	var t := tween(control, "enter")
	t.set_parallel(true)
	t.tween_property(control, "modulate:a", 1.0, time(seconds)).set_delay(time(delay))
	t.tween_property(control, "position", rest, time(seconds)).set_delay(time(delay))
	return t


## A quick swell and settle, for something that just changed state.
static func pop(item: CanvasItem, amount: float = 0.18, seconds: float = 0.38) -> Tween:
	if item is Control:
		(item as Control).pivot_offset = (item as Control).size * 0.5
	var rest: Vector2 = item.get("scale")
	var t := tween(item, "scale")
	if reduced():
		t.tween_property(item, "scale", rest, 0.01)
		return t
	t.tween_property(item, "scale", rest * (1.0 + amount), seconds * 0.45)
	t.tween_property(item, "scale", rest, seconds * 0.55)
	return t


## A side-to-side shake, for "not yet" (e.g. a name that's still empty).
static func shake(control: Control, distance: float = 10.0) -> Tween:
	var rest := control.position
	var t := tween(control, "shake")
	for i in 4:
		var dx := distance * (1.0 - i * 0.22) * (1.0 if i % 2 == 0 else -1.0)
		t.tween_property(control, "position", rest + Vector2(dx, 0), 0.06)
	t.tween_property(control, "position", rest, 0.06)
	return t


## Repeats a gentle up-and-down drift until the node leaves the tree.
static func float_loop(item: CanvasItem, height: float = 6.0, seconds: float = 1.6) -> Tween:
	var rest: Vector2 = item.get("position")
	var t := tween(item, "float")
	t.set_loops()
	t.tween_property(item, "position", rest - Vector2(0, height), seconds * 0.5)
	t.tween_property(item, "position", rest, seconds * 0.5)
	return t
