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

# HP Bar
@export var hp_bar_smooth_speed: float = 1000.0
@export var hp_damage_delay: float = 0.25
@export var hp_damage_smooth_speed: float = 20.0

var hp_bar: ProgressBar
var hp_damage_bar: ProgressBar
var displayed_health: float = 100.0
var delayed_health: float = 100.0
var damage_delay_timer: float = 0.0


func setup(player_ref: CharacterBody2D) -> void:
	player = player_ref
	health = health_max
	
	displayed_health = health
	delayed_health = health
	damage_delay_timer = 0.0
	
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
	
	# Smooth HP bar
	displayed_health = move_toward(displayed_health, health, hp_bar_smooth_speed * delta)
	
	if hp_bar:
		hp_bar.value = displayed_health
	
	# Delayed damage bar
	if damage_delay_timer > 0.0:
		damage_delay_timer -= delta
	else:
		delayed_health = move_toward(delayed_health, health, hp_damage_smooth_speed * delta)
		
		if hp_damage_bar:
			hp_damage_bar.value = delayed_health

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
	
	damage_delay_timer = hp_damage_delay
	invulnerability_timer = hurt_invulnerability
	
	player.spawn_blood_particles(attack_direction)
	
	# Damage immediately cancels attacks and their hitbox.
	if is_instance_valid(player.combat):
		player.combat.interrupt_for_hurt()

	# Hurt knockback has priority over normal movement.
	player.velocity = knockback

	if health <= 0:
		start_death()
	else:
		hurt = true
		hurt_timer = hurt_duration

	return true

func setup_hp_bars(front_bar: ProgressBar, damage_bar: ProgressBar) -> void:
	hp_bar = front_bar
	hp_damage_bar = damage_bar
	
	hp_bar.max_value = health_max
	hp_damage_bar.max_value = health_max
	
	hp_bar.value = health
	hp_damage_bar.value = health
	displayed_health = health
	delayed_health = health


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
