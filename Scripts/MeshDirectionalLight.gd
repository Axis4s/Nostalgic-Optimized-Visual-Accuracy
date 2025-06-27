@tool
extends MeshInstance3D

@export var directional_light: DirectionalLight3D
var material: ShaderMaterial

func _ready():
	material = get_surface_override_material(0)
	if material:
		update_light_direction()

func _process(_delta):
	if material and directional_light:
		update_light_direction()

func update_light_direction():
	# Make sure we have a light assigned and material is valid
	if not directional_light or not material:
		return
	
	# Make sure the light node is valid
	if not is_instance_valid(directional_light):
		return
	
	# Get the forward direction of the light (negative Z in local space)
	var light_forward = -directional_light.global_transform.basis.z
	
	# Update the material's light_direction parameter
	material.set_shader_parameter("light_direction", light_forward)
