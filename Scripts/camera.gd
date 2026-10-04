extends Camera2D

@export var look_ahead_distance := 40.0
@export var look_ahead_speed := 2.0

var shake_strength := 0.0
var shake_fade := 60.0  # Amount of fade per delta
var target_offset := Vector2.ZERO
var look_ahead_offset := Vector2.ZERO

func _ready() -> void:
	pass

func shake(amount: float) -> void:
	shake_strength = max(shake_strength, amount)

func _process(delta: float) -> void:
	var player = get_parent()
	
	
	target_offset.x = player.facing_direction * look_ahead_distance
	look_ahead_offset.x = lerp(look_ahead_offset.x, target_offset.x, look_ahead_speed * delta)

	offset = look_ahead_offset
	
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_fade * delta)

		offset += Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
