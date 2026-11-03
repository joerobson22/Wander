extends Node
## Autoload "Audio": button clicks, one-off sounds and the looping ambience,
## all following the sound and ambience settings.

const SOUND_DIR := "res://assets/sounds/"
## The sound list you can change in the Godot editor: each sound's
## recording, loudness and pitch (see SoundLibrary).
const LIBRARY := "res://assets/sounds/sounds.tres"
## Ambience per place; the walk picks by biome and time of day.
const AMBIENCE := {
	"lake": "water_ambience",
	"day": "daytime_birds",
	"night": "night_ambience",
	"wind": "wind_ambience",
	"rain": "rain_ambience",
}
## How loud the ambience plays, under the sound effects.
const AMBIENCE_DB := -10.0
## One-off sounds can overlap (a rustle, then a bark) up to this many at once.
const VOICES := 4

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _ambience := AudioStreamPlayer.new()
var _ambience_name := ""
## Sounds already looked up in assets/sounds/ (null: none there).
var _cache := {}
var _library: SoundLibrary
## The file types a sound in assets/sounds/ can be, first found wins.
const EXTENSIONS := ["wav", "ogg", "mp3"]


func _ready() -> void:
	if ResourceLoader.exists(LIBRARY):
		_library = load(LIBRARY) as SoundLibrary
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	add_child(_ambience)
	_ambience.volume_db = AMBIENCE_DB
	_ambience.finished.connect(func(): _ambience.play())
	# Every button in the app clicks, without each screen wiring it up.
	get_tree().node_added.connect(_on_node_added)
	WorkerThreadPool.add_task(Synth.warm, false, "Generate placeholder sounds")
	# Ready before the first tap, so the first click isn't late either.
	_stream("button_click")


## Plays a sound from assets/sounds/, or its generated placeholder (Synth).
## Every sound the app makes is listed in assets/sounds/README.md.
## `pitch` raises or lowers it, e.g. for the gift button's rising pops.
## `fallback` names the generated sound to use while there's no file for
## `sound`, so each moment can have its own recording but share a placeholder.
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0, fallback: String = "") -> void:
	if not App.state.settings.get("sound", true):
		return
	var setting := _setting(sound)
	if setting and setting.muted:
		return
	var stream := _stream(sound)
	if stream == null:
		stream = Synth.sound(fallback if fallback != "" else sound)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.pitch_scale = pitch * (setting.pitch if setting else 1.0)
	p.volume_db = volume_db + (setting.volume_db if setting else 0.0)
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
	var file: String = AMBIENCE.get(sound, sound)
	var setting := _setting(file)
	if setting and setting.muted:
		return
	var stream := _stream(file)
	if stream == null:
		stream = Synth.sound(sound)
	if stream:
		_ambience.stream = stream
		_ambience.volume_db = AMBIENCE_DB + (setting.volume_db if setting else 0.0)
		_ambience.pitch_scale = setting.pitch if setting else 1.0
		_ambience.play()


## Re-applies the settings after they change (e.g. ambience switched off).
func refresh(playing: String) -> void:
	_ambience_name = "-"
	ambience(playing)


func current_ambience() -> String:
	return _ambience_name


## The sound list's setting for `sound`, or null.
func _setting(sound: String) -> SoundSetting:
	return _library.find(sound) if _library else null


## Your own recording of `sound`: the one picked for it in the sound list,
## else the file named after it in assets/sounds/ (.wav, .ogg or .mp3, in
## that order), loaded once and kept; or null to use the generated one.
func _stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var setting := _setting(sound)
	if setting and setting.stream:
		_cache[sound] = setting.stream
		return setting.stream
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path: String = SOUND_DIR + sound + "." + str(ext)
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[sound] = stream
	return stream


func _on_node_added(node: Node) -> void:
	# Nodes are re-added when a pane rebuilds, so connect only once.
	if node is BaseButton and not node.has_meta("clicks"):
		node.set_meta("clicks", true)
		# The click plays the moment the button goes down, so it never lags
		# behind your finger. In a list that scrolls, a press might be the
		# start of a scroll, so there it waits for the button to be pressed.
		if _in_scroll(node):
			node.pressed.connect(play.bind("button_click", 1.0, -6.0))
		else:
			node.button_down.connect(play.bind("button_click", 1.0, -6.0))


static func _in_scroll(node: Node) -> bool:
	var n := node.get_parent()
	while n:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false
