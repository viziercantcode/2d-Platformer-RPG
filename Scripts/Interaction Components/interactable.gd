extends Area2D

@export var interact_name: String = ""
@export var is_interactable: bool = true

@onready var interact_label: Label = $InteractLabel

var interact: Callable = func():
	pass

func _ready() -> void:
	interact_label.hide()
