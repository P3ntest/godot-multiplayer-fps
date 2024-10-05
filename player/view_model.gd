extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.

var mouse_movement = Vector2()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_movement = event.relative

func sway(delta: float) -> void:
	var x_amount = min(abs(mouse_movement.x * 0.0005), 1)
	var y_amount = min(abs(mouse_movement.y * 0.0005), 1)
	rotation.x = lerp(rotation.x, y_amount * sign(mouse_movement.y), 20 * delta)
	rotation.y = lerp(rotation.y, x_amount * sign(mouse_movement.x), 20 * delta)
	mouse_movement = Vector2()
	

func _process(delta: float) -> void:
	sway(delta)

