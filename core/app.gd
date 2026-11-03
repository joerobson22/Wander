extends Node
## Autoload "App": owns the GameState, saves it, runs the walk lifecycle and
## asks the app shell to move between screens.

## Screens: the five panes ("focus", "gifts", "projects", "profile",
## "stats"), the full-screen flows ("choose_focus", "walk", "finish",
## "ended"), and "home", which closes any flow and returns to the focus pane.
## The debug bar's time of day is being dragged: the sky follows.
@warning_ignore("unused_signal")
signal sky_moved
signal navigate(screen: String, params: Dictionary)
## A full-screen flow to build out of sight, ready for App.go() (see prepare()).
signal prepare_screen(screen: String, params: Dictionary)
signal state_changed

var state: GameState
var rng := RandomNumberGenerator.new()
## Set when this launch found a save from another version: it was put aside
## (as .old) and a fresh one started, and the app says so.
var save_reset := false
## Set when this launch found a walk still running from before the app was
## closed: {session, biome}. The shell shows the focus ended screen for it.
var ended_walk := {}
## Friends for the leaderboard and their profiles (the shape is in
## Friends). Filled by the friends service once accounts exist (roadmap
## phase 4); never saved locally. Debug builds give the first save slot
## sample friends; a new slot starts with none.
var friends: Array = []
## The save slot in use (see SaveSlots).
var slot := SaveSlots.FIRST
## True after Log out, until you create an account or pick one: the create
## account screen covers everything till then (needs_account()).
var signed_out := false

## What's been done so far, for the unlock rules (Unlocks); worked out again
## after each change.
var _facts := {}
var _facts_key := ""
var _changes := 0
## The holiday last worked out, and for which minute and save (see holiday()).
var _holidays: Array[String] = []
var _holiday_key := ""


## How often a running walk notes that the app is still open, in seconds.
const HEARTBEAT := 30.0


## How many of each gift the debug "Unlock all" switch hands out.
const DEBUG_GIFTS := 50


func _ready() -> void:
	rng.randomize()
	var index := SaveSlots.read_index()
	slot = index["current"]
	signed_out = index["signed_out"]
	friends = _friends_for(slot)
	if SaveSystem.out_of_date(SaveSlots.file(slot)):
		SaveSystem.set_aside(SaveSlots.file(slot))
		save_reset = true
	state = SaveSystem.read(SaveSlots.file(slot))
	if state == null:
		state = _first_launch_state()
		save()
	elif state.active:
		ended_walk = _end_left_walk()
		save()
	var heartbeat := Timer.new()
	heartbeat.wait_time = HEARTBEAT
	heartbeat.autostart = true
	heartbeat.timeout.connect(_on_heartbeat)
	add_child(heartbeat)
	# Every button grows a little under the pointer (HoverGrow).
	get_tree().node_added.connect(func(n: Node):
		if n is BaseButton:
			HoverGrow.attach(n))


func _notification(what: int) -> void:
	# Mobile apps can be killed at any time once backgrounded, so save then.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if state:
				if state.active:
					state.active.last_seen_unix = now()
				save()


## While walking, notes every so often that the app is still open, so a walk
## the app is killed in the middle of stops about when that happened.
func _on_heartbeat() -> void:
	if state and state.active:
		state.active.last_seen_unix = now()
		save()


func now() -> int:
	return int(Time.get_unix_time_from_system())


func tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


func today() -> int:
	return Stats.local_day(now(), tz_bias())


func set_setting(key: String, value) -> void:
	state.settings[key] = value
	_changed()


func set_profile(key: String, value) -> void:
	state.profile[key] = value
	_changed()


func save() -> void:
	var err := SaveSystem.write(state, SaveSlots.file(slot))
	if err != OK:
		push_error("Save failed: %s" % error_string(err))


func go(screen: String, params: Dictionary = {}) -> void:
	navigate.emit(screen, params)


## Builds a full-screen flow under the one showing, out of sight, so it's
## fully drawn the moment App.go() opens it with the same screen (the
## params given here are the ones it opens with).
func prepare(screen: String, params: Dictionary = {}) -> void:
	prepare_screen.emit(screen, params)


# --- Save slots --------------------------------------------------------------

