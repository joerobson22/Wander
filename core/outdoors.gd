extends Node
## Autoload "Outdoors": where you are and what the weather's doing there.
## With your say-so (asked once, and a switch in settings) it looks up your
## approximate location from your internet connection, works out that day's
## sunrise and sunset there (SunTimes), and checks the weather every half
## hour (Open-Meteo). The places you walk follow both. Without it, or while
## offline, the sun keeps the day cycle's own hours and the weather is fair.
## A weather picked on the walk screen wins over the real one until you
## pick the real weather again.

signal changed

## Approximate location from the connection's IP address: no key needed.
const LOCATE_URL := "https://get.geojs.io/v1/ip/geo.json"
const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=%.3f&longitude=%.3f&current=weather_code"
## How often to look again, in seconds.
const LOCATE_EVERY := 24 * 3600
const WEATHER_EVERY := 30 * 60
## Weather older than this is forgotten (fair weather again).
const WEATHER_KEEPS := 3 * 3600
const CHECK_EVERY := 5 * 60.0

var _locate := HTTPRequest.new()
var _forecast := HTTPRequest.new()
var _busy := false
## Today's sun times, worked out once a day: {date, sun: Vector2}.
var _sun_cache := {}


func _ready() -> void:
	for http in [_locate, _forecast]:
		http.timeout = 15.0
		add_child(http)
	_locate.request_completed.connect(_on_located)
	_forecast.request_completed.connect(_on_forecast)
	var timer := Timer.new()
	timer.wait_time = CHECK_EVERY
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)
	refresh.call_deferred()


# --- Asking ------------------------------------------------------------------

## Whether you've been asked yet.
func asked() -> bool:
	return str(App.state.settings.get("location", "")) != ""


func enabled() -> bool:
	return str(App.state.settings.get("location", "")) == "on"


func set_enabled(on: bool) -> void:
	App.state.settings["location"] = "on" if on else "off"
	if not on:
		App.state.settings.erase("location_cache")
		App.state.settings.erase("weather_cache")
	_sun_cache = {}
	App.save()
	changed.emit()
	refresh()


## "London" while it's on and found, else "".
func place_name() -> String:
	return str(_cached("location_cache").get("place", "")) if enabled() else ""


# --- What the places use -----------------------------------------------------

## Today's sunrise and sunset (local hours) where you are, or the day
## cycle's own hours if location is off or not found yet.
func sun_hours() -> Vector2:
	var cycle := Content.day_cycle
	var fallback := Vector2(float(cycle.get("sunrise", 6.0)), float(cycle.get("sunset", 18.0)))
	var loc := _cached("location_cache")
	if not enabled() or not loc.has("lat"):
		return fallback
	var d := Time.get_date_dict_from_system()
	var date := "%d-%d-%d" % [d["year"], d["month"], d["day"]]
	if _sun_cache.get("date", "") != date:
		var offset := float(Time.get_time_zone_from_system().get("bias", 0)) / 60.0
		var t := SunTimes.for_day(float(loc["lat"]), float(loc["lon"]), d["year"], d["month"], d["day"], offset)
		var sun := fallback
		match str(t.get("polar", "")):
			"day":
				sun = Vector2(0.25, 23.75)
			"night":
				sun = Vector2(11.75, 12.25)
			_:
				sun = Vector2(t["sunrise"], t["sunset"])
		_sun_cache = {"date": date, "sun": sun}
	return _sun_cache["sun"]


## The weather you picked on the walk (see Weather.KINDS), kept in the
## settings; "" follows the real weather.
func choice() -> String:
	var kind := str(App.state.settings.get("weather", ""))
	return kind if kind in Weather.KINDS else ""


func set_choice(kind: String) -> void:
	App.state.settings["weather"] = kind if kind in Weather.KINDS else ""
	App.save()
	changed.emit()


## The weather kind the places show (see Weather.KINDS): a holiday's (it
## always snows at Christmas), else the one you picked, else the latest real
## weather, else "sunny".
func weather() -> String:
	var look := App.holiday_look()
	if look and look.weather in Weather.KINDS:
		return look.weather
	if choice() != "":
		return choice()
	var w := _cached("weather_cache")
	if enabled() and w.has("kind") and App.now() - int(w.get("at", 0)) < WEATHER_KEEPS:
		return str(w["kind"])
	return "sunny"


# --- Looking things up -------------------------------------------------------

## Looks up whatever's out of date (location daily, weather half-hourly).
func refresh() -> void:
	if not enabled() or _busy:
		return
	var loc := _cached("location_cache")
	if not loc.has("lat") or App.now() - int(loc.get("at", 0)) > LOCATE_EVERY:
		_busy = _locate.request(LOCATE_URL) == OK
	elif App.now() - int(_cached("weather_cache").get("at", 0)) > WEATHER_EVERY:
		_ask_weather(loc)


func _ask_weather(loc: Dictionary) -> void:
	_busy = _forecast.request(WEATHER_URL % [float(loc["lat"]), float(loc["lon"])]) == OK


func _on_located(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var loc := parse_location(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else {}
	if loc.is_empty() or not enabled():
		return
	loc["at"] = App.now()
	App.state.settings["location_cache"] = loc
	_sun_cache = {}
	App.save()
	changed.emit()
	_ask_weather(loc)


func _on_forecast(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var kind := parse_weather(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else ""
	if kind == "" or not enabled():
		return
	App.state.settings["weather_cache"] = {"kind": kind, "at": App.now()}
	App.save()
	changed.emit()


## {lat, lon, place} from the location service's reply, or {} if it isn't one.
static func parse_location(text: String) -> Dictionary:
	var d = JSON.parse_string(text)
	if not d is Dictionary or not d.has("latitude") or not d.has("longitude"):
		return {}
	var lat := str(d["latitude"])
	var lon := str(d["longitude"])
	if not lat.is_valid_float() or not lon.is_valid_float():
		return {}
	return {"lat": lat.to_float(), "lon": lon.to_float(), "place": str(d.get("city", d.get("region", "")))}


## The weather kind from Open-Meteo's reply, or "" if it isn't one.
static func parse_weather(text: String) -> String:
	var d = JSON.parse_string(text)
	if not d is Dictionary or not d.get("current") is Dictionary or not (d["current"] as Dictionary).has("weather_code"):
		return ""
	return Weather.from_wmo(int(d["current"]["weather_code"]))


func _cached(key: String) -> Dictionary:
	var v = App.state.settings.get(key, {})
	return v if v is Dictionary else {}
