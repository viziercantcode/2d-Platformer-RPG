@tool
extends Sprite2D

func _ready() -> void:
	_zoom_changed()

func _process(delta: float) -> void:
	_zoom_changed()

func _zoom_changed():
	material.set_shader_parameter("y_zoom", get_viewport_transform().get_scale().y)
