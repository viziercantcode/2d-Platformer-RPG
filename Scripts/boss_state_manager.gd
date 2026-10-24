extends Node
class_name BossStateManager

## State timer for the boss movement and animation events.
var boss: Node
var current_state: StringName = &""
var state_time := 0.0

func setup(boss_ref: Node) -> void:
	boss = boss_ref
	change_state(&"intro")

func change_state(next_state: StringName) -> void:
	if next_state == current_state or not is_instance_valid(boss):
		return
	current_state = next_state
	state_time = 0.0
	boss._enter_state(next_state)

func restart_state(next_state: StringName) -> void:
	if not is_instance_valid(boss):
		return
	current_state = &""
	change_state(next_state)

func update(delta: float) -> void:
	if not is_instance_valid(boss):
		return
	state_time += delta
	boss._update_state(delta)
