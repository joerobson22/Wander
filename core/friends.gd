class_name Friends
extends RefCounted
## Friends and the weekly leaderboard. A friend is a Dictionary:
## {name, weekly_seconds, walking, look, joined_unix, shelf,
## gifts, focused_seconds}. `shelf` is their three shelf gift ids ("" for an
## empty spot), `gifts` every gift id they've found, `focused_seconds` all
## their focus ever (for their achievements). Real friends arrive with
## accounts (roadmap phase 4); until then debug builds get sample() ones.


## Everyone on the leaderboard this week, most focus first: you
## (`mine` seconds, marked "me") and every friend. Nobody, you included,
## when you have no friends.
static func ranked(friends: Array, mine: int, walking: bool) -> Array:
	if friends.is_empty():
		return []
	var rows: Array = [{"name": Text.t("friends.you"), "weekly_seconds": mine, "walking": walking, "look": {}, "me": true}]
	rows.append_array(friends)
	rows.sort_custom(func(a, b): return int(a["weekly_seconds"]) > int(b["weekly_seconds"]))
	return rows


## Pretend friends for debug builds, so the leaderboard and friend profiles
## have something to show before accounts exist.
static func sample() -> Array:
	var h := 3600
	var day := 86400
	var start := 1788220800  # 1 Sep 2026
	return [
		{"name": "Sam", "weekly_seconds": 9 * h, "walking": true, "joined_unix": start + 3 * day,
			"look": {"skin_tone": 3, "hair_tone": 0, "cosmetics": {"hair": "hair_curly", "hat": "hat_beanie"}},
			"shelf": ["bear_legendary", "snail_rare", "dog_common"], "focused_seconds": 140 * h,
			"gifts": ["bear_legendary", "snail_rare", "dog_common", "dog_rare", "frog_common", "sheep_common", "rabbit_common", "bird_common", "bird_rare"]},
		{"name": "Priya", "weekly_seconds": 6 * h + 1200, "walking": false, "joined_unix": start + 10 * day,
			"look": {"skin_tone": 2, "hair_tone": 0, "cosmetics": {"hair": "hair_long", "face": "face_smile"}},
			"shelf": ["dog_epic", "", "cat_rare"], "focused_seconds": 62 * h,
			"gifts": ["dog_epic", "dog_common", "dog_rare", "dog_legendary", "cat_rare", "cat_common"]},
		{"name": "Alexandra-Louise", "weekly_seconds": 2 * h, "walking": false, "joined_unix": start + 20 * day,
			"look": {"skin_tone": 0, "hair_tone": 3, "cosmetics": {"hair": "hair_bun", "hat": "hat_cap"}},
			"shelf": ["", "", ""], "focused_seconds": 12 * h, "gifts": ["rabbit_common"]},
		{"name": "Tom", "weekly_seconds": 4 * h + 900, "walking": false, "joined_unix": start + 5 * day,
			"look": {"skin_tone": 1, "hair_tone": 6, "cosmetics": {"hair": "hair_short", "face": "face_glasses"}},
			"shelf": ["pig_rare", "pig_epic", ""], "focused_seconds": 35 * h,
			"gifts": ["pig_rare", "pig_epic", "pig_common", "tortoise_common"]},
		{"name": "Mei", "weekly_seconds": 11 * h + 300, "walking": false, "joined_unix": start,
			"look": {"skin_tone": 1, "hair_tone": 0, "cosmetics": {"hair": "hair_long", "face": "face_freckles"}},
			"shelf": ["cat_legendary", "bird_epic", "monkey_rare"], "focused_seconds": 260 * h,
			"gifts": ["cat_legendary", "cat_common", "cat_rare", "cat_epic", "bird_epic", "bird_common", "monkey_rare", "monkey_common", "snail_common", "bear_common"]},
		{"name": "Jordan", "weekly_seconds": 45 * 60, "walking": false, "joined_unix": start + 40 * day,
			"look": {"skin_tone": 4, "hair_tone": 1, "cosmetics": {"hair": "hair_buzz", "face": "face_grin"}},
			"shelf": ["", "dog_common", ""], "focused_seconds": 3 * h, "gifts": ["dog_common"]},
		{"name": "Ellie", "weekly_seconds": 3 * h + 1800, "walking": true, "joined_unix": start + 15 * day,
			"look": {"skin_tone": 0, "hair_tone": 4, "cosmetics": {"hair": "hair_bun", "face": "face_smile"}},
			"shelf": ["rabbit_epic", "", ""], "focused_seconds": 28 * h, "gifts": ["rabbit_epic", "rabbit_common", "rabbit_rare"]},
	]
