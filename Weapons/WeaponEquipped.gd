# WeaponEquipped.gd
class_name WeaponEquipped
extends Node3D

# This signal will be sent up to the WeaponManager when we hit something.
signal deal_damage(damage_amount: int, hit_point: Vector3, hit_normal: Vector3, collider: Object)
signal ammo_changed(current_magazine: int, total_ammo: int)
signal reload_started()
signal reload_finished()

# This will hold the data resource for the specific weapon (e.g., revolver.tres)
var weapon_data: WeaponData
var reload_timer: Timer

func _ready() -> void:
	# We will initialize things here later
	pass
	
func _initialize_ammo_system() -> void:
	if not weapon_data or not weapon_data.uses_ammo:
		return
	
	# If this is the first time, set ammo to full.
	if weapon_data.total_ammo == 0:
		weapon_data.initialize_ammo()
		
	# Create a timer for reloading
	if not reload_timer:
		reload_timer = Timer.new()
		reload_timer.one_shot = true
		reload_timer.timeout.connect(_on_reload_finished)
		add_child(reload_timer)
	
	reload_timer.wait_time = weapon_data.reload_time
	
	# Tell the UI about our current ammo count
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)

func can_fire() -> bool:
	if not weapon_data: return false
	if not weapon_data.uses_ammo: return true # Melee weapons can always fire
	return weapon_data.current_magazine_ammo > 0 and not weapon_data.is_reloading

func consume_ammo() -> void:
	if not can_fire(): return
	
	weapon_data.current_magazine_ammo -= 1
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)
	
	if weapon_data.current_magazine_ammo <= 0 and weapon_data.total_ammo > 0:
		start_reload() # Auto-reload when the mag is empty

func start_reload() -> void:
	if not weapon_data or not weapon_data.uses_ammo or weapon_data.is_reloading: return
	if weapon_data.current_magazine_ammo >= weapon_data.max_magazine_capacity: return
	if weapon_data.total_ammo <= 0: return

	weapon_data.is_reloading = true
	reload_timer.start()
	reload_started.emit()

func _on_reload_finished() -> void:
	var ammo_needed = weapon_data.max_magazine_capacity - weapon_data.current_magazine_ammo
	var ammo_to_transfer = min(ammo_needed, weapon_data.total_ammo)
	
	weapon_data.current_magazine_ammo += ammo_to_transfer
	weapon_data.total_ammo -= ammo_to_transfer
	
	weapon_data.is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)

func manual_reload() -> void:
	start_reload()
# We'll export node paths so we can link them easily in the editor.
@export var weapon_model: Node3D # The visual part of the weapon that will move.
@export var fire_ray: RayCast3D  # The raycast that determines where we hit.

# This variable will be set by the WeaponManager so we know who is shooting.
@export var shooter_body: CharacterBody3D

# This function is the crucial link. The WeaponManager will call this
# right after it creates the weapon instance.
func set_weapon_data(data: WeaponData) -> void:
	weapon_data = data
	_initialize_ammo_system() # Call the setup function here

# This is a "virtual" function. We define it here, but each specific weapon
# script (like our revolver) will provide its own implementation.
func attack() -> void:
	# Base implementation does nothing.
	# The child script (RevolverEquipped.gd) will override this.
	pass


# Add this function to WeaponEquipped.gd

func fire_hitscan() -> void:
	if not can_fire():
		print("Cannot fire: No ammo or reloading!")
		return
	
	consume_ammo()
	if not fire_ray:
		printerr("Fire Ray not assigned for ", self.name)
		return

	# We get the physics world.
	var space_state = get_world_3d().direct_space_state
	# The query holds the ray's start, end, and any exceptions.
	var query = PhysicsRayQueryParameters3D.create(
		fire_ray.global_position,
		fire_ray.to_global(fire_ray.get_target_position())
	)
	# This is crucial: we tell the ray to ignore the player's body.
	if shooter_body:
		query.exclude = [shooter_body.get_rid()]
	
	# We execute the raycast!
	var result = space_state.intersect_ray(query)
	
	# Did we hit anything?
	if result:
		var collider = result.collider
		var hit_point = result.position
		var hit_normal = result.normal
		
		print("Hit: ", collider.name, " at position ", hit_point)
		
		# --- Placeholder Impact Effect ---
		# To visually confirm our hit, let's spawn a small red cube.
		var hit_marker = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.RED
		box_mesh.material = material
		box_mesh.size = Vector3(0.1, 0.1, 0.1)
		hit_marker.mesh = box_mesh
		
		# Add the marker to the main scene tree and position it.
		get_tree().root.add_child(hit_marker)
		hit_marker.global_position = hit_point
		
		# Send the damage info up to the WeaponManager.
		deal_damage.emit(weapon_data.damage, hit_point, hit_normal, collider)
