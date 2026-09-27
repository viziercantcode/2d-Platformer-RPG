extends CharacterBody2D
class_name Enemy_1

var movement: EnemyMovement
var combat: EnemyCombat

@onready var deal_damage_zone = $EnemyDealDamageZone
@onready var hitbox = $EnemyHitbox/CollisionShape2D
@onready var anim_sprite = $AnimatedSprite2D

func _ready() -> void:
	movement = EnemyMovement.new()
	combat = EnemyCombat.new()
	add_child(movement)
	add_child(combat)

	combat.setup(self)
	movement.setup(self, combat)

	anim_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	var player = Global.playerBody
	if not is_instance_valid(player):
		return

	Global.enemyDamageAmount = combat.damage_to_deal
	Global.enemyDamageZone = deal_damage_zone

	combat.update(delta)
	movement.update(delta)
	handle_animation()
	move_and_slide()

func handle_animation() -> void:
	if combat.dead:
		if anim_sprite.animation != "death":
			anim_sprite.play("death")
		return

	if combat.taking_damage:
		if anim_sprite.animation != "hurt":
			anim_sprite.play("hurt")
		return

	if combat.is_dealing_damage:
		if anim_sprite.animation != "deal_damage":
			anim_sprite.play("deal_damage")
		return

	if anim_sprite.animation != "walk" or not anim_sprite.is_playing():
		anim_sprite.play("walk")

	# Flip sprite based on direction.
	if movement.dir.x == 1:
		anim_sprite.scale.x = -1
		deal_damage_zone.scale.x = -1
		hitbox.scale.x = -1
	elif movement.dir.x == -1:
		anim_sprite.scale.x = 1
		deal_damage_zone.scale.x = 1
		hitbox.scale.x = 1

# Keep these wrapper methods so existing scene signal connections do not need to change.
func _on_direction_timer_timeout() -> void:
	movement.on_direction_timer_timeout()

func _on_enemy_hurtbox_area_entered(area: Area2D) -> void:
	combat.on_enemy_hurtbox_area_entered(area)

func _on_animation_finished() -> void:
	combat.on_animation_finished()
