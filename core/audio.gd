extends Node
## Autoload "Audio": button clicks, one-off sounds and the looping ambience,
## all following the sound and ambience settings.

const SOUND_DIR := "res://assets/sounds/"
## Ambience per place; the walk picks by biome and time of day.
const AMBIENCE := {
	"lake": "water_ambience",
	"day": "daytime_birds",
	"night": "night_ambience",
}
## One-off sounds can overlap (a rustle, then a bark) up to this many at once.
const VOICES := 4

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _ambience := AudioStreamPlayer.new()
var _ambience_name := ""


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	add_child(_ambience)
	_ambience.volume_db = -10.0
	_ambience.finished.connect(func(): _ambience.play())
	# Every button in the app clicks, without each screen wiring it up.
	get_tree().node_added.connect(_on_node_added)
	WorkerThreadPool.add_task(Synth.warm, false, "Generate placeholder sounds")


## Plays a sound from assets/sounds/, or its generated placeholder (Synth).
## `pitch` raises or lowers it, e.g. for the gift button's rising pops.
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not App.state.settings.get("sound", true):
		return
	var stream := _stream(sound)
	if stream == null:
		stream = Synth.sound(sound)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Starts (or keeps) a looping ambience, or stops it with "".
func ambience(sound: String) -> void:
	if not App.state.settings.get("ambience", true):
		sound = ""
	if sound == _ambience_name:
		return
	_ambience_name = sound
	_ambience.stop()
	if sound == "":
		return
	var stream := _stream(AMBIENCE.get(sound, sound))
	if stream == null:
		stream = Synth.sound(sound)
	if stream:
		_ambience.stream = stream
		_ambience.play()


## Re-applies the settings after they change (e.g. ambience switched off).
func refresh(playing: String) -> void:
	_ambience_name = "-"
	ambience(playing)


func current_ambience() -> String:
	return _ambience_name


func _stream(sound: String) -> AudioStream:
	var path := SOUND_DIR + sound + ".mp3"
	return load(path) if ResourceLoader.exists(path) else null


func _on_node_added(node: Node) -> void:
	# Nodes are re-added when a pane rebuilds, so connect only once.
	if node is BaseButton and not node.has_meta("clicks"):
		node.set_meta("clicks", true)
		node.pressed.connect(play.bind("button_click", 1.0, -6.0))
