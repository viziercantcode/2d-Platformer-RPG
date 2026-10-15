extends Node
class_name PlayerMovement

enum MovementState { IDLE, RUN, JUMP, FALL, DASH, LEDGE_HANG, CLIMB }

@export_category("Ground Movement")
@export var max_speed := 200.0
@export var acceleration := 600.0
@export var friction := 800.0
@export_category("Air Movement")
@export var air_acceleration := 500.0
@export var air_friction := 220.0
@export_category("Jump")
@export var jump_force := -480.0
@export var double_jump_force := -480.0
@export var gravity := 1200.0
@export var max_fall_speed := 400.0
@export_category("Dash")
@export var dash_distance := 200.0
@export var dash_duration := 0.4
@export var dash_iframe_duration := 0.25
@export var dash_cooldown := 0.35

@export_category("Ledge Grab")
@export var ledge_hold_offset := 0.0
@export var climb_forward_distance := 15.0
@export var climb_vertical_distance := -30.0
@export var climb_animation_offset_y := 28.0
@export_range(0.0, 1.0, 0.01) var climb_end_offset_start := 0.50
@export var climb_fallback_duration := 0.40
@export var climb_floor_snap_length := 64.0

# Forgiving input mechanics
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.10
const LEDGE_COLLISION_MASK := 1
signal dash_finished

var player: Player
var combat: PlayerCombat
var health: PlayerHealth
var state: MovementState = MovementState.IDLE
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_invulnerability_timer := 0.0
var dash_direction := 1.0
var can_double_jump := true
var dash_key_was_down := false
var ledge_cooldown_timer := 0.0
var climb_elapsed := 0.0
var climb_duration := 0.0
var climb_start_position := Vector2.ZERO
var climb_target_position := Vector2.ZERO
var original_collision_layer := 0
var original_collision_mask := 0
var original_floor_snap_length := 0.0
var ledge_wall_cast: RayCast2D
var ledge_clear_cast: ShapeCast2D
var player_collision_shape: CollisionShape2D

var is_dashing: bool:
	get:
		return state == MovementState.DASH

var is_ledge_hanging: bool:
	get:
		return state == MovementState.LEDGE_HANG

var is_climbing: bool:
	get:
		return state == MovementState.CLIMB

var is_ledge_locked: bool:
	get:
		return is_ledge_hanging or is_climbing

func setup(player_ref: Player, combat_ref: PlayerCombat, health_ref: PlayerHealth) -> void:
	player = player_ref
	combat = combat_ref
	health = health_ref
	ledge_wall_cast = player.get_node_or_null("LedgeWallCast") as RayCast2D
	ledge_clear_cast = player.get_node_or_null("LedgeClearCast") as ShapeCast2D
	player_collision_shape = player.get_node_or_null("CollisonShape2D") as CollisionShape2D
	original_collision_layer = player.collision_layer
	original_collision_mask = player.collision_mask
	original_floor_snap_length = player.floor_snap_length
	_configure_ledge_casts()

func update(delta: float) -> float:
	if health.dead or health.healing:
		cancel_dash()
		_cancel_ledge_state()
		player.velocity = Vector2.ZERO
		return 0.0

	_update_timers(delta)
	if not is_climbing and player.is_on_floor() and player.floor_snap_length != original_floor_snap_length:
		player.floor_snap_length = original_floor_snap_length
	var direction := Input.get_axis("ui_left", "ui_right")
	var jump_pressed := Input.is_action_just_pressed("ui_accept")
	var dash_pressed := Input.is_key_pressed(KEY_SHIFT)

	if health.hurt and is_ledge_locked:
		_cancel_ledge_state()
		player.velocity = Vector2.ZERO
		_set_dust_enabled(false)
		return direction

	if is_ledge_hanging:
		_update_ledge_hang(jump_pressed)
		_set_dust_enabled(false)
		return direction

	if is_climbing:
		_update_climb(delta)
		_set_dust_enabled(false)
		return direction

	if jump_pressed and not health.hurt and not combat.is_attacking:
		jump_buffer_timer = JUMP_BUFFER_TIME
	if direction != 0.0 and not is_dashing and not health.hurt and not combat.is_attacking:
		player.set_facing(sign(direction))
	if dash_pressed and not dash_key_was_down and can_dash():
		start_dash(direction)
	dash_key_was_down = dash_pressed

	if is_dashing:
		_update_dash(delta)
		_set_dust_enabled(false)
		return direction

	_update_on_ground_state(delta)
	if not health.hurt and not combat.is_attacking:
		_try_jump()

	if state == MovementState.JUMP or state == MovementState.FALL:
		_update_in_air(direction, delta)
	else:
		_update_on_ground(direction, delta)

	if not health.hurt and not combat.is_attacking and _try_grab_ledge():
		_set_dust_enabled(false)
		return direction

	_update_state(direction)
	_set_dust_enabled(state == MovementState.RUN and absf(player.velocity.x) > 10.0 and not health.hurt and not combat.is_attacking)
	return direction

