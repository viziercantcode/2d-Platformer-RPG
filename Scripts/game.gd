extends Node2D

@onready var options_menu: OptionsMenu = $HUD/OptionsMenu
var ui_mouse_click_blocked := false

func _ready() -> void:
	$Fade_transition/AnimationPlayer.play("fade_out")

func _process(_delta: float) -> void:
	if ui_mouse_click_blocked and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		ui_mouse_click_blocked = false

func _on_settings_pressed() -> void:
	ui_mouse_click_blocked = true
	options_menu.open()
	get_tree().paused = true

func _on_options_closed() -> void:
	ui_mouse_click_blocked = true
	get_tree().paused = false

func is_ui_mouse_click_blocked() -> bool:
	return ui_mouse_click_blocked

