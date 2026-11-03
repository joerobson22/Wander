class_name SessionClock
extends RefCounted
## Timestamp-based focus timer. Elapsed time is always derived from wall-clock
## timestamps, so backgrounding, sleep or the app being killed can't corrupt it.
## Every method takes `now` (unix seconds) so it can be tested deterministically.

var project_id: String = ""
var pet_id: String = ""
var start_unix: int = 0
var paused_total: int = 0
## 0 while running.
var pause_started_unix: int = 0
var biome_id: String = "lake"
## The last moment the app was known to be open during this walk (kept up
## to date while it runs); 0 if never recorded.
var last_seen_unix: int = 0


static func begin(p_project_id: String, p_pet_id: String, now: int, p_biome_id: String = "lake") -> SessionClock:
	var c := SessionClock.new()
	c.project_id = p_project_id
	c.pet_id = p_pet_id
	c.start_unix = now
	c.biome_id = p_biome_id
	return c


func is_paused() -> bool:
	return pause_started_unix > 0


func pause(now: int) -> void:
	if not is_paused():
		pause_started_unix = maxi(now, start_unix)


func resume(now: int) -> void:
	if is_paused():
		paused_total += maxi(0, now - pause_started_unix)
		pause_started_unix = 0


func elapsed(now: int) -> int:
	var end := pause_started_unix if is_paused() else now
	# Clamp so a clock that jumps backwards never produces negative time.
	return maxi(0, end - start_unix - paused_total)


## When a walk found still running at launch really stopped: the last time
## the app was seen open, else when the save was last written (`saved_unix`,
## 0 if unknown), never before the start or after `now`.
func left_at(saved_unix: int, now: int) -> int:
	var seen := last_seen_unix if last_seen_unix > 0 else saved_unix
	if seen <= 0:
		seen = start_unix
	return clampi(seen, start_unix, maxi(now, start_unix))


func to_dict() -> Dictionary:
	return {
		"project_id": project_id,
		"pet_id": pet_id,
		"start_unix": start_unix,
		"paused_total": paused_total,
		"pause_started_unix": pause_started_unix,
		"biome_id": biome_id,
		"last_seen_unix": last_seen_unix,
	}


static func from_dict(d: Dictionary) -> SessionClock:
	var c := SessionClock.new()
	c.project_id = str(d.get("project_id", ""))
	c.pet_id = str(d.get("pet_id", ""))
	c.start_unix = int(d.get("start_unix", 0))
	c.paused_total = int(d.get("paused_total", 0))
	c.pause_started_unix = int(d.get("pause_started_unix", 0))
	c.biome_id = str(d.get("biome_id", "lake"))
	c.last_seen_unix = int(d.get("last_seen_unix", 0))
	return c


## "01:02:05", and from a day on "1d 02:13:05".
static func format(seconds: int) -> String:
	@warning_ignore("integer_division")
	var days := seconds / 86400
	@warning_ignore("integer_division")
	var clock := "%02d:%02d:%02d" % [(seconds / 3600) % 24, (seconds / 60) % 60, seconds % 60]
	return "%dd %s" % [days, clock] if days > 0 else clock