## Every save slot on this device, oldest first, for the account switcher:
## SaveSlots.summary() of each, plus its "id" and whether it's "current".
func slots() -> Array:
	var index := SaveSlots.read_index()
	var out: Array = []
	for id in index["slots"]:
		var s: GameState = state if id == slot else SaveSystem.read(SaveSlots.file(id))
		if s == null:
			s = GameState.new()
		var row := SaveSlots.summary(s, achievement_rows(s))
		row["id"] = id
		row["current"] = id == slot
		out.append(row)
	return out


## Saves this slot and carries on in slot `id`, as it was left.
func switch_slot(id: String) -> void:
	var index := SaveSlots.read_index()
	if id == slot or not (index["slots"] as Array).has(id):
		return
	# A blank account left after deleting the one you logged out of isn't kept.
	if (index["slots"] as Array).has(slot):
		save()
	if SaveSystem.out_of_date(SaveSlots.file(id)):
		SaveSystem.set_aside(SaveSlots.file(id))
	var next := SaveSystem.read(SaveSlots.file(id))
	if next == null:
		next = GameState.new()
		next.profile["created_unix"] = now()
	_enter_slot(id, next, index)


## Whether the create account screen should be up: after Log out, and for
## an account with no name yet (a first launch).
func needs_account() -> bool:
	return signed_out or str(state.profile.get("username", "")).strip_edges() == ""


## Whether there's a named account to log back into, for "I have an account".
func has_accounts() -> bool:
	return slots().any(func(r): return str(r["name"]).strip_edges() != "")


## The create account screen's Create: fills in this slot if it has no name
## yet (a first launch keeps anything done so far), or else makes a new,
## empty slot with your settings from this one and moves into it.
func create_account(username: String, institution: String, dob: String = "") -> void:
	var index := SaveSlots.read_index()
	if str(state.profile.get("username", "")).strip_edges() != "":
		var id := SaveSlots.new_id(now(), rng, index["slots"])
		var fresh := GameState.new()
		fresh.profile["created_unix"] = now()
		fresh.settings = state.settings.duplicate(true)
		save()
		(index["slots"] as Array).append(id)
		_enter_slot(id, fresh, index)
	elif not (index["slots"] as Array).has(slot):
		(index["slots"] as Array).append(slot)
	state.profile["username"] = username.strip_edges()
	state.profile["institution"] = institution.strip_edges()
	state.profile["dob"] = dob
	# When the privacy policy and terms were agreed to.
	state.profile["agreed_unix"] = now()
	_set_signed_out(false, index)
	_changed()


## Saves and goes back to the create account screen. The account stays on
## this device, to log back into.
func log_out() -> void:
	save()
	_set_signed_out(true, SaveSlots.read_index())
	state_changed.emit()


## Settings, Data, Delete: this account and everything in it goes for good,
## and the create account screen comes up.
func delete_account() -> void:
	log_out()
	delete_slot(slot)
	# Where you are isn't kept for the next account either.
	state.settings.erase("location_cache")
	state.settings.erase("weather_cache")


## "I have an account": carries on in slot `id`, as it was left.
func log_in(id: String) -> void:
	switch_slot(id)
	_set_signed_out(false, SaveSlots.read_index())
	state_changed.emit()


func _set_signed_out(on: bool, index: Dictionary) -> void:
	signed_out = on
	index["current"] = slot
	index["signed_out"] = on
	SaveSlots.write_index(index)


## Deletes a slot's save for good. The slot in use can only go once you've
## logged out of it; you're then left in a new, blank one till you create
## or pick an account.
func delete_slot(id: String) -> void:
	var index := SaveSlots.read_index()
	if id == slot:
		if not signed_out:
			return
		var rest: Array = (index["slots"] as Array).filter(func(x): return x != id)
		var blank := SaveSlots.FIRST if id != SaveSlots.FIRST and not rest.has(SaveSlots.FIRST) else SaveSlots.new_id(now(), rng, index["slots"])
		# Out of the slot first, so it can go; the blank one joins the list
		# when it's given a name.
		index["current"] = blank
		SaveSlots.remove(index, id)
		var fresh := GameState.new()
		fresh.profile["created_unix"] = now()
		fresh.settings = state.settings.duplicate(true)
		slot = blank
		state = fresh
		friends = _friends_for(blank)
		SaveSlots.write_index(index)
		state_changed.emit()
		return
	if SaveSlots.remove(index, id):
		SaveSlots.write_index(index)


