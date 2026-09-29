extends RefCounted
class_name BloodEffect

static func spawn(parent: Node, position: Vector2, direction: float, settings: Dictionary) -> void:
	var particles := GPUParticles2D.new()
	
	particles.one_shot = true
	particles.amount = int(settings.get("amount", 8))
	particles.lifetime = float(settings.get("explosiveness", 0.32))
	particles.explosiveness = 0.95
	particles.local_coords = false
	particles.visibility_rect = Rect2(-128, -128, 256, 256)

	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	
	image.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(image)

	var material := ParticleProcessMaterial.new()

	material.particle_flag_disable_z = true
	material.direction = Vector3(direction, float(settings.get("direction_y", -0.20)), 0.0)
	material.spread = float(settings.get("spread", 35.0))

	material.initial_velocity_min = float(settings.get("speed_min", 130.0))
	material.initial_velocity_max = float(settings.get("speed_max", 300.0))

	material.gravity = Vector3(0.0, float(settings.get("gravity", 620.0)), 0.0)

	material.damping_min = float(settings.get("damping_min", 5.0))
	material.damping_max = float(settings.get("damping_max", 12.0))
	material.scale_min = float(settings.get("scale_min", 0.6))
	material.scale_max = float(settings.get("scale_max", 1.2))
	material.color = settings.get("color", Color.WHITE)

	particles.process_material = material

	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true

	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = particles.lifetime + 0.1
	cleanup.timeout.connect(particles.queue_free)

	particles.add_child(cleanup)
	cleanup.start()

func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	pass
