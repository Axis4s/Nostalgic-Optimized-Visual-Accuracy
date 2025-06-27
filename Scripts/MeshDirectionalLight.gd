@tool
extends MeshInstance3D

const MAX_LIGHTS = 9

var material: ShaderMaterial
var cached_lights: Array[DirectionalLight3D] = []
var last_update_time: float = 0.0
const UPDATE_INTERVAL: float = 0.1

func _ready():
	material = get_surface_override_material(0)
	if material:
		find_and_update_lights()

func _process(_delta):
	if Engine.is_editor_hint():
		# In editor, update immediately
		find_and_update_lights()
	else:
		# In game, use the interval
		if material:
			last_update_time += _delta
			if last_update_time >= UPDATE_INTERVAL:
				last_update_time = 0.0
				find_and_update_lights()

func find_and_update_lights():
	var lights: Array[DirectionalLight3D] = []
	
	# Get the appropriate root node
	var root = get_tree().get_edited_scene_root() if Engine.is_editor_hint() else get_tree().root
	if root:
		lights = find_directional_lights(root)
		
		# Only update if lights have changed or we're in the editor
		if Engine.is_editor_hint() or lights_have_changed(lights):
			cached_lights = lights
			update_light_parameters()

func lights_have_changed(new_lights: Array) -> bool:
	if new_lights.size() != cached_lights.size():
		return true
	
	for i in range(new_lights.size()):
		if new_lights[i] != cached_lights[i]:
			return true
			
	return false

func find_directional_lights(node: Node) -> Array[DirectionalLight3D]:
	var lights: Array[DirectionalLight3D] = []
	
	# Check if current node is a DirectionalLight3D and is visible
	if node is DirectionalLight3D and node.visible:
		lights.append(node)
	
	# Recursively search through all children
	for child in node.get_children():
		if lights.size() >= MAX_LIGHTS:
			break
		lights.append_array(find_directional_lights(child))
	
	# Only return up to MAX_LIGHTS
	return lights.slice(0, MAX_LIGHTS)

func update_light_parameters():
	if not material:
		return
	
	# Initialize arrays
	var light_directions = PackedVector3Array()
	var light_colors = PackedColorArray()
	var light_intensities = PackedFloat32Array()
	var active_count = 0
	
	# Process lights
	for light in cached_lights:
		if not is_instance_valid(light) or not light.visible:
			continue
		
		# Get light parameters
		var light_dir = -light.global_transform.basis.z
		var light_color = light.light_color
		var light_energy = light.light_energy
		
		light_directions.push_back(light_dir)
		light_colors.push_back(light_color)
		light_intensities.push_back(light_energy)
		active_count += 1
	
	# Pad arrays to MAX_LIGHTS size
	while light_directions.size() < MAX_LIGHTS:
		light_directions.push_back(Vector3.ZERO)
		light_colors.push_back(Color.BLACK)
		light_intensities.push_back(0.0)
	
	# Update shader parameters
	material.set_shader_parameter("light_directions", light_directions)
	material.set_shader_parameter("light_colors", light_colors)
	material.set_shader_parameter("light_intensities", light_intensities)
	material.set_shader_parameter("active_light_count", active_count)
