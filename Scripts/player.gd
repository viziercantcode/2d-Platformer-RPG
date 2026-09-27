extends CharacterBody2D

# Main player script: coordinates movement/combat and owns animation presentation.

var movement: PlayerMovement
var combat: PlayerCombat

var was_on_floor: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust: GPUParticles2D = $dust
@onready var deal_damage_zone = $DealDamageZone
@onready var slash1_sfx = $"Slash-1"
@onready var slash2_sfx = $"Slash-2"
@onready var jumpst_sfx = $JumpStart
@onready var jumpend_sfx = $AudioStreamPlayer

func _ready() -> void:
	# Create the components at runtime, so no scene-file changes are required.
	movement = PlayerMovement.new()
	combat = PlayerCombat.new()
	add_child(movement)
	add_child(combat)

	movement.setup(self, combat)
	combat.setup(self)

	Global.playerBody = self
	Global.playerAlive = true
	combat.current_attack = false
	combat.dead = false

	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox = $PlayerHitbox

	# Preserve the original order: hit detection/timers first, movement second,
	# attack-input handling after movement.
	combat.update_before_movement(delta)

	var direction: float = 0.0
	if not combat.dead:
		direction = movement.update(delta)

	combat.update_after_movement()
	update_animation(direction)
	move_and_slide()

	# Detect an actual landing: AIR -> FLOOR only.
	if not was_on_floor and is_on_floor():
		jumpend_sfx.play()

	was_on_floor = is_on_floor()

func _on_animation_finished() -> void:
	combat.on_animation_finished()

func update_animation(direction: float) -> void:
	if combat.dead:
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
		return

	if combat.hurt_timer > 0:
		if animated_sprite.animation != "hurt":
			animated_sprite.play("hurt")
		return

	# Don't let movement/idle animations override an active attack animation.
	if combat.current_attack:
		if direction > 0:
			animated_sprite.flip_h = false
		elif direction < 0:
			animated_sprite.flip_h = true
		return

	# Flip sprite based on movement direction.
	if not movement.is_dashing:
		if direction > 0:
			animated_sprite.flip_h = false
			deal_damage_zone.scale.x = 1
		elif direction < 0:
			animated_sprite.flip_h = true
			deal_damage_zone.scale.x = -1

	var target_animation: String = "Idle"

	if movement.is_dashing:
		target_animation = "Dash"
	elif not is_on_floor():
		if velocity.y < -50:
			target_animation = "Jump_start"
		elif velocity.y <= 50:
			target_animation = "Jump_middle"
		else:
			target_animation = "Jump_end"
	elif direction != 0:
		target_animation = "Run"
	else:
		target_animation = "Idle"

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)
