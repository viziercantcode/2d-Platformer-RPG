extends CharacterBody2D

class_name Enemy_1

# Health
var health = 100
var health_max = 100
var health_min = 0

# Attack
var attack_startup_timer: float = 0.0
const ATTACK_STARTUP = 0.3
var can_damage_player: bool = false

var is_dealing_damage: bool = false
var player_hit_this_attack: bool = false

# Damage
var dead: bool = false
var taking_damage: bool = false
var damage_to_deal = 20

# Physics
var dir: Vector2
const gravity = 900
var knockback_force = -75
var is_roaming: bool = true
const speed = 30
var is_enemy_chase: bool = true
var player: CharacterBody2D
var player_in_area: bool = false

# Animation timing (replacing await)
var hurt_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

@onready var deal_damage_zone = $EnemyDealDamageZone
@onready var hitbox = $EnemyHitbox/CollisionShape2D
@onready var anim_sprite = $AnimatedSprite2D

func _ready() -> void:
	anim_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	player = Global.playerBody
	
	if !is_instance_valid(player):
		return
	
	Global.enemyDamageAmount = damage_to_deal
	Global.enemyDamageZone = deal_damage_zone

	# Update timers
	if hurt_timer > 0:
		hurt_timer -= delta
	else:
		if taking_damage:
			taking_damage = false
	
	# Attack Startup timer
	if attack_startup_timer > 0:
		attack_startup_timer -= delta
	else:
		if is_dealing_damage and not can_damage_player:
			can_damage_player = true
	
	# Attack Cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	if !is_dealing_damage and attack_cooldown_timer <= 0:
		check_enemy_attack_hit()

	if !is_on_floor():
		velocity.y += gravity * delta

	move(delta)
	handle_animation()
	move_and_slide()

func move(delta):
	if dead:
		velocity.x = 0
		return
	
	# Stop completely while attacking
	if is_dealing_damage:
		velocity.x = 0
		return
	
	# Knockback has priority
	if taking_damage:
		velocity.x = move_toward(velocity.x, 0, 180 * delta)
	# Then chasing
	elif is_enemy_chase:
		if is_instance_valid(player):
			var dir_to_player = position.direction_to(player.position) * speed
			velocity.x = dir_to_player.x
			if velocity.x != 0:
				dir.x = sign(velocity.x)
	# Then roaming
	elif is_roaming:
		velocity += dir * speed * delta

func handle_animation():
	if dead:
		if anim_sprite.animation != "death":
			anim_sprite.play("death")
		return
	
	if taking_damage:
		if anim_sprite.animation != "hurt":
			anim_sprite.play("hurt")
		return
	
	if is_dealing_damage:
		if anim_sprite.animation != "deal_damage":
			anim_sprite.play("deal_damage")
		return
	
	if anim_sprite.animation != "walk" or not anim_sprite.is_playing():
		anim_sprite.play("walk")
	
	# Flip sprite based on direction
	if dir.x == 1:
		anim_sprite.scale.x = -1
		deal_damage_zone.scale.x = -1
		hitbox.scale.x = -1
	elif dir.x == -1:
		anim_sprite.scale.x = 1
		deal_damage_zone.scale.x = 1
		hitbox.scale.x = +1

func _on_direction_timer_timeout() -> void:
	$DirectionTimer.wait_time = choose([1.5, 2.0, 2.5])
	if !is_enemy_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0

func choose(array):
	array.shuffle()
	return array.front()

func check_enemy_attack_hit():
	var areas_hit = deal_damage_zone.get_overlapping_areas()
	
	for area in areas_hit:
		if area == Global.playerHitbox:
			is_dealing_damage = true
			attack_startup_timer = ATTACK_STARTUP
			attack_cooldown_timer = 2.0
			player_hit_this_attack = false
			break

func _on_enemy_hurtbox_area_entered(area: Area2D) -> void:
	var damage = Global.playerDamageAmount
	if area == Global.playerDamageZone:
		take_damage(damage)

func take_damage(damage):
	health -= damage
	taking_damage = true
	hurt_timer = 0.6
	
	# Apply knockback instantly
	var knockback_dir = position.direction_to(player.position) * knockback_force
	velocity.x = knockback_dir.x
	
	if health <= health_min:
		health = health_min
		dead = true
		queue_free()
	
	
func _on_animation_finished() -> void:
	if anim_sprite.animation == "deal_damage":
		is_dealing_damage = false
		player_hit_this_attack = false
		can_damage_player = false
		attack_cooldown_timer = 1.0
		
