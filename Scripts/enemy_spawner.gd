extends Marker2D

@export var enemy_scene: PackedScene

var has_spawned: bool = false
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	visibility_notifier.screen_entered.connect(spawn_enemy)

func spawn_enemy() -> void:
	if has_spawned or enemy_scene == null:
		return
	
	has_spawned = true
	
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position
	
	queue_free()
