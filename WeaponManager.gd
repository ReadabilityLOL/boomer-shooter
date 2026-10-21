# WeaponManager.gd
class_name WeaponManager
extends Node3D

# --- Exports ---
# This is where we will drag-and-drop our WeaponData resources in the Inspector.
@export var weapon_data_array: Array[WeaponData]
# A reference to the player body, to prevent us from shooting ourselves.
@export var shooter_body: Node3D

# --- Private Variables ---
var current_weapon_index: int = -1 # -1 means no weapon is equipped
var current_weapon_instance: Node3D # A reference to the currently active weapon scene instance
var weapon_instances: Array[Node3D] = [] # An array to hold all spawned weapon instances

var weapons_initialized: bool = false

# (Add after the variables)

func _ready() -> void:
	# We use call_deferred to ensure this runs after the rest of the scene is ready.
	_initialize_all_weapons.call_deferred()

	# Equip the first weapon by default.
	if not weapon_data_array.is_empty():
		switch_weapon.call_deferred(0)
	else:
		print("WeaponManager: No weapon data assigned.")

# This function creates instances of all our weapons and stores them.
func _initialize_all_weapons() -> void:
	if weapons_initialized:
		return

	# Clear any old instances if this were to be run again
	for child in get_children():
		child.queue_free()
	weapon_instances.clear()

	for weapon_data in weapon_data_array:
		if weapon_data and weapon_data.weapon_equipped_scene:
			# Create an instance of the weapon's equipped scene
			var weapon_instance = weapon_data.weapon_equipped_scene.instantiate()
			weapon_instance.shooter_body = shooter_body

			# We will add a function to our weapon scenes later to pass the data
			if weapon_instance.has_method("set_weapon_data"):
				weapon_instance.set_weapon_data(weapon_data)
			
			# Add it to the manager, but keep it hidden and disabled for now.
			add_child(weapon_instance)
			weapon_instance.visible = false
			weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED) # Important for performance!
			
			weapon_instances.append(weapon_instance)
		else:
			# If a weapon entry is invalid, add a null placeholder to keep arrays in sync.
			weapon_instances.append(null)
			printerr("WeaponManager: Invalid WeaponData or missing weapon_equipped_scene.")
	
	weapons_initialized = true

# (Add after _initialize_all_weapons)

# This is the core logic for changing the active weapon.
func switch_weapon(index: int) -> void:
	# 1. Basic safety checks.
	if not weapons_initialized or index < 0 or index >= weapon_instances.size():
		return
	
	# 2. Hide the currently equipped weapon, if there is one.
	if current_weapon_instance:
		current_weapon_instance.visible = false
		current_weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)

	# 3. Get the new weapon from our array and make it active.
	current_weapon_instance = weapon_instances[index]
	current_weapon_index = index

	if current_weapon_instance:
		current_weapon_instance.visible = true
		current_weapon_instance.set_process_mode(Node.PROCESS_MODE_INHERIT)
		print("WeaponManager: Switched to weapon %s" % current_weapon_instance.name)
	else:
		printerr("WeaponManager: Weapon instance at index %d is null." % index)


# These are public functions our PlayerController will call.
func switch_to_next_weapon() -> void:
	if weapon_data_array.size() <= 1:
		return
	
	var new_index = current_weapon_index + 1
	if new_index >= weapon_data_array.size():
		new_index = 0 # Wrap around to the beginning
	
	switch_weapon(new_index)

func switch_to_previous_weapon() -> void:
	if weapon_data_array.size() <= 1:
		return
	
	var new_index = current_weapon_index - 1
	if new_index < 0:
		new_index = weapon_data_array.size() - 1 # Wrap around to the end
	
	switch_weapon(new_index)

# (Add after the switching functions)

# --- Public Interaction Functions ---

# Called by the PlayerController to fire the weapon.
func attack() -> void:
	if current_weapon_instance and current_weapon_instance.has_method("attack"):
		current_weapon_instance.attack()

