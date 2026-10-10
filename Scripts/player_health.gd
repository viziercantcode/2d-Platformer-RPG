extends Node
class_name PlayerHealth

const HEALING_AMOUNT: float = 0.75

@export var health_max: int = 100
@export var hurt_duration: float = 0.36
@export var hurt_invulnerability: float = 0.36
@export var healing_amount: float = HEALING_AMOUNT
@export var healing_duration: float = 1.0
@export var no_of_heals: int = 1

var player: Player
var health: int
var hurt_timer: float = 0.0
var invulnerability_timer: float = 0.0
var dead: bool = false
var hurt: bool = false
var healing: bool = false
var heal_key_was_down: bool = false
var healing_start_health: int = 0
var healing_target_health: int = 0
var healing_elapsed: float = 0.0

var hp_bar: Healthbar


func setup(player_ref: Player) -> void:
	player = player_ref
	health = health_max
	
	hurt_timer = 0.0
	invulnerability_timer = 0.0
	dead = false
	hurt = false
	healing = false
	heal_key_was_down = false
	healing_start_health = health
	healing_target_health = health
	healing_elapsed = 0.0

func update(delta: float) -> void:
	var heal_key_down := Input.is_key_pressed(KEY_R)
	if heal_key_down and not heal_key_was_down:
		start_healing()
	heal_key_was_down = heal_key_down

	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)

	if hurt_timer > 0.0:
		hurt_timer = max(hurt_timer - delta, 0.0)

	if hurt and hurt_timer <= 0.0 and not dead:
		hurt = false

	if healing:
		healing_elapsed = minf(healing_elapsed + delta, healing_duration)
		var healing_progress := 1.0 if healing_duration <= 0.0 else healing_elapsed / healing_duration
		health = roundi(lerpf(healing_start_health, healing_target_health, healing_progress))
	
	if is_instance_valid(hp_bar):
		hp_bar.set_health(health)

func can_receive_damage() -> bool:
	if dead:
		return false
	if invulnerability_timer > 0.0:
		return false
	if not is_instance_valid(player):
		return false
	if player.movement != null and player.movement.is_dash_invulnerable():
		return false
	return true

func start_healing() -> void:
	if dead or not _can_start_healing():
		return

	if no_of_heals > 0:
		no_of_heals -= 1
		healing_start_health = health
		healing_target_health = min(health + roundi(health_max * healing_amount), health_max)
		_start_healing_animation("Healing")
	else:
		healing_start_health = health
		healing_target_health = health
		_start_healing_animation("Healing_no_effect")

func _can_start_healing() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(player.movement):
		return false
	if is_instance_valid(player.combat) and player.combat.is_attacking:
		return false
	if not player.is_on_floor() or player.movement.is_dashing:
		return false
	if not is_zero_approx(player.velocity.x) or not is_zero_approx(player.velocity.y):
		return false
	return is_zero_approx(Input.get_axis("ui_left", "ui_right"))

func _start_healing_animation(animation_name: String) -> void:
	healing = true
	healing_elapsed = 0.0
	hurt = false
	hurt_timer = 0.0

	if is_instance_valid(player.combat):
		player.combat.interrupt_for_hurt()
	player.velocity = Vector2.ZERO
	player.animated_sprite.speed_scale = 1.0
	player.animated_sprite.play(animation_name)

func finish_healing() -> void:
	health = healing_target_health
	if is_instance_valid(hp_bar):
		hp_bar.set_health(health)
	healing = false

func take_damage(damage: int, knockback: Vector2, attack_direction: float) -> bool:
	if damage <= 0 or not can_receive_damage():
		return false

	var health_before_damage := health
	health = max(health - damage, 0)
	if healing:
		var remaining_healing := maxf(healing_target_health - health_before_damage, 0)
		healing_start_health = health
		healing_target_health = min(health + remaining_healing, health_max)
		healing_elapsed = 0.0
	if is_instance_valid(hp_bar):
		hp_bar.set_health(health)
		hp_bar.flash_damage()
	invulnerability_timer = hurt_invulnerability
	
	player.spawn_blood_particles(attack_direction)
	player.spawn_hurt_effect(attack_direction)
	
	# Damage immediately cancels attacks and their hitbox.
	if is_instance_valid(player.combat):
		player.combat.request_hitstop(0.3)
		player.combat.interrupt_for_hurt()

	var camera := player.get_node_or_null("Camera2D")
	if camera != null and camera.has_method("shake"):
		camera.shake(4.0)

	# Hurt knockback has priority over normal movement.
	player.velocity = knockback

	if health <= 0:
		start_death()
	else:
		hurt = true
		hurt_timer = hurt_duration

	return true

func setup_hp_bar(bar: Healthbar) -> void:
	hp_bar = bar
	if is_instance_valid(hp_bar):
		hp_bar.setup(health_max, health)


func start_death() -> void:
	if dead:
		return

	dead = true
	hurt = false
	healing = false
	hurt_timer = 0.0
	invulnerability_timer = 0.0
	player.velocity = Vector2.ZERO

	if is_instance_valid(player.movement):
		player.movement.cancel_dash()
	if is_instance_valid(player.combat):
		player.combat.interrupt_for_death()

	Global.playerAlive = false
	player.on_death_started()
