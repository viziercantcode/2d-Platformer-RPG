
extends Node2D

var current_interactions: Array[Area2D] = []
var can_interact := true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Interact") and can_interact:
		current_interactions = current_interactions.filter(
			func(area): return is_instance_valid(area)
		)

		if not current_interactions.is_empty():
			current_interactions.sort_custom(_sort_by_nearest)
			var target = current_interactions[0]

			if target.is_interactable:
				can_interact = false
				_hide_all_labels()

				await target.interact.call()

				can_interact = true

func _process(_delta: float) -> void:
	current_interactions = current_interactions.filter(
		func(area): return is_instance_valid(area)
	)

	_hide_all_labels()

	if current_interactions.is_empty() or not can_interact:
		return

	current_interactions.sort_custom(_sort_by_nearest)

	var target = current_interactions[0]

	if target.is_interactable:
		target.interact_label.text = target.interact_name
		target.interact_label.show()

func _hide_all_labels() -> void:
	for area in current_interactions:
		if is_instance_valid(area):
			area.interact_label.hide()

func _sort_by_nearest(area1: Area2D, area2: Area2D) -> bool:
	return global_position.distance_to(area1.global_position) < \
		global_position.distance_to(area2.global_position)

func _on_interact_range_area_entered(area: Area2D) -> void:
	if not current_interactions.has(area):
		current_interactions.append(area)

func _on_interact_range_area_exited(area: Area2D) -> void:
	current_interactions.erase(area)

	if is_instance_valid(area):
		area.interact_label.hide()
