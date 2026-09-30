extends Node
class_name PlayerMovement

# Movement speeds
const MAX_SPEED := 200.0
const ACCELERATION := 600.0
const FRICTION := 800.0
const AIR_ACCELERATION := 500.0
const AIR_FRICTION := 220.0

# Dash mechanics
const DASH_DISTANCE: float = 130.0
const DASH_DURATION: float = 0.22
const DASH_ACC_TIME: float = 0.04
const DASH_DEC_TIME: float = 0.04
const DASH_IFRAME_DURATION: float = 0.18
const DASH_COOLDOWN: float = 0.35

# Jump mechanics
const JUMP_FORCE := -450
const DOUBLE_JUMP_FORCE := -400
const MAX_FALL_SPEED := 400.0
const GRAVITY := 1200.0

# Forgiving input mechanics
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.10

var player: CharacterBody2D
var combat: PlayerCombat
var health: PlayerHealth

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_invulnerability_timer := 0.0
var dash_direction := 1.0
var can_double_jump := true
var dash_key_was_down := false

func setup(player_ref: CharacterBody2D, combat_ref: PlayerCombat, health_ref: PlayerHealth) -> void:
	player = player_ref
	combat = combat_ref
	health = health_ref

func update(delta: float) -> float:
	if health.dead:
		cancel_dash()
		player.velocity = Vector2.ZERO
		return 0.0

	var on_ground := player.is_on_floor()
	var direction := Input.get_axis("ui_left", "ui_right")
	var dash_key_down := Input.is_key_pressed(KEY_SHIFT)

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	if dash_invulnerability_timer > 0.0:
		dash_invulnerability_timer = max(dash_invulnerability_timer - delta, 0.0)
	if coyote_timer > 0.0 and not on_ground:
		coyote_timer = max(coyote_timer - delta, 0.0)
	if on_ground:
		coyote_timer = COYOTE_TIME
		can_double_jump = true

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if direction != 0.0 and not is_dashing and not health.hurt and not combat.is_attacking:
		player.set_facing(sign(direction))

	# Shift is edge-triggered. Holding Shift no longer auto-repeats dashes.
	if dash_key_down and not dash_key_was_down:
		if can_dash():
			start_dash(direction)
	dash_key_was_down = dash_key_down

	if is_dashing:
		_update_dash(delta)
		player.dust.emitting = false
		return direction

	# Gravity still acts during attack/hurt states.
	if not on_ground:
		player.velocity.y += GRAVITY * delta
		player.velocity.y = min(player.velocity.y, MAX_FALL_SPEED)
	else:
		if player.velocity.y > 0.0:
			player.velocity.y = 0.0
	
	# Handle Jump input
	# Jump is disabled during attack/hurt states.
	if not health.hurt and not combat.is_attacking and Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	
	if not health.hurt and not combat.is_attacking:
		# Execute jump.
		if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			player.velocity.y = JUMP_FORCE
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			player.jumpst_sfx.play()
		# Execute double jump.
		elif jump_buffer_timer > 0.0 and can_double_jump:
			player.velocity.y = DOUBLE_JUMP_FORCE
			can_double_jump = false
			jump_buffer_timer = 0.0
			player.jumpst_sfx.play()
	
	var target_speed := MAX_SPEED
	var acceleration := ACCELERATION
	var friction := FRICTION
	
	if not on_ground:
		acceleration = AIR_ACCELERATION
		friction = AIR_FRICTION
	
	# Player slows down during attack.
	if combat.is_attacking:
		var multiplier := float(combat.current_attack_data.get("move_multiplier", 0.4))
		target_speed *= multiplier
		acceleration *= multiplier
		friction *= multiplier

	if health.hurt:
		# Knockback owns the initial velocity, input cannot override it immediately.
		player.velocity.x = move_toward(player.velocity.x, 0.0, friction * 0.75 * delta)
	elif direction != 0.0:
		player.velocity.x = move_toward(player.velocity.x, direction * target_speed, acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, friction * delta)

	player.dust.emitting = abs(player.velocity.x) > 10.0 and on_ground and not health.hurt and not combat.is_attacking
	return direction

func can_dash() -> bool:
	if is_dashing or dash_cooldown_timer > 0.0:
		return false
	if health.dead or health.hurt:
		return false
	return true

func start_dash(direction: float) -> void:
	# Dash cancels an attack.
	if combat.is_attacking:
		combat.interrupt_for_dash()

	is_dashing = true
	dash_timer = DASH_DURATION
	dash_invulnerability_timer = DASH_IFRAME_DURATION

	if direction != 0.0:
		dash_direction = sign(direction)
	else:
		dash_direction = player.facing_direction

	player.set_facing(dash_direction)
	player.animated_sprite.play("Dash")

func _update_dash(delta: float) -> void:
	dash_timer = max(dash_timer - delta, 0.0)
	
	var progress: float = 1.0 - (dash_timer / DASH_DURATION)
	var speed_factor: float
	
	if progress < 0.15:
		# Acceleration
		speed_factor = progress / 0.15
	elif progress < 0.8:
		# Main dash
		speed_factor = 1.0
	else:
		# Deceleration
		speed_factor = 1.0 - ((progress - 0.80) / 0.20)
	
	var dash_speed: float = DASH_DISTANCE / (DASH_DURATION * 0.92)
	
	player.velocity.x = dash_direction * dash_speed * speed_factor

	if dash_timer <= 0.0:
		is_dashing = false
		dash_cooldown_timer = DASH_COOLDOWN
		player.velocity.x = 0.0

func is_dash_invulnerable() -> bool:
	return is_dashing and dash_invulnerability_timer > 0.0

func cancel_dash() -> void:
	if is_dashing:
		is_dashing = false
		dash_timer = 0.0
		dash_invulnerability_timer = 0.0
		dash_cooldown_timer = DASH_COOLDOWN
