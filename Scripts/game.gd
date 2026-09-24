extends Node2D

func _ready() -> void:
	$Fade_transition/AnimationPlayer.play("fade_out")
