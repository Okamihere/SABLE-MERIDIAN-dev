extends Node
## Aplica outline via next_pass nos materiais das MeshInstance3D filhas.
## Adicionar este node nas cenas de personagens. Marcar meshes sem outline
## no grupo "no_outline".

@export var enabled: bool = true
@export var outline_color: Color = Color(0.02, 0.01, 0.05, 1.0)
@export var outline_width: float = 0.01

var _outline_material: ShaderMaterial

func _ready() -> void:
    if not enabled:
        return
    var shader := load("res://shaders/outline.gdshader") as Shader
    _outline_material = ShaderMaterial.new()
    _outline_material.shader = shader
    _outline_material.set_shader_parameter("outline_color", outline_color)
    _outline_material.set_shader_parameter("outline_width", outline_width)
    _apply_recursive(get_parent())

func _apply_recursive(node: Node) -> void:
    if node is MeshInstance3D and not node.is_in_group("no_outline"):
        _apply_to_mesh(node)
    for child in node.get_children():
        _apply_recursive(child)

func _apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
    if mesh_instance.mesh == null:
        return
    for i in mesh_instance.mesh.get_surface_count():
        var mat := mesh_instance.get_active_material(i)
        if mat is BaseMaterial3D:
            if mat.next_pass == _outline_material:
                continue
            var local_material := mat.duplicate() as BaseMaterial3D
            local_material.next_pass = _outline_material
            if mesh_instance.material_override != null:
                mesh_instance.material_override = local_material
                break
            mesh_instance.set_surface_override_material(i, local_material)
