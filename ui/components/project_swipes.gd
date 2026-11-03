class_name ProjectSwipes
extends RefCounted
## What swiping a project does, wherever its row is (the Projects screen or
## the project list on the choose-focus screen), so both behave exactly the
## same: left to right deletes it (it shrinks away red, with a few seconds
## to undo); right to left completes an ongoing one (confetti and a green
## flash) or puts a completed one back to ongoing.


## A swipeable row holding `panel`, set up for project `p`: a completed one
## swipes back to ongoing (an hourglass) instead of completing.
static func row(panel: Control, p: ProjectData) -> SwipeRow:
	var r := SwipeRow.new(panel)
	if p.is_complete():
		r.left_colour = UI.SERIES[1]
		r.left_icon = "hourglass"
	return r


## Acts on a swipe of row `swipe` (project `id`) in `direction` (+1 right, -1
## left), playing its animation first. `keep_ongoing` / `keep_completed`
## say whether the row stays in its list once the project is ongoing /
## completed; otherwise its gap closes up. Await it: it returns once the
## project has changed.
static func act(direction: int, swipe: SwipeRow, id: String, keep_ongoing: bool, keep_completed: bool) -> void:
	var p := App.state.project(id)
	if p == null:
		swipe.spring_back()
		return
	if direction > 0:
		var at := App.state.projects.find(p)
		await swipe.vanish()
		App.delete_project(id)
		Toast.show_action(Text.t("projects.deleted", {"project": p.name}), "bin", Text.t("common.undo"), func():
			App.restore_project(p, at))
	elif p.is_complete():
		swipe.spring_back()
		if not keep_ongoing:
			await swipe.collapse()
		App.reopen_project(id)
		Toast.show_text(Text.t("projects.reopened", {"project": p.name}), "hourglass")
	else:
		Audio.play("project_complete")
		await swipe.celebrate()
		if not keep_completed:
			await swipe.collapse()
		App.complete_project(id)
		Toast.show_text(Text.t("projects.completed_toast", {"project": p.name}), "check")
