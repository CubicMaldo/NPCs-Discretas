class_name SocialComponent
extends Node

## Componente que proporciona una interfaz limpia entre un NPC y el SocialGraphManager.
## Elimina la necesidad de mantener cachés locales redundantes y sincronización manual.

signal relationship_changed(partner_id: int, new_familiarity: float)
signal relationship_broken(partner_id: int)

@export var owner_id: int = -1
@export var break_threshold: float = 0.0
@export var auto_register: bool = true

var social_graph_manager: SocialGraphManager

func _ready() -> void:
	if auto_register and social_graph_manager:
		_ensure_registered()

## Inyecta el SocialGraphManager y opcionalmente registra el NPC automáticamente.
func set_graph_manager(manager: SocialGraphManager) -> void:
	social_graph_manager = manager
	if auto_register:
		_ensure_registered()

## Obtiene la relación con un partner (NPC o id) directamente del grafo social.
## No mantiene caché local para evitar inconsistencias.
func get_relationship(partner) -> float:
	if not social_graph_manager:
		return 0.0
	var owner_key = _get_owner_key()
	if owner_key == null:
		return 0.0
	return social_graph_manager.get_familiarity(owner_key, partner, 0.0)

## Obtiene todas las relaciones salientes del owner desde el grafo social.
func get_all_relationships() -> Dictionary:
	if not social_graph_manager:
		return {}
	var owner_key = _get_owner_key()
	if owner_key == null:
		return {}
	return social_graph_manager.get_relationships_for(owner_key)

## Establece o actualiza una relación con un partner.
func set_relationship(partner, familiarity: float) -> void:
	if not social_graph_manager:
		return
	var owner_key = _get_owner_key()
	if owner_key == null:
		return
	
	if familiarity < break_threshold:
		break_relationship(partner)
		return
	
	social_graph_manager.set_familiarity(owner_key, partner, familiarity)
	relationship_changed.emit(_get_partner_id(partner), familiarity)

## Actualiza la familiaridad existente con un delta incremental.
func update_familiarity(partner, delta: float) -> void:
	if not social_graph_manager:
		return
	var owner_key = _get_owner_key()
	if owner_key == null:
		return
	
	var current := social_graph_manager.get_familiarity(owner_key, partner, 0.0)
	var new_familiarity := current + delta
	
	if new_familiarity < break_threshold:
		break_relationship(partner)
		return
	
	social_graph_manager.set_familiarity(owner_key, partner, new_familiarity)
	relationship_changed.emit(_get_partner_id(partner), new_familiarity)

## Rompe una relación eliminándola del grafo social.
func break_relationship(partner) -> void:
	if not social_graph_manager:
		return
	var owner_key = _get_owner_key()
	if owner_key == null:
		return
	
	social_graph_manager.remove_connection(owner_key, partner)
	relationship_broken.emit(_get_partner_id(partner))

## Obtiene los N partners con mayor familiaridad.
func get_top_relationships(top_n: int = 3) -> Array:
	if not social_graph_manager:
		return []
	var owner_key = _get_owner_key()
	if owner_key == null:
		return []
	return social_graph_manager.get_top_relations(owner_key, top_n)

## Obtiene todos los partners con familiaridad por encima de un umbral.
func get_friends_above(threshold: float) -> Array:
	if not social_graph_manager:
		return []
	var owner_key = _get_owner_key()
	if owner_key == null:
		return []
	return social_graph_manager.get_friends_above(owner_key, threshold)

## Comprueba si existe una relación con familiaridad mínima.
func has_relationship_at_least(partner, threshold: float) -> bool:
	if not social_graph_manager:
		return false
	var owner_key = _get_owner_key()
	if owner_key == null:
		return false
	return social_graph_manager.has_relationship_at_least(owner_key, partner, threshold)

## Obtiene la relación más fuerte (mayor familiaridad).
func get_strongest_relationship() -> float:
	var relationships := get_all_relationships()
	var strongest := 0.0
	for familiarity in relationships.values():
		if typeof(familiarity) == TYPE_FLOAT or typeof(familiarity) == TYPE_INT:
			strongest = max(strongest, float(familiarity))
	return strongest

## Obtiene el número total de relaciones activas.
func get_relationship_count() -> int:
	if not social_graph_manager:
		return 0
	var owner_key = _get_owner_key()
	if owner_key == null:
		return 0
	return social_graph_manager.get_cached_degree(owner_key)

func _get_owner_key():
	var parent = get_parent()
	if parent is NPC:
		return parent
	if owner_id != -1:
		return owner_id
	return null

func _get_partner_id(partner) -> int:
	if partner is NPC:
		return partner.npc_id
	if typeof(partner) == TYPE_INT:
		return int(partner)
	return -1

func _ensure_registered() -> void:
	if not social_graph_manager:
		return
	var owner_key = _get_owner_key()
	if owner_key != null:
		social_graph_manager.ensure_npc(owner_key)
