extends CharacterBody2D
class_name Enemy_1

@export_category("Detection")
@export var forward_detection_range: float = 200.0

@export_category("Combat")
@export var health_max: int = 100
@export var damage_to_deal: int = 20
@export var attack_trigger_distance: float = 72.0
@export var attack_startup: float = 0.25
@export var attack_active: float = 0.10
@export var attack_recovery: float = 0.35
@export var attack_cooldown: float = 0.80
@export var hurt_duration: float = 0.34
@export var hurt_invulnerability: float = 0.04
@export var knockback_force: float = 180.0
@export var knockback_up_force: float = 45.0
@export var hitstop_on_hurt: float = 0.07
@export var default_hitstop: float = 0.06

@export_category("Blood Particles")
@export var blood_amount: int = 8
@export var blood_lifetime: float = 0.32
@export var blood_spread: float = 35.0
@export var blood_speed_min: float = 130.0
@export var blood_speed_max: float = 300.0
@export var blood_gravity: float = 620.0
@export var blood_direction_y: float = -0.20
@export var blood_damping_min: float = 5.0
@export var blood_damping_max: float = 12.0
@export var blood_color: Color = Color(0.493, 0.101, 0.143, 1.0)
@export var blood_scale_min: float = 0.6
@export var blood_scale_max: float = 1.2

var movement: EnemyMovement
var combat: EnemyCombat
var death_started := false

@onready var deal_damage_zone: Area2D = $EnemyDealDamageZone
@onready var hitbox: CollisionShape2D = $EnemyHitbox/CollisionShape2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_detection_ray: RayCast2D = $PlayerDetectionRay
@onready var player_detection_area: Area2D = $PlayerDetectionArea

func _ready() -> void:
	movement = EnemyMovement.new()
	combat = EnemyCombat.new()
	add_child(movement)
	add_child(combat)

	combat.setup(self)
	movement.setup(self, combat)

	anim_sprite.animation_finished.connect(_on_animation_finished)
	Global.enemyDamageAmount = combat.damage_to_deal
	Global.enemyDamageZone = deal_damage_zone

	# The attack zone is a real hitbox only during attack active frames.
	var attack_shape := deal_damage_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if attack_shape != null:
		attack_shape.disabled = true

func _physics_process(delta: float) -> void:
	Global.enemyDamageAmount = combat.damage_to_deal
	Global.enemyDamageZone = deal_damage_zone

	combat.update(delta)
	movement.update(delta)
	handle_animation()
	move_and_slide()

func handle_animation() -> void:
	if combat.dead:
		if anim_sprite.animation != "death":
			anim_sprite.speed_scale = 1.0
			anim_sprite.play("death")
		return

	if combat.taking_damage:
		anim_sprite.speed_scale = 1.0
		if anim_sprite.animation != "hurt":
			anim_sprite.play("hurt")
		return

	if combat.state == EnemyCombat.State.ATTACK:
		anim_sprite.speed_scale = 1.35
		if anim_sprite.animation != "deal_damage":
			anim_sprite.play("deal_damage")
		return
	
	if absf(velocity.x) > 1.0:
		if movement.is_enemy_chase:
			anim_sprite.speed_scale = 1.35
		else:
			anim_sprite.speed_scale = 0.8
		
		if anim_sprite.animation != "walk" or not anim_sprite.is_playing():
			anim_sprite.play("walk")
	else:
		anim_sprite.speed_scale = 1.0
		
		if anim_sprite.animation != "idle" or not anim_sprite.is_playing():
			anim_sprite.play("idle")


func can_see_player() -> bool:
	var player := Global.playerBody
	
	if not is_instance_valid(player) or player.health.dead:
		return false
	
	var target := player.global_position + Vector2(0.0, player_detection_ray.position.y)
	var offset := target - player_detection_ray.global_position
	var player_is_in_front := signf(offset.x) == movement.facing_direction
	
	if player_is_in_front:
		if offset.length() > forward_detection_range:
			return false
	elif not player_detection_area.overlaps_body(player):
		return false
		
	player_detection_ray.target_position = player_detection_ray.to_local(target)
	player_detection_ray.force_raycast_update()
	
	return player_detection_ray.get_collider() == player

func health_blocked_for_attack() -> bool:
	return combat.dead or combat.state == EnemyCombat.State.HURT or combat.state == EnemyCombat.State.ATTACK

func spawn_blood_particles(attack_direction: float) -> void:
	var settings := {
		"amount": blood_amount,
		"lifetime": blood_lifetime,
		"spread": blood_spread,
		"speed_min": blood_speed_min,
		"speed_max": blood_speed_max,
		"gravity": blood_gravity,
		"direction_y": blood_direction_y,
		"damping_min": blood_damping_min,
		"damping_max": blood_damping_max,
		"color": blood_color,
		"scale_min": blood_scale_min,
		"scale_max": blood_scale_max
	}
	
	BloodEffect.spawn(get_parent(), global_position + Vector2(0.0, -20.0), attack_direction, settings)

func on_death_started() -> void:
	if death_started:
		return
	death_started = true
	velocity = Vector2.ZERO
	anim_sprite.speed_scale = 1.0
	anim_sprite.play("death")

func enemy_direction_timer_reset() -> void:
	var timer := get_node_or_null("DirectionTimer") as Timer
	if timer != null:
		timer.wait_time = choose([4.0,4.5, 5.0])

func choose(array):
	array.shuffle()
	return array.front()

func _on_direction_timer_timeout() -> void:
	movement.on_direction_timer_timeout()

func _on_enemy_hurtbox_area_entered(_area: Area2D) -> void:
	pass

func _on_enemy_deal_damage_zone_area_entered(_area: Area2D) -> void:
	pass

func _on_animation_finished() -> void:
	combat.on_animation_finished()
