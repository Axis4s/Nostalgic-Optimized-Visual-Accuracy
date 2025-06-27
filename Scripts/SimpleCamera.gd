extends Camera3D

# Movement settings
@export var movement_speed: float = 1.0
@export var sprint_speed: float = 10.0
@export var mouse_sensitivity: float = 0.01

# Mouse look variables
var mouse_delta: Vector2 = Vector2.ZERO
var pitch: float = 0.0

func _ready():
	# Capture the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Handle mouse movement
	if event is InputEventMouseMotion:
		mouse_delta = event.relative
	
	# Toggle mouse capture with Escape key
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	handle_mouse_look()
	handle_movement(delta)

func handle_mouse_look():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera based on mouse movement
		rotate_y(-mouse_delta.x * mouse_sensitivity)
		
		# Handle pitch (up/down look) with clamping
		pitch -= mouse_delta.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)
		rotation.x = pitch
		
		# Reset mouse delta
		mouse_delta = Vector2.ZERO

func handle_movement(delta):
	var input_vector = Vector3.ZERO
	var current_speed = movement_speed
	
	# Check for sprint
	if Input.is_action_pressed("ui_accept"):  # Usually Spacebar or Enter
		current_speed = sprint_speed
	
	# Get movement input (relative to world coordinates)
	if Input.is_action_pressed("Left"):
		input_vector += Vector3.LEFT
	if Input.is_action_pressed("Right"):
		input_vector += Vector3.RIGHT
	if Input.is_action_pressed("Forward"):
		input_vector += Vector3.FORWARD
	if Input.is_action_pressed("Backward"):
		input_vector += Vector3.BACK
	
	# Vertical movement (Q/E or similar)
	if Input.is_key_pressed(KEY_E):
		input_vector += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		input_vector += Vector3.DOWN
	
	# Normalize and apply movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		translate(input_vector * current_speed * delta)
