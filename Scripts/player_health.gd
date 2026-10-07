extends Node
class_name PlayerHealth

## Player health is separate from attack logic.
## Hurt/death always interrupt combat so an attack cannot finish after being hit.

@export var health_max: int = 100
@export var hurt_duration: float = 0.36
@export var hurt_invulnerability: float = 0.36

var player: CharacterBody2D
var health: int
var hurt_timer: float = 0.0
var invulnerability_timer: float = 0.0
var dead: bool = false
var hurt: bool = false

var hp_bar: Healthbar


func setup(player_ref: CharacterBody2D) -> void:
	player = player_ref
	health = health_max
	
	hurt_timer = 0.0
	invulnerability_timer = 0.0
	dead = false
	hurt = false

func update(delta: float) -> void:
	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)

	if hurt_timer > 0.0:
		hurt_timer = max(hurt_timer - delta, 0.0)

	if hurt and hurt_timer <= 0.0 and not dead:
		hurt = false
	
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

func take_damage(damage: int, knockback: Vector2, attack_direction: float) -> bool:
	if damage <= 0 or not can_receive_damage():
		return false

	health = max(health - damage, 0)
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
	hurt_timer = 0.0
	invulnerability_timer = 0.0
	player.velocity = Vector2.ZERO

	if is_instance_valid(player.movement):
		player.movement.cancel_dash()
	if is_instance_valid(player.combat):
		player.combat.interrupt_for_death()

	Global.playerAlive = false
	player.on_death_started()
