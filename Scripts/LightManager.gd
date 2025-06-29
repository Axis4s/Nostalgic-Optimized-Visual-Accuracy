@tool
extends Node

## Maximum number of lights to process - must match shader constant
const MAX_LIGHTS: int = 9
## Update interval for light processing in game (seconds)
const UPDATE_INTERVAL: float = 0.1
## Name or path of the shader to identify meshes using it
const SHADER_PATH := "res://Shaders/Gouraud/NewGouraud.gdshader" # Update this path to match your shader

## Cache of current lights
var cached_lights: Array = []
## Cache of light properties for change detection
var cached_light_data: Dictionary = {}
## Cache of world environment data
var cached_world_environment: WorldEnvironment = null
var cached_ambient_color: Color = Color.BLACK
## Timer for update intervals
var update_timer: float = 0.0

func _ready() -> void:
	# Connect to scene tree signals
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	# Initial light scan and environment detection
	_update_world_environment()
	_update_lights()

func _exit_tree() -> void:
	# Disconnect signals if connected
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		# Small delay to ensure material is properly set up
		get_tree().create_timer(0.1).timeout.connect(
			func():
				if is_instance_valid(node):
					_check_and_update_mesh(node as MeshInstance3D)
		)
	elif node is DirectionalLight3D or node is OmniLight3D:
		_update_lights()
	elif node is WorldEnvironment:
		_update_world_environment()

func _on_node_removed(node: Node) -> void:
	if node is DirectionalLight3D or node is OmniLight3D:
		_update_lights()
	elif node is WorldEnvironment:
		if cached_world_environment == node:
			cached_world_environment = null
			cached_ambient_color = Color.BLACK
		_update_world_environment()

func _check_and_update_mesh(mesh: MeshInstance3D) -> void:
	var material = mesh.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		if material.shader and material.shader.resource_path == SHADER_PATH:
			_update_shader_parameters(mesh)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_world_environment()
		_update_lights()
	else:
		update_timer += delta
		if update_timer >= UPDATE_INTERVAL:
			update_timer = 0.0
			_update_world_environment()
			_update_lights()

func _update_world_environment() -> void:
	var world_env = _find_world_environment()
	var ambient_color = Color.BLACK
	
	if world_env and world_env.environment:
		var env = world_env.environment
		
		# Get ambient light color based on ambient source
		match env.ambient_light_source:
			Environment.AMBIENT_SOURCE_BG:
				# Use background color
				if env.background_mode == Environment.BG_COLOR:
					ambient_color = env.background_color
				elif env.background_mode == Environment.BG_SKY and env.sky:
					# For sky background, we can't easily extract color, use a default
					ambient_color = Color(0.1, 0.1, 0.1, 1.0)  # Default sky ambient
				else:
					ambient_color = Color.BLACK
			Environment.AMBIENT_SOURCE_DISABLED:
				ambient_color = Color.BLACK
			Environment.AMBIENT_SOURCE_COLOR:
				ambient_color = env.ambient_light_color
			Environment.AMBIENT_SOURCE_SKY:
				if env.sky:
					# Sky-based ambient - use a reasonable default since we can't sample the sky
					ambient_color = Color(0.1, 0.1, 0.15, 1.0)  # Slightly blue default
				else:
					ambient_color = Color.BLACK
			_:
				ambient_color = Color.BLACK
		
		# Apply ambient energy multiplier
		ambient_color = Color(
			ambient_color.r * env.ambient_light_energy,
			ambient_color.g * env.ambient_light_energy,
			ambient_color.b * env.ambient_light_energy,
			1.0
		)
	
	# Check if environment or ambient color changed
	if cached_world_environment != world_env or cached_ambient_color != ambient_color:
		cached_world_environment = world_env
		cached_ambient_color = ambient_color
		_update_all_meshes()  # Update all meshes with new ambient color