# Called by the PlayerController to reload.
func reload_current_weapon() -> void:
	if current_weapon_instance and current_weapon_instance.has_method("manual_reload"):
		current_weapon_instance.manual_reload()

# --- Weapon Throwing/Pickup Logic ---

func throw_current_weapon(throw_force: Vector3 = Vector3.ZERO) -> bool:
	if not current_weapon_instance:
		return false
	
	# Get the data from the weapon we're about to throw.
	var weapon_data = weapon_data_array[current_weapon_index]
	
	if weapon_data and weapon_data.weapon_pickup_scene:
		# Instantiate the pickup/world scene for the weapon.
		var weapon_pickup = weapon_data.weapon_pickup_scene.instantiate()
		# Add it to the main game world, not as a child of the player.
		get_tree().root.add_child(weapon_pickup)
		weapon_pickup.global_position = current_weapon_instance.global_position
		
		# IMPORTANT: Copy the current weapon's data (including ammo state) to the pickup.
		if weapon_pickup.has_method("set_weapon_data"):
			weapon_pickup.set_weapon_data(weapon_data)
		
		# If it's a RigidBody3D, give it a shove.
		if weapon_pickup is RigidBody3D and throw_force != Vector3.ZERO:
			weapon_pickup.apply_central_impulse(throw_force)
		
		# Now, permanently remove the weapon from our inventory.
		remove_current_weapon()
		return true
	return false

func get_throw_direction(throw_strength: float = 7.5) -> Vector3:
	# We'll use the camera's forward direction to aim the throw.
	var camera = get_viewport().get_camera_3d()
	if camera:
		return -camera.global_transform.basis.z * throw_strength
	return Vector3.ZERO

func remove_current_weapon() -> void:
	if current_weapon_index == -1:
		return
	
	# Remove the data and the instance. Keeping these arrays in sync is critical!
	weapon_data_array.remove_at(current_weapon_index)
	weapon_instances.remove_at(current_weapon_index)
	current_weapon_instance.queue_free()
	
	# Reset the current weapon and switch to the next available one.
	current_weapon_instance = null
	current_weapon_index = -1
	
	if not weapon_data_array.is_empty():
		switch_weapon(0)
# This function adds a new weapon to our inventory.
# It will be called by our interaction system in a future tutorial.
func pickup_weapon(new_weapon_data: WeaponData) -> bool:
	if not new_weapon_data:
		return false

	# First, check if we already have this type of weapon.
	for i in range(weapon_data_array.size()):
		if weapon_data_array[i].weapon_name == new_weapon_data.weapon_name:
			# If we do, just take its ammo instead of picking up a duplicate weapon.
			var existing_data = weapon_data_array[i]
			if existing_data.uses_ammo:
				existing_data.total_ammo += new_weapon_data.current_magazine_ammo + new_weapon_data.total_ammo
				existing_data.total_ammo = min(existing_data.total_ammo, existing_data.max_total_ammo)
				print("Added ammo to %s" % existing_data.weapon_name)
				return true # Indicate success
			else:
				return false # Can't pick up duplicate melee weapon

	# If it's a new weapon, add it to our inventory.
	weapon_data_array.append(new_weapon_data)

	# Now, instantiate it and add it to our pool of weapon instances, just like in _initialize_all_weapons.
	if new_weapon_data.weapon_equipped_scene:
		var weapon_instance = new_weapon_data.weapon_equipped_scene.instantiate()
		if weapon_instance.has_method("set_weapon_data"):
			weapon_instance.set_weapon_data(new_weapon_data)
			
		weapon_instance.shooter_body = shooter_body
		
		add_child(weapon_instance)
		weapon_instance.visible = false
		weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
		weapon_instances.append(weapon_instance)
		
		# Switch to the new weapon we just picked up.
		switch_weapon(weapon_instances.size() - 1)
		return true
	else:
		weapon_instances.append(null) # Keep arrays in sync
		return false