func _enter_slot(id: String, next: GameState, index: Dictionary) -> void:
	slot = id
	index["current"] = id
	SaveSlots.write_index(index)
	state = next
	friends = _friends_for(id)
	save_reset = false
	ended_walk = {}
	# Only the slot in use can have a walk running, but just in case.
	if state.active:
		_end_left_walk()
	_changed()


func _friends_for(id: String) -> Array:
	return Friends.sample() if OS.is_debug_build() and id == SaveSlots.FIRST else []


# --- Achievements ------------------------------------------------------------

## Every achievement with how far along `s` (this slot's save if null) is,
## in order: the hours focused, then every gift, then each table's set.
func achievement_rows(s: GameState = null) -> Array:
	if s == null:
		s = state
	return Achievements.progress(Achievements.list(Content.achievements, Content.tables, Content.gifts),
		s.total_seconds(), s.inventory.keys(), Content.gifts)


# --- Projects ----------------------------------------------------------------

func new_project_id() -> String:
	return "p%d_%04x" % [now(), rng.randi() & 0xffff]


func add_project(p: ProjectData) -> void:
	if p.id == "":
		p.id = new_project_id()
	if p.created_unix == 0:
		p.created_unix = now()
	state.projects.append(p)
	_changed()


func delete_project(id: String) -> void:
	state.projects.assign(state.projects.filter(func(p): return p.id != id))
	_changed()


func complete_project(id: String) -> void:
	var p := state.project(id)
	if p and not p.is_complete():
		p.completed_unix = now()
		_changed()


## Puts a deleted project back where it was in the list (undo).
func restore_project(p: ProjectData, index: int) -> void:
	if state.project(p.id) != null:
		return
	state.projects.insert(clampi(index, 0, state.projects.size()), p)
	_changed()


## Back to ongoing; its grade stays, hidden until it's completed again.
func reopen_project(id: String) -> void:
	var p := state.project(id)
	if p and p.is_complete():
		p.completed_unix = 0
		_changed()


# --- Pets --------------------------------------------------------------------

func add_pet(p: PetData) -> void:
	if p.id == "":
		p.id = "pet%d_%04x" % [now(), rng.randi() & 0xffff]
	if p.adopted_unix == 0:
		p.adopted_unix = now()
	state.pets.append(p)
	_changed()


## The pet leaves your pets for good, but still shows on the projects it
## walked for.
func rehome_pet(id: String) -> void:
	var p := state.pet(id)
	if p and not p.is_rehomed():
		p.rehomed_unix = now()
		_changed()


## A name for a new pet of this animal that no pet of yours has yet:
## "Dog 1", then "Dog 1 (2)", "Dog 1 (3)"...
func free_pet_name(animal_id: String) -> String:
	var base := str(Content.animal(animal_id).get("name", ""))
	var taken := {}
	for p in state.pets:
		taken[p.name.to_lower()] = true
	var pick := base
	var n := 2
	while taken.has(pick.to_lower()):
		pick = "%s (%d)" % [base, n]
		n += 1
	return pick


## Where you last focused: the place the choose focus screen opens on
## (lakeside before your first walk, or if that place is locked again).
func focus_place() -> String:
	var id := str(state.settings.get("walk_biome", "lake"))
	return id if can_walk_in(id) else "lake"


## True if `id` is a place you can walk in now.
func can_walk_in(id: String) -> bool:
	return id != "" and Content.biome(id).get("id", "") == id and is_unlocked("place", id)


## `grade_ref` is "<scale>/<grade>" from data/grades.json, or "" for none.
func set_grade(id: String, grade_ref: String) -> void:
	var p := state.project(id)
	if p:
		p.grade = grade_ref
		_changed()


# --- Levels ------------------------------------------------------------------

func xp() -> int:
	return state.xp


func level() -> int:
	return Levels.level_for(xp(), Content.levels)


## Whether an animal or place ("animal" / "place") is unlocked yet.
func is_unlocked(type: String, id: String) -> bool:
	if debug_unlock_all():
		return true
	return unlock_progress(type, id)["done"]


