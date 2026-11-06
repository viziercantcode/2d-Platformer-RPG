extends Camera2D

@export var look_ahead_distance := 40.0
@export var look_ahead_speed := 2.0
@export var dialogue_zoom := Vector2(3.0, 3.0)
@export var dialogue_pan_speed := 4.0

var shake_strength := 0.0
var shake_fade := 60.0  # Amount of fade per delta
var target_offset := Vector2.ZERO
var look_ahead_offset := Vector2.ZERO
var dialogue_focus_active := false
var dialogue_focus_position := Vector2.ZERO
var default_position := Vector2.ZERO
var default_zoom := Vector2.ONE

func _ready() -> void:
	default_position = position
	default_zoom = zoom

func focus_on_dialogue(world_position: Vector2) -> void:
	dialogue_focus_position = world_position
	dialogue_focus_active = true

func clear_dialogue_focus() -> void:
	dialogue_focus_active = false

func shake(amount: float) -> void:
	shake_strength = max(shake_strength, amount)

func _process(delta: float) -> void:
	var player := get_parent() as Player
	if player == null:
		return

	var follow_weight := 1.0 - exp(-dialogue_pan_speed * delta)
	if dialogue_focus_active:
		var focus_local_position := dialogue_focus_position - player.global_position
		position = position.lerp(focus_local_position, follow_weight)
		zoom = zoom.lerp(dialogue_zoom, follow_weight)
		look_ahead_offset = look_ahead_offset.lerp(Vector2.ZERO, follow_weight)
	else:
		position = position.lerp(default_position, follow_weight)
		zoom = zoom.lerp(default_zoom, follow_weight)

	if dialogue_focus_active:
		offset = look_ahead_offset
		if shake_strength > 0.0:
			shake_strength = move_toward(shake_strength, 0.0, shake_fade * delta)
			offset += Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
		return

	target_offset.x = player.facing_direction * look_ahead_distance
	look_ahead_offset.x = lerp(look_ahead_offset.x, target_offset.x, look_ahead_speed * delta)

	offset = look_ahead_offset
	
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_fade * delta)

		offset += Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
