extends Node
class_name PlayerMovement

enum MovementState { IDLE, RUN, JUMP, FALL, DASH }

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
@export var dash_distance := 150.0
@export var dash_duration := 0.22
@export var dash_iframe_duration := 0.18
@export var dash_cooldown := 0.35

# Forgiving input mechanics
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.10
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

var is_dashing: bool:
	get:
		return state == MovementState.DASH

func setup(player_ref: Player, combat_ref: PlayerCombat, health_ref: PlayerHealth) -> void:
	player = player_ref
	combat = combat_ref
	health = health_ref

func update(delta: float) -> float:
	if health.dead or health.healing:
		cancel_dash()
		player.velocity = Vector2.ZERO
		return 0.0

	_update_timers(delta)
	var direction := Input.get_axis("ui_left", "ui_right")
	var jump_pressed := Input.is_action_just_pressed("ui_accept")
	var dash_pressed := Input.is_key_pressed(KEY_SHIFT)

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

	_update_state(direction)
	_set_dust_enabled(state == MovementState.RUN and absf(player.velocity.x) > 10.0 and not health.hurt and not combat.is_attacking)
	return direction

func _update_timers(delta: float) -> void:
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	dash_invulnerability_timer = maxf(dash_invulnerability_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

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

func _update_dash(delta: float) -> void:
	dash_timer = maxf(dash_timer - delta, 0.0)
	var progress := 1.0 - (dash_timer / dash_duration)
	var speed_factor := 1.0
	if progress < 0.15:
		speed_factor = progress / 0.15
	elif progress >= 0.8:
		speed_factor = 1.0 - ((progress - 0.8) / 0.2)
	player.velocity.x = dash_direction * (dash_distance / (dash_duration * 0.92)) * speed_factor
	player.velocity.y *= 0.92
	if dash_timer <= 0.0:
		state = MovementState.FALL if not player.is_on_floor() else MovementState.IDLE
		dash_cooldown_timer = dash_cooldown
		player.velocity.x = 0.0
		dash_finished.emit()

func is_dash_invulnerable() -> bool:
	return is_dashing and dash_invulnerability_timer > 0.0

func cancel_dash() -> void:
	if not is_dashing:
		return
	dash_timer = 0.0
	dash_invulnerability_timer = 0.0
	dash_cooldown_timer = dash_cooldown
	state = MovementState.FALL if not player.is_on_floor() else MovementState.IDLE

func _set_dust_enabled(enabled: bool) -> void:
	player.dust.emitting = enabled