func _update_timers(delta: float) -> void:
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	dash_invulnerability_timer = maxf(dash_invulnerability_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	ledge_cooldown_timer = maxf(ledge_cooldown_timer - delta, 0.0)

func _configure_ledge_casts() -> void:
	if ledge_wall_cast == null or ledge_clear_cast == null:
		return
	ledge_wall_cast.collision_mask = LEDGE_COLLISION_MASK
	ledge_clear_cast.collision_mask = LEDGE_COLLISION_MASK
	ledge_wall_cast.enabled = true
	ledge_clear_cast.enabled = true
	ledge_wall_cast.exclude_parent = true
	ledge_clear_cast.exclude_parent = true

func _update_ledge_cast_direction() -> void:
	if ledge_wall_cast == null or ledge_clear_cast == null:
		return
	ledge_wall_cast.target_position.x = absf(ledge_wall_cast.target_position.x) * player.facing_direction
	ledge_clear_cast.target_position.x = absf(ledge_clear_cast.target_position.x) * player.facing_direction
	ledge_wall_cast.force_raycast_update()
	ledge_clear_cast.force_shapecast_update()

func _try_grab_ledge() -> bool:
	if ledge_wall_cast == null or ledge_clear_cast == null:
		return false
	if ledge_cooldown_timer > 0.0 or player.is_on_floor() or player.velocity.y <= 0.0:
		return false

	_update_ledge_cast_direction()
	if not ledge_wall_cast.is_colliding() or ledge_clear_cast.is_colliding():
		return false

	var wall_normal := ledge_wall_cast.get_collision_normal()
	if absf(wall_normal.x) < 0.70 or wall_normal.x * player.facing_direction > -0.50:
		return false

	_enter_ledge_hang(ledge_wall_cast.get_collision_point())
	return true

func _enter_ledge_hang(wall_point: Vector2) -> void:
	state = MovementState.LEDGE_HANG
	player.velocity = Vector2.ZERO
	jump_buffer_timer = 0.0
	player.collision_layer = 0
	player.collision_mask = LEDGE_COLLISION_MASK
	if player_collision_shape != null:
		player_collision_shape.disabled = true
	player.global_position.x = wall_point.x - player.facing_direction * ledge_hold_offset
	player.animated_sprite.speed_scale = 1.0
	player.animated_sprite.play("Ledge_grab")

func _update_ledge_hang(jump_pressed: bool) -> void:
	player.velocity = Vector2.ZERO
	_update_ledge_cast_direction()
	if ledge_wall_cast != null and not ledge_wall_cast.is_colliding():
		_cancel_ledge_state()
		state = MovementState.FALL
		return
	if jump_pressed:
		_start_climb()

func _start_climb() -> void:
	state = MovementState.CLIMB
	climb_elapsed = 0.0
	climb_start_position = player.global_position
	climb_target_position = climb_start_position + Vector2(
		player.facing_direction * climb_forward_distance,
		climb_vertical_distance
	)
	climb_duration = _get_animation_length("Climb")
	if climb_duration <= 0.0:
		climb_duration = climb_fallback_duration
	if player_collision_shape != null:
		player_collision_shape.disabled = true
	player.animated_sprite.offset = Vector2.ZERO
	player.animated_sprite.speed_scale = 1.0
	player.animated_sprite.play("Climb")

func _update_climb(delta: float) -> void:
	player.velocity = Vector2.ZERO
	climb_elapsed += delta
	var progress := clampf(climb_elapsed / climb_duration, 0.0, 1.0)
	player.global_position = climb_start_position.lerp(climb_target_position, progress)
	var end_offset_progress := inverse_lerp(climb_end_offset_start, 1.0, progress)
	player.animated_sprite.offset = Vector2(0.0, climb_animation_offset_y * clampf(end_offset_progress, 0.0, 1.0))
	if progress >= 1.0:
		_finish_climb()

func _finish_climb() -> void:
	player.global_position = climb_target_position
	player.velocity = Vector2.ZERO
	player.animated_sprite.offset = Vector2.ZERO
	if player_collision_shape != null:
		player_collision_shape.disabled = false
	player.collision_layer = original_collision_layer
	player.collision_mask = original_collision_mask
	player.floor_snap_length = maxf(original_floor_snap_length, climb_floor_snap_length)
	player.apply_floor_snap()
	state = MovementState.IDLE
	ledge_cooldown_timer = 0.12

func _cancel_ledge_state() -> void:
	if not is_ledge_hanging and not is_climbing:
		return
	if player_collision_shape != null:
		player_collision_shape.disabled = false
	player.animated_sprite.offset = Vector2.ZERO
	player.collision_layer = original_collision_layer
	player.collision_mask = original_collision_mask
	player.floor_snap_length = original_floor_snap_length
	state = MovementState.FALL
	climb_elapsed = 0.0
	climb_duration = 0.0
	ledge_cooldown_timer = 0.12

func _get_animation_length(animation_name: String) -> float:
	var frames := player.animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(animation_name):
		return 0.0
	var fps := frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for frame_index in frames.get_frame_count(animation_name):
		total += frames.get_frame_duration(animation_name, frame_index)
	return total / fps

func _update_on_ground_state(delta: float) -> void:
	if player.is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
		if player.velocity.y > 0.0:
			player.velocity.y = 0.0
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		if state == MovementState.IDLE or state == MovementState.RUN:
			state = MovementState.FALL

func _try_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return
	if coyote_timer > 0.0:
		_jump(jump_force, false)
		coyote_timer = 0.0
	elif can_double_jump:
		_jump(double_jump_force, true)
		can_double_jump = false

func _jump(force: float, is_double_jump: bool) -> void:
	player.velocity.y = force
	jump_buffer_timer = 0.0
	state = MovementState.JUMP
	player.jumpst_sfx.play()
	player.play_jump_effect(is_double_jump)

func _update_on_ground(direction: float, delta: float) -> void:
	var target_speed := max_speed
	var current_acceleration := acceleration
	var current_friction := friction
	var multiplier := _get_action_movement_multiplier()
	target_speed *= multiplier
	current_acceleration *= multiplier
	current_friction *= multiplier
	_apply_horizontal_movement(direction, target_speed, current_acceleration, current_friction, delta)

func _update_in_air(direction: float, delta: float) -> void:
	player.velocity.y = minf(player.velocity.y + gravity * delta, max_fall_speed)
	var target_speed := max_speed
	var current_acceleration := air_acceleration
	var current_friction := air_friction
	var multiplier := _get_action_movement_multiplier()
	target_speed *= multiplier
	current_acceleration *= multiplier
	current_friction *= multiplier
	_apply_horizontal_movement(direction, target_speed, current_acceleration, current_friction, delta)

func _apply_horizontal_movement(direction: float, target_speed: float, current_acceleration: float, current_friction: float, delta: float) -> void:
	if health.hurt:
		player.velocity.x = move_toward(player.velocity.x, 0.0, current_friction * 0.75 * delta)
	elif direction != 0.0:
		player.velocity.x = move_toward(player.velocity.x, direction * target_speed, current_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, current_friction * delta)

func _get_action_movement_multiplier() -> float:
	if combat.is_attacking:
		return float(combat.current_attack_data.get("move_multiplier", 0.4))
	return 1.0

func _update_state(direction: float) -> void:
	if not player.is_on_floor():
		state = MovementState.JUMP if player.velocity.y < 0.0 else MovementState.FALL
	elif absf(player.velocity.x) > 0.01 and direction != 0.0:
		state = MovementState.RUN
	else:
		state = MovementState.IDLE

func is_dash_invulnerable() -> bool:
	return is_dashing and dash_invulnerability_timer > 0.0

func cancel_dash() -> void:
	if not is_dashing:
		return
	dash_timer = 0.0
	dash_invulnerability_timer = 0.0
	dash_cooldown_timer = dash_cooldown
	state = MovementState.FALL if not player.is_on_floor() else MovementState.IDLE

func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0 and not health.dead and not health.hurt

func start_dash(direction: float) -> void:
	if combat.is_attacking:
		combat.interrupt_for_dash()
	dash_direction = sign(direction) if direction != 0.0 else player.facing_direction
	dash_timer = dash_duration
	dash_invulnerability_timer = dash_iframe_duration
	state = MovementState.DASH
	player.set_facing(dash_direction)
	player.play_dash_effect(dash_direction)

func _update_dash(delta: float) -> void:
	dash_timer = maxf(dash_timer - delta, 0.0)
	var progress := 1.0 - (dash_timer / dash_duration)
	var speed_factor := 1.0
	if progress < 0.10:
		speed_factor = progress / 0.10
	elif progress >= 0.7:
		speed_factor = 1.0 - ((progress - 0.7) / 0.3)
	player.velocity.x = dash_direction * (dash_distance / (dash_duration * 0.92)) * speed_factor
	player.velocity.y *= 0.92
	if dash_timer <= 0.0:
		state = MovementState.FALL if not player.is_on_floor() else MovementState.IDLE
		dash_cooldown_timer = dash_cooldown
		player.velocity.x = 0.0
		dash_finished.emit()

func _set_dust_enabled(enabled: bool) -> void:
	player.dust.emitting = enabled
