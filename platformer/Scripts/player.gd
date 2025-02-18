extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 350.0 # Base horizontal movement speed
const ACCELERATION = 1200.0 # Base acceleration
const FRICTION = 4000.0 # Base friction
const GRAVITY = 2000.0 # Gravity when moving upwards
const FALL_GRAVITY = 3000.0 # Gravity when falling downwards
const FAST_FALL_GRAVITY = 5000.0 # Gravity while holding "fast_fall"
const WALL_GRAVITY = 25.0 # Gravity while sliding on a wall
const JUMP_VELOCITY = -700.0 # Maximum jump strength
const WALL_JUMP_VELOCITY = -700.0 # Maximum wall jump strength
const WALL_JUMP_PUSHBACK = 300.0 # Horizontal push strength off walls
const INPUT_BUFFER_PATIENCE = 0.1 # Input queue patience time
const COYOTE_TIME = 0.08 # Coyote patience time

var input_buffer : Timer # Reference to the input queue timer
var coyote_timer : Timer # Reference to the coyote timer
var coyote_jump_available := true
var is_facing_right := true

func _ready() -> void:
	# Set up input buffer timer
	input_buffer = Timer.new()
	input_buffer.wait_time = INPUT_BUFFER_PATIENCE
	input_buffer.one_shot = true
	add_child(input_buffer)

	# Set up coyote timer
	coyote_timer = Timer.new()
	coyote_timer.wait_time = COYOTE_TIME
	coyote_timer.one_shot = true
	add_child(coyote_timer)
	coyote_timer.timeout.connect(coyote_timeout)

func _physics_process(delta) -> void:
	# Get inputs
	var horizontal_input := Input.get_axis("left", "right")
	var jump_attempted := Input.is_action_just_pressed("jump")
	var is_dashing := Input.is_action_pressed("dash") # Check if dash is pressed

	# Change animations
	if is_on_floor():
		if is_dashing and horizontal_input != 0:
			animated_sprite.play("Dash") # Play dash animation
		elif horizontal_input != 0:
			animated_sprite.play("Run") # Play walking animation
		else:
			animated_sprite.play("Idle") # Play idle animation
	elif is_on_wall() and velocity.y > 0:
		animated_sprite.play("Wallslide") # Play wall sliding animation
	elif velocity.y < 0:
		animated_sprite.play("Jump") # Play jumping animation
	else:
		animated_sprite.play("Fall") # Play falling animation

	# Add the gravity and handle jumping
	if jump_attempted or input_buffer.time_left > 0:
		if coyote_jump_available: # If jumping on the ground
			velocity.y = JUMP_VELOCITY
			coyote_jump_available = false
		elif is_on_wall() and horizontal_input != 0: # If jumping off a wall
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = WALL_JUMP_PUSHBACK * -sign(horizontal_input)
		elif jump_attempted: # Queue input buffer if jump was attempted
			input_buffer.start()

	# Shorten jump if jump key is released
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y = JUMP_VELOCITY / 4

	# Apply gravity and reset coyote jump
	if is_on_floor():
		coyote_jump_available = true
		coyote_timer.stop()
	else:
		if coyote_jump_available:
			if coyote_timer.is_stopped():
				coyote_timer.start()
		velocity.y += getthegravity(horizontal_input) * delta

	# Handle horizontal motion and friction
	var floor_damping := 1.0 if is_on_floor() else 0.2 # Set floor damping, friction is less when in air
	var dash_multiplier := 2 if Input.is_action_pressed("dash") else 1
	if horizontal_input:
		velocity.x = move_toward(velocity.x, horizontal_input * SPEED * dash_multiplier, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, (FRICTION * delta) * floor_damping)

	# Apply velocity
	move_and_slide()
	
	 # Change player direction using flip_h
	if horizontal_input > 0 and !is_facing_right:
		is_facing_right = true
		animated_sprite.flip_h = false  # Face right
	elif horizontal_input < 0 and is_facing_right:
		is_facing_right = false
		animated_sprite.flip_h = true  # Face left

## Returns the gravity based on the state of the player
func getthegravity(input_dir : float = 0) -> float:
	if Input.is_action_pressed("fast_fall"):
		return FAST_FALL_GRAVITY
	if is_on_wall_only() and velocity.y > 0 and input_dir != 0:
		return WALL_GRAVITY
	return GRAVITY if velocity.y < 0 else FALL_GRAVITY

## Reset coyote jump
func coyote_timeout() -> void:
	coyote_jump_available = false
