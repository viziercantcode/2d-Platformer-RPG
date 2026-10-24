extends CharacterBody2D
class_name Boss

const GRAVITY := 900.0
const SPIT_PROJECTILE_SPEED := 220.0
const BURST_PROJECTILE_SPEED := 300.0
const PROJECTILE_SCENE := preload("res://Scenes/boss_projectile.tscn")
const HIT_SOUND := preload("res://Assets/SFX/Boss/impacts/Impact 4.wav")
const FOOTSTEPS: Array[AudioStream] = [
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 1.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 2.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 3.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 4.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 5.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 6.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 7.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 8.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 9.wav"),
	preload("res://Assets/SFX/Boss/footsteps/metal/Metal footstep 10.wav")
]
const DIALOGUE: Array[AudioStream] = [
	preload("res://Assets/SFX/Boss/monster_voice/come_to_us.wav"),
	preload("res://Assets/SFX/Boss/monster_voice/end_it_all.wav"),
	preload("res://Assets/SFX/Boss/monster_voice/i_can_hear_you.wav"),
	preload("res://Assets/SFX/Boss/monster_voice/save_us.wav"),
	preload("res://Assets/SFX/Boss/monster_voice/spill_thy_blood.wav"),
	preload("res://Assets/SFX/Boss/monster_voice/the_pain.wav"),
	preload("res://Assets/SFX/Boss/monster_voice/we_mean_no_harm.wav")
]

@export_category("Boss combat")
@export var health_max := 1200
@export var damage_to_deal := 30
@export var attack_distance := Vector2(100.0, 8.0)
@export var intro_active := true
@export var hurt_duration := 0.05
@export var hurt_invulnerability := 0.04
@export var knockback_force := 180.0
@export var move_speed := 65.0
@export var hitstop_on_hurt := 0.1
@export var default_hitstop := 0.06

@export_category("Boss attacks")
@export var slam_damage := 30
@export var slam_knockback := 180.0
@export var spit_damage := 30
@export var spit_knockback := 320.0
@export var burst_damage := 30
@export var burst_knockback := 320.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: CollisionShape2D = $EnemyHitbox/CollisionShape2D
@onready var attack_shape: CollisionShape2D = $EnemyDealDamageZone/CollisionShape2D
@onready var ground_ahead_ray: RayCast2D = $GroundAheadRay
@onready var state_manager: BossStateManager = $StateManager
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sounds: Node2D = $Sounds

var health := 1200
var facing_direction := -1.0
var dead := false
var taking_damage := false
var invulnerability_timer := 0.0
var hurt_timer := 0.0
var hit_flash_timer := 0.0
var attack_window_active := false
var attack_hit := false
var _rng := RandomNumberGenerator.new()
var _idle_state_duration := 0.6
var _walk_state_duration := 1.8
var _vanish_wait := -1.0
var _default_attack_shape_position := Vector2.ZERO
var _default_attack_shape_size := Vector2.ZERO

func _ready() -> void:
	health = health_max
	_rng.randomize()
	var attack_rectangle := attack_shape.shape as RectangleShape2D
	if attack_rectangle != null:
		attack_rectangle = attack_rectangle.duplicate() as RectangleShape2D
		attack_shape.shape = attack_rectangle
		_default_attack_shape_size = attack_rectangle.size
	_default_attack_shape_position = attack_shape.position
	attack_shape.disabled = true
	hitbox.disabled = false
	anim.animation_finished.connect(_on_animation_finished)
	state_manager.setup(self)
	Global.enemyDamageZone = $EnemyDealDamageZone
	Global.enemyDamageAmount = damage_to_deal

func _exit_tree() -> void:
	if Global.enemyDamageZone == get_node_or_null("EnemyDealDamageZone"):
		Global.enemyDamageZone = null
		Global.enemyDamageAmount = 0

func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_combat(delta)
	if dead:
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 600.0)
	else:
		velocity.y = 0.0
	Global.enemyDamageZone = $EnemyDealDamageZone
	Global.enemyDamageAmount = damage_to_deal
	state_manager.update(delta)
	if state_manager.current_state != &"walk":
		velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
	move_and_slide()
	_check_player_hit()
	_update_hit_flash(delta)

