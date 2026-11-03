class_name FocusSession
extends RefCounted
## One finished walk, as the end screens show it. Walks aren't kept one by
## one: each adds its time to the day's totals (GameState.days) and its XP
## to the running total.

var project_id: String = ""
var pet_id: String = ""
var animal_id: String = ""
## The place it was walked in.
var place_id: String = ""
var start_unix: int = 0
var end_unix: int = 0
## Time actually walked, excluding pauses.
var focus_seconds: int = 0
## Empty when the walk was too short for a gift.
var gift_id: String = ""
