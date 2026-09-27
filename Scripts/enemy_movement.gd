extends Node
class_name EnemyMovement

const GRAVITY = 900.0
const SPEED = 30.0

var enemy
var combat: EnemyCombat

var dir: Vector2
var is_roaming: bool = true
var is_enemy_chase: bool = true

func setup(enemy_ref, combat_ref: EnemyCombat) -> void:
	enemy = enemy_ref
	combat = combat_ref

func update(delta: float) -> void:
	var player = Global.playerBody
	if not is_instance_valid(player):
		return

	if not enemy.is_on_floor():
		enemy.velocity.y += GRAVITY * delta

	move(delta, player)

func move(delta: float, player) -> void:
	if combat.dead:
		enemy.velocity.x = 0
		return

	# Stop completely while attacking.
	if combat.is_dealing_damage:
		enemy.velocity.x = 0
		return

	# Knockback has priority.
	if combat.taking_damage:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, 180 * delta)
	# Then chasing.
	elif is_enemy_chase:
		var dir_to_player = enemy.position.direction_to(player.position) * SPEED
		enemy.velocity.x = dir_to_player.x
		if enemy.velocity.x != 0:
			dir.x = sign(enemy.velocity.x)
	# Then roaming.
	elif is_roaming:
		enemy.velocity += dir * SPEED * delta

func on_direction_timer_timeout() -> void:
	enemy_direction_timer_reset()

	if not is_enemy_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		enemy.velocity.x = 0

func enemy_direction_timer_reset() -> void:
	enemy.get_node("DirectionTimer").wait_time = choose([1.5, 2.0, 2.5])

func choose(array):
	array.shuffle()
	return array.front()
