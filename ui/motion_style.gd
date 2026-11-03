class_name MotionStyle
extends Resource
## How the app moves, in one place you can change in the Godot editor:
## double-click ui/motion.tres and change any of these in the Inspector.
## Every animation in the app goes through Motion, which reads this.

@export_group("Everything")
## Above 1 every animation is quicker; below 1, slower.
@export_range(0.25, 3.0, 0.05) var speed := 1.0
## The shape of every animation's curve (Sine is soft, Quad and Cubic a
## little firmer, Back overshoots).
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
## Whether animations ease in, out or both.
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Choosing a place")
## How long one place takes to fade into the next; the place buttons'
## highlight slides in the same time.
@export_range(0.0, 3.0, 0.05, "suffix:s") var place_fade := 0.6

@export_group("Setting off on a walk")
## The screen's words and buttons fading away once you pick a pet.
@export_range(0.0, 3.0, 0.05, "suffix:s") var leave_fade := 0.34
## Your pet walking over to its place on the path.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pet_to_path := 0.9
## You walking in from the left to join it.
@export_range(0.0, 5.0, 0.05, "suffix:s") var walk_in := 1.6
## The lead appearing.
@export_range(0.0, 3.0, 0.05, "suffix:s") var lead_in := 0.35
## The pause, once the lead's on, before you set off together.
@export_range(0.0, 5.0, 0.05, "suffix:s") var set_off_wait := 1.0
## The scenery getting up to walking speed.
@export_range(0.0, 5.0, 0.05, "suffix:s") var speed_up := 0.8
## How far the project's name and the time drop as they fade in.
@export_range(0.0, 60.0, 1.0, "suffix:px") var drop := 14.0
## Typing out the encouragement: each letter, and the extra pause at each
## space between words.
@export_range(0.0, 0.5, 0.005, "suffix:s") var type_letter := 0.045
@export_range(0.0, 1.0, 0.01, "suffix:s") var type_space := 0.16
## How often the encouragement changes, in minutes of focus.
@export_range(1, 120, 1, "suffix:min") var quote_every := 10

@export_group("Arriving home after making an account")
## The view tilting up from the hilltop to the sky.
@export_range(0.0, 5.0, 0.05, "suffix:s") var account_rise := 1.6
## Then the focus orb growing from nothing (the greeting then drops in and
## types itself out like a walk's encouragement)...
@export_range(0.0, 3.0, 0.05, "suffix:s") var orb_grow := 0.6
## ...and "Tap to focus" rising this far as it fades in...
@export_range(0.0, 60.0, 1.0, "suffix:px") var hint_rise := 14.0
## ...before the map, the arrows and the home icon fade in.
@export_range(0.0, 3.0, 0.05, "suffix:s") var home_ui_fade := 0.6

@export_group("Focus complete")
## How far the gift's glow reaches (on a screen 720 tall).
@export_range(0.0, 200.0, 1.0, "suffix:px") var glow_radius := 44.0
## How much the scenery dims around your pet.
@export_range(0.0, 1.0, 0.01) var dim := 0.25
## Your pet turning round to show you the gift.
@export_range(0.0, 2.0, 0.02, "suffix:s") var turn := 0.28
