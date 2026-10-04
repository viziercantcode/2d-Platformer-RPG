extends RefCounted
class_name HitEffect

static func spawn(parent: Node, position: Vector2, direction: float) -> void:
	var hit_effect = load("res://Scenes/VFX/hit_effect.tscn").instantiate()

	parent.add_child(hit_effect)
	hit_effect.global_position = position
	hit_effect.scale.x = sign(direction) if direction != 0.0 else 1.0

	for particles in hit_effect.get_children():
		if particles is GPUParticles2D:
			particles.restart()

	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 0.8
	cleanup.timeout.connect(hit_effect.queue_free)

	hit_effect.add_child(cleanup)
	cleanup.start()