func _find_world_environment() -> WorldEnvironment:
	var root: Node
	
	if Engine.is_editor_hint():
		root = get_tree().get_edited_scene_root()
		if not root:
			return null
	else:
		root = get_tree().root
	
	return _find_world_environment_recursive(root)

func _find_world_environment_recursive(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
		
	for child in node.get_children():
		var result = _find_world_environment_recursive(child)
		if result:
			return result
			
	return null

func _update_lights() -> void:
	var lights := _find_lights()
	if lights != cached_lights:
		cached_lights = lights
		_update_all_meshes()
		return
	
	if _light_properties_changed(lights):
		_update_all_meshes()

func _find_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var root: Node
	
	if Engine.is_editor_hint():
		# In editor, use the edited scene root
		root = get_tree().get_edited_scene_root()
		if not root:
			return meshes
	else:
		# In game, use the scene tree root
		root = get_tree().root
	
	_collect_meshes_recursive(root, meshes)
	return meshes

func _collect_meshes_recursive(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var material = node.get_surface_override_material(0)
		if material and material is ShaderMaterial:
			if material.shader and material.shader.resource_path == SHADER_PATH:
				meshes.append(node)
	
	for child in node.get_children():
		_collect_meshes_recursive(child, meshes)

func _update_all_meshes() -> void:
	var meshes = _find_meshes()
	for mesh in meshes:
		_update_shader_parameters(mesh)

func _light_properties_changed(lights: Array) -> bool:
	var new_data: Dictionary = {}
	for light in lights:
		if not is_instance_valid(light) or not light.visible or not light.is_inside_tree():
			continue
		
		var light_id = light.get_instance_id()
		var light_data = []
		
		if light is DirectionalLight3D:
			light_data = [
				-light.global_transform.basis.z,
				light.light_color,
				light.light_energy,
				false  # is_point_light
			]
		elif light is OmniLight3D:
			light_data = [
				light.global_position,
				light.light_color,
				light.light_energy,
				true,  # is_point_light
				light.omni_range,
				light.omni_attenuation
			]
		
		new_data[light_id] = light_data
	
	if new_data.hash() != cached_light_data.hash():
		cached_light_data = new_data
		return true
	return false

func _find_lights() -> Array:
	var all_lights: Array = []
	var root: Node
	
	if Engine.is_editor_hint():
		root = get_tree().get_edited_scene_root()
	else:
		root = get_tree().root
		
	if not root:
		return all_lights
	
	_collect_lights_recursive(root, all_lights)
	
	return all_lights

func _collect_lights_recursive(node: Node, lights: Array) -> void:
	if node is DirectionalLight3D and node.visible:
		lights.append(node)
	elif node is OmniLight3D and node.visible:
		lights.append(node)
	
	for child in node.get_children():
		_collect_lights_recursive(child, lights)

func _sort_lights_for_mesh(mesh: MeshInstance3D, lights: Array) -> Array:
	var sorted_lights: Array = []
	var point_lights: Array = []
	var directional_lights: Array = []
	
	# Check if mesh is valid and in tree
	if not is_instance_valid(mesh) or not mesh.is_inside_tree():
		return sorted_lights
	
	# Cache mesh position
	var mesh_global_pos = mesh.global_position
	
	# Separate lights by type and filter out-of-range point lights
	for light in lights:
		# Check if light is valid and in tree before accessing transform
		if not is_instance_valid(light) or not light.is_inside_tree():
			continue
			
		if light is DirectionalLight3D:
			directional_lights.append(light)
		elif light is OmniLight3D:
			var dist = mesh_global_pos.distance_squared_to(light.global_position)
			var range_squared = light.omni_range * light.omni_range * 1.44  # 1.2 * 1.2
			if dist <= range_squared:
				point_lights.append(light)
	
	# Sort point lights by priority
	if point_lights.size() > 0:
		point_lights.sort_custom(func(a: OmniLight3D, b: OmniLight3D):
			# Additional safety check inside sort function
			if not is_instance_valid(a) or not a.is_inside_tree() or not is_instance_valid(b) or not b.is_inside_tree():
				return false
				
			var dist_a = mesh_global_pos.distance_squared_to(a.global_position)
			var dist_b = mesh_global_pos.distance_squared_to(b.global_position)
			
			# Consider intensity and range in priority
			var priority_a = a.light_energy * (1.0 - sqrt(dist_a) / a.omni_range)
			var priority_b = b.light_energy * (1.0 - sqrt(dist_b) / b.omni_range)
			
			return priority_a > priority_b
		)
	
	# Prioritize directional lights first
	sorted_lights.append_array(directional_lights)
	sorted_lights.append_array(point_lights)
	
	return sorted_lights.slice(0, MAX_LIGHTS)

func _update_shader_parameters(mesh: MeshInstance3D) -> void:
	# Check if mesh is valid and in tree
	if not is_instance_valid(mesh) or not mesh.is_inside_tree():
		return
		
	var material = mesh.get_surface_override_material(0)
	if not material or not (material is ShaderMaterial):
		return
		
	# Force material to update its shader
	if material.shader and material.shader.resource_path == SHADER_PATH:
		material.shader = material.shader # This forces a shader reload
		
	var sorted_lights = _sort_lights_for_mesh(mesh, cached_lights)
	
	var directions := PackedVector3Array()
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	var intensities := PackedFloat32Array()
	var is_point_light := PackedByteArray()
	var ranges := PackedFloat32Array()
	var attenuations := PackedFloat32Array()
	var active_count: int = 0
	
	for light in sorted_lights:
		if not is_instance_valid(light) or not light.visible or not light.is_inside_tree():
			continue
			
		if light is DirectionalLight3D:
			directions.append(-light.global_transform.basis.z)
			positions.append(Vector3.ZERO)
			colors.append(light.light_color)
			intensities.append(light.light_energy)
			is_point_light.append(0)
			ranges.append(0.0)
			attenuations.append(0.0)
			active_count += 1
		elif light is OmniLight3D:
			directions.append(Vector3.ZERO)
			positions.append(light.global_position)
			colors.append(light.light_color)
			intensities.append(light.light_energy)
			is_point_light.append(1)
			ranges.append(light.omni_range)
			attenuations.append(light.omni_attenuation)
			active_count += 1
	
	# Pad arrays to ensure consistent size
	while directions.size() < MAX_LIGHTS:
		directions.append(Vector3.ZERO)
		positions.append(Vector3.ZERO)
		colors.append(Color.BLACK)
		intensities.append(0.0)
		is_point_light.append(0)
		ranges.append(0.0)
		attenuations.append(0.0)
	
	# Update shader parameters
	material.set_shader_parameter("light_directions", directions)
	material.set_shader_parameter("light_positions", positions)
	material.set_shader_parameter("light_colors", colors)
	material.set_shader_parameter("light_intensities", intensities)
	material.set_shader_parameter("is_point_light", is_point_light)
	material.set_shader_parameter("light_ranges", ranges)
	material.set_shader_parameter("light_attenuations", attenuations)
	material.set_shader_parameter("active_light_count", active_count)
	
	# Update world ambient color from WorldEnvironment
	material.set_shader_parameter("world_ambient_color", Vector3(cached_ambient_color.r, cached_ambient_color.g, cached_ambient_color.b))
	
	# Update specular parameters if they exist
	if material.get_shader_parameter("enable_specular") != null:
		var enable_specular = material.get_shader_parameter("enable_specular")
		material.set_shader_parameter("enable_specular", enable_specular)
		
		if enable_specular:
			material.set_shader_parameter("specular_power", material.get_shader_parameter("specular_power"))
			material.set_shader_parameter("specular_intensity", material.get_shader_parameter("specular_intensity"))
			material.set_shader_parameter("specular_color", material.get_shader_parameter("specular_color"))
			material.set_shader_parameter("per_pixel_specular", material.get_shader_parameter("per_pixel_specular"))
