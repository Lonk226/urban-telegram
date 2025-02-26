extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

const SPEED = 250.0 # Base horizontal movement speed
const ACCELERATION = 800.0 # Base acceleration
const FRICTION = 6000.0 # Base friction
const GRAVITY = 2000.0 # Gravity when moving upwards
const FALL_GRAVITY = 4000.0 # Gravity when falling downwards
const FAST_FALL_GRAVITY = 5000.0 # Gravity while holding "fast_fall"
const WALL_GRAVITY = 25.0 # Gravity while sliding on a wall
const JUMP_VELOCITY = -500.0 # Maximum jump strength
const WALL_JUMP_VELOCITY = -700.0 # Maximum wall jump strength
const WALL_JUMP_PUSHBACK = 300.0 # Horizontal push strength off walls
const INPUT_BUFFER_PATIENCE = 0.1 # Input queue patience time
const COYOTE_TIME = 0.08 # Coyote patience time

var input_buffer : Timer # Reference to the input queue timer
var coyote_timer : Timer # Reference to the coyote timer
var coyote_jump_available := true
var is_facing_right := true

@export_category("Dash var")
@export var dash_speed = 850
@export var dash_grav = 0
@export var dash_num = 1
var dash_key_pressed = 0
var is_airdashing = false
var dash_timer = Timer

var is_attacking = false
var attack2 = false
var is_attacking2 = false

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
		if horizontal_input != 0 and not is_airdashing:
			animated_sprite.play("Run") # Play walking animation
		elif is_airdashing:
			animated_sprite.play("AirDash")
		elif is_attacking:
			animated_sprite.play("Sword")
		elif is_attacking2:
			animated_sprite.play("Sword2")
		else:
			animated_sprite.play("Idle") # Play idle animation
	elif is_on_wall() and velocity.y > 0:
		animated_sprite.play("Wallslide") # Play wall sliding animation
	elif velocity.y < 0:
		animated_sprite.play("Jump") # Play jumping animation
	elif is_airdashing:
			animated_sprite.play("AirDash")
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
			
	if is_on_floor():
		dash_num = 1

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
		elif is_airdashing == true:
			velocity.y = dash_grav
		else:
			velocity.y += getthegravity(horizontal_input) * delta

	# Handle horizontal motion and friction
	var floor_damping := 0.5 if is_on_floor() else 0.2 # Set floor damping, friction is less when in air
	var dash_multiplier = 1
	if horizontal_input:
		velocity.x = move_toward(velocity.x, horizontal_input * SPEED * dash_multiplier, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, (FRICTION * delta) * floor_damping)
	
	if Input.is_action_just_pressed("wavedash") and dash_key_pressed == 0 and dash_num >= 1:
		dash_key_pressed = 1
		dash_num -= 1
		dash()

	# Apply velocity
	move_and_slide()
	
	if Input.is_action_just_pressed("attack"):
		if is_attacking == false:
			attack()
			timer.start()
			attack2 = true
		elif attack2 == true:
			Attack2()
	
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
	
func dash():
	if dash_key_pressed == 1:
		is_airdashing = true
	else:
		is_airdashing = false
		
	if is_facing_right == true:
		velocity.x = dash_speed
		dash_started()
	if is_facing_right == false:
		velocity.x = -dash_speed
		dash_started()
		
func dash_started():
	if is_airdashing == true:
		dash_key_pressed = 1
		await get_tree().create_timer(0.15).timeout
		is_airdashing = false
		dash_key_pressed = 0
	else:
		return
		
		
func attack():
	is_attacking = true
	await get_tree().create_timer(0.4).timeout
	is_attacking = false
	
func Attack2():
	is_attacking2 = true
	await get_tree().create_timer(0.6).timeout
	is_attacking2 = false

func _on_timer_timeout() -> void:
	attack2 = true
	await get_tree().create_timer(0.6).timeout
	attack2 = false
