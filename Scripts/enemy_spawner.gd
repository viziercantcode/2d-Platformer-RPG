extends Marker2D

@export var enemy_scene: PackedScene
@export_range(1, 3, 1) var enemy_level: int = 1

var has_spawned: bool = false
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	visibility_notifier.screen_entered.connect(spawn_enemy)

func spawn_enemy() -> void:
	if has_spawned or enemy_scene == null:
		return
	
	has_spawned = true
	
	var enemy := enemy_scene.instantiate() as Enemy_1
	if enemy == null:
		has_spawned = false
		push_warning("EnemySpawner requires enemy_scene to contain an Enemy_1 node.")
		return

	enemy.level = clampi(enemy_level, 1, 3)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position
	
	queue_free()
