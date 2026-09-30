extends Camera2D

@export var look_ahead_distance := 40.0
@export var look_ahead_speed := 2.0

var target_offset := Vector2.ZERO

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	var player = get_parent()
	target_offset.x = player.facing_direction * look_ahead_distance
	offset.x = lerp(offset.x, target_offset.x, look_ahead_speed * delta)
