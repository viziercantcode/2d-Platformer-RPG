extends Node2D

const DIALOGUE: DialogueResource = preload("res://dialogue manager/dialogue1.dialogue")

@onready var interactable: Area2D = $Interactable

func _ready() -> void:
	interactable.interact = _on_interact

func _on_interact() -> void:
	if not interactable.is_interactable:
		return

	# Keep the player interaction component occupied until the conversation ends.
	interactable.is_interactable = false
	var player := Global.playerBody as Player
	if is_instance_valid(player):
		player.begin_dialogue(global_position)

	var dialogue_manager: Node = Engine.get_singleton("DialogueManager")
	dialogue_manager.show_dialogue_balloon(DIALOGUE, "start")

	var ended_resource: DialogueResource = await dialogue_manager.dialogue_ended
	while ended_resource != DIALOGUE:
		ended_resource = await dialogue_manager.dialogue_ended

	if is_instance_valid(player):
		player.end_dialogue()
	interactable.is_interactable = true
