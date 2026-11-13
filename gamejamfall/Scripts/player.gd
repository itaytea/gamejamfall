extends CharacterBody2D

#speed of player
@export var speed = 360
@export var jump_speed = -650
@export var gravity = 2100
@export var fall_gravity_multiplier = 1.5 #fall faster than you rise
@export var max_fall_speed = 640
@export_range(0.0, 1.0) var friction = 0.45
@export_range(0,0, 1.0) var acceleration = 0.25
@export_range(0,0, 1.0) var air_control = 0.65
var input_direction

#function gets directional input
func get_input():
	input_direction = Input.get_axis("move_left", "move_right")
	

func _physics_process(delta: float) -> void:
	get_input() #called every physics update
	
	#gravity 
	if not is_on_floor():
		var g = gravity * (fall_gravity_multiplier if velocity.y > 0 else 1.0) #heavier when falling 
		velocity.y = min(velocity.y + g * delta, max_fall_speed) #capped at max_fall_speed, min() returns the smallest of two variables
	
	var control = 1.0 if is_on_floor() else air_control
	if input_direction != 0: #if player is actively moving
		velocity.x = lerp(velocity.x, input_direction * speed, acceleration * control) #accelerate to max speed, then coast at max speed
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * control) #slow to a halt
	
	#jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_speed
	#shorter jump if let go early
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5
	
	move_and_slide()

	