## How far along unlocking an animal or place is (Unlocks.progress), with
## its "rule" added.
func unlock_progress(type: String, id: String) -> Dictionary:
	var rule := Content.unlock_rule(type, id)
	var p := Unlocks.progress(rule, facts(), Content.gifts)
	p["rule"] = rule
	return p


## Every animal and place unlocked now, as "type:id" keys.
func unlocked_keys() -> Dictionary:
	var out := {}
	for type in ["place", "animal"]:
		for thing in Content.biomes if type == "place" else Content.animals:
			if is_unlocked(type, thing["id"]):
				out["%s:%s" % [type, thing["id"]]] = true
	return out


## What's been done so far, for the unlock rules (see Unlocks).
func facts() -> Dictionary:
	var key := "%d:%d" % [state.get_instance_id(), _changes]
	if key != _facts_key:
		_facts_key = key
		var found := {}
		for id in state.inventory:
			found[id] = true
		var holiday_seconds := {}
		for h in Content.holidays:
			holiday_seconds[h["id"]] = Holidays.best_seconds(h, state.days, str(state.profile.get("dob", "")))
		_facts = {"level": level(), "total_seconds": state.total_seconds(), "place_seconds": state.place_seconds(),
			"found": found, "holiday_seconds": holiday_seconds}
	return _facts


## Debug builds only: tops every gift up to DEBUG_GIFTS, so trade-ins and
## the collection can be tried out. Switching "Unlock all" on does this.
func debug_fill_gifts() -> void:
	if not OS.is_debug_build():
		return
	for g in Content.gifts:
		var id: String = g["id"]
		state.inventory[id] = maxi(state.gift_count(id), DEBUG_GIFTS)
	_changed()


## The debug-only "unlock everything" switch on the focus screen. Ignored
## outside debug builds (runs from the editor, debug exports).
func debug_unlock_all() -> bool:
	return OS.is_debug_build() and bool(state.settings.get("debug_unlock_all", false))


## The debug-only "phone size" switch: the window takes a phone's shape and
## the app lays itself out as on a phone (see main.gd).
func debug_phone_view() -> bool:
	return OS.is_debug_build() and bool(state.settings.get("debug_phone_view", false))


## True on phones and tablets, and in the debug phone view: a finger, not a
## mouse, so nothing reacts to hovering and "tap" is said rather than "click".
func touch_screen() -> bool:
	return OS.has_feature("mobile") or debug_phone_view()


## Set by main.gd while a computer's window is tall and narrow, like a phone.
var narrow_window := false


## True on phones and tablets, in the debug phone view and in a narrow
## window: swiping and a tap-to-open map rather than edge arrows and a map
## that opens under the pointer.
func phone_layout() -> bool:
	return OS.has_feature("mobile") or debug_phone_view() or narrow_window


# --- Time of day -------------------------------------------------------------

## The local time as hours past midnight: the real time, or the debug
## bar's time of day while it's set (debug builds only). A holiday can pin
## it (it's always midnight on Halloween).
func day_hour() -> float:
	var look := holiday_look()
	if look and look.hour >= 0.0:
		return look.hour
	var forced := float(state.settings.get("debug_hour", -1.0))
	if OS.is_debug_build() and forced >= 0.0:
		return forced
	return DayCycle.hour_now()


## How much it's night where you are (0 day, 1 night), easing over the
## twilight round sunrise and sunset (Outdoors.sun_hours()).
func night() -> float:
	var sun := Outdoors.sun_hours()
	return DayCycle.night_at(day_hour(), sun.x, sun.y)


## The sky now (DayCycle.at()), with the sun up while it's really up.
func sky_look() -> Dictionary:
	var sun := Outdoors.sun_hours()
	var cycle := Content.day_cycle
	return DayCycle.at(DayCycle.solar_hour(day_hour(), sun.x, sun.y, cycle), cycle)


## Whether the app is in its dark colours: after sunset till sunrise. Tests
## can pin it to light or dark ("debug_theme"; debug builds only).
func wants_dark() -> bool:
	match str(state.settings.get("debug_theme", "auto")) if OS.is_debug_build() else "auto":
		"light":
			return false
		"dark":
			return true
	return night() >= 0.5


