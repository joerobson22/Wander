class_name DayCycle
extends RefCounted
## How the outdoors looks at any moment of the day. data/biomes.json gives
## the sky and the light at a handful of hours ("keys"); between them
## everything blends smoothly, round the clock, so it gets lighter until
## midday and darker after it. The sun crosses the sky from sunrise to
## sunset, then the moon does the same overnight.


## The local time now, as hours past midnight (14.5 is half past two).
static func hour_now() -> float:
	var t := Time.get_datetime_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0 + float(t["second"]) / 3600.0


## The look at `hour` (wrapped into 0..24): {sky_top, sky_bottom, tint:
## Color, dark: 0 (broad day) to 1 (night), sun, moon: how far across the
## sky each is (0 rising, 0.5 highest, 1 setting), or -1 while it's down}.
## `cycle` is Content.day_cycle: {sunrise, sunset, moon_gap, keys: [{hour,
## sky_top, sky_bottom, tint, dark}]} with keys in order of hour.
static func at(hour: float, cycle: Dictionary) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var out := {
		"sky_top": Color("#8ec3e6"), "sky_bottom": Color("#d7ecf6"), "tint": Color.WHITE, "dark": 0.0,
		"sun": arc(h, float(cycle.get("sunrise", 6.0)), float(cycle.get("sunset", 18.0))),
		"moon": -1.0,
	}
	var gap := float(cycle.get("moon_gap", 0.5))
	out["moon"] = arc(h, float(cycle.get("sunset", 18.0)) + gap, float(cycle.get("sunrise", 6.0)) - gap)
	var keys: Array = cycle.get("keys", [])
	if keys.is_empty():
		return out
	# The last key at or before this hour, and the next one round the clock.
	var i := keys.size() - 1
	for k in keys.size():
		if float(keys[k]["hour"]) <= h:
			i = k
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[(i + 1) % keys.size()]
	var span := fposmod(float(b["hour"]) - float(a["hour"]), 24.0)
	var f := fposmod(h - float(a["hour"]), 24.0) / span if span > 0.0 else 0.0
	for name in ["sky_top", "sky_bottom", "tint"]:
		out[name] = Color(a[name]).lerp(Color(b[name]), f)
	out["dark"] = lerpf(float(a.get("dark", 0.0)), float(b.get("dark", 0.0)), f)
	return out


## Where the local time `hour` falls on the cycle's own day, given the real
## `sunrise` and `sunset` (local hours): sunrise lands on the cycle's
## sunrise and sunset on its sunset, and the day between (and the night
## after) stretches or squeezes to fit. at() on the result then has the
## sun up exactly while it's really up.
static func solar_hour(hour: float, sunrise: float, sunset: float, cycle: Dictionary) -> float:
	var c_rise := float(cycle.get("sunrise", 6.0))
	var c_day := fposmod(float(cycle.get("sunset", 18.0)) - c_rise, 24.0)
	var day := clampf(fposmod(sunset - sunrise, 24.0), 0.5, 23.5)
	var into := fposmod(hour - sunrise, 24.0)
	if into <= day:
		return fposmod(c_rise + c_day * into / day, 24.0)
	return fposmod(c_rise + c_day + (24.0 - c_day) * (into - day) / (24.0 - day), 24.0)


## How far across the sky something is that rises at `rise` and sets at
## `set_at` (hours; it may be up over midnight): 0..1, or -1 while it's down.
static func arc(hour: float, rise: float, set_at: float) -> float:
	var span := fposmod(set_at - rise, 24.0)
	var into := fposmod(hour - rise, 24.0)
	if span <= 0.0 or into > span:
		return -1.0
	return into / span


## How long dusk and dawn take, in hours, centred on sunset and sunrise.
const TWILIGHT := 40.0 / 60.0


## How much it's night at local `hour`, given that day's `sunrise` and
## `sunset`: 0 by day, 1 by night, easing between over the twilight round
## each. 0.5 is the moment of sunset or sunrise.
static func night_at(hour: float, sunrise: float, sunset: float) -> float:
	var half := TWILIGHT * 0.5
	var h := fposmod(hour, 24.0)
	# Signed hours from each edge, the short way round the clock.
	var from_rise := fposmod(h - sunrise + 12.0, 24.0) - 12.0
	var from_set := fposmod(h - sunset + 12.0, 24.0) - 12.0
	if absf(from_rise) <= half:
		return 1.0 - smoothstep(-half, half, from_rise)
	if absf(from_set) <= half:
		return smoothstep(-half, half, from_set)
	return 0.0 if arc(h, sunrise, sunset) >= 0.0 else 1.0
