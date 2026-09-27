extends Node
class_name PlayerCombat

const HURT_DURATION = 0.3

var player

# Attack mechanics
var attack_type: String = ""
var current_attack: bool = false
var attack_hit_this_frame: bool = false

# Health
var health = 100
var health_max = 100
var health_min = 0
var dead: bool = false
var hurt_timer: float = 0.0

func setup(player_ref) -> void:
	player = player_ref

func update_before_movement(delta: float) -> void:
	# Check whether an enemy is attacking the player.
	check_hitbox()

	# Check player attack hits.
	if current_attack and not attack_hit_this_frame:
		check_attack_hit()

	# Hurt timer.
	if hurt_timer > 0:
		hurt_timer -= delta

func update_after_movement() -> void:
	if dead:
		return

	if not current_attack and hurt_timer <= 0:
		if Input.is_action_just_pressed("Left_mouse") or Input.is_action_just_pressed("Right_mouse"):
			current_attack = true

			if Input.is_action_just_pressed("Left_mouse") and player.is_on_floor():
				attack_type = "single"
				player.slash1_sfx.play()
			elif Input.is_action_just_pressed("Right_mouse") and player.is_on_floor():
				attack_type = "double"
				player.slash2_sfx.play()
			else:
				attack_type = "air"
				player.slash1_sfx.play()

			set_damage(attack_type)
			handle_attack_animation(attack_type)

func check_hitbox() -> void:
	var hitbox_areas = player.get_node("PlayerHitbox").get_overlapping_areas()

	for enemy_area in hitbox_areas:
		var enemy = enemy_area.get_parent()

		if enemy is Enemy_1:
			if enemy.combat.is_dealing_damage and enemy.combat.can_damage_player and not enemy.combat.player_hit_this_attack:
				enemy.combat.player_hit_this_attack = true
				take_damage(enemy.combat.damage_to_deal)
				player.update_animation(0)
				return

func take_damage(damage) -> void:
	print("DAMAGE RECEIVED:", damage)
	print("HEALTH BEFORE:", health)

	if damage <= 0:
		return
	if health <= 0:
		return
	if hurt_timer > 0:
		return

	health -= damage
	hurt_timer = HURT_DURATION

	current_attack = false
	attack_hit_this_frame = false
	player.deal_damage_zone.get_node("CollisionShape2D").disabled = true

	print("Player health: ", health)

	if health <= 0:
		health = 0
		dead = true
		Global.playerAlive = false
		hurt_timer = 0
		current_attack = false
		attack_hit_this_frame = false
		player.deal_damage_zone.get_node("CollisionShape2D").disabled = true

		handle_death_animation()

func check_attack_hit() -> void:
	var enemies_hit = player.deal_damage_zone.get_overlapping_areas()

	for enemy_area in enemies_hit:
		var parent = enemy_area.get_parent()

		if parent is Enemy_1 and enemy_area == parent.get_node("EnemyHitbox"):
			attack_hit_this_frame = true
			var knockback_dir = player.global_position.direction_to(parent.global_position) * -150
			player.velocity.x = knockback_dir.x
			break

func handle_attack_animation(type: String) -> void:
	if current_attack:
		var animation = str(type, "_attack")
		player.animated_sprite.play(animation)
		toggle_damage_collision()

func toggle_damage_collision() -> void:
	var damage_zone_collision = player.deal_damage_zone.get_node("CollisionShape2D")
	damage_zone_collision.disabled = false
	attack_hit_this_frame = false

func set_damage(type: String) -> void:
	var current_damage_to_deal: int

	if type == "single":
		current_damage_to_deal = 8
	elif type == "double":
		current_damage_to_deal = 16
	elif type == "air":
		current_damage_to_deal = 20
	else:
		current_damage_to_deal = 0

	Global.playerDamageAmount = current_damage_to_deal

func handle_death_animation() -> void:
	player.animated_sprite.play("death")
	await player.get_tree().create_timer(1).timeout
	player.queue_free()

func on_animation_finished() -> void:
	if current_attack and player.animated_sprite.animation == str(attack_type, "_attack"):
		player.deal_damage_zone.get_node("CollisionShape2D").disabled = true
		current_attack = false
		attack_hit_this_frame = false