## The walk's debug time buttons: the walk started `minutes` earlier.
## Does nothing outside debug builds.
func debug_add_minutes(minutes: int) -> void:
	if not OS.is_debug_build() or state.active == null:
		return
	state.active.start_unix -= minutes * 60
	_changed()


# --- Holidays ----------------------------------------------------------------

## The holiday on now (see Holidays and data/holidays.json), or "" on an
## ordinary day. Debug builds can try one out from the debug bar
## ("debug_holiday": an id, or "none" for an ordinary day whatever the date).
func holiday() -> String:
	var all := holidays()
	return all[0] if not all.is_empty() else ""


## Every holiday on now, the one the app dresses for first (your birthday
## beats the others): each gives its present. Debug builds can force one.
func holidays() -> Array[String]:
	if OS.is_debug_build():
		var forced := str(state.settings.get("debug_holiday", ""))
		if forced == "none":
			return []
		if not Content.holiday(forced).is_empty():
			return [forced]
	var key := "%d:%d:%d" % [floori(now() / 60.0), state.get_instance_id(), _changes]
	if key != _holiday_key:
		_holiday_key = key
		_holidays = Holidays.all_on(Time.get_datetime_dict_from_system(), Content.holidays, str(state.profile.get("dob", "")))
	return _holidays


## How the holiday on now looks (HolidayLook), or null.
func holiday_look() -> HolidayLook:
	return Holidays.look(holiday())


## The hat a holiday has you wear whatever you've picked (your party hat on
## your birthday), or "".
func holiday_hat() -> String:
	var look := holiday_look()
	return look.hat if look and not Content.cosmetic(look.hat).is_empty() else ""


## Your present for opening the app on a holiday, given once a year:
## {holiday, gift} (ids), or {} if there's nothing to give (no holiday, no
## account yet, or already given this year). With two on at once (your
## birthday at Christmas), each call gives the next.
func claim_holiday_gift() -> Dictionary:
	if needs_account():
		return {}
	var year := int(Time.get_date_dict_from_system()["year"])
	var given = state.profile.get("holiday_gifts", {})
	if not given is Dictionary:
		given = {}
	for id in holidays():
		var gift_id := str(Content.holiday(id).get("gift", ""))
		if gift_id == "" or Content.gift(gift_id).is_empty() or int(given.get(id, 0)) == year:
			continue
		given[id] = year
		state.profile["holiday_gifts"] = given
		state.inventory[gift_id] = state.gift_count(gift_id) + 1
		_changed()
		return {"holiday": id, "gift": gift_id}
	return {}


# --- Gifts -------------------------------------------------------------------

## Trades gifts up a rarity. Returns the new gift's id, or "" if it can't.
func trade_in(gift_id: String) -> String:
	var g := Content.gift(gift_id)
	if g.is_empty():
		return ""
	var new_id := GiftRoller.trade(state.inventory, gift_id, Content.gifts, Content.trade_cost(g["rarity"]))
	if new_id != "":
		state.tidy_gift_references()
		_changed()
	return new_id


func place_on_shelf(gift_id: String, index: int) -> void:
	state.place_on_shelf(gift_id, index)
	_changed()


func remove_from_shelf(index: int) -> void:
	state.remove_from_shelf(index)
	_changed()


# --- Character ---------------------------------------------------------------

## Saves a look from the customise popup: {skin_tone, hair_tone, cosmetics,
## and skin_colour / hair_colour (hex, "" for none) when a colour was picked
## instead of a swatch}.
func set_look(look: Dictionary) -> void:
	state.profile["skin_tone"] = int(look.get("skin_tone", 0))
	state.profile["hair_tone"] = int(look.get("hair_tone", 0))
	state.profile["skin_colour"] = str(look.get("skin_colour", ""))
	state.profile["hair_colour"] = str(look.get("hair_colour", ""))
	state.profile["cosmetics"] = (look.get("cosmetics", {}) as Dictionary).duplicate()
	_changed()


# --- Walks -------------------------------------------------------------------

func start_walk(project_id: String, pet_id: String, biome_id: String = "") -> void:
	if biome_id == "":
		biome_id = focus_place()
	state.settings["last_project"] = project_id
	state.settings["last_pet"] = pet_id
	# Where the choose focus screen opens next time.
	state.settings["walk_biome"] = biome_id
	state.active = SessionClock.begin(project_id, pet_id, now(), biome_id)
	_changed()


