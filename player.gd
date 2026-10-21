extends CharacterBody3D

# --- Movement Parameters ---
@export var walk_speed = 5.0
@export var gravity = 9.8
@export var jump_strength = 5.0
# Add to your Movement group
@export var sprint_speed = 8.0
@export var crouch_speed = 2.5

#crouch height changes
@export var crouch_offset = -0.75

# --- Look & Feel Parameters ---
@export var mouse_sensitivity = 0.002
@onready var camera = $Head/Camera3D # Need a reference to the camera now
@export var base_fov = 75.0
@export var sprint_fov = 85.0

# Add under the @export_group("Look & Feel")
@export_group("Components")
@export var weapons_manager: WeaponManager


# --- Node References ---
@onready var head = $Head

# This function runs once when the game starts.
func _ready():
	# This hides our mouse cursor and keeps it locked to the game window.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		# To look left and right, we rotate the entire player body.
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# To look up and down, we only rotate our "Head" pivot.
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# We need to prevent the head from looking too far and flipping over.
		# This line clamps the rotation between straight up (-90 degrees) and straight down (90 degrees).
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
		
		# Add this code inside the _input(event) function

	# --- Weapon Input ---
	# We check if the manager exists before trying to use it.
	if weapons_manager:
		if event.is_action_pressed("fire"):
			weapons_manager.attack()

		if event.is_action_pressed("reload"):
			weapons_manager.reload_current_weapon()
		
		# Use mouse wheel for weapon switching
		if event.is_action_pressed("weapon_scroll_up"):
			weapons_manager.switch_to_next_weapon()
		elif event.is_action_pressed("weapon_scroll_down"):
			weapons_manager.switch_to_previous_weapon()

		if event.is_action_pressed("throw_weapon"):
			var throw_force = weapons_manager.get_throw_direction()
			weapons_manager.throw_current_weapon(throw_force)


func _physics_process(delta):
	# First, apply gravity so we don't float.
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_strength
	
	if Input.is_action_just_pressed("escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)	
		
	var is_sprinting = Input.is_action_pressed("sprint") 
	var is_crouching = Input.is_action_pressed("crouch") 


	# Update FOV based on sprinting state
	if is_sprinting and not is_crouching:
		camera.fov = lerp(camera.fov, sprint_fov, delta * 10.0)
	else:
		camera.fov = lerp(camera.fov, base_fov, delta * 10.0)
		
	if is_crouching:
		camera.v_offset = crouch_offset
	else:
		camera.v_offset = 0
	# Get our WASD input.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	
	# This bit of math translates our local "forward" into the world's "forward"
	# based on the direction our player is facing.
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Set our horizontal velocity.
	#velocity.x = direction.x * walk_speed
	#velocity.z = direction.z * walk_speed
	var target_speed = sprint_speed if is_sprinting else walk_speed
	target_speed = crouch_speed if is_crouching else target_speed

	
	# Apply velocity using the target_speed
	if velocity.x > 0 and velocity.x > 0:
		velocity.x = direction.x * target_speed/sqrt(2)
		velocity.z = direction.z * target_speed/sqrt(2)
	else:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed

	# This is the Godot function that does all the heavy lifting of moving and colliding.
	move_and_slide()
