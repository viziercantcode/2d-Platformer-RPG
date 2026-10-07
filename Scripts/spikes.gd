extends StaticBody2D

@export var damage: int = 10
@export var knockback: float = 300.0

@onready var damage_area: Area2D = $Area2D


func _ready() -> void:
	damage_area.area_entered.connect(_on_damage_area_entered)
	damage_area.body_entered.connect(_on_damage_body_entered)


func _physics_process(_delta: float) -> void:
	# Poll overlap as a fallback if area_entered was missed during initialization.
	for area in damage_area.get_overlapping_areas():
		_handle_overlapping_area(area)

func _on_damage_area_entered(area: Area2D) -> void:
	_handle_overlapping_area(area)

func _handle_overlapping_area(area: Area2D) -> void:
#for enemy
	if area.name == "EnemyHitbox":
		var enemy := area.get_parent() as Enemy_1
		if enemy != null:
			enemy.combat.kill_from_spikes()
			return
#for player
	if area.name != "PlayerHitbox":
		return
	var player: CharacterBody2D = area.get_parent() as CharacterBody2D
	if player == null:
		return
	_handle_player_contact(player)

func _on_damage_body_entered(body: Node2D) -> void:
	var player := body as CharacterBody2D
	if player != null:
		_handle_player_contact(player)

func _handle_player_contact(player: CharacterBody2D) -> void:
	if player.movement.is_dashing:
		var finished_callback := _on_player_dash_finished.bind(player)
		if not player.movement.dash_finished.is_connected(finished_callback):
			player.movement.dash_finished.connect(finished_callback, CONNECT_ONE_SHOT)
		return
	_damage_player(player)


func _on_player_dash_finished(player: CharacterBody2D) -> void:
#for dash invulneberlity
	if not is_instance_valid(player):
		return
	# Make sure the player's hitbox is still inside this spike.
	if not damage_area.overlaps_area(player.get_node("PlayerHitbox")):
		return
	_damage_player(player)


func _damage_player(player: CharacterBody2D) -> void:
	if not player.health.can_receive_damage():
		return

	var direction: float = signf(player.global_position.x - global_position.x)

	var knockback_velocity: Vector2 = Vector2(direction * 100.0, -400.0)

	player.health.take_damage(damage, knockback_velocity, player.facing_direction)
	
