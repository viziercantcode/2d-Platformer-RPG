extends Node2D

@onready var interactable: Area2D = $Interactable
@onready var animation_player: AnimationPlayer = $AnimatableBody2D/AnimationPlayer

func _ready() -> void:
	interactable.interact = _on_interact

func _on_interact() -> void:
	if interactable.is_interactable:
		interactable.is_interactable = false
		animation_player.play("door_open")
		print("worksd")
