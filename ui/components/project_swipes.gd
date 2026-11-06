class_name ProjectSwipes
extends RefCounted
## What swiping a project does, wherever its row is (the Projects screen or
## the project list on the choose-focus screen), so both behave exactly the
## same: left to right deletes it (it shrinks away red, with a few seconds
## to undo); right to left completes an ongoing one (a green flash that
## holds while confetti flies, then it fades away) or puts a completed one
## back to ongoing (an amber flash, then it fades). Once it has faded the
## rest of the list closes up; a list that still shows it brings it back
## where it now belongs with SwipeRow.arrive().


## A swipeable row holding `panel`, set up for project `p`: a completed one
## swipes back to ongoing (an hourglass) instead of completing.
static func row(panel: Control, p: ProjectData) -> SwipeRow:
	var r := SwipeRow.new(panel)
	if p.is_complete():
		r.left_colour = UI.SERIES[1]
		r.left_icon = "hourglass"
	return r


## Acts on a swipe of row `swipe` (project `id`) in `direction` (+1 right, -1
## left), playing its animation first: the row fades and its gap closes.
## Await it: it returns once the project has changed.
static func act(direction: int, swipe: SwipeRow, id: String) -> void:
	var p := App.state.project(id)
	if p == null:
		swipe.spring_back()
		return
	if direction > 0:
		var at := App.state.projects.find(p)
		await swipe.vanish()
		App.delete_project(id)
		Toast.show_action(Text.t("projects.deleted", {"project": p.name}), "bin", Text.t("common.undo"), func():
			App.restore_project(p, at), "danger")
	elif p.is_complete():
		await swipe.celebrate(UI.SERIES[1], false)
		await swipe.collapse()
		App.reopen_project(id)
		Toast.show_text(Text.t("projects.reopened", {"project": p.name}), "hourglass")
	else:
		Audio.play("project_complete")
		await swipe.celebrate()
		await swipe.collapse()
		App.complete_project(id)
		Toast.show_action(Text.t("projects.completed_toast", {"project": p.name}), "check", Text.t("common.undo"), func():
			App.reopen_project(id), "success")
