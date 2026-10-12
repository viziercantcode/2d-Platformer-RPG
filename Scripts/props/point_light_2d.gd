extends PointLight2D

@export var flicker_amount: float = 0.12
@export var flicker_speed: float = 8.0

var base_energy: float
var time_passed: float = 0.0

func _ready() -> void:
	base_energy = energy
	time_passed = randf() * 100.0

func _process(delta: float) -> void:
	time_passed += delta * flicker_speed
	energy = base_energy + sin(time_passed) * flicker_amount
