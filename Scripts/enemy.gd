extends CharacterBody2D

class_name Enemy_1
#health
var health = 100
var health_max = 100
var health_min = 0

#damage
var dead: bool = false
var taking_damage: bool = false
var damage_to_deal = 20
var is_dealing_damage: bool = false

#physics elements
var dir: Vector2
const gravity = 900
var knockback_force = -75
var is_roaming: bool = true
const speed = 30
var is_enemy_chase: bool = true
var player: CharacterBody2D
var player_in_area: bool = false

@onready var deal_damage_zone = $EnemyDealDamageZone

func handle_animation():
	var anim_sprite = $AnimatedSprite2D
	if !dead and !taking_damage and !is_dealing_damage:
		anim_sprite.play("walk")
		if dir.x == 1:
			anim_sprite.flip_h = true
			deal_damage_zone.scale.x = -1
		elif dir.x == -1:
			anim_sprite.flip_h = false
			deal_damage_zone.scale.x = +1
	elif !dead and taking_damage and !is_dealing_damage:
		anim_sprite.play("hurt")
		await get_tree().create_timer(0.6).timeout
		taking_damage = false
	elif dead and is_roaming:
		is_roaming = false
		anim_sprite.play("death")
		await get_tree().create_timer(1).timeout
		handle_death()
	elif !dead and is_dealing_damage:
		anim_sprite.play("deal_damage")

func handle_death():
	self.queue_free()

func _process(delta: float) -> void:
	player = Global.playerBody #made a new global script for communication for values between scripts
	Global.enemyDamageAmount = damage_to_deal
	Global.enemyDamageZone = $EnemyDealDamageZone

	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0

	move(delta)
	handle_animation()
	move_and_slide()

func move(delta):
	if !dead:
		if !is_enemy_chase:
			velocity += dir * speed * delta
		elif is_enemy_chase and !taking_damage:
			var dir_to_player = position.direction_to(player.position) * speed
			velocity.x = dir_to_player.x
			dir.x = abs(velocity.x) / velocity.x
		elif taking_damage:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
		is_roaming = true
	elif dead:
		velocity.x = 0

func _on_direction_timer_timeout() -> void:
	$DirectionTimer.wait_time = choose([1.5,2.0,2.5]) #change wait t
	if !is_enemy_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0
func choose(array):
	array.shuffle()
	return array.front()

func _on_enemy_hurtbox_area_entered(area: Area2D) -> void:
	var damage = Global.playerDamageAmount
	if area  == Global.playerDamageZone:
		take_damage(damage)

func _on_enemy_deal_damage_zone_area_entered(area: Area2D) -> void:
	if area == Global.playerHitbox:
		is_dealing_damage = true 
		await get_tree().create_timer(1).timeout
		is_dealing_damage = false

func take_damage(damage):
	health -= damage
	taking_damage = true
	if health <= health_min:
		health = health_min
		dead = true
	print(str(self), "health", health)
