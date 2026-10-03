extends Node
class_name EnemyMovement

const GRAVITY := 900.0
const SPEED := 42.0
const ROAM_SPEED := 25.0
const CHASE_SPEED := 55.0
const AIR_FRICTION := 250.0

const SEARCH_DURATION := 7.0

const GROUND_AHEAD_DISTANCE := 46.0
const GROUND_AHEAD_DROP := 14.0
const WALL_AHEAD_DISTANCE := 56.0


var enemy: Enemy_1
var combat: EnemyCombat

var dir := Vector2.LEFT
var facing_direction := -1.0

var is_enemy_chase := false

var last_known_player_position := Vector2.ZERO
var search_timer := 0.0


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

	update_ai(delta, player)
	check_for_obstacles()

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
	enemy.velocity.x = move_toward(enemy.velocity.x, facing_direction * CHASE_SPEED, 300.0 * delta)
	dir = Vector2(facing_direction, 0.0)
	_apply_facing()

func update_ai(delta: float, player: CharacterBody2D) -> void:
	if enemy.can_see_player():
		last_known_player_position = player.global_position
		is_enemy_chase = true
		search_timer = SEARCH_DURATION
		move_toward_player(delta, player)
	elif is_enemy_chase:
		search(delta)
	else:
		roam(delta)

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

	# This enemy sprite is facing left by default.
	enemy.anim_sprite.scale.x = -1.0 if facing_direction > 0.0 else 1.0
	enemy.deal_damage_zone.scale.x = -facing_direction
	enemy.player_detection_area.scale.x = -facing_direction
	enemy.ground_ahead_ray.target_position = Vector2(facing_direction * GROUND_AHEAD_DISTANCE, GROUND_AHEAD_DROP)
	enemy.wall_ahead_ray.target_position = Vector2(facing_direction * WALL_AHEAD_DISTANCE, 0.0)

func check_for_obstacles() -> void:
	if not enemy.is_on_floor() or enemy.velocity.x == 0.0:
		return

	enemy.ground_ahead_ray.force_raycast_update()
	enemy.wall_ahead_ray.force_raycast_update()

	if not enemy.ground_ahead_ray.is_colliding() or enemy.wall_ahead_ray.is_colliding():
		facing_direction *= -1.0
		dir = Vector2(facing_direction, 0.0)
		enemy.velocity.x = 0.0
		_apply_facing()

func on_direction_timer_timeout() -> void:
	if not is_enemy_chase and combat.state == EnemyCombat.State.NORMAL:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		facing_direction = sign(dir.x)
		_apply_facing()
	enemy.enemy_direction_timer_reset()

func choose(array):
	array.shuffle()
	return array.front()

func roam(delta: float) -> void:
	if combat.state == EnemyCombat.State.NORMAL:
		enemy.velocity.x = move_toward(enemy.velocity.x, dir.x * ROAM_SPEED, 300.0 * delta)
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 400.0 * delta)
	
	facing_direction = sign(dir.x)
	_apply_facing()

func search(delta: float) -> void:
	search_timer -= delta
	
	var dx := last_known_player_position.x - enemy.global_position.x
	
	if absf(dx) > 5.0:
		facing_direction = sign(dx)
		enemy.velocity.x = move_toward(enemy.velocity.x, facing_direction * SPEED, 300.0 * delta)
		_apply_facing()
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 400.0 * delta)
	
	if search_timer <= 0.0:
		is_enemy_chase = false
		dir = Vector2(facing_direction, 0.0)
		enemy.velocity.x = 0.0
		
