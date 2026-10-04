extends RefCounted
class_name HurtEffect

static func spawn(parent: Node, position: Vector2, direction: float) -> void:
	var hurt_effect = load("res://Scenes/VFX/hurt_effect.tscn").instantiate()

	parent.add_child(hurt_effect)
	hurt_effect.global_position = position
	hurt_effect.scale.x = sign(direction) if direction != 0.0 else 1.0

	for particles in hurt_effect.get_children():
		if particles is GPUParticles2D:
			particles.restart()

	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 0.8
	cleanup.timeout.connect(hurt_effect.queue_free)

	hurt_effect.add_child(cleanup)
	cleanup.start()