func pause_walk() -> void:
	if state.active:
		state.active.pause(now())
		_changed()


func resume_walk() -> void:
	if state.active:
		state.active.resume(now())
		_changed()


## Ends the walk, logs it, rolls the gift and returns a summary for the
## focus complete screen: {session: FocusSession, gift: Dictionary,
## unlocked: [{type, id}] for anything the walk unlocked}.
func finish_walk() -> Dictionary:
	var clock := state.active
	if clock == null:
		return {}
	var t := now()
	var seconds := clock.elapsed(t)
	var pet := state.pet(clock.pet_id)
	var animal_id := pet.animal_id if pet else ""

	var before := unlocked_keys()
	var pity := int(state.profile.get("walks_since_epic", 0))
	var gift := GiftRoller.roll(seconds, Content.table_of(animal_id), pity, Content.drop_table, Content.gifts, rng)
	state.profile["walks_since_epic"] = GiftRoller.next_pity_count(pity, seconds, gift.get("rarity", ""), Content.drop_table)

	var s := _log_walk(clock, t, gift.get("gift_id", ""))
	if s.gift_id != "":
		state.inventory[s.gift_id] = int(state.inventory.get(s.gift_id, 0)) + 1
	state.active = null
	_changed()
	var unlocked: Array = []
	for key in unlocked_keys():
		if not before.has(key):
			var bits: PackedStringArray = key.split(":")
			unlocked.append({"type": bits[0], "id": bits[1]})
	return {"session": s, "gift": gift, "unlocked": unlocked}


func cancel_walk() -> void:
	state.active = null
	_changed()


## A walk still running at launch means the app was closed (or killed) in
## the middle of it. It stops where the app was last seen open and the time
## still counts, but the pet never got to finish looking: no gift.
func _end_left_walk() -> Dictionary:
	var clock := state.active
	var s := _log_walk(clock, clock.left_at(SaveSystem.saved_unix(), now()), "")
	state.active = null
	_changes += 1
	return {"session": s, "biome": clock.biome_id}


## Logs a walk that ended at `end_unix`: its time goes on the days it
## fell on (by project, pet and place) and onto the project (by pet and
## place), its XP onto the total and its gift onto the project. Walks under
## a minute (mis-taps) aren't worth keeping. Returns the walk either way.
func _log_walk(clock: SessionClock, end_unix: int, gift_id: String) -> FocusSession:
	var project := state.project(clock.project_id)
	var pet := state.pet(clock.pet_id)
	var s := FocusSession.new()
	s.project_id = clock.project_id
	s.pet_id = clock.pet_id
	s.animal_id = pet.animal_id if pet else ""
	s.place_id = clock.biome_id
	s.start_unix = clock.start_unix
	s.end_unix = end_unix
	s.focus_seconds = clock.elapsed(end_unix)
	s.gift_id = gift_id
	if s.focus_seconds >= 60:
		for day in Stats.split_by_day(s.start_unix, s.focus_seconds, tz_bias()):
			state.log_focus(day[0], s.project_id, s.pet_id, s.place_id, day[1])
		if project:
			project.pets[s.pet_id] = int(project.pets.get(s.pet_id, 0)) + s.focus_seconds
			project.places[s.place_id] = int(project.places.get(s.place_id, 0)) + s.focus_seconds
			project.last_walked_unix = end_unix
		if pet:
			pet.last_walked_unix = end_unix
			pet.places[s.place_id] = int(pet.places.get(s.place_id, 0)) + s.focus_seconds
		state.xp += Levels.walk_xp(s.focus_seconds, Content.gift_rarity(gift_id) if gift_id != "" else "", Content.levels)
		state.profile["walks"] = int(state.profile.get("walks", 0)) + 1
		if project and gift_id != "":
			project.gifts[gift_id] = int(project.gifts.get(gift_id, 0)) + 1
	return s


# --- Internals ---------------------------------------------------------------

func _changed() -> void:
	_changes += 1
	save()
	state_changed.emit()


func _first_launch_state() -> GameState:
	var s := GameState.new()
	s.profile["created_unix"] = now()
	return s
