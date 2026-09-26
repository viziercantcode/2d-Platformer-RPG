extends CharacterBody2D

#Attack mechanics
var attack_type: String
var current_attack: bool

var health = 1000
var health_max = 100
var health_min = 0
var can_take_damage: bool
var dead: bool

# Movement speeds
const MAX_SPEED = 200.0
const ACCELERATION = 600.0
const FRICTION = 800.0  # How quickly player slows down when no input

# Dash mechanics
const DASH_SPEED = 500.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.3

# Jump mechanics
const JUMP_FORCE = -400.0
const DOUBLE_JUMP_FORCE = -300.0
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
@onready var deal_damage_zone = $DealDamageZone

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var can_double_jump: bool = true

func _ready() -> void:
	dead = false
	can_take_damage = true
	Global.playerBody = self
	Global.playerAlive = true
	current_attack = false

	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox = $PlayerHitbox
	
	var is_moving = abs(velocity.x) > 10  # For dust particles
	var on_ground = is_on_floor()
	if !dead:
	# Update timers
		if on_ground:
			coyote_timer = COYOTE_TIME
			can_double_jump = true
		else:
			coyote_timer -= delta
		
		jump_buffer_timer -= delta  # Count down the buffer timer every frame (this remembers the jump for 0.1s)
		
		dash_cooldown_timer -= delta
		# Handle dash input
		var direction := Input.get_axis("ui_left", "ui_right")
		
		if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown_timer <= 0 and not is_dashing:
			start_dash(direction)
		
		# Dust particles
		dust.emitting = is_moving and on_ground
		
		if is_dashing:
			dash_timer -= delta
			velocity.x = dash_direction * DASH_SPEED
			velocity.y = 0
			
			if dash_timer <= 0:
				is_dashing = false
				dash_cooldown_timer = DASH_COOLDOWN
		else:
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
			elif jump_buffer_timer > 0 and can_double_jump:
				velocity.y = DOUBLE_JUMP_FORCE
				can_double_jump = false
				jump_buffer_timer = 0.0
			
			# Handle horizontal movement
			if direction != 0:
				# Accelerate towards max speed
				velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
			else:
				# Apply friction
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		#handling attack mechanics
		if !current_attack:
			if Input.is_action_just_pressed("Left_mouse") or Input.is_action_just_pressed("Right_mouse"):
				current_attack = true
				if Input.is_action_just_pressed("Left_mouse") and is_on_floor():
					attack_type = "single"
				elif Input.is_action_just_pressed("Right_mouse") and is_on_floor():
					attack_type = "double"
				else:
					attack_type = "air"
				set_damage(attack_type)
				handle_attack_animation(attack_type)
		update_animation(direction)
		check_hitbox()
	move_and_slide()

func check_hitbox():
	var hitbox_areas = $PlayerHitbox.get_overlapping_areas()
	var damage: int
	if hitbox_areas:
		var hitbox = hitbox_areas.front()
		if hitbox.get_parent() is Enemy_1:
			damage = Global.enemyDamageAmount
			
	if can_take_damage:
		take_damage(damage)

func take_damage(damage):
	if damage != 0:
		if health > 0:
			health -= damage
			print(health)
			if health <= 0:
				health = 0
				dead = true
				Global.playerAlive = false
				handle_death_animation()
			take_damage_cooldown()

func take_damage_cooldown():
	can_take_damage = false
	await get_tree().create_timer(1.5).timeout
	can_take_damage = true

func start_dash(direction: float) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	
	if direction != 0:
		dash_direction = sign(direction)
	elif animated_sprite.flip_h:
		dash_direction = -1.0
	else:
		dash_direction = 1.0
	velocity.y = 0

func handle_death_animation():
	animated_sprite.play("death")
	await get_tree().create_timer(1).timeout
	self.queue_free()

func handle_attack_animation(attack_type):
	if current_attack:
		var animation = str(attack_type, "_attack")
		animated_sprite.play(animation)
		toggle_damage_collision(attack_type)

func toggle_damage_collision(attack_type):
	var damage_zone_collison = deal_damage_zone.get_node("CollisionShape2D")
	var wait_time: float 
	if attack_type == "air":
		wait_time = 0.35
	elif attack_type == "single":
		wait_time = 0.3
	elif attack_type == "double":
		wait_time = 0.35
	damage_zone_collison.disabled = false
	await get_tree().create_timer(wait_time).timeout
	damage_zone_collison.disabled = true

func set_damage(attack_type):
	var current_damage_to_deal: int
	if attack_type == "single":
		current_damage_to_deal = 8
	elif attack_type == "double":
		current_damage_to_deal = 16
	elif attack_type == "air":
		current_damage_to_deal = 20
	Global.playerDamageAmount = current_damage_to_deal

func _on_animation_finished() -> void:
	if current_attack and animated_sprite.animation == str(attack_type, "_attack"):
		current_attack = false

func update_animation(direction: float) -> void:
	# Don't let movement/idle animations override an active attack animation
	if current_attack:
		if direction > 0:
			animated_sprite.flip_h = false
		elif direction < 0:
			animated_sprite.flip_h = true
		return

	if not is_dashing:
		# Flip sprite based on direction
		if direction > 0:
			animated_sprite.flip_h = false
			deal_damage_zone.scale.x = 1
		elif direction < 0:
			animated_sprite.flip_h = true
			deal_damage_zone.scale.x = -1

	var target_animation: String = "Idle"

	# Determine animation state
	if is_dashing:
		target_animation = "Dash"
	elif not is_on_floor():
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
