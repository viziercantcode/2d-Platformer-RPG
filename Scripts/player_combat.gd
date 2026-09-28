extends Node
class_name PlayerCombat

const BUFFER_DURATION := 0.15
const COMBO_RESET_TIME := 0.28
const LIGHT_COMBO_COUNT := 3

const ATTACK_LIGHT_1 := {
	"damage": 8,
	"startup": 0.15,
	"active": 0.10,
	"recovery": 0.10,
	"knockback": 145.0,
	"move_multiplier": 0.45,
	"animation": "Attack_light_1",
	"sfx": 1
}

const ATTACK_LIGHT_2 := {
	"damage": 10,
	"startup": 0.20,
	"active": 0.10,
	"recovery": 0.05,
	"knockback": 165.0,
	"move_multiplier": 0.42,
	"animation": "Attack_light_2",
	"sfx": 1
}

const ATTACK_LIGHT_3 := {
	"damage": 14,
	"startup": 0.10,
	"active": 0.10,
	"recovery": 0.10,
	"knockback": 185.0,
	"move_multiplier": 0.38,
	"animation": "Attack_light_3",
	"sfx": 2
}

const ATTACK_HEAVY := {
	"damage": 30,
	"startup": 0.25,
	"active": 0.15,
	"recovery": 0.30,
	"knockback": 210.0,
	"move_multiplier": 0.20,
	"animation": "Attack_heavy",
	"sfx": 2,
	"cooldown": 0.90
}

var player: CharacterBody2D
var health: PlayerHealth

var attack_type: String = ""
var current_attack: bool = false
var attack_hit_this_frame: bool = false
var dead: bool = false

var is_attacking: bool = false
var is_heavy_attack: bool = false
var combo_step: int = 0
var attack_elapsed: float = 0.0  # To determine startup, active or recovery
var current_attack_duration: float = 0.0
var hitbox_active: bool = false
var combo_chain_timer: float = 0.0
var input_buffer_timer: float = 0.0
var buffered_attack: int = 0  # 0 none, 1 light, 2 heavy
var heavy_cooldown_timer: float = 0.0

var current_attack_data: Dictionary = {}
var hit_targets: Dictionary = {}

const LIGHT := 1
const HEAVY := 2

func setup(player_ref: CharacterBody2D, health_ref: PlayerHealth) -> void:
	player = player_ref
	health = health_ref
	_disable_attack_hitbox()

func update(delta: float) -> void:
	# Checks if player and health exists
	if not is_instance_valid(player) or not is_instance_valid(health):
		return

	dead = health.dead
	if dead:
		_disable_attack_hitbox()
		return

	if heavy_cooldown_timer > 0.0:
		heavy_cooldown_timer = max(heavy_cooldown_timer - delta, 0.0)

	if combo_chain_timer > 0.0:
		combo_chain_timer = max(combo_chain_timer - delta, 0.0)
		if combo_chain_timer <= 0.0 and not is_attacking:
			combo_step = 0

	if input_buffer_timer > 0.0:
		input_buffer_timer = max(input_buffer_timer - delta, 0.0)
		if input_buffer_timer <= 0.0:
			buffered_attack = 0

	_capture_attack_input()

	# Disables attack if hurt.
	if health.hurt:
		_disable_attack_hitbox()
		buffered_attack = 0
		input_buffer_timer = 0.0
		return

	if is_attacking:
		_update_attack(delta)
	else:
		_try_start_buffered_attack()

func _capture_attack_input() -> void:
	if Input.is_action_just_pressed("Left_mouse"):
		_buffer_attack(LIGHT)

	if Input.is_action_just_pressed("Right_mouse"):
		_buffer_attack(HEAVY)

func _buffer_attack(type: int) -> void:
	buffered_attack = type
	input_buffer_timer = BUFFER_DURATION

func _try_start_buffered_attack() -> void:
	if buffered_attack == 0 or input_buffer_timer <= 0.0:
		return
	if player.movement.is_dashing:
		return

	var queued := buffered_attack
	buffered_attack = 0
	input_buffer_timer = 0.0

	if queued == HEAVY:
		if heavy_cooldown_timer <= 0.0:
			_start_heavy_attack()
		else:
			# Do not carry a heavy input indefinitely through its cooldown.
			combo_step = 0
		return

	_start_light_attack()

func _start_light_attack() -> void:
	is_attacking = true
	current_attack = true
	is_heavy_attack = false
	attack_type = "light"
	attack_elapsed = 0.0
	hit_targets.clear()
	attack_hit_this_frame = false
	_disable_attack_hitbox()

	if combo_chain_timer > 0.0 and combo_step > 0 and combo_step < LIGHT_COMBO_COUNT:
		combo_step += 1
	else:
		combo_step = 1

	current_attack_data = _get_light_attack_data(combo_step)
	current_attack_duration = _get_attack_total(current_attack_data)
	combo_chain_timer = 0.0

	_set_attack_facing()
	_play_attack_animation(current_attack_data)
	_play_attack_sfx(current_attack_data)
	Global.playerDamageAmount = int(current_attack_data.damage)
	Global.playerDamageZone = player.deal_damage_zone

