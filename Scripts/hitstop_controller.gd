extends Node
class_name HitstopController

## Screen-wide combat freeze that is independent of Engine.time_scale's delta.
## It uses real wall-clock time so a time_scale of 0 cannot deadlock the timer.

var active := false
var end_time_usec: int = 0
var previous_time_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func request(duration: float) -> void:
	if duration <= 0.0:
		return

	var now := Time.get_ticks_usec()
	var requested_end := now + int(duration * 1_000_000.0)

	if not active:
		active = true
		previous_time_scale = Engine.time_scale
		Engine.time_scale = 0.0
		end_time_usec = requested_end
	else:
		# Overlapping hits extend the freeze instead of creating competing timers.
		end_time_usec = max(end_time_usec, requested_end)

func _process(_delta: float) -> void:
	if not active:
		return

	if Time.get_ticks_usec() >= end_time_usec:
		Engine.time_scale = previous_time_scale
		active = false
		end_time_usec = 0
