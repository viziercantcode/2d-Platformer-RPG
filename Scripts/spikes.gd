extends StaticBody2D

@export var damage: int = 10
@export var knockback: float = 300.0

@onready var damage_area: Area2D = $Area2D


func _ready() -> void:
	damage_area.area_entered.connect(_on_damage_area_entered)


func _on_damage_area_entered(area: Area2D) -> void:
	if area.name != "PlayerHitbox":
		return

	var player: CharacterBody2D = area.get_parent() as CharacterBody2D

	if player == null:
		return

	# If the player entered while dashing, wait until the dash ends.
	if player.movement.is_dashing:
		if not player.movement.dash_finished.is_connected(_on_player_dash_finished):
			player.movement.dash_finished.connect(_on_player_dash_finished.bind(player), CONNECT_ONE_SHOT)
		return

	_damage_player(player)


func _on_player_dash_finished(player: CharacterBody2D) -> void:
	if not is_instance_valid(player):
		return

	# Make sure the player's hitbox is still inside this spike.
	if not damage_area.overlaps_area(player.get_node("PlayerHitbox")):
		return

	_damage_player(player)


func _damage_player(player: CharacterBody2D) -> void:
	if not player.health.can_receive_damage():
		return

	var direction: float = signf(
		player.global_position.x - global_position.x
	)

	var knockback_velocity: Vector2 = Vector2(
		direction * 100.0,
		-400.0
	)

	player.health.take_damage(
		damage,
		knockback_velocity,
		player.facing_direction
	)
