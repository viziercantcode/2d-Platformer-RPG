extends ParallaxLayer

var CLOUD_SPEED = 15
func _process(delta) -> void:
	self.motion_offset.x += CLOUD_SPEED * delta
