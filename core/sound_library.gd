class_name SoundLibrary
extends Resource
## Every sound the app makes, in one list you can change in the Godot
## editor: double-click assets/sounds/sounds.tres, open Sounds in the
## Inspector, and click any one (see SoundSetting).

@export var sounds: Array[SoundSetting] = []


## The setting for `id`, or null if it isn't listed.
func find(id: String) -> SoundSetting:
	for s in sounds:
		if s and s.id == id:
			return s
	return null