func _enter_state(state: StringName) -> void:
	attack_shape.set_deferred("disabled", true)
	_reset_attack_shape()
	if state in [&"idle", &"walk", &"slam", &"spit", &"burst"]:
		hitbox.set_deferred("disabled", false)
	attack_window_active = false
	attack_hit = false
	velocity.x = 0.0
	match state:
		&"intro":
			hitbox.set_deferred("disabled", true)
			_play("DiveAttack")
		&"idle":
			_idle_state_duration = _rng.randf_range(0.4, 0.8)
			_play("Idle")
			if not _sound("Dialogue").playing:
				_sound("Dialogue").stream = DIALOGUE[_rng.randi_range(0, DIALOGUE.size() - 1)]
				_sound("Dialogue").play()
		&"walk":
			_walk_state_duration = _rng.randf_range(1.4, 2.4)
			_play("Walk")
		&"slam":
			_face_player()
			_play("SlamAttack")
		&"spit":
			_face_player()
			_play("SpitAttack")
		&"burst":
			_face_player()
			_play("Burst")
		&"vanish":
			_vanish_wait = -1.0
			_play("Vanish")
			modulate.a = 1.0
		&"dive":
			var player := Global.playerBody
			if not is_instance_valid(player) or player.health.dead:
				state_manager.change_state(&"idle")
				return
			hitbox.set_deferred("disabled", true)
			modulate.a = 1.0
			global_position = player.global_position
			velocity.y = 0.0
			_play("DiveAttack")
		&"death":
			dead = true
			velocity = Vector2.ZERO
			attack_shape.set_deferred("disabled", true)
			_play("Death")

func _update_state(delta: float) -> void:
	var elapsed := state_manager.state_time
	var player := Global.playerBody
	if state_manager.current_state == &"intro":
		if not intro_active:
			state_manager.change_state(&"idle")
		return
	if state_manager.current_state == &"idle":
		if elapsed >= _idle_state_duration:
			state_manager.change_state(&"walk")
		return
	if state_manager.current_state == &"walk":
		if not is_instance_valid(player) or player.health.dead:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			return
		_face_player()
		var player_distance := absf(player.global_position.x - global_position.x)
		var walk_direction := 0.0
		if player_distance > attack_distance.x:
			walk_direction = facing_direction
		if walk_direction != 0.0 and is_on_floor():
			ground_ahead_ray.force_raycast_update()
			if not ground_ahead_ray.is_colliding():
				walk_direction = 0.0
		velocity.x = move_toward(velocity.x, walk_direction * move_speed, 300.0 * delta)
		if is_zero_approx(velocity.x) and player_distance <= attack_distance.x:
			if animation_player.current_animation == &"Walk":
				animation_player.stop()
			_sound("Steps").stop()
			anim.play(&"Idle")
		else:
			if animation_player.current_animation != &"Walk":
				_play("Walk")
			else:
				anim.play(&"Walk")
		if absf(player.global_position.x - global_position.x) > 400.0:
			state_manager.change_state(&"vanish")
			return
		if elapsed > _walk_state_duration:
			_choose_attack()
		return
	if state_manager.current_state == &"vanish":
		velocity.x = 0.0
		if _vanish_wait >= 0.0:
			_vanish_wait -= delta
			if _vanish_wait <= 0.0:
				state_manager.change_state(&"dive")
		return
func animation_attack_start(position: Vector2, size: Vector2) -> void:
	attack_window_active = true
	attack_hit = false
	_set_attack_shape(true, position, size)

func animation_attack_shape(position: Vector2, size: Vector2) -> void:
	_set_attack_shape(attack_window_active, position, size)

func animation_attack_end() -> void:
	attack_window_active = false
	attack_shape.set_deferred("disabled", true)

func animation_spit_projectile() -> void:
	_spawn_projectile(
		Vector2(facing_direction * SPIT_PROJECTILE_SPEED, 0.0),
		Vector2(facing_direction * 35.0, -19.0),
		false,
		spit_damage,
		spit_knockback
	)

func animation_burst_projectiles() -> void:
	_spawn_burst_projectiles()

func animation_enable_hurtbox() -> void:
	hitbox.set_deferred("disabled", false)

