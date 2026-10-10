extends Node
class_name PlayerFootsteps

# Step interval at a walk and run. The player's normal maximum speed is 200.
const SLOW_STEP_INTERVAL := 0.44
const FAST_STEP_INTERVAL := 0.28
const MIN_MOVE_SPEED := 18.0

# Keep pitch changes subtle so the same footstep sample stays natural.
const MIN_PITCH := 0.94
const MAX_PITCH := 1.08
const ACCELERATION_PITCH_BONUS := 0.025

var player: Player
var step_timer := 0.0
var previous_horizontal_speed := 0.0

func setup(player_ref: Player) -> void:
	player = player_ref
	previous_horizontal_speed = absf(player.velocity.x)

func update(delta: float) -> void:
	if player == null:
		return

	var horizontal_speed := absf(player.velocity.x)
	var has_movement_input := absf(Input.get_axis("ui_left", "ui_right")) > 0.0
	var is_ground_moving := player.is_on_floor() and has_movement_input and horizontal_speed >= MIN_MOVE_SPEED
	var is_in_action: bool = player.movement.is_dashing or player.health.dead or player.combat.is_attacking
	var acceleration := 0.0
	if delta > 0.0:
		acceleration = maxf(0.0, (horizontal_speed - previous_horizontal_speed) / delta)
	previous_horizontal_speed = horizontal_speed

	if not is_ground_moving or is_in_action:
		step_timer = 0.0
		if player.footst_sfx.playing:
			player.footst_sfx.stop()
		return

	var speed_ratio := clampf(horizontal_speed / player.movement.max_speed, 0.0, 1.0)
	var interval := lerpf(SLOW_STEP_INTERVAL, FAST_STEP_INTERVAL, speed_ratio)
	# Acceleration makes the next step arrive a little sooner, capped to avoid
	# footstep bursts from sudden velocity changes or frame-rate spikes.
	var acceleration_ratio := clampf(acceleration / player.movement.acceleration, 0.0, 1.0)
	interval *= 1.0 - 0.06 * acceleration_ratio

	step_timer -= delta
	if step_timer <= 0.0:
		var acceleration_pitch := ACCELERATION_PITCH_BONUS * acceleration_ratio
		player.footst_sfx.pitch_scale = clampf(
			lerpf(MIN_PITCH, MAX_PITCH, speed_ratio) + acceleration_pitch,
			MIN_PITCH,
			MAX_PITCH
		)
		player.footst_sfx.play()
		step_timer = interval
