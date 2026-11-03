extends TestCase

var cycle: Dictionary


func _init() -> void:
	cycle = load_json("res://data/biomes.json")["day_cycle"]


func _brightness(hour: float) -> float:
	var tint: Color = DayCycle.at(hour, cycle)["tint"]
	return tint.get_luminance()


func test_keys_in_order() -> void:
	var keys: Array = cycle["keys"]
	for i in range(1, keys.size()):
		check(float(keys[i]["hour"]) > float(keys[i - 1]["hour"]), "key %d comes after the one before" % i)


func test_brighter_until_midday_then_darker() -> void:
	var noon := _brightness(12.0)
	check(is_equal_approx(noon, 1.0), "full light at midday")
	var h := 4.0
	while h < 12.0:
		check(_brightness(h + 0.25) >= _brightness(h) - 0.001, "lighter at %.2f than %.2f" % [h + 0.25, h])
		h += 0.25
	while h < 24.0:
		check(_brightness(h + 0.25) <= _brightness(h) + 0.001, "darker at %.2f than %.2f" % [h + 0.25, h])
		h += 0.25
	check(_brightness(0.0) < 0.5 and _brightness(23.0) < 0.5, "night is dim")


func test_blends_smoothly_round_midnight() -> void:
	var before: Dictionary = DayCycle.at(23.999, cycle)
	var after: Dictionary = DayCycle.at(0.0, cycle)
	for name in ["sky_top", "sky_bottom", "tint"]:
		var x: Color = before[name]
		var y: Color = after[name]
		check(absf(x.r - y.r) < 0.01 and absf(x.g - y.g) < 0.01 and absf(x.b - y.b) < 0.01, "no jump in %s at midnight" % name)
	check(absf(float(before["dark"]) - float(after["dark"])) < 0.01, "dark carries over midnight")
	var at_key: Dictionary = DayCycle.at(12.0, cycle)
	check((at_key["sky_top"] as Color).is_equal_approx(Color(cycle["keys"][6]["sky_top"])), "exactly the key's sky at its hour")
	var a: Color = DayCycle.at(13.0, cycle)["sky_top"]
	var b: Color = DayCycle.at(13.0 + 1.0 / 60.0, cycle)["sky_top"]
	check(absf(a.r - b.r) < 0.01 and absf(a.b - b.b) < 0.01, "a minute changes very little")


func test_sun_then_moon() -> void:
	eq(DayCycle.at(5.0, cycle)["sun"], -1.0, "no sun before sunrise")
	eq(DayCycle.at(6.0, cycle)["sun"], 0.0, "the sun comes up at sunrise")
	check(is_equal_approx(DayCycle.at(12.0, cycle)["sun"], 0.5), "highest at midday")
	eq(DayCycle.at(19.0, cycle)["sun"], -1.0, "gone after sunset")
	eq(DayCycle.at(12.0, cycle)["moon"], -1.0, "no moon by day")
	eq(DayCycle.at(18.2, cycle)["moon"], -1.0, "a gap between sunset and moonrise")
	check(DayCycle.at(23.0, cycle)["moon"] > 0.0, "the moon is up at night")
	check(DayCycle.at(2.0, cycle)["moon"] > DayCycle.at(23.0, cycle)["moon"], "and keeps going across after midnight")
	eq(DayCycle.at(5.75, cycle)["moon"], -1.0, "set before sunrise")
	check(DayCycle.at(0.0, cycle)["dark"] > 0.9 and DayCycle.at(12.0, cycle)["dark"] == 0.0, "dark at night, not by day")


func test_arc_wraps_midnight() -> void:
	eq(DayCycle.arc(22.0, 20.0, 4.0), 0.25)
	eq(DayCycle.arc(2.0, 20.0, 4.0), 0.75)
	eq(DayCycle.arc(12.0, 20.0, 4.0), -1.0)
	eq(DayCycle.arc(-1.0 + 24.0, 6.0, 18.0), -1.0)


## The app turns dark at sunset and light at sunrise, easing over about
## 40 minutes of twilight round each.
func test_night_follows_sunset_and_sunrise() -> void:
	eq(DayCycle.night_at(12.0, 6.0, 18.0), 0.0, "midday")
	eq(DayCycle.night_at(0.0, 6.0, 18.0), 1.0, "midnight")
	check(is_equal_approx(DayCycle.night_at(18.0, 6.0, 18.0), 0.5), "halfway at sunset")
	check(is_equal_approx(DayCycle.night_at(6.0, 6.0, 18.0), 0.5), "halfway at sunrise")
	eq(DayCycle.night_at(18.0 + 0.34, 6.0, 18.0), 1.0, "dark 20 minutes after sunset")
	eq(DayCycle.night_at(18.0 - 0.34, 6.0, 18.0), 0.0, "light 20 minutes before")
	var dusk := DayCycle.night_at(18.1, 6.0, 18.0)
	check(dusk > 0.5 and dusk < 1.0, "getting darker in the twilight (%.2f)" % dusk)
	eq(DayCycle.night_at(1.0, 21.0, 3.5), 0.0, "a day that runs over midnight")
