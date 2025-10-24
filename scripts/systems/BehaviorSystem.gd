class_name BehaviorSystem
extends Node

const Relationship = preload("res://scripts/entities/Relationship.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# Maintains compatibility with older callers while delegating to the new logic.
func suggest_action_for(npc: NPC) -> String:
	return choose_action_for(npc)

# Chooses an action for the NPC based on emotional intensity and strongest relationship affinity.
func choose_action_for(npc: NPC) -> String:
	var strongest_affinity: float = _get_strongest_affinity(npc)
	var emotion_intensity: float = 0.0
	if npc.current_emotion:
		emotion_intensity = npc.current_emotion.intensity

	var interact_weight: float = 1.0
	if strongest_affinity > 0.7:
		interact_weight += 1.5
	elif strongest_affinity > 0.3:
		interact_weight += 0.75
	interact_weight += max(emotion_intensity, 0.0) * 1.25

	var walk_weight: float = 1.0 + (1.0 - abs(emotion_intensity)) * 0.5
	var ignore_weight: float = 1.0 + max(-strongest_affinity, 0.0) * 1.5 + max(-emotion_intensity, 0.0) * 1.25

	var total: float = interact_weight + walk_weight + ignore_weight
	if total == 0.0:
		return "idle"
	var roll: float = rng.randf() * total
	if roll < interact_weight:
		return "interact"
	elif roll < interact_weight + walk_weight:
		return "walk"
	return "ignore"

# Hook for other systems to listen for completed interactions.
func notify_interaction(_npc: NPC, _other: NPC) -> void:
	pass

func _get_strongest_affinity(npc: NPC) -> float:
	var strongest: float = 0.0
	var relationships: Dictionary = npc.get_relationship_snapshot()
	for relationship in relationships.values():
		if relationship is Relationship:
			strongest = max(strongest, relationship.affinity)
		else:
			strongest = max(strongest, float(relationship.get("affinity", 0.0)))
	return strongest
