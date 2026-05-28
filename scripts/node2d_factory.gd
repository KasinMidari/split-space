extends Node
class_name NodeFactory

signal created(product)

@export var product_packed_scene: PackedScene
@export var target_container_name: StringName

func create(_product_packed_scene := product_packed_scene) -> Node2D:
	if not _product_packed_scene:
		push_error("No packed scene provided")
		return null
	
	var product: Node2D = _product_packed_scene.instantiate()
	#product.global_position = global_position
	
	if not GameManager.current_match:
		push_error("GameManager.current_match is null")
		return null
	
	var container = GameManager.current_match.find_child(target_container_name, true, false)
	
	if not container:
		push_error("Container not found: ",  target_container_name)
		push_error("Available children: ", GameManager.current_match.get_children())
		return null
	
	container.add_child(product)
	created.emit(product)
	return product
