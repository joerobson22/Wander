class_name Gestures
extends RefCounted
## Shared pointer rules, so one drag never does two things. A control that
## takes over the pointer (lifting a gift to drag it) sets `claimed` until
## the pointer is released, and the app shell won't turn that into a swipe.

## How far a press can wander and still count as a tap.
const TAP_SLOP := 12.0
## Hold this long without moving to pick something up.
const LONG_PRESS := 0.35
## Gifts in the shelf editor pick up sooner: dragging them about is what
## that screen is for.
const QUICK_HOLD := 0.15
## How far a gift that picks up as soon as it's dragged moves first.
const LIFT_SLOP := 5.0

static var claimed := false
## Set when a press lands on something that picks up as soon as it's
## dragged (a gift, with a mouse), so the drag isn't taken for a scroll.
## Cleared by each new press.
static var lifts := false
## Set when a press lands on something that swipes sideways itself (a
## project on the projects screen), so a sideways drag isn't taken for a
## swipe between screens. Cleared by each new press.
static var sideways := false