func _start_heavy_attack() -> void:
	is_attacking = true
	current_attack = true
	is_heavy_attack = true
	attack_type = "heavy"
	attack_elapsed = 0.0
	combo_step = 0
	combo_chain_timer = 0.0
	hit_targets.clear()
	attack_hit_this_frame = false
	_disable_attack_hitbox()

	current_attack_data = ATTACK_HEAVY.duplicate()
	current_attack_duration = _get_attack_total(current_attack_data)
	heavy_cooldown_timer = float(current_attack_data.get("cooldown", 0.90))

	_set_attack_facing()
	_play_attack_animation(current_attack_data)
	_play_attack_sfx(current_attack_data)
	Global.playerDamageAmount = int(current_attack_data.damage)
	Global.playerDamageZone = player.deal_damage_zone

func _get_light_attack_data(step: int) -> Dictionary:
	match step:
		1:
			return ATTACK_LIGHT_1.duplicate()
		2:
			return ATTACK_LIGHT_2.duplicate()
		3:
			return ATTACK_LIGHT_3.duplicate()
	return ATTACK_LIGHT_1.duplicate()

func _get_attack_total(data: Dictionary) -> float:
	return float(data.startup) + float(data.active) + float(data.recovery)

func _update_attack(delta: float) -> void:
	if health.hurt or health.dead:
		return

	attack_elapsed += delta
	var startup := float(current_attack_data.startup)
	var active_end := startup + float(current_attack_data.active)
	var total := current_attack_duration

	if attack_elapsed >= startup and attack_elapsed < active_end:
		if not hitbox_active:
			_enable_attack_hitbox()
		_check_attack_hits()
	else:
		if hitbox_active:
			_disable_attack_hitbox()

	if attack_elapsed >= total:
		_finish_attack()

func _finish_attack() -> void:
	_disable_attack_hitbox()
	is_attacking = false
	current_attack = false
	attack_hit_this_frame = false
	attack_elapsed = 0.0
	current_attack_duration = 0.0
	current_attack_data = {}

	# A buffered light attack chains immediately only if it was pressed recently.
	if buffered_attack == LIGHT and input_buffer_timer > 0.0 and not health.hurt:
		buffered_attack = 0
		input_buffer_timer = 0.0
		if combo_step < LIGHT_COMBO_COUNT:
			_start_light_attack()
			return
		else:
			combo_step = 0
			_start_light_attack()
			return

	# Heavy is a separate branch and resets the normal combo sequence.
	if buffered_attack == HEAVY and input_buffer_timer > 0.0 and not health.hurt:
		buffered_attack = 0
		input_buffer_timer = 0.0
		if heavy_cooldown_timer <= 0.0:
			_start_heavy_attack()
			return

	buffered_attack = 0
	input_buffer_timer = 0.0
	combo_chain_timer = COMBO_RESET_TIME

func _enable_attack_hitbox() -> void:
	var collision := player.deal_damage_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	collision.disabled = false
	hitbox_active = true

func _disable_attack_hitbox() -> void:
	if not is_instance_valid(player):
		return
	var collision := player.deal_damage_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true
	hitbox_active = false

func _check_attack_hits() -> void:
	if not hitbox_active or health.hurt or health.dead:
		return

	for area in player.deal_damage_zone.get_overlapping_areas():
		if area == null or not is_instance_valid(area):
			continue
		if area.name != "EnemyHitbox":
			continue

		var enemy = area.get_parent()
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Enemy_1:
			continue
		if enemy.combat.dead:
			continue
		if hit_targets.has(enemy.get_instance_id()):
			continue

		var applied: bool = enemy.combat.take_damage_from_player(
			int(current_attack_data.damage),
			float(current_attack_data.knockback),
			player.facing_direction,
			float(enemy.hitstop_on_hurt)
		)

		if applied:
			hit_targets[enemy.get_instance_id()] = true
			attack_hit_this_frame = true

func interrupt_for_hurt() -> void:
	_disable_attack_hitbox()
	is_attacking = false
	current_attack = false
	is_heavy_attack = false
	attack_type = ""
	combo_step = 0
	attack_elapsed = 0.0
	current_attack_duration = 0.0
	current_attack_data = {}
	hit_targets.clear()
	attack_hit_this_frame = false
	buffered_attack = 0
	input_buffer_timer = 0.0
	combo_chain_timer = 0.0
	player.animated_sprite.speed_scale = 1.0

func interrupt_for_dash() -> void:
	# Dash cancels attacks.
	interrupt_for_hurt()

func interrupt_for_death() -> void:
	# Death cancels everything.
	interrupt_for_hurt()
	dead = true

func _set_attack_facing() -> void:
	player.set_facing(player.facing_direction)

func _play_attack_animation(data: Dictionary) -> void:
	var animation_name := str(data.animation)

	player.animated_sprite.speed_scale = 1.0
	player.animated_sprite.play(animation_name)

func _play_attack_sfx(data: Dictionary) -> void:
	var sfx_type := int(data.get("sfx", 1))
	if sfx_type == 2:
		player.slash2_sfx.play()
	else:
		player.slash1_sfx.play()

func request_hitstop(duration: float) -> void:
	if is_instance_valid(player.hitstop_controller):
		player.hitstop_controller.request(duration)

func on_animation_finished() -> void:
	# Attack timing is controlled by attack_elapsed, not animation_finished.
	# Keeping this method avoids breaking old signal/wrapper connections.
	if player.animated_sprite.animation == "death":
		return
