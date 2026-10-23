class_name Cursor
extends Node
## The pointer over anything you can tap is a hand ready to grab. Every
## button gets it as it's made; other tappable things (the orb, gift tiles,
## the map) ask for it with HOVER, and Press gives it to whatever it makes
## tappable. The app shell adds one of these.

const HOVER := Control.CURSOR_CAN_DROP


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		_on_added(n)


static func _on_added(n: Node) -> void:
	if n is BaseButton and (n as Control).mouse_default_cursor_shape == Control.CURSOR_ARROW:
		# Deferred: a node can be added while its parent is still being set up.
		n.set_deferred("mouse_default_cursor_shape", HOVER)
