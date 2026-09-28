extends CharacterBody2D

## Player coordinator.
## Movement, health and combat are separate components 

@export_category("Health")
@export var player_health_max: int = 100

var movement: PlayerMovement
var combat: PlayerCombat
var health: PlayerHealth
var hitstop_controller: HitstopController

var facing_direction: float = 1.0
var was_on_floor := true
var death_started := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust: GPUParticles2D = $dust
@onready var deal_damage_zone: Area2D = $DealDamageZone
@onready var slash1_sfx: AudioStreamPlayer = $"Slash-1"
@onready var slash2_sfx: AudioStreamPlayer = $"Slash-2"
@onready var jumpst_sfx: AudioStreamPlayer = $JumpStart
@onready var jumpend_sfx: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	movement = PlayerMovement.new()
	combat = PlayerCombat.new()
	health = PlayerHealth.new()

	add_child(movement)
	add_child(combat)
	add_child(health)

	health.health_max = player_health_max
	health.setup(self)
	combat.setup(self, health)
	movement.setup(self, combat, health)

	_hitstop_setup()

	Global.playerBody = self
	Global.playerAlive = true

	animated_sprite.animation_finished.connect(_on_animation_finished)
	set_facing(facing_direction)
	combat.interrupt_for_hurt()

func _physics_process(delta: float) -> void:
	Global.playerHitbox = $PlayerHitbox
	Global.playerDamageZone = deal_damage_zone
	
	# Health updates first, then combat, then movement
	health.update(delta)
	combat.update(delta)
	var direction := movement.update(delta)

	move_and_slide()
	_update_landing_audio()
	update_animation(direction)

func _update_landing_audio() -> void:
	if not was_on_floor and is_on_floor() and not health.dead:
		jumpend_sfx.play()
	was_on_floor = is_on_floor()

func set_facing(direction: float) -> void:
	if direction == 0.0:
		return
	
	# Flip sprite based on movement direction.
	facing_direction = sign(direction)
	animated_sprite.flip_h = facing_direction < 0.0
	deal_damage_zone.scale.x = facing_direction

func update_animation(direction: float) -> void:
	if health.dead:
		if animated_sprite.animation != "death":
			animated_sprite.speed_scale = 1.0
			animated_sprite.play("death")
		return

	if health.hurt:
		animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != "hurt":
			animated_sprite.play("hurt")
		return

	if movement.is_dashing:
		animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != "Dash":
			animated_sprite.play("Dash")
		return

	if combat.is_attacking:
		# Combat owns the attack animation. Movement must not overwrite it.
		return

	animated_sprite.speed_scale = 1.0

	if direction > 0.0:
		set_facing(1.0)
	elif direction < 0.0:
		set_facing(-1.0)

	var target_animation := "Idle"

	if not is_on_floor():
		if velocity.y < -50.0:
			target_animation = "Jump_start"
		elif velocity.y <= 50.0:
			target_animation = "Jump_middle"
		else:
			target_animation = "Jump_end"
	elif direction != 0.0:
		target_animation = "Run"

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

func on_death_started() -> void:
	if death_started:
		return
	death_started = true
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	animated_sprite.play("death")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "death" and death_started:
		queue_free()

func _hitstop_setup() -> void:
	var root := get_tree().root
	var existing := root.get_node_or_null("CombatHitstop")
	if existing is HitstopController:
		hitstop_controller = existing
		return

	hitstop_controller = HitstopController.new()
	hitstop_controller.name = "CombatHitstop"
	root.add_child(hitstop_controller)