func animation_vanish_hurtbox() -> void:
	hitbox.set_deferred("disabled", true)

func animation_camera_shake() -> void:
	var player := Global.playerBody
	if is_instance_valid(player):
		var camera := player.get_node_or_null("Camera2D")
		if camera != null and camera.has_method("shake"):
			camera.shake(4.0)

func animation_footstep() -> void:
	var steps := _sound("Steps")
	steps.stream = FOOTSTEPS[_rng.randi_range(0, FOOTSTEPS.size() - 1)]
	steps.play()

func _choose_attack() -> void:
	var player := Global.playerBody
	if not is_instance_valid(player) or player.health.dead:
		state_manager.change_state(&"idle")
		return
	var horizontal_distance := absf(player.global_position.x - global_position.x)
	if horizontal_distance > 400.0:
		state_manager.change_state(&"vanish")
		return
	var vertical_distance := absf(player.global_position.y - global_position.y)
	var roll := _rng.randf()
	if horizontal_distance <= attack_distance.x and vertical_distance <= attack_distance.y and roll < 0.6:
		state_manager.change_state(&"slam")
	elif roll < 0.4:
		state_manager.change_state(&"spit")
	elif roll < 0.8:
		state_manager.change_state(&"burst")
	else:
		state_manager.change_state(&"vanish")

func _spawn_burst_projectiles() -> void:
	var origin := Vector2(0.0, -15.0)
	var spawn_offsets: Array[Vector2] = [
		Vector2(-22.0, -29.0),
		Vector2(-10.0, -40.0),
		Vector2(14.0, -40.0),
		Vector2(24.0, -29.0)
	]
	for spawn_offset in spawn_offsets:
		var local_direction := spawn_offset - origin
		local_direction.x *= facing_direction
		_spawn_projectile(
			local_direction.normalized() * BURST_PROJECTILE_SPEED,
			Vector2(spawn_offset.x * facing_direction, spawn_offset.y),
			true,
			burst_damage,
			burst_knockback
		)

func _set_attack_shape(enabled: bool, local_position: Vector2, size: Vector2) -> void:
	attack_shape.position = Vector2(local_position.x * facing_direction, local_position.y)
	var rectangle := attack_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = size
	attack_shape.set_deferred("disabled", not enabled)

func _reset_attack_shape() -> void:
	_set_attack_shape(false, Vector2(absf(_default_attack_shape_position.x), _default_attack_shape_position.y), _default_attack_shape_size)

func _on_animation_finished() -> void:
	match state_manager.current_state:
		&"intro": state_manager.change_state(&"idle")
		&"slam", &"spit", &"burst": state_manager.change_state(&"idle")
		&"dive": state_manager.change_state(&"idle")
		&"vanish":
			modulate.a = 0.0
			_vanish_wait = _rng.randf_range(0.2, 1.0)
		&"death": queue_free()

func take_damage_from_player(damage: int, knockback: float, attack_direction: float, _hitstop := 0.06) -> bool:
	if dead or invulnerability_timer > 0.0 or damage <= 0:
		return false
	health = maxi(health - damage, 0)
	invulnerability_timer = hurt_invulnerability
	if is_instance_valid(Global.playerBody) and is_instance_valid(Global.playerBody.combat):
		var effective_hitstop := _hitstop if _hitstop >= 0.0 else default_hitstop
		if effective_hitstop > 0.0:
			Global.playerBody.combat.request_hitstop(effective_hitstop)
	var away_direction := signf(global_position.x - Global.playerBody.global_position.x) if is_instance_valid(Global.playerBody) else signf(attack_direction)
	if away_direction == 0.0:
		away_direction = signf(attack_direction)
	modulate.a = 1.0
	_spawn_hit_effect(attack_direction)
	if health <= 0:
		state_manager.change_state(&"death")
	else:
		taking_damage = true
		hurt_timer = hurt_duration
		velocity.x = away_direction * knockback
		var impact := _sound("AnimB")
		impact.stream = HIT_SOUND
		impact.play()
	return true

func _update_combat(delta: float) -> void:
	if invulnerability_timer > 0.0:
		invulnerability_timer = maxf(invulnerability_timer - delta, 0.0)
	if taking_damage:
		hurt_timer = maxf(hurt_timer - delta, 0.0)
		if hurt_timer <= 0.0 and not dead:
			taking_damage = false

