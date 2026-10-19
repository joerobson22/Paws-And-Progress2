extends Node
## Autoload "Audio": button clicks, one-off sounds and the looping ambience,
## all following the sound and ambience settings.

const SOUND_DIR := "res://assets/sounds/"
## Ambience per place; the walk picks by biome and time of day.
const AMBIENCE := {
	"cabin": "fire_crackling",
	"lake": "water_ambience",
	"day": "daytime_birds",
	"night": "night_ambience",
}

var _sfx := AudioStreamPlayer.new()
var _ambience := AudioStreamPlayer.new()
var _ambience_name := ""


func _ready() -> void:
	add_child(_sfx)
	add_child(_ambience)
	_ambience.volume_db = -10.0
	_ambience.finished.connect(func(): _ambience.play())
	# Every button in the app clicks, without each screen wiring it up.
	get_tree().node_added.connect(_on_node_added)


func play(sound: String) -> void:
	if not App.state.settings.get("sound", true):
		return
	var stream := _stream(sound)
	if stream:
		_sfx.stream = stream
		_sfx.play()


## Starts (or keeps) a looping ambience, or stops it with "".
func ambience(name: String) -> void:
	if not App.state.settings.get("ambience", true):
		name = ""
	if name == _ambience_name:
		return
	_ambience_name = name
	_ambience.stop()
	if name == "":
		return
	var stream := _stream(AMBIENCE.get(name, name))
	if stream:
		_ambience.stream = stream
		_ambience.play()


## Re-applies the settings after they change (e.g. ambience switched off).
func refresh(current_ambience: String) -> void:
	_ambience_name = "-"
	ambience(current_ambience)


func _stream(sound: String) -> AudioStream:
	var path := SOUND_DIR + sound + ".mp3"
	return load(path) if ResourceLoader.exists(path) else null


func _on_node_added(node: Node) -> void:
	# Nodes are re-added when the shell rebuilds, so connect only once.
	if node is BaseButton and not node.has_meta("clicks"):
		node.set_meta("clicks", true)
		node.pressed.connect(play.bind("button_click"))
