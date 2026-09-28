extends Node
class_name EnemyMovement

const GRAVITY := 900.0
const SPEED := 42.0
const AIR_FRICTION := 250.0

var enemy: Enemy_1
var combat: EnemyCombat
var dir := Vector2.LEFT
var facing_direction := -1.0
var is_roaming := true
var is_enemy_chase := true

func setup(enemy_ref: Enemy_1, combat_ref: EnemyCombat) -> void:
	enemy = enemy_ref
	combat = combat_ref

func update(delta: float) -> void:
	var player := Global.playerBody
	if not is_instance_valid(player):
		return

	if not enemy.is_on_floor():
		enemy.velocity.y += GRAVITY * delta
		enemy.velocity.y = min(enemy.velocity.y, 500.0)
	else:
		if enemy.velocity.y > 0.0:
			enemy.velocity.y = 0.0

	if combat.dead:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 500.0 * delta)
		return

	if combat.state == EnemyCombat.State.ATTACK:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 900.0 * delta)
		return

	if combat.state == EnemyCombat.State.HURT:
		# Preserves the initial knockback, then let it end. Does not allow chase AI to immediately overwrite the hit reaction.
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 260.0 * delta)
		return

	move_toward_player(delta, player)

func move_toward_player(delta: float, player: CharacterBody2D) -> void:
	if not is_enemy_chase:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 250.0 * delta)
		return

	var dx := player.global_position.x - enemy.global_position.x
	var distance: float = absf(dx)

	if distance <= combat.attack_trigger_distance * 0.82:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 400.0 * delta)
		return

	facing_direction = sign(dx) if dx != 0.0 else facing_direction
	enemy.velocity.x = move_toward(enemy.velocity.x, facing_direction * SPEED, 300.0 * delta)
	dir = Vector2(facing_direction, 0.0)
	_apply_facing()

func face_player() -> void:
	var player := Global.playerBody
	if not is_instance_valid(player):
		return

	var dx := player.global_position.x - enemy.global_position.x
	if dx != 0.0:
		facing_direction = sign(dx)
	_apply_facing()

func _apply_facing() -> void:
	if facing_direction == 0.0:
		return

	# This enemy sprite is authored facing left by default.
	enemy.anim_sprite.scale.x = -1.0 if facing_direction > 0.0 else 1.0
	enemy.deal_damage_zone.scale.x = -facing_direction

func on_direction_timer_timeout() -> void:
	if not is_enemy_chase and combat.state == EnemyCombat.State.NORMAL:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		facing_direction = sign(dir.x)
		_apply_facing()
	enemy.enemy_direction_timer_reset()

func choose(array):
	array.shuffle()
	return array.front()
