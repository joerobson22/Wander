class_name SoundSetting
extends Resource
## One sound in the sound list (assets/sounds/sounds.tres): which recording
## plays for it, and how loud and how high. Click it in the Inspector to
## change it. Left empty, the recording is the file named after it in
## assets/sounds/ (e.g. dog_bark.mp3), or the app's own made-up placeholder.

## The sound's name, as the app asks for it (see assets/README.md).
@export var id := ""
## The recording to play. Drag an audio file here from the FileSystem dock.
@export var stream: AudioStream
## Louder (above 0) or quieter (below 0), on top of how loud the app plays it.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db := 0.0
## Higher (above 1) or lower (below 1), on top of the app's own pitch.
@export_range(0.25, 4.0, 0.01) var pitch := 1.0
## Never plays.
@export var muted := false
