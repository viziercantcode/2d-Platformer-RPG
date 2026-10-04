extends Node
class_name EnemyCombat

enum State {
	NORMAL,
	ATTACK,
	HURT,
	DEAD
}

var enemy: Enemy_1
var state: State = State.NORMAL

var dead := false
var taking_damage := false
var is_dealing_damage := false
var can_damage_player := false
var player_hit_this_attack := false

var health := 100
var health_max := 100
var damage_to_deal := 20
var attack_startup := 0.25
var attack_active := 0.10
var attack_recovery := 0.35
var attack_cooldown := 1.40
var attack_trigger_distance := 72.0
var hurt_duration := 0.69
var hurt_invulnerability := 0.04
var knockback_force := 180.0
var hitstop_on_hurt := -1.0

var attack_timer := 0.0
var hurt_timer := 0.0
var invulnerability_timer := 0.0
var attack_cooldown_timer := 0.0
var death_started := false

func setup(enemy_ref: Enemy_1) -> void:
	enemy = enemy_ref
	health_max = enemy.health_max
	health = health_max
	damage_to_deal = enemy.damage_to_deal
	attack_startup = enemy.attack_startup
	attack_active = enemy.attack_active
	attack_recovery = enemy.attack_recovery
	attack_cooldown = enemy.attack_cooldown
	attack_trigger_distance = enemy.attack_trigger_distance
	hurt_duration = enemy.hurt_duration
	hurt_invulnerability = enemy.hurt_invulnerability
	knockback_force = enemy.knockback_force
	hitstop_on_hurt = enemy.hitstop_on_hurt
	_set_attack_hitbox_enabled(false)

func update(delta: float) -> void:
	if not is_instance_valid(enemy):
		return

	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)

	if state == State.DEAD:
		_set_attack_hitbox_enabled(false)
		return

	if state == State.HURT:
		hurt_timer = max(hurt_timer - delta, 0.0)
		if hurt_timer <= 0.0:
			state = State.NORMAL
			taking_damage = false
		return

	if state == State.ATTACK:
		_update_attack(delta)
		return

	if enemy.health_blocked_for_attack() or not enemy.is_on_floor():
		return

	if attack_cooldown_timer <= 0.0 and _player_in_attack_range():
		_start_attack()

func _player_in_attack_range() -> bool:
	var player := Global.playerBody
	if not is_instance_valid(player) or player.health == null:
		return false
	if player.health.dead or player.health.hurt:
		return false

	var dx: float = absf(player.global_position.x - enemy.global_position.x)
	var dy: float = absf(player.global_position.y - enemy.global_position.y)
	return dx <= attack_trigger_distance and dy <= 55.0

func _start_attack() -> void:
	state = State.ATTACK
	is_dealing_damage = true
	can_damage_player = false
	player_hit_this_attack = false
	attack_timer = 0.0
	_set_attack_hitbox_enabled(false)
	enemy.movement.face_player()

func _update_attack(delta: float) -> void:
	attack_timer += delta
	var active_start := attack_startup
	var active_end := attack_startup + attack_active
	var total := attack_startup + attack_active + attack_recovery

	if attack_timer >= active_start and attack_timer < active_end:
		can_damage_player = true
		_set_attack_hitbox_enabled(true)
		_check_attack_hit()
	else:
		can_damage_player = false
		_set_attack_hitbox_enabled(false)

	if attack_timer >= total:
		_finish_attack()

func _check_attack_hit() -> void:
	if player_hit_this_attack or not can_damage_player:
		return

	var player := Global.playerBody
	if not is_instance_valid(player) or player.health.dead:
		return

	for area in enemy.deal_damage_zone.get_overlapping_areas():
		if area == null or not is_instance_valid(area):
			continue
		if area != player.get_node_or_null("PlayerHitbox"):
			continue

		var direction: float = sign(player.global_position.x - enemy.global_position.x)
		if direction == 0.0:
			direction = enemy.movement.facing_direction

		var knockback := Vector2(direction * knockback_force, 0.0)
		
		if player.health.take_damage(damage_to_deal, knockback, direction):
			player_hit_this_attack = true

func _finish_attack() -> void:
	state = State.NORMAL
	is_dealing_damage = false
	can_damage_player = false
	player_hit_this_attack = false
	attack_timer = 0.0
	attack_cooldown_timer = attack_cooldown
	_set_attack_hitbox_enabled(false)

func take_damage_from_player(
	damage: int,
	knockback: float,
	attack_direction: float,
	hitstop_override: float
) -> bool:
	if damage <= 0 or dead:
		return false
	if invulnerability_timer > 0.0:
		return false

	health = max(health - damage, 0)
	invulnerability_timer = hurt_invulnerability

	# Being hurt interrupts an enemy attack.
	_cancel_attack()

	var away_direction: float = signf(enemy.global_position.x - Global.playerBody.global_position.x)
	if away_direction == 0.0:
		away_direction = attack_direction

	enemy.velocity.x = away_direction * knockback
	enemy.spawn_blood_particles(attack_direction)

	var effective_hitstop := hitstop_override
	if effective_hitstop < 0.0:
		effective_hitstop = enemy.default_hitstop
	if effective_hitstop > 0.0:
		Global.playerBody.combat.request_hitstop(effective_hitstop)

	if health <= 0:
		_start_death()
	else:
		state = State.HURT
		taking_damage = true
		hurt_timer = hurt_duration

	return true

func _start_death() -> void:
	if dead:
		return

	dead = true
	state = State.DEAD
	taking_damage = false
	is_dealing_damage = false
	can_damage_player = false
	player_hit_this_attack = false
	_set_attack_hitbox_enabled(false)
	enemy.velocity = Vector2.ZERO
	enemy.on_death_started()

func _cancel_attack() -> void:
	state = State.NORMAL if not dead else State.DEAD
	is_dealing_damage = false
	can_damage_player = false
	player_hit_this_attack = false
	attack_timer = 0.0
	_set_attack_hitbox_enabled(false)

func _set_attack_hitbox_enabled(enabled: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var collision := enemy.deal_damage_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = not enabled

func on_animation_finished() -> void:
	if enemy.anim_sprite.animation == "death" and dead:
		enemy.queue_free()

func kill_from_spikes() -> void:
	if dead:
		return
	#handling death anims for eneemy
	dead = true
	state = State.DEAD
	taking_damage = false
	is_dealing_damage = false
	can_damage_player = false
	player_hit_this_attack = false
	_set_attack_hitbox_enabled(false)

	enemy.velocity = Vector2.ZERO
	enemy.on_death_started()