func _spawn_hit_effect(attack_direction: float) -> void:
	var settings := {
		"amount": 8,
		"lifetime": 0.32,
		"spread": 35.0,
		"speed_min": 130.0,
		"speed_max": 300.0,
		"gravity": 620.0,
		"direction_y": -0.20,
		"damping_min": 5.0,
		"damping_max": 12.0,
		"color": Color(0.493, 0.101, 0.143, 1.0),
		"scale_min": 0.6,
		"scale_max": 1.2
	}
	BloodEffect.spawn(get_parent(), global_position + Vector2(0.0, -20.0), attack_direction, settings)
	HitEffect.spawn(get_parent(), global_position + Vector2(0.0, -20.0), attack_direction)
	hit_flash_timer = 0.09
	modulate = Color(1.0, 0.35, 0.35, modulate.a)

func _update_hit_flash(delta: float) -> void:
	if hit_flash_timer <= 0.0:
		return
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	if hit_flash_timer <= 0.0:
		modulate = Color(1.0, 1.0, 1.0, modulate.a)

func _check_player_hit() -> void:
	if dead or not attack_window_active or attack_hit:
		return
	var player := Global.playerBody
	if not is_instance_valid(player) or player.health.dead:
		return
	for area in $EnemyDealDamageZone.get_overlapping_areas():
		if area == player.get_node_or_null("PlayerHitbox"):
			var direction := signf(player.global_position.x - global_position.x)
			if direction == 0.0:
				direction = facing_direction
			var attack_damage := damage_to_deal
			var attack_knockback := knockback_force
			match state_manager.current_state:
				&"slam", &"dive":
					attack_damage = slam_damage
					attack_knockback = slam_knockback
				&"spit":
					attack_damage = spit_damage
					attack_knockback = spit_knockback
				&"burst":
					attack_damage = burst_damage
					attack_knockback = burst_knockback
			if player.health.take_damage(attack_damage, Vector2(direction * attack_knockback, 0.0), direction):
				attack_hit = true

func _spawn_projectile(
	projectile_velocity: Vector2,
	local_offset: Vector2,
	uses_gravity: bool,
	projectile_damage: int,
	projectile_knockback: float
) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as BossProjectile
	projectile.initialize(global_position + local_offset, projectile_velocity, uses_gravity, self)
	projectile.damage = projectile_damage
	projectile.knockback_force = projectile_knockback
	get_tree().current_scene.add_child(projectile)

func _face_player() -> void:
	var player := Global.playerBody
	if is_instance_valid(player):
		var dx := player.global_position.x - global_position.x
		if dx != 0.0:
			facing_direction = signf(dx)
			anim.flip_h = facing_direction < 0.0
			attack_shape.position.x = absf(_default_attack_shape_position.x) * facing_direction
			ground_ahead_ray.target_position = Vector2(facing_direction * 46.0, 14.0)

func _play(animation_name: StringName) -> void:
	var sprite_animation: StringName = &"Intro_DiveAttack" if animation_name == &"DiveAttack" else animation_name
	var animation_duration := 0.0
	if animation_player.has_animation(String(animation_name)):
		animation_duration = animation_player.get_animation(String(animation_name)).length
	var sprite_duration := _sprite_animation_duration(sprite_animation)
	anim.speed_scale = sprite_duration / animation_duration if animation_duration > 0.0 and sprite_duration > 0.0 else 1.0
	if animation_player.has_animation(String(animation_name)):
		animation_player.play(String(animation_name))

func _sprite_animation_duration(animation_name: StringName) -> float:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(animation_name):
		return 0.0
	var fps := anim.sprite_frames.get_animation_speed(animation_name)
	var frames := anim.sprite_frames.get_frame_count(animation_name)
	var duration := 0.0
	for i in frames:
		duration += anim.sprite_frames.get_frame_duration(animation_name, i)
	return duration / maxf(fps, 1.0)

func _sound(node_name: String) -> AudioStreamPlayer2D:
	return sounds.get_node(node_name) as AudioStreamPlayer2D
