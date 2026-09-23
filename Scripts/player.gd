extends CharacterBody2D

# Movement speeds
const MAX_SPEED = 200.0
const ACCELERATION = 600.0
const FRICTION = 800.0  # How quickly player slows down when no input

# Jump mechanics
const JUMP_FORCE = -400.0
const MAX_FALL_SPEED = 400.0
const GRAVITY = 1200.0

# Air control
const AIR_ACCELERATION = 500.0  # Reduced acceleration in air
const AIR_FRICTION = 200.0  # Air resistance

# Forgiving input mechanics
const COYOTE_TIME = 0.1  # Frames after leaving ground you can still jump
const JUMP_BUFFER_TIME = 0.1  # Frames before landing you can press jump

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust: GPUParticles2D = $dust

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var is_moving = abs(velocity.x) > 10  # For dust particles
	var on_ground = is_on_floor()
	
	# Update timers
	if on_ground:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
	
	jump_buffer_timer -= delta  # Count down the buffer timer every frame (this remembers the jump for 0.1s)
	
	# Dust particles
	dust.emitting = is_moving and on_ground
	
	# Apply gravity
	if not on_ground:
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)  # Terminal velocity
	
	# Handle jump input
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	
	# Execute jump if conditions are met
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_FORCE
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	# Handle horizontal movement
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		# Accelerate towards max speed
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		# Apply friction
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	
	move_and_slide()
	update_animation(direction)


func update_animation(direction: float) -> void:
	# Flip sprite based on direction
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	var target_animation: String = "Idle"

	# Determine animation state
	if not is_on_floor():
		if velocity.y < -50:
			target_animation = "Jump_start"
		elif velocity.y >= -50 and velocity.y <= 50:
			target_animation = "Jump_middle"
		else:
			target_animation = "Jump_end"
	elif direction != 0:
		target_animation = "Run"
	else:
		target_animation = "Idle"


	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)
