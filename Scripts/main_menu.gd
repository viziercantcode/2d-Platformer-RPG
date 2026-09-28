extends Node2D

var button_type = null

@onready var button_manager = $Button_manager
@onready var options_menu: OptionsMenu = $OptionsLayer/OptionsMenu

@onready var hover_sfx = $Hover_sfx
@onready var click_sfx = $Click_sfx
func _ready() -> void:
	button_manager.visible = true
	options_menu.visible = false


	var start_button = $Button_manager/Start
	var options_button = $Button_manager/Options
	var quit_button = $Button_manager/Quit

	# Connect hover signals only if they aren't already connected.
	# This prevents duplicate connection errors.
	if not start_button.mouse_entered.is_connected(_on_button_hovered):
		start_button.mouse_entered.connect(_on_button_hovered)

	if not options_button.mouse_entered.is_connected(_on_button_hovered):
		options_button.mouse_entered.connect(_on_button_hovered)

	if not quit_button.mouse_entered.is_connected(_on_button_hovered):
		quit_button.mouse_entered.connect(_on_button_hovered)



func _on_button_hovered() -> void:
	# Play the hover sound when the mouse enters a button.
	hover_sfx.play()


func _on_start_pressed() -> void:
	button_type = "start"

	click_sfx.play()

	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")


func _on_options_pressed() -> void:
	click_sfx.play()
	await click_sfx.finished

	button_manager.visible = false
	options_menu.open()


func _on_quit_pressed() -> void:
	click_sfx.play()
	await click_sfx.finished

	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_options_closed() -> void:
	click_sfx.play()
	button_manager.visible = true
