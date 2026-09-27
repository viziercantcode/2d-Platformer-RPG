extends Node
class_name EnemyCombat

const ATTACK_STARTUP = 0.3

var enemy

# Attack
var attack_startup_timer: float = 0.0
var can_damage_player: bool = false
var is_dealing_damage: bool = false
var player_hit_this_attack: bool = false

# Damage / health
var dead: bool = false
var taking_damage: bool = false
var damage_to_deal = 20
var health = 100
var health_max = 100
var health_min = 0
var knockback_force = -75

# Timers
var hurt_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

func setup(enemy_ref) -> void:
	enemy = enemy_ref

func update(delta: float) -> void:
	if hurt_timer > 0:
		hurt_timer -= delta
	else:
		if taking_damage:
			taking_damage = false

	if attack_startup_timer > 0:
		attack_startup_timer -= delta
	else:
		if is_dealing_damage and not can_damage_player:
			can_damage_player = true

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if not is_dealing_damage and attack_cooldown_timer <= 0:
		check_enemy_attack_hit()

func check_enemy_attack_hit() -> void:
	var areas_hit = enemy.deal_damage_zone.get_overlapping_areas()

	for area in areas_hit:
		if area == Global.playerHitbox:
			is_dealing_damage = true
			attack_startup_timer = ATTACK_STARTUP
			attack_cooldown_timer = 2.0
			player_hit_this_attack = false
			break

func on_enemy_hurtbox_area_entered(area: Area2D) -> void:
	var damage = Global.playerDamageAmount

	if area == Global.playerDamageZone:
		take_damage(damage)

func take_damage(damage) -> void:
	health -= damage
	taking_damage = true
	hurt_timer = 0.6

	var player = Global.playerBody
	if is_instance_valid(player):
		var knockback_dir = enemy.position.direction_to(player.position) * knockback_force
		enemy.velocity.x = knockback_dir.x

	if health <= health_min:
		health = health_min
		dead = true
		enemy.queue_free()

func on_animation_finished() -> void:
	if enemy.anim_sprite.animation == "deal_damage":
		is_dealing_damage = false
		player_hit_this_attack = false
		can_damage_player = false
		attack_cooldown_timer = 1.0
