extends Node
class_name PlayerMovement

# Movement speeds
const MAX_SPEED = 200.0
const ACCELERATION = 600.0
const FRICTION = 800.0

# Dash mechanics
const DASH_SPEED = 300.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.3

# Jump mechanics
const JUMP_FORCE = -400.0
const DOUBLE_JUMP_FORCE = -300.0
const MAX_FALL_SPEED = 400.0
const GRAVITY = 1200.0

# Air control
const AIR_ACCELERATION = 500.0
const AIR_FRICTION = 200.0

# Forgiving input mechanics
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.1

var player
var combat: PlayerCombat

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var can_double_jump: bool = true

func setup(player_ref, combat_ref: PlayerCombat) -> void:
	player = player_ref
	combat = combat_ref

func update(delta: float) -> float:
	var is_moving = abs(player.velocity.x) > 10
	var on_ground = player.is_on_floor()
	var direction := Input.get_axis("ui_left", "ui_right")

	# Update timers.
	if on_ground:
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else:
		coyote_timer -= delta

	jump_buffer_timer -= delta
	dash_cooldown_timer -= delta

	# Handle dash input.
	if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown_timer <= 0 and not is_dashing:
		start_dash(direction)

	# Dust particles.
	player.dust.emitting = is_moving and on_ground

	if is_dashing:
		dash_timer -= delta
		player.velocity.x = dash_direction * DASH_SPEED
		player.velocity.y = 0

		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown_timer = DASH_COOLDOWN
	else:
		# Apply gravity.
		if not on_ground:
			player.velocity.y += GRAVITY * delta
			player.velocity.y = min(player.velocity.y, MAX_FALL_SPEED)

		# Handle jump input.
		if Input.is_action_just_pressed("ui_accept"):
			jump_buffer_timer = JUMP_BUFFER_TIME

		# Execute jump if conditions are met.
		if jump_buffer_timer > 0 and coyote_timer > 0:
			player.velocity.y = JUMP_FORCE
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			player.jumpst_sfx.play()

		elif jump_buffer_timer > 0 and can_double_jump:
			player.velocity.y = DOUBLE_JUMP_FORCE
			can_double_jump = false
			jump_buffer_timer = 0.0
			player.jumpst_sfx.play()

		# Handle horizontal movement.
		if direction != 0:
			player.velocity.x = move_toward(
				player.velocity.x,
				direction * MAX_SPEED,
				ACCELERATION * delta
			)
		else:
			player.velocity.x = move_toward(
				player.velocity.x,
				0,
				FRICTION * delta
			)

	return direction

func start_dash(direction: float) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION

	if direction != 0:
		dash_direction = sign(direction)
	elif player.animated_sprite.flip_h:
		dash_direction = -1.0
	else:
		dash_direction = 1.0

	player.velocity.y = 0
